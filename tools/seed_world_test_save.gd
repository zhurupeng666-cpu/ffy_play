## 文件用途：在明确指定的数据库里加入一份可测试经营、练兵与出征的战略进度。
extends SceneTree

const Store = preload("res://scripts/world_save_repository.gd")
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Army = preload("res://scripts/army_service.gd")
const Legions = preload("res://scripts/legion_service.gd")
const Scout = preload("res://scripts/region_scout.gd")
const TITLE: String = "测试进度｜边境镇"


# 启动模块：要求指定路径并防止为同一库重复添加测试进度。
func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0].is_absolute_path():
		push_error("请提供一个绝对存档路径")
		quit(1)
		return
	var store: RefCounted = Store.new()
	if not store.open_store(arguments[0]):
		push_error(store.error_message)
		quit(1)
		return
	for row: Dictionary in store.list_saves():
		if row["title"] == TITLE:
			print("SEED_ALREADY_PRESENT")
			store.close_store()
			quit(0)
			return
	var world: RefCounted = _prepare()
	if world == null or not store.save_world(world, TITLE):
		push_error("无法写入测试进度 " + store.error_message)
		store.close_store()
		quit(1)
		return
	var check: RefCounted = store.load_world()
	if check == null or check.snapshot() != world.snapshot():
		push_error("测试进度提交后校验失败")
		store.close_store()
		quit(1)
		return
	print("SEED_PASS: day %d, %d buildings, %d ready, %d training, %d saves" % [check.current_day(), check.buildings.size(), Army.people(check.troops, false, true), Army.people(check.troops) - Army.people(check.troops, false, true), store.list_saves().size()])
	store.close_store()
	quit(0)


# 样本模块：正常建造、训练和侦察，保留所有相关回执与进度。
func _prepare() -> RefCounted:
	var world: RefCounted = State.new()
	world.resources = {"food": 560, "gold": 6000, "wood": 4000, "stone": 3000}
	var sites: Array[Dictionary] = [
		{"type": "b_house", "at": Vector2i(4, 4)},
		{"type": "b_farm", "at": Vector2i(0, 34), "large": true},
		{"type": "b_ranch", "at": Vector2i(23, 44), "large": true},
		{"type": "b_fishery", "at": Vector2i(8, 71)},
		{"type": "b_lumber", "at": Vector2i(46, 46)},
		{"type": "b_quarry", "at": Vector2i(101, 37)},
		{"type": "b_granary", "at": Vector2i(31, 2), "large": true},
		{"type": "b_barracks", "at": Vector2i(60, 12), "large": true},
		{"type": "b_barracks", "at": Vector2i(60, 70), "large": true},
	]
	for index: int in range(sites.size()):
		var site: Dictionary = sites[index]
		var placed: Dictionary = Build.execute(world, site["type"], site["at"], "fixture-site-%d" % index, site.get("large", false))
		if not placed["ok"]:
			push_error("%s %s" % [site["type"], placed.get("reason", "")])
			return null
	var clock: RefCounted = Clock.new(world)
	world.paused = false
	clock.advance(850)
	for record: Dictionary in world.buildings:
		if record["state"] != "ready":
			push_error("测试建筑尚未完工")
			return null
	var first: String = "building_000009"
	var second: String = "building_000010"
	if not Army.recruit(world, first, "fixture-first")["ok"] or not Army.recruit(world, second, "fixture-second")["ok"]:
		return null
	clock.advance(60)
	if not Army.recruit(world, first, "fixture-third")["ok"]:
		return null
	clock.advance(60)
	var scout_legion: String = Legions.create(world, "fixture-legion-one")["legion_id"]
	var home_legion: String = Legions.create(world, "fixture-legion-two")["legion_id"]
	if not Legions.set_count(world, scout_legion, "troop_000001", 5)["ok"] \
		or not Legions.set_count(world, scout_legion, "troop_000003", 5)["ok"] \
		or not Legions.set_count(world, home_legion, "troop_000002", 5)["ok"]:
		return null
	if not Scout.dispatch(world, scout_legion):
		return null
	clock.advance(120)
	if not Scout.complete(world) or not Army.recruit(world, second, "fixture-fourth")["ok"]:
		return null
	clock.advance(24)
	world.assign_builders(0)
	if not world.assign_producers("building_000003", 2) or not world.assign_producers("building_000004", 1) \
		or not world.assign_producers("building_000005", 1):
		return null
	world.resources = {"food": 560, "gold": 5000, "wood": 3000, "stone": 2000}
	world.paused = true
	return world
