## 文件用途：在真实Windows导出包中跨进程验证伐木采石岗位、整数积累与材料日结账单。
extends RefCounted
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")

# 验收模块：写进程保留半日积累，读进程续至日结并验证材料账单再次保存。
static func run(world: RefCounted, store: RefCounted, mode: String) -> int:
	if mode == "write":
		if not Build.execute(world, "b_lumber", Vector2i(1, 10), "export-lumber")["ok"] or not Build.execute(world, "b_quarry", Vector2i(12, 4), "export-quarry")["ok"]:
			return 1
		world.paused = false
		var clock: RefCounted = Clock.new(world)
		clock.advance(240)
		world.assign_producers("building_000002", 3)
		world.assign_producers("building_000003", 3)
		clock.advance(61)
		world.paused = true
		if not store.save_world(world):
			return 1
	else:
		var loaded: RefCounted = store.load_world()
		if loaded == null or loaded.tick != 301 or loaded.production_workers() != 6 or loaded.buildings[1]["material_credit"] != 1464 or loaded.buildings[2]["material_credit"] != 915 or not loaded.paused:
			return 1
		loaded.paused = false
		Clock.new(loaded).advance(59)
		if loaded.resources["wood"] != 119 or loaded.resources["stone"] != 95 or loaded.resources["food"] != 135 or loaded.last_material_ledger["wood"]["stored"] != 24 or loaded.last_material_ledger["stone"]["stored"] != 15:
			return 1
		var before: Dictionary = loaded.snapshot()
		loaded.settle_days()
		if loaded.snapshot() != before or not store.save_world(loaded):
			return 1
		var reopened: RefCounted = store.load_world()
		if reopened == null or reopened.last_material_ledger != loaded.last_material_ledger:
			return 1
	print("EXPORT_MATERIAL_PASS: ", mode)
	return 0

