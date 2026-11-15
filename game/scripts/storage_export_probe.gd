## 文件用途：在真实Windows导出包中验证粮仓容量、满仓账单及跨进程恢复后的日结连续性。
extends RefCounted
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")

# 验收模块：隔离库保存带溢出账单，再由新进程读取并继续一日。
static func run(world: RefCounted, store: RefCounted, mode: String) -> int:
	if mode == "write":
		if not Build.execute(world, "b_farm", Vector2i(2, 4), "storage-export-farm")["ok"] or not Build.execute(world, "b_granary", Vector2i(10, 10), "storage-export-granary")["ok"]:
			return 1
		world.paused = false
		var clock: RefCounted = Clock.new(world)
		clock.advance(240)
		world.assign_producers("building_000002", 3)
		world.resources["food"] = 595
		clock.advance(120)
		world.paused = true
		if world.resources["food"] != 585 or world.last_food_ledger["overflow"] != 13 or not store.save_world(world):
			return 1
	else:
		var loaded: RefCounted = store.load_world()
		if loaded == null or loaded.food_capacity() != 600 or loaded.resources["food"] != 585 or loaded.last_food_ledger["overflow"] != 13 or loaded.last_food_ledger["by_source"]["b_farm"] != 18 or not loaded.paused:
			return 1
		loaded.paused = false
		Clock.new(loaded).advance(120)
		if loaded.resources["food"] != 585 or loaded.last_food_ledger["day"] != 4 or loaded.last_food_ledger["overflow"] != 3:
			return 1
		var before: Dictionary = loaded.snapshot()
		loaded.settle_days()
		if loaded.snapshot() != before:
			return 1
	print("EXPORT_STORAGE_PASS: ", mode)
	return 0
