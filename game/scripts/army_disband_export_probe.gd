## 文件用途：在真实Windows导出包中验证取消训练退款、返还兵源和退役军需跨进程连续性。
extends RefCounted
const Catalog = preload("res://scripts/building_catalog.gd")
const Army = preload("res://scripts/army_service.gd")
const Disband = preload("res://scripts/army_disband_service.gd")

# 验收模块：写进程取消50%训练，读进程检验旧命令不复活或重复退款，已发生费用仍日结。
static func run(main: Control, mode: String) -> int:
	if mode == "write":
		main._start_preview(Catalog.BARRACKS)
		main.town_map.hovered = Vector2i(2, 4)
		main._on_placement_clicked({})
		main.world.paused = false
		main.clock.advance(120)
		main.world.paused = true
		main._recruit_infantry()
		main.world.paused = false
		main.clock.advance(30)
		main.world.paused = true
		main._refresh()
		main._request_army_disband()
		main._confirm_army_disband()
		if not main.world.troops.is_empty() or main.world.idle_workers() != 22 or main.world.resources["gold"] != 265 or main.world.resources["wood"] != 87 or not main.store.save_world(main.world):
			return 1
	else:
		main._load()
		if not main.world.troops.is_empty() or main.world.retired_troops.size() != 1 or main.world.retired_army_cost["ration_credit"] != 150:
			return 1
		var before: Dictionary = main.world.snapshot()
		if not Army.recruit(main.world, "building_000002", str(main.world.recruit_commands.keys()[0])).get("replayed", false) or not Disband.execute(main.world, "troop_000001", str(main.world.disband_commands.keys()[0])).get("replayed", false) or main.world.snapshot() != before:
			return 1
		main.world.paused = false
		main.clock.advance(90)
		main.world.paused = true
		main._refresh()
		if main.world.resources["food"] != 149 or main.world.resources["gold"] != 284 or main.world.retired_army_cost["ration_credit"] != 30 or not main.ledger_data[2].visible or not main.store.save_world(main.world):
			return 1
	print("EXPORT_DISBAND_PASS: ", mode)
	return 0
