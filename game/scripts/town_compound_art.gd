## 文件用途：绘制大型农场、牧场和军营，提供与岗位和驻军人数联动的活动视图。
extends "res://scripts/town_art.gd"

const TYPES: Array[String] = ["b_farm", "b_ranch", "b_barracks"]


# 场地坐标：统一将建筑内部格位换算成等距投影。
static func _tile(x: float, y: float) -> Vector2:
	return Vector2((x - y) * Grid.HALF.x, (x + y) * Grid.HALF.y)


# 场地铺装：给道路、草场、石坪与农田绘制明确边界。
static func _ground(canvas: Control, at: Vector2, x: float, y: float, color: Color, trim: Color) -> void:
	var a: Vector2 = _tile(-x, -y)
	var b: Vector2 = _tile(x, -y)
	var c: Vector2 = _tile(x, y)
	var d: Vector2 = _tile(-x, y)
	_poly(canvas, at, [a, b, c, d], color)
	_stroke(canvas, at, b, c, trim, 3)
	_stroke(canvas, at, c, d, trim, 3)


# 大型建筑入口：同一座建筑按用途布置多个相连的作业区。
static func draw_compound(canvas: Control, kind: String, center: Vector2) -> void:
	match kind:
		"b_farm":
			_farm(canvas, center)
		"b_ranch":
			_pasture(canvas, center)
		"b_barracks":
			_garrison(canvas, center)


# 农场模块：道路连起麦田、菜畦、翻耕区和收储工棚。
static func _farm(canvas: Control, center: Vector2) -> void:
	_ground(canvas, center, 8.9, 0.65, Color("#b59b65"), Color("#90764c"))
	_ground(canvas, center, 0.70, 8.9, Color("#b49d69"), Color("#90764c"))
	_crop_plot(canvas, center + _tile(4.8, -4.8), 0)
	_crop_plot(canvas, center + _tile(-4.8, 4.8), 1)
	_crop_plot(canvas, center + _tile(4.8, 4.8), 2)
	_ground(canvas, center + _tile(-4.8, -4.8), 3.9, 3.9, Color("#967448"), Color("#684e33"))
	_house(canvas, center + _tile(-6.5, -6.2), 38, 22, Color("#a4633c"), Color("#c59c64"), "timber", 2.15)
	_house(canvas, center + _tile(-3.65, -5.2), 24, 14, Color("#8d743e"), Color("#b49158"), "store", 1.8)
	for p: Vector2 in [Vector2(-7, -3), Vector2(-5.6, -3.4), Vector2(3.9, 2.8), Vector2(6.9, -2.35)]:
		_bale(canvas, center + _tile(p.x, p.y))
	_cart_load(canvas, center + _tile(-2.4, -2.45), Color("#d0ad63"))
	_produce_box(canvas, center + _tile(-4.2, -1.12))
	_produce_box(canvas, center + _tile(-2.7, -1.25))
	_crate(canvas, center + _tile(-4.2, -2.3))
	_crate(canvas, center + _tile(-4.6, -2.75))
	_trough(canvas, center + _tile(-1.05, -6.75), Color("#72939a"))
	_open_shelter(canvas, center + _tile(-6.45, -1.95), Color("#ae804e"))
	_rail(canvas, center, _tile(-8.4, 7.85), _tile(-8.4, 1.2), 6)


# 田垄模块：不同颜色与植株轮廓区分麦田、菜畦和翻好的土垄。
static func _crop_plot(canvas: Control, at: Vector2, kind: int) -> void:
	var soil: Color = [Color("#89633f"), Color("#795639"), Color("#694938")][kind]
	_ground(canvas, at, 3.85, 3.85, soil, Color("#55402d"))
	for row: int in range(9):
		var y: float = -3.35 + row * 0.84
		var a: Vector2 = _tile(-3.55, y)
		var b: Vector2 = _tile(3.55, y)
		_stroke(canvas, at, a, b, soil.darkened(0.25), 9.0)
		_stroke(canvas, at, a - Vector2(0, 2), b - Vector2(0, 2), soil.lightened(0.2), 2.5)
		if kind == 2:
			continue
		var shade: Color = Color("#dbc56b") if kind == 0 else Color("#90aa63")
		for group: int in range(6):
			var p: Vector2 = at + _tile(-3.1 + group * 1.22 + (row % 2) * 0.16, y)
			_stroke(canvas, p, Vector2(-5, 2), Vector2(-3, -7 if kind == 0 else -4), shade.darkened(0.17), 3.0)
			_stroke(canvas, p, Vector2(1, 0), Vector2(3, -9 if kind == 0 else -5), shade, 3.6)
			if kind == 1:
				_leaf_cluster(canvas, p, row + group)
			else:
				_stroke(canvas, p, Vector2(-4, -7), Vector2(4, -10), Color("#efca76"), 3.5)
				_pixel(canvas, p, Vector2(1, -11), Vector2(4, 2), Color("#ffe3a4"))


# 菜畦轮廓：错开的叶片包住果实，近看有颜色与形状差异。
static func _leaf_cluster(canvas: Control, at: Vector2, variant: int) -> void:
	_pixel(canvas, at, Vector2(-4, -6), Vector2(11, 6), Color("#526941"))
	_pixel(canvas, at, Vector2(-4, -7), Vector2(6, 3), Color("#85a358"))
	_pixel(canvas, at, Vector2(3, -10), Vector2(4, 5), Color("#a5b669"))
	_pixel(canvas, at, Vector2(0, -5), Vector2(4, 4), Color("#d87952") if variant % 3 == 0 else Color("#d0c46f"))


# 收获箱：木框包住成簇果实，靠近搬运通道摆放。
static func _produce_box(canvas: Control, at: Vector2) -> void:
	_crate(canvas, at, Color("#aa754e"))
	for y: int in range(2):
		for x: int in range(3):
			_pixel(canvas, at, Vector2(-4 + x * 3 + y, -10 + y * 3), Vector2(3, 3), Color("#de8156") if x != 1 else Color("#b3ae62"))


# 牧场模块：双围栏将牛羊分开，草场后方设畜棚、干草堆与饲料车。
static func _pasture(canvas: Control, center: Vector2) -> void:
	_ground(canvas, center + _tile(0, 0.5), 0.75, 8.2, Color("#a28b60"), Color("#7f6b46"))
	for side: int in [-1, 1]:
		var pen: Vector2 = center + _tile(side * 4.65, 2.15)
		_ground(canvas, pen, 3.95, 4.95, Color("#76844e") if side < 0 else Color("#66774b"), Color("#515c3e"))
		for i: int in range(18):
			var p: Vector2 = pen + _tile((i * 47 % 68 - 34) * 0.1, (i * 39 % 90 - 45) * 0.1)
			_stroke(canvas, p, Vector2(0, 1), Vector2(-2, -4), Color("#97a05c"), 2.5)
		_pen(canvas, pen, 3.95, 4.95)
		_trough(canvas, pen + _tile(1.9, -3.1), Color("#6f969d"))
		_bale(canvas, pen + _tile(-2.5, -2.9))
	_house(canvas, center + _tile(-5.45, -6.15), 41, 24, Color("#975447"), Color("#be9160"), "timber", 2.2)
	_house(canvas, center + _tile(5.0, -6.4), 33, 20, Color("#806146"), Color("#c59a65"), "timber", 1.95)
	for p: Vector2 in [Vector2(-2, -6.8), Vector2(-2.7, -5.8), Vector2(2.0, -5.0), Vector2(7.2, -5.2)]:
		_bale(canvas, center + _tile(p.x, p.y))
	_cart_load(canvas, center + _tile(0, -3.1), Color("#b69454"))
	_milk_churn(canvas, center + _tile(-3.8, -4.5))
	_milk_churn(canvas, center + _tile(-3.35, -4.6))
	_open_shelter(canvas, center + _tile(7.25, -2.6), Color("#8b754a"))
	_open_shelter(canvas, center + _tile(-7.55, -2.75), Color("#a08a53"))


# 奶桶：桶盖、提把和受光金属面标示畜棚的收集区。
static func _milk_churn(canvas: Control, at: Vector2) -> void:
	_pixel(canvas, at, Vector2(-6, -15), Vector2(12, 16), Color("#494952"))
	_pixel(canvas, at, Vector2(-4, -14), Vector2(7, 13), Color("#a3a8a1"))
	_pixel(canvas, at, Vector2(-3, -15), Vector2(5, 4), Color("#dfd3af"))
	_stroke(canvas, at, Vector2(-3, -15), Vector2(3, -18), Color("#75675f"), 2)


# 围栏模块：每面分段绘制立柱和横梁，朝前留有中央入口。
static func _pen(canvas: Control, at: Vector2, x: float, y: float) -> void:
	var a: Vector2 = _tile(-x, -y)
	var b: Vector2 = _tile(x, -y)
	var c: Vector2 = _tile(x, y)
	var d: Vector2 = _tile(-x, y)
	_rail(canvas, at, a, b, 8)
	_rail(canvas, at, b, c, 10)
	_rail(canvas, at, a, d, 10)
	_rail(canvas, at, d, d.lerp(c, 0.39), 3)
	_rail(canvas, at, d.lerp(c, 0.60), c, 3)


# 横栏模块：双层木梁、柱头和亮面让大面积围栏依旧有层次。
static func _rail(canvas: Control, at: Vector2, a: Vector2, b: Vector2, sections: int) -> void:
	for height: float in [6.0, 14.0]:
		_stroke(canvas, at, a - Vector2(0, height), b - Vector2(0, height), Color("#8b6545"), 4.8)
		_stroke(canvas, at, a - Vector2(0, height + 1), b - Vector2(0, height + 1), Color("#ca9b64"), 1.8)
	for i: int in range(sections + 1):
		var point: Vector2 = a.lerp(b, float(i) / sections)
		_stroke(canvas, at, point, point - Vector2(0, 19), Color("#6d513a"), 5)
		_pixel(canvas, at, point - Vector2(2, 19), Vector2(4, 4), Color("#e0b578"))


# 军营模块：营舍、器械棚和补给区围住有列线、木靶与旗台的操练坪。
static func _garrison(canvas: Control, center: Vector2) -> void:
	_ground(canvas, center + _tile(0, 2.05), 8.1, 5.6, Color("#b39166"), Color("#755b45"))
	_ground(canvas, center + _tile(0, -5.1), 8.2, 2.25, Color("#9b8871"), Color("#665743"))
	_ground(canvas, center + _tile(0, 8.05), 1.6, 0.8, Color("#918274"), Color("#655747"))
	for y: float in [-0.9, 0.65, 2.2, 3.75, 5.3]:
		_stroke(canvas, center, _tile(-5.4, y), _tile(5.4, y), Color("#c6ac83"), 2.6)
	_house(canvas, center + _tile(-5.55, -5.4), 46, 27, Color("#a45447"), Color("#c4ad90"), "stone", 2.15)
	_house(canvas, center + _tile(4.6, -5.85), 36, 19, Color("#85604e"), Color("#bea283"), "store", 2.0)
	for x: float in [-5.5, -3.9, 3.9, 5.5]:
		_target(canvas, center + _tile(x, 6.75))
	for p: Vector2 in [Vector2(-7.1, -2.75), Vector2(7.1, -2.75), Vector2(-1.6, 7.6), Vector2(1.6, 7.6)]:
		var post: Vector2 = center + _tile(p.x, p.y)
		_stroke(canvas, post, Vector2(0, 5), Vector2(0, -53), Color("#755442"), 4.8)
		_flag(canvas, post - Vector2(0, 53), Color("#bf5345"))
	for x: float in [1.0, 2.2, 3.4]:
		_crate(canvas, center + _tile(x, -3.7), Color("#8c6745"))
	_cart_load(canvas, center + _tile(-0.9, -6.3), Color("#847d68"))
	_open_shelter(canvas, center + _tile(0.2, -4.4), Color("#925f4d"))
	_rail(canvas, center, _tile(-8.25, 3), _tile(-8.25, 7.5), 4)
	_rail(canvas, center, _tile(8.25, 3), _tile(8.25, 7.5), 4)


# 木靶模块：采用带同心色块的木板靶和三脚支架。
static func _target(canvas: Control, at: Vector2) -> void:
	for x: float in [-10.0, 9.0]:
		_stroke(canvas, at, Vector2(x, 3), Vector2(0, -25), Color("#644732"), 4)
	_poly(canvas, at, [Vector2(-10, -27), Vector2(8, -33), Vector2(12, -14), Vector2(-6, -9)], Color("#d3ac71"))
	_poly(canvas, at, [Vector2(-5, -25), Vector2(5, -28), Vector2(8, -17), Vector2(-3, -14)], Color("#a45343"))
	_pixel(canvas, at, Vector2(0, -23), Vector2(4, 4), Color("#e8c98c"))


# 开放工棚：支柱、顶梁和彩色篷面能从远景区分场地用途。
static func _open_shelter(canvas: Control, at: Vector2, roof: Color) -> void:
	var span: Array[Vector2] = [Vector2(-38, 0), Vector2(-4, -18), Vector2(36, 0), Vector2(4, 17)]
	_poly(canvas, at, span, Color("#393a2b88"))
	for p: Vector2 in span:
		_stroke(canvas, at, p, p - Vector2(0, 29), Color("#775640"), 4.2)
	var front := Vector2(0, -26)
	var back := Vector2(0, -42)
	_poly(canvas, at, [span[0] + front, span[1] + back, span[2] + back, span[3] + front], roof)
	_stroke(canvas, at, span[0] + front, span[3] + front, roof.lightened(0.26), 3.2)
	_stroke(canvas, at, span[1] + back, span[2] + back, roof.lightened(0.16), 3.0)
	for weight: float in [0.24, 0.48, 0.72]:
		_stroke(canvas, at, (span[0] + front).lerp(span[3] + front, weight), (span[1] + back).lerp(span[2] + back, weight), roof.darkened(0.26), 2.2)


# 补给道具：水槽、干草和双轮车提供可辨识的生产或补给场景。
static func _trough(canvas: Control, at: Vector2, fill: Color) -> void:
	_ground(canvas, at, 0.62, 0.26, Color("#604938"), Color("#473a2c"))
	_ground(canvas, at - Vector2(0, 7), 0.61, 0.26, Color("#a58158"), Color("#654632"))
	_ground(canvas, at - Vector2(0, 7), 0.52, 0.16, fill, Color("#4c6f73"))


# 草捆模块：亮稻草、阴影和捆绳形成小型饲料堆。
static func _bale(canvas: Control, at: Vector2) -> void:
	_crate(canvas, at, Color("#b28d48"))
	_crate(canvas, at + Vector2(11, 6), Color("#c3a25a"))
	_stroke(canvas, at, Vector2(5, -10), Vector2(15, -4), Color("#74583f"), 2.2)


# 双轮车模块：用轮缘和车斗表达装运状态。
static func _cart_load(canvas: Control, at: Vector2, cargo: Color) -> void:
	for side: float in [-12.0, 12.0]:
		_pixel(canvas, at, Vector2(side - 5, -3), Vector2(10, 11), Color("#41372d"))
		_pixel(canvas, at, Vector2(side - 1, 0), Vector2(3, 4), Color("#936b49"))
	_poly(canvas, at, [Vector2(-20, -9), Vector2(1, -19), Vector2(23, -9), Vector2(2, 1)], Color("#74543e"))
	_poly(canvas, at, [Vector2(-13, -10), Vector2(1, -16), Vector2(17, -10), Vector2(3, -3)], cargo)
	_stroke(canvas, at, Vector2(-19, -6), Vector2(-31, 4), Color("#b18a60"), 3)


# 动态入口：按实际在岗或留营人数绘制人员，牛羊沿各自围栏内路线活动。
static func draw_activity(canvas: Control, kind: String, center: Vector2, time: float, staff: int, troops: Vector2i) -> void:
	if kind == "b_barracks":
		var total: int = troops.x + troops.y
		for index: int in range(total):
			_drill_soldier(canvas, center + drill_foot(index, total, time), time, index, index >= troops.x)
		return
	if kind == "b_ranch":
		for index: int in range(7):
			var at: Vector2 = pasture_foot(index, time)
			var heading: float = 1.0 if pasture_foot(index, time + 0.1).x > at.x else -1.0
			_animal(canvas, center + at, index >= 4, heading, int(time * 5.0 + index) % 2)
	for index: int in range(staff):
		var step: float = sin(time * 4.0 + index * 2.1)
		var x: float = sin(time * 0.74 + index * 2.0) * 1.9
		var pos: Vector2 = _tile(4.8 + x, -5.4 + index * 1.4) if kind == "b_farm" else _tile(x * 0.31, -3.7 + index * 2.0)
		_field_worker(canvas, center + pos, step, kind == "b_farm", index)


# 牛羊路线：两群在各自围栏内部走动，保留与栅栏和水槽的间距。
static func pasture_foot(index: int, time: float) -> Vector2:
	var base: float = -4.65 if index < 4 else 4.65
	var phase: float = time * 0.38 + index * 1.73
	return _tile(base + sin(phase) * (1.4 + (index % 3) * 0.4), 2.7 + cos(phase) * (2.0 + (index % 2) * 0.6))


# 操练站位：人数增减与队列长度联动，每个人都保留独立站位。
static func drill_foot(index: int, total: int, time: float) -> Vector2:
	var columns: int = clampi(ceili(sqrt(float(total))), 1, 6)
	var row: int = floori(float(index) / columns)
	var x: float = (index % columns - (columns - 1) * 0.5) * 1.25
	return _tile(x + sin(time * 2.3 + row) * 0.1, 0.15 + row * 1.25)


# 农牧工人：草帽、袖口和移动工具区分田间锄作与牧场搬运。
static func _field_worker(canvas: Control, at: Vector2, step: float, farmer: bool, job: int) -> void:
	_pixel(canvas, at, Vector2(-9, 0), Vector2(18, 4), Color("#352b206b"))
	Sprites.draw(canvas, at, "farmer" if farmer else "herder", clampi(roundi(step) + 1, 0, 2))
	var hand := Vector2(10, -14 + step * 2.0)
	if farmer and job % 3 == 0:
		var tip := Vector2(21, -6 - step * 11.0)
		_stroke(canvas, at, hand, tip, Color("#8e6146"), 3.1)
		_stroke(canvas, at, tip - Vector2(2, 0), tip + Vector2(6, 3), Color("#bbc6ac"), 3.1)
	else:
		_pixel(canvas, at, hand, Vector2(10, 7), Color("#6d4938"))
		_pixel(canvas, at, hand + Vector2(1, 1), Vector2(8, 3), Color("#c79a5a"))
		_pixel(canvas, at, hand + Vector2(2, -2), Vector2(5, 3), Color("#ddad61") if farmer else Color("#b3aa6d"))
