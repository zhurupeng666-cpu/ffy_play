## 文件用途：绘制城镇等距地图，处理建筑点选、方向键镜头和鼠标中心缩放。
extends Control

signal hovered_changed(cell: Vector2i)
signal building_selected(id: String)
signal view_changed
signal placement_changed(result: Dictionary)
signal placement_clicked(result: Dictionary)
signal placement_cancelled

const Art = preload("res://scripts/town_art.gd")
const WorksiteArt = preload("res://scripts/town_worksite_art.gd")
const CompoundArt = preload("res://scripts/town_compound_art.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Construction = preload("res://scripts/construction_service.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Grid = preload("res://scripts/isometric_grid.gd")
const Sites = preload("res://scripts/region_sites.gd")
const Scout = preload("res://scripts/region_scout.gd")
const Field = preload("res://scripts/woods_battle.gd")
const Siege = preload("res://scripts/fort_siege.gd")
const GROUND_SHADER = preload("res://scripts/town_ground.gdshader")
const PAN_KEYS: Dictionary = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
const PAN_SPEED: float = 420.0
static var terrain_texture: ImageTexture
static var deposit_models: Array[Dictionary] = []

# 视图状态模块：镜头与选格属于界面状态，不写入战略存档。
var zoom_level: float = 0.5
var fitting_overview: bool = true
var fitting_region_cell: Vector2i = Grid.INVALID
var showing_entire_map: bool = false
const MIN_ZOOM: float = 0.025
var pan_offset: Vector2 = Vector2.ZERO
var hovered: Vector2i = Grid.INVALID
var inspected_building_id: String = ""
var held_directions: Dictionary = {}
var ground: ColorRect
var ground_material: ShaderMaterial
var region_sites: Dictionary = {}
var site_buildings: Dictionary = {}
var site_cells: Dictionary = {}
var overview_only: bool = false

# 建筑视图模块：占用来自世界实例，视图只读并将确认请求交回控制器。
var occupied_cells: Dictionary = {}
var placed_buildings: Array = []
# 点击几何：可见楼体与占地格共同用于选择，楼体以世界坐标缓存。
var drawing_building: String = ""
# 景物动画：在地图中低频重画按岗位分配的工人、牲畜与训练单位。
var yard_counts_by_barracks: Dictionary = {}
var staff_by_site: Dictionary = {}
var scenery_time: float = 0.0
var has_ranch: bool = false
var has_fishery: bool = false
var scenery_frame: int = 0
var building_faces: Dictionary = {}
# 绘图分层：固定地貌、活动单位、交互标记分别失效更新。
var static_layer: Node2D
var static_patches: Array[Dictionary] = []
var static_dirty: bool = true
const STATIC_PATCH_LIMIT: int = 5
const INACTIVE_PATCH_POSITION := Vector2(20000000, 20000000)
var art_world_space: bool = false
var work_areas: Dictionary = {}
var equipment_cells: Dictionary = {}
var motion_layer: Control
var art_canvas: CanvasItem
var animated_objects: Array[Dictionary] = []
var art_origin: Vector2 = Vector2.ZERO
var art_scale: float = 1.0
const CAMERA_BUFFER: float = 168.0
var available_resources: Dictionary = {}
var economy_ready: bool = false
var active_definition: Resource
var preview_result: Dictionary = {}


# 初始化模块：只捕获地图内部鼠标输入，不影响旁侧管理按钮。
func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE if overview_only else Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_make_ground()
	static_layer = Node2D.new()
	static_layer.show_behind_parent = true
	add_child(static_layer)
	motion_layer = _make_map_layer(_draw_motion)
	_fit_camera()
	_redraw_scene()
	if overview_only:
		set_process(false)
		set_process_input(false)
		set_process_unhandled_key_input(false)
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
	ground_material.set_shader_parameter("west_river_span", Vector2(Terrain.river_span(0)))
	ground_material.set_shader_parameter("east_river_span", Vector2(Terrain.river_span(Grid.SIZE.x - 1)))
	for id: String in Sites.IDS:
		var bounds: Rect2i = Sites.bounds(id)
		var parameter: String = "woods_site" if id == Scout.WOODS else "fort_site"
		ground_material.set_shader_parameter(parameter, Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
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


# 镜头变换：已有静态指令以世界坐标保留，只有视窗越出缓存范围才补画。
func _redraw_scene() -> void:
	_update_ground_camera()
	static_layer.position = world_to_screen(Vector2.ZERO)
	static_layer.scale = Vector2.ONE * zoom_level
	_use_static_patch(_world_viewport())
	motion_layer.queue_redraw()
	queue_redraw()


# 静景缓存：保留最近去过的区域，可从全览、主城和资源区来回跳转。
func _use_static_patch(view: Rect2) -> void:
	if static_dirty:
		for previous: Dictionary in static_patches:
			previous["node"].free()
		static_patches.clear()
		static_dirty = false
	var decorate: bool = zoom_level >= 0.085
	var best: int = -1
	var width: float = INF
	for i: int in range(static_patches.size()):
		var patch: Dictionary = static_patches[i]
		var coverage: Rect2 = patch["coverage"]
		if patch["decorate"] == decorate and coverage.encloses(view) and coverage.size.x < minf(width, view.size.x * 4.0):
			best = i
			width = coverage.size.x
	# 保留离屏画布的绘制指令，回访时直接平移回来。
	if not static_patches.is_empty() and best != static_patches.size() - 1:
		static_patches[-1]["node"].position = INACTIVE_PATCH_POSITION
	var current: Dictionary
	if best < 0:
		var node := Node2D.new()
		static_layer.add_child(node)
		var motion: Array[Dictionary] = []
		current = {"node": node, "coverage": view.grow(CAMERA_BUFFER / zoom_level), "decorate": decorate, "faces": {}, "motion": motion}
		node.draw.connect(_draw_static_map.bind(current))
	else:
		current = static_patches.pop_at(best)
	static_patches.append(current)
	if static_patches.size() > STATIC_PATCH_LIMIT:
		var oldest: Dictionary = static_patches.pop_front()
		oldest["node"].free()
	building_faces = current["faces"]
	animated_objects = current["motion"]
	current["node"].position = Vector2.ZERO


# 视窗换算：地形、静态几何和可见性使用同一世界坐标系。
func _world_viewport() -> Rect2:
	return Rect2(screen_to_world(Vector2.ZERO), size / zoom_level)


# 美术坐标模块：放大建筑模型或资源造型，保持地面投影和逻辑占地。
func art_point(world_point: Vector2) -> Vector2:
	var point: Vector2 = art_origin + (world_point - art_origin) * art_scale
	return point if art_world_space else world_to_screen(point)


# 笔画比例：缓存几何的线宽用世界单位，活动层随当前镜头缩放。
func art_zoom() -> float:
	return 1.0 if art_world_space else zoom_level


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
	if zoom_level < 0.12 or (not has_ranch and not has_fishery and yard_counts_by_barracks.is_empty() and staff_by_site.is_empty()):
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


# 静景缓存：屋顶、场地和器械使用同一批完整世界几何，缩放时保留轮廓。
func _draw_static_map(patch: Dictionary) -> void:
	var prior_faces: Dictionary = building_faces
	var prior_motion: Array[Dictionary] = animated_objects
	building_faces = patch["faces"]
	animated_objects = []
	art_canvas = patch["node"]
	art_world_space = true
	art_scale = 1.0
	var coverage: Rect2 = patch["coverage"]
	for record: Dictionary in placed_buildings:
		if coverage.intersects(_building_bounds(record)):
			_draw_foundation(record)
	for id: String in region_sites:
		var cell: Vector2i = Scout.LAYOUT.regions[id]["position"]
		var span: Vector2 = Grid.HALF * (Sites.EXTENT * 2 + 4)
		var center: Vector2 = Grid.cell_to_world(cell)
		if coverage.intersects(Rect2(center - span, span * 2.0)):
			Sites.draw_ground(self, id)
	for record: Dictionary in site_buildings.values():
		if coverage.intersects(_building_bounds(record)):
			var cell := Vector2i(record["cell"][0], record["cell"][1])
			art_canvas.draw_colored_polygon(_footprint_outline(cell, record["size"], true), Color("#7d7351"))
	_draw_map_objects(coverage, patch["decorate"])
	patch["motion"] = animated_objects
	if patch["node"] != static_patches[-1]["node"]:
		building_faces = prior_faces
		animated_objects = prior_motion
	art_world_space = false
	motion_layer.queue_redraw()


# 交互层：标牌、选区和放置提示无需重新绘制静态建筑。
func _draw() -> void:
	if overview_only:
		return
	_draw_building_feedback()
	_draw_region_site_labels()
	if active_definition != null and Grid.contains(hovered):
		var valid: bool = preview_result.get("ok", false)
		var tint: Color = Color("#51d88580") if valid else Color("#f454508a")
		var edge: Color = Color("#a2f7a5") if valid else Color("#ff8877")
		if not preview_result.get("cells", []).is_empty():
			var corners: PackedVector2Array = _footprint_outline(hovered, active_definition.get("footprint"))
			draw_colored_polygon(corners, tint)
			corners.append(corners[0])
			draw_polyline(corners, edge, 2.0, false)

# 悬停模块：仅在目标格改变时通知管理界面。
func _update_hover(point: Vector2) -> void:
	var cell: Vector2i = cell_at(point)
	if hovered != cell:
		hovered = cell
		hovered_changed.emit(cell)
		_update_preview()
		queue_redraw()


# 建筑命中：优先选中点到的可见立面，再回退到完整占地。
func _selection_at(point: Vector2) -> String:
	var terrain_cell: Vector2i = cell_at(point)
	var own_id: String = occupied_cells.get(terrain_cell, "")
	var site_id: String = site_cells.get(terrain_cell, "")
	var world_point: Vector2 = screen_to_world(point)
	var ids: Array = building_faces.keys()
	ids.reverse()
	for id: String in ids:
		var record: Dictionary = building_faces[id]
		if occupied_cells.get(record["anchor"]) != id and site_cells.get(record["anchor"]) != id:
			continue
		for face: PackedVector2Array in record["faces"]:
			if Geometry2D.is_point_in_polygon(world_point, face):
				return id
	return own_id if not own_id.is_empty() else site_id


# 墙面记录模块：只有绘制建筑本体时登记轮廓，地形和占地不重复登记。
func remember_building_face(face: PackedVector2Array) -> void:
	if not drawing_building.is_empty():
		building_faces[drawing_building]["faces"].append(face)


# 鼠标模块：左键选择建筑，右键取消，滚轮定位缩放；施工模式仍按地格预览。
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
				var id: String = _selection_at(event.position) if event.button_index == MOUSE_BUTTON_LEFT else ""
				highlight_building(id)
				building_selected.emit(id)
				if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					if not id.is_empty():
						_focus_building(id)
					elif zoom_level < 0.23 and Grid.contains(cell_at(event.position)):
						_focus_cell(cell_at(event.position))
		_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_update_hover(event.position)


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


# 镜头平移：越过已知区域后继续移动，只在引擎坐标精度范围内做保护。
func _pan_camera(delta: Vector2) -> void:
	fitting_region_cell = Grid.INVALID
	var center: Vector2 = screen_to_world(size * 0.5) + delta / zoom_level
	var logical := Vector2((center.x / Grid.HALF.x + center.y / Grid.HALF.y) * 0.5, (center.y / Grid.HALF.y - center.x / Grid.HALF.x) * 0.5)
	logical = logical.clamp(-Vector2.ONE * Grid.WORLD_LIMIT, Vector2.ONE * Grid.WORLD_LIMIT)
	center = Vector2((logical.x - logical.y) * Grid.HALF.x, (logical.x + logical.y) * Grid.HALF.y)
	var next_pan: Vector2 = (Grid.center() - center) * zoom_level
	if next_pan.is_equal_approx(pan_offset):
		return
	fitting_overview = false
	pan_offset = next_pan
	_redraw_scene()
	var mouse: Vector2 = get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		_update_hover(mouse)


# 地图导航入口：快速到达分布在主城之外的生产资源。
func visit_site(cell: Vector2i) -> void:
	held_directions.clear()
	_focus_cell(cell)


# 据点导航：按可视范围留出岗楼和名称的空间，定位后仍可自行缩放。
func visit_region_site(cell: Vector2i) -> void:
	held_directions.clear()
	fitting_overview = false
	fitting_region_cell = cell
	_fit_region_site()
	view_changed.emit()
	_redraw_scene()


# 据点取景模块：容器完成布局或改变大小后继续对准整个街区。
func _fit_region_site() -> void:
	var span: Vector2 = Grid.HALF * (Sites.EXTENT * 4 + 2) + Vector2(70, 150)
	var bounds: Vector2 = (size - Vector2(30, 28)) / span
	zoom_level = clampf(minf(bounds.x, bounds.y), 0.06, 0.45)
	pan_offset = (Grid.center() - Grid.cell_to_world(fitting_region_cell)) * zoom_level


# 林矿导航：优先对准附近已建采集场在资源格内的设备，未建时定位资源区。
func visit_work_area(fallback: Vector2i, kind: String) -> void:
	var target: Vector2i = fallback
	var nearest: float = INF
	for area: Dictionary in work_areas.values():
		if area["kind"] != kind or area["sites"].is_empty():
			continue
		var site: Vector2i = area["sites"][0]
		var distance: float = Vector2(site - fallback).length_squared()
		if distance < nearest:
			nearest = distance
			target = site
	visit_site(target)


# 远景导航：双击全览空地可直接回到可逐格建造的局部镜头。
func _focus_cell(cell: Vector2i) -> void:
	fitting_region_cell = Grid.INVALID
	fitting_overview = false
	zoom_level = 0.6
	pan_offset = (Grid.center() - Grid.cell_to_world(cell)) * zoom_level
	view_changed.emit()
	_redraw_scene()


# 聚焦模块：双击后原地放大整座建筑，把地块与建筑上方留白居中。
func _focus_building(id: String) -> void:
	fitting_region_cell = Grid.INVALID
	for record: Dictionary in placed_buildings + site_buildings.values():
		if record["id"] != id:
			continue
		var center: Vector2 = _building_center(record) - Vector2(0, 18)
		var footprint: Vector2i = _building_footprint(record)
		var span: float = float(footprint.x + footprint.y) * Grid.HALF.x
		fitting_overview = false
		zoom_level = clampf(minf((size.x - 30.0) / span, (size.y - 24.0) / (span * 0.5 + 42.0)), 0.24, 3.2)
		pan_offset = (Grid.center() - center) * zoom_level
		view_changed.emit()
		_redraw_scene()
		return


# 缩放模块：保持鼠标所指世界位置固定，倍率限制在2.5%至800%。
func _apply_zoom(mouse: Vector2, factor: float) -> void:
	fitting_region_cell = Grid.INVALID
	var anchor: Vector2 = screen_to_world(mouse)
	fitting_overview = false
	zoom_level = clampf(zoom_level * factor, minf(MIN_ZOOM, _overview_fit_zoom()), 8.0)
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
	fitting_region_cell = Grid.INVALID
	fitting_overview = true
	_fit_camera()
	_update_hover(get_local_mouse_position())
	view_changed.emit()
	_redraw_scene()


# 取景模块：全图适配外围土地，复位则适配原起始城镇范围。
func _fit_camera() -> void:
	var area: Vector2i = _known_area() if showing_entire_map else Grid.STARTER_SIZE
	var span: Vector2 = float(area.x + area.y) * Grid.HALF
	var available: Vector2 = size - Vector2(32, 36)
	zoom_level = _overview_fit_zoom() if showing_entire_map else clampf(minf(available.x / span.x, available.y / span.y), 0.5, 0.75)
	var center: Vector2 = Grid.cell_to_world(area - Vector2i.ONE) * 0.5
	pan_offset = (Grid.center() - center) * zoom_level


# 全图缩放：狭窄地图栏也能缩放回能容纳完整边线的倍率。
func _overview_fit_zoom() -> float:
	var area: Vector2i = _known_area()
	var span: Vector2 = float(area.x + area.y) * Grid.HALF
	var available: Vector2 = size - Vector2(32, 36)
	return clampf(minf(available.x / span.x, available.y / span.y), 0.005, 0.75)


# 总览范围：区域图同时容纳外围据点，城镇全览沿用首府腹地的取景范围。
func _known_area() -> Vector2i:
	var extent: Vector2i = Grid.SIZE
	if overview_only:
		for id: String in Sites.IDS:
			extent = extent.max(Sites.bounds(id).end + Vector2i(8, 8))
	return extent


# 尺寸模块：总览模式适应变化，手动移动或缩放后保留镜头。
func _on_resized() -> void:
	if fitting_overview:
		_fit_camera()
		view_changed.emit()
	elif Grid.contains(fitting_region_cell):
		_fit_region_site()
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


# 据点同步：侦察揭示营地和旧堡，战果决定是否仍有敌方守军。
func sync_region_sites(world: RefCounted) -> void:
	var known: Dictionary = {}
	if Scout.complete(world):
		known[Scout.WOODS] = 0 if Field.report(world)["status"] == "victory" else Scout.LAYOUT.woods_guards
		known[Scout.FORT] = 0 if Siege.report(world)["status"] == "victory" else Scout.LAYOUT.fort_guards
	if known != region_sites:
		if known.keys() != region_sites.keys():
			site_buildings.clear()
			site_cells.clear()
			for id: String in known:
				site_buildings.merge(Sites.buildings(id))
			for record: Dictionary in site_buildings.values():
				var cell := Vector2i(record["cell"][0], record["cell"][1])
				for tile: Vector2i in Placement.footprint_cells(cell, record["size"]):
					site_cells[tile] = record["id"]
			if inspected_building_id.begins_with("r_") and not site_buildings.has(inspected_building_id):
				highlight_building("")
		region_sites = known
		static_dirty = true
		_redraw_scene()


# 据点标牌：只在局部视角显示驻军，与区域总览的名称标记互不叠加。
func _draw_region_site_labels() -> void:
	if zoom_level < 0.065:
		return
	var font: Font = ThemeDB.fallback_font
	for id: String in region_sites:
		var cell: Vector2i = Scout.LAYOUT.regions[id]["position"]
		var baseline: Vector2 = world_to_screen(Grid.cell_to_world(cell) + Vector2(0, -(Sites.EXTENT * 2 + 2) * Grid.HALF.y)).round()
		if not Rect2(Vector2.ZERO, size).has_point(baseline):
			continue
		var guards: int = region_sites[id]
		var label: String = "%s · %s" % [Scout.LAYOUT.regions[id]["title"], "己方控制" if guards == 0 else "守军 %d" % guards]
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var origin: Vector2 = baseline - Vector2(width * 0.5, 0)
		draw_rect(Rect2(origin - Vector2(7, 15), Vector2(width + 14, 21)), Color("#202720ed"))
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#fff0cc"))


# 实例同步模块：从世界传入只读副本，重新推导格表以避免视图与存档各存一份占用。
func sync_buildings(records: Array) -> void:
	var before: Array = placed_buildings
	placed_buildings = records.duplicate(true)
	if _same_layout(before, placed_buildings):
		if before != placed_buildings:
			queue_redraw()
		return
	occupied_cells.clear()
	work_areas.clear()
	equipment_cells.clear()
	has_ranch = false
	has_fishery = false
	for record: Dictionary in placed_buildings:
		has_ranch = has_ranch or (record["def_id"] == "b_ranch" and record["state"] == "ready")
		has_fishery = has_fishery or (record["def_id"] == "b_fishery" and record["state"] == "ready")
		if record["state"] == "ready" and record["def_id"] in ["b_lumber", "b_quarry"]:
			var area: Dictionary = WorksiteArt.resource_area(record, equipment_cells)
			if not area.is_empty():
				work_areas[record["id"]] = area
		var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
		for cell: Vector2i in Placement.footprint_cells(anchor, Catalog.footprint(record)):
			occupied_cells[cell] = record["id"]
	static_dirty = true
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


# 工人同步：岗位调整立刻更新活动层，工地和空岗不创建活动单位。
func sync_worksite_staff(records: Array) -> void:
	var staffed: Dictionary = {}
	for record: Dictionary in records:
		if record["state"] == "ready" and (record["def_id"] in WorksiteArt.TYPES or _has_compound(record)) and int(record["workers"]) > 0:
			staffed[record["id"]] = int(record["workers"])
	if staffed != staff_by_site:
		staff_by_site = staffed
		motion_layer.queue_redraw()


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
	var surface: PackedVector2Array = _footprint_outline(anchor, footprint, true)
	art_canvas.draw_colored_polygon(surface, tint)
	surface.append(surface[0])
	art_canvas.draw_polyline(surface, Color("#473e32aa"), 2.0, false)


# 深度模块：按等距投影纵坐标绘制场景物件，近处覆盖远处。
func _draw_map_objects(visible_objects: Rect2, decorate: bool) -> void:
	var objects: Array[Dictionary] = []
	if decorate:
		var deposit_view: Rect2 = visible_objects.grow(104.0)
		for item: Dictionary in deposit_models:
			if deposit_view.has_point(item["center"]) and not equipment_cells.has(Grid.world_to_cell(item["center"])):
				objects.append(item)
		_append_outer_deposits(objects, deposit_view)
	for record: Dictionary in site_buildings.values():
		if visible_objects.intersects(_building_bounds(record)):
			objects.append({"center": _building_center(record), "site_building": record})
	for area: Dictionary in work_areas.values():
		var sites: Array = area["sites"]
		for role: int in range(sites.size()):
			var position: Vector2 = Grid.cell_to_world(sites[role])
			if visible_objects.grow(160.0).has_point(position):
				objects.append({"center": position, "equipment": area["kind"], "role": role})
	for record: Dictionary in placed_buildings:
		var center: Vector2 = _building_center(record)
		if visible_objects.intersects(_building_bounds(record)):
			objects.append({"center": center, "record": record})
	objects.sort_custom(_farther_first)
	building_faces.clear()
	animated_objects.clear()
	for item: Dictionary in objects:
		var center: Vector2 = item["center"]
		if item.has("site_building"):
			var record: Dictionary = item["site_building"]
			drawing_building = record["id"]
			building_faces[drawing_building] = {"anchor": Vector2i(record["cell"][0], record["cell"][1]), "faces": []}
			Sites.draw_building(self, record, center, region_sites[record["region"]])
			drawing_building = ""
		elif item.has("equipment"):
			WorksiteArt.draw_resource_equipment(self, item["equipment"], center, item["role"])
		elif item.has("deposit"):
			Art.deposit(self, center, item["deposit"])
		elif item["record"]["state"] == "constructing":
			Art.site(self, center)
		else:
			var record: Dictionary = item["record"]
			drawing_building = record["id"]
			building_faces[drawing_building] = {"anchor": Vector2i(int(record["cell"][0]), int(record["cell"][1])), "faces": []}
			var spread: float = float(Catalog.footprint(record).x) / float(Catalog.find(record["def_id"]).get("footprint").x)
			var dock: Dictionary = {}
			if record["def_id"] == "b_fishery":
				dock = Terrain.dock_edge(building_faces[drawing_building]["anchor"], Catalog.footprint(record))
				if not dock.is_empty():
					Art.fishing_dock(self, dock["cell"], dock["outward"], center)
			var worksite: bool = record["def_id"] in WorksiteArt.TYPES
			var compound: bool = _has_compound(record)
			if compound:
				CompoundArt.draw_compound(self, record["def_id"], center)
			elif worksite:
				WorksiteArt.draw_site(self, record["def_id"], center)
			else:
				Art.building(self, record["def_id"], center, spread)
			drawing_building = ""
			if compound or worksite or record["def_id"] in ["b_ranch", "b_barracks"]:
				animated_objects.append({
					"center": center, "type": record["def_id"], "id": record["id"], "spread": spread,
					"worksite": worksite, "compound": compound, "bounds": _building_bounds(record), "dock": dock,
				})


# 外围景物：只抽样当前静景缓存覆盖的地块，远处资源由地表纹理表示。
func _append_outer_deposits(objects: Array[Dictionary], view: Rect2) -> void:
	var nw: Vector2i = Grid.world_to_cell(view.position)
	var ne: Vector2i = Grid.world_to_cell(Vector2(view.end.x, view.position.y))
	var sw: Vector2i = Grid.world_to_cell(Vector2(view.position.x, view.end.y))
	var se: Vector2i = Grid.world_to_cell(view.end)
	var step: int = 8
	for x: int in range(nw.x - posmod(nw.x, step), se.x + step, step):
		for y: int in range(ne.y - posmod(ne.y, step), sw.y + step, step):
			var cell := Vector2i(x + posmod(y * 2459 ^ x * 7927, step), y + posmod(x * 601 ^ y * 1789, step))
			if not Grid.contains(cell) or Grid.in_authored_map(cell) or equipment_cells.has(cell) or occupied_cells.has(cell):
				continue
			var center: Vector2 = Grid.cell_to_world(cell)
			if not view.has_point(center):
				continue
			var kind: String = Terrain.deposit_at(cell)
			if not kind.is_empty():
				objects.append({"center": center, "deposit": kind})


# 场地样式：大型场地拥有专用布局，小型旧建筑继续使用匹配尺寸的模型。
func _has_compound(record: Dictionary) -> bool:
	return record["def_id"] in CompoundArt.TYPES and Catalog.footprint(record) == Vector2i(20, 20)


# 世界包围盒：涵盖地基、屋顶和伸出岸线的码头，边缘进入视窗即保留整座建筑。
func _building_bounds(record: Dictionary) -> Rect2:
	var footprint: Vector2 = Vector2(_building_footprint(record))
	var half_span: Vector2 = (footprint.x + footprint.y) * Grid.HALF * 0.5
	var extent: Vector2 = half_span + Vector2(170, 155)
	return Rect2(_building_center(record) - extent, extent * 2.0)


# 动态层：复用静景过滤后的场地，只绘制镜头附近的牲畜、士兵和在岗工人。
func _draw_motion() -> void:
	art_canvas = motion_layer
	if zoom_level < 0.12:
		return
	var view: Rect2 = _world_viewport().grow(65.0)
	for item: Dictionary in animated_objects:
		if not view.intersects(item["bounds"]):
			continue
		var center: Vector2 = item["center"]
		if item["compound"]:
			CompoundArt.draw_activity(self, item["type"], center, scenery_time, staff_by_site.get(item["id"], 0), yard_counts_by_barracks.get(item["id"], Vector2i.ZERO))
		elif item["type"] == "b_fishery":
			var workers: int = staff_by_site.get(item["id"], 0)
			WorksiteArt.draw_fish(self, center, item["dock"], scenery_time)
			if workers > 0:
				WorksiteArt.draw_fishers(self, center, item["dock"], workers, scenery_time)
		elif not item["worksite"]:
			Art.moving_units(self, item["type"], center, scenery_time, yard_counts_by_barracks.get(item["id"], Vector2i.ZERO), item["spread"])
	for id: String in staff_by_site:
		if work_areas.has(id):
			var area: Dictionary = work_areas[id]
			WorksiteArt.draw_resource_workers(self, area, staff_by_site[id], scenery_time, view)


# 排序模块：深度相同时按横坐标固定绘制顺序。
func _farther_first(left: Dictionary, right: Dictionary) -> bool:
	var a: Vector2 = left["center"]
	var b: Vector2 = right["center"]
	return a.x < b.x if a.y == b.y else a.y < b.y


# 占地模块：据点设施独立于首府经济，地图使用其本地尺寸。
func _building_footprint(record: Dictionary) -> Vector2i:
	return record["size"] if record.has("region") else Catalog.footprint(record)


# 名称模块：稳定建筑标识映射到现场标牌与详情标题。
func building_title(id: String) -> String:
	if site_buildings.has(id):
		return site_buildings[id]["title"]
	for record: Dictionary in placed_buildings:
		if record["id"] == id:
			return Catalog.find(record["def_id"]).get("display_name")
	return ""


# 坐标模块：美术和名称使用建筑占地的投影中心。
func _building_center(record: Dictionary) -> Vector2:
	var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
	var footprint: Vector2i = _building_footprint(record)
	return (Grid.cell_to_world(anchor) + Grid.cell_to_world(anchor + footprint - Vector2i.ONE)) * 0.5


# 标牌模块：在画面顶部叠加建筑名称、施工进度和选中边界。
func _draw_building_feedback() -> void:
	for record: Dictionary in placed_buildings + site_buildings.values():
		var selected: bool = record["id"] == inspected_building_id
		var constructing: bool = record.get("state") == "constructing"
		if not selected and (not constructing or zoom_level < 0.14):
			continue
		var footprint: Vector2i = _building_footprint(record)
		if selected:
			var anchor: Vector2i = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
			_outline_building(anchor, footprint)
		var bottom_offset: float = maxf(28.0, (footprint.x + footprint.y) * Grid.HALF.y * 0.5 * zoom_level + 12.0)
		var baseline: Vector2 = (world_to_screen(_building_center(record)) + Vector2(0, bottom_offset)).round()
		if not Rect2(Vector2.ZERO, size).grow(100.0).has_point(baseline):
			continue
		var label: String = building_title(record["id"])
		if constructing:
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
func _footprint_outline(anchor: Vector2i, footprint: Vector2i, in_world: bool = false) -> PackedVector2Array:
	var top: Vector2 = Grid.cell_to_world(anchor) - Vector2(0, Grid.HALF.y)
	var east: Vector2 = Grid.cell_to_world(anchor + Vector2i(footprint.x - 1, 0)) + Vector2(Grid.HALF.x, 0)
	var bottom: Vector2 = Grid.cell_to_world(anchor + footprint - Vector2i.ONE) + Vector2(0, Grid.HALF.y)
	var west: Vector2 = Grid.cell_to_world(anchor + Vector2i(0, footprint.y - 1)) - Vector2(Grid.HALF.x, 0)
	var outline: PackedVector2Array = []
	for point: Vector2 in [top, east, bottom, west]:
		outline.append(point if in_world else world_to_screen(point))
	return outline


# 详情高亮模块：仅保存界面选中ID，不改变占地或建筑实例数据。
func highlight_building(id: String) -> void:
	inspected_building_id = id
	queue_redraw()
