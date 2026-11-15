## 文件用途：保存世界日期、人口、资源与建筑实例，并提供v1到v6快照迁移和完整校验。
extends RefCounted

# 状态模块：数值均为待平衡参数，资源以完整单位保存。
const DAY_TICKS: int = 120
const Catalog = preload("res://scripts/building_catalog.gd")
const FoodLedger = preload("res://scripts/food_ledger.gd")
const Placement = preload("res://scripts/placement_validator.gd")
var tick: int = 0
var subsecond: float = 0.0
var last_settled_day: int = 0
var population: int = 30

# 劳动力模块：居民分为可就业与被抚养人口，施工岗位最多两人，其余保持空闲。
var dependents: int = 6
var builders: int = 2
var labor_credit: int = 0
var resources: Dictionary = {"food": 180, "gold": 300, "wood": 120, "stone": 80}
var speed: int = 1
var paused: bool = true
var last_food_ledger: Dictionary = {}
var last_bill: String = "尚未日结；生产建筑完工并分配工人后可产粮"

# 建筑模块：初始领主厅免费存在，实例ID不复用，回执只记录成功命令。
var buildings: Array = [{"id": "building_000001", "def_id": "b_hall", "cell": [6, 6], "level": 1, "state": "ready", "work_done": 0, "work_required": 0, "workers": 0, "food_credit": 0}]
var next_building_id: int = 2
var applied_commands: Dictionary = {}


# 日期模块：第0至119秒属于第1日，完成120秒才进入第2日。
func current_day() -> int:
	return int(tick / float(DAY_TICKS)) + 1


# 日结模块：固定先收获再消费，记录可重算的账单，同一天不重复结算。
func settle_days() -> void:
	while last_settled_day < current_day() - 1:
		var sources: Dictionary = collect_food()
		last_food_ledger = FoodLedger.calculate(last_settled_day + 1, int(resources["food"]), food_capacity(), sources, population)
		resources["food"] = last_food_ledger["closing"]
		var tax: int = roundi(population * 0.8 * (50.0 / 60.0))
		resources["gold"] += tax
		last_settled_day += 1
		last_bill = "第%d日日结：产粮 +%d（入库%d，溢出%d），消耗 -%d，净变%+d，税收 +%d" % [last_settled_day, last_food_ledger["produced"], last_food_ledger["stored"], last_food_ledger["overflow"], last_food_ledger["consumed"], last_food_ledger["net"], tax]
		if last_food_ledger["shortage"] > 0:
			last_bill += "；缺粮 %d（本阶段仅提示）" % last_food_ledger["shortage"]

# 快照模块：只导出基础数据，不保存节点、数据库连接或脚本引用。
func snapshot() -> Dictionary:
	return {"version": 6, "tick": tick, "subsecond": subsecond, "last_settled_day": last_settled_day, "population": population, "dependents": dependents, "builders": builders, "labor_credit": labor_credit, "resources": resources.duplicate(), "speed": speed, "paused": paused, "last_bill": last_bill, "last_food_ledger": last_food_ledger.duplicate(true), "buildings": buildings.duplicate(true), "next_building_id": next_building_id, "applied_commands": applied_commands.duplicate(true)}


# 载入模块：在临时对象中完整校验，失败返回空值，不改变当前世界。
static func from_snapshot(data: Variant) -> RefCounted:
	if not data is Dictionary:
		return null
	for key: String in ["version", "tick", "last_settled_day", "population", "speed"]:
		if not _valid_integer(data.get(key), 0, 120000000):
			return null
	if int(data["version"]) not in [1, 2, 3, 4, 5, 6] or int(data["speed"]) not in [1, 2, 4] or data["population"] != 30:
		return null
	if data["last_settled_day"] != int(float(data["tick"]) / DAY_TICKS):
		return null
	var fraction: Variant = data.get("subsecond")
	if typeof(fraction) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(fraction)) or fraction < 0 or fraction >= 1:
		return null
	if not data.get("paused") is bool or not data.get("last_bill") is String or data["last_bill"].length() > 200:
		return null
	if not data.get("resources") is Dictionary:
		return null
	for key: String in ["food", "gold", "wood", "stone"]:
		if not _valid_integer(data["resources"].get(key), 0, 1000000000):
			return null
	var state: RefCounted = load("res://scripts/world_state.gd").new()
	state.tick = int(data["tick"])
	state.subsecond = float(fraction)
	state.last_settled_day = int(data["last_settled_day"])
	state.population = int(data["population"])
	# 迁移模块：旧档默认两名施工工人，保留原进度和速度，不重新扣费。
	if int(data["version"]) >= 4:
		if not _valid_integer(data.get("dependents"), 0, state.population) or not _valid_integer(data.get("builders"), 0, 2) or not _valid_integer(data.get("labor_credit"), 0, 1):
			return null
		state.dependents = int(data["dependents"])
		state.builders = int(data["builders"])
		state.labor_credit = int(data["labor_credit"])
		if state.builders > state.population - state.dependents:
			return null
	for key: String in ["food", "gold", "wood", "stone"]:
		state.resources[key] = int(data["resources"][key])
	state.speed = int(data["speed"])
	state.paused = data["paused"]
	state.last_bill = data["last_bill"]
	# 历史迁移模块：旧档不虚构粮食收支，新版账单完整校验后才恢复。
	if int(data["version"]) >= 6:
		if not FoodLedger.valid(data.get("last_food_ledger"), state.last_settled_day, state.population):
			return null
		var saved_ledger: Dictionary = data["last_food_ledger"]
		if not saved_ledger.is_empty():
			state.last_food_ledger = FoodLedger.calculate(int(saved_ledger["day"]), int(saved_ledger["opening"]), int(saved_ledger["capacity"]), saved_ledger["by_source"], state.population)
	# 迁移模块：旧战略档没有建筑，保留经济时间并补初始领主厅，不立即覆写磁盘。
	if int(data["version"]) == 1:
		return state
	if not state._restore_buildings(data) or state.idle_workers() < 0:
		return null
	return state


# 数值模块：拒绝空值、小数、负数、无穷值和超出边界的数据。
static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floor(float(value))


# 占用模块：从真实实例推导占用，不将冗余格表另行存档。
func occupied_cells() -> Dictionary:
	var occupied: Dictionary = {}
	for record: Dictionary in buildings:
		var definition: Resource = Catalog.find(record["def_id"])
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		for cell: Vector2i in Placement.footprint_cells(anchor, definition.get("footprint")):
			occupied[cell] = record["id"]
	return occupied


# 建筑载入模块：校验定义、坐标、重叠、实例ID、计数器与回执引用后才整体替换。
func _restore_buildings(data: Dictionary) -> bool:
	if not data.get("buildings") is Array or data["buildings"].is_empty() or data["buildings"].size() > 256:
		return false
	if not _valid_integer(data.get("next_building_id"), 2, 1000000) or not data.get("applied_commands") is Dictionary:
		return false
	var records: Array = []
	var by_id: Dictionary = {}
	var occupied: Dictionary = {}
	var hall_count: int = 0
	for raw: Variant in data["buildings"]:
		if not raw is Dictionary or not raw.get("id") is String or not raw.get("def_id") is String:
			return false
		var id: String = raw["id"]
		var suffix: String = id.trim_prefix("building_")
		if not suffix.is_valid_int():
			return false
		var number: int = int(suffix)
		if number < 1 or number >= int(data["next_building_id"]) or id != "building_%06d" % number or by_id.has(id):
			return false
		var definition: Resource = Catalog.find(raw["def_id"])
		if definition == null or not raw.get("cell") is Array or raw["cell"].size() != 2:
			return false
		if not _valid_integer(raw["cell"][0], 0, 15) or not _valid_integer(raw["cell"][1], 0, 15) or not _valid_integer(raw.get("level"), 1, 1) or raw.get("state") not in ["ready", "constructing"]:
			return false
		var anchor: Vector2i = Vector2i(int(raw["cell"][0]), int(raw["cell"][1]))
		var check: Dictionary = Placement.check(anchor, definition.get("footprint"), occupied)
		if not check["ok"]:
			return false
		# 渔场存档模块：新增渔场仍必须位于岸上临水地块，旧陆地建筑保留原址。
		if definition.get("requires_water") and not preload("res://scripts/town_terrain.gd").check(check["cells"], true)["ok"]:
			return false
		if raw["def_id"] == "b_hall":
			hall_count += 1
			if id != "building_000001" or anchor != Vector2i(6, 6):
				return false
		# 施工迁移模块：旧v2的即时建筑保留完工状态，新版严格检查状态与进度一致。
		var done: int = 0
		var required: int = 0
		if int(data["version"]) == 2:
			if raw["state"] != "ready":
				return false
		else:
			if not _valid_integer(raw.get("work_required"), 0, 100000) or not _valid_integer(raw.get("work_done"), 0, int(raw.get("work_required", 0))):
				return false
			done = int(raw["work_done"])
			required = int(raw["work_required"])
			if (raw["state"] == "ready") != (done == required):
				return false
			if raw["def_id"] == "b_hall" and (required != 0 or raw["state"] != "ready"):
				return false
		# 生产迁移模块：旧档的建筑默认无人工作，不追溯发放粮食。
		var workers: int = 0
		var credit: int = 0
		if int(data["version"]) >= 5:
			if not _valid_integer(raw.get("workers"), 0, int(definition.get("worker_slots"))) or not _valid_integer(raw.get("food_credit"), 0, int(definition.get("worker_slots")) * int(definition.get("food_per_worker_day")) * DAY_TICKS + DAY_TICKS - 1):
				return false
			workers = int(raw["workers"])
			credit = int(raw["food_credit"])
			if (raw["state"] != "ready" or int(definition.get("worker_slots")) == 0) and (workers != 0 or credit != 0):
				return false
		var record: Dictionary = {"id": id, "def_id": raw["def_id"], "cell": [anchor.x, anchor.y], "level": 1, "state": raw["state"], "work_done": done, "work_required": required, "workers": workers, "food_credit": credit}
		records.append(record)
		by_id[id] = record
		for cell: Vector2i in check["cells"]:
			occupied[cell] = id
	if hall_count != 1 or data["applied_commands"].size() != records.size() - 1:
		return false
	var receipts: Dictionary = {}
	var receipted: Dictionary = {}
	for command: Variant in data["applied_commands"]:
		if not command is String or command.is_empty() or command.length() > 64:
			return false
		var raw: Variant = data["applied_commands"][command]
		if not raw is Dictionary or not raw.get("building_id") is String or not by_id.has(raw["building_id"]):
			return false
		var record: Dictionary = by_id[raw["building_id"]]
		if record["def_id"] == "b_hall" or raw.get("def_id") != record["def_id"] or receipted.has(record["id"]):
			return false
		if not raw.get("cell") is Array or raw["cell"].size() != 2 or not _valid_integer(raw["cell"][0], 0, 15) or not _valid_integer(raw["cell"][1], 0, 15):
			return false
		if [int(raw["cell"][0]), int(raw["cell"][1])] != record["cell"]:
			return false
		receipts[command] = {"def_id": record["def_id"], "cell": record["cell"].duplicate(), "building_id": record["id"]}
		receipted[record["id"]] = true
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	buildings = records
	next_building_id = int(data["next_building_id"])
	applied_commands = receipts
	return true


# 施工推进模块：每名工人每战略秒投入半份工作，整数余数避免浮点误差并支持中途存档。
func advance_construction() -> void:
	for building: Dictionary in buildings:
		if building["state"] == "constructing":
			if builders == 0:
				return
			labor_credit += builders
			if labor_credit < 2:
				return
			labor_credit -= 2
			building["work_done"] = mini(int(building["work_done"]) + 1, int(building["work_required"]))
			if building["work_done"] == building["work_required"]:
				building["state"] = "ready"
			return
	labor_credit = 0


# 分配模块：拒绝超额或负人数，合法调整不增减总人口、不扣金币。
func assign_builders(count: int) -> bool:
	if count < 0 or count > 2 or count > population - dependents - production_workers():
		return false
	builders = count
	return true


# 统计模块：施工岗位计入可就业人口，保持人口与岗位守恒。
func idle_workers() -> int:
	return population - dependents - builders - production_workers()


# 住房模块：只有完工住宅增加容量，未完工工地不提供住房。
func housing_capacity() -> int:
	var capacity: int = 30
	for building: Dictionary in buildings:
		if building["def_id"] == "b_house" and building["state"] == "ready":
			capacity += 10
	return capacity


# 生产岗位统计模块：所有生产建筑共享同一镇民劳动力池。
func production_workers() -> int:
	var total: int = 0
	for building: Dictionary in buildings:
		total += int(building["workers"])
	return total


# 生产岗位分配模块：仅完工生产建筑可用，超岗位或超劳动力请求不改变状态。
func assign_producers(building_id: String, count: int) -> bool:
	for building: Dictionary in buildings:
		if building["id"] == building_id:
			var definition: Resource = Catalog.find(building["def_id"])
			if building["state"] != "ready" or int(definition.get("worker_slots")) == 0 or count < 0 or count > int(definition.get("worker_slots")) or count - int(building["workers"]) > idle_workers():
				return false
			building["workers"] = count
			return true
	return false


# 工作累计模块：每战略秒按真实在岗人数增加整数信用，调岗不会补发整日产量。
func advance_production() -> void:
	for building: Dictionary in buildings:
		if building["state"] == "ready" and int(building["workers"]) > 0:
			var rate: int = int(Catalog.find(building["def_id"]).get("food_per_worker_day"))
			building["food_credit"] += int(building["workers"]) * rate


# 收获模块：按生产来源统计整份粮食，零头跨日保留，溢出也不重复发放。
func collect_food() -> Dictionary:
	var sources: Dictionary = {"b_farm": 0, "b_ranch": 0, "b_fishery": 0}
	for building: Dictionary in buildings:
		if sources.has(building["def_id"]):
			sources[building["def_id"]] += int(int(building["food_credit"]) / float(DAY_TICKS))
			building["food_credit"] = int(building["food_credit"]) % DAY_TICKS
	return sources


# 容量模块：基础公共储粮300，每座完工粮仓叠加静态配置容量，工地不计入。
func food_capacity() -> int:
	var capacity: int = 300
	for building: Dictionary in buildings:
		if building["state"] == "ready":
			capacity += int(Catalog.find(building["def_id"]).get("food_capacity"))
	return capacity
