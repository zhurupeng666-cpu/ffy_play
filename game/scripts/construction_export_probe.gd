## 文件用途：在实际Windows导出包中验证建筑持久化及命令回执跨进程幂等。
extends RefCounted

const Build = preload("res://scripts/construction_service.gd")


# 验收模块：独立写进程建一座住宅，读进程确认费用、占用和回执不重复执行。
static func run(world: RefCounted, store: RefCounted, mode: String) -> int:
	if mode == "write":
		if not Build.execute(world, "b_house", Vector2i(2, 2), "export-house-1").get("ok", false):
			return 1
		if not store.save_world(world):
			return 1
	else:
		var loaded: RefCounted = store.load_world()
		if loaded == null or loaded.buildings.size() != 2 or loaded.resources["wood"] != 100 or loaded.resources["gold"] != 290:
			return 1
		if not loaded.occupied_cells().has(Vector2i(3, 3)):
			return 1
		var before: Dictionary = loaded.snapshot()
		var result: Dictionary = Build.execute(loaded, "b_house", Vector2i(2, 2), "export-house-1")
		if not result.get("replayed", false) or loaded.snapshot() != before:
			return 1
	print("EXPORT_BUILD_PASS: ", mode)
	return 0
