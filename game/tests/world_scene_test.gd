## 文件用途：在隔离数据库上验证战略面板加载、暂停按钮与保存读取后的界面同步。
extends SceneTree
const Army = preload("res://scripts/army_service.gd")
const Disband = preload("res://scripts/army_disband_service.gd")
const Build = preload("res://scripts/construction_service.gd")
const Legions = preload("res://scripts/legion_service.gd")
const Battle = preload("res://scripts/woods_battle.gd")
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const State = preload("res://scripts/world_state.gd")


# 启动模块：等待场景树可添加节点后开始界面回归。
func _initialize() -> void:
	call_deferred("_run")


# 验收模块：测试世界引用和界面显示均恢复，失败不影响用户存档。
func _run() -> void:
	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var main: Control = scene.instantiate()
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/world_ui_%s.db" % Time.get_ticks_usec())
	main.store_path_override = path
	root.add_child(main)
	# 隔离模块：地图选择不应更改权威世界状态。
	var before_map: Dictionary = main.world.snapshot()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.town_map.world_to_screen(Vector2(0, 256))
	main.town_map._gui_input(click)
	var map_safe: bool = before_map == main.world.snapshot() and main.map_info.text.contains("(8,8)")
	# 区域验收：切换会清理未确认施工，关闭视图或尝试进入锁定区域不会写世界。
	var city_zoom: float = main.town_map.zoom_level
	main._start_preview(load("res://data/buildings/house.tres"))
	main.region_toggle.pressed.emit()
	var overview: Control = main.region_overview
	overview.scout_shortcut.pressed.emit()
	var scout_entry_visible: bool = overview.scout_button.is_visible_in_tree() and overview.scout_button.disabled
	scout_entry_visible = scout_entry_visible and overview.detail.text.contains("现役士兵")
	scout_entry_visible = scout_entry_visible and overview.scout_row.get_index() < overview.board.get_index()
	overview.enter_button.pressed.emit()
	var region_safe: bool = scout_entry_visible and overview.visible and not main.town_view.visible \
		and main.town_map.active_definition == null and overview.enter_button.disabled \
		and not overview.markers.has("r_fort") and before_map == main.world.snapshot()
	overview.markers["r_home"].pressed.emit()
	overview.enter_button.pressed.emit()
	region_safe = region_safe and main.town_view.visible and not overview.visible \
		and main.town_map.zoom_level == city_zoom and before_map == main.world.snapshot()
	main._toggle_pause()
	main.clock.advance(120.0)
	main._toggle_pause()
	main._save()
	main.world.resources["gold"] = 999
	main._load()
	var passed: bool = region_safe and map_safe and main.world.current_day() == 2 and main.world.resources["food"] == 165 and main.world.resources["gold"] == 320 and main.world.paused and main.resource_label.text.contains("320")
	passed = _check_scout(main) and passed
	main.free()
	DirAccess.remove_absolute(path)
	if not passed:
		push_error("战略界面保存读取联动失败")
	else:
		print("WORLD_UI_PASS: scene, regions, scouting, march, battle, pause, save, load, resource display")
	quit(0 if passed else 1)


# 侦察验收：真实界面派遣，检查扣费、兵员锁定、跨读档计时和揭示。
func _check_scout(main: Control) -> bool:
	Build.execute(main.world, "b_barracks", Vector2i(2, 4), "scout-camp")
	main.world.paused = false
	main.clock.advance(80)
	var recruitment: Dictionary = Army.recruit(main.world, "building_000002", "scout-troop")
	if not recruitment["ok"]:
		return false
	main.clock.advance(60)
	main.world.paused = true
	var id: String = Legions.create(main.world, "scout-legion")["legion_id"]
	var troop: String = recruitment["troop_id"]
	Legions.set_count(main.world, id, troop, 2)
	main.region_toggle.pressed.emit()
	var overview: Control = main.region_overview
	overview.markers[Scout.WOODS].pressed.emit()
	var food: int = main.world.resources["food"]
	main.world.resources["food"] = 1
	overview.sync(main.world)
	overview.scout_button.pressed.emit()
	if not overview.scout_button.disabled or not main.world.woods_scout.is_empty() or main.world.resources["food"] != 1:
		return false
	main.world.resources["food"] = food
	overview.sync(main.world)
	overview.scout_button.pressed.emit()
	overview.scout_button.pressed.emit()
	if main.world.resources["food"] != food - 2 or not Scout.busy(main.world, id) or overview.scout_button.text != "侦察进行中":
		return false
	if Legions.set_count(main.world, id, troop, 0)["ok"] or Legions.dissolve(main.world, id)["ok"] or Disband.quote(main.world, troop)["ok"]:
		return false
	main.clock.advance(120)
	if not Scout.busy(main.world) or overview.markers.has(Scout.FORT):
		return false
	main._save()
	main._load()
	if not Scout.busy(main.world) or main.world.resources["food"] != food - 2:
		return false
	main.world.paused = false
	main.clock.advance(119)
	overview.sync(main.world)
	if overview.markers.has(Scout.FORT) or not overview.detail.text.contains("1 战略秒"):
		return false
	main.clock.advance(1)
	main.world.paused = true
	overview.sync(main.world)
	if not Scout.complete(main.world) or not overview.markers.has(Scout.FORT) or overview.scout_button.text != "侦察已完成" or not Disband.quote(main.world, troop)["ok"]:
		return false
	if not _check_march(main, id, troop) or not _check_battle(main, id, troop):
		return false
	Legions.dissolve(main.world, id)
	main._save()
	main._load()
	if not Scout.complete(main.world) or not overview.markers.has(Scout.FORT):
		return false
	var legacy: Dictionary = main.world.snapshot()
	legacy["version"] = 13
	legacy.erase("woods_scout")
	var migrated: RefCounted = State.from_snapshot(legacy)
	return migrated != null and migrated.woods_scout.is_empty()


# 行军验收：用真实面板往返，验证途中存档、驻地、锁定、旧档迁移与返回解锁。
func _check_march(main: Control, legion_id: String, troop_id: String) -> bool:
	var overview: Control = main.region_overview
	if not overview.march_button.is_visible_in_tree() or overview.march_button.disabled:
		return false
	if March.dispatch(main.world, legion_id, Scout.FORT):
		return false
	var food: int = main.world.resources["food"]
	overview.march_button.pressed.emit()
	overview.march_button.pressed.emit()
	if March.remaining(main.world, legion_id) != 120 or main.world.resources["food"] != food:
		return false
	if Legions.set_count(main.world, legion_id, troop_id, 0)["ok"] or Disband.quote(main.world, troop_id)["ok"]:
		return false
	main.world.paused = false
	main.clock.advance(60)
	main.world.paused = true
	main._save()
	main._load()
	if March.remaining(main.world, legion_id) != 60 or not overview.detail.text.contains("剩余 60"):
		return false
	var legacy: Dictionary = main.world.snapshot()
	legacy["version"] = 14
	legacy.erase("legion_trips")
	var migrated: RefCounted = State.from_snapshot(legacy)
	if migrated == null or not migrated.legion_trips.is_empty() or not Scout.complete(migrated):
		return false
	main.world.paused = false
	main.clock.advance(60)
	main.world.paused = true
	overview.sync(main.world)
	if not March.away(main.world, legion_id) or overview.march_button.text != "调回边境镇":
		return false
	if Legions.dissolve(main.world, legion_id)["ok"]:
		return false
	main._save()
	main._load()
	if not overview.detail.text.contains("驻地为北部林地"):
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	return main.world.legion_trips.is_empty() and Disband.quote(main.world, troop_id)["ok"] \
		and overview.march_button.text == "前往北部林地"


# 遭遇验收：验证出战位置、失利、战中读档、胜利归属和回城后的战果。
func _check_battle(main: Control, legion_id: String, troop_id: String) -> bool:
	var overview: Control = main.region_overview
	if Battle.start(main.world, legion_id) or not overview.battle_button.disabled:
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	overview.battle_button.pressed.emit()
	if not Battle.busy(main.world, legion_id) or not overview.march_button.disabled:
		return false
	main.world.paused = false
	main.clock.advance(160)
	main.world.paused = true
	overview.sync(main.world)
	if Battle.report(main.world)["status"] != "defeat":
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	var reinforcement: Dictionary = Army.recruit(main.world, "building_000002", "woods-reinforcement")
	if not reinforcement["ok"]:
		return false
	main.clock.advance(60)
	main.world.paused = true
	if not Legions.set_count(main.world, legion_id, troop_id, 5)["ok"]:
		return false
	if not Legions.set_count(main.world, legion_id, reinforcement["troop_id"], 5)["ok"]:
		return false
	overview.sync(main.world)
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	overview.battle_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(8)
	main.world.paused = true
	var battle_before: Dictionary = Battle.report(main.world)
	if battle_before["status"] != "running" or battle_before["allies"] >= 100:
		return false
	main._save()
	main._load()
	if Battle.report(main.world) != battle_before:
		return false
	main.world.paused = false
	main.clock.advance(160)
	main.world.paused = true
	overview.sync(main.world)
	if Battle.report(main.world)["status"] != "victory" or not overview.detail.text.contains("己方控制"):
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	return main.world.legion_trips.is_empty() and Battle.report(main.world)["status"] == "victory"
