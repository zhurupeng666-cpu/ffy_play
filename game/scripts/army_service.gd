## 文件用途：管理基础步兵的招募幂等、军营容量、训练、按时服役开销和军事存档校验。
extends RefCounted
const Morale = preload("res://scripts/army_morale.gd")
const Costs = preload("res://scripts/building_costs.gd")
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const Disband = preload("res://scripts/army_disband_service.gd")
const UNIT = preload("res://data/units/infantry.tres")
const Build = preload("res://scripts/construction_service.gd")
const Inspector = preload("res://scripts/building_inspector.gd")
const DAY_TICKS: int = 120

# 人数模块：训练和现役都计入已征募人数，城镇兵源才占用原城镇劳动力。
static func people(records: Array, town_only: bool = false, ready_only: bool = false) -> int:
	var total: int = 0
	for record: Dictionary in records:
		if (not town_only or record["source"] == "town") and (not ready_only or record["state"] == "ready"):
			total += int(record["count"])
	return total

# 军营统计模块：每座军营允许一批训练，总编额包括训练中与已完成人员。
static func stationed(records: Array, id: String) -> Dictionary:
	var count: int = 0
	var training: bool = false
	for record: Dictionary in records:
		if record["barracks_id"] == id:
			count += int(record["count"])
			training = training or record["state"] == "training"
	return {"count": count, "training": training}

# 操练数量模块：按军营统计留营现役和新兵，扣除侦察、行军或驻外的现役成员。
static func yard_counts(world: RefCounted) -> Dictionary:
	var away_by_troop: Dictionary = {}
	for legion: Dictionary in world.legions:
		var legion_id: String = legion["id"]
		if not March.away(world, legion_id) and not Scout.busy(world, legion_id):
			continue
		for member: Dictionary in legion["members"]:
			var troop_id: String = member["troop_id"]
			away_by_troop[troop_id] = int(away_by_troop.get(troop_id, 0)) + int(member["count"])
	var counts: Dictionary = {}
	for troop: Dictionary in world.troops:
		var id: String = troop["barracks_id"]
		var people: int = int(troop["count"])
		var pair: Vector2i = counts.get(id, Vector2i.ZERO)
		if troop["state"] == "training":
			pair.y += people
		else:
			pair.x += maxi(0, people - int(away_by_troop.get(troop["id"], 0)))
		if pair != Vector2i.ZERO:
			counts[id] = pair
	return counts

# 招募预检模块：军营、容量、兵源和费用全部满足才允许一次性扣费。
static func quote(world: RefCounted, barracks: String) -> Dictionary:
	var building: Dictionary = Inspector.find(world, barracks)
	if building.is_empty() or building["def_id"] != "b_barracks" or building["state"] != "ready":
		return {"ok": false, "reason": "请先选中已完工军营"}
	var used: Dictionary = stationed(world.troops, barracks)
	if used["training"]:
		return {"ok": false, "reason": "该军营已有训练批次，请等待完成"}
	if int(used["count"]) + int(UNIT.batch_size) > int(UNIT.barracks_capacity) or world.troops.size() >= 64 or world.next_troop_id >= 1000000 or world.troops.size() + world.retired_troops.size() >= 512:
		return {"ok": false, "reason": "军营编额或当前原型部队数量已满"}
	if UNIT.use_town_workers and world.idle_workers() < int(UNIT.batch_size):
		return {"ok": false, "reason": "空闲劳动力不足5人，请先释放生产或施工岗位"}
	return Build.check_cost(UNIT.recruit_cost, world.resources)

# 招募模块：稳定命令ID只扣费一次，失败不扣资源、不占人口、不递增实例ID。
static func recruit(world: RefCounted, barracks: String, command: String) -> Dictionary:
	if command.is_empty() or command.length() > 64:
		return {"ok": false, "reason": "招募命令ID无效"}
	if world.recruit_commands.has(command):
		if world.recruit_commands[command]["barracks_id"] != barracks:
			return {"ok": false, "reason": "同一招募命令不能用于另一军营"}
		return {"ok": true, "replayed": true, "troop_id": world.recruit_commands[command]["troop_id"]}
	var check: Dictionary = quote(world, barracks)
	if not check["ok"]:
		return check
	var resources: Dictionary = world.resources.duplicate()
	for key: String in UNIT.recruit_cost:
		resources[key] -= int(UNIT.recruit_cost[key])
	var id: String = "troop_%06d" % world.next_troop_id
	var records: Array = world.troops.duplicate(true)
	var source: String = "town" if UNIT.use_town_workers else "external"
	records.append({"id": id, "unit_id": UNIT.id, "barracks_id": barracks, "source": source, "count": int(UNIT.batch_size), "state": "training", "work_done": 0, "work_required": int(UNIT.train_work), "ration_credit": 0, "wage_credit": 0, "paid_cost": Costs.normalize(UNIT.recruit_cost)})
	var receipts: Dictionary = world.recruit_commands.duplicate(true)
	receipts[command] = {"troop_id": id, "barracks_id": barracks, "unit_id": UNIT.id, "source": source, "count": int(UNIT.batch_size)}
	world.resources = resources
	world.troops = records
	world.recruit_commands = receipts
	world.next_troop_id += 1
	return {"ok": true, "replayed": false, "troop_id": id}

# 时间模块：每战略秒训练一份工作，训练及现役均按实际服役时间累计军粮军饷。
static func advance(world: RefCounted) -> void:
	for record: Dictionary in world.troops:
		record["ration_credit"] += int(record["count"]) * int(UNIT.food_per_day)
		record["wage_credit"] += int(record["count"]) * int(UNIT.wage_per_day)
		if record["state"] == "training":
			record["work_done"] += 1
			if record["work_done"] == record["work_required"]:
				record["state"] = "ready"

# 开销账单模块：居民先领粮，军队再消耗额外补给；税收入库后再支付军饷，不产生负库存。
static func calculate_bill(day: int, food: int, gold: int, needed_food: int, needed_wage: int) -> Dictionary:
	var used: int = mini(food, needed_food)
	var paid: int = mini(gold, needed_wage)
	return {"day": day, "food_needed": needed_food, "food_used": used, "food_shortage": needed_food - used, "wage_needed": needed_wage, "wage_paid": paid, "wage_shortage": needed_wage - paid, "food_before": food, "food_after": food - used, "gold_before": gold, "gold_after": gold - paid}

# 日结模块：整份开销兑付一次，零头跨日保留，并用实付账单结算士气。
static func settle(world: RefCounted) -> void:
	var retired_food: int = int(int(world.retired_army_cost["ration_credit"]) / float(DAY_TICKS))
	var retired_wage: int = int(int(world.retired_army_cost["wage_credit"]) / float(DAY_TICKS))
	world.retired_army_cost["ration_credit"] = int(world.retired_army_cost["ration_credit"]) % DAY_TICKS
	world.retired_army_cost["wage_credit"] = int(world.retired_army_cost["wage_credit"]) % DAY_TICKS
	world.retired_army_cost["ration_settled"] += retired_food
	world.retired_army_cost["wage_settled"] += retired_wage
	var food: int = retired_food
	var wage: int = retired_wage
	for record: Dictionary in world.troops:
		food += int(int(record["ration_credit"]) / float(DAY_TICKS))
		wage += int(int(record["wage_credit"]) / float(DAY_TICKS))
		record["ration_credit"] = int(record["ration_credit"]) % DAY_TICKS
		record["wage_credit"] = int(record["wage_credit"]) % DAY_TICKS
	world.last_army_ledger = calculate_bill(world.last_settled_day + 1, int(world.resources["food"]), int(world.resources["gold"]), food, wage)
	world.resources["food"] = world.last_army_ledger["food_after"]
	world.resources["gold"] = world.last_army_ledger["gold_after"]
	Morale.settle(world, food > retired_food or wage > retired_wage)

# 数值模块：只接受有限非负整数，防止坏档的小数、空值或溢出。
static func _integer(value: Variant, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= maximum and float(value) == floor(float(value))

# 账单校验模块：军队账单与同日居民领粮和税收入库的顺序必须一致。
static func restore_bill(raw: Variant, world: RefCounted) -> Variant:
	if not raw is Dictionary:
		return null
	if raw.is_empty():
		return {}
	if raw.size() != 11 or world.last_food_ledger.is_empty() or world.last_civic_ledger.is_empty():
		return null
	for key: String in ["day", "food_needed", "food_used", "food_shortage", "wage_needed", "wage_paid", "wage_shortage", "food_before", "food_after", "gold_before", "gold_after"]:
		if not _integer(raw.get(key), 1000000000):
			return null
	if raw["day"] != world.last_settled_day or world.last_settled_day < 1 or raw["food_before"] != world.last_food_ledger["closing"] or raw["gold_before"] != world.last_civic_ledger["gold_after"]:
		return null
	var expected: Dictionary = calculate_bill(int(raw["day"]), int(raw["food_before"]), int(raw["gold_before"]), int(raw["food_needed"]), int(raw["wage_needed"]))
	for key: String in expected:
		if int(raw[key]) != int(expected[key]):
			return null
	return expected

# 存档模块：临时校验全部批次、军营引用、编额和回执后才替换新世界军队数据。
static func restore_world(world: RefCounted, data: Dictionary) -> bool:
	if not data.get("troops") is Array or data["troops"].size() > 64 or not data.get("recruit_commands") is Dictionary or data["recruit_commands"].size() != data["troops"].size() + (data.get("retired_troops", []).size() if int(data["version"]) >= 11 and data.get("retired_troops") is Array else 0) or not _integer(data.get("next_troop_id"), 1000000) or data["next_troop_id"] < 1:
		return false
	var retired_raw: Array = []
	if int(data["version"]) >= 11:
		if not data.get("retired_troops") is Array or data["retired_troops"].size() + data["troops"].size() > 512:
			return false
		retired_raw = data["retired_troops"]
	var records: Array = []
	var archives: Array = []
	var by_id: Dictionary = {}
	var all_records: Array = data["troops"] + retired_raw
	for index: int in range(all_records.size()):
		var raw: Variant = all_records[index]
		var retired: bool = index >= data["troops"].size()
		if not raw is Dictionary or not raw.get("id") is String or raw.get("unit_id") != UNIT.id or raw.get("source") not in ["town", "external"] or raw.get("state") not in ["training", "ready"] or not raw.get("barracks_id") is String:
			return false
		if raw["source"] != ("town" if UNIT.use_town_workers else "external"):
			return false
		var suffix: String = str(raw["id"]).trim_prefix("troop_")
		if not suffix.is_valid_int() or int(suffix) < 1 or int(suffix) >= int(data["next_troop_id"]) or raw["id"] != "troop_%06d" % int(suffix) or by_id.has(raw["id"]):
			return false
		var barracks: Dictionary = Inspector.find(world, raw["barracks_id"])
		if retired and barracks.is_empty():
			for historical: Dictionary in world.retired_buildings:
				if historical["id"] == raw["barracks_id"]:
					barracks = historical
		if barracks.is_empty() or barracks["def_id"] != "b_barracks" or barracks["state"] != "ready":
			return false
		if not _integer(raw.get("count"), int(UNIT.batch_size)) or raw["count"] != UNIT.batch_size or not _integer(raw.get("work_required"), 100000) or raw["work_required"] < 1 or not _integer(raw.get("work_done"), int(raw["work_required"])):
			return false
		if (raw["state"] == "ready") != (raw["work_done"] == raw["work_required"]):
			return false
		for field: String in ["ration_credit", "wage_credit"]:
			var rate: int = int(UNIT.food_per_day if field == "ration_credit" else UNIT.wage_per_day)
			if not _integer(raw.get(field), int(UNIT.batch_size) * rate * DAY_TICKS + DAY_TICKS - 1):
				return false
		var used: Dictionary = stationed(records, raw["barracks_id"])
		if not retired and (int(used["count"]) + int(raw["count"]) > int(UNIT.barracks_capacity) or (used["training"] and raw["state"] == "training")):
			return false
		var paid: Dictionary = Costs.normalize({"wood": 5, "gold": 50})
		if int(data["version"]) >= 11:
			if not Costs.valid(raw.get("paid_cost")):
				return false
			paid = Costs.normalize(raw["paid_cost"])
		var record: Dictionary = {"id": raw["id"], "unit_id": raw["unit_id"], "barracks_id": raw["barracks_id"], "source": raw["source"], "count": int(raw["count"]), "state": raw["state"], "work_done": int(raw["work_done"]), "work_required": int(raw["work_required"]), "ration_credit": int(raw["ration_credit"]), "wage_credit": int(raw["wage_credit"]), "paid_cost": paid}
		if retired:
			archives.append(record)
		else:
			records.append(record)
		by_id[record["id"]] = record
	var receipts: Dictionary = {}
	var seen: Dictionary = {}
	for command: Variant in data["recruit_commands"]:
		if not command is String or command.is_empty() or command.length() > 64 or not data["recruit_commands"][command] is Dictionary:
			return false
		var receipt: Dictionary = data["recruit_commands"][command]
		if not receipt.get("troop_id") is String or not by_id.has(receipt["troop_id"]) or seen.has(receipt["troop_id"]):
			return false
		var record: Dictionary = by_id[receipt["troop_id"]]
		for key: String in ["barracks_id", "unit_id", "source", "count"]:
			if receipt.get(key) != record[key]:
				return false
		seen[receipt["troop_id"]] = true
		receipts[command] = {"troop_id": receipt["troop_id"], "barracks_id": record["barracks_id"], "unit_id": record["unit_id"], "source": record["source"], "count": record["count"]}
	var ledger: Variant = restore_bill(data.get("last_army_ledger"), world)
	if ledger == null:
		return false
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var retirement: Dictionary = {"commands": {}, "pending": {"ration_credit": 0, "wage_credit": 0, "ration_settled": 0, "wage_settled": 0}}
	if int(data["version"]) >= 11:
		var restored: Variant = Disband.restore(data.get("disband_commands"), data.get("retired_army_cost"), archives, world.tick)
		if restored == null:
			return false
		retirement = restored
	world.troops = records
	world.retired_troops = archives
	world.disband_commands = retirement["commands"]
	world.retired_army_cost = retirement["pending"]
	world.recruit_commands = receipts
	world.next_troop_id = int(data["next_troop_id"])
	world.last_army_ledger = ledger
	return world.idle_workers() >= 0
