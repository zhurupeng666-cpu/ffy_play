## 文件用途：自动验证主场景加载、计时推进、暂停冻结与恢复运行。
extends SceneTree


# 启动模块：延迟到场景树就绪后执行测试。
func _initialize() -> void:
	call_deferred("_run")


# 验收模块：依次检查运行、暂停与恢复，全部通过后返回成功。
func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate()
	main.save_path_override = ProjectSettings.globalize_path("res://local_data/tests/main_%s.db" % Time.get_ticks_usec())
	root.add_child(main)
	await create_timer(0.15).timeout
	if main.elapsed_seconds <= 0.0:
		_fail("Clock did not advance")
		return
	main.toggle_pause()
	var before: float = main.elapsed_seconds
	await create_timer(0.15, true).timeout
	if not is_equal_approx(main.elapsed_seconds, before):
		_fail("Clock advanced while paused")
		return
	main.toggle_pause()
	await create_timer(0.15).timeout
	if main.elapsed_seconds <= before:
		_fail("Clock did not resume")
		return
	# 界面存档模块：检查加值、保存和读取确实同步到标签与内存。
	main._add_gold()
	main._save_gold()
	main._add_gold()
	main._load_gold()
	if main.gold != 110 or not str(main.save_status.text).begins_with("读取成功"):
		_fail("界面存档联动失败")
		return
	var temporary_path: String = main.save_path_override
	main.free()
	DirAccess.remove_absolute(temporary_path)
	print("SMOKE_PASS: scene, time, pause, resume")
	quit(0)


# 失败模块：记录具体原因并用非零退出码通知调用方。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
