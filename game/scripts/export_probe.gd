## 文件用途：为导出包提供隔离的命令行存档验收，不触碰玩家手动测试槽。
extends RefCounted


# 模式模块：仅识别明确的导出测试参数，普通双击运行不启用。
static func get_mode() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--verify-export=write":
			return "write"
		if argument == "--verify-export=read":
			return "read"
	return ""


# 验收模块：两个独立导出进程先写入再读取，覆盖实际发布库加载。
static func run(repository: RefCounted, mode: String) -> int:
	if mode == "write":
		if not repository.save_gold(170):
			push_error(repository.error_message)
			return 1
	else:
		var result: Dictionary = repository.load_gold()
		if not result.get("ok", false) or result.get("gold", -1) != 170:
			push_error("导出进程未读取到已保存的170金币")
			return 1
	print("EXPORT_SQLITE_PASS: ", mode, " | ", repository.database_path)
	return 0
