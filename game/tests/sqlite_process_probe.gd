## 文件用途：在独立Godot进程中读取自动测试库，确认数据已落盘而非仅留在内存。
extends SceneTree

const Repository = preload("res://scripts/sqlite_save_repository.gd")


# 跨进程验收模块：只读取测试目录中的数据库，读到130才返回成功。
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var safe_root: String = ProjectSettings.globalize_path("res://local_data/tests/").simplify_path() + "/"
	if args.size() != 1 or not args[0].simplify_path().begins_with(safe_root):
		quit(1)
		return
	var repository: RefCounted = Repository.new()
	if not repository.open_store(args[0]):
		quit(1)
		return
	var result: Dictionary = repository.load_gold()
	repository.close_store()
	if result.get("gold", -1) != 130:
		quit(1)
		return
	print("SQLITE_CHILD_REOPEN_PASS")
	quit(0)
