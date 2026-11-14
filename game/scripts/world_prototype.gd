## 文件用途：组织等距地图与战略管理界面，通过独立模块操作视图、世界和存档。
extends Control

const ConstructionProbe = preload("res://scripts/construction_export_probe.gd")
const Construction = preload("res://scripts/construction_service.gd")
const HOUSE = preload("res://data/buildings/house.tres")
const FARM = preload("res://data/buildings/farm.tres")
const TownMap = preload("res://scripts/town_map.gd")
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
var town_map: Control
var map_info: Label
var placement_label: Label
var building_label: Label
var pending_build_command: String = ""


# 启动模块：普通运行进入战略原型，旧导出验收参数仍转入原存档测试场景。
func _ready() -> void:
	if OS.has_feature("portable_test") and not ExportProbe.get_mode().is_empty():
		set_process(false)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
		return
	_build_ui()
	var world_probe: String = ""
	var build_probe: String = ""
	if OS.has_feature("portable_test"):
		for argument: String in OS.get_cmdline_user_args():
			if argument in ["--verify-world=write", "--verify-world=read"]:
				world_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-build=write", "--verify-build=read"]:
				build_probe = argument.get_slice("=", 1)
		if not world_probe.is_empty():
			store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/world_export.db")
	if not build_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/building_export.db")
	if not store.open_store(store_path_override):
		status_label.text = "存档不可用：" + store.error_message
		if not world_probe.is_empty() or not build_probe.is_empty():
			get_tree().quit(1)
			return
	_refresh()
	if not world_probe.is_empty():
		get_tree().quit(_verify_export(world_probe))
	if not build_probe.is_empty():
		get_tree().quit(ConstructionProbe.run(world, store, build_probe))


# 界面模块：左侧为占位地图，右侧为可滚动管理面板，二者输入互不穿透。
func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)
	var map_column: VBoxContainer = VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.custom_minimum_size.x = 320
	columns.add_child(map_column)
	var title: Label = Label.new()
	title.text = "城镇格网（16×16，占位）"
	map_column.add_child(title)
	town_map = TownMap.new()
	town_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	town_map.custom_minimum_size = Vector2(320, 200)
	map_column.add_child(town_map)
	map_info = Label.new()
	map_column.add_child(map_info)
	var map_actions: HBoxContainer = HBoxContainer.new()
	map_column.add_child(map_actions)
	_button(map_actions, "镜头复位（Home）", town_map.reset_view)
	var help: Label = Label.new()
	help.text = "左键选格或检查预览 / 右键取消 / 中键拖动 / 滚轮缩放"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_column.add_child(help)
	town_map.hovered_changed.connect(_on_map_cell_changed)
	town_map.selected_changed.connect(_on_map_cell_changed)
	town_map.view_changed.connect(_refresh_map_info)
	town_map.placement_changed.connect(_on_placement_changed)
	town_map.placement_clicked.connect(_on_placement_clicked)
	town_map.placement_cancelled.connect(_on_placement_cancelled)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 320
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	_label("领地管理（占位）")
	var building_actions: HBoxContainer = _row()
	_button(building_actions, "建住宅 2×2", _start_preview.bind(HOUSE))
	_button(building_actions, "建农场 4×4", _start_preview.bind(FARM))
	_button(building_actions, "取消", _cancel_preview)
	placement_label = _label("选择建筑；左键确认会扣材料")
	building_label = _label("")
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
	_label("1日120秒；每日粮食-15、税收+20。数值待平衡。")
	_label("中央为初始领主厅。左键确认建造；本阶段立即落地，尚无施工、生产与人口效果。")
	_sync_building_view()
	_refresh_map_info()


# 地块通知模块：只更新界面提示，不改变人口、库存或战略时间。
func _on_map_cell_changed(_cell: Vector2i) -> void:
	_refresh_map_info()


# 地图提示模块：分别显示悬停和选择，使用从0开始的逻辑坐标。
func _refresh_map_info() -> void:
	map_info.text = "悬停 %s  | 选中 %s  | 缩放 %d%%" % [_cell_text(town_map.hovered), _cell_text(town_map.selected), roundi(town_map.zoom_level * 100)]


# 坐标文本模块：地图外或未选择时显示短横线。
func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y] if cell.x >= 0 and cell.y >= 0 else "—"


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
	town_map.sync_resources(world.resources)
	building_label.text = "已建建筑：%d座（含初始领主厅）" % world.buildings.size()


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
	status_label.text = "保存成功：第%d日；已保存日期、资源、建筑与暂停状态" % world.current_day() if store.save_world(world) else "保存失败：" + store.error_message


# 读取模块：用校验成功的新世界替换旧引用，避免半读档和重复日结。
func _load() -> void:
	var candidate: RefCounted = store.load_world()
	if candidate == null:
		status_label.text = store.error_message
		return
	world = candidate
	clock = Clock.new(world)
	town_map.cancel_preview()
	_sync_building_view()
	status_label.text = "读取成功：已恢复日期、资源、建筑与暂停状态"
	_refresh()


# 键盘模块：提供与按钮一致的暂停和退出操作。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			town_map.reset_view()
		elif event.keycode == KEY_ESCAPE:
			if town_map.active_definition != null:
				town_map.cancel_preview()
				get_viewport().set_input_as_handled()
			else:
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


# 建筑选择模块：为一次放置生成唯一命令，失败时可调整位置重试。
func _start_preview(definition: Resource) -> void:
	pending_build_command = Crypto.new().generate_random_bytes(16).hex_encode()
	town_map.set_preview(definition)
	var cost: Dictionary = definition.get("cost")
	status_label.text = "建造%s：木材%d、金币%d；左键确认扣费" % [definition.get("display_name"), cost.get("wood", 0), cost.get("gold", 0)]


# 取消入口模块：提供按钮与鼠标右键一致的操作。
func _cancel_preview() -> void:
	town_map.cancel_preview()


# 预览提示模块：显示几何和费用校验原因，不凭预览结果直接扣费。
func _on_placement_changed(result: Dictionary) -> void:
	if placement_label == null:
		return
	if not result.get("active", false):
		placement_label.text = "已退出建造模式，可普通选格"
	else:
		placement_label.text = str(town_map.active_definition.get("display_name")) + "：" + str(result.get("reason", ""))


# 确认建造模块：重新检查权威世界，成功后同步视图并退出单次放置模式。
func _on_placement_clicked(_result: Dictionary) -> void:
	if town_map.active_definition == null:
		return
	var definition: Resource = town_map.active_definition
	var result: Dictionary = Construction.execute(world, definition.get("id"), town_map.hovered, pending_build_command)
	if not result["ok"]:
		status_label.text = "建造失败：" + str(result.get("reason", ""))
		return
	_sync_building_view()
	town_map.cancel_preview()
	_refresh()
	var cost: Dictionary = result["cost"]
	status_label.text = "建造成功：%s；木材-%d，金币-%d（请保存战略进度）" % [definition.get("display_name"), cost.get("wood", 0), cost.get("gold", 0)]


# 取消提示模块：清除尚未提交的命令，不修改已建实例或资源。
func _on_placement_cancelled() -> void:
	pending_build_command = ""
	if status_label != null:
		status_label.text = "已退出建造模式，恢复普通选格"


# 视图同步模块：建造或读档后，从权威数据重建建筑占用与费用提示。
func _sync_building_view() -> void:
	town_map.sync_buildings(world.buildings)
	town_map.sync_resources(world.resources)
