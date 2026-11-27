## 文件用途：验证投影、方向键、地形缓存和全图切换时的选格一致性。
extends SceneTree

const Grid = preload("res://scripts/isometric_grid.gd")
const Map = preload("res://scripts/town_map.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const CompoundArt = preload("res://scripts/town_compound_art.gd")
const Capital = preload("res://scripts/capital_layout.gd")
const People = preload("res://scripts/resident_sprite_art.gd")
const Walker = preload("res://scripts/capital_walkers.gd")
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
	_check(Grid.contains(Vector2i(-1, -1)) and Grid.contains(Vector2i(Grid.SIZE.x, 8)) and not Grid.contains(Grid.INVALID), "外围格与无效坐标未正确区分")
	var map: Control = Map.new()
	map.size = Vector2(600, 400)
	root.add_child(map)
	map.sync_buildings(preload("res://scripts/world_state.gd").new().buildings)
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
	_check(map.inspected_building_id == "building_000001", "左键未选整栋建筑")
	map.pan_offset = Vector2(120, 80)
	map.reset_view()
	var overview: float = (map.size.x - 32.0) / (Grid.HALF.x * (Grid.STARTER_SIZE.x + Grid.STARTER_SIZE.y))
	_check(map.inspected_building_id == "building_000001" and map.screen_to_world(map.size * 0.5).is_equal_approx(Vector2(0, 240)) and is_equal_approx(map.zoom_level, overview), "镜头复位未适配全图或改变选择")
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
	_check(map.inspected_building_id.is_empty(), "右键取消选择失败")
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	map._gui_input(click)
	_check(map.inspected_building_id.is_empty(), "空地仍可被选中")
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
	# 外围验收：镜头跨过旧边界，地表缓存保持不变，河道两端连续。
	map.visit_site(Vector2i(0, 0))
	map._pan_camera(Vector2(0, -36))
	var outer: Vector2i = map.cell_at(map.size * 0.5)
	_check(outer.x < 0 and outer.y < 0 and map.terrain_texture == texture, "镜头仍被原边界拦截或重建地表")
	map.visit_site(Vector2i(310, 310))
	_check(map.cell_at(map.size * 0.5) == Vector2i(310, 310), "不能定位旧东南边界外的地块")
	_check(Terrain.river_span(-1) == Terrain.river_span(0) and Terrain.river_span(300) == Terrain.river_span(299), "河流在原边界中断")
	_check(Terrain.is_water(Vector2i(-1, 99)) and Terrain.is_water(Vector2i(300, 132)), "河道没有向外围延伸")
	_check(Terrain.deposit_at(Vector2i(-56, -56)) == "forest" and Terrain.deposit_at(Vector2i(380, 380)) == "stone", "外围未生成可采集的林矿")
	for district: Dictionary in Terrain.DISTRICTS:
		var bounds: Rect2i = district["bounds"]
		var area: int = 0
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				area += int(Terrain.deposit_at(Vector2i(x, y)) == district["kind"])
		_check(area >= 800 and bounds.position.length() > 50.0, "林矿资源区面积不足或离主城太近")
	_check(Terrain.is_water(Vector2i(100, 110)) and Terrain.is_water(Vector2i(299, 130)) and not Terrain.is_water(Vector2i(6, 1)), "内陆水域未替换旧窄水带")
	_check_capital(map)
	_check_palace_decor()
	_check_broad_streets(map)
	map.free()
	if not failed:
		print("MAP_PASS: projection, terrain, capital, broad streets, saved entrances, pedestrian routes")
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


# 首府验收：检查河道退界、四门、大宅用地、连路行人和版本往返。
func _check_capital(map: Control) -> void:
	var State = preload("res://scripts/world_state.gd")
	var world: RefCounted = State.new()
	State.HouseEconomy.activate(world, 71342)
	world.capital_layout = true
	var restored: RefCounted = State.from_snapshot(world.snapshot())
	_check(restored != null and restored.capital_layout, "扩建布局未从战略存档恢复")
	_check(Capital.OUTER.size == Vector2i(300,300) and Capital.OUTER.encloses(Capital.INNER), "外城面积错误或皇城越界")
	for x: int in range(Capital.OUTER.position.x, Capital.OUTER.end.x):
		_check(not Terrain.is_water(Vector2i(x,Capital.OUTER.end.y - 1)), "外城南墙进入河道")
	_check(State.Catalog.footprint({"def_id":"b_manor","large":true}) == Vector2i(15,15), "府邸不是15×15")
	map.sync_capital(true,58)
	map.show_entire_map()
	var visible := Rect2(Vector2.ZERO,map.size)
	for record: Array in Capital.GATES.slice(0,4):
		var area: Rect2i = record[2]
		var projected: Vector2 = map.world_to_screen(Grid.cell_to_world(area.get_center()))
		_check(area.get_area() >= 200 and visible.has_point(projected), "外城大门没有完整随地图定位")
	_check(Walker.routes(world,{}).is_empty(),"没有目的地仍出现来回闲逛")
	var farm_market: String = State.DistrictMarket.found(world,Vector2i(18,10),State.Catalog.MARKET)
	var wall: String = State.DistrictMarket.found(world,Vector2i(12,7),State.Catalog.WALL)
	State.Register.sync_people(world)
	for household: Dictionary in world.resident_register:
		household["address"]="building_000001"
	var routes: Array[Dictionary] = Walker.routes(world,{})
	_check(not routes.is_empty(),"有市场和已登记住所仍未生成办事路线")
	for route: Dictionary in routes:
		_check(route["target"]==farm_market and route["activity"]=="buy","住户办事缺少市场目的地")
		for point: Vector2 in route["points"]:
			_check(world.occupied_cells().get(Grid.world_to_cell(point),"")!=wall,"行人路线经过城墙")
	var a: Texture2D = Walker.Pedestrians._texture(0,0,false,false)
	var b: Texture2D = Walker.Pedestrians._texture(0,3,false,false)
	var child: Texture2D = Walker.Pedestrians._texture(3,0,false,false)
	_check(a.get_image().get_data() != b.get_image().get_data() and a.get_image().get_data() != child.get_image().get_data(), "行人步态或身份剪影没有区别")

	var styles: Dictionary = {}
	for role: String in People.ROLES:
		var texture: ImageTexture = People.texture(role,0,false,false)
		var silhouette: Image = texture.get_image()
		var signature: int = hash(silhouette.get_data())
		_check(not styles.has(signature) and silhouette.get_pixel(0,0).a==0.0,"职业造型重复或背景不透明")
		_check(texture==People.texture(role,0,false,false),"滚动地图时重复创建人物帧")
		styles[signature]=true


# 宽街验收：真实占地、完工前限制、四侧门向、预览单一来源及读档。
func _check_broad_streets(map: Control) -> void:
	var state = preload("res://scripts/world_state.gd")
	var build = preload("res://scripts/construction_service.gd")
	var world: RefCounted = state.new()
	state.HouseEconomy.activate(world, 71342)
	world.capital_layout = true
	var anchor := Vector2i(20,10)
	var road: Dictionary = build.execute(world,"b_road",anchor,"wide-road")
	_check(road["ok"] and state.Catalog.footprint(world.buildings.back()) == Vector2i(3,3), "默认道路没有完整占用3×3")
	var house_cell := Vector2i(20,8)
	_check(build.execute(world,"b_house",house_cell,"unready")["code"] == "NEEDS_STREET", "住宅错误接入施工中的道路")
	var record: Dictionary = world.buildings.back()
	record["state"] = "ready"
	record["work_done"] = record["work_required"]
	var ways: Dictionary = build.Streets.network(world.buildings)
	_check(ways.size() == 9 and ways.has(anchor + Vector2i(2,2)), "宽街外缘未加入道路网络")
	var adjacent: Array[Vector2i] = [house_cell,Vector2i(18,10),Vector2i(20,13),Vector2i(23,10)]
	for index: int in range(adjacent.size()):
		_check(build.Streets.direction(adjacent[index],Vector2i(2,2),ways) == index, "住宅门未向对应道路侧")
	map.sync_buildings(world.buildings)
	map.visit_site(house_cell)
	map.hovered = house_cell
	map.set_preview(state.Catalog.HOUSE)
	_check(map.preview_result.get("front") == 0, "施工预览未标出临街入口")
	map.cancel_preview()
	_check(build.execute(world,"b_house",house_cell,"aligned-house")["ok"], "临街住宅无法建造")
	var snapshot: Dictionary = world.snapshot()
	var loaded: RefCounted = state.from_snapshot(snapshot)
	_check(loaded != null and loaded.buildings.back().get("front") == 0, "读档丢失住宅门向")
	snapshot["buildings"].back()["front"] = 4
	_check(state.from_snapshot(snapshot) == null, "坏档可以注入无效门向")


# 宫苑验收：陈设边界、重叠禁止、布置存档以及城内资源清除同步。
func _check_palace_decor() -> void:
	var State = preload("res://scripts/world_state.gd")
	var courts = State.Courts
	var world: RefCounted = State.new()
	State.HouseEconomy.activate(world, 71342)
	world.capital_layout = true
	var useful := Vector2i(131,-145)
	_check(courts.can_place(world.palace_decor,0,4,useful), "院内空地不能放亭")
	world.palace_decor["items"].append([4,useful.x,useful.y])
	_check(not courts.can_place(world.palace_decor,0,0,useful) and not courts.can_place(world.palace_decor,0,0,Vector2i(5,5)), "布置允许重叠或越界")
	var restored: RefCounted = State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot())))
	_check(restored != null and restored.palace_decor == world.palace_decor, "自定义陈设未随读档恢复")
	_check(Terrain.deposit_at(Vector2i(56,42)) == "forest" and Terrain.deposit_at(Vector2i(56,42), false, true).is_empty(), "城内林矿遮罩未影响规则")
	_check(Terrain.deposit_at(Vector2i(54,162), false, true) == "forest", "城外林矿被错误清除")
