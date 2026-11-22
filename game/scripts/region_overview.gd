## 文件用途：绘制区域道路与侦察进度，提供军团派遣和城镇入口。
extends VBoxContainer

signal town_requested
const Battle = preload("res://scripts/woods_battle.gd")
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const LAYOUT = Scout.LAYOUT

# 视图模块：只保存当前选择，所有地区数据取自区域配置。
var selected_id: String = ""
var markers: Dictionary = {}
var board: Control
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
	board.draw.connect(_draw_board)
	board.resized.connect(_place_markers)
	for id: String in LAYOUT.regions:
		var region: Dictionary = LAYOUT.regions[id]
		if region["visibility"] == "hidden":
			continue
		_add_marker(id)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 64
	add_child(detail)
	enter_button = Button.new()
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.text = "进入边境镇"
	enter_button.pressed.connect(_enter_region)
	add_child(enter_button)
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
	move_child(scout_row, 3)
	scout_row.hide()
	select_region(LAYOUT.home_id)
	_place_markers()

# 标记模块：只为已知区域创建可点击的地图节点。
func _add_marker(id: String) -> void:
	var marker: Button = Button.new()
	marker.custom_minimum_size = Vector2(110, 54)
	marker.toggle_mode = true
	marker.focus_mode = Control.FOCUS_NONE
	marker.pressed.connect(select_region.bind(id))
	board.add_child(marker)
	markers[id] = marker
	_update_marker(id)

# 标注模块：选择和完成状态改变时更新对应区域名称。
func _update_marker(id: String) -> void:
	markers[id].text = "%s\n%s" % [LAYOUT.regions[id]["title"], _status(id)]

# 状态模块：合并静态地图状态和侦察结果。
func _status(id: String) -> String:
	var region: Dictionary = LAYOUT.regions[id]
	if world != null:
		if id == Scout.FORT:
			return "已发现 · 待进军" if Battle.report(world)["status"] == "victory" else "已发现 · 未开放"
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
	var region: Dictionary = LAYOUT.regions[id]
	for marker_id: String in markers:
		markers[marker_id].set_pressed_no_signal(marker_id == id)
	detail.text = "%s ｜ %s\n%s" % [region["title"], _status(id), region["description"]]
	if id == Scout.FORT and world != null and Battle.report(world)["status"] == "victory":
		detail.text = "旧堡 ｜ 已发现 · 待进军\n林地已由己方控制。旧堡是下一处进军目标。"
	enter_button.visible = id != Scout.WOODS
	enter_button.disabled = id != LAYOUT.home_id or region["access"] != "open"
	enter_button.text = "未开放" if enter_button.disabled else "进入边境镇"
	_refresh_scout()

# 世界同步模块：发现旧堡时显示标记与道路，读入较早进度时恢复对应地图。
func sync(state: RefCounted) -> void:
	world = state
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
		detail.text = "%s\n前往%s，剩余 %d 战略秒。" % [briefing, location, remaining] + _battle_summary(report)
		return
	march_button.text = "调回边境镇" if target == LAYOUT.home_id else "前往北部林地"
	var blocked: String = March.reason(world, id, target)
	march_button.disabled = not blocked.is_empty()
	if not blocked.is_empty():
		detail.text = briefing + "\n" + blocked + _battle_summary(report)
	else:
		detail.text = "%s\n军团驻地为%s。单程 %d 战略秒。" % [briefing, location, LAYOUT.march_ticks] + _battle_summary(report)

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
			return "\n战斗胜利，北部林地已由己方控制。"
		"defeat":
			return "\n战斗失利。可调回城镇整编，再派军团迎战。"
	return "\n林地有 %d 名守军。" % LAYOUT.woods_guards

# 开战入口：只在林地视图请求遭遇战，规则层重新验证驻地。
func _start_battle() -> void:
	if world != null and is_visible_in_tree() and selected_id == Scout.WOODS:
		Battle.start(world, _selected_legion())
		sync(world)

# 路线选择：驻扎林地时可以返回主城，否则可从主城前往林地。
func _march_target(legion_id: String) -> String:
	return LAYOUT.home_id if March.destination(world, legion_id) == Scout.WOODS else Scout.WOODS

# 命令入口：只在林地界面处理请求，服务层再次检查可达性。
func _dispatch_march() -> void:
	if world != null and is_visible_in_tree() and selected_id == Scout.WOODS:
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
		marker.position = _point(id) - marker.size * 0.5
	board.queue_redraw()

# 坐标模块：留出标记宽度与边缘空间。
func _point(id: String) -> Vector2:
	var inset: Vector2 = Vector2(66, 33)
	return inset + (board.size - inset * 2.0) * Vector2(LAYOUT.regions[id]["position"])

# 绘制模块：仅显示两端都已发现的道路，背景格线帮助辨认相对位置。
func _draw_board() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color("#252d27"))
	for x: int in range(24, int(board.size.x), 24):
		board.draw_line(Vector2(x, 0), Vector2(x, board.size.y), Color("#303b33"))
	for y: int in range(24, int(board.size.y), 24):
		board.draw_line(Vector2(0, y), Vector2(board.size.x, y), Color("#303b33"))
	for road: PackedStringArray in LAYOUT.roads:
		if markers.has(road[0]) and markers.has(road[1]):
			board.draw_line(_point(road[0]), _point(road[1]), Color("#b09c66"), 4.0)
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color("#52604d"), false, 1.0)
