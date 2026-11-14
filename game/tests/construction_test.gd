## 文件用途：验证真实建造扣费、失败无副作用、命令幂等、旧档迁移和建筑存档恢复。
extends SceneTree

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
	result = Build.execute(world, "b_farm", Vector2i(15, 15), "cmd-outside")
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
	var store: RefCounted = Store.new()
	if not store.open_store(path):
		_check(false, "测试库打开失败")
		quit(1)
		return
	store.database.query_with_bindings("INSERT INTO world_snapshot(slot,payload) VALUES(1,?);", [JSON.stringify(legacy)])
	migrated = store.load_world()
	_check(migrated != null and store.save_world(migrated), "旧档迁移后保存失败")
	store.database.query("SELECT payload FROM snapshot_backup ORDER BY id DESC LIMIT 1;")
	var backup: Dictionary = JSON.parse_string(store.database.query_result[0]["payload"])
	_check(int(backup["version"]) == 1, "迁移保存没有保留旧快照")
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
	# 事务验收模块：旧快照最多保留三份，写入失败时快照和备份一起回滚。
	for index: int in range(4):
		_check(store.save_world(loaded), "连续保存失败")
	store.database.query("SELECT COUNT(*) AS count FROM snapshot_backup;")
	_check(int(store.database.query_result[0]["count"]) == 3, "旧快照保留数量错误")
	var disk_before: Dictionary = store.load_world().snapshot()
	store.database.query("CREATE TRIGGER fail_snapshot BEFORE UPDATE ON world_snapshot BEGIN SELECT RAISE(ABORT, 'test failure'); END;")
	loaded.resources["gold"] += 1
	# 只抑制本条预期故障的原生输出，恢复后再执行断言，不隐藏真实测试失败。
	var previous_error_output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var rejected: bool = not store.save_world(loaded)
	Engine.print_error_messages = previous_error_output
	_check(rejected and store.load_world().snapshot() == disk_before, "失败保存破坏了已提交快照")
	store.database.query("SELECT COUNT(*) AS count FROM snapshot_backup;")
	_check(int(store.database.query_result[0]["count"]) == 3, "失败保存修改了备份")
	store.close_store()
	DirAccess.remove_absolute(path)
	if not failed:
		print("BUILD_PASS: costs, atomic failure, idempotency, migration, snapshots, backup rollback")
	quit(1 if failed else 0)
