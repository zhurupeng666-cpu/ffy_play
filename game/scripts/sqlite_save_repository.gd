## 文件用途：封装SQLite测试存档，提供打开、事务保存、读取与关闭，隔离界面和SQL。
extends RefCounted

# 配置模块：限制测试金币范围，区分测试数据与正式世界存档。
const MAX_GOLD: int = 9999999
const SCHEMA_VERSION: int = 1
var database: SQLite
var error_message: String = ""
var database_path: String = ""


# 连接模块：创建目录、检查版本，并以事务初始化单槽测试表。
func open_store(path_override: String = "") -> bool:
	close_store()
	error_message = ""
	database_path = path_override
	if database_path.is_empty():
		database_path = ProjectSettings.globalize_path("res://local_data/saves/frontier_test.db") if OS.has_feature("editor") else OS.get_user_data_dir().path_join("frontier_test.db")
	if DirAccess.make_dir_recursive_absolute(database_path.get_base_dir()) != OK:
		error_message = "无法创建存档目录"
		return false
	database = SQLite.new()
	database.path = database_path
	database.verbosity_level = 0
	if not database.open_db():
		error_message = database.error_message
		close_store()
		return false
	if not _query("PRAGMA user_version;"):
		close_store()
		return false
	var version: int = int(database.query_result[0]["user_version"])
	if version > SCHEMA_VERSION:
		error_message = "存档版本高于当前程序，禁止覆盖"
		close_store()
		return false
	if not _query("BEGIN IMMEDIATE;"):
		close_store()
		return false
	if not _query("CREATE TABLE IF NOT EXISTS test_save (slot_id INTEGER PRIMARY KEY CHECK(slot_id = 1), gold INTEGER NOT NULL CHECK(gold >= 0 AND gold <= 9999999));") or not _query("PRAGMA user_version = 1;") or not _query("COMMIT;"):
		database.query("ROLLBACK;")
		close_store()
		return false
	return true


# 保存模块：参数绑定与单事务写入，任何失败均尝试回滚，不报告假成功。
func save_gold(gold: int) -> bool:
	error_message = ""
	if database == null:
		error_message = "数据库未打开"
		return false
	if gold < 0 or gold > MAX_GOLD:
		error_message = "金币超出测试范围"
		return false
	if not _query("BEGIN IMMEDIATE;"):
		return false
	if not database.query_with_bindings("INSERT INTO test_save(slot_id, gold) VALUES (1, ?) ON CONFLICT(slot_id) DO UPDATE SET gold = excluded.gold;", [gold]):
		error_message = database.error_message
		database.query("ROLLBACK;")
		return false
	if not _query("COMMIT;"):
		database.query("ROLLBACK;")
		return false
	return true


# 读取模块：区分空槽和错误，只有完整有效的数值才交给调用者。
func load_gold() -> Dictionary:
	error_message = ""
	if database == null:
		return {"ok": false, "message": "数据库未打开"}
	if not _query("SELECT gold FROM test_save WHERE slot_id = 1;"):
		return {"ok": false, "message": error_message}
	if database.query_result.is_empty():
		return {"ok": true, "found": false}
	var gold: int = int(database.query_result[0]["gold"])
	if gold < 0 or gold > MAX_GOLD:
		return {"ok": false, "message": "存档金币无效"}
	return {"ok": true, "found": true, "gold": gold}


# 释放模块：场景退出或测试结束时关闭连接，避免占用数据库文件。
func close_store() -> void:
	if database != null:
		database.close_db()
		database = null


# SQL模块：集中保留失败原因，供界面提示与自动测试定位。
func _query(sql: String) -> bool:
	if database.query(sql):
		return true
	error_message = database.error_message
	return false
