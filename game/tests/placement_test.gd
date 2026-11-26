## 文件用途：验证建筑多格占地、红绿预览和取消交互，确保独立预览不写世界，确认入口只扣一次费用。
extends SceneTree

const Grid = preload("res://scripts/isometric_grid.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Map = preload("res://scripts/town_map.gd")
const House = preload("res://data/buildings/house.tres")
const Farm = preload("res://data/buildings/farm.tres")
const Catalog = preload("res://scripts/building_catalog.gd")
const Construct = preload("res://scripts/construction_service.gd")
const State = preload("res://scripts/world_state.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
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
	_check(Placement.check(Grid.SIZE - Farm.footprint, Farm.footprint, occupied)["ok"], "右下边界合法农场被拒绝")
	_check(Placement.check(Vector2i.ONE * (Grid.WORLD_LIMIT + 1) - Farm.footprint + Vector2i.RIGHT, Farm.footprint, occupied)["code"] == "OUT_OF_BOUNDS", "只检查了锚点而未检查完整尺寸")
	_check(Placement.check(Vector2i(-1, 0), House.footprint, occupied)["ok"], "负坐标不能建造")
	_check(Placement.check(Vector2i(5, 5), House.footprint, occupied)["code"] == "OCCUPIED", "部分重叠未拒绝")
	_check(Placement.check(Vector2i(4, 4), House.footprint, occupied)["ok"], "相邻但不重叠被拒绝")
	_check(Placement.check(Vector2i.ZERO, Vector2i.ZERO, occupied)["code"] == "INVALID_SIZE", "零尺寸未拒绝")
	_check(Placement.check(Vector2i.ZERO, Vector2i(99999, 4), occupied)["code"] == "INVALID_SIZE", "异常尺寸未拒绝")
	_check(occupied == before, "校验修改了占用数据")
	# 视图模块：拖动和缩放后仍以同一逻辑锚点判断，切换尺寸即时生效。
	var map: Control = Map.new()
	map.size = Vector2(600, 400)
	root.add_child(map)
	# 几何单元测试显式注入占用样本，运行游戏不再生成测试占用区。
	for y: int in range(6, 10):
		for x: int in range(6, 10):
			map.occupied_cells[Vector2i(x, y)] = true
	map.set_preview(House)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	map._gui_input(click)
	_check(map.preview_result.get("ok", false) and map.preview_result["cells"].size() == 4, "住宅预览范围或结果错误")
	map.sync_resources({"wood": 0, "gold": 999})
	_check(map.preview_result.get("code") == "INSUFFICIENT", "材料不足仍显示可建造")
	map.sync_resources({"wood": 1000, "gold": 1000})
	_check(map.preview_result.get("ok", false), "补足材料后预览未恢复")
	map.set_preview(Farm)
	_check(map.preview_result["cells"].size() == 16, "切换农场后占地未更新")
	map.pan_offset += Vector2(50, -30)
	map._apply_zoom(Vector2(200, 150), 1.2)
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(7, 7)))
	map._gui_input(click)
	_check(map.preview_result.get("code") == "OCCUPIED", "移动缩放后重叠判断错误")
	map.visit_site(Vector2i.ONE * Grid.WORLD_LIMIT)
	click.position = map.size * 0.5
	map._gui_input(click)
	_check(map.preview_result.get("code") == "OUT_OF_BOUNDS", "超出安全坐标的预览没有拒绝")
	var occupied_count: int = map.occupied_cells.size()
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	map._gui_input(click)
	map._gui_input(click)
	_check(map.occupied_cells.size() == occupied_count, "重复左键创建了建筑或占用")
	click.button_index = MOUSE_BUTTON_RIGHT
	map._gui_input(click)
	_check(map.active_definition == null, "右键未取消预览")
	map.free()
	# 集成模块：合法确认只提交一次，非法位置不改变世界，Esc只取消当前模式。
	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var main: Control = scene.instantiate()
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/placement_%s.db" % Time.get_ticks_usec())
	main.legacy_economy_fixture = true
	main.store_path_override = path
	root.add_child(main)
	var world_before: Dictionary = main.world.snapshot()
	main._start_preview(House)
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = main.town_map.world_to_screen(Grid.cell_to_world(Vector2i(2, 2)))
	main.town_map._gui_input(click)
	_check(main.status_label.text.contains("建造成功") and main.world.buildings.size() == 2 and main.world.resources["wood"] == 100 and main.world.resources["gold"] == 290, "确认建造未落地或扣费错误")
	var committed: Dictionary = main.world.snapshot()
	main.town_map._gui_input(click)
	_check(main.world.snapshot() == committed, "成功后退出模式未防止再次扣费")
	main._start_preview(House)
	click.position = main.town_map.world_to_screen(Grid.cell_to_world(Vector2i(7, 7)))
	main.town_map._gui_input(click)
	_check(main.status_label.text.contains("建造失败"), "重叠点击缺少原因")
	_check(main.world.snapshot() == committed and world_before["tick"] == main.world.tick, "失败建造改变了资源或日期")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._unhandled_key_input(escape)
	_check(main.town_map.active_definition == null, "Esc没有优先取消预览")
	# 市政建造：道路连铺共用正常施工队列，单次放置各用一条独立回执。
	main._start_preview(Catalog.ROAD)
	for cell: Vector2i in [Vector2i(-5, 1), Vector2i(-4, 1)]:
		click.position = main.town_map.world_to_screen(Grid.cell_to_world(cell))
		main.town_map._gui_input(click)
	_check(main.town_map.active_definition == Catalog.ROAD and main.world.buildings.size() == 4, "道路未保留连续建造模式")
	main._cancel_preview()
	for definition: Resource in [Catalog.WALL, Catalog.GATE, Catalog.SMITHY]:
		var slot: Dictionary = {"b_wall": Vector2i(-3, 1), "b_gate": Vector2i(-3, 2), "b_smithy": Vector2i(-7, 3)}
		var result: Dictionary = Construct.execute(main.world, definition.id, slot[definition.id], "verify-" + definition.id)
		_check(result["ok"], "市政设施建造失败 " + definition.id)
	main.world.paused = false
	main.clock.advance(150)
	main.world.paused = true
	main._sync_building_view()
	_check(main.town_map.ready_infrastructure.size() == 4, "完工后没有生成连通路面与城防")
	var restored: RefCounted = State.from_snapshot(main.world.snapshot())
	_check(restored != null and restored.buildings == main.world.buildings, "市政建筑存档恢复失败")
	main.free()
	DirAccess.remove_absolute(path)
	_check_district_market()
	if not failed:
		print("PLACEMENT_PASS: resources, footprint, bounds, overlap, pan, zoom, city works, district market")
	quit(1 if failed else 0)


# 商业验收：住宅数量和街路连通都达标才形成集市，保存后不再重复生成。
func _check_district_market() -> void:
	var world: RefCounted = State.new()
	world.resources["wood"] = 500
	world.resources["gold"] = 500
	for x: int in range(20, 46):
		if x != 31:
			_finish_fixture(world, "b_road", Vector2i(x, 0))
	for x: int in range(20, 40, 2):
		_finish_fixture(world, "b_house", Vector2i(x, -2))
	for x: int in [20, 22, 24, 26, 32, 34, 36, 38, 40]:
		_finish_fixture(world, "b_house", Vector2i(x, 1))
	world.paused = false
	Clock.new(world).advance(State.DAY_TICKS)
	_check(world.buildings.back()["def_id"] == "b_house", "19座住宅提前开市")
	_finish_fixture(world, "b_house", Vector2i(42, 1))
	Clock.new(world).advance(State.DAY_TICKS)
	_check(world.buildings.back()["def_id"] == "b_house", "断路两侧住宅被合并统计")
	_finish_fixture(world, "b_road", Vector2i(31, 0))
	Clock.new(world).advance(State.DAY_TICKS)
	_check(world.buildings.back()["def_id"] == "b_market", "连通的20座住宅没有形成街区集市")
	var count: int = world.buildings.size()
	var loaded: RefCounted = State.from_snapshot(world.snapshot())
	_check(loaded != null and loaded.buildings == world.buildings, "集市地址与回执未恢复")
	if loaded != null:
		Clock.new(loaded).advance(State.DAY_TICKS)
		_check(loaded.buildings.size() == count, "同一街区在读档后重复开市")


# 夹具模块：按正式建造生成历史回执，直接完成施工便于单独测试街区规则。
func _finish_fixture(world: RefCounted, id: String, cell: Vector2i) -> void:
	var result: Dictionary = Construct.execute(world, id, cell, "%s-%s" % [id, cell])
	_check(result["ok"], "街区样本建造失败 %s %s" % [cell, result.get("code", "")])
	if result["ok"]:
		var record: Dictionary = world.buildings.back()
		record["state"] = "ready"
		record["work_done"] = record["work_required"]
