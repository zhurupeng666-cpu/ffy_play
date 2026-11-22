## 文件用途：为城镇等距地图绘制统一配色的地形、资源、工地和建筑图形。
extends RefCounted

const Grid = preload("res://scripts/isometric_grid.gd")
const Ink: Color = Color("#283025")
const Grass: Array[Color] = [Color("#526c3d"), Color("#587343"), Color("#5d7846"), Color("#567140")]
const Water: Array[Color] = [Color("#24546a"), Color("#285b71"), Color("#2c6176")]

# 轮廓模块：图形先以世界像素绘制，再使用城镇镜头变换。
static func _poly(canvas: Control, center: Vector2, offsets: Array, color: Color) -> void:
	var points: PackedVector2Array = []
	for offset: Vector2 in offsets:
		points.append(canvas.world_to_screen(center + offset).round())
	canvas.draw_colored_polygon(points, color)

# 细节模块：小矩形跟随镜头缩放，使用整数屏幕坐标对齐。
static func _pixel(canvas: Control, center: Vector2, offset: Vector2, extent: Vector2, color: Color) -> void:
	var start: Vector2 = canvas.world_to_screen(center + offset).round()
	var end: Vector2 = canvas.world_to_screen(center + offset + extent).round()
	canvas.draw_rect(Rect2(start, end - start), color)

# 地块模块：草地采用固定纹理变化，河格绘制浅滩和水纹。
static func terrain(canvas: Control, cell: Vector2i, points: PackedVector2Array, water: bool) -> void:
	var seed: int = posmod(cell.x * 17 + cell.y * 29, 31)
	var center: Vector2 = Grid.cell_to_world(cell)
	if water:
		canvas.draw_colored_polygon(points, Water[seed % Water.size()])
		_poly(canvas, center, [Vector2(0, 16), Vector2(32, 0), Vector2(27, 0), Vector2(-3, 14)], Color("#508391"))
		_pixel(canvas, center, Vector2(seed % 12 - 12, -4), Vector2(12, 2), Color("#4a8a9a"))
		_pixel(canvas, center, Vector2(0, 4), Vector2(10, 2), Color("#396f82"))
	else:
		canvas.draw_colored_polygon(points, Grass[seed % Grass.size()])
		_pixel(canvas, center, Vector2(seed % 22 - 13, seed % 7 - 6), Vector2(4, 2), Color("#799653"))
		_pixel(canvas, center, Vector2(9 - seed % 17, 3), Vector2(3, 2), Color("#455932"))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, Color("#24382465"), 1.0, false)

# 林矿模块：用树冠、树干与分面岩石表达资源，轮廓不参与点击判断。
static func deposit(canvas: Control, center: Vector2, kind: String) -> void:
	if kind == "forest":
		_tree(canvas, center + Vector2(-10, -3), Color("#315738"))
		_tree(canvas, center + Vector2(10, 0), Color("#3b6741"))
		_tree(canvas, center + Vector2(-1, 7), Color("#447447"))
	elif kind == "stone":
		_rock(canvas, center + Vector2(-8, 4))
		_rock(canvas, center + Vector2(8, -1))

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

# 建筑模块：所有类型都有单独的轮廓或用途细节。
static func building(canvas: Control, id: String, center: Vector2) -> void:
	match id:
		"b_hall":
			_house(canvas, center + Vector2(0, 4), 32, 28, Color("#577896"), Color("#d0b990"))
			_house(canvas, center + Vector2(-23, 5), 12, 21, Color("#526881"), Color("#b2a488"))
			_house(canvas, center + Vector2(23, 5), 12, 21, Color("#526881"), Color("#b2a488"))
			_flag(canvas, center + Vector2(-4, -54), Color("#b44d40"))
		"b_house":
			_house(canvas, center, 25, 19, Color("#a45b43"), Color("#d6bc88"))
		"b_farm":
			_fields(canvas, center)
			_house(canvas, center + Vector2(-22, -16), 13, 11, Color("#a05e41"), Color("#c09a66"))
		"b_ranch":
			_fence(canvas, center)
			_house(canvas, center + Vector2(-23, -14), 17, 14, Color("#815048"), Color("#ba9765"))
			_pixel(canvas, center, Vector2(5, -3), Vector2(12, 7), Color("#e2cbb0"))
			_pixel(canvas, center, Vector2(2, -2), Vector2(5, 4), Color("#714b38"))
		"b_barracks":
			_house(canvas, center + Vector2(0, 4), 29, 22, Color("#9e4842"), Color("#af9b7d"))
			_flag(canvas, center + Vector2(7, -40), Color("#d3674e"))
		"b_granary":
			_house(canvas, center + Vector2(0, -4), 24, 21, Color("#aa8041"), Color("#c6a16d"))
			for offset: Vector2 in [Vector2(-16, 8), Vector2(-7, 13), Vector2(15, 5)]:
				_pixel(canvas, center, offset, Vector2(8, 7), Color("#dfb560"))
		"b_lumber":
			_house(canvas, center + Vector2(-12, -6), 19, 15, Color("#547045"), Color("#ac8457"))
			_logs(canvas, center + Vector2(12, 9))
		"b_quarry":
			_house(canvas, center + Vector2(-13, -5), 16, 12, Color("#686f72"), Color("#b8ab86"))
			_rock(canvas, center + Vector2(12, 8))
			_rock(canvas, center + Vector2(-1, 15))
		"b_fishery":
			_poly(canvas, center, [Vector2(-27, 2), Vector2(5, -13), Vector2(29, -1), Vector2(-4, 15)], Color("#956d47"))
			for i: int in range(4):
				_pixel(canvas, center, Vector2(-19 + i * 9, 4 - i * 4), Vector2(7, 2), Color("#cda66c"))
			_house(canvas, center + Vector2(7, -8), 17, 14, Color("#43778a"), Color("#c6ae7f"))

# 房屋模块：等距墙面由同一屋基推导，屋顶和立面各有深浅面。
static func _house(canvas: Control, center: Vector2, span: int, height: int, roof: Color, wall: Color) -> void:
	var west: Vector2 = Vector2(-span, 0)
	var south: Vector2 = Vector2(0, span * 0.5)
	var east: Vector2 = Vector2(span, 0)
	var north: Vector2 = Vector2(0, -span * 0.5)
	var up: Vector2 = Vector2(0, -height)
	var ridge: Vector2 = Vector2(0, -span * 0.48)
	_poly(canvas, center + Vector2(4, 5), [west, north, east, south], Color("#22352266"))
	_poly(canvas, center, [west, south, south + up, west + up], wall)
	_poly(canvas, center, [south, east, east + up, south + up], wall.darkened(0.28))
	_poly(canvas, center + up, [west, north, north + ridge, west + ridge], roof.darkened(0.28))
	_poly(canvas, center + up, [west, south, east, east + ridge, west + ridge], roof)
	_poly(canvas, center + up, [east, north, north + ridge, east + ridge], roof.darkened(0.38))
	_poly(canvas, center + up, [west + ridge, east + ridge, east + ridge + Vector2(0, 2), west + ridge + Vector2(0, 2)], roof.lightened(0.21))
	_pixel(canvas, center, Vector2(-span * 0.36, 1), Vector2(6, 8), Ink)
	_pixel(canvas, center, Vector2(-span * 0.72, -height * 0.38), Vector2(5, 5), Color("#e6b462"))
	_pixel(canvas, center, Vector2(span * 0.49, -height * 0.3), Vector2(5, 4), Color("#715b45"))

# 旗帜模块：领主厅和军营用醒目的旗帜识别。
static func _flag(canvas: Control, center: Vector2, color: Color) -> void:
	_pixel(canvas, center, Vector2.ZERO, Vector2(2, 15), Color("#ddc285"))
	_poly(canvas, center, [Vector2(2, 1), Vector2(17, 1), Vector2(13, 5), Vector2(17, 9), Vector2(2, 9)], color)

# 农田模块：并排种植条带区分耕地和普通建筑地面。
static func _fields(canvas: Control, center: Vector2) -> void:
	for i: int in range(6):
		var at: Vector2 = Vector2(-35 + i * 10, -7 + i * 5)
		_poly(canvas, center + at, [Vector2(0, 0), Vector2(36, -18), Vector2(44, -14), Vector2(8, 4)], Color("#806345"))
		_poly(canvas, center + at, [Vector2(3, -1), Vector2(36, -17), Vector2(39, -15), Vector2(6, 0)], Color("#bac05a") if i % 2 == 0 else Color("#91a65a"))

# 牧场模块：沿菱形边界设置木质围栏。
static func _fence(canvas: Control, center: Vector2) -> void:
	var outline: PackedVector2Array = []
	for offset: Vector2 in [Vector2(-38, 2), Vector2(0, -17), Vector2(38, 2), Vector2(0, 21), Vector2(-38, 2)]:
		outline.append(canvas.world_to_screen(center + offset))
		_pixel(canvas, center, offset - Vector2(1, 5), Vector2(3, 8), Color("#c6a374"))
	canvas.draw_polyline(outline, Color("#a98655"), 2.0, false)

# 木料模块：绘制原木侧面与端面，可用于工地和伐木场。
static func _logs(canvas: Control, center: Vector2) -> void:
	for offset: Vector2 in [Vector2(-8, 0), Vector2(1, 4), Vector2(-2, -5)]:
		_poly(canvas, center + offset, [Vector2(0, 0), Vector2(18, -8), Vector2(23, -5), Vector2(5, 4)], Color("#8c583c"))
		_pixel(canvas, center + offset, Vector2(0, -1), Vector2(5, 6), Color("#d5a365"))
