## 文件用途：验证全占地建筑选择、施工与容量详情、直接岗位操作、下拉同步和读档清理。
extends SceneTree
const Inspector = preload("res://scripts/building_inspector.gd")
const Build = preload("res://scripts/construction_service.gd")
const TownArt = preload("res://scripts/town_art.gd")
const Grid = preload("res://scripts/isometric_grid.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
var failed: bool = false

# 启动模块：等待管理场景可以加入真实场景树。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：保留失败原因并用退出码阻止发布失败版本。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 点击模块：走地图实际输入路径，使用经过镜头变换的逻辑格中心。
func _click(main: Control, cell: Vector2i, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = main.town_map.world_to_screen(Grid.cell_to_world(cell))
	main.town_map._gui_input(event)

# 集成验收模块：选择与查看不修改世界，只有明确岗位命令会改变分配。
func _run() -> void:
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/inspect_%s.db" % Time.get_ticks_usec())
	main.store_path_override = path
	root.add_child(main)
	var before: Dictionary = main.world.snapshot()
	_click(main, Vector2i(9, 9))
	_check(main.inspected_building_id == "building_000001" and main.inspection_label.text.contains("领主厅") and main.town_map.inspected_building_id == "building_000001", "非锚点领主厅选择失败")
	_check(main.world.snapshot() == before and not main.inspection_increase.get_parent().visible, "只读详情改变世界或领主厅出现生产按钮")
	_check(Build.execute(main.world, "b_farm", Vector2i(2, 4), "inspect-farm")["ok"], "农场开工失败")
	_check(Build.execute(main.world, "b_ranch", Vector2i(10, 10), "inspect-ranch")["ok"], "牧场开工失败")
	_check(Build.execute(main.world, "b_house", Vector2i(2, 2), "inspect-house")["ok"], "住宅开工失败")
	_check(Build.execute(main.world, "b_granary", Vector2i(10, 5), "inspect-granary")["ok"], "粮仓开工失败")
	_check(Build.execute(main.world, "b_lumber", Vector2i(1, 10), "inspect-lumber")["ok"], "伐木场开工失败")
	main._sync_building_view()
	main._refresh()
	# 查询模块：完整4×4农场的每一格都命中同一ID，边界外不误选。
	before = main.world.snapshot()
	for y: int in range(4, 8):
		for x: int in range(2, 6):
			_check(Inspector.at_cell(main.world, Vector2i(x, y)) == "building_000002", "建筑占地内部选择错误")
	_check(Inspector.at_cell(main.world, Vector2i(6, 4)).is_empty() and main.world.snapshot() == before, "边界外误选或查询改变世界")
	_click(main, Vector2i(13, 13))
	_check((main.numbers["building_queue"].text == "2") and main.inspection_label.text.contains("等待前序工地") and main.inspection_increase.disabled, "排队工地详情或按钮错误")
	before = main.world.snapshot()
	main._change_inspected_workers(1)
	_check(main.world.snapshot() == before, "直接调用绕过工地岗位限制")
	_click(main, Vector2i(5, 7))
	main.world.paused = false
	main.clock.advance(20)
	main.world.paused = true
	main._refresh()
	_check((main.numbers["building_progress"].text == "25%"), "选中工地进度不刷新")
	main._change_builders(-1)
	main._change_builders(-1)
	_check(main.inspection_label.text.contains("已停工"), "零施工工人未显示停工")
	main._change_builders(1)
	main._change_builders(1)
	main.world.paused = false
	main.clock.advance(300)
	main.world.paused = true
	main._refresh()
	_check(main.inspection_label.text.contains("已完工") and not main.inspection_increase.disabled and main.inspection_decrease.disabled, "施工转完工后操作未启用")
	main.inspection_increase.pressed.emit()
	_check(main.world.buildings[1]["workers"] == 1 and (main.numbers["building_jobs"].text == "1 / 3") and main.producer_picker.get_item_metadata(main.producer_picker.selected) == "building_000002", "详情岗位按钮或生产列表同步错误")
	# 下拉联动模块：选择牧场后加人只影响牧场，地图高亮与详情一致。
	main.producer_picker.select(1)
	main.producer_picker.item_selected.emit(1)
	main.inspection_increase.pressed.emit()
	_check(main.inspected_building_id == "building_000003" and main.town_map.inspected_building_id == "building_000003" and main.world.buildings[2]["workers"] == 1 and main.world.buildings[1]["workers"] == 1, "下拉选择误改另一建筑")
	_check_ranch_view(main)
	main._change_inspected_workers(1)
	main._change_inspected_workers(1)
	before = main.world.snapshot()
	main._change_inspected_workers(1)
	_check(main.inspection_increase.disabled and main.world.snapshot() == before, "满员仍能加人")
	_click(main, Vector2i(3, 3))
	_check((main.numbers["building_housing"].text == "10") and not main.inspection_increase.get_parent().visible, "住宅容量详情错误")
	_click(main, Vector2i(12, 7))
	_check((main.numbers["building_capacity"].text == "300") and not main.inspection_increase.get_parent().visible, "粮仓容量详情错误")
	# 旧入口联动模块：即使刚查看非生产建筑，使用生产列表按钮也先同步实际操作目标。
	main._change_producers(-1)
	_check(main.inspected_building_id == "building_000003" and main.world.buildings[2]["workers"] == 2 and main.town_map.inspected_building_id == "building_000003", "原生产按钮未同步实际目标")
	_click(main, Vector2i(2, 11))
	main._change_inspected_workers(1)
	main.world.paused = false
	main.clock.advance(15)
	main.world.paused = true
	main._refresh()
	_check((main.numbers["building_credit"].text == "1.00 木材") and main.inspection_label.text.contains("生产暂停"), "材料详情单位、进度或暂停提示错误")
	main._save()
	main._change_inspected_workers(1)
	main._load()
	_check(main.inspected_building_id.is_empty() and main.town_map.inspected_building_id.is_empty() and main.world.buildings[5]["workers"] == 1, "读档未清除旧选择或未恢复岗位")
	_click(main, Vector2i(2, 11))
	_check((main.numbers["building_jobs"].text == "1 / 3") and (main.numbers["building_credit"].text == "1.00 木材"), "重新点击未绑定读档后的建筑")
	# 建造模式模块：进入模式清空选择，成功后自动查看新工地；空地或右键清空高亮。
	main._start_preview(Catalog.HOUSE)
	_check(main.inspected_building_id.is_empty(), "建造模式保留旧岗位目标")
	main.town_map.hovered = Vector2i(12, 1)
	main._on_placement_clicked({})
	_check(main.inspected_building_id == "building_000007" and main.inspection_label.text.contains("住宅") and (main.numbers["building_progress"].text == "0%"), "成功建造后未查看新工地")
	_click(main, Vector2i(12, 1), MOUSE_BUTTON_RIGHT)
	_check(main.inspected_building_id.is_empty() and main.town_map.inspected_building_id.is_empty(), "右键没有取消详情")
	_click(main, Vector2i(0, 12))
	_check(main.inspected_building_id.is_empty(), "资源点被当作建筑")
	# 共享人口模块：详情按钮禁用之外，世界校验仍阻止超额请求。
	for record: Dictionary in main.world.buildings:
		record["workers"] = 0
	main.world.assign_builders(0)
	main.world.dependents = 30
	_click(main, Vector2i(5, 7))
	before = main.world.snapshot()
	main._change_inspected_workers(1)
	_check(main.inspection_increase.disabled and main.world.snapshot() == before, "无空闲人口仍可加人")
	await process_frame
	main.free()
	DirAccess.remove_absolute(path)
	if not failed:
		print("INSPECT_PASS: footprint, readonly, queue, progress, staffing, linked selection, exterior focus and animals, capacities, load cleanup, UI")
	quit(1 if failed else 0)


# 外观验收：双击围栏边格聚焦整座牧场，动物随显示时间行走，世界状态不变。
func _check_ranch_view(main: Control) -> void:
	var map: Control = main.town_map
	var before: Dictionary = main.world.snapshot()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.double_click = true
	click.pressed = true
	click.position = map.world_to_screen(Grid.cell_to_world(Vector2i(13, 13)))
	var zoom_before: float = map.zoom_level
	map._gui_input(click)
	_check(main.town_view.visible and main.inspected_building_id == "building_000003" and map.zoom_level > zoom_before, "双击未在原城镇聚焦整座牧场")
	var start: Vector2 = TownArt.animal_position(0, map.scenery_time)
	map._process(0.8)
	_check(not start.is_equal_approx(TownArt.animal_position(0, map.scenery_time)), "完工牧场的动物没有行走")
	for step: int in range(60):
		for index: int in range(5):
			var position: Vector2 = TownArt.animal_position(index, step * 0.25)
			_check(absf(position.x) / 106.0 + absf(position.y) / 51.0 < 0.9, "动物路线走出了围栏")
	_check(main.world.snapshot() == before, "聚焦与动物绘制改变存档状态")
	map.reset_view()
