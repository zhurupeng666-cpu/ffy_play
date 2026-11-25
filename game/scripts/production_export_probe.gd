## 文件用途：在真实Windows导出包中跨进程验证农牧渔岗位、生产进度和日结连续性。
extends RefCounted
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")

# 验收模块：写进程保存半日产粮，读进程续至日结且不重复发粮。
static func run(world: RefCounted, store: RefCounted, mode: String) -> int:
	if mode == "write":
		if not Build.execute(world, "b_farm", Vector2i(2, 4), "export-farm")["ok"] or not Build.execute(world, "b_ranch", Vector2i(10, 10), "export-ranch")["ok"] or not Build.execute(world, "b_fishery", Vector2i(8, 71), "export-fish")["ok"]:
			return 1
		world.paused = false
		var clock: RefCounted = Clock.new(world)
		clock.advance(240)
		for id: String in ["building_000002", "building_000003", "building_000004"]:
			if not world.assign_producers(id, 1):
				return 1
		clock.advance(61)
		world.paused = true
		if not store.save_world(world):
			return 1
	else:
		var loaded: RefCounted = store.load_world()
		if loaded == null or loaded.tick != 301 or loaded.production_workers() != 3 or loaded.buildings[1]["food_credit"] != 366 or loaded.buildings[2]["food_credit"] != 305 or loaded.buildings[3]["food_credit"] != 244 or not loaded.paused:
			return 1
		loaded.paused = false
		Clock.new(loaded).advance(59)
		if loaded.resources["food"] != 150 or not loaded.last_bill.contains("产粮 +15") or loaded.buildings[1]["food_credit"] != 0:
			return 1
		var before: Dictionary = loaded.snapshot()
		loaded.settle_days()
		if loaded.snapshot() != before:
			return 1
	print("EXPORT_FOOD_PASS: ", mode)
	return 0
