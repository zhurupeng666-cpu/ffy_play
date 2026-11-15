## 文件用途：在真实Windows包中验证2/3自由人数编制、跨进程维护不重计及撤销编制仍保留部队。
extends RefCounted
const Catalog = preload("res://scripts/building_catalog.gd")
const Legions = preload("res://scripts/legion_service.gd")
const Army = preload("res://scripts/army_service.gd")

# 验收模块：写进程把5人分为两个军团，读进程续日结后撤销一团，不退役士兵。
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
		main.clock.advance(60)
		main.world.paused = true
		main._refresh()
		main._create_legion()
		main.legion_people.value = 2
		main._apply_legion_count()
		main._create_legion()
		main.legion_people.value = 3
		main._apply_legion_count()
		if Legions.people(Legions.find(main.world, "legion_000001")) != 2 or Legions.people(Legions.find(main.world, "legion_000002")) != 3 or main.world.idle_workers() != 17 or not main.store.save_world(main.world):
			return 1
	else:
		main._load()
		if Legions.assigned(main.world, "troop_000001") != 5 or main.world.idle_workers() != 17:
			return 1
		main.world.paused = false
		main.clock.advance(60)
		main.world.paused = true
		main._refresh()
		if main.world.resources["food"] != 145 or main.world.resources["gold"] != 255 or main.world.last_army_ledger["wage_needed"] != 5:
			return 1
		main.selected_legion_id = "legion_000001"
		main._request_legion_close()
		main._confirm_legion_close()
		if not Legions.find(main.world, "legion_000001").is_empty() or Legions.people(Legions.find(main.world, "legion_000002")) != 3 or Army.people(main.world.troops, false, true) != 5 or main.world.idle_workers() != 17:
			return 1
		var before: Dictionary = main.world.snapshot()
		for command: String in main.world.legion_create_commands:
			if main.world.legion_create_commands[command] == "legion_000001":
				if not Legions.create(main.world, command).get("replayed", false) or main.world.snapshot() != before:
					return 1
		if not main.store.save_world(main.world):
			return 1
	print("EXPORT_LEGION_PASS: ", mode)
	return 0
