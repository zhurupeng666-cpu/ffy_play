## 文件用途：验证自由人数编制、跨团配额、维护不重计、退役联动、撤销身份及界面存档。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Army = preload("res://scripts/army_service.gd")
const Legions = preload("res://scripts/legion_service.gd")
const Disband = preload("res://scripts/army_disband_service.gd")
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
var failed: bool = false

# 启动模块：在场景树可容纳真实管理界面后执行。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：失败时给出原因，以退出码阻断构建。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 夹具模块：一个军营两批现役共10人，可测试一批在多个军团间拆分。
func _prepare() -> RefCounted:
	var world: RefCounted = State.new()
	Build.execute(world, "b_barracks", Vector2i(2, 4), "camp")
	world.paused = false
	var clock: RefCounted = Clock.new(world)
	clock.advance(120)
	Army.recruit(world, "building_000002", "first")
	clock.advance(60)
	Army.recruit(world, "building_000002", "second")
	clock.advance(60)
	world.paused = true
	return world

# 经济快照模块：排除纯编制字段后，其余世界必须在编制操作中完全保持不变。
func _economy(world: RefCounted) -> Dictionary:
	var snapshot: Dictionary = world.snapshot()
	for key: String in ["legions", "legion_create_commands", "next_legion_id"]:
		snapshot.erase(key)
	return snapshot

# 编制验收模块：整数人数可拆分但不能复制士兵，相同绝对人数请求重复安全。
func _run() -> void:
	var world: RefCounted = _prepare()
	var economic_before: Dictionary = _economy(world)
	var a: String = Legions.create(world, "a")["legion_id"]
	var b: String = Legions.create(world, "b")["legion_id"]
	var before: Dictionary = world.snapshot()
	_check(Legions.create(world, "a").get("replayed", false) and world.snapshot() == before, "重复创建多出军团")
	_check(Legions.set_count(world, a, "troop_000001", 2)["ok"] and Legions.set_count(world, b, "troop_000001", 3)["ok"], "5人不能拆成2和3")
	_check(Legions.people(Legions.find(world, a)) == 2 and Legions.people(Legions.find(world, b)) == 3 and Legions.assigned(world, "troop_000001") == 5, "拆分人数不守恒")
	before = world.snapshot()
	_check(Legions.set_count(world, a, "troop_000001", 2).get("replayed", false) and world.snapshot() == before, "重复保存人数重复编入")
	_check(not Legions.set_count(world, b, "troop_000001", 4)["ok"] and not Legions.set_count(world, a, "troop_000001", -1)["ok"] and not Legions.set_count(world, a, "missing", 1)["ok"] and world.snapshot() == before, "超额或无效成员改变编制")
	Legions.set_count(world, a, "troop_000001", 1)
	_check(Legions.set_count(world, b, "troop_000001", 4)["ok"], "移出1人后不能分给另一团")
	Legions.set_count(world, a, "troop_000001", 0)
	Legions.set_count(world, b, "troop_000001", 5)
	_check(Legions.assigned(world, "troop_000001") == 5 and _economy(world) == economic_before, "移出或转编改变人口、资源或军需")
	Legions.set_count(world, b, "troop_000001", 3)
	Legions.set_count(world, a, "troop_000001", 2)
	Legions.set_count(world, a, "troop_000002", 5)
	_check(Legions.people(Legions.find(world, a)) == 7, "一个军团不能组合不同来源批次")
	Legions.dissolve(world, a)
	before = world.snapshot()
	_check(Legions.dissolve(world, a).get("replayed", false) and Legions.create(world, "a").get("replayed", false) and world.snapshot() == before and Legions.find(world, a).is_empty(), "撤销重放复活军团或重复修改")
	_check(_economy(world) == economic_before and Legions.assigned(world, "troop_000001") == 3, "撤销军团解散了士兵或影响其他团")
	var c: String = Legions.create(world, "c")["legion_id"]
	_check(c == "legion_000003", "撤销后复用军团ID")
	Legions.set_count(world, c, "troop_000001", 2)
	Legions.set_count(world, c, "troop_000002", 5)
	# 日结对照模块：相同部队的有编制和无编制世界，经济及维护应完全相同。
	var baseline: RefCounted = State.from_snapshot(world.snapshot())
	baseline.legions = []
	baseline.legion_create_commands = {}
	baseline.next_legion_id = 1
	world.paused = false
	baseline.paused = false
	Clock.new(world).advance(120)
	Clock.new(baseline).advance(120)
	_check(_economy(world) == _economy(baseline), "军团重复占人或重复扣维护")
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/legion_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "军团保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.legions == world.legions and loaded.idle_workers() == world.idle_workers(), "自由人数或关闭编制历史读档错误")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	# 退役联动模块：退役一个原始5人批次，其在不同团的2人和3人同时清除。
	_check(Disband.quote(loaded, "troop_000001")["legion_people"] == 5, "退役预览遗漏军团影响")
	Disband.execute(loaded, "troop_000001", "dismiss")
	_check(Legions.assigned(loaded, "troop_000001") == 0 and Legions.people(Legions.find(loaded, b)) == 0 and Legions.people(Legions.find(loaded, c)) == 5 and loaded.idle_workers() == 17 and store.save_world(loaded), "退役造成悬空编制或错误返还兵员")
	# 坏档模块：跨团超配、重复引用、历史成员、无效身份和分数人数均拒绝。
	var bad: Dictionary = world.snapshot()
	bad["legions"][1]["members"][0]["count"] = 4
	_check(State.from_snapshot(bad) == null, "读取允许跨团复制士兵")
	bad = world.snapshot()
	bad["legions"][2]["members"].append(bad["legions"][2]["members"][0].duplicate())
	_check(State.from_snapshot(bad) == null, "接受同团重复批次")
	bad = world.snapshot()
	bad["legions"][0]["members"] = [{"troop_id": "troop_000001", "count": 1}]
	_check(State.from_snapshot(bad) == null, "关闭军团仍有成员")
	bad = world.snapshot()
	bad["legions"][2]["members"][0]["count"] = 1.5
	_check(State.from_snapshot(bad) == null, "接受分数兵员")
	bad = world.snapshot()
	bad["legions"][2]["members"][0]["troop_id"] = "troop_999999"
	_check(State.from_snapshot(bad) == null, "接受不存在的成员引用")
	bad = world.snapshot()
	bad["legion_create_commands"] = {}
	_check(State.from_snapshot(bad) == null, "接受缺军团创建回执")
	var legacy: Dictionary = world.snapshot()
	legacy["version"] = 11
	for key: String in ["legions", "legion_create_commands", "next_legion_id"]:
		legacy.erase(key)
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.legions.is_empty() and migrated.troops == world.troops and migrated.resources == world.resources, "v11迁移改变原部队或库存")
	# 训练限制模块：未完成训练不能编入，达到活动上限后撤销可释放名额。
	var training_world: RefCounted = State.new()
	Build.execute(training_world, "b_barracks", Vector2i(2, 4), "camp")
	training_world.paused = false
	Clock.new(training_world).advance(80)
	Army.recruit(training_world, "building_000002", "trainee")
	var empty: String = Legions.create(training_world, "empty")["legion_id"]
	_check(not Legions.set_count(training_world, empty, "troop_000001", 1)["ok"], "训练中部队可编入")
	for index: int in range(7):
		Legions.create(training_world, "limit-%d" % index)
	before = training_world.snapshot()
	_check(not Legions.create(training_world, "ninth")["ok"] and training_world.snapshot() == before, "超过8个活动军团")
	Legions.dissolve(training_world, empty)
	_check(Legions.create(training_world, "replacement")["ok"], "撤销后不释放活动编制名额")
	# 容量模块：合法30名兵源可以测试军团20人上限，超限失败不改变状态。
	var full: RefCounted = State.new()
	full.resources = {"food": 1000, "gold": 1000, "wood": 1000, "stone": 1000}
	full.dependents = 0
	Build.execute(full, "b_barracks", Vector2i(2, 4), "one")
	Build.execute(full, "b_barracks", Vector2i(10, 10), "two")
	Build.execute(full, "b_barracks", Vector2i(10, 5), "three")
	full.paused = false
	Clock.new(full).advance(240)
	full.assign_builders(0)
	for wave: int in range(2):
		for index: int in range(2, 5):
			Army.recruit(full, "building_%06d" % index, "%d-%d" % [wave, index])
		Clock.new(full).advance(60)
	var capped: String = Legions.create(full, "capped")["legion_id"]
	for index: int in range(1, 5):
		Legions.set_count(full, capped, "troop_%06d" % index, 5)
	before = full.snapshot()
	_check(Legions.people(Legions.find(full, capped)) == 20 and not Legions.set_count(full, capped, "troop_000005", 1)["ok"] and full.snapshot() == before, "军团超过20人")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 真实界面模块：数值设置可将一批拆成2和3，未保存输入不被每秒维护刷新打断。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.legacy_economy_fixture = true
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main.world = _prepare()
	main.clock = Clock.new(main.world)
	main._sync_building_view()
	main._refresh()
	main._create_legion()
	main.legion_people.value = 2
	main.legion_apply.pressed.emit()
	main._create_legion()
	main.legion_people.value = 3
	main.legion_apply.pressed.emit()
	_check(Legions.assigned(main.world, "troop_000001") == 5 and main.world.idle_workers() == 12 and main.numbers["legion_size"].text.begins_with("3 / "), "界面没有按人数编制或重复占用兵员")
	main._on_legion_selected(0)
	_check(main.legion_people.value == 2 and main.legion_people.max_value == 2, "切换军团没有同步人数配额")
	main.legion_people.value = 1
	main.world.paused = false
	main.clock.advance(1)
	main.world.paused = true
	main._refresh()
	_check(main.legion_people.value == 1 and Legions.assigned(main.world, "troop_000001", main.selected_legion_id) == 2, "每秒刷新打断输入或自动保存了未提交人数")
	before = main.world.snapshot()
	main._request_legion_close()
	main.clock.advance(100)
	main._cancel_legion_close()
	_check(main.world.snapshot() == before, "保留军团改变世界")
	main._request_legion_close()
	main.world.resources["gold"] += 1
	main._confirm_legion_close()
	_check(not Legions.find(main.world, "legion_000001").is_empty() and main.status_label.text.contains("状态已变化"), "过期撤销预览仍执行")
	main._request_legion_close()
	main._confirm_legion_close()
	_check(Legions.find(main.world, "legion_000001").is_empty() and Army.people(main.world.troops, false, true) == 10 and main.world.idle_workers() == 12, "撤销编制解散了士兵或返还劳动力")
	main._save()
	main._load()
	_check(main.world.legions.size() == 2 and Legions.assigned(main.world, "troop_000001") == 3 and main.world.idle_workers() == 12, "界面读档没有恢复关闭历史与拆分人数")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("LEGION_PASS: free counts, shared quota, capacity, economy, retirement, dissolution, history, migration, UI")
	quit(1 if failed else 0)
