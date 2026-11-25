## 文件用途：绘制伐木场、采石场、渔场的设施和在岗工人，只接收视图数据。
extends "res://scripts/town_art.gd"

const TYPES: Array[String] = ["b_lumber", "b_quarry", "b_fishery"]


# 作业区入口：按用途绘制成套设施，所有落地点以场地中心为原点。
static func draw_site(canvas: Control, id: String, center: Vector2) -> void:
	match id:
		"b_lumber":
			_lumberyard(canvas, center)
		"b_quarry":
			_quarry(canvas, center)
		"b_fishery":
			_fishery(canvas, center)


# 场地坐标：将格网轴上的小数位置换算成等距世界像素。
static func _tile(x: float, y: float) -> Vector2:
	return Vector2((x - y) * Grid.HALF.x, (x + y) * Grid.HALF.y)


# 铺地模块：用等距长方形划出道路、操作台和功能区。
static func _deck(canvas: Control, at: Vector2, width: float, depth: float, surface: Color, edge: Color) -> void:
	var corners: Array = [_tile(-width, -depth), _tile(width, -depth), _tile(width, depth), _tile(-width, depth)]
	_poly(canvas, at, corners, surface)
	_stroke(canvas, at, corners[1], corners[2], edge, 3.0)
	_stroke(canvas, at, corners[2], corners[3], edge, 3.0)


# 伐木场模块：大型锯木棚朝向操作坪，分设原木堆、锯架和成材装车位。
static func _lumberyard(canvas: Control, center: Vector2) -> void:
	_deck(canvas, center + Vector2(0, 8), 1.19, 1.17, Color("#90764c"), Color("#564632"))
	_house(canvas, center + Vector2(-19, -14), 36, 22, Color("#536f43"), Color("#b88c60"), "timber", 1.75)
	_log_stack(canvas, center + Vector2(22, -3))
	_log_stack(canvas, center + Vector2(46, 12))
	_saw_frame(canvas, center + Vector2(-31, 16))
	_stroke(canvas, center + Vector2(-10, 25), Vector2(-13, 1), Vector2(14, -10), Color("#ca9e61"), 7.0)
	_cart(canvas, center + Vector2(26, 22), Color("#aa7a4b"))


# 原木模块：双层堆垛画出树皮、断面和年轮。
static func _log_stack(canvas: Control, at: Vector2) -> void:
	for p: Vector2 in [Vector2(-8, 3), Vector2(0, 6), Vector2(8, 9), Vector2(-3, -2), Vector2(5, 1)]:
		var end: Vector2 = at + p
		_stroke(canvas, end, Vector2(1, -1), Vector2(27, -13), Color("#583c2a"), 8)
		_stroke(canvas, end, Vector2(1, -3), Vector2(27, -15), Color("#987149"), 4)
		_poly(canvas, end, [Vector2(-4, 0), Vector2(0, -5), Vector2(5, -3), Vector2(5, 2), Vector2(0, 4)], Color("#d9ac72"))
		_pixel(canvas, end, Vector2(0, -2), Vector2(2, 3), Color("#947052"))


# 锯架模块：横木、支架和亮色锯片形成可辨识的作业台。
static func _saw_frame(canvas: Control, at: Vector2) -> void:
	for x: float in [-14.0, 10.0]:
		_stroke(canvas, at, Vector2(x - 4, 7), Vector2(x, -9), Color("#5e4230"), 4)
		_stroke(canvas, at, Vector2(x + 4, 8), Vector2(x, -9), Color("#8b6040"), 3)
	_stroke(canvas, at, Vector2(-22, -4), Vector2(17, -16), Color("#d6a565"), 7)
	_stroke(canvas, at, Vector2(-12, -14), Vector2(8, -7), Color("#cdd4c7"), 3)
	_pixel(canvas, at, Vector2(-16, -16), Vector2(6, 4), Color("#453128"))


# 采石场模块：工棚结合吊装机、切石平台、方石堆和运石车。
static func _quarry(canvas: Control, center: Vector2) -> void:
	_deck(canvas, center + Vector2(0, 6), 1.22, 1.22, Color("#888272"), Color("#584f48"))
	_house(canvas, center + Vector2(-20, -16), 35, 24, Color("#637775"), Color("#bcb3a0"), "stone", 1.75)
	_crane(canvas, center + Vector2(35, 4))
	_deck(canvas, center + Vector2(-23, 18), 0.48, 0.38, Color("#b3a48d"), Color("#655d50"))
	for p: Vector2 in [Vector2(-37, 17), Vector2(-14, 21), Vector2(-26, 25), Vector2(44, 16), Vector2(52, 21)]:
		_stone_block(canvas, center + p)
	_cart(canvas, center + Vector2(18, 28), Color("#b5aa91"))


# 吊装机模块：高架、斜撑、滑轮和吊起的石块提供清楚的采石场轮廓。
static func _crane(canvas: Control, at: Vector2) -> void:
	_deck(canvas, at, 0.24, 0.28, Color("#5e5547"), Color("#3e352b"))
	for x: float in [-9.0, 6.0]:
		_stroke(canvas, at, Vector2(x, 5), Vector2(x, -45), Color("#72513a"), 7)
		_stroke(canvas, at, Vector2(x + 1, 3), Vector2(x + 1, -45), Color("#be9562"), 2)
	_stroke(canvas, at, Vector2(-8, -14), Vector2(6, -42), Color("#ac8658"), 4)
	_stroke(canvas, at, Vector2(5, -16), Vector2(-8, -42), Color("#946741"), 4)
	_stroke(canvas, at, Vector2(-16, -45), Vector2(35, -33), Color("#49392f"), 8)
	_stroke(canvas, at, Vector2(-16, -46), Vector2(35, -34), Color("#d0a06a"), 4)
	_stroke(canvas, at, Vector2(28, -34), Vector2(28, -10), Color("#e0c7a1"), 1.6)
	_stone_block(canvas, at + Vector2(28, -10))


# 方石模块：明暗分面区分已切石料与自然裸岩。
static func _stone_block(canvas: Control, at: Vector2) -> void:
	_poly(canvas, at, [Vector2(-8, 0), Vector2(2, 5), Vector2(2, -5), Vector2(-8, -9)], Color("#9a9686"))
	_poly(canvas, at, [Vector2(2, 5), Vector2(11, 0), Vector2(11, -8), Vector2(2, -5)], Color("#696d67"))
	_poly(canvas, at, [Vector2(-8, -9), Vector2(2, -5), Vector2(11, -8), Vector2(2, -13)], Color("#c7c2ae"))


# 手推车模块：用车斗、双轮和扶手承接各场地的装载作业。
static func _cart(canvas: Control, at: Vector2, cargo: Color) -> void:
	for x: float in [-8.0, 8.0]:
		_pixel(canvas, at, Vector2(x - 4, -1), Vector2(8, 9), Color("#312d27"))
		_pixel(canvas, at, Vector2(x - 1, 1), Vector2(3, 4), Color("#978467"))
	_poly(canvas, at, [Vector2(-15, -8), Vector2(3, -16), Vector2(18, -9), Vector2(1, 1)], Color("#654732"))
	_poly(canvas, at, [Vector2(-11, -9), Vector2(3, -14), Vector2(13, -9), Vector2(0, -3)], cargo)
	_stroke(canvas, at, Vector2(-13, -5), Vector2(-24, 4), Color("#96704b"), 3)


# 渔场模块：装卸场居中，四侧设晒网、分拣棚、暂养池和木料器具区，通道连通全场。
static func _fishery(canvas: Control, center: Vector2) -> void:
	_deck(canvas, center, 10.9, 0.70, Color("#b19a6e"), Color("#826c4d"))
	_deck(canvas, center, 0.70, 8.9, Color("#ad9668"), Color("#816d4c"))
	_deck(canvas, center + _tile(-5.6, -4.6), 4.7, 3.55, Color("#947356"), Color("#65513c"))
	_deck(canvas, center + _tile(5.6, -4.6), 4.7, 3.55, Color("#927f61"), Color("#65513c"))
	_deck(canvas, center + _tile(-5.6, 4.6), 4.7, 3.55, Color("#a08860"), Color("#65513c"))
	_deck(canvas, center + _tile(5.6, 4.6), 4.7, 3.55, Color("#877958"), Color("#65513c"))
	for x: float in [-8.4, -5.5, -2.9]:
		for y: float in [3.2, 6.2]:
			_net_rack(canvas, center + _tile(x, y))
	for x: float in [3.4, 7.4]:
		_holding_pool(canvas, center + _tile(x, 4.7))
	for x: float in [3.3, 5.8, 8.0]:
		_sorting_table(canvas, center + _tile(x, -2.8))
	for p: Vector2 in [Vector2(-8, -5), Vector2(-5, -6), Vector2(-8, -2.6), Vector2(-6.2, -2.65), Vector2(9, 7.0)]:
		var at: Vector2 = center + _tile(p.x, p.y)
		_cargo_pallet(canvas, at)
	for p: Vector2 in [Vector2(-6.8, 0.9), Vector2(4.4, 0.8), Vector2(-0.8, 6.7)]:
		_cart(canvas, center + _tile(p.x, p.y), Color("#94b3aa"))
	_house(canvas, center + _tile(-7.6, -6.0), 37, 20, Color("#6a6955"), Color("#b19268"), "store", 2.3)
	_house(canvas, center + _tile(-2.8, -2.0), 43, 23, Color("#4c7580"), Color("#cfad79"), "store", 2.15)
	_house(canvas, center + _tile(7.4, -6.4), 35, 18, Color("#677c7c"), Color("#c3a681"), "timber", 1.95)


# 货盘模块：成组的箱筐和木托盘把仓库外侧变成可辨识的卸货区。
static func _cargo_pallet(canvas: Control, at: Vector2) -> void:
	_deck(canvas, at, 0.57, 0.53, Color("#b88f62"), Color("#5d4736"))
	for step: Vector2 in [Vector2(-15, 3), Vector2(0, -2), Vector2(14, 3)]:
		canvas.art_origin = at + step
		canvas.art_scale = 1.7
		_crate(canvas, at + step, Color("#916340") if step.x > 0 else Color("#b78753"))
	canvas.art_scale = 1.0


# 晒网架模块：两排木架拉起菱格渔网，地台收集水滴。
static func _net_rack(canvas: Control, at: Vector2) -> void:
	_deck(canvas, at, 0.9, 0.6, Color("#ad9167"), Color("#776044"))
	var a := Vector2(-34, -16)
	var b := Vector2(30, 0)
	var top := Vector2(0, -32)
	for edge: Vector2 in [a, b]:
		_stroke(canvas, at, edge + Vector2(0, 6), edge + top, Color("#674932"), 5)
	_stroke(canvas, at, a + top, b + top, Color("#d9b481"), 5)
	for thread: int in range(10):
		var p: Vector2 = a.lerp(b, float(thread) / 9.0)
		_stroke(canvas, at, p + top, p + Vector2(10, -5), Color("#ccb998"), 1.7)
		_stroke(canvas, at, p + top, p + Vector2(-8, -7), Color("#9d8d70"), 1.5)
	_stroke(canvas, at, a - Vector2(0, 4), b - Vector2(0, 4), Color("#d0b790"), 2)


# 暂养池模块：木框、蓝绿色池面和小鱼反光标出渔场的湿作业区。
static func _holding_pool(canvas: Control, at: Vector2) -> void:
	_deck(canvas, at, 1.48, 1.7, Color("#6c5039"), Color("#4c3a2d"))
	_deck(canvas, at + Vector2(0, -7), 1.41, 1.62, Color("#c39b69"), Color("#896345"))
	_deck(canvas, at + Vector2(0, -7), 1.23, 1.39, Color("#3c7176"), Color("#254e56"))
	for p: Vector2 in [Vector2(-42, -9), Vector2(0, -28), Vector2(40, -7), Vector2(1, 15)]:
		_pixel(canvas, at, p, Vector2(8, 6), Color("#e0b77b"))
	for p: Vector2 in [Vector2(-22, -11), Vector2(17, -12), Vector2(-3, 1), Vector2(31, -2)]:
		_stroke(canvas, at + p, Vector2(-5, 0), Vector2(7, -4), Color("#a4c9bd"), 2.3)


# 分拣台模块：蓝布铺在木托盘上，鱼获按行摆放。
static func _sorting_table(canvas: Control, at: Vector2) -> void:
	for p: Vector2 in [Vector2(-20, -2), Vector2(19, 6), Vector2(-2, 12)]:
		_stroke(canvas, at, p, p - Vector2(0, 18), Color("#624735"), 4)
	_deck(canvas, at + Vector2(0, -15), 0.62, 0.53, Color("#548787"), Color("#533b2b"))
	for p: Vector2 in [Vector2(-12, -17), Vector2(2, -21), Vector2(9, -14), Vector2(-4, -11)]:
		_stroke(canvas, at + p, Vector2(-3, 1), Vector2(5, -2), Color("#b7c9bf"), 2)


# 工人路线：靠近设备来回搬运，坐标始终位于当前建筑占地内。
static func worker_position(id: String, index: int, time: float) -> Vector2:
	var phase: float = 0.5 + 0.5 * sin(time * (1.2 + index * 0.13) + index * 1.7)
	if id == "b_fishery":
		if index == 0:
			return _tile(lerpf(-8.0, -1.1, phase), -0.48)
		return _tile(0.43, lerpf(0.6, 7.8, phase))
	var from: Array[Vector2] = [Vector2(-52, 16), Vector2(8, 23), Vector2(26, 12)]
	var to: Array[Vector2] = [Vector2(-17, 23), Vector2(32, 26), Vector2(56, 14)]
	return from[index].lerp(to[index], phase)


# 工人图层：使用建筑实际在岗人数，按纵深排序绘制行走及行业工具动作。
static func draw_workers(canvas: Control, id: String, center: Vector2, count: int, time: float) -> void:
	var positions: Array[Vector2] = []
	for index: int in range(count):
		positions.append(worker_position(id, index, time))
	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var tunic: Color = Color("#c18242")
	if id == "b_quarry":
		tunic = Color("#c98a6b")
	elif id == "b_fishery":
		tunic = Color("#6bb1bb")
	for i: int in range(positions.size()):
		_worker(canvas, center + positions[i], id, tunic, sin(time * 9.2 + i * 1.9))


# 工人轮廓：帽子和动作区分木匠、石工与渔工，帽檐和衣料保持像素对齐。
static func _worker(canvas: Control, at: Vector2, id: String, tunic: Color, step: float) -> void:
	_pixel(canvas, at, Vector2(-7, 0), Vector2(15, 4), Color("#30281eb0"))
	_stroke(canvas, at, Vector2(-3, -9), Vector2(-4 + step * 5, 1), Color("#302b27"), 3)
	_stroke(canvas, at, Vector2(4, -9), Vector2(4 - step * 5, 1), Color("#302b27"), 3)
	_pixel(canvas, at, Vector2(-6, -21), Vector2(13, 13), Color("#382e28"))
	_pixel(canvas, at, Vector2(-4, -20), Vector2(9, 10), tunic)
	_pixel(canvas, at, Vector2(-4, -27), Vector2(9, 7), Color("#d4a27b"))
	_pixel(canvas, at, Vector2(-8, -27), Vector2(17, 3), Color("#493b2e"))
	_pixel(canvas, at, Vector2(-6, -31), Vector2(13, 5), Color("#d0ad68") if id == "b_fishery" else Color("#a4815d"))
	var hand := Vector2(9, -15 + step * 4)
	_stroke(canvas, at, Vector2(3, -18), hand, Color("#d4a27b"), 3)
	if id == "b_fishery":
		_pixel(canvas, at, hand + Vector2(-2, -1), Vector2(10, 7), Color("#af8256"))
		_pixel(canvas, at, hand + Vector2(0, 0), Vector2(6, 2), Color("#dbad6f"))
	else:
		var tip := Vector2(13, -25 - step * 4)
		_stroke(canvas, at, hand, tip, Color("#5f412c"), 2.5)
		_stroke(canvas, at, tip - Vector2(4, 2), tip + Vector2(5, 0.5), Color("#c7c7b4"), 3)
