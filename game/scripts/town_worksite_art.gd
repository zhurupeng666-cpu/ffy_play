## 文件用途：绘制伐木场、采石场、渔场的设施和在岗工人，只接收视图数据。
extends "res://scripts/town_art.gd"

const Terrain = preload("res://scripts/town_terrain.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
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
		_stroke(canvas, at + p, Vector2(-5, 0), Vector2(7, -4), Color("#82aaa580"), 1.4)


# 分拣台模块：蓝布铺在木托盘上，鱼获按行摆放。
static func _sorting_table(canvas: Control, at: Vector2) -> void:
	for p: Vector2 in [Vector2(-20, -2), Vector2(19, 6), Vector2(-2, 12)]:
		_stroke(canvas, at, p, p - Vector2(0, 18), Color("#624735"), 4)
	_deck(canvas, at + Vector2(0, -15), 0.62, 0.53, Color("#548787"), Color("#533b2b"))
	_fish_shape(canvas, at + Vector2(-8, -17), 1.0, 0.61, 0.0, Color("#bec9b0"))
	_fish_shape(canvas, at + Vector2(10, -13), -1.0, 0.55, -0.3, Color("#97b7ab"))


# 资源作业区：从临接边进入同类型资源格，给每个岗位预留实际地块。
static func resource_area(record: Dictionary, reserved: Dictionary) -> Dictionary:
	var anchor := Vector2i(int(record["cell"][0]), int(record["cell"][1]))
	var extent: Vector2i = Catalog.footprint(record)
	var kind: String = "forest" if record["def_id"] == "b_lumber" else "stone"
	var entry: Vector2i = Grid.INVALID
	var inward := Vector2i.ZERO
	var metric: float = INF
	var middle: Vector2 = Vector2(anchor) + Vector2(extent - Vector2i.ONE) * 0.5
	for y: int in range(anchor.y, anchor.y + extent.y):
		for x: int in range(anchor.x, anchor.x + extent.x):
			for edge: Vector2i in Terrain.CARDINALS:
				var probe := Vector2i(x, y) + edge
				var distance: float = Vector2(probe).distance_squared_to(middle)
				if distance < metric and Terrain.deposit_at(probe) == kind:
					entry = probe
					inward = edge
					metric = distance
	if entry == Grid.INVALID:
		return {}
	var side := Vector2i(-inward.y, inward.x)
	var positions: Array[Vector2i] = []
	for forward: int in [3, 5, 2, 6, 1, 4, 0]:
		for offset: int in [0, -2, 2, -4, 4, -1, 1, -3, 3]:
			var site: Vector2i = entry + inward * forward + side * offset
			if Terrain.deposit_at(site) != kind or reserved.has(site):
				continue
			# 相邻设备之间留出装运通道，设备与工人的站位落在同一资源格。
			positions.append(site)
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					reserved[site + Vector2i(dx, dy)] = true
			if positions.size() == 3:
				return {"kind": kind, "sites": positions}
	return {"kind": kind, "sites": positions}


# 森林工位：伐桩、带手摇绞盘的滑木架和装载车分布在林地内。
static func draw_resource_equipment(canvas: Control, kind: String, at: Vector2, role: int) -> void:
	if kind == "forest":
		_deck(canvas, at, 0.78, 0.62, Color("#80704b"), Color("#514531"))
		for p: Vector2 in [Vector2(-23, 2), Vector2(13, -12)]:
			_deck(canvas, at + p, 0.17, 0.17, Color("#b99462"), Color("#654331"))
			_stroke(canvas, at + p, Vector2(-6, -1), Vector2(5, 2), Color("#795938"), 2)
		match role:
			0:
				_saw_frame(canvas, at + Vector2(-12, 3))
				_log_stack(canvas, at + Vector2(8, 11))
			1:
				_stroke(canvas, at, Vector2(9, 8), Vector2(9, -22), Color("#6b4a32"), 4)
				_stroke(canvas, at, Vector2(21, 14), Vector2(21, -16), Color("#a17a4d"), 4)
				_stroke(canvas, at, Vector2(8, -18), Vector2(22, -12), Color("#d3a46b"), 5)
				_stroke(canvas, at, Vector2(19, -13), Vector2(27, -20), Color("#cec7a3"), 2.2)
				_stroke(canvas, at, Vector2(16, -16), Vector2(-27, 14), Color("#d6b783"), 2)
			2:
				_log_stack(canvas, at + Vector2(-19, -7))
				_cart(canvas, at + Vector2(23, 20), Color("#c5975b"))
	else:
		_deck(canvas, at, 0.84, 0.72, Color("#898675"), Color("#5b564b"))
		_deck(canvas, at - Vector2(0, 5), 0.52, 0.49, Color("#555e59"), Color("#c1bda5"))
		for p: Vector2 in [Vector2(-30, 4), Vector2(-19, 13), Vector2(18, 15)]:
			_stone_block(canvas, at + p)
		if role == 0:
			_crane(canvas, at + Vector2(7, -3))
		elif role == 1:
			_stone_block(canvas, at + Vector2(4, -7))
			_stroke(canvas, at, Vector2(3, -17), Vector2(11, -18), Color("#ece2bb"), 2)
		else:
			for y: float in [12.0, 18.0]:
				_stroke(canvas, at, Vector2(7, y), Vector2(43, y - 12), Color("#5a5345"), 1.7)
			_cart(canvas, at + Vector2(29, 11), Color("#a6a795"))


# 资源工人：以资源格中心为锚点原地操作工具，不虚构岗位或重复画回厂房。
static func draw_resource_workers(canvas: Control, area: Dictionary, count: int, time: float, view: Rect2) -> void:
	var sites: Array = area["sites"]
	var lumber: bool = area["kind"] == "forest"
	for i: int in range(count):
		if sites.is_empty():
			return
		var site: Vector2i = sites[i % sites.size()]
		var base: Vector2 = Grid.cell_to_world(site)
		if not view.has_point(base):
			continue
		var work: float = sin(time * 4.8 + i * 1.7)
		var stride: float = sin(time * 1.6 + i * 1.7) * 5.0
		_worker(canvas, base + Vector2(-8 + stride + floori(float(i) / sites.size()) * 9, 6),
			"b_lumber" if lumber else "b_quarry", Color("#bd8046") if lumber else Color("#c98568"), work)


# 水中生物：两座暂养池和码头附近分别显示鱼群，摆尾与转向独立于战略日结。
static func draw_fish(canvas: Control, center: Vector2, dock: Dictionary, time: float) -> void:
	for x: float in [3.4, 7.4]:
		var pool: Vector2 = center + _tile(x, 4.7) - Vector2(0, 10)
		_school(canvas, pool, Vector2(30, 14), 6, time + x * 0.31, false)
	if not dock.is_empty():
		var outward: Vector2i = dock["outward"]
		var water: Vector2i = dock["cell"] + outward * 3
		if Terrain.is_water(water):
			_school(canvas, Grid.cell_to_world(water) + Vector2(-13, 0), Vector2(29, 9), 5, time, true)


# 鱼群路线：椭圆游动带错相与深浅，河鱼每次绘制前确认仍在水格。
static func _school(canvas: Control, at: Vector2, span: Vector2, count: int, time: float, river: bool) -> void:
	for i: int in range(count):
		var phase: float = time * (0.63 + i * 0.017) + i * TAU / count
		var fish: Vector2 = at + Vector2(cos(phase), sin(phase)) * span * (0.62 + i * 0.06)
		if river and not Terrain.is_water(Grid.world_to_cell(fish)):
			continue
		var facing: float = 1.0 if -sin(phase) > 0.0 else -1.0
		var ink: Color = Color("#80b5ac") if i % 2 == 0 else Color("#d3c49a")
		_fish_shape(canvas, fish, facing, 0.76 + (i % 3) * 0.13, sin(time * 11.0 + i), ink)
		if i == 0:
			_stroke(canvas, fish, Vector2(-10, -3), Vector2(-17, -5), Color("#bce0d183"), 1.25)


# 单鱼轮廓：身体、尾鳍、背鳍、腹部和鱼眼分层绘制，近看可辨朝向和摆尾。
static func _fish_shape(canvas: Control, at: Vector2, facing: float, scale_hint: float, tail: float, ink: Color) -> void:
	var axis := Vector2(facing, 1.0) * scale_hint
	_poly(canvas, at, [Vector2(-9, 0) * axis, Vector2(-5, -3) * axis, Vector2(2, -4) * axis,
		Vector2(8, -1) * axis, Vector2(7, 2) * axis, Vector2(2, 4) * axis, Vector2(-5, 3) * axis], ink.darkened(0.31))
	_poly(canvas, at, [Vector2(-9, 0) * axis, Vector2(-14, -5 + tail * 2.0) * axis,
		Vector2(-12, 0) * axis, Vector2(-15, 4 + tail * 2.0) * axis], ink.darkened(0.16))
	_poly(canvas, at, [Vector2(-5, -2) * axis, Vector2(-1, -6) * axis, Vector2(3, -3) * axis], ink.darkened(0.22))
	_poly(canvas, at, [Vector2(-7, 1) * axis, Vector2(5, -1) * axis,
		Vector2(7, 1) * axis, Vector2(0, 3) * axis], ink.lightened(0.18))
	_stroke(canvas, at, Vector2(4, -1) * axis, Vector2(5, -1) * axis, Color("#2d3c3a"), 1.9)


# 渔工路线：有码头时首名渔工在栈桥卸篓，其余人沿场内通道搬运。
static func draw_fishers(canvas: Control, center: Vector2, dock: Dictionary, count: int, time: float) -> void:
	for index: int in range(count):
		var phase: float = 0.5 + 0.5 * sin(time * (1.2 + index * 0.13) + index * 1.7)
		var at: Vector2 = center + _tile(0.43, lerpf(0.6, 7.8, phase))
		if index == 0:
			if dock.is_empty():
				at = center + _tile(lerpf(-8.0, -1.1, phase), -0.48)
			else:
				var direction: Vector2 = Grid.cell_to_world(dock["outward"])
				at = Grid.cell_to_world(dock["cell"]) + direction * lerpf(-0.45, 0.85, phase)
		_worker(canvas, at, "b_fishery", Color("#6bb1bb"), sin(time * 9.2 + index * 1.9))


# 工人轮廓：帽子和动作区分木匠、石工与渔工，帽檐和衣料保持像素对齐。
static func _worker(canvas: Control, at: Vector2, id: String, tunic: Color, step: float) -> void:
	_pixel(canvas, at, Vector2(-7, 0), Vector2(15, 4), Color("#30281eb0"))
	_stroke(canvas, at, Vector2(-3, -9), Vector2(-4 + step * 5, 1), Color("#302b27"), 3)
	_stroke(canvas, at, Vector2(4, -9), Vector2(4 - step * 5, 1), Color("#302b27"), 3)
	_pixel(canvas, at, Vector2(-6, -21), Vector2(13, 13), Color("#382e28"))
	_pixel(canvas, at, Vector2(-4, -20), Vector2(9, 10), tunic)
	_pixel(canvas, at, Vector2(-3, -19), Vector2(4, 8), tunic.lightened(0.27))
	_pixel(canvas, at, Vector2(-4, -12), Vector2(10, 3), Color("#554033"))
	_pixel(canvas, at, Vector2(-4, -27), Vector2(9, 7), Color("#d4a27b"))
	_pixel(canvas, at, Vector2(1, -24), Vector2(3, 2), Color("#544034"))
	_pixel(canvas, at, Vector2(-4, -23), Vector2(3, 4), Color("#906646"))
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
		if id == "b_lumber":
			_poly(canvas, at + tip, [Vector2(-3, -2), Vector2(5, -4), Vector2(7, 2), Vector2(1, 4)], Color("#c4c9bc"))
		else:
			_stroke(canvas, at, tip - Vector2(4, 2), tip + Vector2(5, 0.5), Color("#c7c7b4"), 3.5)
