## 文件用途：在真实Windows导出包中验证军营招募、训练中途重开、兵员占用及军需结算。
extends RefCounted
const Catalog = preload("res://scripts/building_catalog.gd")
const Army = preload("res://scripts/army_service.gd")

# 验收模块：写进程保存50%训练，新读进程继续至现役与完整军需日结，旧命令不能再次扣费。
static func run(main: Control, mode: String) -> int:
	if mode == "write":
		main._start_preview(Catalog.BARRACKS)
		main.town_map.hovered = Vector2i(2, 4)
		main._on_placement_clicked({})
		main.world.paused = false
		main.clock.advance(80)
		main.world.paused = true
		main._refresh()
		main._recruit_infantry()
		main.world.paused = false
		main.clock.advance(30)
		main.world.paused = true
		main._refresh()
		if not (main.numbers["batch_progress"].text == "50%") or main.world.idle_workers() != 17 or not main.store.save_world(main.world):
			return 1
	else:
		main._load()
		main._inspect_building("building_000002", false)
		if main.world.tick != 110 or main.world.idle_workers() != 17 or not (main.numbers["batch_progress"].text == "50%"):
			return 1
		main.world.paused = false
		main.clock.advance(130)
		main.world.paused = true
		main._refresh()
		if Army.people(main.world.troops, false, true) != 5 or main.world.resources["food"] != 144 or main.world.resources["gold"] != 254 or main.world.last_army_ledger["wage_paid"] != 5:
			return 1
		var before: Dictionary = main.world.snapshot()
		var command: String = str(main.world.recruit_commands.keys()[0])
		if not Army.recruit(main.world, "building_000002", command).get("replayed", false) or main.world.snapshot() != before or not main.store.save_world(main.world):
			return 1
		var reopened: RefCounted = main.store.load_world()
		if reopened == null or reopened.troops != main.world.troops or reopened.last_army_ledger != main.world.last_army_ledger:
			return 1
		# 士气验收模块：独立读进程触发实际短缺，核对面板与再次存读档。
		var supplied_morale: int = main.world.army_morale
		main.world.resources["food"] = 0
		main.world.paused = false
		main.clock.advance(120)
		main.world.paused = true
		main._refresh()
		if supplied_morale != 64 or main.world.army_morale != 52 or not main.numbers["morale_change"].text == "64 → 52" or main.world.idle_workers() != 17:
			return 1
		if not main.store.save_world(main.world):
			return 1
		reopened = main.store.load_world()
		if reopened == null or reopened.army_morale != 52 or reopened.last_morale_before != 64:
			return 1
	print("EXPORT_ARMY_PASS: ", mode)
	return 0
