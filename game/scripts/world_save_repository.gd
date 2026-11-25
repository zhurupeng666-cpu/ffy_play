## 文件用途：在 SQLite 中保留七份战略存档，提供按时间浏览、事务轮换与旧库迁移。
extends RefCounted

const State = preload("res://scripts/world_state.gd")
const SAVE_LIMIT: int = 7
var database: SQLite
var error_message: String = ""


# 打开模块：定位存档目录，初始化或迁移 SQLite 表。
func open_store(path_override: String = "") -> bool:
	close_store()
	error_message = ""
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
	var version: int = int(database.query_result[0]["user_version"])
	if version not in [0, 1, 2, 3]:
		error_message = "不支持的数据库版本"
		close_store()
		return false
	if version == 3:
		return true
	if not _query("BEGIN IMMEDIATE;"):
		close_store()
		return false
	if not _migrate_legacy() or not _query("COMMIT;"):
		database.query("ROLLBACK;")
		close_store()
		return false
	return true


# 迁移模块：旧备份按顺序纳入列表，未知保存时间保留为空。
func _migrate_legacy() -> bool:
	if not _query("CREATE TABLE world_saves(id INTEGER PRIMARY KEY AUTOINCREMENT, saved_at INTEGER, game_day INTEGER NOT NULL, title TEXT NOT NULL, payload TEXT NOT NULL);"):
		return false
	if not _query("CREATE TABLE IF NOT EXISTS world_snapshot(slot INTEGER PRIMARY KEY CHECK(slot=1), payload TEXT NOT NULL);") \
		or not _query("CREATE TABLE IF NOT EXISTS snapshot_backup(id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL);"):
		return false
	if not _query("SELECT payload FROM snapshot_backup ORDER BY id ASC;"):
		return false
	var backups: Array = database.query_result.duplicate(true)
	if not _query("SELECT payload FROM world_snapshot WHERE slot=1;"):
		return false
	backups.append_array(database.query_result.duplicate(true))
	for row: Dictionary in backups:
		var raw: Variant = JSON.parse_string(row["payload"])
		var day: int = 0
		if raw is Dictionary and typeof(raw.get("tick")) in [TYPE_INT, TYPE_FLOAT]:
			var tick: float = float(raw["tick"])
			if is_finite(tick) and tick >= 0 and tick <= 120000000:
				day = floori(tick / State.DAY_TICKS) + 1
		if not _bound("INSERT INTO world_saves(saved_at,game_day,title,payload) VALUES(NULL,?,?,?);", [day, "旧版进度", row["payload"]]):
			return false
	return _trim() and _query("DROP TABLE snapshot_backup;") and _query("DROP TABLE world_snapshot;") and _query("PRAGMA user_version=3;")


# 保存模块：新档与淘汰最早档在同一事务，任一失败就恢复原列表。
func save_world(world: RefCounted, title: String = "战略进度") -> bool:
	error_message = ""
	if database == null:
		error_message = "数据库未打开"
		return false
	var snapshot: Dictionary = world.snapshot()
	if State.from_snapshot(snapshot) == null:
		error_message = "当前状态未通过存档校验"
		return false
	if not _query("BEGIN IMMEDIATE;"):
		return false
	var now: int = int(Time.get_unix_time_from_system())
	if not _bound("INSERT INTO world_saves(saved_at,game_day,title,payload) VALUES(?,?,?,?);", [now, world.current_day(), title, JSON.stringify(snapshot)]) \
		or not _trim() or not _query("COMMIT;"):
		database.query("ROLLBACK;")
		return false
	return true


# 保留模块：按写入顺序淘汰，系统时间调整或同一秒保存也能稳定排序。
func _trim() -> bool:
	return _query("DELETE FROM world_saves WHERE id NOT IN (SELECT id FROM world_saves ORDER BY id DESC LIMIT %d);" % SAVE_LIMIT)


# 列表模块：只读取元信息，时间按当前系统时区显示。
func list_saves() -> Array:
	error_message = ""
	if database == null:
		error_message = "数据库未打开"
		return []
	if not _query("SELECT id, game_day, title, datetime(saved_at,'unixepoch','localtime') AS saved_local FROM world_saves ORDER BY id DESC;"):
		return []
	return database.query_result.duplicate(true)


# 读取模块：按稳定 ID 读取。缺省取最新一份，用于程序内恢复和验收。
func load_world(save_id: int = 0) -> RefCounted:
	error_message = ""
	if database == null:
		error_message = "数据库未打开"
		return null
	if save_id > 0:
		if not _bound("SELECT payload FROM world_saves WHERE id=?;", [save_id]):
			return null
	elif not _query("SELECT payload FROM world_saves ORDER BY id DESC LIMIT 1;"):
		return null
	if database.query_result.is_empty():
		error_message = "未找到此存档，请重新选择"
		return null
	var parser: JSON = JSON.new()
	if parser.parse(database.query_result[0]["payload"]) != OK:
		error_message = "存档格式损坏，当前进度保持不变"
		return null
	var result: RefCounted = State.from_snapshot(parser.data)
	if result == null:
		error_message = "存档损坏或版本不兼容，当前进度保持不变"
	return result


# 释放模块：关闭连接，允许安全复制数据库。
func close_store() -> void:
	if database != null:
		database.close_db()
		database = null


# 查询模块：保留 SQLite 提供的失败原因。
func _query(sql: String) -> bool:
	if database.query(sql):
		return true
	error_message = database.error_message
	return false


# 绑定模块：保存内容和 ID 通过参数交给 SQLite。
func _bound(sql: String, parameters: Array) -> bool:
	if database.query_with_bindings(sql, parameters):
		return true
	error_message = database.error_message
	return false
