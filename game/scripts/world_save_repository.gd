## 文件用途：将完整的战略原型快照存入独立SQLite库，与旧金币测试档隔离。
extends RefCounted

const State = preload("res://scripts/world_state.gd")
var database: SQLite
var error_message: String = ""


# 打开模块：只初始化本版本数据库，拒绝未知的新版本。
func open_store(path_override: String = "") -> bool:
	var path: String = path_override
	if path.is_empty():
		if OS.has_feature("portable_test"):
			path = OS.get_executable_path().get_base_dir().path_join("local_data/saves/world_prototype.db")
		elif OS.has_feature("editor"):
			path = ProjectSettings.globalize_path("res://local_data/saves/world_prototype.db")
		else:
			path = OS.get_user_data_dir().path_join("world_prototype.db")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		error_message = "无法创建存档目录"
		return false
	database = SQLite.new()
	database.path = path
	database.verbosity_level = 0
	if not database.open_db() or not _query("PRAGMA user_version;"):
		close_store()
		return false
	if int(database.query_result[0]["user_version"]) not in [0, 1, 2]:
		error_message = "不支持的数据库版本"
		close_store()
		return false
	if not _query("BEGIN IMMEDIATE;"):
		close_store()
		return false
	if not _query("CREATE TABLE IF NOT EXISTS world_snapshot(slot INTEGER PRIMARY KEY CHECK(slot=1), payload TEXT NOT NULL);") or not _query("CREATE TABLE IF NOT EXISTS snapshot_backup(id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL);") or not _query("PRAGMA user_version=2;") or not _query("COMMIT;"):
		database.query("ROLLBACK;")
		close_store()
		return false
	return true


# 保存模块：校验后以单事务替换快照，失败时不报告成功。
func save_world(world: RefCounted) -> bool:
	if database == null:
		error_message = "数据库未打开"
		return false
	var snapshot: Dictionary = world.snapshot()
	if State.from_snapshot(snapshot) == null:
		error_message = "当前状态未通过存档校验"
		return false
	if not _query("BEGIN IMMEDIATE;"):
		return false
	# 备份模块：同一事务中保留最近三个旧快照，迁移后第一次保存仍可找回旧内容。
	if not _query("INSERT INTO snapshot_backup(payload) SELECT payload FROM world_snapshot WHERE slot=1;") or not _query("DELETE FROM snapshot_backup WHERE id NOT IN (SELECT id FROM snapshot_backup ORDER BY id DESC LIMIT 3);"):
		database.query("ROLLBACK;")
		return false
	if not database.query_with_bindings("INSERT INTO world_snapshot(slot,payload) VALUES(1,?) ON CONFLICT(slot) DO UPDATE SET payload=excluded.payload;", [JSON.stringify(snapshot)]):
		error_message = database.error_message
		database.query("ROLLBACK;")
		return false
	if not _query("COMMIT;"):
		database.query("ROLLBACK;")
		return false
	return true


# 读取模块：解析与领域校验均成功后才返回可替换的新世界。
func load_world() -> RefCounted:
	error_message = ""
	if database == null or not _query("SELECT payload FROM world_snapshot WHERE slot=1;"):
		error_message = "数据库读取失败"
		return null
	if database.query_result.is_empty():
		error_message = "暂无战略存档，请先保存"
		return null
	var parser: JSON = JSON.new()
	if parser.parse(database.query_result[0]["payload"]) != OK:
		error_message = "存档格式损坏，当前进度保持不变"
		return null
	var result: RefCounted = State.from_snapshot(parser.data)
	if result == null:
		error_message = "存档损坏或版本不兼容，当前进度保持不变"
	return result


# 释放模块：关闭连接以允许程序退出和文件备份。
func close_store() -> void:
	if database != null:
		database.close_db()
		database = null


# 查询模块：保留SQLite提供的失败原因。
func _query(sql: String) -> bool:
	if database.query(sql):
		return true
	error_message = database.error_message
	return false
