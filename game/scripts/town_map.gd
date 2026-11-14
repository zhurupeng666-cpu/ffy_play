## 文件用途：绘制占位等距地图，处理高亮选格、镜头拖动和鼠标中心缩放。
extends Control

signal hovered_changed(cell: Vector2i)
signal selected_changed(cell: Vector2i)
signal view_changed

const Grid = preload("res://scripts/isometric_grid.gd")

# 视图状态模块：镜头与选格属于界面状态，不写入战略存档。
var zoom_level: float = 0.75
var pan_offset: Vector2 = Vector2.ZERO
var hovered: Vector2i = Grid.INVALID
var selected: Vector2i = Grid.INVALID
var dragging: bool = false


# 初始化模块：只捕获地图内部鼠标输入，不影响旁侧管理按钮。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(_on_resized)
	mouse_exited.connect(_on_mouse_exited)


# 画面变换模块：将世界坐标转换到地图控件内部，不移动管理界面。
func world_to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + pan_offset + (point - Grid.center()) * zoom_level


# 输入变换模块：反解镜头变换，保证拖动或缩放后仍能正确选格。
func screen_to_world(point: Vector2) -> Vector2:
	return (point - size * 0.5 - pan_offset) / zoom_level + Grid.center()


# 选格模块：先还原世界坐标，再按逻辑边界过滤无效地块。
func cell_at(point: Vector2) -> Vector2i:
	var cell: Vector2i = Grid.world_to_cell(screen_to_world(point))
	return cell if Grid.contains(cell) else Grid.INVALID


# 菱形模块：根据同一投影生成顶点，避免绘制与反选采用不同格距。
func _diamond(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = Grid.cell_to_world(cell)
	var points: PackedVector2Array = PackedVector2Array()
	for offset: Vector2 in [Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]:
		points.append(world_to_screen(center + offset))
	return points


# 绘制模块：仅在输入或尺寸改变时重绘，纯色地块不代表正式地形美术。
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.12))
	for y: int in range(Grid.SIZE.y):
		for x: int in range(Grid.SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			var points: PackedVector2Array = _diamond(cell)
			var shade: Color = Color(0.22, 0.24, 0.25) if (x + y) % 2 == 0 else Color(0.27, 0.29, 0.30)
			draw_colored_polygon(points, shade)
			points.append(points[0])
			draw_polyline(points, Color(0.40, 0.42, 0.43), 1.0, true)
	if Grid.contains(selected):
		draw_colored_polygon(_diamond(selected), Color(0.25, 0.75, 0.45, 0.75))
	if Grid.contains(hovered):
		var outline: PackedVector2Array = _diamond(hovered)
		outline.append(outline[0])
		draw_polyline(outline, Color(1.0, 0.82, 0.25), 2.0, true)


# 悬停模块：仅在目标格改变时通知管理界面。
func _update_hover(point: Vector2) -> void:
	var cell: Vector2i = cell_at(point)
	if hovered != cell:
		hovered = cell
		hovered_changed.emit(cell)
	queue_redraw()


# 鼠标模块：左键选格、右键取消、中键拖动，滚轮仅缩放地图。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_DRAG if dragging else Control.CURSOR_CROSS
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_apply_zoom(event.position, 1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			selected = cell_at(event.position) if event.button_index == MOUSE_BUTTON_LEFT else Grid.INVALID
			selected_changed.emit(selected)
		_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			pan_offset += event.relative
			view_changed.emit()
		_update_hover(event.position)


# 释放模块：即使鼠标在地图外松开中键，也结束拖动避免黏住镜头。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		dragging = false
		mouse_default_cursor_shape = Control.CURSOR_CROSS


# 缩放模块：保持鼠标所指世界位置固定，倍率限制在50%至200%。
func _apply_zoom(mouse: Vector2, factor: float) -> void:
	var anchor: Vector2 = screen_to_world(mouse)
	zoom_level = clampf(zoom_level * factor, 0.5, 2.0)
	pan_offset = mouse - size * 0.5 - (anchor - Grid.center()) * zoom_level
	_update_hover(mouse)
	view_changed.emit()


# 复位模块：镜头回到地图中心，保留用户已经选中的地块。
func reset_view() -> void:
	zoom_level = 0.75
	pan_offset = Vector2.ZERO
	dragging = false
	_update_hover(get_local_mouse_position())
	view_changed.emit()


# 尺寸模块：窗口变化后重算悬停位置并重绘。
func _on_resized() -> void:
	_update_hover(get_local_mouse_position())


# 离开模块：鼠标移出地图时清除悬停，不清除已有选择。
func _on_mouse_exited() -> void:
	hovered = Grid.INVALID
	hovered_changed.emit(hovered)
	queue_redraw()


# 焦点模块：窗口失焦时停止拖动，防止切换程序后镜头继续移动。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		dragging = false
		mouse_default_cursor_shape = Control.CURSOR_CROSS
