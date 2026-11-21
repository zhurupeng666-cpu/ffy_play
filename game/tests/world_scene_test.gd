## 文件用途：在隔离数据库上验证战略面板加载、暂停按钮与保存读取后的界面同步。
extends SceneTree


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
	overview.markers["r_woods"].pressed.emit()
	overview.enter_button.pressed.emit()
	var region_safe: bool = overview.visible and not main.town_view.visible \
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
	main.free()
	DirAccess.remove_absolute(path)
	if not passed:
		push_error("战略界面保存读取联动失败")
	else:
		print("WORLD_UI_PASS: scene, regions, pause, save, load, resource display")
	quit(0 if passed else 1)
