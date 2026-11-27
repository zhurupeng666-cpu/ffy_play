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
const HudIcons = preload("res://scripts/hud_icons.gd")
const HudTheme = preload("res://scripts/hud_theme.gd")
const TownMap = preload("res://scripts/town_map.gd")
const State = preload("res://scripts/world_state.gd")
const Population = preload("res://scripts/population_service.gd")
const HouseEconomy = preload("res://scripts/household_economy.gd")
const Capital = preload("res://scripts/capital_layout.gd")
const Courts = preload("res://scripts/palace_courtyards.gd")
const Works = preload("res://scripts/royal_works.gd")
const Register = preload("res://scripts/resident_register.gd")
const Estate = preload("res://scripts/estate_labor.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const ExportProbe = preload("res://scripts/export_probe.gd")

# 控制模块：界面只持有世界引用，资源计算和SQL分别由独立模块承担。
var world: RefCounted = State.new()
var legacy_economy_fixture: bool = false
var auto_lifecycle_for_test: bool = false
var automatic_lifecycle: bool = false
var works_totals: Label
var resource_summary: Control
var compact_resources: Dictionary = {}
var notice_strip: HBoxContainer
var court_button: Button
var memorial_window: Window
var memorial_filter: OptionButton
var memorial_list: ItemList
var memorial_detail: RichTextLabel
var memorial_actions: HBoxContainer
var memorial_signature: int = -1
var field_card: Label
var invest_button: Button
var asset_card: VBoxContainer
var asset_label: Label
var equity_points: SpinBox
var buyout_button: Button
var equity_dialog: ConfirmationDialog
var equity_order: Dictionary = {}
var resident_window: Window
var resident_list: ItemList
var resident_filter: LineEdit
var resident_details: RichTextLabel
var resident_scope: String = ""
var resident_home: Button
var resident_card: Label
var household_detail: Label
var household_report: Label
var civil_button: Button
var marshal_button: Button
var appointment_legion: OptionButton
var selected_household: int = 0
var city_navigation: MenuButton
var palace_menu: MenuButton
var clock: RefCounted = Clock.new(world)
var store: RefCounted = Store.new()
var store_path_override: String = ""
var numbers: Dictionary = {}
var ledger_sections: Array[Control] = []
var town_sections: Array[Control] = []
var producer_numbers: VBoxContainer
var ledger_data: Array[Control] = []
var ledger_message: Array[Label] = []
var stock_warning: Label
var retired_cost: VBoxContainer
var production_rows: Dictionary = {}
var tax_buttons: Dictionary = {}
var status_label: Label
# 读档界面：列表项使用数据库ID，显示本地保存时间和游戏日期。
var save_picker: ConfirmationDialog
var save_items: ItemList
var save_delete_button: Button
var save_delete_dialog: ConfirmationDialog
var pending_save_delete: int = 0
var pause_button: Button
var speed_buttons: Dictionary = {}
var progress: ProgressBar
var panel: VBoxContainer
var town_map: Control
# 地图导航模块：城镇和区域总览使用同一个世界与时钟。
var town_view: VBoxContainer
var region_overview: RegionOverview
var region_toggle: Button
var map_info: Label
var placement_label: Label
var construction_label: Label
var construction_metrics: VBoxContainer
var producer_picker: OptionButton
var producer_detail: Label
var producer_signature: String = ""
var displayed_building_tick: int = -1
var pending_build_command: String = ""
var inspected_building_id: String = ""
var management_scroll: ScrollContainer
var management_drawer: PanelContainer
var management_tabs: TabContainer
var build_toolbar: HBoxContainer
var cancel_build_button: Button
var save_stamp: Label
var inspection_card: PanelContainer
var inspection_label: Label
var inspection_increase: Button
var inspection_decrease: Button
var inspection_remove: Button
var site_builder_actions: VBoxContainer
var site_builder_hint: Label
var builder_add_buttons: Array[Button] = []
var builder_remove_buttons: Array[Button] = []
var release_producer_button: Button
var town_picker: OptionButton
var population_hint: Label
var population_event: Label
var household_list: ItemList
var household_signature: String = ""
var estate_buy_button: Button
var estate_food_hint: Label
var estate_site_row: HBoxContainer
var estate_builder_add: Array[Button] = []
var estate_builder_remove: Array[Button] = []
var estate_producer_add: Button
var estate_producer_remove: Button
var barracks_stats: VBoxContainer
var barracks_notice: Label
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
var legion_stats: VBoxContainer
var legion_allocation: VBoxContainer
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
	var probes: Array[String] = [world_probe, build_probe, food_probe, storage_probe, material_probe, inspection_probe,
		removal_probe, civic_probe, army_probe, disband_probe, legion_probe]
	legacy_economy_fixture = legacy_economy_fixture or probes.any(func(probe: String) -> bool: return not probe.is_empty())
	if not legacy_economy_fixture:
		world.capital_layout = true
		HouseEconomy.activate(world, randi_range(1, 999999))
		for index: int in range(world.households.size()):
			State.Rural.petition(world,index,world.current_day(),world.households[index]["adults"])
	_build_ui()
	if not store.open_store(store_path_override):
		status_label.text = "存档不可用：" + store.error_message
		if not world_probe.is_empty() or not build_probe.is_empty() or not food_probe.is_empty() or not storage_probe.is_empty() or not material_probe.is_empty() or not inspection_probe.is_empty() or not removal_probe.is_empty() or not civic_probe.is_empty() or not army_probe.is_empty() or not disband_probe.is_empty() or not legion_probe.is_empty():
			get_tree().quit(1)
			return
	else:
		_refresh_save_stamp()
		automatic_lifecycle = not legacy_economy_fixture and (auto_lifecycle_for_test or (store_path_override.is_empty() and DisplayServer.get_name() != "headless"))
		if automatic_lifecycle:
			get_tree().auto_accept_quit = false
			if not store.list_saves().is_empty():
				_load()
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


# 界面模块：顶部放全局状态，中间留地图，底部放建造与管理入口。
func _build_ui() -> void:
	theme = HudTheme.make()
	var backdrop := PanelContainer.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override("panel", HudTheme.surface("#181e19", "#181e19", 10))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	backdrop.add_child(layout)
	_build_header(layout)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)
	layout.add_child(columns)
	_build_map(columns)
	_build_management_drawer(columns)
	_build_command_bar(layout)
	_build_save_picker()
	if not legacy_economy_fixture:
		_build_resident_window()
		_build_memorial_window()
	_sync_building_view()
	_refresh_map_info()


# 抬头信息：资源单行排列，地图、暂停和存读档入口始终可见。
func _build_header(layout: VBoxContainer) -> void:
	var header := PanelContainer.new()
	layout.add_child(header)
	var strips := VBoxContainer.new()
	header.add_child(strips)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 14)
	strips.add_child(summary)
	resource_summary=summary
	resource_summary.hide()
	_number_grid(summary, "", [
		["population", "人口", "people"], ["hud_workforce", "劳动力", "work"], ["hud_idle", "可用劳动力", "idle"],
		["food", "粮食", "food"], ["gold", "金币", "gold"],
		["wood", "木材", "wood"], ["stone", "石材", "stone"], ["date", "城镇时间", "clock"],
	], 8)

	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 6)
	strips.add_child(navigation)
	region_toggle = _button(navigation, "区域地图", _toggle_region_view)
	for entry: Array in [["population","人口","people"],["hud_workforce","劳动力","work"],["hud_idle","可用劳力","idle"],["food","粮食","food"],["gold","金币","gold"],["wood","木材","wood"],["stone","石材","stone"],["date","城镇时间","clock"]]:
		_compact_metric(navigation,entry)
	_button(navigation,"数值 ▾",_toggle_resource_summary).tooltip_text="展开或收起全部资源标签"
	var divider := Control.new()
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(divider)
	pause_button = _button(navigation, "继续", _toggle_pause)
	pause_button.tooltip_text="空格切换暂停"
	for multiplier: int in [1, 2, 4]:
		var speed_button := _button(navigation, "%d×" % multiplier, _set_speed.bind(multiplier))
		speed_button.tooltip_text = "%d 倍速" % multiplier
		speed_button.toggle_mode = true
		speed_buttons[multiplier] = speed_button
	_button(navigation, "保存", _save)
	_button(navigation, "读档", _choose_save)
	progress = ProgressBar.new()
	progress.max_value = State.DAY_TICKS
	progress.show_percentage = false
	progress.custom_minimum_size.y = 3
	strips.add_child(progress)


# 紧凑数值：图标和数字单行常驻，标签由提示和展开状态提供。
func _compact_metric(parent: HBoxContainer, entry: Array) -> void:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation",3)
	cell.mouse_filter=Control.MOUSE_FILTER_PASS
	cell.tooltip_text=entry[1]
	parent.add_child(cell)
	var icon := TextureRect.new()
	icon.texture=HudIcons.texture(entry[2])
	icon.custom_minimum_size=Vector2(17,17)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	var value := Label.new()
	value.add_theme_font_size_override("font_size",14)
	value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cell.add_child(value)
	compact_resources[entry[0]]=value


# 展开入口：仅调整界面空间，数值本身始终由同一世界状态驱动。
func _toggle_resource_summary() -> void:
	resource_summary.visible=not resource_summary.visible
	for metric: Label in compact_resources.values():
		metric.get_parent().visible=not resource_summary.visible


# 消息入口：玩家可以恢复操作反馈与存档时间，建造提示仍独立显示。
func _toggle_notices() -> void:
	notice_strip.visible=not notice_strip.visible


# 地图模块：地图填满剩余空间，视角工具放在地图自身下边缘。
func _build_map(columns: HBoxContainer) -> void:
	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.custom_minimum_size.x = 320
	columns.add_child(map_column)
	town_view = VBoxContainer.new()
	town_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_child(town_view)
	region_overview = RegionOverview.new()
	region_overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	region_overview.hide()
	region_overview.town_requested.connect(_enter_home_region)
	region_overview.site_requested.connect(_view_region_site)
	map_column.add_child(region_overview)
	town_map = TownMap.new()
	town_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	town_map.custom_minimum_size = Vector2(320, 175)
	town_view.add_child(town_map)
	var map_actions := HBoxContainer.new()
	map_actions.add_theme_constant_override("separation", 6)
	town_view.add_child(map_actions)
	_button(map_actions, "回城镇", town_map.reset_view).tooltip_text = "Home 回城镇 · 方向键移动"
	_button(map_actions, "已知全图", town_map.show_entire_map)
	_button(map_actions, "林场", town_map.visit_work_area.bind(Vector2i(50, 46), "forest"))
	_button(map_actions, "石矿", town_map.visit_work_area.bind(Vector2i(106, 39), "stone"))
	_button(map_actions, "河港", town_map.visit_site.bind(Vector2i(22, 90)))
	_build_city_navigation(map_actions)
	_build_palace_menu(map_actions)
	map_info = Label.new()
	map_info.custom_minimum_size.x = 39
	map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_info.mouse_filter = Control.MOUSE_FILTER_PASS
	map_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var map_icon := TextureRect.new()
	map_icon.texture = HudIcons.texture("map")
	map_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	map_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_icon.size_flags_horizontal = Control.SIZE_SHRINK_END
	var map_space := Control.new()
	map_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_actions.add_child(map_space)
	map_actions.add_child(map_icon)
	map_actions.add_child(map_info)
	town_map.hovered_changed.connect(_on_map_cell_changed)
	town_map.building_selected.connect(_on_town_selected)
	town_map.court_clicked.connect(_court_action)
	town_map.view_changed.connect(_refresh_map_info)
	town_map.placement_changed.connect(_on_placement_changed)
	town_map.placement_clicked.connect(_on_placement_clicked)
	town_map.placement_cancelled.connect(_on_placement_cancelled)


# 导览模块：外城、皇城、普通集市、府邸与四座城门均可一键定位。
func _build_city_navigation(row: HBoxContainer) -> void:
	city_navigation = MenuButton.new()
	city_navigation.text = "城镇导览 ▾"
	city_navigation.flat = false
	city_navigation.focus_mode = Control.FOCUS_NONE
	row.add_child(city_navigation)
	var popup: PopupMenu = city_navigation.get_popup()
	for title: String in ["外城 · 300×300", "皇城全景", "太和殿", "御花园", "居民集市", "府邸", "北城门", "南城门", "西城门", "东城门", "城外民田", "城外牧场", "城外军营"]:
		popup.add_item(title)
	popup.id_pressed.connect(_visit_city)


# 导览入口：每处设施保留整栋点选与用途说明。
func _visit_city(index: int) -> void:
	_end_court_edit()
	management_drawer.hide()
	if index < 2:
		town_map.visit_capital_area(Capital.OUTER if index == 0 else Capital.INNER)
		return
	if index in [4, 5, 10, 11, 12]:
		var kind: String = {4:"b_market",5:"b_manor",10:"b_farm",11:"b_ranch",12:"b_barracks"}[index]
		var candidates: Array = []
		for building: Dictionary in world.buildings:
			if building["def_id"] == kind:
				candidates.append(building)
		if candidates.is_empty():
			status_label.text = "暂无%s" % {4:"居民集市",5:"府邸",10:"城外民田",11:"城外牧场",12:"城外军营"}[index]
			return
		var record: Dictionary = candidates[0]
		if index == 5:
			for manor: Dictionary in candidates:
				if manor.get("large", false):
					record = manor
					break
		var point := Vector2i(record["cell"][0], record["cell"][1])
		var area := Rect2i(point, Construction.Catalog.footprint(record))
		if kind=="b_farm":
			for district: Rect2i in town_map.cultivated_districts:
				if district.has_point(point):
					area=district
					break
		town_map.visit_capital_area(area.grow(4))
		_inspect_building(record["id"], false)
		return
	var key: String = "ceremony" if index == 2 else "garden"
	if index >= 6:
		key = Capital.GATES[index - 6][0]
	var landmark: Dictionary = Capital.buildings()["capital/" + key]
	var cell := Vector2i(landmark["cell"][0], landmark["cell"][1])
	town_map.visit_capital_area(Rect2i(cell, landmark["size"]).grow(4))
	_inspect_building(landmark["id"], false)


# 皇宫菜单：可切换殿内视图，并在三块独立院落摆设及换铺地砖。
func _build_palace_menu(row: HBoxContainer) -> void:
	palace_menu = MenuButton.new()
	palace_menu.text = "皇宫布置 ▾"
	palace_menu.flat = false
	palace_menu.focus_mode = Control.FOCUS_NONE
	row.add_child(palace_menu)
	var menu: PopupMenu = palace_menu.get_popup()
	menu.add_item("查看殿内／恢复屋顶",0)
	for i: int in range(Courts.NAMES.size()):
		menu.add_item("布置" + Courts.NAMES[i],i+1)
	menu.add_separator()
	menu.add_item("切换地砖",5)
	for i: int in range(Courts.ITEMS.size()):
		menu.add_item("放置" + Courts.ITEMS[i],10+i)
	menu.add_item("结束布置",99)
	menu.id_pressed.connect(_palace_command)


# 操作入口：道具工具每次仅作用于当前院落，退出后恢复正常建筑点选。
func _palace_command(id: int) -> void:
	if not world.capital_layout:
		return
	_show_region_view(false)
	if id == 0:
		_end_court_edit()
		town_map.palace_cutaway = not town_map.palace_cutaway
		_visit_city(2)
		if town_map.palace_cutaway:
			town_map._apply_zoom(town_map.size * 0.5,1.52)
		town_map.redraw_palace()
		status_label.text = "正在查看殿内陈设" if town_map.palace_cutaway else "已恢复宫殿屋顶"
		return
	if id == 99:
		_end_court_edit()
		status_label.text = "已结束布置，可保存进度"
		return
	if id >= 1 and id <= Courts.AREAS.size():
		if town_map.active_definition != null:
			town_map.cancel_preview()
		management_drawer.hide()
		_clear_inspection()
		town_map.court_edit = id-1
		town_map.visit_capital_area(Courts.AREAS[id-1].grow(5))
	if town_map.court_edit < 0:
		status_label.text = "先从菜单选择要布置的院落"
		return
	if id == 5:
		var court: int = town_map.court_edit
		world.palace_decor["styles"][court] = (world.palace_decor["styles"][court]+1) % Courts.STYLES.size()
		town_map.sync_palace(world.palace_decor)
	if id >= 10 and id < 10+Courts.ITEMS.size():
		town_map.court_tool = id-10
	status_label.text = "%s · 左键放%s · 右键移除 · 菜单结束" % [Courts.NAMES[town_map.court_edit],Courts.ITEMS[town_map.court_tool]]
	town_map.queue_redraw()


# 院落点击：只提交通过范围和碰撞校验的改动。
func _court_action(cell: Vector2i, remove: bool) -> void:
	var court: int = town_map.court_edit
	var layout: Dictionary = world.palace_decor
	if court < 0 or not Courts.AREAS[court].has_point(cell):
		return
	if remove:
		var item: int = Courts.item_at(layout,cell)
		if item < 0:
			return
		layout["items"].remove_at(item)
	elif Courts.can_place(layout,court,town_map.court_tool,cell):
		layout["items"].append([town_map.court_tool,cell.x,cell.y])
	else:
		status_label.text = "陈设需要院内连续空地"
		return
	town_map.sync_palace(layout)
	status_label.text = "院落已更新 · 保存进度后可继续使用"


# 编辑退出：保留布置内容，释放地图点击。
func _end_court_edit() -> void:
	if town_map.court_edit >= 0:
		town_map.court_edit = -1
		town_map.queue_redraw()


# 管理抽屉：按当前对象、城镇、军团与账本分组，默认给地图留足空间。
func _build_management_drawer(columns: HBoxContainer) -> void:
	management_drawer = PanelContainer.new()
	management_drawer.custom_minimum_size.x = 326
	columns.add_child(management_drawer)
	var body := VBoxContainer.new()
	management_drawer.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := Label.new()
	title.text = "领地管理"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("#ead7a0"))
	heading.add_child(title)
	_button(heading, "收起", management_drawer.hide)
	management_tabs = TabContainer.new()
	management_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(management_tabs)
	management_tabs.tab_changed.connect(_resize_management)
	management_scroll = _drawer_page("建筑")
	_build_inspection_card()

	_drawer_page("城镇")
	var town_page: VBoxContainer = panel
	town_picker = OptionButton.new()
	town_page.add_child(town_picker)
	town_picker.add_icon_item(HudIcons.texture("people"), "库存与民生")
	town_picker.add_icon_item(HudIcons.texture("work"), "劳动力与施工")
	town_picker.add_icon_item(HudIcons.texture("food"), "生产岗位")
	town_picker.add_icon_item(HudIcons.texture("people"), "人口与户籍")
	town_picker.add_icon_item(HudIcons.texture("work"), "领主劳役")
	panel = _data_section(town_page, town_sections)
	_number_grid(panel, "", [
		["food_store", "储粮 / 容量", "food"], ["housing", "人口 / 住房", "house"],
		["satisfaction", "满意度", "happy"], ["forecast", "预计税收", "gold"],
	], 2)
	stock_warning = _label("")
	var taxes: HBoxContainer = _row()
	for policy: String in Civic.POLICIES:
		tax_buttons[policy] = _button(taxes, Civic.policy_name(policy), _set_tax_policy.bind(policy))
	panel = _data_section(town_page, town_sections)
	_number_grid(panel, "劳动力", [
		["idle", "空闲", "people"], ["employable", "可就业", "people"],
		["builders", "施工", "work"], ["producers", "生产", "work"],
		["dependent", "被抚养", "house"], ["military_workers", "军职", "shield"],
	], 2)
	_number_grid(panel, "建筑", [
		["ready_buildings", "已完工", "house"], ["queued_buildings", "待完工", "work"],
	], 2)
	construction_label = _label("")
	construction_label.add_theme_color_override("font_color", Color("#ddbb91"))
	construction_metrics = _number_grid(panel, "", [
		["active_build_progress", "施工进度", "work"], ["waiting_builds", "等待施工", "clock"],
	], 2)
	var labor_actions: HBoxContainer = _row()
	_build_builder_buttons(labor_actions)
	panel = _data_section(town_page, town_sections)
	producer_picker = OptionButton.new()
	panel.add_child(producer_picker)
	producer_picker.item_selected.connect(_on_producer_selected)
	producer_numbers = _number_grid(panel, "当前建筑", [
		["producer_workers", "在岗", "people"], ["producer_credit", "待入库", "book"],
	], 2)
	producer_detail = _label("请选择生产建筑")
	var production_actions: HBoxContainer = _row()
	_button(production_actions, "生产 −1", _change_producers.bind(-1))
	_button(production_actions, "生产 +1", _change_producers.bind(1))
	var production_icons := {"b_farm": "food", "b_ranch": "ranch", "b_fishery": "fish", "b_lumber": "wood", "b_quarry": "stone"}
	for id: String in Construction.Catalog.PRODUCERS:
		var name_text: String = Construction.Catalog.find(id).get("display_name")
		production_rows[id] = _number_grid(panel, name_text, [
			[id + "_jobs", "在岗 / 岗位", "people"], [id + "_rate", "全天折算", production_icons[id]],
		], 2)

	_build_population_sections(town_page)
	if not legacy_economy_fixture:
		town_picker.add_icon_item(HudIcons.texture("work"),"皇家工程与交易")
		panel = _data_section(town_page,town_sections)
		works_totals = _label("")
		_button(_row(),"撤回最早的待投标工程",_cancel_tender)
	town_picker.item_selected.connect(_show_data_section.bind(town_sections))
	_show_data_section(0, town_sections)

	_drawer_page("军团")
	_number_grid(panel, "兵力", [
		["soldiers", "现役", "shield"], ["training", "训练中", "work"], ["army_morale", "全军士气", "happy"],
	], 2)
	retired_cost = _number_grid(panel, "退役待结", [
		["retired_food", "军粮", "food"], ["retired_pay", "军饷", "gold"],
	], 2)
	_build_legion_panel()

	_drawer_page("账本")
	_build_ledger()
	management_drawer.hide()


# 工程展示：在城镇账页列出投标、承建户和皇家木石账。
func _refresh_works() -> void:
	if works_totals == null:
		return
	var data: Dictionary = world.royal_works
	if town_map.tender_orders != data["roads"]:
		town_map.tender_orders = data["roads"].duplicate(true)
		town_map.tender_reserve = Works.reserved(town_map.tender_orders)
		town_map.queue_redraw()
	var lines: PackedStringArray = ["木材 %d金／份 · 石材 %d金／份" % [Works.WOOD_PRICE,Works.STONE_PRICE],
		"累计售木 %d · 售石 %d · 收入 %d金" % [data["wood"],data["stone"],data["sales"]],
		"工程款 %d金 · 商铺分红 %d金" % [data["paid"],data["dividends"]]]
	for order: Dictionary in data["roads"]:
		var text: String = "等投标" if order["owner"] < 0 else "%s承建，报价%d金，第%d日交工" % [world.household_name(order["owner"]),order["bid"],order["due"]]
		lines.append("(%d,%d) · %s" % [order["cell"][0],order["cell"][1],text])
	works_totals.text = "\n".join(lines)


# 撤标入口：只撤销尚未选出承建户的一项工程。
func _cancel_tender() -> void:
	var roads: Array = world.royal_works["roads"]
	for i: int in range(roads.size()):
		if roads[i]["owner"] < 0 and world.resources["gold"] <= 1000000000-Works.ROAD_BUDGET:
			world.resources["gold"] += Works.ROAD_BUDGET
			var order: Dictionary = roads.pop_at(i)
			world.post_report("工程","道路招标撤回","路段 (%d,%d) 撤标，预算退回。" % [order["cell"][0],order["cell"][1]])
			status_label.text = "已撤标，预算退回"
			_refresh_works()
			town_map._update_preview()
			return
	status_label.text = "暂无可撤回工程"


# 城镇数据模块：家庭账和领主劳役分别展示，方便确认两类劳动力来源。
func _build_population_sections(town_page: VBoxContainer) -> void:
	panel = _data_section(town_page, town_sections)
	_number_grid(panel, "", [
		["households", "家庭", "house"], ["children", "儿童", "people"],
		["next_adult_day", "下次成年", "clock"], ["next_adult_count", "本批人数", "people"],
	], 2)
	population_hint = _label("")
	population_event = _label("")
	household_list = ItemList.new()
	household_list.custom_minimum_size.y = 125
	panel.add_child(household_list)
	if not legacy_economy_fixture:
		household_list.item_selected.connect(_select_household)
		household_detail = _label("")
		household_report = _label("")
		var posts: HBoxContainer = _row()
		civil_button = _button(posts, "任命税务官", _appoint_household.bind(false))
		marshal_button = _button(posts, "任命武将", _appoint_household.bind(true))
		appointment_legion = OptionButton.new()
		appointment_legion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		appointment_legion.item_selected.connect(_update_appointment.bind())
		panel.add_child(appointment_legion)
		# 户籍页先显示可点选的账册，人口趋势放在任命工具之后。
		household_list.custom_minimum_size.y = 84
		for control: Control in [household_report, appointment_legion, posts, household_detail, household_list]:
			panel.move_child(control, 0)

	panel = _data_section(town_page, town_sections)
	estate_buy_button = _button(_row(), "购买1人 · %d金币" % Estate.PRICE, _purchase_estate)
	_build_estate_builder_buttons(_row())
	_number_grid(panel, "", [
		["estate_workers", "劳役人数", "people"], ["estate_idle", "可用劳役", "work"],
		["estate_construction", "施工劳役", "work"], ["estate_production", "生产劳役", "work"],
		["estate_daily_food", "每日口粮", "food"], ["estate_food_paid", "上日扣粮", "food"],
	], 2)
	estate_food_hint = _label("")


# 分页模块：每个分类独立滚动，原有按钮继续操作同一份数据。
func _drawer_page(name_text: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_text
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	management_tabs.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	return scroll


# 面板宽度：账本用三列显示，建筑和岗位保留紧凑宽度。
func _resize_management(index: int) -> void:
	management_drawer.custom_minimum_size.x = 462 if index == 3 else 326


# 抽屉入口：同一类别再次点击即收起，建筑选中可以直接定位详情。
func _open_management(index: int, toggle: bool = false) -> void:
	if toggle and management_drawer.visible and management_tabs.current_tab == index:
		management_drawer.hide()
		return
	management_tabs.current_tab = index
	_resize_management(index)
	management_drawer.show()


# 底栏模块：建造按用途归类，管理入口与游戏反馈放在固定位置。
func _build_command_bar(layout: VBoxContainer) -> void:
	var footer := PanelContainer.new()
	layout.add_child(footer)
	var rows := VBoxContainer.new()
	footer.add_child(rows)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 7)
	rows.add_child(toolbar)
	build_toolbar = HBoxContainer.new()
	build_toolbar.add_theme_constant_override("separation", 6)
	toolbar.add_child(build_toolbar)
	if legacy_economy_fixture:
		_build_category("民居仓储", "house", ["b_house","b_granary"])
	else:
		_build_category("仓储", "house", ["b_granary"])
	if legacy_economy_fixture:
		_build_category("农业渔牧", "food", ["b_farm", "b_ranch", "b_fishery"])
	else:
		_build_category("领主畜牧", "ranch", ["b_ranch"])
	_build_category("采集工坊", "wood", ["b_lumber", "b_quarry", "b_smithy"])
	_build_category("道路城防", "shield", ["b_barracks", "b_road", "b_wall", "b_gate"])
	cancel_build_button = _button(build_toolbar, "取消建造", _cancel_preview)
	cancel_build_button.hide()
	var divider := Control.new()
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(divider)
	_button(toolbar, "建筑", _open_management.bind(0, true)).icon = HudIcons.texture("house")
	_button(toolbar, "城镇", _open_management.bind(1, true)).icon = HudIcons.texture("people")
	_button(toolbar, "军团", _open_management.bind(2, true)).icon = HudIcons.texture("shield")
	_button(toolbar, "账本", _open_management.bind(3, true)).icon = HudIcons.texture("book")
	if not legacy_economy_fixture:
		_button(toolbar,"居民册",_open_resident_register).icon = HudIcons.texture("people")
		court_button = _button(toolbar,"奏章",_open_memorial_window)
		court_button.icon=HudIcons.texture("book")
	_button(toolbar,"消息 ▾",_toggle_notices)

	placement_label = Label.new()
	placement_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	placement_label.hide()
	rows.add_child(placement_label)
	var notices := HBoxContainer.new()
	notice_strip=notices
	rows.add_child(notices)
	notice_strip.visible=legacy_economy_fixture
	status_label = Label.new()
	status_label.text = "选择建筑查看详情"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notices.add_child(status_label)
	save_stamp = Label.new()
	save_stamp.add_theme_color_override("font_color", Color("#c8b88b"))
	notices.add_child(save_stamp)


# 田地图层：地契名和作物同步到地图，数值日结留在建筑详情。
func _sync_farm_view() -> void:
	var crops: Dictionary = {}
	var names: Dictionary = {}
	for id: String in world.chancery["fields"]:
		crops[id]=world.chancery["fields"][id]["crop"]
		names[id]=world.household_name(world.household_economy["property"].get(id,-1))+"的田"
	town_map.sync_farms(world.buildings,crops,names)


# 奏章窗口：待办和历史分组，左侧定位、右侧审阅，审批按钮只出现在待办。
func _build_memorial_window() -> void:
	memorial_window=Window.new()
	memorial_window.title="奏章"
	memorial_window.theme=theme
	memorial_window.min_size=Vector2i(570,360)
	memorial_window.hide()
	memorial_window.close_requested.connect(memorial_window.hide)
	add_child(memorial_window)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	memorial_window.add_child(frame)
	var layout := VBoxContainer.new()
	frame.add_child(layout)
	memorial_filter=OptionButton.new()
	layout.add_child(memorial_filter)
	for section: String in ["待批","全部奏报"]+State.Book.SECTIONS:
		memorial_filter.add_item(section)
	memorial_filter.item_selected.connect(func(_index: int)->void: _populate_memorial())
	var split := HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(split)
	memorial_list=ItemList.new()
	memorial_list.custom_minimum_size.x=250
	memorial_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(memorial_list)
	memorial_list.item_selected.connect(_read_memorial)
	var reading := VBoxContainer.new()
	reading.custom_minimum_size.x=290
	reading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(reading)
	memorial_detail=RichTextLabel.new()
	memorial_detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	memorial_detail.bbcode_enabled=true
	memorial_detail.add_theme_color_override("default_color",Color("#e8dfc9"))
	memorial_detail.add_theme_font_size_override("normal_font_size",15)
	memorial_detail.add_theme_font_size_override("bold_font_size",16)
	reading.add_child(memorial_detail)
	memorial_actions=HBoxContainer.new()
	reading.add_child(memorial_actions)
	_button(memorial_actions,"准予开垦",_rule_memorial.bind(true))
	_button(memorial_actions,"驳回",_rule_memorial.bind(false))


# 打开奏章：优先定位有待批的队列，否则打开最近奏报。
func _open_memorial_window() -> void:
	memorial_filter.select(0 if not world.chancery["claims"].is_empty() else 1)
	_populate_memorial()
	memorial_window.popup_centered(Vector2i(780,470))


# 未决计数与动态刷新：世界变化后才重建，选中的待批奏章保持原对象。
func _refresh_memorial() -> void:
	if court_button==null:
		return
	var count: int = world.chancery["claims"].size()
	court_button.text="奏章 · %d待批" % count if count>0 else "奏章"
	if not memorial_window.visible:
		return
	var signature: int = hash(world.chancery["claims"])+hash(world.chancery["items"])
	if signature!=memorial_signature:
		memorial_signature=signature
		_populate_memorial()


# 列表构造：分类可筛选军务、民生及臣属处理过的事务。
func _populate_memorial() -> void:
	var items: Array = world.chancery["claims"] if memorial_filter.selected==0 else world.chancery["items"]
	var previous: Variant = null
	var selected: PackedInt32Array = memorial_list.get_selected_items()
	if not selected.is_empty():
		previous=memorial_list.get_item_metadata(selected[0])
	memorial_list.clear()
	var choice: int = 0
	for i: int in range(items.size()-1,-1,-1):
		var item: Dictionary = items[i]
		if memorial_filter.selected>=2 and item["group"]!=memorial_filter.get_item_text(memorial_filter.selected):
			continue
		var label: String = world.household_name(item["owner"])+"呈请垦荒" if memorial_filter.selected==0 else item["title"]
		var row: int = memorial_list.add_item("第%d日 · %s" % [item["day"],label])
		memorial_list.set_item_metadata(row,item)
		if item==previous:
			choice=row
	if memorial_list.item_count==0:
		memorial_actions.hide()
		memorial_detail.text="暂无待批奏请" if memorial_filter.selected==0 else "本类尚无奏报"
	else:
		memorial_list.select(choice)
		_read_memorial(choice)


# 奏章正文：申请列出请垦亩数、拟种作物和费用承担方，已办列出结果。
func _read_memorial(index: int) -> void:
	var item: Dictionary = memorial_list.get_item_metadata(index)
	var pending: bool = memorial_filter.selected==0
	memorial_actions.visible=pending
	if pending:
		memorial_detail.text="[b]%s呈请开垦[/b]\n第%d日呈报\n\n申请开垦 %d 亩，拟种%s。\n准许后由该户承担 40 金，其中 8 金用于向皇家采购 4 份木材。随后在城外农区登记新田。" % [world.household_name(item["owner"]),item["day"],item["acres"],State.Book.CROPS[item["crop"]]]
	else:
		memorial_detail.text="[b]%s[/b]\n第%d日 · %s\n\n%s" % [item["title"],item["day"],item["group"],item["detail"]]


# 朱批按钮：确认结果后立即同步地图，错误显示在当前奏章内。
func _rule_memorial(approve: bool) -> void:
	var selected: PackedInt32Array = memorial_list.get_selected_items()
	if selected.is_empty() or memorial_filter.selected!=0:
		return
	var result: String = State.Rural.rule(world,memorial_list.get_item_metadata(selected[0]),approve)
	if not result.is_empty():
		_read_memorial(selected[0])
		memorial_detail.append_text("\n\n[color=#ffd59a]"+result+"[/color]")
		return
	_sync_building_view()
	_refresh()
	_populate_memorial()
	if approve:
		memorial_window.hide()
		if region_overview.visible:
			_show_region_view(false)
		var id: String = world.buildings.back()["id"]
		town_map._focus_building(id)
		_inspect_building(id,true)
		status_label.text="已批准，农户正在此处开始垦田"


# 居民册界面：左侧检索住户，右侧阅读地址、成员、征收和产业。
func _build_resident_window() -> void:
	resident_window = Window.new()
	resident_window.title = "边境镇居民册"
	resident_window.visible = false
	resident_window.transient = true
	resident_window.exclusive = true
	resident_window.min_size = Vector2i(690,400)
	add_child(resident_window)
	resident_window.close_requested.connect(resident_window.hide)
	var margin := MarginContainer.new()
	resident_window.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,14)
	var body := VBoxContainer.new()
	body.theme = theme
	margin.add_child(body)
	var search := HBoxContainer.new()
	body.add_child(search)
	resident_filter = LineEdit.new()
	resident_filter.placeholder_text = "按姓名或坐标查找"
	resident_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_child(resident_filter)
	resident_filter.text_changed.connect(_populate_resident_list.unbind(1))
	_button(search,"全部住户",_show_all_residents)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 235
	body.add_child(split)
	resident_list = ItemList.new()
	resident_list.custom_minimum_size.x = 205
	resident_list.item_selected.connect(_show_resident_row)
	split.add_child(resident_list)
	resident_details = RichTextLabel.new()
	resident_details.bbcode_enabled = true
	resident_details.selection_enabled = true
	resident_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(resident_details)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	resident_home = _button(footer,"定位住址",_jump_to_household)
	_button(footer,"返回地图",resident_window.hide)


# 居民册入口：可看全城，也可先按所选住宅筛选。
func _open_resident_register() -> void:
	_show_register("")


# 房屋联动：从建筑详情进入本宅住户清单。
func _open_home_register() -> void:
	_show_register(inspected_building_id)


# 弹窗模块：刷新住址后填充居民册，保持地图操作焦点明确。
func _show_register(address: String) -> void:
	Register.sync_people(world)
	Register.assign_homes(world)
	resident_scope = address
	resident_filter.clear()
	_populate_resident_list()
	resident_window.popup_centered(Vector2i(760,470))


# 清除筛选：从某宅回到全城户籍。
func _show_all_residents() -> void:
	resident_scope = ""
	resident_filter.clear()
	_populate_resident_list()


# 地址显示：将房号折合为地点、建筑和有符号地图坐标。
func _address_text(address: String) -> String:
	if address.is_empty():
		return "居所待分配"
	if address=="building_000001":
		return "边境镇 · 领主厅附属住区 (6,6)"
	var record: Dictionary = Inspector.find(world,address)
	if record.is_empty():
		return "居所待分配"
	return "边境镇 · %s · %s (%d,%d)" % [town_map.building_title(address),address.trim_prefix("building_"),record["cell"][0],record["cell"][1]]


# 检索模块：跨成员姓名、户主和地址搜索。
func _populate_resident_list() -> void:
	resident_list.clear()
	var key: String = resident_filter.text.strip_edges()
	for i: int in range(world.resident_register.size()):
		var entry: Dictionary = world.resident_register[i]
		if not resident_scope.is_empty() and entry["address"] != resident_scope:
			continue
		var title: String = "%s · %d人" % [world.household_name(i),entry["people"].size()]
		var haystack: String = title + _address_text(entry["address"])
		for person: Dictionary in entry["people"]:
			haystack += person["name"]
		if not key.is_empty() and not haystack.contains(key):
			continue
		resident_list.add_item(title)
		resident_list.set_item_metadata(resident_list.item_count-1,i)
	if resident_list.item_count>0:
		resident_list.select(0)
		_show_resident_row(0)
	else:
		resident_details.text = "没有符合条件的住户"
		resident_home.disabled = true


# 户帖模块：使用实际收成税额和产业估值，迁入记录保留登记日期。
func _show_resident_row(row: int) -> void:
	var i: int = resident_list.get_item_metadata(row)
	var entry: Dictionary = world.resident_register[i]
	var asset: Dictionary = world.household_economy["families"][i]
	var worth: int = HouseEconomy.worth(world,i)
	var rank: String = "富裕户" if worth >= HouseEconomy.OFFICE_WEALTH else ("贫困户" if worth<75 else "殷实户")
	var occupation: String = "税务官户" if world.household_economy["civil"]==i else ("武将户" if world.household_economy["general"]==i else rank)
	var details: PackedStringArray = ["[font_size=25][b]%s[/b][/font_size]" % world.household_name(i),
		_address_text(entry["address"]),"登记于第%d日　%s　%s" % [entry["registered"],occupation,asset["occupation"]],
		"", "[b]家庭成员 · %d人[/b]" % entry["people"].size()]
	for p: int in range(entry["people"].size()):
		details.append(Register.member_line(world,i,p))
	details.append_array(["","[b]田宅与资产[/b]","田产 %d亩　渔船 %d艘　现金 %d金" % [asset["land"],asset["boats"],asset["cash"]],
		"资产估值 %d金　上日净收入 %+d金　雇工 %d人" % [worth,asset["income"],asset["hired"]],
		"","[b]上日实征[/b]","田赋 %d粮　渔税 %d粮　商税 %d金" % [entry["grain"],entry["fish"],entry["commerce"]]])
	for record: Dictionary in world.buildings:
		var owner: int = world.household_economy["property"].get(record["id"],world.royal_works["homes"].get(record["id"],-1))
		var stake: int = 100-world.royal_works["shares"].get(record["id"],0)
		if owner==i and stake>0:
			var share_text: String = " · 持股 %d%%" % stake if stake<100 else ""
			details.append("地籍 · "+town_map.building_title(record["id"]) + " (%d,%d)" % [record["cell"][0],record["cell"][1]]+share_text)
	resident_details.text = "\n".join(details)
	resident_details.scroll_to_line(0)
	resident_home.disabled = entry["address"].is_empty()


# 定位模块：看完户帖即可回到地图选中同一栋房屋。
func _jump_to_household() -> void:
	var rows: PackedInt32Array = resident_list.get_selected_items()
	if rows.is_empty():
		return
	var i: int = resident_list.get_item_metadata(rows[0])
	var id: String = world.resident_register[i]["address"]
	var record: Dictionary = Inspector.find(world,id)
	if record.is_empty():
		return
	resident_window.hide()
	_show_region_view(false)
	town_map.visit_site(Vector2i(record["cell"][0],record["cell"][1]))
	_inspect_building(id,true)


# 建造分类：展示真实占地，从选项自动进入对应地块预览。
func _build_category(title: String, icon_id: String, ids: Array[String]) -> void:
	var menu := MenuButton.new()
	menu.text = title + " ▾"
	menu.icon = HudIcons.texture(icon_id)
	menu.flat = false
	menu.focus_mode = Control.FOCUS_NONE
	build_toolbar.add_child(menu)
	var popup: PopupMenu = menu.get_popup()
	for i: int in range(ids.size()):
		var id: String = ids[i]
		var definition: Resource = Construction.Catalog.find(id)
		var scaled: bool = Construction.Catalog.LARGE_SIZES.has(id) and (id != "b_road" or not legacy_economy_fixture)
		var footprint: Vector2i = Construction.Catalog.footprint({"def_id": id, "large": scaled})
		var title_text: String = "宽街招标" if id == "b_road" and scaled else definition.get("display_name")
		popup.add_icon_item(HudIcons.texture(icon_id), "%s   %d×%d" % [title_text, footprint.x, footprint.y], i)
	popup.id_pressed.connect(_build_menu_selected.bind(ids))


# 建造选择：资源类型采用既有规则，选择分类项后隐藏抽屉扩大摆放视野。
func _build_menu_selected(index: int, ids: Array[String]) -> void:
	var id: String = ids[index]
	management_drawer.hide()
	if Construction.Catalog.LARGE_SIZES.has(id) and (id != "b_road" or not legacy_economy_fixture):
		_start_large_preview(id)
	else:
		_start_preview(Construction.Catalog.for_construction(id, false))


# 地块通知模块：只更新界面提示，不改变人口、库存或战略时间。
func _on_map_cell_changed(_cell: Vector2i) -> void:
	_refresh_map_info()


# 地图提示模块：平时显示选中的建筑，施工模式附带地块坐标。
func _refresh_map_info() -> void:
	map_info.text = "%d%%" % roundi(town_map.zoom_level * 100)
	var title: String = town_map.building_title(town_map.inspected_building_id)
	map_info.tooltip_text = "已选建筑 · %s\n方向键移动，滚轮缩放，双击聚焦，右键取消。" % ("—" if title.is_empty() else title)
	if town_map.active_definition != null:
		map_info.tooltip_text += "\n施工地块 %s" % _cell_text(town_map.hovered)


# 坐标文本模块：地图外或未选择时显示短横线。
func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y] if TownMap.Grid.contains(cell) else "—"


# 标签模块：统一设置左对齐与换行，便于浏览较长账单。
func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	if show_overview:
		_end_court_edit()
	if show_overview and town_map.active_definition != null:
		town_map.cancel_preview()
	if show_overview:
		region_overview.sync(world)
	region_overview.visible = show_overview
	town_view.visible = not show_overview
	build_toolbar.visible = not show_overview
	region_toggle.text = "返回城镇" if show_overview else "区域地图"


# 首府入口：从区域图选择进入边境镇时，镜头落回主城。
func _enter_home_region() -> void:
	_show_region_view(false)
	town_map.reset_view()


# 据点导航：从区域标注返回同一张地图，镜头移到对应营地。
func _view_region_site(cell: Vector2i) -> void:
	_show_region_view(false)
	town_map.sync_region_sites(world)
	town_map.visit_region_site(cell)


# 帧模块：推进固定步时钟并显示结果，界面自身不执行日结。
func _process(delta: float) -> void:
	if progress == null:
		return
	var before: int = world.tick
	clock.advance_real(delta)
	town_map.sync_hour(_hour())
	if world.tick != before:
		_refresh()
	elif not world.paused:
		progress.value = (world.tick % State.DAY_TICKS) + world.subsecond


# 时辰换算：沿用存档里的当日进度，与通勤和灯火使用同一个时间。
func _hour() -> float:
	return ((world.tick % State.DAY_TICKS)+world.subsecond)*24.0/State.DAY_TICKS


# 刷新模块：日期、库存与账单全部来自同一份世界数据。
func _refresh() -> void:
	town_map.sync_region_sites(world)
	if region_overview.visible:
		region_overview.sync(world)
	_refresh_legions()
	_refresh_army()
	_refresh_civic()
	_refresh_builder_controls()
	_refresh_population()
	_refresh_works()
	town_map.sync_capital(world.capital_layout, world.population)
	town_map.sync_hour(_hour())
	var crews: Dictionary = world.construction_crews()
	var working: bool = world.buildings.any(func(record:Dictionary)->bool: return record["state"]=="constructing")
	if crews!=town_map.construction_crews or working!=town_map.has_construction or world.paused!=town_map.animation_paused:
		town_map.construction_crews=crews
		town_map.has_construction=working
		town_map.animation_paused=world.paused
		town_map.motion_layer.queue_redraw()
	_refresh_estate()
	_refresh_inspection()
	_refresh_memorial()
	_set_numbers({
		"date": "第%d日 %02d时 · %s" % [world.current_day(), int(_hour()), "白昼" if _hour()>=6.0 and _hour()<18.0 else "夜间"],
		"population": world.population, "hud_workforce": world.workforce_capacity(), "hud_idle": world.idle_workers(),
		"food": world.resources["food"], "gold": world.resources["gold"],
		"wood": world.resources["wood"], "stone": world.resources["stone"],
	})
	_refresh_workforce_tooltips()
	for speed: int in speed_buttons:
		speed_buttons[speed].set_pressed_no_signal(speed == world.speed)
	progress.value = (world.tick % State.DAY_TICKS) + world.subsecond
	_refresh_storage()
	_refresh_ledger()
	pause_button.text = "继续" if world.paused else "暂停"
	town_map.sync_resources(world.resources)
	var ready_count: int = 0
	var queued_count: int = 0
	var active_text: String = "无施工任务"
	var active_progress: int = 0
	for building: Dictionary in world.buildings:
		if building["state"] == "ready":
			ready_count += 1
		else:
			queued_count += 1
			if queued_count == 1:
				active_text = str(Construction.Catalog.find(building["def_id"]).get("display_name"))
				active_progress = floori(100.0 * building["work_done"] / building["work_required"])
	_set_numbers({
		"ready_buildings": ready_count, "queued_buildings": queued_count,
		"housing": "%d / %d" % [world.population, world.housing_capacity()],
		"employable": world.workforce_capacity(), "dependent": world.dependents,
		"builders": world.builders - world.estate_builders, "idle": world.idle_workers(), "military_workers": Army.people(world.troops, true),
		"producers": world.production_workers() - Estate.production_count(world),
	})
	_refresh_production()
	construction_label.text = active_text
	construction_metrics.visible = queued_count > 0
	_set_numbers({"active_build_progress": "%d%%" % active_progress, "waiting_builds": maxi(0, queued_count - 1)})
	if queued_count>0 and not crews.values().any(func(count:int)->bool: return count>0):
		construction_label.text += "；缺施工工人，已停工"
	town_map.sync_yard_counts(Army.yard_counts(world))
	town_map.sync_worksite_staff(world.buildings)
	if displayed_building_tick != world.tick:
		displayed_building_tick = world.tick
		town_map.sync_property(world.household_economy.get("property", {}), [world.household_economy.get("civil",-1),world.household_economy.get("general",-1)])
		town_map.sync_buildings(world.buildings)
	if world.capital_layout:
		Register.sync_people(world)
		Register.assign_homes(world)
		town_map.sync_commutes(world)
	_sync_farm_view()


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
	if not store.save_world(world):
		status_label.text = "保存失败：" + store.error_message
		return
	_refresh_save_stamp()
	status_label.text = "已新增存档 · 游戏第%d日" % world.current_day()


# 存档时间文字：直接显示本地时间，旧存档保留未知状态。
func _saved_local_text(row: Dictionary) -> String:
	return "保存于 %s" % row["saved_local"] if row["saved_local"] != null else "保存时间未知"


# 存档时间栏：启动或保存时显示最新一份，指定读档时显示所选记录。
func _refresh_save_stamp(save_id: int = 0, loaded: bool = false) -> void:
	var rows: Array = store.list_saves()
	for row: Dictionary in rows:
		if save_id == 0 or int(row["id"]) == save_id:
			var context: String = "当前读档" if loaded else "最近存档"
			save_stamp.text = "%s · %s" % [context, _saved_local_text(row)]
			save_stamp.tooltip_text = "以本机时间显示"
			return
	save_stamp.text = "暂无存档" if store.error_message.is_empty() else "保存时间不可用"
	save_stamp.tooltip_text = ""


# 读档布局：通过行选择与确认按钮加载指定存档。
func _build_save_picker() -> void:
	save_picker = ConfirmationDialog.new()
	save_picker.title = "管理存档 · 最多保留七份 · 本机时间"
	save_picker.exclusive = true
	save_picker.get_ok_button().text = "读取所选"
	save_picker.get_cancel_button().text = "返回"
	add_child(save_picker)
	save_items = ItemList.new()
	save_items.custom_minimum_size = Vector2(600, 228)
	save_picker.add_child(save_items)
	save_picker.confirmed.connect(_load_selected)
	save_items.item_activated.connect(_activate_save)
	save_delete_button = save_picker.add_button("删除存档…", true, "delete_save")
	save_delete_button.pressed.connect(_request_save_delete)
	save_delete_dialog = ConfirmationDialog.new()
	save_delete_dialog.title = "确认删除存档"
	save_delete_dialog.exclusive = true
	save_delete_dialog.get_ok_button().text = "确认删除"
	save_delete_dialog.get_cancel_button().text = "保留存档"
	add_child(save_delete_dialog)
	save_delete_dialog.confirmed.connect(_confirm_save_delete)
	save_delete_dialog.canceled.connect(_cancel_save_delete)


# 列表入口：每次打开重新查询，防止显示已轮换淘汰的存档。
func _choose_save() -> void:
	var rows: Array = store.list_saves()
	save_items.clear()
	if rows.is_empty():
		status_label.text = "暂无战略存档，请先保存" if store.error_message.is_empty() else store.error_message
		return
	for row: Dictionary in rows:
		var date: String = _saved_local_text(row)
		var day: String = "第%d日" % row["game_day"] if int(row["game_day"]) > 0 else "游戏日期未知"
		save_items.add_item("%s  ·  %s  ·  %s  ·  #%d" % [date, day, row["title"], row["id"]])
		save_items.set_item_metadata(save_items.item_count - 1, int(row["id"]))
	save_items.select(0)
	save_picker.popup_centered()


# 删除请求：将确认文本和选中的稳定ID绑定，默认聚焦保留存档。
func _request_save_delete() -> void:
	var selection: PackedInt32Array = save_items.get_selected_items()
	if selection.is_empty():
		return
	var index: int = selection[0]
	pending_save_delete = int(save_items.get_item_metadata(index))
	save_delete_dialog.dialog_text = "确认永久删除以下存档？\n%s\n当前正在玩的进度会保留在游戏中。" % save_items.get_item_text(index)
	save_picker.hide()
	save_delete_dialog.popup_centered()
	save_delete_dialog.get_cancel_button().grab_focus()


# 删除确认：只有第二次明确确认时才操作数据库。
func _confirm_save_delete() -> void:
	var save_id: int = pending_save_delete
	pending_save_delete = 0
	if save_id <= 0:
		return
	if store.delete_save(save_id):
		save_items.clear()
		_refresh_save_stamp()
		status_label.text = "存档已删除"
	else:
		status_label.text = "删除失败：" + store.error_message
		_refresh_save_stamp()


# 删除取消：清除待删ID，并重新显示当前存档。
func _cancel_save_delete() -> void:
	pending_save_delete = 0
	call_deferred("_choose_save")


# 确认模块：只加载当前列表项记录的ID。
func _load_selected() -> void:
	var selection: PackedInt32Array = save_items.get_selected_items()
	if not selection.is_empty():
		_activate_save(selection[0])


# 激活模块：双击或确认选择，都使用同一个安全读取入口。
func _activate_save(index: int) -> void:
	if index < 0 or index >= save_items.item_count:
		return
	save_picker.hide()
	_load(int(save_items.get_item_metadata(index)))


# 读取模块：用校验成功的新世界替换旧引用，避免半读档和重复日结。
func _load(save_id: int = 0) -> void:
	_cancel_legion_close()
	selected_legion_id = ""
	legion_signature = ""
	_cancel_army_disband()
	_cancel_removal()
	var candidate: RefCounted = store.load_world(save_id)
	if candidate == null:
		status_label.text = store.error_message
		return
	_clear_inspection()
	_end_court_edit()
	memorial_signature=-1
	world = candidate
	if not legacy_economy_fixture:
		HouseEconomy.activate(world)
	selected_household = 0
	clock = Clock.new(world)
	town_map.cancel_preview()
	_sync_building_view()
	status_label.text = "读取成功：已恢复日期、资源、建筑与暂停状态"
	_refresh_save_stamp(save_id, true)
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
			if town_map.court_edit >= 0:
				_end_court_edit()
				get_viewport().set_input_as_handled()
			elif region_overview.visible:
				_show_region_view(false)
				get_viewport().set_input_as_handled()
			elif town_map.active_definition != null:
				town_map.cancel_preview()
				get_viewport().set_input_as_handled()
			elif management_drawer.visible:
				management_drawer.hide()
				get_viewport().set_input_as_handled()
			else:
				_request_game_exit()


# 关闭按钮入口：窗口关闭请求与 Esc 共用自动存档。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and automatic_lifecycle:
		_request_game_exit()


# 退出请求：保存成功后释放窗口和数据库，失败仍可继续操作。
func _request_game_exit() -> void:
	if automatic_lifecycle and not _save_on_exit():
		status_label.text = "自动存档失败，游戏仍打开：" + store.error_message
		return
	get_tree().quit()


# 自动存档模块：复用普通存档的事务和七档轮换。
func _save_on_exit() -> bool:
	return store.save_world(world,"退出自动存档")


# 退出模块：释放存档连接。
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


# 大型场地入口：使用可验证的场地规格建立预览。
func _start_large_preview(id: String) -> void:
	_start_preview(Construction.Catalog.for_construction(id, true))


# 建筑选择模块：为一次放置生成唯一命令，失败时可调整位置重试。
func _start_preview(definition: Resource) -> void:
	_end_court_edit()
	if definition.get("id") == "b_road" and world.capital_layout:
		definition = Construction.Catalog.for_construction("b_road", true)
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
	placement_label.visible = bool(result.get("active", false))
	cancel_build_button.visible = placement_label.visible
	if not result.get("active", false):
		placement_label.text = "已退出建造模式，可普通选格"
	else:
		placement_label.text = str(town_map.active_definition.get("display_name")) + "：" + str(result.get("reason", ""))


# 确认建造模块：校验并提交一次建造，道路和城墙保留预览供连续铺设。
func _on_placement_clicked(_result: Dictionary) -> void:
	if town_map.active_definition == null:
		return
	var definition: Resource = town_map.active_definition
	if world.capital_layout and definition.get("id") == "b_road":
		var order: Dictionary = Works.publish(world,town_map.hovered)
		status_label.text = "已发布道路招标，预留%d金币" % Works.ROAD_BUDGET if order["ok"] else order["reason"]
		_refresh_works()
		town_map._update_preview()
		return
	var result: Dictionary = Construction.execute(world, definition.get("id"), town_map.hovered, pending_build_command, bool(definition.get_meta("large", false)))
	if not result["ok"]:
		status_label.text = "建造失败：" + str(result.get("reason", ""))
		return
	_sync_building_view()
	if definition.get("id") in ["b_road", "b_wall"]:
		pending_build_command = Crypto.new().generate_random_bytes(16).hex_encode()
		_refresh()
	else:
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
	town_map.sync_palace(world.palace_decor)
	palace_menu.visible = world.capital_layout
	town_map.sync_capital(world.capital_layout, world.population)
	town_map.sync_hour(_hour())
	city_navigation.visible = world.capital_layout
	town_map.sync_property(world.household_economy.get("property", {}), [world.household_economy.get("civil",-1),world.household_economy.get("general",-1)])
	town_map.sync_buildings(world.buildings)
	if world.capital_layout:
		Register.sync_people(world)
		Register.assign_homes(world)
		town_map.sync_commutes(world)
	_sync_farm_view()
	town_map.sync_resources(world.resources)


# 施工按钮：城镇与所选工地使用同一支队伍，分配后两处同时更新。
func _build_builder_buttons(row: HBoxContainer) -> void:
	builder_remove_buttons.append(_button(row, "施工 −1", _change_builders.bind(-1)))
	builder_add_buttons.append(_button(row, "施工 +1", _change_builders.bind(1)))


# 增员限制：给出当前阻塞原因，并由世界再验证是否能占用新的岗位。
func _builder_add_block() -> String:
	if world.builders >= State.MAX_BUILDERS:
		return "施工队已达%d人上限" % State.MAX_BUILDERS
	if world.idle_workers() <= 0:
		return "可用劳动力为0"
	return ""


# 用工提示：从同一份人口数据解释空闲人数和解除阻塞的入口。
func _refresh_builder_controls() -> void:
	var block: String = _builder_add_block()
	for button: Button in builder_add_buttons:
		button.disabled = not block.is_empty()
		button.tooltip_text = block if button.disabled else "从可用劳动力调1人到施工队"
	for button: Button in builder_remove_buttons:
		button.disabled = world.builders <= world.estate_builders
		button.tooltip_text = "施工队目前无人" if button.disabled else "将1名施工工人释放为空闲"
	var producers: int = world.production_workers() - Estate.production_count(world)
	release_producer_button.visible = world.idle_workers() <= 0 and producers > 0 and world.builders < State.MAX_BUILDERS
	var hint: String = "全城共用施工队 · %d / %d 人" % [world.builders, State.MAX_BUILDERS]
	if world.idle_workers() == 0 and world.builders < State.MAX_BUILDERS:
		hint += "\n无空闲人手 · 军职%d · 生产%d" % [Army.people(world.troops, true), producers]
	site_builder_hint.text = hint


# 人口面板：按家庭展示儿童的成年日，与全城下次结算提示同步。
func _refresh_population() -> void:
	var adulthood: Dictionary = Population.next_adulthood(world.households)
	_set_numbers({
		"households": world.households.size(), "children": world.dependents,
		"next_adult_day": "第%d日" % adulthood["day"] if adulthood["day"] > 0 else "—",
		"next_adult_count": adulthood["count"],
	})
	var next_check: int = world.last_settled_day + Population.MIGRATION_PERIOD - world.last_settled_day % Population.MIGRATION_PERIOD
	var block: String = Population.growth_block(world, Population.MIGRANT_SIZE)
	population_hint.text = "下次移民检查在第%d日结算。%s" % [next_check, "目前符合条件" if block.is_empty() else block]
	var report: Dictionary = world.population_report
	population_event.text = "上次日结：迁入%d · 出生%d · 成年%d" % [report.get("joined", 0), report.get("born", 0), report.get("matured", 0)]
	population_event.visible = not report.is_empty()
	var signature: String = JSON.stringify([world.households, world.household_economy, world.legions])
	if signature == household_signature:
		return
	household_signature = signature
	household_list.clear()
	if not world.household_economy.is_empty():
		_refresh_register()
		return
	for i: int in range(world.households.size()):
		var family: Dictionary = world.households[i]
		var dates := PackedStringArray()
		for day: int in family["children"]:
			dates.append("第%d日" % day)
		var note: String = " · 成年 " + "、".join(dates) if not dates.is_empty() else ""
		household_list.add_item("%s · 成人%d 儿童%d%s" % [world.household_name(i), family["adults"], dates.size(), note], HudIcons.texture("people"), false)


# 户籍界面：按户显示资产、田亩、人口与职业，详情可用于选任。
func _refresh_register() -> void:
	var state: Dictionary = world.household_economy
	for i: int in range(world.households.size()):
		var family: Dictionary = world.households[i]
		var members: int = int(family["adults"]) + family["children"].size()
		var asset: Dictionary = state["families"][i]
		household_list.add_item("%s · %d人 · %d金资产 · %d亩" % [world.household_name(i), members, HouseEconomy.worth(world, i), asset["land"]])
	selected_household = clampi(selected_household, 0, world.households.size() - 1)
	household_list.select(selected_household)
	var selected_legion: String = _appointment_legion_id()
	appointment_legion.clear()
	for legion: Dictionary in world.legions:
		if legion["state"] != "active" or legion["members"].is_empty():
			continue
		appointment_legion.add_item(legion["name"])
		appointment_legion.set_item_metadata(appointment_legion.item_count - 1, legion["id"])
		if selected_legion == legion["id"]:
			appointment_legion.select(appointment_legion.item_count - 1)
	if appointment_legion.selected < 0 and appointment_legion.item_count > 0:
		appointment_legion.select(0)
	_update_appointment(0)


# 户籍选择：刷新此户资产、就业与任命规则。
func _select_household(index: int) -> void:
	selected_household = index
	_update_appointment(0)


# 军团下拉：只有带现役成员的军团会成为可选目标。
func _appointment_legion_id() -> String:
	if appointment_legion.selected < 0:
		return ""
	return str(appointment_legion.get_item_metadata(appointment_legion.selected))


# 任命说明：任职效果来自能力，家资只决定是否进入候选名单。
func _update_appointment(_option: int) -> void:
	var state: Dictionary = world.household_economy
	var family: Dictionary = world.households[selected_household]
	var asset: Dictionary = state["families"][selected_household]
	var buildings: PackedStringArray = []
	var wealth: int = HouseEconomy.worth(world, selected_household)
	var standing: String = "富裕" if wealth >= HouseEconomy.OFFICE_WEALTH else ("贫困" if wealth < 75 else "殷实")
	for building: Dictionary in world.buildings:
		var stake: int = 100-world.royal_works["shares"].get(building["id"],0)
		if state["property"].get(building["id"], -1) == selected_household and stake>0:
			var share_text: String = "（%d%%）" % stake if stake<100 else ""
			buildings.append(HouseEconomy.TITLES[building["def_id"]]+share_text)
	household_detail.text = "%s · %s · 成人%d · 儿童%d\n现金%d金 · 田地%d亩 · 渔船%d艘\n%s · 上日净入%+d金 · 雇工%d · 商税%d金\n私产：%s\n文才%d · 武略%d；候选家资至少%d金，能力至少60。" % [
		world.household_name(selected_household), standing, family["adults"], family["children"].size(), asset["cash"], asset["land"], asset["boats"],
		asset["occupation"], asset["income"], asset["hired"], asset["tax"], "、".join(buildings) if not buildings.is_empty() else "无",
		asset["civil"], asset["marshal"], HouseEconomy.OFFICE_WEALTH]
	civil_button.disabled = not HouseEconomy.eligible(world, selected_household, false) or selected_household in [state["civil"], state["general"]]
	marshal_button.disabled = not HouseEconomy.eligible(world, selected_household, true) or selected_household == state["civil"] or _appointment_legion_id().is_empty()
	var report: Dictionary = state["report"]
	household_report.text = "税务官：%s　武将：%s\n最近结算 · 税粮%d · 渔税%d · 商税%d金 · 雇工%d\n标准税：田亩税粮18%% · 店铺营业税22%%" % [
		world.household_name(state["civil"]) if state["civil"] >= 0 else "空缺",
		world.household_name(state["general"]) if state["general"] >= 0 else "空缺",
		report.get("tax_grain", 0), report.get("fish_levy", 0), report.get("shop_tax", 0), report.get("hires", 0)]


# 任命命令：由世界校验文武资格和军团驻地。
func _appoint_household(military: bool) -> void:
	var appointed: bool = HouseEconomy.appoint(world, selected_household, military, _appointment_legion_id())
	status_label.text = "任命成功" if appointed else "任命失败：请检查候选资格和军团是否驻守主城"
	_refresh_population()


# 独立施工按钮：仅使用领主人手，共享城镇施工队容量。
func _build_estate_builder_buttons(row: HBoxContainer) -> void:
	estate_builder_remove.append(_button(row, "劳役施工 −1", _change_estate_builders.bind(-1)))
	estate_builder_add.append(_button(row, "劳役施工 +1", _change_estate_builders.bind(1)))


# 领主面板：显示购买成本、劳役池和独立日用粮，不混入居民口粮账。
func _refresh_estate() -> void:
	var bill: Dictionary = world.estate_food_report
	_set_numbers({
		"estate_workers": world.estate_workers, "estate_idle": world.estate_idle(),
		"estate_construction": world.estate_builders, "estate_production": Estate.production_count(world),
		"estate_daily_food": "%.1f" % (world.estate_workers * 0.5), "estate_food_paid": bill.get("paid", "—"),
	})
	var blocked: String = Estate.purchase_block(world)
	estate_buy_button.disabled = not blocked.is_empty()
	estate_buy_button.tooltip_text = blocked
	estate_site_row.visible = world.estate_workers > 0
	for button: Button in estate_builder_add:
		button.disabled = world.estate_idle() == 0 or world.builders >= State.MAX_BUILDERS
	for button: Button in estate_builder_remove:
		button.disabled = world.estate_builders == 0
	estate_food_hint.text = "每人每日0.5粮食，半份结转。"
	if int(bill.get("shortage", 0)) > 0:
		estate_food_hint.text += " 上日缺粮%d。" % int(bill["shortage"])


# 购买入口：每次明确点击只完成一笔金币与独立人手交易。
func _purchase_estate() -> void:
	status_label.text = "领主劳役 +1，可分配施工或生产" if Estate.purchase(world) else Estate.purchase_block(world)
	_refresh()


# 独立调岗：从选中建筑分配或释放领主生产人员。
func _change_estate_producers(delta: int) -> void:
	status_label.text = "已调整领主生产人员" if world.assign_estate_producers(inspected_building_id, delta) else "劳役空闲或设施岗位不足"
	_refresh()


# 独立施工：两类人手共用施工队容量，分开增减。
func _change_estate_builders(delta: int) -> void:
	status_label.text = "已调整领主施工人员" if world.assign_estate_builders(delta) else "劳役空闲不足或施工队已满"
	_refresh()


# 顶栏提示：人口旁的两项数值可直接查看计算口径和岗位占用。
func _refresh_workforce_tooltips() -> void:
	var workforce: Label = numbers["hud_workforce"]
	var idle: Label = numbers["hud_idle"]
	workforce.get_parent().get_parent().get_parent().tooltip_text = "人口%d − 被抚养%d = 劳动力%d" % [
		world.population, world.dependents, world.workforce_capacity(),
	]
	idle.get_parent().get_parent().get_parent().tooltip_text = "劳动力%d − 施工%d − 生产%d − 军职%d = 可用%d" % [
		world.workforce_capacity(), world.builders - world.estate_builders, world.production_workers() - Estate.production_count(world), Army.people(world.troops, true), world.idle_workers(),
	]


# 生产岗位入口：选中一个有人的生产建筑，具体减员仍由玩家确认操作。
func _open_staffed_production() -> void:
	_open_management(1)
	town_picker.select(2)
	_show_data_section(2, town_sections)
	for index: int in range(producer_picker.item_count):
		var building: Dictionary = Inspector.find(world, str(producer_picker.get_item_metadata(index)))
		if int(building.get("workers", 0)) > int(world.estate_posts.get(building.get("id", ""), 0)):
			producer_picker.select(index)
			_on_producer_selected(index)
			return


# 岗位操作：按钮只发出分配请求，守恒与上限由世界模型验证。
func _change_builders(delta: int) -> void:
	if world.assign_builders(world.builders + delta):
		status_label.text = "施工队 %d / %d 人" % [world.builders, State.MAX_BUILDERS]
	elif delta > 0:
		status_label.text = _builder_add_block()
	else:
		status_label.text = "施工队没有可撤下的居民"
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
	for id: String in summaries:
		var info: Dictionary = _production_info(Construction.Catalog.find(id))
		production_rows[id].visible = int(summaries[id][1]) > 0
		_set_numbers({
			id + "_jobs": "%d / %d" % [summaries[id][0], summaries[id][1]],
			id + "_rate": "%d %s" % [int(summaries[id][0]) * int(info["rate"]), info["unit"]],
		})
	var selected: Dictionary = Inspector.find(world, str(producer_picker.get_selected_metadata()))
	producer_detail.visible = selected.is_empty()
	producer_numbers.visible = not selected.is_empty()
	if not selected.is_empty():
		var info: Dictionary = _production_info(Construction.Catalog.find(selected["def_id"]))
		_set_numbers({
			"producer_workers": selected["workers"],
			"producer_credit": "%.2f %s" % [int(selected[info["credit"]]) / float(State.DAY_TICKS), info["unit"]],
		})


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


# 分组标题：用相同字号和低饱和色区隔不同用途的指标。
func _section_title(parent: Container, title_text: String) -> void:
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("#bac4ae"))
	parent.add_child(heading)


# 数值单元：每项由独立的图标、含义与数值组成，可用于常驻栏或详情面板。
func _number_grid(parent: Container, title_text: String, entries: Array, columns: int) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(group)
	if not title_text.is_empty():
		_section_title(group, title_text)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	group.add_child(grid)
	for entry: Array in entries:
		var card := PanelContainer.new()
		card.tooltip_text = entry[1]
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", HudTheme.surface("#1c2520", "#364237", 5))
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = HudIcons.texture(entry[2])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.add_theme_constant_override("separation", 0)
		row.add_child(text_column)
		var caption := Label.new()
		caption.text = entry[1]
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color("#b9c3b0"))
		text_column.add_child(caption)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 16)
		if entry[0] != "date":
			value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_column.add_child(value)
		numbers[entry[0]] = value
	return group


# 数值更新：与游戏状态同源，仅在展示值变化时改动控件。
func _set_numbers(values: Dictionary) -> void:
	for key: String in values:
		var label: Label = numbers[key]
		var value: String = str(values[key])
		if compact_resources.has(key):
			compact_resources[key].text=value
		if label.text != value:
			label.text = value
			var card: PanelContainer = label.get_parent().get_parent().get_parent()
			var caption: Label = label.get_parent().get_child(0)
			card.tooltip_text = "%s · %s" % [caption.text, value]
			var signed: bool = value.begins_with("+") or value.begins_with("-") or value.begins_with("−")
			if signed:
				var tint: Color = Color("#abd198") if value.begins_with("+") else Color("#e7aa8f")
				label.add_theme_color_override("font_color", tint if value.substr(1) != "0" else Color("#e8dfc9"))


# 账本分类：一次只显示一种收支，减少同时出现的指标数量。
func _build_ledger() -> void:
	var picker := OptionButton.new()
	panel.add_child(picker)
	var categories: Array = [
		["口粮", "food", [
			["food_day", "结算日", "clock"],
			["grain_in", "粮食入库", "food"],
			["grain_used", "居民口粮" if legacy_economy_fixture else "公共救济", "people"],
			["grain_open", "期初储粮", "food"],
			["grain_close", "口粮后余额", "food"],
			["grain_net", "基础口粮净变化", "food"],
			["grain_short", "居民缺粮", "warn"],
			["grain_produced", "粮食总产出", "food"],
			["grain_over", "库存溢出", "warn"],
			["grain_need", "居民需粮" if legacy_economy_fixture else "居民缺口", "people"],
			["grain_cap", "结算时容量", "house"],
			["farm_out", "农场" if legacy_economy_fixture else "田亩税粮", "food"],
			["ranch_out", "牧场", "ranch"],
			["fish_out", "渔场" if legacy_economy_fixture else "渔税", "fish"],
			["grain_military", "扣除军粮", "shield"],
			["grain_total", "军需后余粮", "food"],
			["grain_day_net", "全日净变化", "food"],
		]],
		["政务", "gold", [
			["civic_day", "结算日", "clock"],
			["tax_stored", "税收入库", "gold"],
			["tax_over", "税收溢出", "warn"],
			["tax_policy", "当日税率", "book"],
			["satisfaction_change", "满意度变化", "happy"],
			["tax_delta", "税率影响", "happy"],
			["tax_recovery", "供粮恢复", "food"],
			["tax_penalty", "缺粮影响", "warn"],
			["fort_gold", "旧堡金币入库", "gold"],
			["fort_income", "旧堡应缴", "gold"],
			["fort_over", "旧堡金币溢出", "warn"],
		]],
		["军需", "shield", [
			["army_day", "结算日", "clock"],
			["ration_paid", "军粮实付 / 应付", "food"],
			["pay_paid", "军饷实付 / 应付", "gold"],
			["ration_short", "缺军粮", "warn"],
			["pay_short", "缺军饷", "warn"],
			["morale_change", "士气变化", "happy"],
			["morale_delta", "士气增减", "happy"],
		]],
		["材料", "wood", [
			["material_day", "结算日", "clock"],
			["wood_in", "木材入库", "wood"],
			["stone_in", "石材入库", "stone"],
			["wood_over", "木材溢出", "warn"],
			["stone_over", "石材溢出", "warn"],
			["local_wood", "伐木场产量", "wood"],
			["woods_wood", "北部林地产量", "wood"],
		]],
	]
	for category: Array in categories:
		picker.add_icon_item(HudIcons.texture(category[1]), category[0])
		var section := _data_section(panel, ledger_sections)
		ledger_data.append(_number_grid(section, "", category[2], 3))
		var message := Label.new()
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(message)
		ledger_message.append(message)
	picker.item_selected.connect(_show_data_section.bind(ledger_sections))
	_show_data_section(0, ledger_sections)


# 分类内容：为选项建立独立容器，布局和滚动跟随当前类别。
func _data_section(parent: VBoxContainer, sections: Array[Control]) -> VBoxContainer:
	var section := VBoxContainer.new()
	parent.add_child(section)
	sections.append(section)
	return section


# 类别切换：只切换当前分组，并回到该分组开头。
func _show_data_section(index: int, sections: Array[Control]) -> void:
	for i: int in range(sections.size()):
		sections[i].visible = i == index
	sections[index].get_parent().get_parent().scroll_vertical = 0


# 账本有无状态：旧存档可显示原文摘要，新档等待首次日结。
func _ledger_available(index: int, available: bool, message: String = "尚未生成日结记录") -> bool:
	ledger_data[index].visible = available
	ledger_message[index].visible = not available
	if not available:
		ledger_message[index].text = message
	return available


# 库存提示：只有达到警戒容量时才占用一行。
func _refresh_storage() -> void:
	var capacity: int = world.food_capacity()
	var stock: int = int(world.resources["food"])
	_set_numbers({"food_store": "%d / %d" % [stock, capacity]})
	stock_warning.visible = stock >= capacity - 15
	stock_warning.text = "存粮超过容量，新粮暂停入库" if stock > capacity else "储粮接近上限"


# 日结同步：四类数据各取已完成的账本，不从当前库存反推历史。
func _refresh_ledger() -> void:
	var bill: Dictionary = world.last_food_ledger
	if _ledger_available(0, not bill.is_empty(), world.last_bill):
		var army: Dictionary = world.last_army_ledger
		if army.get("day") != bill["day"]:
			army = {}
		_set_numbers({
			"food_day": "第%d日" % bill["day"],
			"grain_in": "+%d" % bill["stored"],
			"grain_used": "−%d" % bill["consumed"],
			"grain_open": bill["opening"],
			"grain_close": bill["closing"],
			"grain_net": "%+d" % bill["net"],
			"grain_short": bill["shortage"],
			"grain_produced": bill["produced"],
			"grain_over": bill["overflow"],
			"grain_need": bill["needed"],
			"grain_cap": bill["capacity"],
			"farm_out": bill["by_source"].get("tax_grain", bill["by_source"]["b_farm"]),
			"ranch_out": bill["by_source"]["b_ranch"],
			"fish_out": bill["by_source"].get("fish_levy", bill["by_source"]["b_fishery"]),
			"grain_military": ("−%d" % army["food_used"]) if army.has("food_used") else "—",
			"grain_total": army.get("food_after", "—"),
			"grain_day_net": "%+d" % (int(army["food_after"]) - int(bill["opening"])) if army.has("food_after") else "—",
		})
	bill = world.last_civic_ledger
	if _ledger_available(1, not bill.is_empty()):
		_set_numbers({
			"civic_day": "第%d日" % bill["day"],
			"tax_stored": "+%d" % (int(bill["tax_stored"]) + int(bill.get("shop_gold", {}).get("stored", 0))),
			"tax_over": bill["tax_overflow"],
			"tax_policy": Civic.policy_name(bill["policy"]),
			"satisfaction_change": "%d → %d" % [bill["before"], bill["after"]],
			"tax_delta": "%+d" % bill["policy_delta"],
			"tax_recovery": "%+d" % bill["recovery"],
			"tax_penalty": "−%d" % bill["food_penalty"],
			"fort_gold": "+%d" % int(bill.get("fort_gold", {}).get("stored", 0)),
			"fort_income": bill.get("fort_gold", {}).get("income", 0),
			"fort_over": bill.get("fort_gold", {}).get("overflow", 0),
		})
	bill = world.last_army_ledger
	if _ledger_available(2, not bill.is_empty()):
		_set_numbers({
			"army_day": "第%d日" % bill["day"],
			"ration_paid": "%d / %d" % [bill["food_used"], bill["food_needed"]],
			"pay_paid": "%d / %d" % [bill["wage_paid"], bill["wage_needed"]],
			"ration_short": bill["food_shortage"],
			"pay_short": bill["wage_shortage"],
			"morale_change": "%d → %d" % [world.last_morale_before, world.army_morale] if world.last_morale_before != null else "—",
			"morale_delta": "%+d" % (world.army_morale - int(world.last_morale_before)) if world.last_morale_before != null else "—",
		})
	bill = world.last_material_ledger
	if _ledger_available(3, not bill.is_empty()):
		_set_numbers({
			"material_day": "第%d日" % bill["day"],
			"wood_in": "+%d" % bill["wood"]["stored"],
			"stone_in": "+%d" % bill["stone"]["stored"],
			"wood_over": bill["wood"]["overflow"],
			"stone_over": bill["stone"]["overflow"],
			"local_wood": int(bill["wood"]["produced"]) - int(bill.get("woods_wood", 0)),
			"woods_wood": bill.get("woods_wood", 0),
		})


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
	if not legacy_economy_fixture:
		resident_card = Label.new()
		resident_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(resident_card)
		var quick := HBoxContainer.new()
		contents.add_child(quick)
		_button(quick,"查看本宅居民册",_open_home_register)
		resident_card.set_meta("actions",quick)
	site_builder_actions = VBoxContainer.new()
	contents.add_child(site_builder_actions)
	var crew_buttons := HBoxContainer.new()
	site_builder_actions.add_child(crew_buttons)
	_build_builder_buttons(crew_buttons)
	estate_site_row = HBoxContainer.new()
	site_builder_actions.add_child(estate_site_row)
	_build_estate_builder_buttons(estate_site_row)
	site_builder_hint = Label.new()
	site_builder_hint.add_theme_font_size_override("font_size", 13)
	site_builder_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	site_builder_actions.add_child(site_builder_hint)
	release_producer_button = Button.new()
	release_producer_button.text = "调整生产岗位"
	release_producer_button.focus_mode = Control.FOCUS_NONE
	release_producer_button.pressed.connect(_open_staffed_production)
	site_builder_actions.add_child(release_producer_button)
	site_builder_actions.hide()
	_number_grid(contents, "", [
		["building_level", "等级", "house"], ["building_size", "占地", "house"],
		["building_progress", "施工进度", "work"], ["building_queue", "施工顺序", "clock"],
		["building_builders", "施工工人", "people"], ["building_jobs", "在岗 / 岗位", "people"],
		["building_rate", "全天折算", "work"], ["building_credit", "待入库", "book"],
		["building_housing", "提供住房", "house"], ["building_capacity", "储粮容量", "food"],
	], 2)
	var actions: HBoxContainer = HBoxContainer.new()
	contents.add_child(actions)
	inspection_decrease = _button(actions, "本建筑工人 -1", _change_inspected_workers.bind(-1))
	inspection_increase = _button(actions, "本建筑工人 +1", _change_inspected_workers.bind(1))
	var estate_actions := HBoxContainer.new()
	contents.add_child(estate_actions)
	estate_producer_remove = _button(estate_actions, "劳役生产 −1", _change_estate_producers.bind(-1))
	estate_producer_add = _button(estate_actions, "劳役生产 +1", _change_estate_producers.bind(1))
	var military_actions: HBoxContainer = HBoxContainer.new()
	contents.add_child(military_actions)
	army_recruit_button = _button(military_actions, "招募%d名步兵" % Army.UNIT.batch_size, _recruit_infantry)
	barracks_stats = _number_grid(contents, "招募", [
		["barracks_people", "在营 / 编额", "shield"], ["batch_size", "每批人数", "people"],
		["batch_gold", "招募金币", "gold"], ["batch_wood", "招募木材", "wood"],
		["batch_time", "训练用时", "clock"], ["batch_workers_after", "征募后可用居民", "people"],
	], 2)
	barracks_notice = Label.new()
	barracks_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(barracks_notice)
	var lifecycle: VBoxContainer = VBoxContainer.new()
	contents.add_child(lifecycle)
	army_troop_picker = OptionButton.new()
	lifecycle.add_child(army_troop_picker)
	_number_grid(lifecycle, "", [
		["batch_people", "批次人数", "people"], ["batch_progress", "训练进度", "work"],
	], 2)
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
	field_card=Label.new()
	field_card.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(field_card)
	asset_card = VBoxContainer.new()
	contents.add_child(asset_card)
	asset_label = Label.new()
	asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asset_card.add_child(asset_label)
	var finance := HBoxContainer.new()
	asset_card.add_child(finance)
	equity_points = SpinBox.new()
	equity_points.min_value = 1
	equity_points.max_value = 100
	equity_points.value = 10
	equity_points.suffix = "%"
	equity_points.value_changed.connect(func(_points: float) -> void: _refresh_asset())
	finance.add_child(equity_points)
	invest_button = _button(finance,"购买股份",_request_equity.bind(false))
	var acquisition := HBoxContainer.new()
	asset_card.add_child(acquisition)
	buyout_button = _button(acquisition,"收购商铺",_request_equity.bind(true))
	equity_dialog = ConfirmationDialog.new()
	equity_dialog.exclusive = true
	equity_dialog.get_ok_button().text = "确认支付"
	equity_dialog.confirmed.connect(_confirm_equity)
	add_child(equity_dialog)
	removal_dialog = ConfirmationDialog.new()
	removal_dialog.exclusive = true
	removal_dialog.get_ok_button().text = "确认执行"
	removal_dialog.get_cancel_button().text = "保留建筑"
	removal_dialog.confirmed.connect(_confirm_removal)
	removal_dialog.canceled.connect(_cancel_removal)
	add_child(removal_dialog)
	_refresh_inspection()


# 地图选择模块：地图反馈整栋建筑的标识，详情根据归属提供对应操作。
func _on_town_selected(id: String) -> void:
	_inspect_building(id, true)


# 下拉选择模块：生产列表与地图详情使用同一建筑ID，避免两处操作不同对象。
func _on_producer_selected(index: int) -> void:
	if town_map.active_definition != null:
		town_map.cancel_preview()
	_inspect_building(str(producer_picker.get_item_metadata(index)), false)
	_refresh_production()


# 身份绑定模块：只记稳定ID，更新全建筑高亮并同步已有生产列表。
func _inspect_building(id: String, reveal: bool) -> void:
	inspected_building_id = id if not Inspector.find(world, id).is_empty() else ""
	var focus: String = id if town_map.site_buildings.has(id) or town_map.capital_buildings.has(id) else inspected_building_id
	town_map.highlight_building(focus)
	_refresh_map_info()
	if producer_picker != null:
		for index: int in range(producer_picker.item_count):
			if producer_picker.get_item_metadata(index) == inspected_building_id:
				producer_picker.select(index)
		_refresh_production()
	_refresh_inspection()
	if reveal and not focus.is_empty():
		_open_management(0)
		management_scroll.set_deferred("scroll_vertical", 0)


# 住宅摘要：区分宅主与住户，合住时显示每户全部个人资料。
func _refresh_residence_card(record: Dictionary) -> void:
	var housing: bool = record.get("def_id") in ["b_house","b_manor"] and record.get("state")=="ready"
	resident_card.visible = housing
	resident_card.get_meta("actions").visible = housing
	if not housing:
		return
	Register.sync_people(world)
	Register.assign_homes(world)
	var id: String = record["id"]
	var households: Array[int] = Register.residents(world,id)
	var owner: int = world.household_economy["property"].get(id,world.royal_works["homes"].get(id,-1))
	var lines: PackedStringArray = ["宅主：%s" % world.household_name(owner) if owner>=0 else "宅主：公有分配住宅"]
	for i: int in households:
		var people: Array = world.resident_register[i]["people"]
		lines.append("%s ｜ %d口" % [world.household_name(i),people.size()])
		for p: int in range(people.size()):
			lines.append(Register.member_line(world,i,p))
	if households.is_empty():
		lines.append("目前空置")
	resident_card.text = "\n".join(lines)


# 商铺卡片：并排展示市值、最新净利、估值依据和余下股权价格。
func _refresh_asset() -> void:
	var offer: Dictionary = Works.quote(world,inspected_building_id) if world.capital_layout else {}
	asset_card.visible = not offer.is_empty()
	if offer.is_empty():
		return
	var held: int = offer["share"]
	var available: int = 100-held
	var stats: String = "暂无完整营业日" if offer["days"]==0 else "上日净利 %+d 金 · 近%d日均 %+0.1f 金" % [offer["latest"],offer["days"],offer["average"]]
	var ownership: String = "皇家全资 · 原商户受托经营" if held==100 else "皇家持有 %d%% · 商户持有 %d%%" % [held,available]
	asset_label.text = "商铺市值 %d 金\n%s\n%s" % [offer["value"],stats,ownership]
	equity_points.get_parent().visible = available>0
	buyout_button.visible = available>0
	if available==0:
		return
	equity_points.set_block_signals(true)
	equity_points.max_value = available
	equity_points.set_value_no_signal(clampi(int(equity_points.value),1,available))
	equity_points.set_block_signals(false)
	var due: int = Works.share_price(offer["value"],held,int(equity_points.value))
	var total: int = Works.share_price(offer["value"],held,available)
	invest_button.text = "入股 · %d金" % due
	buyout_button.text = "收购剩余 %d%% · %d金" % [available,total]
	var capacity: int = 1000000-world.household_economy["families"][offer["owner"]]["cash"]
	var budget: int = mini(world.resources["gold"],capacity)
	invest_button.disabled = due>budget
	buyout_button.disabled = total>budget


# 付款确认：只使用玩家确认的商铺及当时的报价，日结后报价过期需重开窗口。
func _request_equity(buy_all: bool) -> void:
	var offer: Dictionary = Works.quote(world,inspected_building_id)
	if offer.is_empty() or offer["share"]>=100:
		return
	var points: int = 100-offer["share"] if buy_all else int(equity_points.value)
	var due: int = Works.share_price(offer["value"],offer["share"],points)
	equity_order = {"id":inspected_building_id,"points":points,"offer":offer}
	equity_dialog.title = "确认收购商铺" if offer["share"]+points==100 else "确认购买股份"
	equity_dialog.dialog_text = "%s\n本次支付 %d 金，获得 %d%% 股份。\n成交后持股 %d%%，营业净利按占比划拨。" % [town_map.building_title(inspected_building_id),due,points,offer["share"]+points]
	equity_dialog.popup_centered(Vector2i(430,200))


# 成交模块：先校验再划款，交易结束立即更新库款和详情。
func _confirm_equity() -> void:
	var filled: bool = Works.invest(world,equity_order["id"],equity_order["points"],equity_order["offer"])
	equity_order.clear()
	status_label.text = "交易成功，日结按新持股比例划拨净利" if filled else "交易未完成：报价或资金已变更，请重新确认"
	_refresh()


# 详情刷新模块：施工、暂停、岗位和读档后始终从当前世界重算显示及按钮状态。
func _refresh_inspection() -> void:
	if inspection_label == null:
		return
	var detail: Dictionary = Inspector.describe(world, inspected_building_id)
	var selected: Dictionary = Inspector.find(world,inspected_building_id)
	if world.capital_layout and selected.get("state")=="constructing":
		detail["text"]+="\n"+TownMap.BuildArt.phase(selected)
	var site: Dictionary = town_map.site_buildings.get(town_map.inspected_building_id, {})
	var landmark: Dictionary = town_map.capital_buildings.get(town_map.inspected_building_id, {})
	if not landmark.is_empty():
		detail["text"] = "%s ｜ 首府\n%s" % [landmark["title"], landmark["description"]]
		var scale: Vector2i = landmark["size"]
		detail["numbers"]["size"] = "%d × %d" % [scale.x, scale.y]
	var owner: int = world.household_economy.get("property", {}).get(inspected_building_id,world.royal_works["homes"].get(inspected_building_id,-1))
	if owner >= 0:
		var property: Dictionary = Inspector.find(world, inspected_building_id)
		var extent: Vector2i = Construction.Catalog.footprint(property)
		var held: int = world.royal_works["shares"].get(inspected_building_id,0)
		var title: String = "%s私产" % world.household_name(owner)
		if held>0:
			title = "皇家全资" if held==100 else "皇家与%s共同持有" % world.household_name(owner)
		if property["state"]=="constructing":
			detail["text"]="%s ｜ %s\n%s" % [town_map.building_title(inspected_building_id),title,TownMap.BuildArt.phase(property)]
		else:
			detail = {"text": "%s ｜ %s" % [town_map.building_title(inspected_building_id),title],
				"numbers":{"size":"%d × %d" % [extent.x,extent.y]},"increase":false,"decrease":false}
	if not site.is_empty():
		var region: Dictionary = RegionOverview.LAYOUT.regions[site["region"]]
		detail["text"] = "%s ｜ %s\n据点设施" % [site["title"], region["title"]]
		var footprint: Vector2i = site["size"]
		detail["numbers"]["size"] = "%d × %d" % [footprint.x, footprint.y]
	inspection_label.text = detail["text"]
	for key: String in ["level", "size", "progress", "queue", "builders", "jobs", "rate", "credit", "housing", "capacity"]:
		var metric: String = "building_" + key
		var label: Label = numbers[metric]
		label.get_parent().get_parent().get_parent().visible = detail["numbers"].has(key)
		if detail["numbers"].has(key):
			_set_numbers({metric: detail["numbers"][key]})
	inspection_increase.disabled = not detail["increase"]
	inspection_decrease.disabled = not detail["decrease"]
	inspection_increase.get_parent().visible = bool(detail.get("producer", false))
	var record: Dictionary = Inspector.find(world, inspected_building_id)
	if resident_card != null:
		_refresh_residence_card(record)
	var estate_producer: bool = world.estate_workers > 0 and bool(detail.get("producer", false))
	estate_producer_add.get_parent().visible = estate_producer
	if estate_producer:
		var definition: Resource = Construction.Catalog.find(record["def_id"])
		estate_producer_add.disabled = world.estate_idle() == 0 or int(record["workers"]) >= int(definition.get("worker_slots"))
		estate_producer_remove.disabled = int(world.estate_posts.get(inspected_building_id, 0)) == 0
	site_builder_actions.visible = record.get("state")=="constructing" and world.builder_owner(record)==-1
	var plot: Dictionary = world.chancery["fields"].get(inspected_building_id,{})
	field_card.visible=not plot.is_empty()
	if field_card.visible:
		inspection_label.text=town_map.building_title(inspected_building_id)
		if record.get("state")=="constructing":
			inspection_label.text+=" · "+TownMap.BuildArt.phase(record)
		var harvest: int = plot["yield"]
		var nominal: int = floori(plot["acres"]*State.Rural.CROP_FACTORS[plot["crop"]])
		field_card.text="作物  %s   ·   地籍  %d亩\n上次日结产量  %s\n满耕参考  %d粮／日" % [State.Book.CROPS[plot["crop"]],plot["acres"],"%d粮" % harvest if harvest>=0 else "待首次收成",nominal]
	_refresh_asset()
	if asset_card.visible:
		numbers["building_size"].get_parent().get_parent().get_parent().hide()
	inspection_remove.visible = owner < 0 and not record.is_empty() and not Works.is_contract(world,record) and record["def_id"] not in ["b_hall", "b_market"]
	inspection_remove.text = "取消施工" if record.get("state") == "constructing" else "拆除建筑"
	var military: bool = record.get("def_id") == "b_barracks"
	army_recruit_button.get_parent().visible = military
	barracks_stats.visible = military
	barracks_notice.hide()
	if military:
		var offer: Dictionary = Army.quote(world, inspected_building_id)
		army_recruit_button.disabled = not offer["ok"]
		var used: Dictionary = Army.stationed(world.troops, inspected_building_id)
		_set_numbers({
			"barracks_people": "%d / %d" % [used["count"], Army.UNIT.barracks_capacity], "batch_size": Army.UNIT.batch_size,
			"batch_gold": Army.UNIT.recruit_cost.get("gold", 0), "batch_wood": Army.UNIT.recruit_cost.get("wood", 0),
			"batch_time": "%d 战略秒" % Army.UNIT.train_work,
			"batch_workers_after": world.idle_workers() - int(Army.UNIT.batch_size) if world.idle_workers() >= int(Army.UNIT.batch_size) else "兵源不足",
		})
		barracks_notice.visible = not offer["ok"]
		barracks_notice.text = str(offer.get("reason", ""))
	_refresh_army_lifecycle(military)


# 清理模块：读档或进入建造模式时清除临时选择，不让相同ID误指向新世界建筑。
func _clear_inspection() -> void:
	inspected_building_id = ""
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
	_set_numbers({"satisfaction": "%d / 100" % world.satisfaction, "forecast": forecast})
	for policy: String in tax_buttons:
		tax_buttons[policy].disabled = policy == world.tax_policy


# 招募入口模块：每次明确操作生成新命令，由军队服务校验费用、兵源和军营编额。
func _recruit_infantry() -> void:
	var command: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var result: Dictionary = Army.recruit(world, inspected_building_id, command)
	status_label.text = "已征募%d人，进入训练；扣金币%d、木材%d，请保存" % [Army.UNIT.batch_size, Army.UNIT.recruit_cost.get("gold", 0), Army.UNIT.recruit_cost.get("wood", 0)] if result["ok"] else str(result["reason"])
	_refresh()


# 军事面板模块：显示现役、训练、当前士气及上次军需结算造成的士气变化。
func _refresh_army() -> void:
	var ready: int = Army.people(world.troops, false, true)
	var training: int = Army.people(world.troops) - ready
	var ration: int = world.retired_army_cost["ration_credit"]
	var wages: int = world.retired_army_cost["wage_credit"]
	retired_cost.visible = ration > 0 or wages > 0
	_set_numbers({
		"soldiers": ready, "training": training,
		"army_morale": "—" if world.troops.is_empty() else "%d / %d" % [world.army_morale, Army.Morale.MAXIMUM],
		"retired_food": "%.2f" % (ration / float(State.DAY_TICKS)),
		"retired_pay": "%.2f" % (wages / float(State.DAY_TICKS)),
	})


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
				army_troop_picker.add_icon_item(HudIcons.texture("shield"), "步兵批次 %s · %s" % [str(troop["id"]).trim_prefix("troop_"), "训练中" if troop["state"] == "training" else "现役"])
				var index: int = army_troop_picker.item_count - 1
				army_troop_picker.set_item_metadata(index, troop["id"])
				if troop["id"] == selected:
					army_troop_picker.select(index)
		army_picker_signature = signature
	army_troop_picker.get_parent().visible = army_troop_picker.item_count > 0
	if army_troop_picker.selected >= 0:
		var troop: Dictionary = ArmyDisband.find(world, str(army_troop_picker.get_item_metadata(army_troop_picker.selected)))
		var training: bool = troop.get("state") == "training"
		_set_numbers({
			"batch_people": troop["count"],
			"batch_progress": "%d%%" % floori(100.0 * troop["work_done"] / troop["work_required"]) if training else "已完成",
		})
		army_disband_button.text = "取消这批训练" if training else "解散这批部队"


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
	legion_toggle.icon = HudIcons.texture("shield")
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
	legion_stats = _number_grid(legion_body, "所选军团", [
		["legion_size", "兵力 / 上限", "shield"], ["legion_batches", "来源批次", "people"],
		["legion_ration", "每日军粮", "food"], ["legion_wage", "每日军饷", "gold"],
	], 2)
	legion_stats.tooltip_text = "每日军粮与军饷已计入全军维护"
	legion_troop_picker = OptionButton.new()
	legion_body.add_child(legion_troop_picker)
	legion_troop_picker.item_selected.connect(func(_index: int) -> void: _update_legion_amount())
	legion_allocation = _number_grid(legion_body, "批次分配", [
		["legion_current", "本团人数", "people"], ["legion_maximum", "可设上限", "shield"],
	], 2)
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
			legion_picker.add_icon_item(HudIcons.texture("shield"), legion["name"])
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
				legion_troop_picker.add_icon_item(HudIcons.texture("shield"), "步兵批次 " + str(troop["id"]).trim_prefix("troop_"))
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
	legion_stats.visible = not selected.is_empty()
	legion_detail.visible = selected.is_empty()
	legion_detail.text = "新建军团后可编入现役士兵。"
	if not selected.is_empty():
		var count: int = Legions.people(selected)
		_set_numbers({
			"legion_size": "%d / %d" % [count, Legions.SETTINGS.people_capacity],
			"legion_batches": selected["members"].size(),
			"legion_ration": count * int(Army.UNIT.food_per_day), "legion_wage": count * int(Army.UNIT.wage_per_day),
		})
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
	legion_allocation.visible = legion_people.editable
	_set_numbers({"legion_current": current, "legion_maximum": maximum})
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
