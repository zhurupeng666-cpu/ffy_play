## 文件用途：绘制城镇等距地图，处理高亮选格、方向键镜头和鼠标中心缩放。
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
const GROUND_SHADER = preload("res://scripts/town_ground.gdshader")
const PAN_KEYS: Dictionary = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
const PAN_SPEED: float = 420.0
static var terrain_texture: ImageTexture
static var deposit_models: Array[Dictionary] = []

# 视图状态模块：镜头与选格属于界面状态，不写入战略存档。
var zoom_level: float = 0.5
var fitting_overview: bool = true
var showing_entire_map: bool = false
const MIN_ZOOM: float = 0.025
var pan_offset: Vector2 = Vector2.ZERO
var hovered: Vector2i = Grid.INVALID
var selected: Vector2i = Grid.INVALID
var inspected_building_id: String = ""
var held_directions: Dictionary = {}
var ground: ColorRect
var ground_material: ShaderMaterial

# 建筑视图模块：占用来自世界实例，视图只读并将确认请求交回控制器。
var occupied_cells: Dictionary = {}
var placed_buildings: Array = []
# 点击几何：可见楼体与占地格共同用于选择，楼体以世界坐标缓存。
var drawing_building: String = ""
# 景物动画：每秒重绘约十二次，只在可见地图有完工牧场时运行。
var yard_counts_by_barracks: Dictionary = {}
var scenery_time: float = 0.0
var has_ranch: bool = false
var scenery_frame: int = 0
var building_faces: Dictionary = {}
# 绘图分层：固定地貌、活动单位、交互标记分别失效更新。
var static_layer: Control
var motion_layer: Control
var art_canvas: CanvasItem
var animated_objects: Array[Dictionary] = []
var art_origin: Vector2 = Vector2.ZERO
var art_scale: float = 1.0
const CAMERA_BUFFER: float = 168.0
var rendered_pan: Vector2 = Vector2.ZERO
var rendered_motion_pan: Vector2 = Vector2.ZERO
var available_resources: Dictionary = {}
var economy_ready: bool = false
var active_definition: Resource
var preview_result: Dictionary = {}


# 初始化模块：只捕获地图内部鼠标输入，不影响旁侧管理按钮。
func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_make_ground()
	static_layer = _make_map_layer(_draw_static_map)
	motion_layer = _make_map_layer(_draw_motion)
	_fit_camera()
	_update_ground_camera()
	resized.connect(_on_resized)
	mouse_exited.connect(_on_mouse_exited)


# 地表缓存：四通道存储水域、深浅、矿林和岸滩，所有视角共用同一张地形纹理。
func _make_ground() -> void:
	if terrain_texture == null:
		var bitmap := Image.create(Grid.SIZE.x, Grid.SIZE.y, false, Image.FORMAT_RGBA8)
		for x: int in range(Grid.SIZE.x):
			var span: Vector2i = Terrain.river_span(x)
			for y: int in range(Grid.SIZE.y):
				var cell := Vector2i(x, y)
				var water: bool = y >= span.x and y <= span.y
				var depth: float = clampf(mini(y - span.x, span.y - y) / 12.0, 0.0, 1.0)
				var ridge: String = Terrain.deposit_at(cell)
				var natural: float = 1.0 if ridge == "stone" else (0.5 if ridge == "forest" else 0.0)
				var sand: bool = not water and (absi(y - span.x) <= 1 or absi(y - span.y) <= 1)
				bitmap.set_pixel(x, y, Color(float(water), depth, natural, float(sand)))
				if natural > 0.0 and posmod((x * 7927) ^ (y * 2459) ^ (x * y * 13), 13) == 0:
					deposit_models.append({"center": Grid.cell_to_world(cell), "deposit": ridge})
		terrain_texture = ImageTexture.create_from_image(bitmap)
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.show_behind_parent = true
	add_child(ground)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("terrain_mask", terrain_texture)
	ground_material.set_shader_parameter("depth_mask", terrain_texture)
	ground_material.set_shader_parameter("map_extent", Vector2(Grid.SIZE))
	ground_material.set_shader_parameter("half_cell", Grid.HALF)
	ground.material = ground_material


# 地表镜头：移动和缩放只更新采样坐标，纹理本身无需重建。
func _update_ground_camera() -> void:
	ground_material.set_shader_parameter("world_origin", screen_to_world(Vector2.ZERO))
	ground_material.set_shader_parameter("world_extent", size / zoom_level)
	ground_material.set_shader_parameter("zoom", zoom_level)


# 画布模块：两张独立图层绘制在选区提示下方。
func _make_map_layer(draw_callback: Callable) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.show_behind_parent = true
	add_child(layer)
	layer.draw.connect(draw_callback)
	return layer


# 失效模块：视角变化会更新三层，仅悬停和动画各自重画所需层。
func _redraw_scene() -> void:
	_update_ground_camera()
	static_layer.position = Vector2.ZERO
	motion_layer.position = Vector2.ZERO
	static_layer.queue_redraw()
	motion_layer.queue_redraw()
	queue_redraw()


# 美术坐标模块：放大建筑模型或资源造型，保持地面投影和逻辑占地。
func art_point(world_point: Vector2) -> Vector2:
	return world_to_screen(art_origin + (world_point - art_origin) * art_scale).round()


# 每帧镜头：方向键连续移动，景物仍按独立低频节奏更新。
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		held_directions.clear()
		return
	if not held_directions.is_empty():
		var direction := Vector2.ZERO
		for arrow: int in held_directions:
			direction += PAN_KEYS[arrow]
		if direction != Vector2.ZERO:
			_pan_camera(direction.normalized() * PAN_SPEED * minf(delta, 0.05))
	if zoom_level < 0.23 or (not has_ranch and yard_counts_by_barracks.is_empty()):
		return
	scenery_time += delta
	var frame: int = floori(scenery_time * 12.0)
	if frame != scenery_frame:
		scenery_frame = frame
		if not animated_objects.is_empty():
			motion_layer.queue_redraw()


# 画面变换模块：将世界坐标转换到地图控件内部，不移动管理界面。
func world_to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + pan_offset + (point - Grid.center()) * zoom_level


# 输入变换模块：反解镜头变换，保证平移或缩放后仍能正确选格。
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


# 静景模块：只有镜头或建筑布局变化时才重画地貌与建筑。
func _draw_static_map() -> void:
	art_canvas = static_layer
	rendered_pan = pan_offset
	var visible_objects: Rect2 = Rect2(screen_to_world(Vector2.ZERO), size / zoom_level).grow(CAMERA_BUFFER / zoom_level)
	for record: Dictionary in placed_buildings:
		if visible_objects.grow(_building_radius(record)).has_point(_building_center(record)):
			_draw_foundation(record)
	_draw_map_objects(visible_objects)
	motion_layer.queue_redraw()


# 交互层：标牌、选区和放置提示无需重新绘制静态建筑。
func _draw() -> void:
	_draw_building_feedback()
	if active_definition != null and Grid.contains(hovered):
		var valid: bool = preview_result.get("ok", false)
		var tint: Color = Color("#51d88580") if valid else Color("#f454508a")
		var edge: Color = Color("#a2f7a5") if valid else Color("#ff8877")
		if not preview_result.get("cells", []).is_empty():
			var corners: PackedVector2Array = _footprint_outline(hovered, active_definition.get("footprint"))
			draw_colored_polygon(corners, tint)
			corners.append(corners[0])
			draw_polyline(corners, edge, 2.0, false)
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


# 鼠标模块：左键选格、右键取消；滚轮缩放到鼠标所在位置。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_apply_zoom(event.position, 1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if active_definition != null:
				if event.button_index == MOUSE_BUTTON_RIGHT:
					cancel_preview()
				else:
					_update_hover(event.position)
					_update_preview()
					placement_clicked.emit(preview_result.duplicate(true))
			else:
				selected = _selection_at(event.position) if event.button_index == MOUSE_BUTTON_LEFT else Grid.INVALID
				selected_changed.emit(selected)
				if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					if not inspected_building_id.is_empty():
						_focus_building(inspected_building_id)
					elif zoom_level < 0.23 and Grid.contains(selected):
						_focus_cell(selected)
		_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_update_hover(event.position)


# 模型缓存：短距离平移已绘制画布，超过缓冲边界后才刷新附近模型。
func _shift_scene() -> void:
	var offset: Vector2 = pan_offset - rendered_pan
	if maxf(absf(offset.x), absf(offset.y)) >= CAMERA_BUFFER:
		_redraw_scene()
	else:
		static_layer.position = offset
		motion_layer.position = pan_offset - rendered_motion_pan
		queue_redraw()


# 键盘输入：箭头按下由地图接收，弹窗或输入控件可优先处理按键。
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or not is_visible_in_tree() or not PAN_KEYS.has(event.keycode):
		return
	held_directions[event.keycode] = true
	get_viewport().set_input_as_handled()


# 松键处理：即使焦点已转给管理控件，也不会继续移动镜头。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		held_directions.erase(event.keycode)


# 镜头平移：取景中心限制在地图，短距离平移复用已经绘制的模型。
func _pan_camera(delta: Vector2) -> void:
	var center: Vector2 = screen_to_world(size * 0.5) + delta / zoom_level
	var logical := Vector2((center.x / Grid.HALF.x + center.y / Grid.HALF.y) * 0.5, (center.y / Grid.HALF.y - center.x / Grid.HALF.x) * 0.5)
	logical = logical.clamp(Vector2.ZERO, Vector2(Grid.SIZE - Vector2i.ONE))
	center = Vector2((logical.x - logical.y) * Grid.HALF.x, (logical.x + logical.y) * Grid.HALF.y)
	var next_pan: Vector2 = (Grid.center() - center) * zoom_level
	if next_pan.is_equal_approx(pan_offset):
		return
	fitting_overview = false
	pan_offset = next_pan
	_update_ground_camera()
	_shift_scene()
	var mouse: Vector2 = get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		_update_hover(mouse)


# 地图导航入口：快速到达分布在主城之外的生产资源。
func visit_site(cell: Vector2i) -> void:
	held_directions.clear()
	_focus_cell(cell)


# 远景导航：双击全览空地可直接回到可逐格建造的局部镜头。
func _focus_cell(cell: Vector2i) -> void:
	fitting_overview = false
	zoom_level = 0.6
	pan_offset = (Grid.center() - Grid.cell_to_world(cell)) * zoom_level
	view_changed.emit()
	_redraw_scene()


# 聚焦模块：双击后原地放大整座建筑，把地块与建筑上方留白居中。
func _focus_building(id: String) -> void:
	for record: Dictionary in placed_buildings:
		if record["id"] != id:
			continue
		var center: Vector2 = _building_center(record) - Vector2(0, 18)
		var footprint: Vector2i = Catalog.footprint(record)
		var span: float = float(footprint.x + footprint.y) * Grid.HALF.x
		fitting_overview = false
		zoom_level = clampf(minf((size.x - 30.0) / span, (size.y - 24.0) / (span * 0.5 + 42.0)), 0.20, 3.2)
		pan_offset = (Grid.center() - center) * zoom_level
		view_changed.emit()
		_redraw_scene()
		return


# 缩放模块：保持鼠标所指世界位置固定，倍率限制在2.5%至800%。
func _apply_zoom(mouse: Vector2, factor: float) -> void:
	var anchor: Vector2 = screen_to_world(mouse)
	fitting_overview = false
	zoom_level = clampf(zoom_level * factor, MIN_ZOOM, 8.0)
	pan_offset = mouse - size * 0.5 - (anchor - Grid.center()) * zoom_level
	_update_hover(mouse)
	view_changed.emit()
	_redraw_scene()


# 复位模块：返回边境镇附近，保留已经选中的建筑。
func reset_view() -> void:
	showing_entire_map = false
	_refresh_camera_fit()


# 全图入口：远眺整张建设地图，滚轮可从鼠标位置放大。
func show_entire_map() -> void:
	showing_entire_map = true
	_refresh_camera_fit()


# 镜头刷新：应用总览模式，更新所指地块与界面状态。
func _refresh_camera_fit() -> void:
	fitting_overview = true
	_fit_camera()
	_update_hover(get_local_mouse_position())
	view_changed.emit()
	_redraw_scene()


# 取景模块：全图适配外围土地，复位则适配原起始城镇范围。
func _fit_camera() -> void:
	var area: Vector2i = Grid.SIZE if showing_entire_map else Grid.STARTER_SIZE
	var span: Vector2 = float(area.x + area.y) * Grid.HALF
	var available: Vector2 = size - Vector2(32, 36)
	zoom_level = clampf(minf(available.x / span.x, available.y / span.y), MIN_ZOOM if showing_entire_map else 0.5, 0.75)
	var center: Vector2 = Grid.cell_to_world(area - Vector2i.ONE) * 0.5
	pan_offset = (Grid.center() - center) * zoom_level


# 尺寸模块：总览模式适应变化，手动移动或缩放后保留镜头。
func _on_resized() -> void:
	if fitting_overview:
		_fit_camera()
		view_changed.emit()
	_update_hover(get_local_mouse_position())
	_redraw_scene()


# 离开模块：鼠标移出地图时清除悬停，不清除已有选择。
func _on_mouse_exited() -> void:
	hovered = Grid.INVALID
	hovered_changed.emit(hovered)
	_update_preview()
	queue_redraw()


# 焦点模块：窗口失焦时清除方向键状态。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		held_directions.clear()


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
	var before: Array = placed_buildings
	placed_buildings = records.duplicate(true)
	if _same_layout(before, placed_buildings):
		if before != placed_buildings:
			queue_redraw()
		return
	occupied_cells.clear()
	has_ranch = false
	for record: Dictionary in placed_buildings:
		has_ranch = has_ranch or (record["def_id"] == "b_ranch" and record["state"] == "ready")
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		for cell: Vector2i in Placement.footprint_cells(anchor, Catalog.footprint(record)):
			occupied_cells[cell] = record["id"]
	_update_preview()
	_redraw_scene()


# 布局判定：施工进度与产出信用不改变静景或占地表。
func _same_layout(before: Array, after: Array) -> bool:
	if before.size() != after.size():
		return false
	for index: int in range(before.size()):
		for key: String in ["id", "def_id", "cell", "large", "legacy_large", "state"]:
			if before[index].get(key) != after[index].get(key):
				return false
	return true


# 场地同步：按军营接收留营现役与在训人数，场地为空或离开城镇时节省动画开销。
func sync_yard_counts(current: Dictionary) -> void:
	if current == yard_counts_by_barracks:
		return
	yard_counts_by_barracks = current
	motion_layer.queue_redraw()


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
	var footprint: Vector2i = Catalog.footprint(record)
	var constructing: bool = record["state"] == "constructing"
	var tint: Color = Color("#826340") if constructing else Color("#73664a")
	if not constructing and record["def_id"] in ["b_farm", "b_ranch"]:
		tint = Color("#786747") if record["def_id"] == "b_farm" else Color("#687343")
	if not constructing and record["def_id"] == "b_fishery":
		tint = Color("#867452")
	var surface: PackedVector2Array = _footprint_outline(anchor, footprint)
	static_layer.draw_colored_polygon(surface, tint)
	surface.append(surface[0])
	static_layer.draw_polyline(surface, Color("#473e32aa"), 1.0, false)


# 深度模块：按等距投影纵坐标绘制场景物件，近处覆盖远处。
func _draw_map_objects(visible_objects: Rect2) -> void:
	var objects: Array[Dictionary] = []
	if zoom_level >= 0.23:
		var deposit_view: Rect2 = visible_objects.grow(72)
		for item: Dictionary in deposit_models:
			if deposit_view.has_point(item["center"]):
				objects.append(item)
	for record: Dictionary in placed_buildings:
		var center: Vector2 = _building_center(record)
		if visible_objects.grow(_building_radius(record)).has_point(center):
			objects.append({"center": center, "record": record})
	objects.sort_custom(_farther_first)
	building_faces.clear()
	animated_objects.clear()
	for item: Dictionary in objects:
		var center: Vector2 = item["center"]
		if zoom_level < 0.23:
			static_layer.draw_circle(world_to_screen(center), 3.0, Color("#c8ae7b"))
			continue
		if item.has("deposit"):
			Art.deposit(self, center, item["deposit"])
		elif item["record"]["state"] == "constructing":
			Art.site(self, center)
		else:
			var record: Dictionary = item["record"]
			drawing_building = record["id"]
			building_faces[drawing_building] = {"anchor": Vector2i(int(record["cell"][0]), int(record["cell"][1])), "faces": []}
			var spread: float = float(Catalog.footprint(record).x) / float(Catalog.find(record["def_id"]).get("footprint").x)
			if record["def_id"] == "b_fishery":
				var dock: Dictionary = Terrain.dock_edge(building_faces[drawing_building]["anchor"], Catalog.footprint(record))
				if not dock.is_empty():
					Art.fishing_dock(self, dock["cell"], dock["outward"], center)
			Art.building(self, record["def_id"], center, spread)
			drawing_building = ""
			if record["def_id"] in ["b_ranch", "b_barracks"]:
				animated_objects.append({"center": center, "type": record["def_id"], "id": record["id"], "spread": spread})


# 裁剪半径：纳入场地边缘和大型建筑标高，避免镜头靠近时模型突然出现。
func _building_radius(record: Dictionary) -> float:
	var footprint: Vector2i = Catalog.footprint(record)
	return float(footprint.x + footprint.y) * Grid.HALF.x * 0.5 + 140.0


# 动态层：复用静景过滤后的场地，只绘制当前可见的动物和士兵。
func _draw_motion() -> void:
	art_canvas = motion_layer
	rendered_motion_pan = pan_offset
	if motion_layer.position != Vector2.ZERO:
		motion_layer.position = Vector2.ZERO
	if zoom_level < 0.23:
		return
	var visible_bounds: Rect2 = Rect2(Vector2.ZERO, size).grow(32)
	for item: Dictionary in animated_objects:
		var center: Vector2 = item["center"]
		var bounds: Vector2 = Vector2(116, 64) * float(item["spread"]) * zoom_level
		if not visible_bounds.intersects(Rect2(world_to_screen(center) - bounds, bounds * 2.0)):
			continue
		Art.moving_units(self, item["type"], center, scenery_time, yard_counts_by_barracks.get(item["id"], Vector2i.ZERO), item["spread"])


# 排序模块：深度相同时按横坐标固定绘制顺序。
func _farther_first(left: Dictionary, right: Dictionary) -> bool:
	var a: Vector2 = left["center"]
	var b: Vector2 = right["center"]
	return a.x < b.x if a.y == b.y else a.y < b.y


# 坐标模块：美术和名称使用建筑占地的投影中心。
func _building_center(record: Dictionary) -> Vector2:
	var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
	var footprint: Vector2i = Catalog.footprint(record)
	return (Grid.cell_to_world(anchor) + Grid.cell_to_world(anchor + footprint - Vector2i.ONE)) * 0.5


# 标牌模块：在画面顶部叠加建筑名称、施工进度和选中边界。
func _draw_building_feedback() -> void:
	for record: Dictionary in placed_buildings:
		var definition: Resource = Catalog.find(record["def_id"])
		if zoom_level < 0.25 and record["id"] != inspected_building_id:
			continue
		if record["id"] == inspected_building_id:
			var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
			_outline_building(anchor, Catalog.footprint(record))
		var footprint: Vector2i = Catalog.footprint(record)
		var bottom_offset: float = maxf(28.0, (footprint.x + footprint.y) * Grid.HALF.y * 0.5 * zoom_level + 12.0)
		var baseline: Vector2 = (world_to_screen(_building_center(record)) + Vector2(0, bottom_offset)).round()
		if not Rect2(Vector2.ZERO, size).grow(100.0).has_point(baseline):
			continue
		var label: String = definition.get("display_name")
		if record["state"] == "constructing":
			label += " %d%%" % floori(100.0 * record["work_done"] / record["work_required"])
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var origin: Vector2 = baseline - Vector2(text_size.x * 0.5, 0)
		draw_rect(Rect2(origin - Vector2(5, 14), Vector2(text_size.x + 10, 18)), Color("#202720dd"))
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#fff0cc"))


# 整圈描边模块：由占地四角组成一个轮廓，画面不会在场内逐格描金。
func _outline_building(anchor: Vector2i, footprint: Vector2i) -> void:
	var outline: PackedVector2Array = _footprint_outline(anchor, footprint)
	outline.append(outline[0])
	draw_polyline(outline, Color("#ffd56a"), 3.0, false)


# 投影角点模块：场地描边和远景地貌都使用占地的同一组角点。
func _footprint_outline(anchor: Vector2i, footprint: Vector2i) -> PackedVector2Array:
	var top: Vector2 = Grid.cell_to_world(anchor) - Vector2(0, Grid.HALF.y)
	var east: Vector2 = Grid.cell_to_world(anchor + Vector2i(footprint.x - 1, 0)) + Vector2(Grid.HALF.x, 0)
	var bottom: Vector2 = Grid.cell_to_world(anchor + footprint - Vector2i.ONE) + Vector2(0, Grid.HALF.y)
	var west: Vector2 = Grid.cell_to_world(anchor + Vector2i(0, footprint.y - 1)) - Vector2(Grid.HALF.x, 0)
	var outline: PackedVector2Array = []
	for point: Vector2 in [top, east, bottom, west]:
		outline.append(world_to_screen(point))
	return outline


# 详情高亮模块：仅保存界面选中ID，不改变占地或建筑实例数据。
func highlight_building(id: String) -> void:
	inspected_building_id = id
	queue_redraw()
