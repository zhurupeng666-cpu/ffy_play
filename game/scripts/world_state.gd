## 文件用途：保存世界日期、人口、资源与建筑实例，并提供旧档迁移与新版户籍校验。
extends RefCounted

# 状态模块：数值均为待平衡参数，资源以完整单位保存。
const DAY_TICKS: int = 120
const MAX_BUILDERS: int = 2
const Terrain = preload("res://scripts/town_terrain.gd")
const Grid = preload("res://scripts/isometric_grid.gd")
const Siege = preload("res://scripts/fort_siege.gd")
const Battle = preload("res://scripts/woods_battle.gd")
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const Legions = preload("res://scripts/legion_service.gd")
const Army = preload("res://scripts/army_service.gd")
const Civic = preload("res://scripts/civic_economy.gd")
const Costs = preload("res://scripts/building_costs.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const MaterialLedger = preload("res://scripts/material_ledger.gd")
const FoodLedger = preload("res://scripts/food_ledger.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Population = preload("res://scripts/population_service.gd")
const DistrictMarket = preload("res://scripts/district_market.gd")
const Capital = preload("res://scripts/capital_layout.gd")
const HouseEconomy = preload("res://scripts/household_economy.gd")
const Estate = preload("res://scripts/estate_labor.gd")
var tick: int = 0
var subsecond: float = 0.0
var last_settled_day: int = 0
var population: int = Population.START_POPULATION
var household_economy: Dictionary = {}
var capital_layout: bool = false
var households: Array = Population.initial(Population.START_POPULATION, Population.START_CHILDREN, 1)
var population_report: Dictionary = {}
# 领主劳役：建筑工人数包含双方，单独记录领主人手以保留原生产公式。
var estate_workers: int = 0
var estate_builders: int = 0
var estate_posts: Dictionary = {}
var estate_food_remainder: int = 0
var estate_food_report: Dictionary = {}

# 劳动力模块：居民分为可就业与被抚养人口，施工岗位最多两人，其余保持空闲。
var dependents: int = Population.START_CHILDREN
var builders: int = MAX_BUILDERS
var labor_credit: int = 0
var resources: Dictionary = {"food": 180, "gold": 300, "wood": 120, "stone": 80}
var speed: int = 1
var paused: bool = true
var tax_policy: String = "standard"
var satisfaction: int = int(Civic.SETTINGS.initial_satisfaction)
var last_civic_ledger: Dictionary = {}
var troops: Array = []
var legions: Array = []
var legion_create_commands: Dictionary = {}
var next_legion_id: int = 1
# 区域模块：空字典代表未侦察，任务记录通过到达时刻派生发现状态。
var woods_scout: Dictionary = {}
# 行军模块：记录正在途中或驻扎林地的军团，边境镇为默认驻地。
var legion_trips: Dictionary = {}
# 遭遇快照：保存出战条件，由战略时间推算当前战况和林地归属。
var woods_battle: Dictionary = {}
# 攻城快照：记录旧堡的开战条件，用于恢复战况与控制权。
var fort_siege: Dictionary = {}
var retired_troops: Array = []
var disband_commands: Dictionary = {}
var retired_army_cost: Dictionary = {"ration_credit": 0, "wage_credit": 0, "ration_settled": 0, "wage_settled": 0}
var recruit_commands: Dictionary = {}
var next_troop_id: int = 1
var last_army_ledger: Dictionary = {}
# 士气模块：全军共用一份士气，上次日结未适用时没有结算前数值。
var army_morale: int = Army.Morale.INITIAL
var last_morale_before: Variant = null
var last_material_ledger: Dictionary = {}
var last_food_ledger: Dictionary = {}
var last_bill: String = "尚未日结；生产建筑完工并分配工人后可产粮"

# 建筑模块：初始领主厅免费存在，实例ID不复用，回执只记录成功命令。
var buildings: Array = [{"id": "building_000001", "def_id": "b_hall", "cell": [6, 6], "level": 1, "state": "ready", "work_done": 0, "work_required": 0, "workers": 0, "food_credit": 0, "material_credit": 0, "paid_cost": {"wood": 0, "stone": 0, "gold": 0}}]
var next_building_id: int = 2
var applied_commands: Dictionary = {}
var retired_buildings: Array = []
var removal_commands: Dictionary = {}


# 卸任模块：军团撤销后解除对应武将，保留户籍与家产。
func release_commander(id: String) -> void:
	if household_economy.get("legion", "") == id:
		household_economy["general"] = -1
		household_economy["legion"] = ""


# 指挥模块：只有所任命军团获得开战指挥加成，公共士气不受影响。
func effective_battle_morale(legion: String) -> int:
	return mini(Army.Morale.MAXIMUM, army_morale + HouseEconomy.commander_bonus(self, legion))


# 日期模块：第0至119秒属于第1日，完成120秒才进入第2日。
func current_day() -> int:
	return int(tick / float(DAY_TICKS)) + 1


# 日结模块：固定先收获再消费，记录可重算的账单，同一天不重复结算。
func settle_days() -> void:
	while last_settled_day < current_day() - 1:
		var private_bill: Dictionary = HouseEconomy.settle(self) if not household_economy.is_empty() else {}
		var sources: Dictionary = collect_food()
		if not private_bill.is_empty():
			sources["tax_grain"] = private_bill["tax_grain"]
			sources["fish_levy"] = private_bill["fish_levy"]
		last_food_ledger = FoodLedger.calculate(last_settled_day + 1, int(resources["food"]), food_capacity(), sources, population, private_bill.get("relief", -1))
		resources["food"] = last_food_ledger["closing"]
		var woods_wood: int = 0
		if Battle.report(self, last_settled_day * DAY_TICKS)["status"] == "victory":
			woods_wood = Battle.LAYOUT.woods_wood_per_day
		last_material_ledger = MaterialLedger.calculate(last_settled_day + 1, resources, collect_materials(), woods_wood)
		for key: String in MaterialLedger.KEYS:
			resources[key] = last_material_ledger[key]["closing"]
		var fort_income: int = 0
		if Siege.report(self, last_settled_day * DAY_TICKS)["status"] == "victory":
			fort_income = Siege.LAYOUT.fort_gold_per_day
		last_civic_ledger = Civic.calculate(last_settled_day + 1, tax_policy, satisfaction, population, int(last_food_ledger["shortage"]), int(resources["gold"]), fort_income, private_bill.get("shop_tax", 0))
		satisfaction = last_civic_ledger["after"]
		var tax: int = int(last_civic_ledger["tax_stored"])
		resources["gold"] = last_civic_ledger["gold_after"]
		Army.settle(self)
		last_settled_day += 1
		Estate.settle(self)
		Population.settle(self)
		if not household_economy.is_empty():
			HouseEconomy.enroll(self)
		DistrictMarket.settle(self)
		last_bill = "第%d日日结：产粮 +%d（入库%d，溢出%d），消耗 -%d，净变%+d，税收 +%d" % [last_settled_day, last_food_ledger["produced"], last_food_ledger["stored"], last_food_ledger["overflow"], last_food_ledger["consumed"], last_food_ledger["net"], tax]
		if not troops.is_empty() or int(last_army_ledger["food_needed"]) > 0 or int(last_army_ledger["wage_needed"]) > 0:
			last_bill += "；军粮-%d，军饷-%d" % [last_army_ledger["food_used"], last_army_ledger["wage_paid"]]
		if last_civic_ledger.has("fort_gold"):
			last_bill += "；旧堡金币+%d" % last_civic_ledger["fort_gold"]["stored"]
		if last_food_ledger["shortage"] > 0:
			last_bill += "；缺粮 %d（影响满意度）" % last_food_ledger["shortage"]

# 快照模块：只导出基础数据，不保存节点、数据库连接或脚本引用。
func snapshot() -> Dictionary:
	var data: Dictionary = {"version": 26, "households": households.duplicate(true), "population_report": population_report.duplicate(), "estate": {"workers": estate_workers, "builders": estate_builders, "posts": estate_posts.duplicate(), "food_remainder": estate_food_remainder, "food_report": estate_food_report.duplicate()}, "fort_siege": fort_siege.duplicate(), "woods_battle": woods_battle.duplicate(), "legion_trips": legion_trips.duplicate(true), "woods_scout": woods_scout.duplicate(), "tick": tick, "subsecond": subsecond, "last_settled_day": last_settled_day, "population": population, "dependents": dependents, "builders": builders, "labor_credit": labor_credit, "resources": resources.duplicate(), "speed": speed, "paused": paused, "tax_policy": tax_policy, "satisfaction": satisfaction, "last_civic_ledger": last_civic_ledger.duplicate(true), "troops": troops.duplicate(true), "legions": legions.duplicate(true), "legion_create_commands": legion_create_commands.duplicate(), "next_legion_id": next_legion_id, "retired_troops": retired_troops.duplicate(true), "disband_commands": disband_commands.duplicate(true), "retired_army_cost": retired_army_cost.duplicate(), "recruit_commands": recruit_commands.duplicate(true), "next_troop_id": next_troop_id, "last_army_ledger": last_army_ledger.duplicate(true), "army_morale": army_morale, "last_morale_before": last_morale_before, "last_bill": last_bill, "last_food_ledger": last_food_ledger.duplicate(true), "last_material_ledger": last_material_ledger.duplicate(true), "buildings": buildings.duplicate(true), "next_building_id": next_building_id, "applied_commands": applied_commands.duplicate(true), "retired_buildings": retired_buildings.duplicate(true), "removal_commands": removal_commands.duplicate(true)}
	if not household_economy.is_empty():
		data["version"] = 27
		data["household_economy"] = household_economy.duplicate(true)
	if capital_layout:
		data["version"] = 28
		data["capital_layout"] = true
	return data


# 载入模块：在临时对象中完整校验，失败返回空值，不改变当前世界。
static func from_snapshot(data: Variant) -> RefCounted:
	if not data is Dictionary:
		return null
	for key: String in ["version", "tick", "last_settled_day", "population", "speed"]:
		if not _valid_integer(data.get(key), 0, 120000000):
			return null
	if int(data["version"]) not in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28] or int(data["speed"]) not in [1, 2, 4]:
		return null
	var version: int = int(data["version"])
	if not _valid_integer(data["population"], Population.START_POPULATION, Population.MAX_POPULATION) or (version < 25 and data["population"] != Population.START_POPULATION):
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
		if not _valid_integer(data.get("dependents"), 0, state.population) or not _valid_integer(data.get("builders"), 0, MAX_BUILDERS) or not _valid_integer(data.get("labor_credit"), 0, 1):
			return null
		state.dependents = int(data["dependents"])
		state.builders = int(data["builders"])
		state.labor_credit = int(data["labor_credit"])
		if version < 25 and state.builders > state.population - state.dependents:
			return null
	for key: String in ["food", "gold", "wood", "stone"]:
		state.resources[key] = int(data["resources"][key])
	state.speed = int(data["speed"])
	state.paused = data["paused"]
	state.last_bill = data["last_bill"]
	# 人口迁移模块：旧档保留原总数与岗位，儿童从当前日期开始获得成年计划。
	if version < 25:
		state.households = Population.initial(state.population, state.dependents, state.current_day())
	elif not Population.restore(state, data.get("households"), data.get("population_report")):
		return null
	# 收支结算使用新增居民入住之前的人数，避免新档在增长当天无法读回。
	var settled_population: int = state.population - int(state.population_report.get("joined", 0)) - int(state.population_report.get("born", 0))
	# 历史迁移模块：旧档不虚构粮食收支，新版账单完整校验后才恢复。
	if int(data["version"]) >= 6:
		if not FoodLedger.valid(data.get("last_food_ledger"), state.last_settled_day, settled_population):
			return null
		var saved_ledger: Dictionary = data["last_food_ledger"]
		if not saved_ledger.is_empty():
			state.last_food_ledger = FoodLedger.calculate(int(saved_ledger["day"]), int(saved_ledger["opening"]), int(saved_ledger["capacity"]), saved_ledger["by_source"], settled_population, int(saved_ledger.get("relief_needed", -1)))
	# 材料账单迁移模块：旧档不补发材料，也不编造历史生产。
	if int(data["version"]) >= 7:
		if not MaterialLedger.valid(data.get("last_material_ledger"), state.last_settled_day):
			return null
		state.last_material_ledger = MaterialLedger.restore(data["last_material_ledger"])
	# 政务迁移模块：旧档默认标准税与满意度50，不追溯计算过去的民意和税收。
	if int(data["version"]) >= 9:
		if not data.get("tax_policy") is String or data["tax_policy"] not in Civic.POLICIES or not _valid_integer(data.get("satisfaction"), 0, int(Civic.SETTINGS.satisfaction_limit)):
			return null
		state.tax_policy = data["tax_policy"]
		state.satisfaction = int(data["satisfaction"])
		if not Civic.valid(data.get("last_civic_ledger"), state.last_settled_day, settled_population, state.satisfaction, state.last_food_ledger):
			return null
		state.last_civic_ledger = Civic.restore(data["last_civic_ledger"], settled_population)
	# 迁移模块：旧战略档没有建筑，保留经济时间并补初始领主厅，不立即覆写磁盘。
	if int(data["version"]) == 1:
		return state
	if not state._restore_buildings(data):
		return null
	if int(data["version"]) < 24 and not state._relocate_legacy_sites():
		return null
	if int(data["version"]) < 23:
		state._expand_legacy_yards(int(data["version"]))
	if version >= 25 and not Estate.restore(state, data.get("estate")):
		return null
	if int(data["version"]) >= 10 and not Army.restore_world(state, data):
		return null
	if int(data["version"]) >= 12 and not Legions.restore_world(state, data):
		return null
	# 士气迁移模块：旧档从初始士气开始，已记录的新档涨跌须能用当日军需复算。
	if int(data["version"]) >= 13:
		if not data.has("last_morale_before") or not _valid_integer(data.get("army_morale"), 0, Army.Morale.MAXIMUM):
			return null
		var before: Variant = data["last_morale_before"]
		state.army_morale = int(data["army_morale"])
		if before != null:
			var bill: Dictionary = state.last_army_ledger
			if not _valid_integer(before, 0, Army.Morale.MAXIMUM) or bill.is_empty():
				return null
			if int(bill["food_needed"]) + int(bill["wage_needed"]) == 0 or Army.Morale.after(int(before), bill) != state.army_morale:
				return null
			state.last_morale_before = int(before)
	# 区域迁移模块：旧档从尚未侦察开始，新档校验任务时间和军团归属。
	if int(data["version"]) >= 14 and not Scout.restore(state, data.get("woods_scout")):
		return null
	# 行军迁移模块：旧档军团从边境镇出发，新档恢复途中与驻地。
	if int(data["version"]) >= 15 and not March.restore(state, data.get("legion_trips"), int(data["version"]) < 18):
		return null
	# 战斗迁移模块：旧档默认未交战，恢复要等军团、侦察与驻地先完成。
	if int(data["version"]) >= 16 and not Battle.restore(state, data.get("woods_battle")):
		return null
	if not March.valid_fort_trips(state):
		return null
	if int(data["version"]) >= 19 and not Siege.restore(state, data.get("fort_siege")):
		return null
	# 旧堡税账校验：旧堡须在结算日开始时已归己方。
	if state.last_civic_ledger.has("fort_gold"):
		var opening_tick: int = (state.last_settled_day - 1) * DAY_TICKS
		if int(data["version"]) < 20 or Siege.report(state, opening_tick)["status"] != "victory":
			return null
	# 来源校验：有林地上缴的账单必须对应一个从日初就由己方控制的结算日。
	if state.last_material_ledger.has("woods_wood"):
		var opening_tick: int = (state.last_settled_day - 1) * DAY_TICKS
		if int(data["version"]) < 17 or Battle.report(state, opening_tick)["status"] != "victory":
			return null
	if version >= 28:
		if data.get("capital_layout") != true:
			return null
		state.capital_layout = true
	if version >= 27 and not HouseEconomy.restore(state, data.get("household_economy")):
		return null
	if state.idle_workers() < 0 or state.population > state.housing_capacity():
		return null
	return state


# 数值模块：拒绝空值、小数、负数、无穷值和超出边界的数据。
static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floor(float(value))


# 占用模块：从真实实例推导占用，不将冗余格表另行存档。
func occupied_cells() -> Dictionary:
	var occupied: Dictionary = Capital.occupation().duplicate() if capital_layout else {}
	for record: Dictionary in buildings:
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		for cell: Vector2i in Placement.footprint_cells(anchor, Catalog.footprint(record)):
			occupied[cell] = record["id"]
	return occupied


# 建筑载入模块：校验定义、坐标、重叠、实例ID、计数器与回执引用后才整体替换。
func _restore_buildings(data: Dictionary) -> bool:
	if not data.get("buildings") is Array or data["buildings"].is_empty() or data["buildings"].size() > 256:
		return false
	if not _valid_integer(data.get("next_building_id"), 2, 1000000) or not data.get("applied_commands") is Dictionary:
		return false
	var retired_raw: Array = []
	if int(data["version"]) >= 8:
		if not data.get("retired_buildings") is Array or data["retired_buildings"].size() > 2048 or not data.get("removal_commands") is Dictionary:
			return false
		retired_raw = data["retired_buildings"]
	var records: Array = []
	var archives: Array = []
	var by_id: Dictionary = {}
	var occupied: Dictionary = Capital.occupation().duplicate() if int(data["version"]) >= 28 else {}
	var hall_count: int = 0
	var all_records: Array = data["buildings"] + retired_raw
	for index: int in range(all_records.size()):
		var raw: Variant = all_records[index]
		var retired: bool = index >= data["buildings"].size()
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
		if not _valid_cell(raw["cell"], int(data["version"])) or not _valid_integer(raw.get("level"), 1, 1) or raw.get("state") not in ["ready", "constructing"]:
			return false
		var anchor: Vector2i = Vector2i(int(raw["cell"][0]), int(raw["cell"][1]))
		if raw.has("large") and (not raw["large"] is bool or (raw["large"] and not Catalog.LARGE_SIZES.has(raw["def_id"]))):
			return false
		if raw.has("legacy_large") and (raw["legacy_large"] != true or not raw.get("large", false)):
			return false
		var prior_large: bool = int(data["version"]) == 22
		var check: Dictionary = Placement.check(anchor, Catalog.footprint(raw, prior_large), {} if retired else occupied)
		if not check["ok"]:
			return false
		# 地形存档模块：先以原版地形校验旧档，新档的退役记录按历史坐标保留。
		var legacy_terrain: bool = int(data["version"]) < 24
		var terrain_required: bool = raw.get("large", false) or definition.get("requires_water") or not str(definition.get("required_deposit")).is_empty()
		if ((legacy_terrain and terrain_required) or (not legacy_terrain and not retired)) and not Terrain.check(check["cells"], definition.get("requires_water"), definition.get("required_deposit"), legacy_terrain)["ok"]:
			return false
		if not legacy_terrain and not retired and raw["def_id"] == "b_fishery" and not raw.get("large", false):
			return false
		if raw["def_id"] == "b_hall":
			hall_count += 1
			if retired or id != "building_000001" or anchor != Vector2i(6, 6):
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
		# 材料进度模块：新版保存整数信用，非材料建筑和工地不允许持有材料产出。
		var material_credit: int = 0
		var material_rate: int = int(definition.get("material_per_worker_day"))
		if int(data["version"]) >= 7:
			if not _valid_integer(raw.get("material_credit"), 0, int(definition.get("worker_slots")) * material_rate * DAY_TICKS + DAY_TICKS - 1):
				return false
			material_credit = int(raw["material_credit"])
			if (raw["state"] != "ready" or material_rate == 0) and material_credit != 0:
				return false
		if int(definition.get("food_per_worker_day")) == 0 and credit != 0:
			return false
		var paid: Dictionary = Costs.normalize(Costs.LEGACY.get(raw["def_id"], {}))
		if int(data["version"]) >= 8:
			if not Costs.valid(raw.get("paid_cost")):
				return false
			paid = Costs.normalize(raw["paid_cost"])
		if raw["def_id"] == "b_hall" and paid != Costs.normalize({}):
			return false
		var record: Dictionary = {"id": id, "def_id": raw["def_id"], "cell": [anchor.x, anchor.y], "level": 1, "state": raw["state"], "work_done": done, "work_required": required, "workers": workers, "food_credit": credit, "material_credit": material_credit, "paid_cost": paid}
		if raw.has("large"):
			record["large"] = raw["large"]
		if raw.get("legacy_large", false) or (prior_large and raw.get("large", false)):
			record["legacy_large"] = true
		if retired:
			archives.append(record)
		else:
			records.append(record)
		by_id[id] = record
		for cell: Vector2i in check["cells"]:
			if not retired:
				occupied[cell] = id
	if hall_count != 1 or data["applied_commands"].size() != all_records.size() - 1:
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
		if not raw.get("cell") is Array or raw["cell"].size() != 2 or not _valid_cell(raw["cell"], int(data["version"])):
			return false
		if [int(raw["cell"][0]), int(raw["cell"][1])] != record["cell"]:
			return false
		if raw.get("large", false) != record.get("large", false):
			return false
		receipts[command] = {"def_id": record["def_id"], "cell": record["cell"].duplicate(), "building_id": record["id"]}
		if record.has("large"):
			receipts[command]["large"] = record["large"]
		receipted[record["id"]] = true
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	if int(data["version"]) >= 8:
		var restored_removals: Variant = preload("res://scripts/removal_service.gd").restore_history(data["removal_commands"], archives, int(data["tick"]))
		if restored_removals == null:
			return false
		removal_commands = restored_removals
	retired_buildings = archives
	buildings = records
	next_building_id = int(data["next_building_id"])
	applied_commands = receipts
	return true


# 施工推进模块：每名工人每战略秒投入半份工作，整数余数避免浮点误差并支持中途存档。
func advance_construction() -> void:
	for building: Dictionary in buildings:
		if building["state"] == "constructing" and not HouseEconomy.owns(self, building["id"]):
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
	if count < estate_builders or count > MAX_BUILDERS or count - builders > idle_workers():
		return false
	builders = count
	return true


# 劳动力总数：被抚养居民仍计入人口，岗位由可就业居民承担。
func workforce_capacity() -> int:
	return population - dependents


# 统计模块：施工岗位计入可就业人口，保持人口与岗位守恒。
func idle_workers() -> int:
	return workforce_capacity() - (builders - estate_builders) - (production_workers() - Estate.production_count(self)) - Army.people(troops, true)


# 领主空闲人数：只计独立编额，不向居民或军队岗位借用。
func estate_idle() -> int:
	return estate_workers - estate_builders - Estate.production_count(self)


# 领主施工岗位：从领主池调人，同时遵守共用施工队上限。
func assign_estate_builders(delta: int) -> bool:
	if estate_builders + delta < 0 or builders + delta > MAX_BUILDERS or delta > estate_idle():
		return false
	estate_builders += delta
	builders += delta
	return true


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
	if HouseEconomy.owns(self, building_id):
		return false
	for building: Dictionary in buildings:
		if building["id"] == building_id:
			var definition: Resource = Catalog.find(building["def_id"])
			if building["state"] != "ready" or int(definition.get("worker_slots")) == 0 or count < int(estate_posts.get(building_id, 0)) or count > int(definition.get("worker_slots")) or count - int(building["workers"]) > idle_workers():
				return false
			building["workers"] = count
			return true
	return false


# 领主生产岗位：指定独立人手增减，仍用原建筑岗位容量与产量公式。
func assign_estate_producers(building_id: String, delta: int) -> bool:
	if HouseEconomy.owns(self, building_id):
		return false
	var assigned: int = int(estate_posts.get(building_id, 0)) + delta
	if assigned < 0 or delta > estate_idle():
		return false
	for building: Dictionary in buildings:
		if building["id"] != building_id:
			continue
		var definition: Resource = Catalog.find(building["def_id"])
		var total: int = int(building["workers"]) + delta
		if building["state"] != "ready" or total > int(definition.get("worker_slots")):
			return false
		building["workers"] = total
		if assigned == 0:
			estate_posts.erase(building_id)
		else:
			estate_posts[building_id] = assigned
		return true
	return false


# 工作累计模块：每战略秒按真实在岗人数增加整数信用，调岗不会补发整日产量。
func advance_production() -> void:
	for building: Dictionary in buildings:
		if building["state"] == "ready" and int(building["workers"]) > 0:
			var rate: int = int(Catalog.find(building["def_id"]).get("food_per_worker_day"))
			building["food_credit"] += int(building["workers"]) * rate
			building["material_credit"] += int(building["workers"]) * int(Catalog.find(building["def_id"]).get("material_per_worker_day"))


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


# 地形迁移：只重新安置与新水岸或资源区冲突的活动建筑，渔场扩为标准大小。
func _relocate_legacy_sites() -> bool:
	var occupied: Dictionary = occupied_cells()
	var receipts: Dictionary = {}
	for receipt: Dictionary in applied_commands.values():
		receipts[receipt["building_id"]] = receipt
	for building: Dictionary in buildings:
		var id: String = building["def_id"]
		var anchor := Vector2i(int(building["cell"][0]), int(building["cell"][1]))
		var cells: Array[Vector2i] = Placement.footprint_cells(anchor, Catalog.footprint(building))
		var definition: Resource = Catalog.find(id)
		var fishery: bool = id == "b_fishery"
		if not fishery and Terrain.check(cells, false, definition.get("required_deposit"))["ok"]:
			continue
		for cell: Vector2i in cells:
			occupied.erase(cell)
		var extent: Vector2i = Catalog.LARGE_SIZES[id] if fishery else Catalog.footprint(building)
		definition = definition.duplicate()
		definition.set("footprint", extent)
		var target: Vector2i = _nearest_yard(anchor, definition, occupied)
		if target == Grid.INVALID:
			return false
		building["cell"] = [target.x, target.y]
		var receipt: Dictionary = receipts[building["id"]]
		receipt["cell"] = building["cell"].duplicate()
		if fishery:
			building["large"] = true
			receipt["large"] = true
		for cell: Vector2i in Placement.footprint_cells(target, extent):
			occupied[cell] = building["id"]
	return true


# 旧城扩建模块：稳定 ID 保留，优先原地扩大，受阻时寻找最近的无冲突锚点。
func _expand_legacy_yards(old_version: int) -> void:
	var occupied: Dictionary = occupied_cells()
	var receipts_by_id: Dictionary = {}
	for command: String in applied_commands:
		var receipt: Dictionary = applied_commands[command]
		receipts_by_id[receipt["building_id"]] = receipt
	for building: Dictionary in buildings:
		if building["def_id"] == "b_fishery" or not Catalog.LARGE_SIZES.has(building["def_id"]) or (old_version < 20 and building.has("large")):
			continue
		var origin := Vector2i(int(building["cell"][0]), int(building["cell"][1]))
		var former: Array[Vector2i] = Placement.footprint_cells(origin, Catalog.footprint(building))
		for cell: Vector2i in former:
			occupied.erase(cell)
		var variant: Resource = Catalog.for_construction(building["def_id"], true)
		var anchor: Vector2i = _nearest_yard(origin, variant, occupied)
		if anchor.x < 0:
			for cell: Vector2i in former:
				occupied[cell] = building["id"]
			continue
		building["cell"] = [anchor.x, anchor.y]
		building["large"] = true
		building.erase("legacy_large")
		for cell: Vector2i in Placement.footprint_cells(anchor, Catalog.footprint(building)):
			occupied[cell] = building["id"]
		var receipt: Dictionary = receipts_by_id[building["id"]]
		receipt["cell"] = building["cell"].duplicate()
		receipt["large"] = true


# 寻址模块：按曼哈顿距离扫描，每个位置都使用正常建造的地形与碰撞规则。
func _nearest_yard(origin: Vector2i, definition: Resource, occupied: Dictionary) -> Vector2i:
	var extent: Vector2i = definition.get("footprint")
	for distance: int in range(Grid.SIZE.x + Grid.SIZE.y - 1):
		for offset_y: int in range(-distance, distance + 1):
			var offset_x: int = distance - absi(offset_y)
			for x: int in [offset_x, -offset_x] if offset_x != 0 else [0]:
				var cell: Vector2i = origin + Vector2i(x, offset_y)
				if not Grid.contains(cell) or not Grid.contains(cell + extent - Vector2i.ONE):
					continue
				if _yard_site_clear(cell, extent, occupied, definition.get("requires_water"), definition.get("required_deposit")):
					return cell
	return Grid.INVALID


# 候选模块：在迁移扫描中遇到第一个占用即退出，避免为每个位置创建数百格中间数组。
func _yard_site_clear(anchor: Vector2i, extent: Vector2i, occupied: Dictionary, water: bool, deposit: String) -> bool:
	if water:
		if anchor.y + extent.y < 88 or anchor.y > 141 or Terrain.dock_edge(anchor, extent).is_empty():
			return false
	if not deposit.is_empty():
		var nearby: bool = false
		for district: Dictionary in Terrain.DISTRICTS:
			var bounds: Rect2i = district["bounds"]
			if district["kind"] == deposit and bounds.grow(1).intersects(Rect2i(anchor, extent)):
				nearby = true
				break
		if not nearby:
			return false
	for y: int in range(anchor.y, anchor.y + extent.y):
		for x: int in range(anchor.x, anchor.x + extent.x):
			var cell := Vector2i(x, y)
			if occupied.has(cell) or Terrain.is_water(cell) or not Terrain.deposit_at(cell).is_empty():
				return false
	return deposit.is_empty() or Terrain.check(Placement.footprint_cells(anchor, extent), false, deposit)["ok"]


# 材料收获模块：木材和石材独立兑付整数，零头跨日保留，不影响粮食库存。
func collect_materials() -> Dictionary:
	var outputs: Dictionary = {"wood": 0, "stone": 0}
	for building: Dictionary in buildings:
		var key: String = str(Catalog.find(building["def_id"]).get("material_resource"))
		if outputs.has(key):
			outputs[key] += int(int(building["material_credit"]) / float(DAY_TICKS))
			building["material_credit"] = int(building["material_credit"]) % DAY_TICKS
	return outputs


# 税率命令模块：仅改变下次日结采用的政策，不立即改变金币或满意度。
func set_tax_policy(policy: String) -> bool:
	if policy not in Civic.POLICIES:
		return false
	tax_policy = policy
	return true


# 坐标校验：旧档保持原范围，新档允许在已知区域之外建设。
static func _valid_cell(cell: Array, version: int) -> bool:
	var lower: int = -Grid.WORLD_LIMIT if version >= 26 else 0
	var east: int = Grid.WORLD_LIMIT if version >= 26 else Grid.SIZE.x - 1
	var south: int = Grid.WORLD_LIMIT if version >= 26 else Grid.SIZE.y - 1
	return _valid_integer(cell[0], lower, east) and _valid_integer(cell[1], lower, south)
