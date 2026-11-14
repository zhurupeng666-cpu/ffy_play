## 文件用途：开发验证场景，提供运行暂停与SQLite金币存取演示，不承担正式经济和战略时钟。
extends Control

# 计时模块：只记录未暂停期间的运行秒数。
var elapsed_seconds: float = 0.0

# 存档模块：测试金币只保存在内存，点击保存才写入SQLite。
const Repository = preload("res://scripts/sqlite_save_repository.gd")
const ExportProbe = preload("res://scripts/export_probe.gd")
var save_repository: RefCounted = Repository.new()
var gold: int = 100
var save_path_override: String = ""

# 界面引用模块：场景就绪后获取计时、按钮和存档提示。
@onready var elapsed_label: Label = $Center/Panel/Elapsed
@onready var pause_button: Button = $Center/Panel/Pause
@onready var gold_label: Label = $Center/Panel/Gold
@onready var save_status: Label = $Center/Panel/SaveStatus


# 初始化模块：连接操作按钮并打开本地数据库。
func _ready() -> void:
	pause_button.pressed.connect(toggle_pause)
	$Center/Panel/SaveActions/Add.pressed.connect(_add_gold)
	$Center/Panel/SaveActions/Save.pressed.connect(_save_gold)
	$Center/Panel/SaveActions/Load.pressed.connect(_load_gold)
	# 导出验收模块：命令行测试使用独立库，不覆盖手动存档。
	var probe_mode: String = ExportProbe.get_mode() if OS.has_feature("portable_test") else ""
	if not probe_mode.is_empty():
		save_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/export_probe.db")
	if save_repository.open_store(save_path_override):
		save_status.text = "数据库就绪：初始100，点击读取可恢复上次保存"
	else:
		save_status.text = "数据库打开失败：" + save_repository.error_message
		$Center/Panel/SaveActions/Save.disabled = true
		$Center/Panel/SaveActions/Load.disabled = true
	_refresh_gold()
	print("FRONTIER_READY")
	if not probe_mode.is_empty():
		var result_code: int = ExportProbe.run(save_repository, probe_mode) if save_repository.database != null else 1
		get_tree().quit(result_code)


# 计时显示模块：未暂停时累加时间，暂停时保留显示。
func _process(delta: float) -> void:
	if not get_tree().paused:
		elapsed_seconds += delta # 断点测试位置：观察本帧时间与累计秒数。
	elapsed_label.text = "%s: %.1f s" % ["Paused" if get_tree().paused else "Running", elapsed_seconds]


# 键盘模块：空格切换暂停，退出键关闭测试窗口。
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


# 加值模块：只修改内存中的测试金币，不自动覆盖磁盘。
func _add_gold() -> void:
	gold = mini(gold + 10, Repository.MAX_GOLD)
	_refresh_gold()
	save_status.text = "金币已修改，尚未保存"


# 写入模块：成功提交事务后才显示保存成功。
func _save_gold() -> void:
	if save_repository.save_gold(gold):
		save_status.text = "保存成功：%d 金币；关闭重开后点击读取验证" % gold
	else:
		save_status.text = "保存失败：" + save_repository.error_message


# 读档模块：空槽或错误不改变当前金币，成功后更新显示。
func _load_gold() -> void:
	var result: Dictionary = save_repository.load_gold()
	if not result.get("ok", false):
		save_status.text = "读取失败：" + str(result.get("message", "未知错误"))
	elif not result.get("found", false):
		save_status.text = "暂无存档，请先保存"
	else:
		gold = int(result["gold"])
		_refresh_gold()
		save_status.text = "读取成功：%d 金币" % gold


# 金币显示模块：明确标记此数值仅用于存档验证。
func _refresh_gold() -> void:
	gold_label.text = "测试金币：%d" % gold


# 退出模块：窗口关闭时释放SQLite连接。
func _exit_tree() -> void:
	save_repository.close_store()
