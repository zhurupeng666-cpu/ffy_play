## 文件用途：绘制区域道路、选择可见地区并提供城镇进入按钮。
extends VBoxContainer

signal town_requested
const LAYOUT = preload("res://data/regions/frontier.tres")

# 视图模块：只保存当前选择，所有地区数据取自区域配置。
var selected_id: String = ""
var markers: Dictionary = {}
var board: Control
var detail: Label
var enter_button: Button

# 界面模块：建立路线画布、区域标记和随选择切换的详情。
func _ready() -> void:
	var title: Label = Label.new()
	title.text = "边境区域总览"
	add_child(title)
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
		var marker: Button = Button.new()
		marker.text = "%s\n%s" % [region["title"], _status(region)]
		marker.custom_minimum_size = Vector2(110, 54)
		marker.toggle_mode = true
		marker.focus_mode = Control.FOCUS_NONE
		marker.pressed.connect(select_region.bind(id))
		board.add_child(marker)
		markers[id] = marker
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 64
	add_child(detail)
	enter_button = Button.new()
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.text = "进入边境镇"
	enter_button.pressed.connect(_enter_region)
	add_child(enter_button)
	select_region(LAYOUT.home_id)
	_place_markers()

# 状态模块：用可见性、归属和通行权给区域标注简明状态。
func _status(region: Dictionary) -> String:
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
	detail.text = "%s ｜ %s\n%s" % [region["title"], _status(region), region["description"]]
	enter_button.disabled = id != LAYOUT.home_id or region["access"] != "open"
	enter_button.text = "未开放" if enter_button.disabled else "进入边境镇"

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
