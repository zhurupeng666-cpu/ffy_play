extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
