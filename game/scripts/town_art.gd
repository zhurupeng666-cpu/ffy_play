## 文件用途：为城镇等距地图绘制统一配色的地形、资源、工地和建筑图形。
extends RefCounted

const Grid = preload("res://scripts/isometric_grid.gd")
const Ink: Color = Color("#283025")
const Grass: Array[Color] = [Color("#526c3d"), Color("#587343"), Color("#5d7846"), Color("#567140")]
const Water: Array[Color] = [Color("#24546a"), Color("#285b71"), Color("#2c6176")]

# 轮廓模块：图形先以世界像素绘制，再使用城镇镜头变换。
static func _poly(canvas: Control, center: Vector2, offsets: Array, color: Color) -> void:
	var points: PackedVector2Array = []
	var face: PackedVector2Array = []
	for offset: Vector2 in offsets:
		var point: Vector2 = center + offset
		face.append(canvas.art_origin + (point - canvas.art_origin) * canvas.art_scale)
		points.append(canvas.art_point(point))
	canvas.remember_building_face(face)
	canvas.art_canvas.draw_colored_polygon(points, color)

# 细节模块：小矩形跟随镜头缩放，使用整数屏幕坐标对齐。
static func _pixel(canvas: Control, center: Vector2, offset: Vector2, extent: Vector2, color: Color) -> void:
	var start: Vector2 = canvas.art_point(center + offset)
	var end: Vector2 = canvas.art_point(center + offset + extent)
	canvas.art_canvas.draw_rect(Rect2(start, end - start), color)

# 地块模块：草地采用固定纹理变化，河格绘制浅滩和水纹。
static func terrain(canvas: Control, cell: Vector2i, points: PackedVector2Array, water: bool) -> void:
	var seed: int = posmod(cell.x * 17 + cell.y * 29, 31)
	var center: Vector2 = Grid.cell_to_world(cell)
	if canvas.zoom_level < 0.23:
		# 远景只保留土地色带，减少绘制并让整张地图可读。
		var band: int = posmod(floori(cell.x / 5.0) + floori(cell.y / 4.0), Grass.size())
		canvas.art_canvas.draw_colored_polygon(points, Water[1] if water else Grass[band])
		return
	if water:
		canvas.art_canvas.draw_colored_polygon(points, Water[seed % Water.size()])
		_poly(canvas, center, [Vector2(0, 16), Vector2(32, 0), Vector2(27, 0), Vector2(-3, 14)], Color("#508391"))
		_pixel(canvas, center, Vector2(seed % 12 - 12, -4), Vector2(12, 2), Color("#4a8a9a"))
		_pixel(canvas, center, Vector2(0, 4), Vector2(10, 2), Color("#396f82"))
	else:
		canvas.art_canvas.draw_colored_polygon(points, Grass[seed % Grass.size()])
		_pixel(canvas, center, Vector2(seed % 22 - 13, seed % 7 - 6), Vector2(4, 2), Color("#799653"))
		_pixel(canvas, center, Vector2(9 - seed % 17, 3), Vector2(3, 2), Color("#455932"))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.art_canvas.draw_polyline(outline, Color("#24382465"), 1.0, false)

# 林矿模块：用树冠、树干与分面岩石表达资源，轮廓不参与点击判断。
static func deposit(canvas: Control, center: Vector2, kind: String) -> void:
	canvas.art_origin = center
	canvas.art_scale = 1.8 if kind == "forest" else 2.2
	if kind == "forest":
		_tree(canvas, center + Vector2(-10, -3), Color("#315738"))
		_tree(canvas, center + Vector2(10, 0), Color("#3b6741"))
		_tree(canvas, center + Vector2(-1, 7), Color("#447447"))
	elif kind == "stone":
		_rock(canvas, center + Vector2(-8, 4))
		_rock(canvas, center + Vector2(8, -1))
	canvas.art_scale = 1.0

# 树木模块：用两侧深浅树冠和树干构成紧凑松树。
static func _tree(canvas: Control, at: Vector2, green: Color) -> void:
	_pixel(canvas, at, Vector2(-3, -12), Vector2(6, 14), Color("#62412c"))
	_poly(canvas, at, [Vector2(-11, -8), Vector2(-7, -17), Vector2(-4, -17), Vector2(0, -29), Vector2(4, -17), Vector2(8, -17), Vector2(11, -8), Vector2(0, -3)], green)
	_poly(canvas, at, [Vector2(0, -29), Vector2(4, -17), Vector2(8, -17), Vector2(11, -8), Vector2(0, -3)], Color("#2c4e33"))

# 矿石模块：用高光面和阴影面标识裸露矿体。
static func _rock(canvas: Control, at: Vector2) -> void:
	_poly(canvas, at, [Vector2(-11, 0), Vector2(-6, -11), Vector2(3, -14), Vector2(10, -8), Vector2(12, 0), Vector2(1, 5)], Color("#7a8580"))
	_poly(canvas, at, [Vector2(-6, -11), Vector2(3, -14), Vector2(10, -8), Vector2(0, -4)], Color("#b2b6a1"))
	_poly(canvas, at, [Vector2(0, -4), Vector2(10, -8), Vector2(12, 0), Vector2(1, 5)], Color("#555e5d"))

# 工地模块：土色地基上设置木料与四个短桩。
static func site(canvas: Control, center: Vector2) -> void:
	for offset: Vector2 in [Vector2(-24, -9), Vector2(22, -9), Vector2(-24, 10), Vector2(22, 10)]:
		_pixel(canvas, center, offset, Vector2(4, 9), Color("#d7ad63"))
	_logs(canvas, center + Vector2(4, -1))

# 建筑模块：依据用途组合主楼、塔楼、侧棚和生产设施。
static func building(canvas: Control, id: String, center: Vector2, spread: float = 1.0) -> void:
	match id:
		"b_hall":
			_house(canvas, center + Vector2(0, -10), 42, 35, Color("#526b86"), Color("#baa98e"), "stone")
			_tower(canvas, center + Vector2(-39, 3), 14, 37)
			_tower(canvas, center + Vector2(37, 5), 14, 37)
			_flag(canvas, center + Vector2(-3, -73), Color("#c45d4b"))
		"b_house":
			_house(canvas, center, 39, 25, Color("#ab5640"), Color("#e6bf87"), "home")
		"b_farm":
			var plots: int = clampi(roundi(spread), 1, 5)
			for row: int in range(plots):
				for column: int in range(plots):
					var offset: Vector2 = Vector2((column - row) * 112, (column + row - plots + 1) * 56)
					var plot: Vector2 = center + offset
					if Rect2(Vector2.ZERO, canvas.size).grow(120 * canvas.zoom_level).has_point(canvas.world_to_screen(plot)):
						_fields(canvas, plot)
			_house(canvas, center + Vector2(-65 * spread, -10), 27, 18, Color("#a45d3b"), Color("#c69b63"), "timber", 2.85 if spread > 1.0 else 1.42)
		"b_ranch":
			_ranch(canvas, center, spread)
		"b_barracks":
			_barracks(canvas, center, spread)
		"b_granary":
			_house(canvas, center + Vector2(-6, -5), 36, 30, Color("#ad783b"), Color("#d0ae73"), "store", 2.2 if spread > 1.0 else 1.45)
			for offset: Vector2 in [Vector2(-23, 12), Vector2(-15, 16), Vector2(23, 9)]:
				_crate(canvas, center + offset)
			if spread > 1.0:
				_house(canvas, center + Vector2(44 * spread, 4), 38, 26, Color("#936838"), Color("#bc9866"), "store", 2.1)
				for offset: Vector2 in [Vector2(41, 40), Vector2(58, 36), Vector2(76, 32), Vector2(96, 23)]:
					_crate(canvas, center + offset)
		"b_lumber":
			_house(canvas, center + Vector2(-15, -7), 30, 19, Color("#526b41"), Color("#b7875b"), "timber")
			_logs(canvas, center + Vector2(11, 14))
			_logs(canvas, center + Vector2(21, 8))
		"b_quarry":
			_house(canvas, center + Vector2(-14, -8), 27, 18, Color("#666d6f"), Color("#b7a789"), "stone")
			_rock(canvas, center + Vector2(20, 9))
			_rock(canvas, center + Vector2(4, 16))
			_stroke(canvas, center, Vector2(14, 10), Vector2(14, -20), Color("#694934"), 4.0)
			_stroke(canvas, center, Vector2(12, -19), Vector2(32, -10), Color("#ac8357"), 4.0)
			_stroke(canvas, center, Vector2(31, -11), Vector2(31, 1), Color("#d5b986"), 2.0)
		"b_fishery":
			_poly(canvas, center, [Vector2(-42, 7), Vector2(4, -16), Vector2(39, 1), Vector2(-7, 24)], Color("#836344"))
			for i: int in range(7):
				_stroke(canvas, center, Vector2(-35 + i * 6, 7 - i * 3), Vector2(-6 + i * 6, 22 - i * 3), Color("#b39364"), 2.0)
			_house(canvas, center + Vector2(9, -7), 28, 17, Color("#496f7a"), Color("#cfad79"), "timber")
			_crate(canvas, center + Vector2(-17, 13))

# 线条模块：描边与木梁使用同一镜头刻度和像素对齐。
static func _stroke(canvas: Control, center: Vector2, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	canvas.art_canvas.draw_line(canvas.art_point(center + a), canvas.art_point(center + b), color, maxf(1.0, width * canvas.zoom_level * canvas.art_scale), false)

# 立面模块：按墙面的斜边定位门窗、梁柱和石缝，使构件服从透视。
static func _wall(canvas: Control, center: Vector2, a: Vector2, b: Vector2, height: int, wall: Color, mode: String, front: bool) -> void:
	var top: Vector2 = Vector2(0, -height)
	_poly(canvas, center, [a, b, b + top, a + top], wall)
	_stroke(canvas, center, a, b, Ink, 3.0)
	_stroke(canvas, center, a + Vector2(0, -4), b + Vector2(0, -4), wall.darkened(0.3), 4.0)
	if mode == "stone":
		for level: int in range(8, height - 4, 7):
			_stroke(canvas, center, a - Vector2(0, level), b - Vector2(0, level), wall.darkened(0.23), 1.0)
			var grout: Vector2 = a.lerp(b, 0.31 if level % 2 == 0 else 0.65) - Vector2(0, level)
			_stroke(canvas, center, grout, grout - Vector2(0, 6), wall.darkened(0.23), 1.0)
	else:
		var timber: Color = Color("#624332")
		for x: float in [0.05, 0.47, 0.94]:
			var post: Vector2 = a.lerp(b, x)
			_stroke(canvas, center, post, post + top, timber, 3.0)
		_stroke(canvas, center, a + top * 0.52, b + top * 0.52, timber, 2.0)
		if not front:
			_stroke(canvas, center, a.lerp(b, 0.05) + top * 0.52, a.lerp(b, 0.47) + top, timber, 2.0)
	if front:
		_wall_opening(canvas, center, a, b, 0.55, 0.78, 2.0, height * 0.64, Color("#79503a"), true)
		_wall_opening(canvas, center, a, b, 0.16, 0.34, height * 0.36, height * 0.71, Color("#e5b367"), false)
	else:
		_wall_opening(canvas, center, a, b, 0.56, 0.76, height * 0.37, height * 0.72, Color("#d79b5c"), false)
	_stroke(canvas, center, a, a + top, Ink)
	_stroke(canvas, center, b, b + top, Ink)

# 开口模块：门窗有深色框、亮窗格和门柱的局部高光。
static func _wall_opening(canvas: Control, center: Vector2, a: Vector2, b: Vector2, left: float, right: float, bottom: float, top: float, fill: Color, door: bool) -> void:
	var l: Vector2 = a.lerp(b, left)
	var r: Vector2 = a.lerp(b, right)
	var low: Vector2 = Vector2(0, -bottom)
	var high: Vector2 = Vector2(0, -top)
	var margin: Vector2 = (r - l).normalized() * 2.0
	_poly(canvas, center, [l + low, r + low, r + high, l + high], Ink)
	_poly(canvas, center, [l + low + margin - Vector2(0, 2), r + low - margin - Vector2(0, 2), r + high - margin + Vector2(0, 2), l + high + margin + Vector2(0, 2)], fill)
	var middle: Vector2 = (l + r) * 0.5
	_stroke(canvas, center, middle + low, middle + high, Ink, 1.5)
	if not door:
		_stroke(canvas, center, l + (low + high) * 0.5, r + (low + high) * 0.5, Ink, 1.5)
	else:
		_pixel(canvas, center, middle + (low + high) * 0.5 + Vector2(2, 0), Vector2(2, 2), Color("#e1ae61"))

# 房屋模块：根据同一屋基构建双坡屋顶、三角山墙、滴水线和墙体。
static func _house(canvas: Control, center: Vector2, span: int, height: int, roof: Color, wall: Color, mode: String, model_scale: float = 1.45) -> void:
	canvas.art_origin = center
	canvas.art_scale = model_scale
	var west: Vector2 = Vector2(-span, -3)
	var south: Vector2 = Vector2(5, span * 0.42)
	var east: Vector2 = Vector2(span, 3)
	var north: Vector2 = Vector2(-5, -span * 0.42)
	var up: Vector2 = Vector2(0, -height)
	_poly(canvas, center + Vector2(7, 5), [west, north, east, south], Color("#1b231b90"))
	_wall(canvas, center, west, south, height, wall, mode, true)
	_wall(canvas, center, south, east, height, wall.darkened(0.23), mode, false)
	var ridge_height: Vector2 = Vector2(0, -span * 0.41)
	var back_ridge: Vector2 = west.lerp(north, 0.5) + up + ridge_height
	var front_ridge: Vector2 = south.lerp(east, 0.5) + up + ridge_height
	_poly(canvas, center, [south + up, east + up, front_ridge], wall.darkened(0.25))
	_stroke(canvas, center, south.lerp(east, 0.5) + up, front_ridge, Ink, 2.0)
	var eave_w: Vector2 = west + up + Vector2(-3, 1)
	var eave_s: Vector2 = south + up + Vector2(0, 2)
	var eave_e: Vector2 = east + up + Vector2(3, 1)
	var eave_n: Vector2 = north + up + Vector2(0, 0)
	_poly(canvas, center, [back_ridge, front_ridge, eave_e, eave_n], roof.darkened(0.34))
	_poly(canvas, center, [back_ridge, front_ridge, eave_s, eave_w], roof)
	_roof_rows(canvas, center, back_ridge, front_ridge, eave_w, eave_s, roof)
	_stroke(canvas, center, eave_w, eave_s, Ink, 3.0)
	_stroke(canvas, center, eave_s, front_ridge, roof.lightened(0.24), 2.0)
	_stroke(canvas, center, front_ridge, eave_e, Ink, 2.0)
	_stroke(canvas, center, back_ridge, front_ridge, roof.lightened(0.28), 3.0)
	if mode == "home":
		_chimney(canvas, center + back_ridge.lerp(front_ridge, 0.28))
	if mode == "store":
		_stroke(canvas, center, south + Vector2(-7, 4), south + Vector2(7, -3), Color("#d7a269"), 4.0)
	canvas.art_scale = 1.0

# 屋瓦模块：顺坡的错缝纹理增强屋顶坡度与瓦片层次。
static func _roof_rows(canvas: Control, center: Vector2, ridge_a: Vector2, ridge_b: Vector2, eave_a: Vector2, eave_b: Vector2, roof: Color) -> void:
	for row: int in range(1, 5):
		var fraction: float = row * 0.2
		var a: Vector2 = ridge_a.lerp(eave_a, fraction)
		var b: Vector2 = ridge_b.lerp(eave_b, fraction)
		_stroke(canvas, center, a, b, roof.darkened(0.24), 1.4)
		for tile: int in range(4):
			var position: float = (tile + 0.4 + 0.35 * (row % 2)) / 4.0
			var seam: Vector2 = a.lerp(b, position)
			var upper: Vector2 = ridge_a.lerp(eave_a, fraction - 0.13).lerp(ridge_b.lerp(eave_b, fraction - 0.13), position)
			_stroke(canvas, center, seam, upper, roof.darkened(0.17), 1.0)

# 烟囱模块：民居烟囱使用侧面、顶部和盖沿。
static func _chimney(canvas: Control, center: Vector2) -> void:
	_pixel(canvas, center, Vector2(-3, -14), Vector2(8, 16), Color("#a2745c"))
	_pixel(canvas, center, Vector2(3, -13), Vector2(4, 13), Color("#62473c"))
	_poly(canvas, center, [Vector2(-5, -15), Vector2(1, -19), Vector2(8, -15), Vector2(2, -11)], Color("#c19374"))
	_pixel(canvas, center, Vector2(-1, -16), Vector2(5, 2), Ink)

# 塔楼模块：石墙、箭窗和垛口构成领主厅两翼的防卫结构。
static func _tower(canvas: Control, center: Vector2, span: int, height: int) -> void:
	var west: Vector2 = Vector2(-span, 0)
	var south: Vector2 = Vector2(0, span * 0.5)
	var east: Vector2 = Vector2(span, 0)
	var north: Vector2 = Vector2(0, -span * 0.5)
	var top: Vector2 = Vector2(0, -height)
	var stone: Color = Color("#ae9f86")
	_wall(canvas, center, west, south, height, stone, "stone", false)
	_wall(canvas, center, south, east, height, stone.darkened(0.23), "stone", false)
	_poly(canvas, center + top, [west, north, east, south], Color("#746d60"))
	_stroke(canvas, center + top, west, south, stone.lightened(0.16), 4.0)
	_stroke(canvas, center + top, south, east, stone, 4.0)
	for offset: Vector2 in [west, west.lerp(south, 0.52), south, south.lerp(east, 0.55), east]:
		_crate(canvas, center + top + offset - Vector2(0, 4), stone)

# 货箱模块：用三个明暗平面区分箱体，也作为塔楼垛口的石块。
static func _crate(canvas: Control, center: Vector2, color: Color = Color("#ac8054")) -> void:
	_poly(canvas, center, [Vector2(-5, -3), Vector2(0, 0), Vector2(0, 6), Vector2(-5, 3)], color)
	_poly(canvas, center, [Vector2(0, 0), Vector2(5, -3), Vector2(5, 3), Vector2(0, 6)], color.darkened(0.33))
	_poly(canvas, center, [Vector2(-5, -3), Vector2(0, -6), Vector2(5, -3), Vector2(0, 0)], color.lightened(0.19))


# 旗帜模块：领主厅和军营用醒目的旗帜识别。
static func _flag(canvas: Control, center: Vector2, color: Color) -> void:
	_pixel(canvas, center, Vector2.ZERO, Vector2(2, 15), Color("#ddc285"))
	_poly(canvas, center, [Vector2(2, 1), Vector2(17, 1), Vector2(13, 5), Vector2(17, 9), Vector2(2, 9)], color)

# 农田模块：把错落的田垄铺开至四格宽的耕地，地面路径贯穿田间。
static func _fields(canvas: Control, center: Vector2) -> void:
	for row: int in range(10):
		var offset: Vector2 = Vector2(-94 + row * 12, -1 + row * 6)
		var length: float = 88.0
		_poly(canvas, center + offset, [Vector2.ZERO, Vector2(length, -length * 0.5), Vector2(length + 9, -length * 0.5 + 4), Vector2(9, 4)], Color("#60452f"))
		if canvas.zoom_level < 0.6:
			_stroke(canvas, center, offset + Vector2(5, -2), offset + Vector2(length - 4, -length * 0.5), Color("#a7ad5c"), 3.2)
			continue
		for crop: int in range(11):
			var seed: Vector2 = offset + Vector2(6 + crop * 7, -1 - crop * 3.5)
			_stroke(canvas, center, seed, seed - Vector2(0, 6 + (row + crop) % 3), Color("#d3c365") if row % 2 == 0 else Color("#a7ad5c"), 2.8)

# 牧场模块：以整块占地为围栏，远栏、畜棚、牲畜和近栏按层绘制。
static func _ranch(canvas: Control, center: Vector2, spread: float) -> void:
	_poly(canvas, center, [Vector2(-113, 0) * spread, Vector2(0, -55) * spread, Vector2(113, 0) * spread, Vector2(0, 55) * spread], Color("#647a48"))
	for tuft: int in range(38):
		var x: int = (tuft * 31 % 160) - 80
		var y: int = (tuft * 17 % 72) - 36
		if absf(x) / 106.0 + absf(y) / 51.0 < 0.92:
			_pixel(canvas, center, Vector2(x, y) * spread, Vector2(3, 1), Color("#91a15c"))
	_fence(canvas, center, false, spread)
	_house(canvas, center + Vector2(-41, -15) * spread, 26, 19, Color("#925543"), Color("#be8e61"), "timber", 3.0 if spread > 1.0 else 1.42)
	_crate(canvas, center + Vector2(-49, 0) * spread, Color("#c6a05d"))
	var trough: Vector2 = center + Vector2(50, 0) * (spread - 1.0)
	_poly(canvas, trough, [Vector2(48, -9), Vector2(69, -19), Vector2(81, -13), Vector2(60, -3)], Color("#594738"))
	_poly(canvas, trough, [Vector2(52, -10), Vector2(69, -17), Vector2(77, -13), Vector2(60, -6)], Color("#55819a"))
	_fence(canvas, center, true, spread)

# 动物绘制模块：在独立动画层按深度排列牛羊。
static func _ranch_animals(canvas: Control, center: Vector2, time: float, spread: float) -> void:
	var order: Array[Vector2] = []
	for index: int in range(5):
		order.append(Vector2(index, animal_position(index, time).y))
	order.sort_custom(_animal_behind)
	for entry: Vector2 in order:
		var index: int = int(entry.x)
		var at: Vector2 = animal_position(index, time)
		var direction: float = -1.0 if animal_position(index, time + 0.08).x < at.x else 1.0
		_animal(canvas, center + at * spread, index >= 3, direction, int(time * 8.0 + index) % 2)

# 路线模块：羊与牛沿围栏内不同的闭合路线移动。
static func animal_position(index: int, time: float) -> Vector2:
	var sheep: Array[Vector2] = [Vector2(-48, 10), Vector2(-18, 27), Vector2(16, 22), Vector2(5, 5), Vector2(-19, -3)]
	var cattle: Array[Vector2] = [Vector2(15, -15), Vector2(51, -4), Vector2(30, 18), Vector2(13, 8)]
	var path: Array[Vector2] = sheep if index < 3 else cattle
	var phase: float = time * (0.45 if index < 3 else 0.35) + index * 1.46
	var step: int = posmod(floori(phase), path.size())
	return path[step].lerp(path[(step + 1) % path.size()], fposmod(phase, 1.0))

# 练兵场模块：营房靠后，沙场、训练桩和操练队列保持可见。
static func _barracks(canvas: Control, center: Vector2, spread: float) -> void:
	var yard: Vector2 = drill_center(center, spread)
	_poly(canvas, yard, [Vector2(-66, 0) * spread, Vector2(1, -37) * spread, Vector2(66, 0) * spread, Vector2(-1, 37) * spread], Color("#b78a59"))
	_stroke(canvas, yard, Vector2(-66, 0) * spread, Vector2(-1, 37) * spread, Color("#d6aa72"), 3.0)
	_stroke(canvas, yard, Vector2(-1, 37) * spread, Vector2(66, 0) * spread, Color("#d6aa72"), 3.0)
	for line: int in range(4):
		var start: Vector2 = Vector2(-35 + line * 13, -2 + line * 6)
		_stroke(canvas, yard, start * spread, (start + Vector2(45, -22)) * spread, Color("#916844"), 1.6)
	_house(canvas, center + Vector2(-41, -13) * spread, 29, 27, Color("#9c473f"), Color("#bca384"), "stone", 3.0 if spread > 1.0 else 1.45)
	_flag(canvas, center + Vector2(-41, -13) * spread + Vector2(4, -51) * (2.8 if spread > 1.0 else 1.3), Color("#c96349"))
	for i: int in range(2):
		var post: Vector2 = Vector2(31 + i * 12, -10 + i * 7) * spread
		_stroke(canvas, yard, post, post - Vector2(0, 18), Color("#564033"), 4.0)
		_stroke(canvas, yard, post - Vector2(6, 12), post + Vector2(6, -12), Color("#e3b77b"), 3.0)

# 队列中心模块：地面与活动士兵共用练兵场摆放基准。
static func drill_center(center: Vector2, spread: float) -> Vector2:
	return center + (Vector2(24, 3) if spread > 1.0 else Vector2(19, 11))


# 活动物件模块：只重画实际有驻军的操练队伍和已完工牧场牲畜。
static func moving_units(canvas: Control, id: String, center: Vector2, time: float, troops: Vector2i, spread: float) -> void:
	if id == "b_ranch":
		_ranch_animals(canvas, center, time, spread)
		return
	var yard: Vector2 = drill_center(center, spread)
	var total: int = troops.x + troops.y
	for index: int in range(total):
		_drill_soldier(canvas, yard + drill_position(index, total, time) * minf(spread, 2.6), time, index, index >= troops.x)

# 操练节奏模块：按实际人数排成两列，预留每名士兵的站位。
static func drill_position(index: int, total: int, time: float) -> Vector2:
	var columns: int = maxi(1, ceili(total / 2.0))
	var row: int = floori(index / float(columns))
	var column: int = index % columns
	var stride: float = sin(time * 3.8 + index * 0.65) * 2.5
	var spacing: float = column - (columns - 1) * 0.5
	return Vector2(spacing * 17.0 - 11.0 + row * 9.0 + stride, spacing * 2.0 - 6.0 + row * 18.0 - stride * 0.35)

# 士兵绘制模块：头盔、盾牌和木质训练器械跟随操练动作。
static func _drill_soldier(canvas: Control, at: Vector2, time: float, index: int, trainee: bool) -> void:
	var step: float = sin(time * 7.6 + index * 0.8)
	var raised: bool = step > 0.2
	_pixel(canvas, at, Vector2(-6, 1), Vector2(13, 3), Color("#332c2460"))
	_stroke(canvas, at, Vector2(-3, -7), Vector2(-4 + step * 3.0, 2), Ink, 3.0)
	_stroke(canvas, at, Vector2(3, -7), Vector2(4 - step * 3.0, 2), Ink, 3.0)
	_pixel(canvas, at, Vector2(-5, -19), Vector2(11, 12), Ink)
	_pixel(canvas, at, Vector2(-4, -18), Vector2(8, 10), Color("#a68756") if trainee else Color("#a34f42"))
	_pixel(canvas, at, Vector2(-3, -24), Vector2(7, 7), Color("#c99870"))
	_pixel(canvas, at, Vector2(-4, -26), Vector2(9, 5), Color("#b49160") if trainee else Color("#abb0a3"))
	_pixel(canvas, at, Vector2(-8, -16), Vector2(7, 10), Color("#51677a"))
	_pixel(canvas, at, Vector2(-8, -14), Vector2(2, 6), Color("#a7ab99"))
	var weapon: Vector2 = Vector2(15, -30) if raised else Vector2(17, -8)
	_stroke(canvas, at, Vector2(4, -16), weapon, Color("#64432e"), 3.2)
	_stroke(canvas, at, Vector2(6, -17), weapon, Color("#dbb77d"), 1.4)

# 深度模块：按地面纵坐标绘制牛羊，避免远处覆盖近处。
static func _animal_behind(left: Vector2, right: Vector2) -> bool:
	return left.y < right.y

# 像素动物模块：体型、毛色、耳朵和步态让羊与牛在放大画面可辨认。
static func _animal(canvas: Control, at: Vector2, cow: bool, facing: float, step: int) -> void:
	var width: float = 24.0 if cow else 19.0
	var h: float = width * 0.5
	var coat: Color = Color("#a97955") if cow else Color("#e5d6b3")
	var dark: Color = Color("#49392f")
	_pixel(canvas, at, Vector2(-h, 1), Vector2(width + 3, 4), Color("#262c2480"))
	for leg: int in [-1, 1]:
		var stride: float = float(leg * (step * 2 - 1)) * 2.0
		_stroke(canvas, at, Vector2(leg * (h - 4), -5), Vector2(leg * (h - 4) + stride, 3), dark, 3.0)
	_poly(canvas, at, [Vector2(-h, -6), Vector2(-h, -13), Vector2(-h + 4, -17), Vector2(h - 3, -17), Vector2(h, -13), Vector2(h, -6), Vector2(h - 4, -3), Vector2(-h + 4, -3)], dark)
	_pixel(canvas, at, Vector2(-h + 2, -13), Vector2(width - 4, 8), coat)
	_pixel(canvas, at, Vector2(-h + 4, -16), Vector2(width - 8, 4), coat.lightened(0.16))
	var head: Vector2 = Vector2(facing * (h + 1), -9)
	_pixel(canvas, at + head, Vector2(-4, -6), Vector2(9, 8), dark)
	_pixel(canvas, at + head, Vector2(-3, 0), Vector2(8, 4), coat.darkened(0.19))
	_pixel(canvas, at + head, Vector2(facing * 2, -4), Vector2(2, 2), Color("#faf0d7"))
	if cow:
		_pixel(canvas, at + head, Vector2(-6, -7), Vector2(3, 3), Color("#eee0bb"))
		_pixel(canvas, at + head, Vector2(4, -7), Vector2(3, 3), Color("#eee0bb"))
		_pixel(canvas, at, Vector2(-5, -13), Vector2(6, 7), Color("#69492f"))
	else:
		_pixel(canvas, at, Vector2(-5, -18), Vector2(7, 3), Color("#f0e2c3"))

# 围栏模块：前后两半分层，使用斜向木梁和重复立柱。
static func _fence(canvas: Control, center: Vector2, front: bool, spread: float) -> void:
	var corner: Vector2 = Vector2(0, 51 if front else -51) * spread
	for side: Vector2 in [Vector2(-106, 0) * spread, Vector2(106, 0) * spread]:
		for level: int in [-5, -11]:
			var lift: Vector2 = Vector2(0, level)
			_stroke(canvas, center, side + lift, corner + lift, Color("#b18b59") if front else Color("#8b7048"), 3.0)
		var posts: int = int(4 * spread)
		for post: int in range(posts + 1):
			var at: Vector2 = side.lerp(corner, post / float(posts))
			_stroke(canvas, center, at, at - Vector2(0, 15), Color("#d2ac73") if front else Color("#a68456"), 4.0)

# 木料模块：绘制原木侧面与端面，可用于工地和伐木场。
static func _logs(canvas: Control, center: Vector2) -> void:
	for offset: Vector2 in [Vector2(-8, 0), Vector2(1, 4), Vector2(-2, -5)]:
		_poly(canvas, center + offset, [Vector2(0, 0), Vector2(18, -8), Vector2(23, -5), Vector2(5, 4)], Color("#8c583c"))
		_pixel(canvas, center + offset, Vector2(0, -1), Vector2(5, 6), Color("#d5a365"))
