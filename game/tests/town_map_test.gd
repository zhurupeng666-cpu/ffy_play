## 文件用途：验证等距投影、反选、缩放锚点、选格和拖动释放，避免镜头变化后点错格。
extends SceneTree

const Grid = preload("res://scripts/isometric_grid.gd")
const Map = preload("res://scripts/town_map.gd")
var failed: bool = false


# 启动模块：在场景树就绪后创建地图控件。
func _initialize() -> void:
	call_deferred("_run")


# 断言模块：收集失败原因，并让测试进程返回失败。
func _check(condition: bool, reason: String) -> void:
	if not condition:
		failed = true
		push_error(reason)


# 坐标验收模块：检查所有格中心与近边界位置的投影往返。
func _run() -> void:
	for y: int in range(Grid.SIZE.y):
		for x: int in range(Grid.SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			var point: Vector2 = Grid.cell_to_world(cell)
			_check(Grid.world_to_cell(point) == cell, "格中心投影不一致")
			_check(Grid.world_to_cell(point + Vector2(0, 15)) == cell, "菱形内点反选错误")
	_check(not Grid.contains(Vector2i(-1, 0)) and not Grid.contains(Vector2i(Grid.SIZE.x, 8)), "接受地图外坐标")
	var map: Control = Map.new()
	map.size = Vector2(600, 400)
	root.add_child(map)
	var cell: Vector2i = Vector2i(8, 8)
	var screen: Vector2 = map.world_to_screen(Grid.cell_to_world(cell))
	_check(map.cell_at(screen) == cell, "默认镜头选格错误")
	map.pan_offset += Vector2(65, -37)
	screen = map.world_to_screen(Grid.cell_to_world(cell))
	_check(map.cell_at(screen) == cell, "拖动后选格错误")
	var anchor: Vector2 = Vector2(280, 170)
	var before: Vector2 = map.screen_to_world(anchor)
	map._apply_zoom(anchor, 1.2)
	_check(map.screen_to_world(anchor).is_equal_approx(before), "缩放未保持鼠标锚点")
	screen = map.world_to_screen(Grid.cell_to_world(cell))
	_check(map.cell_at(screen) == cell, "缩放后选格错误")
	map._apply_zoom(anchor, 100.0)
	_check(is_equal_approx(map.zoom_level, 8.0), "缩放上限错误")
	map._apply_zoom(anchor, 0.001)
	_check(is_equal_approx(map.zoom_level, 0.025), "缩放下限错误")
	# 输入验收模块：左键选择、右键取消、中键在地图外释放和复位。
	map.reset_view()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.world_to_screen(Grid.cell_to_world(cell))
	map._gui_input(click)
	_check(map.selected == cell, "左键选择错误")
	map.pan_offset = Vector2(120, 80)
	map.reset_view()
	var overview: float = (map.size.x - 32.0) / (Grid.HALF.x * (Grid.STARTER_SIZE.x + Grid.STARTER_SIZE.y))
	_check(map.selected == cell and map.screen_to_world(map.size * 0.5).is_equal_approx(Vector2(0, 240)) and is_equal_approx(map.zoom_level, overview), "镜头复位未适配全图或改变选择")
	map.show_entire_map()
	_check(Grid.SIZE == Vector2i(200, 200) and map.cell_at(map.world_to_screen(Grid.cell_to_world(Vector2i(199, 199)))) == Vector2i(199, 199) and map.zoom_level < 0.23, "全览未覆盖扩建地块")
	map.reset_view()
	click.button_index = MOUSE_BUTTON_RIGHT
	map._gui_input(click)
	_check(map.selected == Grid.INVALID, "右键取消选择失败")
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	map._gui_input(click)
	var previous_pan: Vector2 = map.pan_offset
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(50, -25)
	motion.position = click.position + motion.relative
	map._gui_input(motion)
	_check(map.pan_offset.is_equal_approx(previous_pan + motion.relative), "中键拖动未响应鼠标位移")
	click.pressed = false
	map._input(click)
	_check(not map.dragging, "地图外释放后拖动未停止")
	map.dragging = true
	map._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not map.dragging, "失焦后拖动未停止")
	map.free()
	if not failed:
		print("MAP_PASS: projection, bounds, pan, zoom anchor, zoom limits, selection, reset, release")
	quit(1 if failed else 0)
