## 文件用途：展示战略日期、资源、倍速和账单，通过领域模块操作世界与存档。
extends Control

const State = preload("res://scripts/world_state.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const ExportProbe = preload("res://scripts/export_probe.gd")

# 控制模块：界面只持有世界引用，资源计算和SQL分别由独立模块承担。
var world: RefCounted = State.new()
var clock: RefCounted = Clock.new(world)
var store: RefCounted = Store.new()
var store_path_override: String = ""
var date_label: Label
var resource_label: Label
var bill_label: Label
var status_label: Label
var pause_button: Button
var progress: ProgressBar
var panel: VBoxContainer


# 启动模块：普通运行进入战略原型，旧导出验收参数仍转入原存档测试场景。
func _ready() -> void:
	if OS.has_feature("portable_test") and not ExportProbe.get_mode().is_empty():
		set_process(false)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
		return
	_build_ui()
	var world_probe: String = ""
	if OS.has_feature("portable_test"):
		for argument: String in OS.get_cmdline_user_args():
			if argument in ["--verify-world=write", "--verify-world=read"]:
				world_probe = argument.get_slice("=", 1)
		if not world_probe.is_empty():
			store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/world_export.db")
	if not store.open_store(store_path_override):
		status_label.text = "存档不可用：" + store.error_message
		if not world_probe.is_empty():
			get_tree().quit(1)
			return
	_refresh()
	if not world_probe.is_empty():
		get_tree().quit(_verify_export(world_probe))


# 界面模块：仅使用引擎默认控件组成占位面板，不确定正式视觉设计。
func _build_ui() -> void:
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	panel.custom_minimum_size.x = 700
	center.add_child(panel)
	_label("Frontier Guardian — 战略原型")
	_label("规则验证占位界面；数值均为待平衡参数")
	date_label = _label("")
	resource_label = _label("")
	progress = ProgressBar.new()
	progress.max_value = State.DAY_TICKS
	progress.show_percentage = false
	panel.add_child(progress)
	var actions: HBoxContainer = _row()
	pause_button = _button(actions, "继续（空格）", _toggle_pause)
	for multiplier: int in [1, 2, 4]:
		_button(actions, "%d倍速" % multiplier, _set_speed.bind(multiplier))
	var saves: HBoxContainer = _row()
	_button(saves, "保存战略进度", _save)
	_button(saves, "读取战略进度", _load)
	bill_label = _label("")
	status_label = _label("新世界已暂停；请选择速度后继续")
	_label("1日=120秒；30居民每日粮食-15、税收+20；木石暂不生产")
	_label("空格暂停/继续，Esc退出；此阶段尚无建筑、军队与缺粮惩罚")


# 标签模块：统一设置换行与居中，避免较长账单超出窗口。
func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return label


# 行容器模块：只负责按钮布局，不承载业务状态。
func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	return row


# 按钮模块：连接明确操作，禁用焦点以避免空格误触保存等按钮。
func _button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button


# 帧模块：推进固定步时钟并显示结果，界面自身不执行日结。
func _process(delta: float) -> void:
	if date_label == null:
		return
	clock.advance(delta)
	_refresh()


# 刷新模块：日期、库存与账单全部来自同一份世界数据。
func _refresh() -> void:
	date_label.text = "第%d日  %02d时  | %d倍速 | %s" % [world.current_day(), int((world.tick % State.DAY_TICKS) * 24.0 / State.DAY_TICKS), world.speed, "已暂停" if world.paused else "运行中"]
	resource_label.text = "人口 %d  | 粮食 %d  | 金币 %d  | 木材 %d  | 石材 %d" % [world.population, world.resources["food"], world.resources["gold"], world.resources["wood"], world.resources["stone"]]
	progress.value = (world.tick % State.DAY_TICKS) + world.subsecond
	bill_label.text = world.last_bill
	pause_button.text = "继续（空格）" if world.paused else "暂停（空格）"


# 暂停模块：冻结战略时钟但保持界面与保存操作可用。
func _toggle_pause() -> void:
	world.paused = not world.paused
	_refresh()


# 倍速模块：仅修改时间推进倍率，不改变每日生产消费公式。
func _set_speed(multiplier: int) -> void:
	world.speed = multiplier
	_refresh()


# 保存模块：在完整逻辑步后捕获快照，写入成功才提示。
func _save() -> void:
	status_label.text = "保存成功：第%d日；已保存日期、资源与暂停状态" % world.current_day() if store.save_world(world) else "保存失败：" + store.error_message


# 读取模块：用校验成功的新世界替换旧引用，避免半读档和重复日结。
func _load() -> void:
	var candidate: RefCounted = store.load_world()
	if candidate == null:
		status_label.text = store.error_message
		return
	world = candidate
	clock = Clock.new(world)
	status_label.text = "读取成功：已恢复日期、资源、倍速与暂停状态"
	_refresh()


# 键盘模块：提供与按钮一致的暂停和退出操作。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


# 退出模块：只关闭连接，不擅自覆盖手动存档。
func _exit_tree() -> void:
	store.close_store()


# 导出验收模块：用独立测试库验证战略快照跨进程恢复与日结连续性。
func _verify_export(mode: String) -> int:
	if mode == "write":
		world.paused = false
		clock.advance(120.0)
		world.paused = true
		if not store.save_world(world):
			return 1
	else:
		var loaded: RefCounted = store.load_world()
		if loaded == null or loaded.current_day() != 2 or loaded.resources["food"] != 165 or loaded.resources["gold"] != 320:
			return 1
		loaded.paused = false
		var resumed: RefCounted = Clock.new(loaded)
		resumed.advance(120.0)
		if loaded.current_day() != 3 or loaded.resources["food"] != 150 or loaded.resources["gold"] != 340:
			return 1
	print("EXPORT_WORLD_PASS: ", mode)
	return 0
