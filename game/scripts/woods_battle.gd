## 文件用途：模拟北部林地的自动遭遇战，保存参战快照并据战果判定区域归属。
extends RefCounted

const Scout = preload("res://scripts/region_scout.gd")
const LAYOUT = Scout.LAYOUT

# 原型参数：战力每人10点，每4战略秒同时结算一次攻防。
const POWER_PER_PERSON: int = 10
const ROUND_TICKS: int = 4
const MAX_MORALE: int = 100

# 战况模块：用出战快照和经过时间复算战力，读档后继承相同对局。
static func report(world: RefCounted, at_tick: int = -1) -> Dictionary:
	return simulate(world.woods_battle, world.tick if at_tick < 0 else at_tick)

# 通用战力模块：守军每轮反击，攻方先打城门，再打守军。
static func simulate(record: Dictionary, at_tick: int) -> Dictionary:
	if record.is_empty() or at_tick < int(record["started"]):
		return {"status": "idle"}
	var allies: int = int(record["people"]) * POWER_PER_PERSON
	var enemies: int = int(record["guards"]) * POWER_PER_PERSON
	var gate: int = int(record.get("gate", 0))
	var rounds: int = int((at_tick - int(record["started"])) / float(ROUND_TICKS))
	var morale_factor: float = 0.8 + int(record["morale"]) / 250.0
	for _round: int in range(mini(rounds, allies + enemies + gate)):
		var ally_attack: int = maxi(1, roundi(ceili(allies / float(POWER_PER_PERSON)) * morale_factor))
		var enemy_attack: int = ceili(enemies / float(POWER_PER_PERSON))
		allies = maxi(0, allies - enemy_attack)
		if gate > 0:
			gate = maxi(0, gate - ally_attack)
		else:
			enemies = maxi(0, enemies - ally_attack)
		if allies == 0 or enemies == 0:
			break
	var status: String = "running"
	if allies == 0:
		status = "defeat"
	elif enemies == 0:
		status = "victory"
	return {"status": status, "allies": allies, "enemies": enemies, "gate": gate}

# 出战校验模块：只有已抵达林地的现役军团可迎战当地守军。
static func reason(world: RefCounted, legion_id: String, status: String) -> String:
	if status == "victory":
		return "林地已由己方控制"
	if status == "running":
		return "林地战斗进行中"
	var trip: Dictionary = world.legion_trips.get(legion_id, {})
	if trip.get("target") != Scout.WOODS or int(trip.get("arrives", 0)) > world.tick:
		return "需先让军团抵达北部林地"
	return ""

# 开战模块：冻结参战人数与出战士气，原型只结算战力与领地归属。
static func start(world: RefCounted, legion_id: String) -> bool:
	if not reason(world, legion_id, report(world)["status"]).is_empty():
		return false
	for legion: Dictionary in world.legions:
		if legion["id"] != legion_id or legion["state"] != "active":
			continue
		var people: int = member_count(legion)
		if people == 0:
			return false
		world.woods_battle = {"legion_id": legion_id, "people": people, "guards": LAYOUT.woods_guards, "morale": world.effective_battle_morale(legion_id), "started": world.tick}
		return true
	return false

# 行军联动模块：仅限制正在交战的军团，战斗结算后允许回城。
static func busy(world: RefCounted, legion_id: String) -> bool:
	return world.woods_battle.get("legion_id") == legion_id and report(world)["status"] == "running"

# 兵员模块：从军团编制读取参战人数。
static func member_count(legion: Dictionary) -> int:
	var people: int = 0
	for member: Dictionary in legion["members"]:
		people += int(member["count"])
	return people

# 战斗快照模块：校验冻结的兵力、士气及已提交的开战时间。
static func valid_snapshot(raw: Dictionary, earliest: int, latest: int, siege: bool = false) -> bool:
	if raw.size() != (6 if siege else 5) or not raw.get("legion_id") is String:
		return false
	var limits: Dictionary = {"people": Vector2i(1, 20), "guards": Vector2i(1, 20), "morale": Vector2i(0, MAX_MORALE), "started": Vector2i(earliest, latest)}
	if siege:
		limits["gate"] = Vector2i(1, 200)
	for key: String in limits:
		var value: Variant = raw.get(key)
		var bounds: Vector2i = limits[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or value < bounds.x or value > bounds.y or floor(float(value)) != value:
			return false
	return true

# 存档模块：校验已侦察前提、参战快照和仍在交战军团的驻地。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if not Scout.complete(world) or not valid_snapshot(raw, int(world.woods_scout["arrives"]), world.tick):
		return false
	for legion: Dictionary in world.legions:
		if legion["id"] != raw["legion_id"]:
			continue
		world.woods_battle = raw.duplicate()
		if not busy(world, raw["legion_id"]):
			return true
		var trip: Dictionary = world.legion_trips.get(raw["legion_id"], {})
		var people: int = member_count(legion)
		return legion["state"] == "active" and people == int(raw["people"]) \
			and trip.get("target") == Scout.WOODS and int(trip["arrives"]) <= int(raw["started"])
	return false
