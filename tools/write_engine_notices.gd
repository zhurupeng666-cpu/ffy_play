## 文件用途：提取当前Godot构建的引擎与内置第三方许可证，随独立测试包一并提供。
extends SceneTree


# 许可模块：按构建脚本指定路径写入引擎提供的完整声明，不修改许可原文。
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(args[0].get_base_dir()) != OK:
		quit(1)
		return
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(Engine.get_license_text() + "\n\n" + JSON.stringify(Engine.get_copyright_info(), "\t") + "\n\n" + JSON.stringify(Engine.get_license_info(), "\t"))
	file.close()
	quit(0)
