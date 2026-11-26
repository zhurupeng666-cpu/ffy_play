## 文件用途：按人数自由编组现役部队，管理军团身份、成员约束与存档，不重复计算人口或军需。
extends RefCounted
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const SETTINGS = preload("res://data/military/legion_settings.tres")

# 部队查询模块：只从当前活动部队取成员，退役记录永远不能编入。
static func troop(world: RefCounted, id: String) -> Dictionary:
	for record: Dictionary in world.troops:
		if record["id"] == id:
			return record
	return {}

# 军团查询模块：关闭编制保留历史ID，玩家入口只使用活动军团。
static func find(world: RefCounted, id: String) -> Dictionary:
	for legion: Dictionary in world.legions:
		if legion["id"] == id and legion["state"] == "active":
			return legion
	return {}

# 人数模块：成员人数属于编制引用，不创建士兵、不增加全军人数。
static func people(legion: Dictionary) -> int:
	var total: int = 0
	for member: Dictionary in legion.get("members", []):
		total += int(member["count"])
	return total

# 配额查询模块：统计该部队在指定军团或所有军团的已编人数。
static func assigned(world: RefCounted, troop_id: String, legion_id: String = "") -> int:
	var total: int = 0
	for legion: Dictionary in world.legions:
		if legion["state"] == "active" and (legion_id.is_empty() or legion["id"] == legion_id):
			for member: Dictionary in legion["members"]:
				if member["troop_id"] == troop_id:
					total += int(member["count"])
	return total

# 新建模块：免费创建空编制，成功命令回执保留，旧请求不会复活撤销的军团。
static func create(world: RefCounted, command: String) -> Dictionary:
	if command.is_empty() or command.length() > 64:
		return {"ok": false, "reason": "军团命令ID无效"}
	if world.legion_create_commands.has(command):
		return {"ok": true, "replayed": true, "legion_id": world.legion_create_commands[command]}
	var active: int = 0
	for record: Dictionary in world.legions:
		active += 1 if record["state"] == "active" else 0
	if active >= int(SETTINGS.active_limit) or world.legions.size() >= int(SETTINGS.history_limit) or world.next_legion_id >= 1000000:
		return {"ok": false, "reason": "达到当前军团编制或历史数量上限"}
	var id: String = "legion_%06d" % world.next_legion_id
	var records: Array = world.legions.duplicate(true)
	records.append({"id": id, "name": "第%d军团" % world.next_legion_id, "state": "active", "members": []})
	var commands: Dictionary = world.legion_create_commands.duplicate()
	commands[command] = id
	world.legions = records
	world.legion_create_commands = commands
	world.next_legion_id += 1
	return {"ok": true, "replayed": false, "legion_id": id}

# 编制命令模块：设置本军团从某批次划入的绝对人数，相同请求幂等，0表示移出。
static func set_count(world: RefCounted, legion_id: String, troop_id: String, count: int) -> Dictionary:
	if March.away(world, legion_id):
		return {"ok": false, "reason": "军团驻外或正在行军，回城后可调整编制"}
	if Scout.busy(world, legion_id):
		return {"ok": false, "reason": "军团正在侦察，归队后可调整编制"}
	var legion: Dictionary = find(world, legion_id)
	if legion.is_empty() or count < 0:
		return {"ok": false, "reason": "军团不存在或人数无效"}
	var current: int = assigned(world, troop_id, legion_id)
	if count > 0:
		var source: Dictionary = troop(world, troop_id)
		if source.is_empty() or source["state"] != "ready":
			return {"ok": false, "reason": "只能编入当前现役部队，训练或退役批次不可用"}
		if assigned(world, troop_id) - current + count > int(source["count"]):
			return {"ok": false, "reason": "该批次可用人数不足，请先从其他军团移出"}
		if people(legion) - current + count > int(SETTINGS.people_capacity):
			return {"ok": false, "reason": "超过军团人数上限"}
	if current == count:
		return {"ok": true, "replayed": true}
	var records: Array = world.legions.duplicate(true)
	for record: Dictionary in records:
		if record["id"] == legion_id:
			var members: Array = []
			for member: Dictionary in record["members"]:
				if member["troop_id"] != troop_id:
					members.append(member)
			if count > 0:
				members.append({"troop_id": troop_id, "count": count})
			members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["troop_id"] < b["troop_id"])
			record["members"] = members
	world.legions = records
	return {"ok": true, "replayed": false}

# 撤销编制模块：保留军团历史，部队仍现役且维护照常，不归还城镇兵源。
static func dissolve(world: RefCounted, id: String, expected: Dictionary = {}) -> Dictionary:
	if March.away(world, id):
		return {"ok": false, "reason": "军团驻外或正在行军，回城后可撤销编制"}
	if Scout.busy(world, id):
		return {"ok": false, "reason": "军团正在侦察，归队后可撤销编制"}
	if not expected.is_empty() and expected != world.snapshot():
		return {"ok": false, "reason": "世界状态已变化，请重新查看撤销影响"}
	for record: Dictionary in world.legions:
		if record["id"] == id:
			if record["state"] == "closed":
				return {"ok": true, "replayed": true}
			var records: Array = world.legions.duplicate(true)
			for replacement: Dictionary in records:
				if replacement["id"] == id:
					replacement["state"] = "closed"
					replacement["members"] = []
			world.legions = records
			world.release_commander(id)
			return {"ok": true, "replayed": false}
	return {"ok": false, "reason": "军团不存在"}

# 退役联动模块：从所有编制同步移除同一批次，空军团保留，避免悬空成员引用。
static func without_troop(legions: Array, id: String) -> Array:
	var records: Array = legions.duplicate(true)
	for record: Dictionary in records:
		var members: Array = []
		for member: Dictionary in record["members"]:
			if member["troop_id"] != id:
				members.append(member)
		record["members"] = members
	return records

# 数值模块：编制人数与身份计数必须为有限整数。
static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high and float(value) == floor(float(value))

# 恢复模块：校验军团身份、容量、唯一成员与跨团分配总量，完整通过后替换世界数据。
static func restore_world(world: RefCounted, data: Dictionary) -> bool:
	if not data.get("legions") is Array or data["legions"].size() > int(SETTINGS.history_limit) or not data.get("legion_create_commands") is Dictionary or data["legion_create_commands"].size() != data["legions"].size() or not _integer(data.get("next_legion_id"), 1, 1000000):
		return false
	var records: Array = []
	var by_id: Dictionary = {}
	var used: Dictionary = {}
	var active: int = 0
	for raw: Variant in data["legions"]:
		if not raw is Dictionary or not raw.get("id") is String or not raw.get("name") is String or raw["name"].is_empty() or raw["name"].length() > 32 or raw["name"].contains("\n") or raw["name"].contains("\r") or raw.get("state") not in ["active", "closed"] or not raw.get("members") is Array:
			return false
		var suffix: String = str(raw["id"]).trim_prefix("legion_")
		if not suffix.is_valid_int() or not _integer(int(suffix), 1, int(data["next_legion_id"]) - 1) or raw["id"] != "legion_%06d" % int(suffix) or by_id.has(raw["id"]):
			return false
		if raw["state"] == "closed" and not raw["members"].is_empty():
			return false
		active += 1 if raw["state"] == "active" else 0
		var members: Array = []
		var seen: Dictionary = {}
		var total: int = 0
		if raw["members"].size() > int(SETTINGS.people_capacity):
			return false
		for member: Variant in raw["members"]:
			if not member is Dictionary or member.size() != 2 or not member.get("troop_id") is String or seen.has(member["troop_id"]) or not _integer(member.get("count"), 1, int(SETTINGS.people_capacity)):
				return false
			var source: Dictionary = troop(world, member["troop_id"])
			if source.is_empty() or source["state"] != "ready":
				return false
			var amount: int = int(member["count"])
			used[member["troop_id"]] = int(used.get(member["troop_id"], 0)) + amount
			if used[member["troop_id"]] > int(source["count"]):
				return false
			seen[member["troop_id"]] = true
			total += amount
			members.append({"troop_id": member["troop_id"], "count": amount})
		if total > int(SETTINGS.people_capacity):
			return false
		members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["troop_id"] < b["troop_id"])
		var record: Dictionary = {"id": raw["id"], "name": raw["name"], "state": raw["state"], "members": members}
		records.append(record)
		by_id[record["id"]] = record
	if active > int(SETTINGS.active_limit):
		return false
	var commands: Dictionary = {}
	var seen: Dictionary = {}
	for command: Variant in data["legion_create_commands"]:
		var id: Variant = data["legion_create_commands"][command]
		if not command is String or command.is_empty() or command.length() > 64 or not id is String or not by_id.has(id) or seen.has(id):
			return false
		seen[id] = true
		commands[command] = id
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	world.legions = records
	world.legion_create_commands = commands
	world.next_legion_id = int(data["next_legion_id"])
	return true
