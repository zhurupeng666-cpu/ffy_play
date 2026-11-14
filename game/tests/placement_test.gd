## 文件用途：验证建筑多格占地、红绿预览和取消交互，确保不创建建筑也不扣资源。
extends SceneTree

const Grid = preload("res://scripts/isometric_grid.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Map = preload("res://scripts/town_map.gd")
const House = preload("res://data/buildings/house.tres")
const Farm = preload("res://data/buildings/farm.tres")
var failed: bool = false


# 启动模块：等待场景树就绪，使用独立临时数据库执行界面回归。
func _initialize() -> void:
	call_deferred("_run")


# 断言模块：聚合测试错误并返回明确退出码。
func _check(condition: bool, reason: String) -> void:
	if not condition:
		failed = true
		push_error(reason)


# 规则模块：检查完整占地而非只检查锚点，边缘接触不算重叠。
func _run() -> void:
	var occupied: Dictionary = {Vector2i(6, 6): true}
	var before: Dictionary = occupied.duplicate()
	_check(House.footprint == Vector2i(2, 2) and Farm.footprint == Vector2i(4, 4), "建筑Resource尺寸错误")
	_check(Placement.check(Vector2i(0, 0), House.footprint, occupied)["ok"], "正常住宅被拒绝")
	_check(Placement.check(Vector2i(12, 12), Farm.footprint, occupied)["ok"], "右下边界合法农场被拒绝")
	_check(Placement.check(Vector2i(13, 12), Farm.footprint, occupied)["code"] == "OUT_OF_BOUNDS", "只检查了锚点而未检查完整尺寸")
	_check(Placement.check(Vector2i(-1, 0), House.footprint, occupied)["code"] == "OUT_OF_BOUNDS", "负坐标未拒绝")
	_check(Placement.check(Vector2i(5, 5), House.footprint, occupied)["code"] == "OCCUPIED", "部分重叠未拒绝")
	_check(Placement.check(Vector2i(4, 4), House.footprint, occupied)["ok"], "相邻但不重叠被拒绝")
	_check(Placement.check(Vector2i.ZERO, Vector2i.ZERO, occupied)["code"] == "INVALID_SIZE", "零尺寸未拒绝")
	_check(Placement.check(Vector2i.ZERO, Vector2i(99999, 4), occupied)["code"] == "INVALID_SIZE", "异常尺寸未拒绝")
	_check(occupied == before, "校验修改了占用数据")
	# 视图模块：拖动和缩放后仍以同一逻辑锚点判断，切换尺寸即时生效。
	var map: Control = Map.new()
	map.size = Vector2(600, 400)
	root.add_child(map)
	map.set_preview(House)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	map._gui_input(click)
	_check(map.preview_result.get("ok", false) and map.preview_result["cells"].size() == 4, "住宅预览范围或结果错误")
	map.set_preview(Farm)
	_check(map.preview_result["cells"].size() == 16, "切换农场后占地未更新")
	map.pan_offset += Vector2(50, -30)
	map._apply_zoom(Vector2(200, 150), 1.2)
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(7, 7)))
	map._gui_input(click)
	_check(map.preview_result.get("code") == "OCCUPIED", "移动缩放后重叠判断错误")
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(15, 15)))
	map._gui_input(click)
	_check(map.preview_result.get("code") == "OUT_OF_BOUNDS", "地图边缘预览没有拒绝")
	var occupied_count: int = map.occupied_cells.size()
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	map._gui_input(click)
	map._gui_input(click)
	_check(map.occupied_cells.size() == occupied_count, "重复左键创建了建筑或占用")
	click.button_index = MOUSE_BUTTON_RIGHT
	map._gui_input(click)
	_check(map.active_definition == null, "右键未取消预览")
	map.free()
	# 集成模块：合法与非法点击后世界快照都必须保持不变，Esc只取消当前模式。
	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var main: Control = scene.instantiate()
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/placement_%s.db" % Time.get_ticks_usec())
	main.store_path_override = path
	root.add_child(main)
	var world_before: Dictionary = main.world.snapshot()
	main._start_preview(House)
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = main.town_map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	main.town_map._gui_input(click)
	_check(main.status_label.text.contains("检查通过"), "合法点击缺少反馈")
	click.position = main.town_map.world_to_screen(Grid.cell_to_world(Vector2i(7, 7)))
	main.town_map._gui_input(click)
	_check(main.status_label.text.contains("不可放置"), "重叠点击缺少原因")
	_check(main.world.snapshot() == world_before, "预览改变了资源或日期")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._unhandled_key_input(escape)
	_check(main.town_map.active_definition == null, "Esc没有优先取消预览")
	main.free()
	DirAccess.remove_absolute(path)
	if not failed:
		print("PLACEMENT_PASS: resources, footprint, bounds, overlap, pan, zoom, cancel, no mutation")
	quit(1 if failed else 0)
