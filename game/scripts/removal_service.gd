## 文件用途：原子执行取消施工与拆除，按实付费用退款并保存历史回执，阻止重复退款。
extends RefCounted
const Inspector = preload("res://scripts/building_inspector.gd")
const LIMIT: int = 1000000000

# 退款模块：仅未完成工地按剩余整数工作量退木石，向下取整，不退金币。
static func refundable(building: Dictionary) -> Dictionary:
	var result: Dictionary = {"wood": 0, "stone": 0}
	if building["state"] == "constructing":
		for key: String in result:
			result[key] = floori(int(building["paid_cost"][key]) * (int(building["work_required"]) - int(building["work_done"])) / float(building["work_required"]))
	return result

# 预览模块：读取影响和准确退款，不修改任何世界数据。
static func quote(world: RefCounted, id: String) -> Dictionary:
	var building: Dictionary = Inspector.find(world, id)
	if building.is_empty() or building["def_id"] == "b_hall":
		return {"ok": false, "reason": "未选择可移除建筑；领主厅不能拆除"}
	if building["def_id"] == "b_barracks":
		for troop: Dictionary in world.troops:
			if troop["barracks_id"] == id:
				return {"ok": false, "reason": "军营仍有训练或现役部队，本阶段不能拆除"}
	if world.retired_buildings.size() >= 2048:
		return {"ok": false, "reason": "达到当前原型2048条移除历史上限"}
	var housing: int = world.housing_capacity() - (10 if building["state"] == "ready" and building["def_id"] == "b_house" else 0)
	if housing < world.population:
		return {"ok": false, "reason": "拆除后住房不足，不能拆除此住宅"}
	var refund: Dictionary = refundable(building)
	var overflow: Dictionary = {"wood": 0, "stone": 0}
	for key: String in refund:
		var accepted: int = mini(int(refund[key]), LIMIT - int(world.resources[key]))
		overflow[key] = int(refund[key]) - accepted
		refund[key] = accepted
	var capacity: int = world.food_capacity()
	if building["state"] == "ready":
		capacity -= int(preload("res://scripts/building_catalog.gd").find(building["def_id"]).get("food_capacity"))
	return {"ok": true, "building_id": id, "action": "取消施工" if building["state"] == "constructing" else "拆除建筑", "refund": refund, "overflow": overflow, "workers": int(building["workers"]), "food_credit": int(building["food_credit"]), "material_credit": int(building["material_credit"]), "capacity_after": capacity, "housing_after": housing, "signature": world.snapshot()}

# 执行模块：重做校验后整体替换活动建筑、资源与历史，失败没有副作用。
static func execute(world: RefCounted, id: String, command: String, expected: Dictionary = {}) -> Dictionary:
	if command.is_empty() or command.length() > 64:
		return {"ok": false, "reason": "移除命令ID无效"}
	if world.removal_commands.has(command):
		if world.removal_commands[command]["building_id"] != id:
			return {"ok": false, "reason": "同一命令不能移除另一建筑"}
		return {"ok": true, "replayed": true, "refund": world.removal_commands[command]["refund"].duplicate()}
	var offer: Dictionary = quote(world, id)
	if not offer["ok"]:
		return offer
	if not expected.is_empty() and expected != offer["signature"]:
		return {"ok": false, "reason": "世界状态已变化，请重新查看移除影响"}
	var resources: Dictionary = world.resources.duplicate()
	for key: String in offer["refund"]:
		resources[key] += int(offer["refund"][key])
	var records: Array = []
	var archive: Array = world.retired_buildings.duplicate(true)
	var active_work: String = ""
	for record: Dictionary in world.buildings:
		if active_work.is_empty() and record["state"] == "constructing":
			active_work = str(record["id"])
		if record["id"] == id:
			archive.append(record.duplicate(true))
		else:
			records.append(record.duplicate(true))
	var commands: Dictionary = world.removal_commands.duplicate(true)
	commands[command] = {"building_id": id, "tick": world.tick, "refund": offer["refund"].duplicate(), "overflow": offer["overflow"].duplicate()}
	world.resources = resources
	world.buildings = records
	world.retired_buildings = archive
	world.removal_commands = commands
	if active_work == id:
		world.labor_credit = 0
	return {"ok": true, "replayed": false, "refund": offer["refund"], "overflow": offer["overflow"]}

# 历史校验模块：每座退役建筑恰好有一条合法移除回执，退款不超过实付可退数。
static func restore_history(raw: Dictionary, archives: Array, tick: int) -> Variant:
	if raw.size() != archives.size():
		return null
	var by_id: Dictionary = {}
	for record: Dictionary in archives:
		by_id[record["id"]] = record
	var seen: Dictionary = {}
	var result: Dictionary = {}
	for command: Variant in raw:
		if not command is String or command.is_empty() or command.length() > 64 or not raw[command] is Dictionary:
			return null
		var receipt: Dictionary = raw[command]
		if receipt.size() != 4 or not receipt.get("building_id") is String or not by_id.has(receipt["building_id"]) or seen.has(receipt["building_id"]):
			return null
		var when: Variant = receipt.get("tick")
		if typeof(when) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(when)) or when < 0 or when > tick or float(when) != floor(float(when)):
			return null
		var expected: Dictionary = refundable(by_id[receipt["building_id"]])
		var refund: Dictionary = {}
		var overflow: Dictionary = {}
		for field: String in ["refund", "overflow"]:
			if not receipt.get(field) is Dictionary or receipt[field].size() != 2:
				return null
			for key: String in ["wood", "stone"]:
				var value: Variant = receipt[field].get(key)
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value > 1000000 or float(value) != floor(float(value)):
					return null
				if field == "refund":
					refund[key] = int(value)
				else:
					overflow[key] = int(value)
		for key: String in expected:
			if refund[key] + overflow[key] != expected[key]:
				return null
		seen[receipt["building_id"]] = true
		result[command] = {"building_id": receipt["building_id"], "tick": int(when), "refund": refund, "overflow": overflow}
	return result
