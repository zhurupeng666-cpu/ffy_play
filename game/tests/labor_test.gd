## 文件用途：验证人口守恒、施工岗位速度、住房容量、快照迁移和界面分配持久化。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
var failed: bool = false

# 启动模块：延迟执行，以便挂载真实管理场景。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：累计失败并返回非零退出码。
func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

# 人口验收模块：岗位只占用现有人口，暂停和无工人分别冻结战略与施工。
func _run() -> void:
	var world: RefCounted = State.new()
	_check(world.population == 30 and world.dependents == 6 and world.idle_workers() == 22 and world.housing_capacity() == 30, "初始人口账不符")
	_check(not world.assign_builders(-1) and not world.assign_builders(3) and world.builders == 2, "越界分配改变了状态")
	_check(Build.execute(world, "b_house", Vector2i(2, 2), "labor-house")["ok"], "住宅开工失败")
	world.assign_builders(0)
	world.paused = false
	var clock: RefCounted = Clock.new(world)
	clock.advance(10)
	_check(world.tick == 10 and world.buildings[1]["work_done"] == 0 and world.idle_workers() == 24, "零工人没有仅停止施工")
	world.assign_builders(1)
	clock.advance(1)
	_check(world.labor_credit == 1 and world.buildings[1]["work_done"] == 0 and world.idle_workers() == 23, "半份工作累计错误")
	world.paused = true
	clock.advance(10)
	_check(world.labor_credit == 1 and world.tick == 11, "暂停未冻结工作余数")
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/labor_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "劳动力保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null, "劳动力读档失败")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	_check(loaded.builders == 1 and loaded.dependents == 6 and loaded.labor_credit == 1, "岗位或半份进度未恢复")
	loaded.paused = false
	clock = Clock.new(loaded)
	clock.advance(1)
	_check(loaded.buildings[1]["work_done"] == 1 and loaded.labor_credit == 0 and loaded.housing_capacity() == 30, "单人半速或工地住房规则错误")
	loaded.assign_builders(2)
	clock.advance(39)
	_check(loaded.buildings[1]["state"] == "ready" and loaded.housing_capacity() == 40 and loaded.population == 30, "完工容量或固定人口错误")
	# 迁移模块：旧档无需补字段，默认两人并保持已有施工进度。
	var legacy: Dictionary = loaded.snapshot()
	legacy["version"] = 3
	for key: String in ["dependents", "builders", "labor_credit"]:
		legacy.erase(key)
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.builders == 2 and migrated.buildings == loaded.buildings, "v3迁移改变了建筑或岗位默认值")
	# 坏档模块：拒绝超额岗位、非法工作余数和缺少新版字段。
	var bad: Dictionary = loaded.snapshot()
	bad["dependents"] = 29
	_check(State.from_snapshot(bad) == null, "接受超可就业人口分配")
	bad = loaded.snapshot()
	bad["labor_credit"] = 2
	_check(State.from_snapshot(bad) == null, "接受非法工作余数")
	bad = loaded.snapshot()
	bad.erase("builders")
	_check(State.from_snapshot(bad) == null, "接受缺字段v4")
	world.dependents = 30
	world.assign_builders(0)
	_check(not world.assign_builders(1), "分配超过可就业人口")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 界面验收模块：直接操作场景入口，验证提示和保存读取一致。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.legacy_economy_fixture = true
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main._change_builders(-1)
	main._change_builders(-1)
	Build.execute(main.world, "b_house", Vector2i(2, 2), "ui-labor")
	main._refresh()
	_check(main.numbers["builders"].text == "0" and main.numbers["idle"].text == "24" and main.construction_label.text.contains("已停工"), "界面未显示岗位和停工")
	main._inspect_building("building_000002", true)
	_check(main.site_builder_actions.visible and not main.builder_add_buttons[1].disabled and main.builder_remove_buttons[1].disabled, "工地详情没有可用的施工岗位按钮")
	_check(main.numbers["hud_workforce"].text == "24" and main.numbers["hud_idle"].text == "24", "顶栏人口和劳动力没有同步")
	main.world.dependents = 30
	main._refresh()
	_check(main.numbers["hud_idle"].text == "0" and main.builder_add_buttons[1].disabled and main.site_builder_hint.text.contains("无空闲"), "空闲为零时仍能增员或缺少提示")
	main.world.dependents = 6
	main._refresh()
	main.builder_add_buttons[1].pressed.emit()
	_check(main.world.builders == 1 and main.numbers["hud_idle"].text == "23", "工地增员按钮未分配施工人员")
	main._save()
	main.builder_add_buttons[1].pressed.emit()
	_check(main.builder_add_buttons[1].disabled and main.site_builder_hint.text.contains("2 / 2"), "满员状态未锁定施工增员")
	main._load()
	_check(main.world.builders == 1 and main.numbers["builders"].text == "1" and main.numbers["idle"].text == "23" and main.numbers["hud_idle"].text == "23", "界面读档未恢复岗位")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("LABOR_PASS: conservation, allocation, speed, housing, remainder, migration, guards, UI")
	quit(1 if failed else 0)
