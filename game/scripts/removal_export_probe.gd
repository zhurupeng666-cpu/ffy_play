## 文件用途：在真实Windows导出包中验证取消确认、同址重建及跨进程历史幂等。
extends RefCounted
const Catalog = preload("res://scripts/building_catalog.gd")
const Build = preload("res://scripts/construction_service.gd")
const Remove = preload("res://scripts/removal_service.gd")

# 验收模块：写进程取消半完工住宅并重建，读进程确保旧命令不能复活或重复退款。
static func run(main: Control, mode: String) -> int:
	if mode == "write":
		main._start_preview(Catalog.HOUSE)
		main.town_map.hovered = Vector2i(2, 2)
		main._on_placement_clicked({})
		main.world.paused = false
		main.clock.advance(20)
		main.world.paused = true
		main._request_removal()
		main._confirm_removal()
		if main.world.resources["wood"] != 110 or main.world.retired_buildings.size() != 1:
			return 1
		main._start_preview(Catalog.HOUSE)
		main.town_map.hovered = Vector2i(2, 2)
		main._on_placement_clicked({})
		if main.inspected_building_id != "building_000003" or not main.store.save_world(main.world):
			return 1
	else:
		main._load()
		if main.world.buildings.size() != 2 or main.world.retired_buildings.size() != 1 or main.world.resources["wood"] != 90 or main.world.resources["gold"] != 280:
			return 1
		var before: Dictionary = main.world.snapshot()
		var command: String = str(main.world.removal_commands.keys()[0])
		if not Remove.execute(main.world, "building_000002", command).get("replayed", false) or main.world.snapshot() != before:
			return 1
		for key: String in main.world.applied_commands:
			if main.world.applied_commands[key]["building_id"] == "building_000002":
				if not Build.execute(main.world, "b_house", Vector2i(2, 2), key).get("replayed", false) or main.world.snapshot() != before:
					return 1
		main._inspect_building("building_000003", false)
		main._request_removal()
		main._confirm_removal()
		if main.world.buildings.size() != 1 or main.world.resources["wood"] != 110 or main.world.retired_buildings.size() != 2 or not main.store.save_world(main.world):
			return 1
	print("EXPORT_REMOVAL_PASS: ", mode)
	return 0
