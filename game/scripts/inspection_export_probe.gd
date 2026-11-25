## 文件用途：在真实Windows包内验证建筑点击详情、岗位命令和跨进程读档后的身份重绑定。
extends RefCounted
const Grid = preload("res://scripts/isometric_grid.gd")
const Catalog = preload("res://scripts/building_catalog.gd")

# 验收模块：写进程通过建造与详情操作保存，读进程从地图重新选择后续产。
static func run(main: Control, mode: String) -> int:
	if mode == "write":
		main._start_preview(Catalog.LUMBER)
		main.town_map.hovered = Vector2i(46, 46)
		main._on_placement_clicked({})
		if main.inspected_building_id != "building_000002" or not main.inspection_increase.disabled:
			return 1
		main.world.paused = false
		main.clock.advance(120)
		main.world.paused = true
		main._refresh()
		main._change_inspected_workers(1)
		main.world.paused = false
		main.clock.advance(15)
		main.world.paused = true
		main._refresh()
		if not (main.numbers["building_credit"].text == "1.00 木材") or not main.store.save_world(main.world):
			return 1
	else:
		main._load()
		if not main.inspected_building_id.is_empty() or main.world.tick != 135:
			return 1
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = main.town_map.world_to_screen(Grid.cell_to_world(Vector2i(47, 47)))
		main.town_map._gui_input(click)
		if main.inspected_building_id != "building_000002" or not (main.numbers["building_credit"].text == "1.00 木材") or not (main.numbers["building_jobs"].text == "1 / 3"):
			return 1
		main._change_inspected_workers(1)
		main.world.paused = false
		main.clock.advance(105)
		main.world.paused = true
		main._refresh()
		if main.world.resources["wood"] != 135 or not (main.numbers["building_jobs"].text == "2 / 3"):
			return 1
	print("EXPORT_INSPECT_PASS: ", mode)
	return 0
