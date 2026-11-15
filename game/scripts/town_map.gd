## 文件用途：绘制占位等距地图，处理高亮选格、镜头拖动和鼠标中心缩放。
extends Control

signal hovered_changed(cell: Vector2i)
signal selected_changed(cell: Vector2i)
signal view_changed
signal placement_changed(result: Dictionary)
signal placement_clicked(result: Dictionary)
signal placement_cancelled

const Terrain = preload("res://scripts/town_terrain.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Construction = preload("res://scripts/construction_service.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Grid = preload("res://scripts/isometric_grid.gd")

# 视图状态模块：镜头与选格属于界面状态，不写入战略存档。
var zoom_level: float = 0.75
var pan_offset: Vector2 = Vector2.ZERO
var hovered: Vector2i = Grid.INVALID
var selected: Vector2i = Grid.INVALID
var inspected_building_id: String = ""
var dragging: bool = false

# 建筑视图模块：占用来自世界实例，视图只读并将确认请求交回控制器。
var occupied_cells: Dictionary = {}
var placed_buildings: Array = []
var available_resources: Dictionary = {}
var economy_ready: bool = false
var active_definition: Resource
var preview_result: Dictionary = {}


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
			if preload("res://scripts/town_terrain.gd").is_water(cell):
				shade = Color(0.15, 0.40, 0.65)
			var deposit: String = Terrain.deposit_at(cell)
			if not deposit.is_empty():
				shade = Color(0.16, 0.48, 0.20) if deposit == "forest" else Color(0.63, 0.65, 0.67)
			draw_colored_polygon(points, shade)
			if not deposit.is_empty():
				draw_string(ThemeDB.fallback_font, world_to_screen(Grid.cell_to_world(cell)) + Vector2(-6, 4), "林" if deposit == "forest" else "矿", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			points.append(points[0])
			draw_polyline(points, Color(0.40, 0.42, 0.43), 1.0, true)
	# 占用显示模块：真实建筑的范围由实例推导，并按建筑类型绘制占位块。
	for cell: Vector2i in occupied_cells:
		draw_colored_polygon(_diamond(cell), Color(0.30, 0.38, 0.48, 0.9))
	_draw_buildings()
	if active_definition != null and Grid.contains(hovered):
		var color: Color = Color(0.25, 0.85, 0.4, 0.65) if preview_result.get("ok", false) else Color(0.95, 0.22, 0.2, 0.7)
		for cell: Vector2i in preview_result.get("cells", []):
			draw_colored_polygon(_diamond(cell), color)
	if active_definition == null and inspected_building_id.is_empty() and Grid.contains(selected):
		draw_colored_polygon(_diamond(selected), Color(0.25, 0.75, 0.45, 0.75))
	if active_definition == null and Grid.contains(hovered):
		var outline: PackedVector2Array = _diamond(hovered)
		outline.append(outline[0])
		draw_polyline(outline, Color(1.0, 0.82, 0.25), 2.0, true)


# 悬停模块：仅在目标格改变时通知管理界面。
func _update_hover(point: Vector2) -> void:
	var cell: Vector2i = cell_at(point)
	if hovered != cell:
		hovered = cell
		hovered_changed.emit(cell)
	_update_preview()
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
			if active_definition != null:
				if event.button_index == MOUSE_BUTTON_RIGHT:
					cancel_preview()
				else:
					_update_hover(event.position)
					placement_clicked.emit(preview_result.duplicate(true))
			else:
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
	_update_preview()
	queue_redraw()


# 焦点模块：窗口失焦时停止拖动，防止切换程序后镜头继续移动。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		dragging = false
		mouse_default_cursor_shape = Control.CURSOR_CROSS


# 模式模块：选择静态建筑定义后进入预览，不创建实例或扣材料。
func set_preview(definition: Resource) -> void:
	active_definition = definition
	_update_preview()
	queue_redraw()


# 取消模块：保留普通选格，仅清除建筑预览状态。
func cancel_preview() -> void:
	active_definition = null
	preview_result = {}
	placement_changed.emit({"active": false})
	placement_cancelled.emit()
	queue_redraw()


# 预览校验模块：鼠标离开地图时隐藏占地，进入合法格后检查整个建筑范围。
func _update_preview() -> void:
	if active_definition == null:
		return
	if not Grid.contains(hovered):
		preview_result = {"ok": false, "code": "NO_ANCHOR", "reason": "请将鼠标移到地图内", "cells": []}
	else:
		preview_result = Placement.check_building(hovered, active_definition, occupied_cells)
	if preview_result.get("ok", false) and economy_ready:
		var affordability: Dictionary = Construction.check_cost(active_definition.get("cost"), available_resources)
		if not affordability["ok"]:
			preview_result["ok"] = false
			preview_result["code"] = affordability["code"]
			preview_result["reason"] = affordability["reason"]
		else:
			preview_result["reason"] = "可以建造：左键确认并扣费"
	preview_result["active"] = true
	placement_changed.emit(preview_result)


# 实例同步模块：从世界传入只读副本，重新推导格表以避免视图与存档各存一份占用。
func sync_buildings(records: Array) -> void:
	placed_buildings = records.duplicate(true)
	occupied_cells.clear()
	for record: Dictionary in placed_buildings:
		var definition: Resource = Catalog.find(record["def_id"])
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		for cell: Vector2i in Placement.footprint_cells(anchor, definition.get("footprint")):
			occupied_cells[cell] = record["id"]
	_update_preview()
	queue_redraw()


# 库存同步模块：只在资源变化时刷新可负担提示，不修改世界库存。
func sync_resources(resources: Dictionary) -> void:
	if economy_ready and resources == available_resources:
		return
	economy_ready = true
	available_resources = resources.duplicate()
	_update_preview()
	queue_redraw()


# 建筑绘制模块：用色块和名称表示真实实例，暂不确定正式像素美术。
func _draw_buildings() -> void:
	for record: Dictionary in placed_buildings:
		var definition: Resource = Catalog.find(record["def_id"])
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		var footprint: Vector2i = definition.get("footprint")
		var colors: Dictionary = {"b_lumber": Color(0.26, 0.48, 0.22), "b_quarry": Color(0.48, 0.49, 0.51), "b_granary": Color(0.62, 0.52, 0.22), "b_hall": Color(0.30, 0.38, 0.48), "b_house": Color(0.55, 0.43, 0.29), "b_farm": Color(0.30, 0.47, 0.31), "b_ranch": Color(0.52, 0.46, 0.25), "b_fishery": Color(0.20, 0.52, 0.64)}
		for cell: Vector2i in Placement.footprint_cells(anchor, footprint):
			draw_colored_polygon(_diamond(cell), Color(0.55, 0.45, 0.20) if record["state"] == "constructing" else colors[record["def_id"]])
		if record["id"] == inspected_building_id:
			for cell: Vector2i in Placement.footprint_cells(anchor, footprint):
				var outline: PackedVector2Array = _diamond(cell)
				outline.append(outline[0])
				draw_polyline(outline, Color(1.0, 0.82, 0.25), 2.0, true)
		var center: Vector2 = (Grid.cell_to_world(anchor) + Grid.cell_to_world(anchor + footprint - Vector2i.ONE)) * 0.5
		var label: String = definition.get("display_name")
		if record["state"] == "constructing":
			label += " %d%%" % floori(100.0 * record["work_done"] / record["work_required"])
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(font, world_to_screen(center) + Vector2(-text_size.x * 0.5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


# 详情高亮模块：仅保存界面选中ID，不改变占地或建筑实例数据。
func highlight_building(id: String) -> void:
	inspected_building_id = id
	queue_redraw()
