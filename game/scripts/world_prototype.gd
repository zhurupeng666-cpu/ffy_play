## 文件用途：组织等距地图与战略管理界面，通过独立模块操作视图、世界和存档。
extends Control

const LegionProbe = preload("res://scripts/legion_export_probe.gd")
const Legions = preload("res://scripts/legion_service.gd")
const DisbandProbe = preload("res://scripts/army_disband_export_probe.gd")
const ArmyDisband = preload("res://scripts/army_disband_service.gd")
const ArmyProbe = preload("res://scripts/army_export_probe.gd")
const Army = preload("res://scripts/army_service.gd")
const CivicProbe = preload("res://scripts/civic_export_probe.gd")
const Civic = preload("res://scripts/civic_economy.gd")
const RemovalProbe = preload("res://scripts/removal_export_probe.gd")
const InspectionProbe = preload("res://scripts/inspection_export_probe.gd")
const Removal = preload("res://scripts/removal_service.gd")
const Inspector = preload("res://scripts/building_inspector.gd")
const MaterialProbe = preload("res://scripts/material_export_probe.gd")
const StorageProbe = preload("res://scripts/storage_export_probe.gd")
const ProductionProbe = preload("res://scripts/production_export_probe.gd")
const ConstructionProbe = preload("res://scripts/construction_export_probe.gd")
const Construction = preload("res://scripts/construction_service.gd")
const BARRACKS = preload("res://data/buildings/barracks.tres")
const LUMBER = preload("res://data/buildings/lumber.tres")
const QUARRY = preload("res://data/buildings/quarry.tres")
const GRANARY = preload("res://data/buildings/granary.tres")
const HOUSE = preload("res://data/buildings/house.tres")
const FARM = preload("res://data/buildings/farm.tres")
const RANCH = preload("res://data/buildings/ranch.tres")
const FISHERY = preload("res://data/buildings/fishery.tres")
const RegionOverview = preload("res://scripts/region_overview.gd")
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
var storage_label: Label
var civic_label: Label
var civic_bill_label: Label
var tax_buttons: Dictionary = {}
var food_detail_label: Label
var food_detail_button: Button
var food_details_visible: bool = false
var material_bill_label: Label
var bill_label: Label
var status_label: Label
var pause_button: Button
var progress: ProgressBar
var panel: VBoxContainer
var town_map: Control
# 地图导航模块：城镇和区域总览使用同一个世界与时钟。
var town_view: VBoxContainer
var region_overview: RegionOverview
var region_toggle: Button
var map_info: Label
var placement_label: Label
var building_label: Label
var construction_label: Label
var labor_label: Label
var production_label: Label
var producer_picker: OptionButton
var producer_detail: Label
var producer_signature: String = ""
var displayed_building_tick: int = -1
var pending_build_command: String = ""
var inspected_building_id: String = ""
var management_scroll: ScrollContainer
var inspection_card: PanelContainer
var inspection_label: Label
var inspection_increase: Button
var inspection_decrease: Button
var inspection_remove: Button
var army_label: Label
var army_bill_label: Label
var army_detail_label: Label
var army_recruit_button: Button
var army_troop_picker: OptionButton
var army_disband_button: Button
var army_disband_dialog: ConfirmationDialog
var army_disband_offer: Dictionary = {}
var army_disband_command: String = ""
var army_disband_was_paused: bool = true
var army_picker_signature: String = ""
var legion_toggle: Button
var legion_body: VBoxContainer
var legion_picker: OptionButton
var legion_troop_picker: OptionButton
var legion_people: SpinBox
var legion_detail: Label
var legion_available: Label
var legion_create: Button
var legion_apply: Button
var legion_remove: Button
var legion_close: Button
var selected_legion_id: String = ""
var legion_signature: String = ""
var legion_updating: bool = false
var legion_dialog: ConfirmationDialog
var legion_close_offer: Dictionary = {}
var legion_was_paused: bool = true
var removal_dialog: ConfirmationDialog
var removal_offer: Dictionary = {}
var removal_command: String = ""
var removal_was_paused: bool = true


# 启动模块：普通运行进入战略原型，旧导出验收参数仍转入原存档测试场景。
func _ready() -> void:
	if OS.has_feature("portable_test") and not ExportProbe.get_mode().is_empty():
		set_process(false)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
		return
	_build_ui()
	var world_probe: String = ""
	var build_probe: String = ""
	var food_probe: String = ""
	var storage_probe: String = ""
	var material_probe: String = ""
	var inspection_probe: String = ""
	var removal_probe: String = ""
	var civic_probe: String = ""
	var army_probe: String = ""
	var disband_probe: String = ""
	var legion_probe: String = ""
	if OS.has_feature("portable_test"):
		for argument: String in OS.get_cmdline_user_args():
			if argument in ["--verify-world=write", "--verify-world=read"]:
				world_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-build=write", "--verify-build=read"]:
				build_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-food=write", "--verify-food=read"]:
				food_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-storage=write", "--verify-storage=read"]:
				storage_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-material=write", "--verify-material=read"]:
				material_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-inspect=write", "--verify-inspect=read"]:
				inspection_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-removal=write", "--verify-removal=read"]:
				removal_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-civic=write", "--verify-civic=read"]:
				civic_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-army=write", "--verify-army=read"]:
				army_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-disband=write", "--verify-disband=read"]:
				disband_probe = argument.get_slice("=", 1)
			elif argument in ["--verify-legion=write", "--verify-legion=read"]:
				legion_probe = argument.get_slice("=", 1)
		if not world_probe.is_empty():
			store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/world_export.db")
	if not build_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/building_export.db")
	if not food_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/food_export.db")
	if not storage_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/storage_export.db")
	if not material_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/material_export.db")
	if not inspection_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/inspection_export.db")
	if not removal_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/removal_export.db")
	if not civic_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/civic_export.db")
	if not army_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/army_export.db")
	if not disband_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/disband_export.db")
	if not legion_probe.is_empty():
		store_path_override = OS.get_executable_path().get_base_dir().path_join("local_data/tests/legion_export.db")
	if not store.open_store(store_path_override):
		status_label.text = "存档不可用：" + store.error_message
		if not world_probe.is_empty() or not build_probe.is_empty() or not food_probe.is_empty() or not storage_probe.is_empty() or not material_probe.is_empty() or not inspection_probe.is_empty() or not removal_probe.is_empty() or not civic_probe.is_empty() or not army_probe.is_empty() or not disband_probe.is_empty() or not legion_probe.is_empty():
			get_tree().quit(1)
			return
	_refresh()
	if not world_probe.is_empty():
		get_tree().quit(_verify_export(world_probe))
	if not build_probe.is_empty():
		get_tree().quit(ConstructionProbe.run(world, store, build_probe))
	if not food_probe.is_empty():
		get_tree().quit(ProductionProbe.run(world, store, food_probe))
	if not storage_probe.is_empty():
		get_tree().quit(StorageProbe.run(world, store, storage_probe))
	if not material_probe.is_empty():
		get_tree().quit(MaterialProbe.run(world, store, material_probe))
	if not inspection_probe.is_empty():
		get_tree().quit(InspectionProbe.run(self, inspection_probe))
	if not removal_probe.is_empty():
		get_tree().quit(RemovalProbe.run(self, removal_probe))
	if not civic_probe.is_empty():
		get_tree().quit(CivicProbe.run(self, civic_probe))
	if not army_probe.is_empty():
		get_tree().quit(ArmyProbe.run(self, army_probe))
	if not disband_probe.is_empty():
		get_tree().quit(DisbandProbe.run(self, disband_probe))
	if not legion_probe.is_empty():
		get_tree().quit(LegionProbe.run(self, legion_probe))


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
	var navigation: HBoxContainer = HBoxContainer.new()
	map_column.add_child(navigation)
	region_toggle = _button(navigation, "区域地图", _toggle_region_view)
	town_view = VBoxContainer.new()
	town_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_child(town_view)
	region_overview = RegionOverview.new()
	region_overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	region_overview.hide()
	region_overview.town_requested.connect(_show_region_view.bind(false))
	map_column.add_child(region_overview)
	var title: Label = Label.new()
	title.text = "边境镇 · 城镇地图"
	town_view.add_child(title)
	town_map = TownMap.new()
	town_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	town_map.custom_minimum_size = Vector2(320, 200)
	town_view.add_child(town_map)
	map_info = Label.new()
	town_view.add_child(map_info)
	var map_actions: HBoxContainer = HBoxContainer.new()
	town_view.add_child(map_actions)
	_button(map_actions, "镜头复位（Home）", town_map.reset_view)
	var help: Label = Label.new()
	help.text = "单击整选 / 双击聚焦建筑 / 中键拖动 / 滚轮缩放 / 右键取消\n伐木场须紧邻林地，采石场须紧邻石矿"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	town_view.add_child(help)
	town_map.hovered_changed.connect(_on_map_cell_changed)
	town_map.selected_changed.connect(_on_town_selected)
	town_map.view_changed.connect(_refresh_map_info)
	town_map.placement_changed.connect(_on_placement_changed)
	town_map.placement_clicked.connect(_on_placement_clicked)
	town_map.placement_cancelled.connect(_on_placement_cancelled)
	var scroll: ScrollContainer = ScrollContainer.new()
	management_scroll = scroll
	scroll.custom_minimum_size.x = 320
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	_label("领地管理")
	date_label = _label("")
	resource_label = _label("")
	storage_label = _label("")
	civic_label = _label("")
	var taxes: HBoxContainer = _row()
	for policy: String in Civic.POLICIES:
		tax_buttons[policy] = _button(taxes, Civic.policy_name(policy), _set_tax_policy.bind(policy))
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
	_build_inspection_card()
	army_label = _label("" )
	_build_legion_panel()
	bill_label = _label("")
	food_detail_button = _button(_row(), "展开粮食收支", _toggle_food_details)
	food_detail_label = _label("")
	civic_bill_label = _label("")
	army_bill_label = _label("")
	material_bill_label = _label("")
	status_label = _label("新世界已暂停；请选择速度后继续")
	var building_actions: HBoxContainer = _row()
	_button(building_actions, "建住宅 2×2", _start_preview.bind(HOUSE))
	_button(building_actions, "建农场 4×4", _start_preview.bind(FARM))
	_button(building_actions, "建粮仓 3×3", _start_preview.bind(GRANARY))
	var food_actions: HBoxContainer = _row()
	_button(food_actions, "建牧场 4×4", _start_preview.bind(RANCH))
	_button(food_actions, "建渔场 3×2", _start_preview.bind(FISHERY))
	_button(food_actions, "取消", _cancel_preview)
	var material_actions: HBoxContainer = _row()
	_button(material_actions, "建伐木场 3×3", _start_preview.bind(LUMBER))
	_button(material_actions, "建采石场 3×3", _start_preview.bind(QUARRY))
	var military_actions: HBoxContainer = _row()
	_button(military_actions, "建军营 3×3", _start_preview.bind(BARRACKS))
	placement_label = _label("选择建筑；左键确认会扣材料")
	building_label = _label("")
	construction_label = _label("")
	labor_label = _label("")
	var labor_actions: HBoxContainer = _row()
	_button(labor_actions, "工人 -1", _change_builders.bind(-1))
	_button(labor_actions, "工人 +1", _change_builders.bind(1))
	production_label = _label("")
	producer_picker = OptionButton.new()
	panel.add_child(producer_picker)
	producer_picker.item_selected.connect(_on_producer_selected)
	producer_detail = _label("")
	var production_actions: HBoxContainer = _row()
	_button(production_actions, "生产工人 -1", _change_producers.bind(-1))
	_button(production_actions, "生产工人 +1", _change_producers.bind(1))
	_label("1日120秒；每日先收粮再消耗15；税收受税率与满意度影响。数值待平衡。")
	_label("中央为初始领主厅。左键确认建造；单队施工：2人原速、1人半速、0人停工。完工住宅+10容量；生产建筑完工后在下拉框分配工人；每日入库产物，暂无人口增长。")
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


# 切换入口模块：总览按钮在两个地图视图之间往返。
func _toggle_region_view() -> void:
	_show_region_view(not region_overview.visible)


# 地图切换模块：退出未确认的建造预览，保留城镇镜头、战略时钟和世界状态。
func _show_region_view(show_overview: bool) -> void:
	if show_overview and town_map.active_definition != null:
		town_map.cancel_preview()
	if show_overview:
		region_overview.sync(world)
	region_overview.visible = show_overview
	town_view.visible = not show_overview
	region_toggle.text = "返回城镇" if show_overview else "区域地图"


# 帧模块：推进固定步时钟并显示结果，界面自身不执行日结。
func _process(delta: float) -> void:
	if date_label == null:
		return
	clock.advance(delta)
	_refresh()


# 刷新模块：日期、库存与账单全部来自同一份世界数据。
func _refresh() -> void:
	if region_overview.visible:
		region_overview.sync(world)
	_refresh_legions()
	_refresh_army()
	_refresh_civic()
	_refresh_inspection()
	date_label.text = "第%d日  %02d时  | %d倍速 | %s" % [world.current_day(), int((world.tick % State.DAY_TICKS) * 24.0 / State.DAY_TICKS), world.speed, "已暂停" if world.paused else "运行中"]
	resource_label.text = "人口 %d  | 粮食 %d  | 金币 %d  | 木材 %d  | 石材 %d" % [world.population, world.resources["food"], world.resources["gold"], world.resources["wood"], world.resources["stone"]]
	progress.value = (world.tick % State.DAY_TICKS) + world.subsecond
	bill_label.text = world.last_bill
	_refresh_storage()
	pause_button.text = "继续（空格）" if world.paused else "暂停（空格）"
	town_map.sync_resources(world.resources)
	var ready_count: int = 0
	var queued_count: int = 0
	var active_text: String = "无施工任务"
	for building: Dictionary in world.buildings:
		if building["state"] == "ready":
			ready_count += 1
		else:
			queued_count += 1
			if queued_count == 1:
				active_text = "施工中：%s %d%%" % [Construction.Catalog.find(building["def_id"]).get("display_name"), floori(100.0 * building["work_done"] / building["work_required"])]
	building_label.text = "建筑%d座：完工%d，待完工%d" % [world.buildings.size(), ready_count, queued_count]
	labor_label.text = "人口%d / 住房%d；可就业%d，被抚养%d；施工%d，空闲%d；军职%d" % [world.population, world.housing_capacity(), world.population - world.dependents, world.dependents, world.builders, world.idle_workers(), Army.people(world.troops, true)]
	_refresh_production()
	construction_label.text = active_text + ("；另有%d座等待" % (queued_count - 1) if queued_count > 1 else "")
	if queued_count > 0 and world.builders == 0:
		construction_label.text += "；缺施工工人，已停工"
	if displayed_building_tick != world.tick:
		displayed_building_tick = world.tick
		town_map.sync_buildings(world.buildings)


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
	_cancel_legion_close()
	selected_legion_id = ""
	legion_signature = ""
	_cancel_army_disband()
	_cancel_removal()
	var candidate: RefCounted = store.load_world()
	if candidate == null:
		status_label.text = store.error_message
		return
	_clear_inspection()
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
			if region_overview.visible:
				_show_region_view(false)
				get_viewport().set_input_as_handled()
			elif town_map.active_definition != null:
				town_map.cancel_preview()
				get_viewport().set_input_as_handled()
			else:
				get_tree().quit()


# 退出模块：只关闭连接，不擅自覆盖手动存档。
func _exit_tree() -> void:
	store.close_store()


# 导出验收模块：用独立测试库验证战略快照跨进程恢复与日结连续性。
func _verify_export(mode: String) -> int:
	# 区域入口验收：真实导出包可往返，林地锁定且不显示未发现区域。
	region_toggle.pressed.emit()
	if not region_overview.visible or town_view.visible or region_overview.markers.has("r_fort"):
		return 1
	region_overview.markers["r_woods"].pressed.emit()
	if not region_overview.enter_button.disabled or not region_overview.scout_button.is_visible_in_tree() or not region_overview.scout_button.disabled:
		return 1
	region_overview.markers["r_home"].pressed.emit()
	region_overview.enter_button.pressed.emit()
	if not town_view.visible or region_overview.visible:
		return 1
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
	_show_region_view(false)
	_clear_inspection()
	pending_build_command = Crypto.new().generate_random_bytes(16).hex_encode()
	town_map.set_preview(definition)
	var cost: Dictionary = definition.get("cost")
	status_label.text = "建造%s：木材%d、石材%d、金币%d；左键确认扣费" % [definition.get("display_name"), cost.get("wood", 0), cost.get("stone", 0), cost.get("gold", 0)]


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
	_inspect_building(str(result["building_id"]), true)
	var cost: Dictionary = result["cost"]
	status_label.text = "建造成功：%s工地已入队；木材-%d，石材-%d，金币-%d（请保存）" % [definition.get("display_name"), cost.get("wood", 0), cost.get("stone", 0), cost.get("gold", 0)]


# 取消提示模块：清除尚未提交的命令，不修改已建实例或资源。
func _on_placement_cancelled() -> void:
	pending_build_command = ""
	if status_label != null:
		status_label.text = "已退出建造模式，恢复普通选格"


# 视图同步模块：建造或读档后，从权威数据重建建筑占用与费用提示。
func _sync_building_view() -> void:
	town_map.sync_buildings(world.buildings)
	town_map.sync_resources(world.resources)


# 岗位操作模块：按钮只发出分配请求，守恒与上限由世界模型验证。
func _change_builders(delta: int) -> void:
	if world.assign_builders(world.builders + delta):
		status_label.text = "施工工人已调整为%d；分配会随战略进度保存" % world.builders
	else:
		status_label.text = "施工人数需在0至2之间，且不能超过可就业人口"
	_refresh()


# 生产面板模块：按稳定建筑ID选择岗位，列表只在建筑结构变化或读档时重建。
func _refresh_production() -> void:
	var signature: String = ""
	var summaries: Dictionary = {}
	for id: String in Construction.Catalog.PRODUCERS:
		summaries[id] = [0, 0]
	for building: Dictionary in world.buildings:
		if summaries.has(building["def_id"]):
			signature += str(building["id"]) + str(building["state"])
			summaries[building["def_id"]][0] += int(building["workers"])
			if building["state"] == "ready":
				summaries[building["def_id"]][1] += int(Construction.Catalog.find(building["def_id"]).get("worker_slots"))
	if signature != producer_signature or producer_picker.item_count == 0:
		var selected_id: String = str(producer_picker.get_item_metadata(producer_picker.selected)) if producer_picker.selected >= 0 else ""
		producer_picker.clear()
		for building: Dictionary in world.buildings:
			if summaries.has(building["def_id"]):
				var name_text: String = str(Construction.Catalog.find(building["def_id"]).get("display_name"))
				producer_picker.add_item(name_text + " " + str(building["id"]).trim_prefix("building_") + ("（施工中）" if building["state"] != "ready" else ""))
				var index: int = producer_picker.item_count - 1
				producer_picker.set_item_metadata(index, building["id"])
				if building["id"] == selected_id:
					producer_picker.select(index)
		producer_signature = signature
	var lines: PackedStringArray = ["生产岗位%d；按实际在岗时间累计" % world.production_workers()]
	for id: String in summaries:
		var definition: Resource = Construction.Catalog.find(id)
		var info: Dictionary = _production_info(definition)
		lines.append("%s：%d/%d人；当前全天折算%d%s" % [definition.get("display_name"), summaries[id][0], summaries[id][1], int(summaries[id][0]) * int(info["rate"]), info["unit"]])
	production_label.text = "\n".join(lines)
	producer_detail.text = "先建造并完成生产建筑，再选择分配工人"
	if producer_picker.selected >= 0:
		for building: Dictionary in world.buildings:
			if building["id"] == producer_picker.get_item_metadata(producer_picker.selected):
				var info: Dictionary = _production_info(Construction.Catalog.find(building["def_id"]))
				producer_detail.text = "所选建筑：%d人；已累计%.2f%s，日结入库" % [building["workers"], int(building[info["credit"]]) / float(State.DAY_TICKS), info["unit"]]


# 生产操作模块：岗位命令经过世界人口校验，不允许给工地或不存在的建筑分配。
func _change_producers(delta: int) -> void:
	if producer_picker.selected < 0:
		status_label.text = "请先建造并选择生产建筑"
		return
	var id: String = str(producer_picker.get_item_metadata(producer_picker.selected))
	_on_producer_selected(producer_picker.selected)
	for building: Dictionary in world.buildings:
		if building["id"] == id:
			if world.assign_producers(id, int(building["workers"]) + delta):
				status_label.text = "生产工人已调整，实际工作产出将在日结入库；请保存"
			else:
				status_label.text = "分配失败：须完工、未超过岗位上限且有空闲人口"
	_refresh()


# 展开模块：明细显示是界面偏好，不写入战略存档或影响游戏时钟。
func _toggle_food_details() -> void:
	food_details_visible = not food_details_visible
	_refresh_storage()


# 粮仓面板模块：容量来自已完工建筑，最近日结账单与当前库存分别展示。
func _refresh_storage() -> void:
	var capacity: int = world.food_capacity()
	var stock: int = int(world.resources["food"])
	storage_label.text = "储粮 %d / %d" % [stock, capacity]
	if stock > capacity:
		storage_label.text += "；旧存粮超容量，新粮暂不入库"
	elif stock >= capacity - 15:
		storage_label.text += "；储粮接近上限，请建粮仓"
	var material_bill: Dictionary = world.last_material_ledger
	material_bill_label.text = "暂无材料日结；伐木场与采石场完工后分配工人" if material_bill.is_empty() else "第%d日材料：木材入库+%d，石材入库+%d；溢出木%d、石%d" % [material_bill["day"], material_bill["wood"]["stored"], material_bill["stone"]["stored"], material_bill["wood"]["overflow"], material_bill["stone"]["overflow"]]
	if material_bill.has("woods_wood"):
		var woods_wood: int = material_bill["woods_wood"]
		var local_wood: int = int(material_bill["wood"]["produced"]) - woods_wood
		material_bill_label.text += "\n木材产量：伐木场 %d，北部林地 %d" % [local_wood, woods_wood]
	food_detail_button.text = "收起粮食收支" if food_details_visible else "展开粮食收支"
	food_detail_label.visible = food_details_visible
	var ledger: Dictionary = world.last_food_ledger
	if ledger.is_empty():
		food_detail_label.text = "暂无新版日结明细；完成下一日后生成"
		return
	var sources: Dictionary = ledger["by_source"]
	food_detail_label.text = "第%d日基础口粮收支\n期初%d，结算时容量%d\n农场+%d / 牧场+%d / 渔场+%d\n产出%d = 入库%d + 溢出%d\n居民需%d，实耗%d，缺粮%d\n基础口粮后余额%d，净变化%+d" % [ledger["day"], ledger["opening"], ledger["capacity"], sources["b_farm"], sources["b_ranch"], sources["b_fishery"], ledger["produced"], ledger["stored"], ledger["overflow"], ledger["needed"], ledger["consumed"], ledger["shortage"], ledger["closing"], ledger["net"]]
	var military_bill: Dictionary = world.last_army_ledger
	if not military_bill.is_empty() and military_bill["day"] == ledger["day"] and int(military_bill["food_needed"]) > 0:
		food_detail_label.text += "\n再付军粮%d，军需后余粮%d；全日净变%+d" % [military_bill["food_used"], military_bill["food_after"], int(military_bill["food_after"]) - int(ledger["opening"])]


# 生产显示模块：根据静态配置选择产物单位与信用字段，不执行库存计算。
func _production_info(definition: Resource) -> Dictionary:
	var material: String = str(definition.get("material_resource"))
	if material.is_empty():
		return {"unit": "粮", "rate": int(definition.get("food_per_worker_day")), "credit": "food_credit"}
	return {"unit": "木材" if material == "wood" else "石材", "rate": int(definition.get("material_per_worker_day")), "credit": "material_credit"}


# 详情布局模块：沿用管理面板，选中建筑时可直接操作岗位，不另开弹窗。
func _build_inspection_card() -> void:
	inspection_card = PanelContainer.new()
	panel.add_child(inspection_card)
	var contents: VBoxContainer = VBoxContainer.new()
	inspection_card.add_child(contents)
	inspection_label = Label.new()
	inspection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(inspection_label)
	var actions: HBoxContainer = HBoxContainer.new()
	contents.add_child(actions)
	inspection_decrease = _button(actions, "本建筑工人 -1", _change_inspected_workers.bind(-1))
	inspection_increase = _button(actions, "本建筑工人 +1", _change_inspected_workers.bind(1))
	var military_actions: HBoxContainer = HBoxContainer.new()
	contents.add_child(military_actions)
	army_recruit_button = _button(military_actions, "招募%d名步兵" % Army.UNIT.batch_size, _recruit_infantry)
	army_detail_label = Label.new()
	army_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(army_detail_label)
	var lifecycle: VBoxContainer = VBoxContainer.new()
	contents.add_child(lifecycle)
	army_troop_picker = OptionButton.new()
	lifecycle.add_child(army_troop_picker)
	army_troop_picker.item_selected.connect(func(_index: int) -> void: _refresh_army_lifecycle(true))
	army_disband_button = Button.new()
	army_disband_button.focus_mode = Control.FOCUS_NONE
	army_disband_button.pressed.connect(_request_army_disband)
	lifecycle.add_child(army_disband_button)
	army_disband_dialog = ConfirmationDialog.new()
	army_disband_dialog.exclusive = true
	army_disband_dialog.get_ok_button().text = "确认执行"
	army_disband_dialog.get_cancel_button().text = "保留部队"
	army_disband_dialog.confirmed.connect(_confirm_army_disband)
	army_disband_dialog.canceled.connect(_cancel_army_disband)
	add_child(army_disband_dialog)
	inspection_remove = Button.new()
	inspection_remove.text = "移除建筑"
	inspection_remove.focus_mode = Control.FOCUS_NONE
	inspection_remove.pressed.connect(_request_removal)
	contents.add_child(inspection_remove)
	removal_dialog = ConfirmationDialog.new()
	removal_dialog.exclusive = true
	removal_dialog.get_ok_button().text = "确认执行"
	removal_dialog.get_cancel_button().text = "保留建筑"
	removal_dialog.confirmed.connect(_confirm_removal)
	removal_dialog.canceled.connect(_cancel_removal)
	add_child(removal_dialog)
	_refresh_inspection()


# 地图选择模块：仅普通选格触发详情，建筑任一占地格都按权威世界识别。
func _on_town_selected(cell: Vector2i) -> void:
	_refresh_map_info()
	_inspect_building(Inspector.at_cell(world, cell), true)


# 下拉选择模块：生产列表与地图详情使用同一建筑ID，避免两处操作不同对象。
func _on_producer_selected(index: int) -> void:
	if town_map.active_definition != null:
		town_map.cancel_preview()
	_inspect_building(str(producer_picker.get_item_metadata(index)), false)
	_refresh_production()


# 身份绑定模块：只记稳定ID，更新全建筑高亮并同步已有生产列表。
func _inspect_building(id: String, reveal: bool) -> void:
	inspected_building_id = id if not Inspector.find(world, id).is_empty() else ""
	if not inspected_building_id.is_empty() and Inspector.at_cell(world, town_map.selected) != inspected_building_id:
		var record: Dictionary = Inspector.find(world, inspected_building_id)
		town_map.selected = Vector2i(int(record["cell"][0]), int(record["cell"][1]))
	town_map.highlight_building(inspected_building_id)
	_refresh_map_info()
	if producer_picker != null:
		for index: int in range(producer_picker.item_count):
			if producer_picker.get_item_metadata(index) == inspected_building_id:
				producer_picker.select(index)
		_refresh_production()
	_refresh_inspection()
	if reveal and not inspected_building_id.is_empty():
		management_scroll.call_deferred("ensure_control_visible", inspection_card)


# 详情刷新模块：施工、暂停、岗位和读档后始终从当前世界重算显示及按钮状态。
func _refresh_inspection() -> void:
	if inspection_label == null:
		return
	var detail: Dictionary = Inspector.describe(world, inspected_building_id)
	inspection_label.text = detail["text"]
	inspection_increase.disabled = not detail["increase"]
	inspection_decrease.disabled = not detail["decrease"]
	inspection_increase.get_parent().visible = bool(detail.get("producer", false))
	var record: Dictionary = Inspector.find(world, inspected_building_id)
	inspection_remove.visible = not record.is_empty() and record["def_id"] != "b_hall"
	inspection_remove.text = "取消施工" if record.get("state") == "constructing" else "拆除建筑"
	var military: bool = record.get("def_id") == "b_barracks"
	army_recruit_button.get_parent().visible = military
	army_detail_label.visible = military
	if military:
		var offer: Dictionary = Army.quote(world, inspected_building_id)
		army_recruit_button.disabled = not offer["ok"]
		var used: Dictionary = Army.stationed(world.troops, inspected_building_id)
		var lines: PackedStringArray = ["编额%d/%d；每批%d人\n招募：金币%d、木材%d\n训练：%d战略秒" % [used["count"], Army.UNIT.barracks_capacity, Army.UNIT.batch_size, Army.UNIT.recruit_cost.get("gold", 0), Army.UNIT.recruit_cost.get("wood", 0), Army.UNIT.train_work]]
		if not offer["ok"]:
			lines.append(offer["reason"])
		for troop: Dictionary in world.troops:
			if troop["barracks_id"] == inspected_building_id:
				lines.append("%s 步兵%d人：%s" % [str(troop["id"]).trim_prefix("troop_"), troop["count"], "现役" if troop["state"] == "ready" else "训练%d%%" % floori(100.0 * troop["work_done"] / troop["work_required"])])
		army_detail_label.text = "\n".join(lines)
	_refresh_army_lifecycle(military)


# 清理模块：读档或进入建造模式时清除临时选择，不让相同ID误指向新世界建筑。
func _clear_inspection() -> void:
	inspected_building_id = ""
	town_map.selected = Vector2i(-1, -1)
	town_map.highlight_building("")
	_refresh_map_info()
	_refresh_inspection()


# 直接分配模块：岗位修改仍由世界校验，禁用按钮之外也不能绕过岗位或人口上限。
func _change_inspected_workers(delta: int) -> void:
	var building: Dictionary = Inspector.find(world, inspected_building_id)
	if building.is_empty():
		return
	if world.assign_producers(inspected_building_id, int(building["workers"]) + delta):
		status_label.text = "本建筑岗位已调整，请保存战略进度"
	else:
		status_label.text = "分配失败：须完工且符合岗位与空闲人数限制"
	_refresh()


# 移除预览模块：先冻结世界并列清影响，玩家确认之前不扣减建筑或发放退款。
func _request_removal() -> void:
	if not army_disband_offer.is_empty():
		return
	var offer: Dictionary = Removal.quote(world, inspected_building_id)
	if not offer["ok"]:
		status_label.text = offer["reason"]
		return
	removal_was_paused = world.paused
	world.paused = true
	removal_offer = Removal.quote(world, inspected_building_id)
	removal_command = Crypto.new().generate_random_bytes(16).hex_encode()
	removal_dialog.title = "确认" + str(removal_offer["action"])
	var record: Dictionary = Inspector.find(world, inspected_building_id)
	removal_dialog.dialog_text = "%s %s（%s）？\n退木材%d、石材%d；金币不退。\n材料上限损失：木%d、石%d。\n释放%d名生产工人；待入库粮食%.2f、材料%.2f会丢失。\n操作后住房%d、储粮容量%d；已有粮食保留。\n确认期间时间暂停；执行后请手动保存。" % [removal_offer["action"], Construction.Catalog.find(record["def_id"]).get("display_name"), inspected_building_id.trim_prefix("building_"), removal_offer["refund"]["wood"], removal_offer["refund"]["stone"], removal_offer["overflow"]["wood"], removal_offer["overflow"]["stone"], removal_offer["workers"], int(removal_offer["food_credit"]) / 120.0, int(removal_offer["material_credit"]) / 120.0, removal_offer["housing_after"], removal_offer["capacity_after"]]
	removal_dialog.popup_centered(Vector2i(600, 280))
	_refresh()


# 移除确认模块：用稳定ID和预览签名重做校验，成功后同步地图与全部管理视图。
func _confirm_removal() -> void:
	if removal_offer.is_empty():
		return
	var result: Dictionary = Removal.execute(world, removal_offer["building_id"], removal_command, removal_offer["signature"])
	_cancel_removal()
	if result["ok"]:
		_sync_building_view()
		_clear_inspection()
		status_label.text = "已移除建筑：退木材%d、石材%d；请保存战略进度" % [result["refund"]["wood"], result["refund"]["stone"]]
	else:
		status_label.text = result["reason"]
	_refresh()


# 取消确认模块：关闭窗口时还原进入窗口前的时间状态，不改变建筑或库存。
func _cancel_removal() -> void:
	if removal_offer.is_empty():
		return
	removal_dialog.hide()
	world.paused = removal_was_paused
	removal_offer = {}
	removal_command = ""
	_refresh()


# 税率入口模块：政策切换只改变下次日结，点击不发钱，也不立即改变满意度。
func _set_tax_policy(policy: String) -> void:
	if world.set_tax_policy(policy):
		status_label.text = "下次日结采用%s；切换不立即收税或改变满意度，请保存" % Civic.policy_name(policy)
	_refresh()


# 政务显示模块：当前预测和最近一次实际账单分开，说明税率与缺粮分别造成的变化。
func _refresh_civic() -> void:
	var forecast: int = Civic.estimate(world.population, world.satisfaction, world.tax_policy)
	civic_label.text = "满意度%d/100 · 下次日结%s\n按当前满意度预计税收%d" % [world.satisfaction, Civic.policy_name(world.tax_policy), forecast]
	for policy: String in tax_buttons:
		tax_buttons[policy].disabled = policy == world.tax_policy
	var bill: Dictionary = world.last_civic_ledger
	if bill.is_empty():
		civic_bill_label.text = "暂无政务日结；低税恢复、高税损耗满意度，缺粮额外扣分"
		return
	civic_bill_label.text = "第%d日%s：税收入库%d，溢出%d\n满意度%d→%d；税率%+d、供粮恢复+%d、缺粮-%d" % [bill["day"], Civic.policy_name(bill["policy"]), bill["tax_stored"], bill["tax_overflow"], bill["before"], bill["after"], bill["policy_delta"], bill["recovery"], bill["food_penalty"]]
	if bill.has("fort_gold"):
		var fort: Dictionary = bill["fort_gold"]
		civic_bill_label.text += "\n旧堡金币入库 +%d（应得 %d，溢出 %d）" % [fort["stored"], fort["income"], fort["overflow"]]


# 招募入口模块：每次明确操作生成新命令，由军队服务校验费用、兵源和军营编额。
func _recruit_infantry() -> void:
	var command: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var result: Dictionary = Army.recruit(world, inspected_building_id, command)
	status_label.text = "已征募%d人，进入训练；扣金币%d、木材%d，请保存" % [Army.UNIT.batch_size, Army.UNIT.recruit_cost.get("gold", 0), Army.UNIT.recruit_cost.get("wood", 0)] if result["ok"] else str(result["reason"])
	_refresh()


# 军事面板模块：显示现役、训练、当前士气及上次军需结算造成的士气变化。
func _refresh_army() -> void:
	if army_label == null:
		return
	var ready: int = Army.people(world.troops, false, true)
	army_label.text = "军队：现役%d人，训练%d人；占城镇劳动力%d" % [ready, Army.people(world.troops) - ready, Army.people(world.troops, true)]
	if not world.troops.is_empty():
		army_label.text += "\n全军士气 %d/%d" % [world.army_morale, Army.Morale.MAXIMUM]
	if int(world.retired_army_cost["ration_credit"]) > 0 or int(world.retired_army_cost["wage_credit"]) > 0:
		army_label.text += "\n退役待结：军粮%.2f，军饷%.2f" % [int(world.retired_army_cost["ration_credit"]) / 120.0, int(world.retired_army_cost["wage_credit"]) / 120.0]
	var bill: Dictionary = world.last_army_ledger
	army_bill_label.visible = not world.troops.is_empty() or int(world.retired_army_cost["ration_credit"]) > 0 or int(world.retired_army_cost["wage_credit"]) > 0 or (not bill.is_empty() and (int(bill["food_needed"]) > 0 or int(bill["wage_needed"]) > 0))
	army_bill_label.text = "暂无军需日结；训练及现役每人每日额外军粮1、军饷1，按实际时间累计" if bill.is_empty() else "第%d日军需：军粮-%d/%d，军饷-%d/%d\n缺军粮%d、缺军饷%d" % [bill["day"], bill["food_used"], bill["food_needed"], bill["wage_paid"], bill["wage_needed"], bill["food_shortage"], bill["wage_shortage"]]
	if world.last_morale_before != null:
		var delta: int = world.army_morale - int(world.last_morale_before)
		army_bill_label.text += "\n士气 %d → %d（%+d）" % [world.last_morale_before, world.army_morale, delta]


# 军营批次模块：列表只包含当前军营的活动批次，状态变化时重建并保留稳定选择。
func _refresh_army_lifecycle(military: bool) -> void:
	army_troop_picker.get_parent().visible = military
	if not military:
		return
	var signature: String = inspected_building_id
	for troop: Dictionary in world.troops:
		if troop["barracks_id"] == inspected_building_id:
			signature += str(troop["id"]) + str(troop["state"])
	if signature != army_picker_signature:
		var selected: String = str(army_troop_picker.get_item_metadata(army_troop_picker.selected)) if army_troop_picker.selected >= 0 else ""
		army_troop_picker.clear()
		for troop: Dictionary in world.troops:
			if troop["barracks_id"] == inspected_building_id:
				army_troop_picker.add_item("%s · %d人 · %s" % [str(troop["id"]).trim_prefix("troop_"), troop["count"], "训练中" if troop["state"] == "training" else "现役"])
				var index: int = army_troop_picker.item_count - 1
				army_troop_picker.set_item_metadata(index, troop["id"])
				if troop["id"] == selected:
					army_troop_picker.select(index)
		army_picker_signature = signature
	army_troop_picker.get_parent().visible = army_troop_picker.item_count > 0
	if army_troop_picker.selected >= 0:
		var troop: Dictionary = ArmyDisband.find(world, str(army_troop_picker.get_item_metadata(army_troop_picker.selected)))
		army_disband_button.text = "取消这批训练" if troop.get("state") == "training" else "解散这批部队"


# 退役预览模块：固定所选批次并冻结时间，确认前不退款、不释放人口、不改变军需。
func _request_army_disband() -> void:
	if not army_disband_offer.is_empty() or not removal_offer.is_empty() or army_troop_picker.selected < 0:
		return
	var id: String = str(army_troop_picker.get_item_metadata(army_troop_picker.selected))
	var troop: Dictionary = ArmyDisband.find(world, id)
	if troop.is_empty() or troop["barracks_id"] != inspected_building_id:
		return
	var offer: Dictionary = ArmyDisband.quote(world, id)
	if not offer["ok"]:
		status_label.text = offer["reason"]
		return
	army_disband_was_paused = world.paused
	world.paused = true
	army_disband_offer = ArmyDisband.quote(world, id)
	army_disband_command = Crypto.new().generate_random_bytes(16).hex_encode()
	army_disband_dialog.title = "确认" + str(offer["action"])
	army_disband_dialog.dialog_text = "%s %s（%d人）？\n返回空闲劳动力%d人；同步移出军团编制%d人。\n退金币%d、木材%d；上限损失金币%d、木材%d。\n本批次已累计军粮%.2f、军饷%.2f保留到日结。\n执行后不再训练或产生新的军需；批次不能恢复。\n窗口期间时间暂停，执行后请手动保存。" % [offer["action"], id.trim_prefix("troop_"), troop["count"], offer["return_workers"], offer["legion_people"], offer["refund"]["gold"], offer["refund"]["wood"], offer["overflow"]["gold"], offer["overflow"]["wood"], int(offer["ration_credit"]) / 120.0, int(offer["wage_credit"]) / 120.0]
	army_disband_dialog.popup_centered(Vector2i(600, 280))
	_refresh()


# 退役确认模块：以ID和世界签名重新校验，同步人口、军营编额、退款与待结军需。
func _confirm_army_disband() -> void:
	if army_disband_offer.is_empty():
		return
	var result: Dictionary = ArmyDisband.execute(world, army_disband_offer["troop_id"], army_disband_command, army_disband_offer["signature"])
	_cancel_army_disband()
	status_label.text = "已返还兵源；退金币%d、木材%d，已累计军需留待日结，请保存" % [result["refund"]["gold"], result["refund"]["wood"]] if result["ok"] else str(result["reason"])
	_refresh()


# 保留部队模块：关闭确认窗口恢复原时间状态，不改变部队、资源或未结开销。
func _cancel_army_disband() -> void:
	if army_disband_offer.is_empty():
		return
	army_disband_dialog.hide()
	world.paused = army_disband_was_paused
	army_disband_offer = {}
	army_disband_command = ""
	_refresh()


# 编制面板模块：默认折叠，人数设置为绝对编内人数，避免连续点击重复添加。
func _build_legion_panel() -> void:
	legion_toggle = _button(_row(), "军团管理", _toggle_legions)
	legion_body = VBoxContainer.new()
	panel.add_child(legion_body)
	legion_body.visible = false
	var actions: HBoxContainer = HBoxContainer.new()
	legion_body.add_child(actions)
	legion_create = _button(actions, "新建军团", _create_legion)
	legion_close = _button(actions, "撤销军团编制", _request_legion_close)
	legion_picker = OptionButton.new()
	legion_body.add_child(legion_picker)
	legion_picker.item_selected.connect(_on_legion_selected)
	legion_detail = Label.new()
	legion_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legion_body.add_child(legion_detail)
	legion_troop_picker = OptionButton.new()
	legion_body.add_child(legion_troop_picker)
	legion_troop_picker.item_selected.connect(func(_index: int) -> void: _update_legion_amount())
	legion_available = Label.new()
	legion_available.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legion_body.add_child(legion_available)
	legion_people = SpinBox.new()
	legion_people.min_value = 0
	legion_people.step = 1
	legion_body.add_child(legion_people)
	legion_people.value_changed.connect(func(_value: float) -> void: _update_legion_buttons())
	var edits: HBoxContainer = HBoxContainer.new()
	legion_body.add_child(edits)
	legion_apply = _button(edits, "保存本团人数", _apply_legion_count)
	legion_remove = _button(edits, "移出本团", _remove_legion_count)
	legion_dialog = ConfirmationDialog.new()
	legion_dialog.exclusive = true
	legion_dialog.get_ok_button().text = "撤销编制"
	legion_dialog.get_cancel_button().text = "保留军团"
	legion_dialog.confirmed.connect(_confirm_legion_close)
	legion_dialog.canceled.connect(_cancel_legion_close)
	add_child(legion_dialog)


# 展开模块：只控制军团管理的界面可见性，不推进战略时间。
func _toggle_legions() -> void:
	legion_body.visible = not legion_body.visible


# 编制刷新模块：成员变化时保留军团和部队ID选择，服役信用变化不打断正在输入的人数。
func _refresh_legions() -> void:
	if legion_body == null:
		return
	var active: Array = []
	var signature: String = JSON.stringify(world.legions)
	for legion: Dictionary in world.legions:
		if legion["state"] == "active":
			active.append(legion)
	for troop: Dictionary in world.troops:
		signature += str(troop["id"]) + str(troop["count"]) + str(troop["state"])
	legion_toggle.text = "军团管理（%d个）" % active.size()
	legion_create.disabled = active.size() >= int(Legions.SETTINGS.active_limit) or world.legions.size() >= int(Legions.SETTINGS.history_limit)
	if signature != legion_signature:
		var source_id: String = str(legion_troop_picker.get_item_metadata(legion_troop_picker.selected)) if legion_troop_picker.selected >= 0 else ""
		legion_updating = true
		legion_picker.clear()
		for legion: Dictionary in active:
			legion_picker.add_item("%s · %d/%d人" % [legion["name"], Legions.people(legion), Legions.SETTINGS.people_capacity])
			var index: int = legion_picker.item_count - 1
			legion_picker.set_item_metadata(index, legion["id"])
			if legion["id"] == selected_legion_id:
				legion_picker.select(index)
		if active.is_empty():
			legion_picker.add_item("先创建军团")
			legion_picker.set_item_metadata(0, "")
		legion_picker.disabled = active.is_empty()
		selected_legion_id = str(legion_picker.get_item_metadata(legion_picker.selected))
		legion_troop_picker.clear()
		for troop: Dictionary in world.troops:
			if troop["state"] == "ready":
				var own: int = Legions.assigned(world, troop["id"], selected_legion_id) if not selected_legion_id.is_empty() else 0
				var free: int = int(troop["count"]) - Legions.assigned(world, troop["id"])
				legion_troop_picker.add_item("%s · 本团%d · 未编入%d" % [str(troop["id"]).trim_prefix("troop_"), own, free])
				var index: int = legion_troop_picker.item_count - 1
				legion_troop_picker.set_item_metadata(index, troop["id"])
				if troop["id"] == source_id:
					legion_troop_picker.select(index)
		if legion_troop_picker.item_count == 0:
			legion_troop_picker.add_item("没有现役部队，训练完成后可编入")
			legion_troop_picker.set_item_metadata(0, "")
		legion_signature = signature
		legion_updating = false
		_update_legion_amount()
	var selected: Dictionary = Legions.find(world, selected_legion_id)
	legion_close.disabled = selected.is_empty()
	if selected.is_empty():
		legion_detail.text = "军团是免费编制；先新建，再按人数分配现役部队"
	else:
		var count: int = Legions.people(selected)
		legion_detail.text = "%s：步兵%d人，%d个来源批次\n编内每日额外军粮%d、军饷%d（已包含在全军维护）\n撤销编制后士兵仍现役；移出不会返回空闲劳动力" % [selected["name"], count, selected["members"].size(), count * int(Army.UNIT.food_per_day), count * int(Army.UNIT.wage_per_day)]
	_update_legion_buttons()


# 军团选择模块：只切换操作对象，重新载入该团当前人数而不修改成员。
func _on_legion_selected(index: int) -> void:
	selected_legion_id = str(legion_picker.get_item_metadata(index))
	legion_signature = ""
	_refresh_legions()


# 配额输入模块：上限同时受部队未分配余额和军团剩余容量约束，0为移出。
func _update_legion_amount() -> void:
	if legion_updating:
		return
	legion_updating = true
	var legion: Dictionary = Legions.find(world, selected_legion_id)
	var id: String = str(legion_troop_picker.get_item_metadata(legion_troop_picker.selected)) if legion_troop_picker.selected >= 0 else ""
	var source: Dictionary = Legions.troop(world, id)
	var current: int = Legions.assigned(world, id, selected_legion_id) if not legion.is_empty() else 0
	var maximum: int = 0
	if not legion.is_empty() and not source.is_empty():
		maximum = mini(int(source["count"]) - Legions.assigned(world, id) + current, int(Legions.SETTINGS.people_capacity) - Legions.people(legion) + current)
	legion_people.max_value = maximum
	legion_people.value = current
	legion_people.editable = not legion.is_empty() and not source.is_empty()
	legion_available.text = "设置该批次在本军团的人数：当前%d，可设0至%d（0为移出）" % [current, maximum]
	legion_updating = false
	_update_legion_buttons()


# 按钮模块：只读禁用提示，实际人数约束仍由服务层执行。
func _update_legion_buttons() -> void:
	if legion_updating or legion_people == null:
		return
	var id: String = str(legion_troop_picker.get_item_metadata(legion_troop_picker.selected)) if legion_troop_picker.selected >= 0 else ""
	var usable: bool = not selected_legion_id.is_empty() and not id.is_empty()
	var current: int = Legions.assigned(world, id, selected_legion_id) if usable else 0
	legion_apply.disabled = not usable or int(legion_people.value) == current
	legion_remove.disabled = not usable or current == 0


# 创建入口模块：创建后选择新军团，ID只增不减，操作不消耗资源。
func _create_legion() -> void:
	var result: Dictionary = Legions.create(world, Crypto.new().generate_random_bytes(16).hex_encode())
	if result["ok"]:
		selected_legion_id = result["legion_id"]
		legion_body.visible = true
		status_label.text = "军团编制已创建，可按人数分配现役部队；请保存"
	else:
		status_label.text = result["reason"]
	_refresh()


# 设置入口模块：提交本团绝对人数，重复保存同一值不重复编入。
func _apply_legion_count() -> void:
	if legion_troop_picker.selected < 0:
		return
	var id: String = str(legion_troop_picker.get_item_metadata(legion_troop_picker.selected))
	var result: Dictionary = Legions.set_count(world, selected_legion_id, id, int(legion_people.value))
	status_label.text = "本团人数已保存；人口和军需仍按原部队计算，请保存战略进度" if result["ok"] else str(result["reason"])
	_refresh()


# 移出入口模块：只释放该军团的配额，士兵仍服役并继续产生维护。
func _remove_legion_count() -> void:
	if legion_troop_picker.selected < 0:
		return
	var id: String = str(legion_troop_picker.get_item_metadata(legion_troop_picker.selected))
	var result: Dictionary = Legions.set_count(world, selected_legion_id, id, 0)
	status_label.text = "已移出本团，部队仍现役且维护照常；请保存" if result["ok"] else str(result["reason"])
	_refresh()


# 撤销预览模块：明确撤销编制和解散部队的区别，冻结世界并捕获目标签名。
func _request_legion_close() -> void:
	if not legion_close_offer.is_empty() or not army_disband_offer.is_empty() or not removal_offer.is_empty():
		return
	var legion: Dictionary = Legions.find(world, selected_legion_id)
	if legion.is_empty():
		return
	legion_was_paused = world.paused
	world.paused = true
	legion_close_offer = {"id": selected_legion_id, "signature": world.snapshot()}
	legion_dialog.title = "撤销军团编制"
	legion_dialog.dialog_text = "撤销%s的编制？\n编内%d人将变为未编入军团，仍保持现役。\n城镇空闲人口不增加，招募费不退，军需维护照常。\n部队和军营归属保留；执行后请手动保存。" % [legion["name"], Legions.people(legion)]
	legion_dialog.popup_centered(Vector2i(600, 240))
	_refresh()


# 撤销确认模块：重新校验目标与快照，关闭编制后保留原部队和维护状态。
func _confirm_legion_close() -> void:
	if legion_close_offer.is_empty():
		return
	var result: Dictionary = Legions.dissolve(world, legion_close_offer["id"], legion_close_offer["signature"])
	_cancel_legion_close()
	status_label.text = "军团编制已撤销，原部队仍现役；请保存" if result["ok"] else str(result["reason"])
	_refresh()


# 保留编制模块：关闭弹窗还原原暂停状态，不改变军团或兵员分配。
func _cancel_legion_close() -> void:
	if legion_close_offer.is_empty():
		return
	legion_dialog.hide()
	world.paused = legion_was_paused
	legion_close_offer = {}
	_refresh()
