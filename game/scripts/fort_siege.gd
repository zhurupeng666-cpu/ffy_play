## 文件用途：管理旧堡攻城指令和战果，按战略时间恢复城门与守军战况。
extends RefCounted

const Field = preload("res://scripts/woods_battle.gd")
const Scout = Field.Scout
const LAYOUT = Field.LAYOUT

# 战况模块：旧堡与林地共用战力结算，城门存在时先承受进攻。
static func report(world: RefCounted, at_tick: int = -1) -> Dictionary:
	return Field.simulate(world.fort_siege, world.tick if at_tick < 0 else at_tick)

# 位置模块：必须已在堡外驻扎，不能在途中开战。
static func at_fort(world: RefCounted, legion_id: String, at_tick: int) -> bool:
	var trip: Dictionary = world.legion_trips.get(legion_id, {})
	return trip.get("target") == Scout.FORT and int(trip.get("arrives", 0)) <= at_tick

# 出战条件：林地通路开放、军团抵达并且当前没有待结算攻城。
static func reason(world: RefCounted, legion_id: String, status: String) -> String:
	if status == "victory":
		return "旧堡已由己方控制"
	if status == "running":
		return "攻城进行中"
	if Field.report(world)["status"] != "victory":
		return "需先取得北部林地控制权"
	if not at_fort(world, legion_id, world.tick):
		return "需先让军团抵达旧堡外"
	return ""

# 派遣模块：开战时冻结兵力、士气、守军和城门数值，重复点击不创建新战斗。
static func start(world: RefCounted, legion_id: String) -> bool:
	if not reason(world, legion_id, report(world)["status"]).is_empty():
		return false
	for legion: Dictionary in world.legions:
		if legion["id"] != legion_id or legion["state"] != "active" or legion["members"].is_empty():
			continue
		world.fort_siege = {
			"legion_id": legion_id,
			"people": Field.member_count(legion),
			"guards": LAYOUT.fort_guards,
			"gate": LAYOUT.fort_gate_power,
			"morale": world.army_morale,
			"started": world.tick,
		}
		return true
	return false

# 锁定模块：攻城期间限制参战军团的移动，胜败结算后解除。
static func busy(world: RefCounted, legion_id: String) -> bool:
	return world.fort_siege.get("legion_id") == legion_id and report(world)["status"] == "running"

# 恢复模块：校验历史战果和攻城期间的驻地，并允许已结束军团有后续编制变化。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	var first_tick: int = int(world.woods_scout.get("arrives", 0))
	if not Field.valid_snapshot(raw, first_tick, world.tick, true):
		return false
	if Field.report(world, int(raw["started"]))["status"] != "victory":
		return false
	for legion: Dictionary in world.legions:
		if legion["id"] != raw["legion_id"]:
			continue
		world.fort_siege = raw.duplicate()
		if not busy(world, raw["legion_id"]):
			return true
		return legion["state"] == "active" and Field.member_count(legion) == int(raw["people"]) \
			and at_fort(world, raw["legion_id"], int(raw["started"]))
	return false
