## 文件用途：原子取消训练或解散整批部队，按实付费用退款并保留未结军需与幂等历史。
extends RefCounted
const LIMIT: int = 1000000000

# 查询模块：仅活动批次可操作，历史记录不再占人口或军营编额。
static func find(world: RefCounted, id: String) -> Dictionary:
	for troop: Dictionary in world.troops:
		if troop["id"] == id:
			return troop
	return {}

# 退款模块：训练按剩余整数工作量退实付木材与金币，现役解散不退款。
static func refundable(troop: Dictionary) -> Dictionary:
	var refund: Dictionary = {"wood": 0, "gold": 0}
	if troop["state"] == "training":
		for key: String in refund:
			refund[key] = floori(int(troop["paid_cost"][key]) * (int(troop["work_required"]) - int(troop["work_done"])) / float(troop["work_required"]))
	return refund

# 预览模块：说明释放人数、退款和保留到日结的军需，不立即改变世界。
static func quote(world: RefCounted, id: String) -> Dictionary:
	var troop: Dictionary = find(world, id)
	if troop.is_empty():
		return {"ok": false, "reason": "请选择当前军营的活动部队批次"}
	if world.retired_troops.size() >= 512:
		return {"ok": false, "reason": "达到当前原型退役记录上限"}
	var refund: Dictionary = refundable(troop)
	var overflow: Dictionary = {"wood": 0, "gold": 0}
	for key: String in refund:
		var accepted: int = mini(int(refund[key]), LIMIT - int(world.resources[key]))
		overflow[key] = int(refund[key]) - accepted
		refund[key] = accepted
	return {"ok": true, "troop_id": id, "action": "取消训练" if troop["state"] == "training" else "解散部队", "return_workers": int(troop["count"]) if troop["source"] == "town" else 0, "refund": refund, "overflow": overflow, "ration_credit": troop["ration_credit"], "wage_credit": troop["wage_credit"], "signature": world.snapshot()}

# 执行模块：退款、返还兵源、释放编额与转移军需同一逻辑步生效，重试不重复处理。
static func execute(world: RefCounted, id: String, command: String, expected: Dictionary = {}) -> Dictionary:
	if command.is_empty() or command.length() > 64:
		return {"ok": false, "reason": "退役命令ID无效"}
	if world.disband_commands.has(command):
		if world.disband_commands[command]["troop_id"] != id:
			return {"ok": false, "reason": "同一退役命令不能用于另一批次"}
		return {"ok": true, "replayed": true, "refund": world.disband_commands[command]["refund"].duplicate()}
	var offer: Dictionary = quote(world, id)
	if not offer["ok"]:
		return offer
	if not expected.is_empty() and expected != offer["signature"]:
		return {"ok": false, "reason": "世界状态已变化，请重新查看退役影响"}
	var troop: Dictionary = find(world, id)
	var active: Array = []
	for record: Dictionary in world.troops:
		if record["id"] != id:
			active.append(record.duplicate(true))
	var retired: Array = world.retired_troops.duplicate(true)
	retired.append(troop.duplicate(true))
	var pending: Dictionary = world.retired_army_cost.duplicate()
	pending["ration_credit"] += int(troop["ration_credit"])
	pending["wage_credit"] += int(troop["wage_credit"])
	var resources: Dictionary = world.resources.duplicate()
	for key: String in offer["refund"]:
		resources[key] += int(offer["refund"][key])
	var receipts: Dictionary = world.disband_commands.duplicate(true)
	receipts[command] = {"troop_id": id, "tick": world.tick, "refund": offer["refund"].duplicate(), "overflow": offer["overflow"].duplicate()}
	world.troops = active
	world.retired_troops = retired
	world.retired_army_cost = pending
	world.resources = resources
	world.disband_commands = receipts
	return {"ok": true, "replayed": false, "refund": offer["refund"], "overflow": offer["overflow"]}

# 数值模块：历史费用与计数只接受有限非负整数。
static func _integer(value: Variant, limit: int = 1000000000) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= limit and float(value) == floor(float(value))

# 历史恢复模块：每个退役批次一条回执，并证明未结军需没有消失或重复入账。
static func restore(raw: Variant, pending: Variant, retired: Array, tick: int) -> Variant:
	if not raw is Dictionary or raw.size() != retired.size() or not pending is Dictionary or pending.size() != 4:
		return null
	var normalized: Dictionary = {}
	for key: String in ["ration_credit", "wage_credit", "ration_settled", "wage_settled"]:
		if not _integer(pending.get(key)):
			return null
		normalized[key] = int(pending[key])
	var by_id: Dictionary = {}
	var ration: int = 0
	var wage: int = 0
	for troop: Dictionary in retired:
		by_id[troop["id"]] = troop
		ration += int(troop["ration_credit"])
		wage += int(troop["wage_credit"])
	if ration != normalized["ration_credit"] + normalized["ration_settled"] * 120 or wage != normalized["wage_credit"] + normalized["wage_settled"] * 120:
		return null
	var commands: Dictionary = {}
	var seen: Dictionary = {}
	for command: Variant in raw:
		if not command is String or command.is_empty() or command.length() > 64 or not raw[command] is Dictionary:
			return null
		var receipt: Dictionary = raw[command]
		if receipt.size() != 4 or not receipt.get("troop_id") is String or not by_id.has(receipt["troop_id"]) or seen.has(receipt["troop_id"]) or not _integer(receipt.get("tick"), tick):
			return null
		var expected: Dictionary = refundable(by_id[receipt["troop_id"]])
		var refund: Dictionary = {}
		var overflow: Dictionary = {}
		for field: String in ["refund", "overflow"]:
			if not receipt.get(field) is Dictionary or receipt[field].size() != 2:
				return null
			for key: String in ["wood", "gold"]:
				if not _integer(receipt[field].get(key), 1000000):
					return null
				if field == "refund":
					refund[key] = int(receipt[field][key])
				else:
					overflow[key] = int(receipt[field][key])
		for key: String in expected:
			if refund[key] + overflow[key] != expected[key]:
				return null
		seen[receipt["troop_id"]] = true
		commands[command] = {"troop_id": receipt["troop_id"], "tick": int(receipt["tick"]), "refund": refund, "overflow": overflow}
	return {"commands": commands, "pending": normalized}
