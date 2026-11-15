## 文件用途：验证串行施工、暂停倍速、进度存档、旧完工建筑迁移和非法进度拒绝。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
var failed: bool = false


# 启动模块：使用隔离测试库，不触碰玩家存档。
func _initialize() -> void:
	call_deferred("_run")


# 断言模块：记录失败并通过退出码通知构建脚本。
func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)


# 施工验收模块：单队逐座投入，暂停冻结，倍速只影响时间推进。
func _run() -> void:
	var world: RefCounted = State.new()
	_check(Build.execute(world, "b_house", Vector2i(2, 2), "house")["ok"], "住宅开工失败")
	_check(Build.execute(world, "b_farm", Vector2i(12, 12), "farm")["ok"], "农场入队失败")
	var clock: RefCounted = Clock.new(world)
	clock.advance(100)
	_check(world.buildings[1]["work_done"] == 0, "暂停仍在施工")
	world.paused = false
	clock.advance(10)
	_check(world.buildings[1]["work_done"] == 10 and world.buildings[2]["work_done"] == 0, "施工队没有逐座工作")
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/work_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "进度保存失败")
	store.close_store()
	store = Store.new()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.buildings[1]["work_done"] == 10 and loaded.paused, "重开进度未恢复")
	if loaded == null:
		quit(1)
		return
	loaded.paused = false
	loaded.speed = 4
	clock = Clock.new(loaded)
	clock.advance(7.5)
	_check(loaded.buildings[1]["state"] == "ready" and loaded.buildings[2]["work_done"] == 0, "40秒完工边界错误")
	clock.advance(20)
	_check(loaded.buildings[2]["state"] == "ready" and loaded.tick == 120, "农场完工或倍速错误")
	_check(loaded.resources["wood"] == 75 and loaded.resources["gold"] == 300, "施工重复扣费或跨日税收错误")
	var before: Dictionary = loaded.snapshot()
	_check(Build.execute(loaded, "b_house", Vector2i(2, 2), "house").get("replayed", false) and loaded.snapshot() == before, "完工后重复命令重新开工")
	# 迁移模块：旧v2建筑是即时完工，不能迁移成未完工工地。
	var legacy: Dictionary = loaded.snapshot()
	legacy["version"] = 2
	for record: Dictionary in legacy["buildings"]:
		record.erase("work_done")
		record.erase("work_required")
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.buildings[1]["state"] == "ready", "旧完工建筑迁移失败")
	var bad: Dictionary = loaded.snapshot()
	bad["buildings"][1]["state"] = "constructing"
	_check(State.from_snapshot(bad) == null, "接受已满进度但施工中坏档")
	bad = loaded.snapshot()
	bad["buildings"][1]["work_done"] = -1
	_check(State.from_snapshot(bad) == null, "接受负施工进度")
	bad = loaded.snapshot()
	bad["buildings"][1]["work_done"] = 999999
	_check(State.from_snapshot(bad) == null, "接受超范围施工进度")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 界面验收模块：实际确认建造，推进到25%，保存后恢复同样的工地显示。
	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var main: Control = scene.instantiate()
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main._start_preview(load("res://data/buildings/house.tres"))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.town_map.world_to_screen(Vector2(0, 64))
	main.town_map._gui_input(click)
	main.world.paused = false
	main.clock.advance(10)
	main.world.paused = true
	main._refresh()
	_check(main.construction_label.text.contains("25%"), "界面未显示25%施工")
	main._save()
	main.world.paused = false
	main.clock.advance(30)
	main._load()
	_check(main.world.buildings[1]["work_done"] == 10 and main.world.paused and main.town_map.placed_buildings[1]["work_done"] == 10, "读档后工地视图未恢复")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("WORK_PASS: queue, pause, speed, snapshot, completion, legacy, progress guards, UI")
	quit(1 if failed else 0)
