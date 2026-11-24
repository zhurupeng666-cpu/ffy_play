## 文件用途：绘制城镇等距地图，处理高亮选格、镜头拖动和鼠标中心缩放。
extends Control

signal hovered_changed(cell: Vector2i)
signal selected_changed(cell: Vector2i)
signal view_changed
signal placement_changed(result: Dictionary)
signal placement_clicked(result: Dictionary)
signal placement_cancelled

const Art = preload("res://scripts/town_art.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Construction = preload("res://scripts/construction_service.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Grid = preload("res://scripts/isometric_grid.gd")

# 视图状态模块：镜头与选格属于界面状态，不写入战略存档。
var zoom_level: float = 0.5
var fitting_overview: bool = true
var pan_offset: Vector2 = Vector2.ZERO
var hovered: Vector2i = Grid.INVALID
var selected: Vector2i = Grid.INVALID
var inspected_building_id: String = ""
var dragging: bool = false

# 建筑视图模块：占用来自世界实例，视图只读并将确认请求交回控制器。
var occupied_cells: Dictionary = {}
var placed_buildings: Array = []
# 点击几何：可见楼体与占地格共同用于选择，楼体以世界坐标缓存。
var drawing_building: String = ""
# 景物动画：每秒重绘约十二次，只在可见地图有完工牧场时运行。
var has_ranch: bool = false
var scenery_time: float = 0.0
var scenery_frame: int = 0
var building_faces: Dictionary = {}
var available_resources: Dictionary = {}
var economy_ready: bool = false
var active_definition: Resource
var preview_result: Dictionary = {}


# 初始化模块：只捕获地图内部鼠标输入，不影响旁侧管理按钮。
func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	set_process(false)
	resized.connect(_on_resized)
	mouse_exited.connect(_on_mouse_exited)


# 景物动画模块：独立推进牧场动物，离开城镇时停止推进。
func _process(delta: float) -> void:
	if not has_ranch or not is_visible_in_tree():
		return
	scenery_time += delta
	var frame: int = floori(scenery_time * 12.0)
	if frame != scenery_frame:
		scenery_frame = frame
		queue_redraw()


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


# 绘制模块：先铺地形和地基，再绘资源与建筑，最后叠加交互反馈。
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182720"))
	var visible_ground: Rect2 = Rect2(screen_to_world(Vector2.ZERO), size / zoom_level).grow(34)
	for y: int in range(Grid.SIZE.y):
		for x: int in range(Grid.SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			if visible_ground.has_point(Grid.cell_to_world(cell)):
				Art.terrain(self, cell, _diamond(cell), Terrain.is_water(cell))
	for record: Dictionary in placed_buildings:
		_draw_foundation(record)
	_draw_map_objects()
	_draw_building_feedback()
	if active_definition != null and Grid.contains(hovered):
		var valid: bool = preview_result.get("ok", false)
		var tint: Color = Color("#51d88580") if valid else Color("#f454508a")
		var edge: Color = Color("#a2f7a5") if valid else Color("#ff8877")
		for cell: Vector2i in preview_result.get("cells", []):
			draw_colored_polygon(_diamond(cell), tint)
			_outline_cell(cell, edge, 1.5)
	if active_definition == null and inspected_building_id.is_empty() and Grid.contains(selected):
		draw_colored_polygon(_diamond(selected), Color("#4bdb8d65"))
	if active_definition == null and Grid.contains(hovered):
		_outline_cell(hovered, Color("#ffd56a"), 2.0)


# 格线模块：在美术上方绘制悬停、选区与建造预览边界。
func _outline_cell(cell: Vector2i, color: Color, width: float) -> void:
	var outline: PackedVector2Array = _diamond(cell)
	outline.append(outline[0])
	draw_polyline(outline, color, width, false)


# 悬停模块：仅在目标格改变时通知管理界面。
func _update_hover(point: Vector2) -> void:
	var cell: Vector2i = cell_at(point)
	if hovered != cell:
		hovered = cell
		hovered_changed.emit(cell)
	_update_preview()
	queue_redraw()


# 墙体和屋顶模块：点到非占地格上的可见楼体时，返回该建筑的锚点。
func _selection_at(point: Vector2) -> Vector2i:
	var ground: Vector2i = cell_at(point)
	if occupied_cells.has(ground):
		return ground
	var world_point: Vector2 = screen_to_world(point)
	var ids: Array = building_faces.keys()
	ids.reverse()
	for id: String in ids:
		var record: Dictionary = building_faces[id]
		if occupied_cells.get(record["anchor"]) != id:
			continue
		for face: PackedVector2Array in record["faces"]:
			if Geometry2D.is_point_in_polygon(world_point, face):
				return record["anchor"]
	return ground


# 墙面记录模块：只有绘制建筑本体时登记轮廓，地形和占地不重复登记。
func remember_building_face(face: PackedVector2Array) -> void:
	if not drawing_building.is_empty():
		building_faces[drawing_building]["faces"].append(face)


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
				selected = _selection_at(event.position) if event.button_index == MOUSE_BUTTON_LEFT else Grid.INVALID
				selected_changed.emit(selected)
				if event.button_index == MOUSE_BUTTON_LEFT and event.double_click and not inspected_building_id.is_empty():
					_focus_building(inspected_building_id)
		_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			fitting_overview = false
			pan_offset += event.relative
			view_changed.emit()
		_update_hover(event.position)


# 释放模块：即使鼠标在地图外松开中键，也结束拖动避免黏住镜头。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		dragging = false
		mouse_default_cursor_shape = Control.CURSOR_CROSS


# 聚焦模块：双击后原地放大整座建筑，把地块与建筑上方留白居中。
func _focus_building(id: String) -> void:
	for record: Dictionary in placed_buildings:
		if record["id"] != id:
			continue
		var center: Vector2 = _building_center(record) - Vector2(0, 18)
		var footprint: Vector2i = Catalog.find(record["def_id"]).get("footprint")
		var span: float = float(footprint.x + footprint.y) * Grid.HALF.x
		fitting_overview = false
		zoom_level = clampf(minf((size.x - 30.0) / span, (size.y - 24.0) / (span * 0.5 + 42.0)), 0.5, 3.2)
		pan_offset = (Grid.center() - center) * zoom_level
		view_changed.emit()
		queue_redraw()
		return


# 缩放模块：保持鼠标所指世界位置固定，倍率限制在50%至800%。
func _apply_zoom(mouse: Vector2, factor: float) -> void:
	var anchor: Vector2 = screen_to_world(mouse)
	fitting_overview = false
	zoom_level = clampf(zoom_level * factor, 0.5, 8.0)
	pan_offset = mouse - size * 0.5 - (anchor - Grid.center()) * zoom_level
	_update_hover(mouse)
	view_changed.emit()


# 复位模块：镜头回到地图中心，保留用户已经选中的地块。
func reset_view() -> void:
	fitting_overview = true
	zoom_level = _overview_zoom()
	pan_offset = Vector2.ZERO
	dragging = false
	_update_hover(get_local_mouse_position())
	view_changed.emit()


# 总览尺度模块：用完整菱形宽高适应窗口，保留一圈画面边距。
func _overview_zoom() -> float:
	var span: Vector2 = float(Grid.SIZE.x + Grid.SIZE.y) * Grid.HALF
	var available: Vector2 = size - Vector2(32, 36)
	return clampf(minf(available.x / span.x, available.y / span.y), 0.5, 0.75)


# 尺寸模块：总览模式适应变化，手动拖动或缩放后保留镜头。
func _on_resized() -> void:
	if fitting_overview:
		zoom_level = _overview_zoom()
		view_changed.emit()
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
	has_ranch = false
	for record: Dictionary in placed_buildings:
		has_ranch = has_ranch or (record["def_id"] == "b_ranch" and record["state"] == "ready")
		var definition: Resource = Catalog.find(record["def_id"])
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		for cell: Vector2i in Placement.footprint_cells(anchor, definition.get("footprint")):
			occupied_cells[cell] = record["id"]
	set_process(has_ranch)
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


# 地基模块：按真实占地上色，工地与已完工建筑使用不同地面。
func _draw_foundation(record: Dictionary) -> void:
	var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
	var footprint: Vector2i = Catalog.find(record["def_id"]).get("footprint")
	var constructing: bool = record["state"] == "constructing"
	var tint: Color = Color("#826340") if constructing else Color("#73664a")
	if not constructing and record["def_id"] in ["b_farm", "b_ranch"]:
		tint = Color("#786747") if record["def_id"] == "b_farm" else Color("#687343")
	for cell: Vector2i in Placement.footprint_cells(anchor, footprint):
		draw_colored_polygon(_diamond(cell), tint)
		_outline_cell(cell, Color("#473e3288"), 1.0)


# 深度模块：按等距投影纵坐标绘制场景物件，近处覆盖远处。
func _draw_map_objects() -> void:
	var objects: Array[Dictionary] = []
	for y: int in range(Grid.SIZE.y):
		for x: int in range(Grid.SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			var deposit: String = Terrain.deposit_at(cell)
			if not deposit.is_empty():
				objects.append({"center": Grid.cell_to_world(cell), "deposit": deposit})
	for record: Dictionary in placed_buildings:
		objects.append({"center": _building_center(record), "record": record})
	objects.sort_custom(_farther_first)
	building_faces.clear()
	for item: Dictionary in objects:
		var center: Vector2 = item["center"]
		if item.has("deposit"):
			Art.deposit(self, center, item["deposit"])
		elif item["record"]["state"] == "constructing":
			Art.site(self, center)
		else:
			var record: Dictionary = item["record"]
			drawing_building = record["id"]
			building_faces[drawing_building] = {"anchor": Vector2i(int(record["cell"][0]), int(record["cell"][1])), "faces": []}
			Art.building(self, record["def_id"], center, scenery_time)
			drawing_building = ""


# 排序模块：深度相同时按横坐标固定绘制顺序。
func _farther_first(left: Dictionary, right: Dictionary) -> bool:
	var a: Vector2 = left["center"]
	var b: Vector2 = right["center"]
	return a.x < b.x if a.y == b.y else a.y < b.y


# 坐标模块：美术和名称使用建筑占地的投影中心。
func _building_center(record: Dictionary) -> Vector2:
	var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
	var footprint: Vector2i = Catalog.find(record["def_id"]).get("footprint")
	return (Grid.cell_to_world(anchor) + Grid.cell_to_world(anchor + footprint - Vector2i.ONE)) * 0.5


# 标牌模块：在画面顶部叠加建筑名称、施工进度和选中边界。
func _draw_building_feedback() -> void:
	for record: Dictionary in placed_buildings:
		var definition: Resource = Catalog.find(record["def_id"])
		if record["id"] == inspected_building_id:
			var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
			_outline_building(anchor, definition.get("footprint"))
		var label: String = definition.get("display_name")
		if record["state"] == "constructing":
			label += " %d%%" % floori(100.0 * record["work_done"] / record["work_required"])
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var footprint: Vector2i = definition.get("footprint")
		var bottom_offset: float = maxf(28.0, (footprint.x + footprint.y) * Grid.HALF.y * 0.5 * zoom_level + 12.0)
		var baseline: Vector2 = (world_to_screen(_building_center(record)) + Vector2(0, bottom_offset)).round()
		var origin: Vector2 = baseline - Vector2(text_size.x * 0.5, 0)
		draw_rect(Rect2(origin - Vector2(5, 14), Vector2(text_size.x + 10, 18)), Color("#202720dd"))
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#fff0cc"))


# 整圈描边模块：由占地四角组成一个轮廓，画面不会在场内逐格描金。
func _outline_building(anchor: Vector2i, footprint: Vector2i) -> void:
	var top: Vector2 = Grid.cell_to_world(anchor) - Vector2(0, Grid.HALF.y)
	var east: Vector2 = Grid.cell_to_world(anchor + Vector2i(footprint.x - 1, 0)) + Vector2(Grid.HALF.x, 0)
	var bottom: Vector2 = Grid.cell_to_world(anchor + footprint - Vector2i.ONE) + Vector2(0, Grid.HALF.y)
	var west: Vector2 = Grid.cell_to_world(anchor + Vector2i(0, footprint.y - 1)) - Vector2(Grid.HALF.x, 0)
	var outline: PackedVector2Array = []
	for point: Vector2 in [top, east, bottom, west, top]:
		outline.append(world_to_screen(point))
	draw_polyline(outline, Color("#ffd56a"), 3.0, false)


# 详情高亮模块：仅保存界面选中ID，不改变占地或建筑实例数据。
func highlight_building(id: String) -> void:
	inspected_building_id = id
	queue_redraw()
