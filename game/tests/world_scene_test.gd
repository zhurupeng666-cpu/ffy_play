## 文件用途：在隔离数据库上验证战略面板加载、暂停按钮与保存读取后的界面同步。
extends SceneTree


# 启动模块：等待场景树可添加节点后开始界面回归。
func _initialize() -> void:
	call_deferred("_run")


# 验收模块：测试世界引用和界面显示均恢复，失败不影响用户存档。
func _run() -> void:
	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var main: Control = scene.instantiate()
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/world_ui_%s.db" % Time.get_ticks_usec())
	main.store_path_override = path
	root.add_child(main)
	main._toggle_pause()
	main.clock.advance(120.0)
	main._toggle_pause()
	main._save()
	main.world.resources["gold"] = 999
	main._load()
	var passed: bool = main.world.current_day() == 2 and main.world.resources["food"] == 165 and main.world.resources["gold"] == 320 and main.world.paused and main.resource_label.text.contains("320")
	main.free()
	DirAccess.remove_absolute(path)
	if not passed:
		push_error("战略界面保存读取联动失败")
	else:
		print("WORLD_UI_PASS: scene, pause, save, load, resource display")
	quit(0 if passed else 1)
