## 文件用途：验证真实建造扣费、失败无副作用、命令幂等、旧档迁移和建筑存档恢复。
extends SceneTree

const Grid = preload("res://scripts/isometric_grid.gd")
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Store = preload("res://scripts/world_save_repository.gd")
var failed: bool = false


# 启动模块：使用独立测试库，不修改用户手动存档。
func _initialize() -> void:
	call_deferred("_run")


# 断言模块：记录规则失败并最终返回非零退出码。
func _check(condition: bool, reason: String) -> void:
	if not condition:
		failed = true
		push_error(reason)


# 建造验收模块：成功只扣一次，几何、费用或命令失败都不改变世界。
func _run() -> void:
	var world: RefCounted = State.new()
	_check(world.buildings.size() == 1 and world.occupied_cells().size() == 16, "初始领主厅不完整")
	var result: Dictionary = Build.execute(world, "b_house", Vector2i(2, 2), "cmd-1")
	_check(result.get("ok", false) and world.resources["wood"] == 100 and world.resources["gold"] == 290 and world.buildings.size() == 2, "住宅扣费或实例错误")
	var after: Dictionary = world.snapshot()
	result = Build.execute(world, "b_house", Vector2i(2, 2), "cmd-1")
	_check(result.get("replayed", false) and world.snapshot() == after, "重复成功命令再次扣费")
	result = Build.execute(world, "b_house", Vector2i(4, 2), "cmd-1")
	_check(result.get("code") == "COMMAND_CONFLICT" and world.snapshot() == after, "重复ID更换位置没有拒绝")
	result = Build.execute(world, "b_house", Vector2i(2, 2), "cmd-overlap")
	_check(not result["ok"] and world.snapshot() == after, "重叠建造修改了世界")
	result = Build.execute(world, "b_farm", Grid.SIZE - Vector2i.ONE, "cmd-outside")
	_check(not result["ok"] and world.snapshot() == after, "越界建造修改了世界")
	result = Build.execute(world, "b_hall", Vector2i(12, 12), "cmd-hall")
	_check(not result["ok"] and world.snapshot() == after, "允许重复建领主厅")
	world.resources["wood"] = 0
	after = world.snapshot()
	result = Build.execute(world, "b_farm", Vector2i(12, 12), "cmd-poor")
	_check(result.get("code") == "INSUFFICIENT" and world.snapshot() == after, "材料不足导致部分扣费")
	world.resources["wood"] = 100
	world.next_building_id = 1000000
	after = world.snapshot()
	result = Build.execute(world, "b_house", Vector2i(12, 12), "cmd-counter-limit")
	_check(result.get("code") == "LIMIT" and world.snapshot() == after, "编号上限导致不可保存实例")
	# 迁移验收模块：旧快照保留经济和时间，补入领主厅且不扣材料。
	var legacy: Dictionary = State.new().snapshot()
	legacy["version"] = 1
	legacy.erase("buildings")
	legacy.erase("next_building_id")
	legacy.erase("applied_commands")
	legacy["resources"]["gold"] = 345
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.resources["gold"] == 345 and migrated.buildings.size() == 1, "旧档迁移丢失经济或建筑")
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/build_%s.db" % Time.get_ticks_usec())
	var previous: SQLite = SQLite.new()
	previous.path = path
	_check(previous.open_db(), "不能创建旧版测试库")
	_check(previous.query("CREATE TABLE world_snapshot(slot INTEGER PRIMARY KEY, payload TEXT NOT NULL);"), "旧版快照表无法创建")
	_check(previous.query_with_bindings("INSERT INTO world_snapshot(slot,payload) VALUES(1,?);", [JSON.stringify(legacy)]), "旧档样本写入失败")
	_check(previous.query("PRAGMA user_version=2;"), "旧库版本标记失败")
	previous.close_db()
	var store: RefCounted = Store.new()
	if not store.open_store(path):
		_check(false, "测试库打开失败")
		quit(1)
		return
	migrated = store.load_world()
	_check(migrated != null and store.save_world(migrated), "旧档迁移后保存失败")
	var migrated_rows: Array = store.list_saves()
	_check(migrated_rows.size() == 2 and migrated_rows[1]["saved_local"] == null and store.load_world(migrated_rows[1]["id"]).resources["gold"] == 345, "迁移丢失旧快照或虚构时间")
	_check(Build.execute(migrated, "b_house", Vector2i(2, 2), "saved-cmd")["ok"], "迁移后建造失败")
	_check(store.save_world(migrated), "含建筑快照保存失败")
	store.close_store()
	store = Store.new()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.buildings.size() == 2 and loaded.resources["wood"] == 100 and loaded.resources["gold"] == 335, "重开后建筑或费用未恢复")
	after = loaded.snapshot()
	_check(Build.execute(loaded, "b_house", Vector2i(2, 2), "saved-cmd").get("replayed", false) and loaded.snapshot() == after, "读档后命令幂等丢失")
	_check(Build.execute(loaded, "b_farm", Vector2i(12, 12), "next-cmd").get("building_id") == "building_000003", "实例ID计数器没有恢复")
	# 坏档验收模块：拒绝重叠、未知定义、重复ID及悬空回执。
	var bad: Dictionary = loaded.snapshot()
	bad["buildings"][1]["cell"] = [6, 6]
	bad["applied_commands"]["saved-cmd"]["cell"] = [6, 6]
	_check(State.from_snapshot(bad) == null, "接受重叠建筑存档")
	bad = loaded.snapshot()
	bad["buildings"][1]["def_id"] = "unknown"
	_check(State.from_snapshot(bad) == null, "接受未知建筑定义")
	bad = loaded.snapshot()
	bad["buildings"][2]["id"] = "building_000002"
	_check(State.from_snapshot(bad) == null, "接受重复实例ID")
	bad = loaded.snapshot()
	bad["applied_commands"]["saved-cmd"]["building_id"] = "building_999999"
	_check(State.from_snapshot(bad) == null, "接受悬空命令回执")
	# 七档验收：保存八次后丢弃最早记录，并保留每份独立的余额。
	for index: int in range(8):
		loaded.resources["gold"] = 400 + index
		_check(store.save_world(loaded), "连续保存失败")
	var rows: Array = store.list_saves()
	_check(rows.size() == 7 and rows[0]["saved_local"] is String and store.load_world(rows[6]["id"]).resources["gold"] == 401 and store.load_world().resources["gold"] == 407, "七档轮换或按ID读取错误")
	var disk_before: Dictionary = store.load_world().snapshot()
	store.database.query("CREATE TRIGGER fail_snapshot BEFORE DELETE ON world_saves BEGIN SELECT RAISE(ABORT, 'test failure'); END;")
	loaded.resources["gold"] += 1
	# 只抑制本条预期故障的原生输出，恢复后再执行断言，不隐藏真实测试失败。
	var previous_error_output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var rejected: bool = not store.save_world(loaded)
	Engine.print_error_messages = previous_error_output
	_check(rejected and store.load_world().snapshot() == disk_before, "失败保存破坏了已提交快照")
	_check(store.list_saves() == rows, "失败轮换修改了七档列表")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 扩建区验收：远地施工及其建造回执可一同恢复。
	var expansion: RefCounted = State.new()
	var far_cell := Vector2i(170, 156)
	var placed: Dictionary = Build.execute(expansion, "b_house", far_cell, "far-site")
	var expanded_save: RefCounted = State.from_snapshot(expansion.snapshot())
	_check(placed["ok"] and expanded_save != null and expanded_save.occupied_cells().has(far_cell), "扩建区远处建筑不能建造或存读档")
	if expanded_save != null:
		_check(Build.execute(expanded_save, "b_house", far_cell, "far-site").get("replayed", false), "远处建造回执未恢复")
	_check_expanded_yards()
	if not failed:
		print("BUILD_PASS: costs, atomic failure, idempotency, migration, snapshots, backup rollback")
	quit(1 if failed else 0)


# 老城升级验收：重叠时迁址并保留 ID 原工期与费用，新建与操作回执区分规格。
func _check_expanded_yards() -> void:
	var world: RefCounted = State.new()
	var farm: Dictionary = Build.execute(world, "b_farm", Vector2i(2, 3), "legacy-farm")
	var barn: Dictionary = Build.execute(world, "b_barracks", Vector2i(41, 66), "legacy-barracks")
	if not farm["ok"] or not barn["ok"]:
		_check(false, "旧城样本未能建立")
		return
	var legacy: Dictionary = world.snapshot()
	legacy["version"] = 20
	for record: Dictionary in legacy["buildings"]:
		record.erase("large")
	for receipt: Dictionary in legacy["applied_commands"].values():
		receipt.erase("large")
	var expanded: RefCounted = State.from_snapshot(legacy)
	if expanded == null:
		_check(false, "旧城扩大后无法读取")
		return
	var migrated_farm: Dictionary = expanded.buildings[1]
	var migrated_barn: Dictionary = expanded.buildings[2]
	_check(Build.Catalog.footprint(migrated_farm) == Vector2i(20, 20) and migrated_farm["cell"] != [2, 3] and migrated_farm["id"] == farm["building_id"], "受阻农场未迁至合法位置")
	_check(Build.Catalog.footprint(migrated_barn) == Vector2i(20, 20) and migrated_barn["cell"] == [41, 66] and migrated_barn["id"] == barn["building_id"], "空地军营没有原地扩大")
	_check(expanded.resources == world.resources and migrated_barn["work_required"] == world.buildings[2]["work_required"] and expanded.occupied_cells().size() == 816, "扩建破坏库存、原施工或占地重叠")
	_check(State.from_snapshot(expanded.snapshot()).snapshot() == expanded.snapshot(), "扩建后再次读取不稳定")
	var large: Dictionary = Build.execute(expanded, "b_ranch", Vector2i(82, 152), "new-yard", true)
	_check(large["ok"] and expanded.occupied_cells().get(Vector2i(101, 171)) == large.get("building_id"), "大型牧场末端未实际占地")
	_check(Build.execute(expanded, "b_ranch", Vector2i(82, 152), "new-yard").get("code") == "COMMAND_CONFLICT", "建造回执没有区分规格")
