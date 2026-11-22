## 文件用途：检查北部林地侦察的派遣条件，扣除粮食，并从战略时间读取任务结果。
extends RefCounted

const LAYOUT = preload("res://data/regions/frontier.tres")
const WOODS: String = "r_woods"
const FORT: String = "r_fort"

# 查询模块：任务在到达时刻自动完成，暂停期间战略时间不增长。
static func busy(world: RefCounted, legion_id: String = "") -> bool:
	var mission: Dictionary = world.woods_scout
	return not mission.is_empty() and world.tick < int(mission["arrives"]) \
		and (legion_id.is_empty() or mission["legion_id"] == legion_id)

# 阅览模块：完成记录同时用来持久化旧堡的发现结果。
static func complete(world: RefCounted) -> bool:
	return not world.woods_scout.is_empty() and not busy(world)

# 兵源模块：侦察期间禁止解散正在提供成员的原始部队。
static func uses_troop(world: RefCounted, troop_id: String) -> bool:
	if not busy(world):
		return false
	for legion: Dictionary in world.legions:
		if legion["id"] == world.woods_scout["legion_id"]:
			for member: Dictionary in legion["members"]:
				if member["troop_id"] == troop_id:
					return true
	return false

# 派遣预检模块：只允许一次林地任务，队伍必须存在且有现役成员。
static func reason(world: RefCounted, legion_id: String) -> String:
	if not world.woods_scout.is_empty():
		return "侦察已派出" if busy(world) else "已完成侦察"
	for legion: Dictionary in world.legions:
		if legion["id"] == legion_id and legion["state"] == "active" and not legion["members"].is_empty():
			if int(world.resources["food"]) < LAYOUT.scout_food:
				return "粮食不足"
			return ""
	return "请选择有现役士兵的军团"

# 派遣模块：先校验再扣费并记任务，重复点击不会追加扣粮。
static func dispatch(world: RefCounted, legion_id: String) -> bool:
	if not reason(world, legion_id).is_empty():
		return false
	world.resources["food"] -= LAYOUT.scout_food
	world.woods_scout = {"legion_id": legion_id, "started": world.tick, "arrives": world.tick + LAYOUT.scout_ticks}
	return true

# 存档模块：完成履历允许引用已撤销的军团，进行中则要求该团仍有人。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if raw.size() != 3 or not raw.get("legion_id") is String:
		return false
	for key: String in ["started", "arrives"]:
		var value: Variant = raw.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or value < 0 or value > 121000000 or floor(float(value)) != value:
			return false
	var started: int = int(raw["started"])
	var arrives: int = int(raw["arrives"])
	if started > world.tick or arrives <= started:
		return false
	for legion: Dictionary in world.legions:
		if legion["id"] != raw["legion_id"]:
			continue
		if world.tick < arrives and (legion["state"] != "active" or legion["members"].is_empty()):
			return false
		world.woods_scout = {"legion_id": raw["legion_id"], "started": started, "arrives": arrives}
		return true
	return false
