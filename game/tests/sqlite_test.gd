## 文件用途：使用独立临时数据库验证空槽、跨连接持久化、非法值拒绝、事务回滚和版本保护。
extends SceneTree

const Repository = preload("res://scripts/sqlite_save_repository.gd")
var repository: RefCounted
var test_path: String


# 启动模块：创建唯一测试路径，不触碰用户手动测试的存档。
func _initialize() -> void:
	test_path = ProjectSettings.globalize_path("res://local_data/tests/sqlite_%s.db" % Time.get_ticks_usec())
	repository = Repository.new()
	call_deferred("_run")


# 验收模块：逐项检查SQLite真实行为，失败立即以非零退出码结束。
func _run() -> void:
	if not repository.open_store(test_path):
		_fail(repository.error_message)
		return
	var empty: Dictionary = repository.load_gold()
	if not empty.get("ok", false) or empty.get("found", true):
		_fail("空槽识别失败")
		return
	if not repository.save_gold(130):
		_fail("保存失败")
		return
	repository.close_store()
	# 跨进程模块：启动独立Godot读取已保存的数据，不共享连接或内存。
	var child_output: Array = []
	var child_code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/sqlite_process_probe.gd", "--", test_path], child_output, true)
	if child_code != 0:
		_fail("独立进程读取失败：" + str(child_output))
		return
	print("SQLITE_CHILD_REOPEN_PASS")
	repository = Repository.new()
	if not repository.open_store(test_path) or repository.load_gold().get("gold", -1) != 130:
		_fail("重开后读档失败")
		return
	if repository.save_gold(-1) or repository.save_gold(10000000) or repository.load_gold().get("gold", -1) != 130:
		_fail("非法值破坏存档")
		return
	# 回滚模块：模拟未完成写入，确认ROLLBACK保留上次已提交的金币。
	var db: SQLite = repository.database
	if not db.query("BEGIN IMMEDIATE;") or not db.query("UPDATE test_save SET gold = 999 WHERE slot_id = 1;") or not db.query("ROLLBACK;"):
		_fail("事务回滚执行失败")
		return
	if repository.load_gold().get("gold", -1) != 130:
		_fail("回滚后数值不一致")
		return
	if not db.query("PRAGMA user_version = 999;"):
		_fail("版本测试准备失败")
		return
	repository.close_store()
	if repository.open_store(test_path):
		_fail("错误接受新版本存档")
		return
	DirAccess.remove_absolute(test_path)
	print("SQLITE_PASS: empty, save, reopen, invalid input, rollback, version guard")
	quit(0)


# 失败模块：关闭连接并保留测试库供排查，不输出成功标记。
func _fail(message: String) -> void:
	repository.close_store()
	push_error(message)
	quit(1)
