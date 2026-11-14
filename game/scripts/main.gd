## 文件用途：环境验证场景，提供运行计时、暂停恢复和退出操作；不承担正式战略时钟。
extends Control

# 计时模块：只记录未暂停期间的运行秒数。
var elapsed_seconds: float = 0.0

# 界面引用模块：场景就绪后获取计时标签与暂停按钮。
@onready var elapsed_label: Label = $Center/Panel/Elapsed
@onready var pause_button: Button = $Center/Panel/Pause


# 初始化模块：连接按钮事件并输出场景启动标记。
func _ready() -> void:
	pause_button.pressed.connect(toggle_pause)
	print("FRONTIER_READY | user_data=", OS.get_user_data_dir())


# 显示模块：未暂停时累加时间，并刷新当前状态。
func _process(delta: float) -> void:
	if not get_tree().paused:
		elapsed_seconds += delta # 断点测试位置：观察本帧时间与累计秒数。
	elapsed_label.text = "%s: %.1f s" % ["Paused" if get_tree().paused else "Running", elapsed_seconds]


# 键盘模块：空格暂停或恢复，退出键关闭测试窗口。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


# 暂停模块：切换场景树暂停状态，并同步按钮提示。
func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "Resume (Space)" if get_tree().paused else "Pause (Space)"
