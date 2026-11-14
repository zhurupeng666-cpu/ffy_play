## 文件用途：自动验证主场景加载、计时推进、暂停冻结与恢复运行。
extends SceneTree


# 启动模块：延迟到场景树就绪后执行测试。
func _initialize() -> void:
	call_deferred("_run")


# 验收模块：依次检查运行、暂停与恢复，全部通过后返回成功。
func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate()
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
	print("SMOKE_PASS: scene, time, pause, resume")
	quit(0)


# 失败模块：记录具体原因并用非零退出码通知调用方。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
