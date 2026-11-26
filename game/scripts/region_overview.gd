## 文件用途：以同一张世界地图为底图，标注区域名称、道路和据点入口。
extends VBoxContainer

signal town_requested
signal site_requested(cell: Vector2i)
const TownMap = preload("res://scripts/town_map.gd")
const Battle = preload("res://scripts/woods_battle.gd")
const Siege = preload("res://scripts/fort_siege.gd")
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const LAYOUT = Scout.LAYOUT
const DAY_TICKS: int = preload("res://scripts/world_state.gd").DAY_TICKS

# 视图模块：只保存当前选择，所有地区数据取自区域配置。
var selected_id: String = ""
var markers: Dictionary = {}
var board: Control
var map_overlay: Control
var site_button: Button
var detail: Label
var enter_button: Button
# 侦察控件模块：世界状态由主界面绑定，选择项和布局留在视图。
var world: RefCounted
var scout_shortcut: Button
var scout_row: HBoxContainer
var scout_picker: OptionButton
var scout_button: Button
var march_button: Button
var battle_button: Button
var legion_labels: Dictionary = {}

# 界面模块：建立路线画布、区域标记和随选择切换的详情。
func _ready() -> void:
	var heading: HBoxContainer = HBoxContainer.new()
	add_child(heading)
	var title: Label = Label.new()
	title.text = "边境区域总览"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	scout_shortcut = Button.new()
	scout_shortcut.focus_mode = Control.FOCUS_NONE
	scout_shortcut.text = "林地侦察"
	scout_shortcut.pressed.connect(select_region.bind(Scout.WOODS))
	heading.add_child(scout_shortcut)
	board = Control.new()
	board.custom_minimum_size = Vector2(320, 220)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(board)
	board.clip_contents = true
	map_overlay = TownMap.new()
	map_overlay.overview_only = true
	map_overlay.show_behind_parent = true
	board.add_child(map_overlay)
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_overlay.show_entire_map()
	map_overlay.view_changed.connect(_place_markers)
	board.draw.connect(_draw_board)
	board.resized.connect(_place_markers)
	for id: String in LAYOUT.regions:
		var region: Dictionary = LAYOUT.regions[id]
		if region["visibility"] == "hidden":
			continue
		_add_marker(id)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 44
	add_child(detail)
	enter_button = Button.new()
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.text = "进入边境镇"
	enter_button.pressed.connect(_enter_region)
	add_child(enter_button)
	site_button = Button.new()
	site_button.focus_mode = Control.FOCUS_NONE
	site_button.text = "查看据点"
	site_button.pressed.connect(_view_site)
	add_child(site_button)
	scout_row = HBoxContainer.new()
	add_child(scout_row)
	scout_picker = OptionButton.new()
	scout_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scout_picker.focus_mode = Control.FOCUS_NONE
	scout_picker.item_selected.connect(_on_scout_legion_selected)
	scout_row.add_child(scout_picker)
	scout_button = Button.new()
	scout_button.focus_mode = Control.FOCUS_NONE
	scout_button.text = "派遣侦察（粮食 %d）" % LAYOUT.scout_food
	scout_button.pressed.connect(_dispatch_scout)
	scout_row.add_child(scout_button)
	march_button = Button.new()
	march_button.focus_mode = Control.FOCUS_NONE
	march_button.pressed.connect(_dispatch_march)
	scout_row.add_child(march_button)
	march_button.hide()
	battle_button = Button.new()
	battle_button.focus_mode = Control.FOCUS_NONE
	battle_button.pressed.connect(_start_battle)
	scout_row.add_child(battle_button)
	battle_button.hide()
	# 操作区放在地图上方，方便直接查看和派遣。
	move_child(detail, 1)
	move_child(enter_button, 2)
	move_child(site_button, 3)
	move_child(scout_row, 4)
	scout_row.hide()
	select_region(LAYOUT.home_id)
	_place_markers()

# 标记模块：只为已知区域创建可点击的地图节点。
func _add_marker(id: String) -> void:
	var marker: Button = Button.new()
	marker.custom_minimum_size = Vector2(98, 36)
	marker.toggle_mode = true
	marker.focus_mode = Control.FOCUS_NONE
	marker.pressed.connect(select_region.bind(id))
	board.add_child(marker)
	markers[id] = marker
	_update_marker(id)

# 标注模块：选择和完成状态改变时更新对应区域名称。
func _update_marker(id: String) -> void:
	markers[id].text = LAYOUT.regions[id]["title"]
	markers[id].tooltip_text = _status(id)

# 状态模块：合并静态地图状态和侦察结果。
func _status(id: String) -> String:
	var region: Dictionary = LAYOUT.regions[id]
	if world != null:
		if id == Scout.FORT:
			var status: String = Siege.report(world)["status"]
			if status == "victory":
				return "己方控制"
			if status == "running":
				return "攻城中"
			return "道路开放" if March.fort_access(world) else "已发现 · 未开放"
		if id == Scout.WOODS:
			if Battle.report(world)["status"] == "victory":
				return "己方控制"
			if Scout.complete(world):
				return "已侦察 · 未占领"
			if Scout.busy(world):
				return "侦察中"
	if region["owner"] == "player" and region["access"] == "open":
		return "己方 · 开放"
	if region["visibility"] == "known":
		return "已知 · 待侦察"
	return "暂未开放"

# 选区模块：遮蔽未发现区域，显示可见区域的当前状态和开放条件。
func select_region(id: String) -> void:
	if not markers.has(id):
		return
	selected_id = id
	board.queue_redraw()
	var region: Dictionary = LAYOUT.regions[id]
	for marker_id: String in markers:
		markers[marker_id].set_pressed_no_signal(marker_id == id)
	detail.text = "%s ｜ %s\n%s" % [region["title"], _status(id), region["description"]]
	enter_button.visible = id == LAYOUT.home_id
	enter_button.disabled = id != LAYOUT.home_id or region["access"] != "open"
	enter_button.text = "未开放" if enter_button.disabled else "进入边境镇"
	site_button.visible = id != LAYOUT.home_id and world != null and Scout.complete(world)
	if id == Scout.FORT:
		_refresh_fort()
	else:
		_refresh_scout()

# 世界同步模块：发现旧堡时显示标记与道路，读入较早进度时恢复对应地图。
func sync(state: RefCounted) -> void:
	world = state
	map_overlay.sync_capital(world.capital_layout, world.population)
	map_overlay.sync_buildings(world.buildings)
	map_overlay.sync_region_sites(world)
	var discovered: bool = Scout.complete(world)
	if discovered != markers.has(Scout.FORT):
		if discovered:
			_add_marker(Scout.FORT)
		else:
			var marker: Button = markers[Scout.FORT]
			marker.hide()
			marker.queue_free()
			markers.erase(Scout.FORT)
			if selected_id == Scout.FORT:
				selected_id = LAYOUT.home_id
		_place_markers()
	_update_marker(Scout.WOODS)
	if discovered:
		_update_marker(Scout.FORT)
	select_region(selected_id)

# 状态模块：按战略剩余时间显示进度，到期后显示已揭示区域。
func _refresh_scout() -> void:
	scout_row.visible = world != null and selected_id == Scout.WOODS
	if world == null or selected_id != Scout.WOODS:
		return
	var discovered: bool = Scout.complete(world)
	scout_picker.visible = not Scout.busy(world)
	scout_button.visible = not discovered
	march_button.visible = discovered
	battle_button.visible = discovered
	if Scout.busy(world):
		scout_button.disabled = true
		scout_button.text = "侦察进行中"
		var remaining: int = int(world.woods_scout["arrives"]) - world.tick
		detail.text = "北部林地 ｜ 侦察中\n还需 %d 战略秒。军团归队后揭示侦察结果。" % remaining
	elif Scout.complete(world):
		scout_button.disabled = true
		scout_button.text = "侦察已完成"
		_refresh_march()
	else:
		_update_scout_picker()
		var id: String = _selected_legion()
		var blocked: String = Scout.reason(world, id)
		scout_button.text = "派遣侦察（粮食 %d）" % LAYOUT.scout_food
		scout_button.disabled = not blocked.is_empty()
		var hint: String = blocked if not blocked.is_empty() else "耗时 %d 战略秒" % LAYOUT.scout_ticks
		detail.text += "\n" + hint

# 旧堡面板：展示军团通行、攻城阶段与旧堡归属。
func _refresh_fort() -> void:
	scout_row.visible = world != null
	scout_button.hide()
	battle_button.hide()
	scout_picker.show()
	march_button.show()
	if world == null:
		return
	_update_scout_picker()
	var id: String = _selected_legion()
	var target: String = _march_target(id)
	var remaining: int = March.remaining(world, id)
	var location: String = LAYOUT.regions[March.destination(world, id)]["title"]
	var blocked: String = March.reason(world, id, target)
	var siege: Dictionary = Siege.report(world)
	var status: String = siege["status"]
	battle_button.visible = March.fort_access(world) and status != "victory"
	battle_button.disabled = not Siege.reason(world, id, status).is_empty()
	battle_button.text = "攻城中" if status == "running" else "发起攻城"
	march_button.text = "返回北部林地" if target == Scout.WOODS else "前往旧堡"
	march_button.disabled = not blocked.is_empty()
	if not March.fort_access(world):
		detail.text = "旧堡 ｜ 道路未开放\n需先取得北部林地控制权。"
	elif remaining > 0:
		detail.text = "旧堡 ｜ 道路开放\n前往%s，剩余 %s。" % [location, _march_time(remaining)]
	elif location == LAYOUT.regions[Scout.FORT]["title"]:
		detail.text = "旧堡 ｜ 军团已抵达堡外\n可沿原路返回北部林地。"
	else:
		detail.text = "旧堡 ｜ 道路开放\n军团驻地为%s。请从北部林地出发，单程 %s。" % [location, _march_time(LAYOUT.march_ticks)]
		if not blocked.is_empty():
			detail.text += "\n" + blocked
	detail.text += _siege_summary(siege)

# 行军面板：根据军团的路程与驻地显示下一条可执行的命令。
func _refresh_march() -> void:
	_update_scout_picker()
	var id: String = _selected_legion()
	var target: String = _march_target(id)
	var remaining: int = March.remaining(world, id)
	var location: String = LAYOUT.regions[March.destination(world, id)]["title"]
	var report: Dictionary = Battle.report(world)
	var briefing: String = "北部林地 ｜ 己方控制" if report["status"] == "victory" else "北部林地 ｜ 已侦察 · 未占领"
	_refresh_battle(id, report)
	if remaining > 0:
		march_button.text = "行军中"
		march_button.disabled = true
		detail.text = "%s\n前往%s，剩余 %s。" % [briefing, location, _march_time(remaining)] + _battle_summary(report)
		return
	march_button.text = "调回边境镇" if target == LAYOUT.home_id else "前往北部林地"
	var blocked: String = March.reason(world, id, target)
	march_button.disabled = not blocked.is_empty()
	if not blocked.is_empty():
		detail.text = briefing + "\n" + blocked + _battle_summary(report)
	else:
		detail.text = "%s\n军团驻地为%s。单程 %s。" % [briefing, location, _march_time(LAYOUT.march_ticks)] + _battle_summary(report)

# 行军时间：按游戏日与小时显示，抵达前至少显示一小时。
func _march_time(ticks: int) -> String:
	var hours: int = ceili(ticks * 24.0 / DAY_TICKS)
	var days: int = floori(hours / 24.0)
	var remainder: int = hours % 24
	if days == 0:
		return "%d 小时" % remainder
	return "%d 天" % days if remainder == 0 else "%d 天 %d 小时" % [days, remainder]


# 遭遇指令：派驻林地的军团可迎战，开战后暂停调动参战军团。
func _refresh_battle(legion_id: String, report: Dictionary) -> void:
	var status: String = report["status"]
	battle_button.visible = status != "victory"
	battle_button.disabled = not Battle.reason(world, legion_id, status).is_empty()
	battle_button.text = "交战中" if status == "running" else "迎战守军"

# 战况反馈：显示双方剩余战力、结果和胜利后的控制权。
func _battle_summary(report: Dictionary) -> String:
	match report["status"]:
		"running":
			return "\n自动交战中　己方战力 %d　守军战力 %d" % [report["allies"], report["enemies"]]
		"victory":
			return "\n林地上缴木材 +%d/日，从占领后的首个完整日结算。" % LAYOUT.woods_wood_per_day
		"defeat":
			return "\n战斗失利。可调回城镇整编，再派军团迎战。"
	return "\n林地有 %d 名守军。" % LAYOUT.woods_guards

# 旧堡战况：分阶段显示城门与守军，结束后显示胜败和控制权。
func _siege_summary(siege: Dictionary) -> String:
	match siege["status"]:
		"running":
			var stage: String = "攻击城门" if int(siege["gate"]) > 0 else "城门已破，迎战守军"
			return "\n%s ｜ 城门 %d ｜ 己方战力 %d ｜ 守军战力 %d" % [stage, siege["gate"], siege["allies"], siege["enemies"]]
		"victory":
			return "\n旧堡已由己方控制。每个完整战略日上缴金币 %d。" % LAYOUT.fort_gold_per_day
		"defeat":
			return "\n攻城失利。可以再次攻城，或返回林地。"
	return ""

# 开战入口：按选区发出战斗请求，由对应规则复查军团驻地。
func _start_battle() -> void:
	if world == null or not is_visible_in_tree():
		return
	if selected_id == Scout.WOODS:
		Battle.start(world, _selected_legion())
	elif selected_id == Scout.FORT:
		Siege.start(world, _selected_legion())
	sync(world)

# 路线选择：林地视图负责回城与回林地，旧堡视图负责林地到堡外。
func _march_target(legion_id: String) -> String:
	var origin: String = March.destination(world, legion_id)
	if selected_id == Scout.FORT:
		return Scout.WOODS if origin == Scout.FORT else Scout.FORT
	return LAYOUT.home_id if origin == Scout.WOODS else Scout.WOODS

# 命令入口：在林地或旧堡界面处理请求，由服务层复查路线。
func _dispatch_march() -> void:
	if world != null and is_visible_in_tree() and selected_id in [Scout.WOODS, Scout.FORT]:
		var id: String = _selected_legion()
		March.dispatch(world, id, _march_target(id))
		sync(world)

# 名单模块：编制变化才重建选项，保留仍可用的军团选择。
func _update_scout_picker() -> void:
	var current: Dictionary = {}
	for legion: Dictionary in world.legions:
		if legion["state"] == "active" and not legion["members"].is_empty():
			var people: int = 0
			for member: Dictionary in legion["members"]:
				people += int(member["count"])
			current[legion["id"]] = "%s · %d人" % [legion["name"], people]
	if current == legion_labels and scout_picker.item_count > 0:
		return
	var previous: String = _selected_legion()
	legion_labels = current
	scout_picker.clear()
	for id: String in current:
		scout_picker.add_item(current[id])
		var index: int = scout_picker.item_count - 1
		scout_picker.set_item_metadata(index, id)
		if id == previous:
			scout_picker.select(index)
	scout_picker.disabled = current.is_empty()
	if current.is_empty():
		scout_picker.add_item("暂无可派遣军团")
		scout_picker.set_item_metadata(0, "")

# 取值模块：空队列或占位项返回空 ID，交由规则模块判断。
func _selected_legion() -> String:
	if scout_picker.selected < 0:
		return ""
	return str(scout_picker.get_item_metadata(scout_picker.selected))

# 选择模块：即时刷新派遣条件和按钮状态。
func _on_scout_legion_selected(_index: int) -> void:
	select_region(selected_id)

# 派遣入口模块：地图关闭或切到其他地区后，不再响应派遣操作。
func _dispatch_scout() -> void:
	if world != null and is_visible_in_tree() and selected_id == Scout.WOODS:
		Scout.dispatch(world, _selected_legion())
		sync(world)

# 进入模块：只接受配置为开放的主城，避免绕过界面禁用状态。
func _enter_region() -> void:
	if selected_id == LAYOUT.home_id and LAYOUT.regions[selected_id]["access"] == "open":
		town_requested.emit()

# 布局模块：标记与道路共用坐标，缩放窗口时连接点保持对齐。
func _place_markers() -> void:
	for id: String in markers:
		var marker: Button = markers[id]
		marker.size = marker.get_combined_minimum_size()
		var point: Vector2 = _point(id)
		var offset := Vector2(-72, -28)
		if id == Scout.WOODS:
			offset = Vector2(60, -22)
		elif id == Scout.FORT:
			offset = Vector2(-64, -2)
		var limit: Vector2 = (board.size - marker.size - Vector2(5, 5)).max(Vector2(5, 5))
		marker.position = (point + offset - marker.size * 0.5).clamp(Vector2(5, 5), limit)
	board.queue_redraw()

# 据点入口：只开放已侦察位置的局部视角。
func _view_site() -> void:
	if world != null and selected_id != LAYOUT.home_id and Scout.complete(world):
		site_requested.emit(LAYOUT.regions[selected_id]["position"])


# 位置投影：区域名称使用真实格网锚点，并与底图同步缩放。
func _point(id: String) -> Vector2:
	var cell: Vector2i = LAYOUT.regions[id]["position"]
	return map_overlay.world_to_screen(TownMap.Grid.cell_to_world(cell))


# 路线与地标：在地形上方描出已发现路径和每个区域的地面位置。
func _draw_board() -> void:
	for road: PackedStringArray in LAYOUT.roads:
		if markers.has(road[0]) and markers.has(road[1]):
			board.draw_dashed_line(_point(road[0]), _point(road[1]), Color("#292b22df"), 5.0, 9.0)
			board.draw_dashed_line(_point(road[0]), _point(road[1]), Color("#e3c88b"), 2.0, 9.0)
	for id: String in markers:
		var marker: Button = markers[id]
		var anchor: Vector2 = _point(id)
		var pin: Color = Color("#fff1b7") if id == selected_id else Color("#e3c88b")
		var label_edge: Vector2 = anchor.clamp(marker.position, marker.position + marker.size)
		board.draw_line(anchor, label_edge, pin, 1.0, true)
		board.draw_circle(anchor, 5.0, Color("#263126"))
		board.draw_circle(anchor, 3.0, pin)
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color("#52604d"), false, 1.0)
