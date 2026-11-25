## 文件用途：验证投影、方向键、地形缓存和全图切换时的选格一致性。
extends SceneTree

const Grid = preload("res://scripts/isometric_grid.gd")
const Map = preload("res://scripts/town_map.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const CompoundArt = preload("res://scripts/town_compound_art.gd")
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
	_check(map.cell_at(screen) == cell, "平移后选格错误")
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
	# 输入验收模块：左右键选择和取消，镜头复位保留选中对象。
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
	_check(Grid.SIZE == Vector2i(300, 300) and map.cell_at(map.world_to_screen(Grid.cell_to_world(Vector2i(299, 299)))) == Vector2i(299, 299) and map.zoom_level < 0.23, "全览未覆盖扩建地块")
	_chk_compound_paths()
	map.size = Vector2(360, 290)
	map.show_entire_map()
	var screen_bounds := Rect2(Vector2.ZERO, map.size)
	_check(screen_bounds.has_point(map.world_to_screen(Grid.cell_to_world(Vector2i(299, 0)))) and screen_bounds.has_point(map.world_to_screen(Grid.cell_to_world(Vector2i(0, 299)))), "窄视窗全览裁掉地图两端")
	map.size = Vector2(600, 400)
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
	_check(map.pan_offset.is_equal_approx(previous_pan), "中键仍在移动镜头")
	var direction := InputEventKey.new()
	direction.keycode = KEY_RIGHT
	direction.pressed = true
	map._unhandled_key_input(direction)
	var old_center: Vector2 = map.screen_to_world(map.size * 0.5)
	var texture: Texture2D = map.terrain_texture
	map._process(0.02)
	_check(map.screen_to_world(map.size * 0.5).x > old_center.x, "方向键未向右移动镜头")
	_check(map.terrain_texture == texture, "移动时重复创建地形纹理")
	direction.pressed = false
	map._input(direction)
	_check(map.held_directions.is_empty(), "松开方向键后镜头未停止")
	direction.pressed = true
	map._unhandled_key_input(direction)
	map._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(map.held_directions.is_empty(), "失焦后镜头未停止")
	map.show_entire_map()
	map.visit_site(Vector2i(22, 90))
	_check(map.terrain_texture == texture and map.cell_at(map.size * 0.5) == Vector2i(22, 90), "切换视角未复用地形或远景不能定位")
	for district: Dictionary in Terrain.DISTRICTS:
		var bounds: Rect2i = district["bounds"]
		var area: int = 0
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				area += int(Terrain.deposit_at(Vector2i(x, y)) == district["kind"])
		_check(area >= 800 and bounds.position.length() > 50.0, "林矿资源区面积不足或离主城太近")
	_check(Terrain.is_water(Vector2i(100, 110)) and Terrain.is_water(Vector2i(299, 130)) and not Terrain.is_water(Vector2i(6, 1)), "内陆水域未替换旧窄水带")
	map.free()
	if not failed:
		print("MAP_PASS: projection, bounds, pan, zoom anchor, zoom limits, selection, keyboard pan, cache, large terrain")
	quit(1 if failed else 0)


# 大场地验收：养殖动物始终留在各自围栏，20人的操练队列不重叠。
func _chk_compound_paths() -> void:
	for frame: int in range(28):
		for index: int in range(7):
			var cell: Vector2i = Grid.world_to_cell(CompoundArt.pasture_foot(index, frame * 0.4))
			var side: bool = cell.x <= -2 if index < 4 else cell.x >= 2
			_check(side and cell.y >= 0 and cell.y <= 6, "牛羊离开对应围栏")
	var seen: Dictionary = {}
	for index: int in range(20):
		var cell: Vector2i = Grid.world_to_cell(CompoundArt.drill_foot(index, 20, 0.5))
		_check(absi(cell.x) < 8 and cell.y >= 0 and cell.y < 6 and not seen.has(cell), "操练站位重叠或离开场地")
		seen[cell] = true
