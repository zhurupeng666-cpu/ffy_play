## 文件用途：保存世界日期、人口、资源与建筑实例，并提供v1到v2快照迁移和完整校验。
extends RefCounted

# 状态模块：数值均为待平衡参数，资源以完整单位保存。
const DAY_TICKS: int = 120
const Catalog = preload("res://scripts/building_catalog.gd")
const Placement = preload("res://scripts/placement_validator.gd")
var tick: int = 0
var subsecond: float = 0.0
var last_settled_day: int = 0
var population: int = 30
var resources: Dictionary = {"food": 180, "gold": 300, "wood": 120, "stone": 80}
var speed: int = 1
var paused: bool = true
var last_bill: String = "尚未日结；当前仅有居民消耗和基础税收"

# 建筑模块：初始领主厅免费存在，实例ID不复用，回执只记录成功命令。
var buildings: Array = [{"id": "building_000001", "def_id": "b_hall", "cell": [6, 6], "level": 1, "state": "ready", "work_done": 0, "work_required": 0}]
var next_building_id: int = 2
var applied_commands: Dictionary = {}


# 日期模块：第0至119秒属于第1日，完成120秒才进入第2日。
func current_day() -> int:
	return int(tick / float(DAY_TICKS)) + 1


# 日结模块：每个完成的日期仅结算一次，粮食不足时不出现负库存。
func settle_days() -> void:
	while last_settled_day < current_day() - 1:
		var needed: int = ceili(population * 0.5)
		var consumed: int = mini(needed, int(resources["food"]))
		var tax: int = roundi(population * 0.8 * (50.0 / 60.0))
		resources["food"] -= consumed
		resources["gold"] += tax
		last_settled_day += 1
		last_bill = "第%d日日结：粮食 -%d，税收 +%d" % [last_settled_day, consumed, tax]
		if consumed < needed:
			last_bill += "；缺粮 %d（本阶段仅提示）" % (needed - consumed)


# 快照模块：只导出基础数据，不保存节点、数据库连接或脚本引用。
func snapshot() -> Dictionary:
	return {"version": 3, "tick": tick, "subsecond": subsecond, "last_settled_day": last_settled_day, "population": population, "resources": resources.duplicate(), "speed": speed, "paused": paused, "last_bill": last_bill, "buildings": buildings.duplicate(true), "next_building_id": next_building_id, "applied_commands": applied_commands.duplicate(true)}


# 载入模块：在临时对象中完整校验，失败返回空值，不改变当前世界。
static func from_snapshot(data: Variant) -> RefCounted:
	if not data is Dictionary:
		return null
	for key: String in ["version", "tick", "last_settled_day", "population", "speed"]:
		if not _valid_integer(data.get(key), 0, 120000000):
			return null
	if int(data["version"]) not in [1, 2, 3] or int(data["speed"]) not in [1, 2, 4] or data["population"] != 30:
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
	for key: String in ["food", "gold", "wood", "stone"]:
		state.resources[key] = int(data["resources"][key])
	state.speed = int(data["speed"])
	state.paused = data["paused"]
	state.last_bill = data["last_bill"]
	# 迁移模块：旧战略档没有建筑，保留经济时间并补初始领主厅，不立即覆写磁盘。
	if int(data["version"]) == 1:
		return state
	if not state._restore_buildings(data):
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
		if raw["def_id"] == "b_hall":
			hall_count += 1
			if id != "building_000001" or anchor != Vector2i(6, 6):
				return false
		# 施工迁移模块：旧v2的即时建筑保留完工状态，新v3严格检查状态与进度一致。
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
		var record: Dictionary = {"id": id, "def_id": raw["def_id"], "cell": [anchor.x, anchor.y], "level": 1, "state": raw["state"], "work_done": done, "work_required": required}
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


# 施工推进模块：单支抽象施工队按实例创建顺序工作，每个战略秒只投入一份工作。
func advance_construction() -> void:
	for building: Dictionary in buildings:
		if building["state"] == "constructing":
			building["work_done"] = mini(int(building["work_done"]) + 1, int(building["work_required"]))
			if building["work_done"] == building["work_required"]:
				building["state"] = "ready"
			return
