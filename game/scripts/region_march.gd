## 文件用途：根据区域道路与控制权派遣军团，并验证途中的路线和驻地。
extends RefCounted

const Siege = preload("res://scripts/fort_siege.gd")
const Battle = preload("res://scripts/woods_battle.gd")
const Scout = preload("res://scripts/region_scout.gd")
const LAYOUT = Scout.LAYOUT

# 时间模块：战略时钟控制行军，抵达时读取持久记录上的目的地。
static func remaining(world: RefCounted, legion_id: String) -> int:
	var trip: Dictionary = world.legion_trips.get(legion_id, {})
	return maxi(0, int(trip.get("arrives", 0)) - world.tick)

# 驻地模块：没有行程记录的军团默认在边境镇。
static func destination(world: RefCounted, legion_id: String) -> String:
	var trip: Dictionary = world.legion_trips.get(legion_id, {})
	return str(trip.get("target", LAYOUT.home_id))

# 编制模块：路线途中和驻林地时保持成员，回城后恢复编辑。
static func away(world: RefCounted, legion_id: String) -> bool:
	return remaining(world, legion_id) > 0 or destination(world, legion_id) != LAYOUT.home_id

# 批次模块：只拦截有成员被派出的招募批次。
static func uses_troop(world: RefCounted, troop_id: String) -> bool:
	for legion: Dictionary in world.legions:
		if not away(world, legion["id"]):
			continue
		for member: Dictionary in legion["members"]:
			if member["troop_id"] == troop_id:
				return true
	return false

# 邻接模块：道路支持双向通行，军团每次只走一条相邻道路。
static func adjacent(origin: String, target: String) -> bool:
	for road: PackedStringArray in LAYOUT.roads:
		if origin in road and target in road and origin != target:
			return true
	return false

# 旧堡路线模块：林地在出发时已由己方控制，才允许通过相邻道路。
static func fort_access(world: RefCounted, at_tick: int = -1) -> bool:
	return Battle.report(world, at_tick)["status"] == "victory"

# 派遣校验模块：校验驻地、领地控制权和当前行程。
static func reason(world: RefCounted, legion_id: String, target: String) -> String:
	if not Scout.complete(world):
		return "需先完成北部林地侦察"
	if not LAYOUT.regions.has(target):
		return "目的地区域不存在"
	if Battle.busy(world, legion_id) or Siege.busy(world, legion_id):
		return "军团正在交战，战斗结束后可调动"
	if remaining(world, legion_id) > 0:
		return "军团正在行军"
	for legion: Dictionary in world.legions:
		if legion["id"] == legion_id and legion["state"] == "active" and not legion["members"].is_empty():
			var origin: String = destination(world, legion_id)
			if target == origin:
				return "军团已在该区域"
			if not adjacent(origin, target):
				return "两地不相邻，需经北部林地中转"
			if (target == Scout.FORT or origin == Scout.FORT) and not fort_access(world):
				return "需先取得北部林地控制权"
			return ""
	return "请选择有现役士兵的军团"

# 派遣模块：每个军团单独计时，原有居民口粮和军需按日结算。
static func dispatch(world: RefCounted, legion_id: String, target: String) -> bool:
	if not reason(world, legion_id, target).is_empty():
		return false
	world.legion_trips[legion_id] = {
		"origin": destination(world, legion_id),
		"target": target,
		"started": world.tick,
		"arrives": world.tick + LAYOUT.march_ticks,
	}
	return true

# 归队模块：回城即释放行程记录，驻外军团的位置继续保存。
static func advance(world: RefCounted) -> void:
	for id: String in world.legion_trips.keys():
		var trip: Dictionary = world.legion_trips[id]
		if world.capital_layout and trip["arrives"]==world.tick:
			var group: String = "出征军团"
			if world.household_economy.get("legion","")==id:
				group=world.household_name(world.household_economy["general"])+"统领的军团"
			world.post_report("军务","军团抵达","%s已抵达%s。" % [group,LAYOUT.regions[trip["target"]]["title"]])
		if destination(world, id) == LAYOUT.home_id and remaining(world, id) == 0:
			world.legion_trips.erase(id)

# 存档校验模块：保留已派行程的原到达时间，三天路程从新派遣起生效。
static func restore(world: RefCounted, raw: Variant, legacy: bool) -> bool:
	if not raw is Dictionary or raw.size() > world.legions.size():
		return false
	if raw.is_empty():
		return true
	if not Scout.complete(world):
		return false
	var active: Dictionary = {}
	for legion: Dictionary in world.legions:
		if legion["state"] == "active" and not legion["members"].is_empty():
			active[legion["id"]] = true
	var trips: Dictionary = {}
	for id: Variant in raw:
		var trip: Variant = raw[id]
		if not active.has(id) or not trip is Dictionary or trip.size() != (3 if legacy else 4):
			return false
		var target: Variant = trip.get("target")
		if not target is String:
			return false
		var origin: Variant = trip.get("origin")
		if legacy:
			if target not in [LAYOUT.home_id, Scout.WOODS]:
				return false
			origin = Scout.WOODS if target == LAYOUT.home_id else LAYOUT.home_id
		if not origin is String or not adjacent(origin, target):
			return false
		for key: String in ["started", "arrives"]:
			var value: Variant = trip.get(key)
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
				or value < 0 or value > 121000000 or floor(float(value)) != value:
				return false
		var started: int = int(trip["started"])
		var arrives: int = int(trip["arrives"])
		if started < int(world.woods_scout["arrives"]) or started > world.tick or arrives <= started:
			return false
		if target == LAYOUT.home_id and arrives <= world.tick:
			return false
		trips[id] = {"origin": origin, "target": target, "started": started, "arrives": arrives}
	world.legion_trips = trips
	return true

# 控制权校验模块：战果恢复后，再校验存档中的旧堡道路是否已经开放。
static func valid_fort_trips(world: RefCounted) -> bool:
	for trip: Dictionary in world.legion_trips.values():
		if Scout.FORT in [trip["origin"], trip["target"]] and not fort_access(world, trip["started"]):
			return false
	return true
