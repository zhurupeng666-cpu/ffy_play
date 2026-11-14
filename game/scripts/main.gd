extends Control
## Environment smoke scene; elapsed time is not the campaign clock.

var elapsed_seconds: float = 0.0

@onready var elapsed_label: Label = $Center/Panel/Elapsed
@onready var pause_button: Button = $Center/Panel/Pause


func _ready() -> void:
	pause_button.pressed.connect(toggle_pause)
	print("FRONTIER_READY | user_data=", OS.get_user_data_dir())


func _process(delta: float) -> void:
	if not get_tree().paused:
		elapsed_seconds += delta # Set a breakpoint here to inspect elapsed_seconds.
	elapsed_label.text = "%s: %.1f s" % ["Paused" if get_tree().paused else "Running", elapsed_seconds]


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "Resume (Space)" if get_tree().paused else "Pause (Space)"
