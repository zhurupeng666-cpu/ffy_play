## 文件用途：配置林地村落和旧堡小城的建筑、公共设施、道路与驻军。
extends RefCounted

const Art = preload("res://scripts/town_art.gd")
const Grid = preload("res://scripts/isometric_grid.gd")
const LAYOUT = preload("res://data/regions/frontier.tres")
const IDS: Array[String] = ["r_woods", "r_fort"]
const EXTENT: int = 21
# 街区配置：设施锚点相对街心，旧堡另有一条紧凑的工匠街。
const FORT_OFFSETS: Dictionary = {"mill": Vector2i(13, 11), "forge": Vector2i(4, -17), "ranch": Vector2i(3, 10), "inn": Vector2i(15, 17), "clinic": Vector2i(11, 4)}
const BUILDINGS: Array[Array] = [
	["hall", "议事厅", "b_hall", Vector2i(-8, -12), Vector2i(5, 5)],
	["barracks", "驻军营房", "b_barracks", Vector2i(-19, -15), Vector2i(8, 8)],
	["grain", "粮仓", "b_granary", Vector2i(4, -10), Vector2i(4, 4)],
	["store", "补给库", "b_granary", Vector2i(11, -10), Vector2i(4, 4)],
	["mill", "磨坊", "mill", Vector2i(5, -18), Vector2i(5, 5)],
	["forge", "铁匠工坊", "forge", Vector2i(13, -18), Vector2i(5, 5)],
	["market", "集市", "market", Vector2i(-7, 4), Vector2i(6, 6)],
	["well", "公共水井", "well", Vector2i(3, 3), Vector2i(2, 2)],
	["clinic", "医馆", "clinic", Vector2i(6, 4), Vector2i(4, 4)],
	["stable", "驿站马厩", "stable", Vector2i(-17, 3), Vector2i(6, 5)],
	["farm", "农田", "field", Vector2i(-19, 10), Vector2i(8, 8)],
	["ranch", "牧场", "b_ranch", Vector2i(11, 10), Vector2i(8, 8)],
	["home_west", "民居", "b_house", Vector2i(-16, -5), Vector2i(3, 3)],
	["home_south", "民居", "b_house", Vector2i(-6, 13), Vector2i(3, 3)],
	["home_east", "民居", "b_house", Vector2i(16, 2), Vector2i(3, 3)],
	["home_north", "民居", "b_house", Vector2i(-9, -20), Vector2i(3, 3)],
	["home_market", "民居", "b_house", Vector2i(-8, 18), Vector2i(3, 3)],
	["inn", "旅店", "inn", Vector2i(5, 17), Vector2i(4, 4)],
	["tower_nw", "东北哨塔", "tower", Vector2i(19, -21), Vector2i(3, 3)],
	["tower_se", "西南哨塔", "tower", Vector2i(-21, 19), Vector2i(3, 3)],
	["gate", "南门", "gate", Vector2i(-2, 19), Vector2i(5, 3)],
]


# 占地模块：所有据点的范围与建筑、道路共用同一个锚点。
static func bounds(id: String) -> Rect2i:
	var cell: Vector2i = LAYOUT.regions[id]["position"]
	return Rect2i(cell - Vector2i.ONE * EXTENT, Vector2i.ONE * (EXTENT * 2 + 1))


# 预留模块：禁止城镇建筑覆盖村镇设施，也给外围地形提供建成区标记。
static func overlaps(area: Rect2i) -> bool:
	for id: String in IDS:
		if bounds(id).intersects(area):
			return true
	return false


# 街区模块：构造地图自己的静态建筑标识，选中时只展示对应设施。
static func buildings(id: String) -> Dictionary:
	var center: Vector2i = LAYOUT.regions[id]["position"]
	var result: Dictionary = {}
	for entry: Array in BUILDINGS:
		var key: String = id + "/" + entry[0]
		var offset: Vector2i = FORT_OFFSETS.get(entry[0], entry[3]) if id == "r_fort" else entry[3]
		var cell: Vector2i = center + offset
		var title: String = entry[1]
		if entry[0] == "hall":
			title = "林地议事厅" if id == "r_woods" else "旧堡镇政厅"
		result[key] = {"id": key, "region": id, "title": title, "def_id": entry[2], "cell": [cell.x, cell.y], "size": entry[4]}
	return result


# 市镇地面：用小路连接城门、中心广场和农牧区，保留街区之间的草地。
static func draw_ground(canvas: Control, id: String) -> void:
	var center: Vector2i = LAYOUT.regions[id]["position"]
	var stone: bool = id == "r_fort"
	var road: Color = Color("#8a8573") if stone else Color("#9b7d51")
	for strip: Rect2i in [Rect2i(-1, -20, 3, 45), Rect2i(-20, -1, 41, 3), Rect2i(-8, 3, 20, 6), Rect2i(-19, 8, 38, 2)]:
		canvas.art_canvas.draw_colored_polygon(canvas._footprint_outline(center + strip.position, strip.size, true), road)
	var west := Vector2i(-21, -21)
	var east := Vector2i(21, -21)
	var front := Vector2i(21, 21)
	var left := Vector2i(-21, 21)
	_wall(canvas, center, west, east, stone)
	_wall(canvas, center, west, left, stone)
	_wall(canvas, center, east, front, stone)
	_wall(canvas, center, left, Vector2i(-3, 21), stone)
	_wall(canvas, center, Vector2i(3, 21), front, stone)


# 围墙模块：以格为单位画石墙和木栅栏，墙段沿城镇边界连续排列。
static func _wall(canvas: Control, center: Vector2i, start: Vector2i, end: Vector2i, stone: bool) -> void:
	var a: Vector2 = Grid.cell_to_world(center + start)
	var b: Vector2 = Grid.cell_to_world(center + end)
	var height: float = 30.0 if stone else 20.0
	var top := Vector2(0, -height)
	var paint: Color = Color("#737b76") if stone else Color("#75573a")
	Art._poly(canvas, a, [Vector2.ZERO, b - a, b - a + top, top], paint)
	Art._stroke(canvas, a, top, b - a + top, paint.lightened(0.26), 3.0)
	var segments: int = maxi(absi(end.x - start.x), absi(end.y - start.y))
	for index: int in range(segments):
		var post: Vector2 = (b - a) * (float(index) / segments)
		Art._stroke(canvas, a, post, post + top - Vector2(0, 5), paint.darkened(0.3), 3.0)
		if stone:
			Art._stroke(canvas, a, post + top, post + top - Vector2(0, 6), paint.lightened(0.35), 10.0)


# 设施模块：使用既有像素房屋造型，并为市场、水井、磨坊等绘制辨识细节。
static func draw_building(canvas: Control, record: Dictionary, at: Vector2, guards: int) -> void:
	var kind: String = record["def_id"]
	var stone: bool = record["region"] == "r_fort"
	match kind:
		"field":
			for plot: Vector2i in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
				Art._fields(canvas, at + Grid.cell_to_world(plot))
		"market":
			Art._market(canvas, at, 1.0)
		"well":
			Art._house(canvas, at, 17, 18, Color("#46666b"), Color("#97958c"), "stone", 1.08)
			Art._poly(canvas, at, [Vector2(-17, 8), Vector2(0, 0), Vector2(17, 8), Vector2(0, 16)], Color("#559798"))
		"tower":
			_tower(canvas, at, stone)
		"gate":
			_tower(canvas, at + Grid.cell_to_world(Vector2i(-2, 0)), stone)
			_tower(canvas, at + Grid.cell_to_world(Vector2i(2, 0)), stone)
			Art._flag(canvas, at - Vector2(0, 53), Color("#568e9d") if guards == 0 else Color("#b74f41"))
		"b_hall":
			Art._house(canvas, at, 50, 41, Color("#586d83") if stone else Color("#976342"), Color("#b9a282"), "stone" if stone else "timber", 1.95)
			Art._flag(canvas, at - Vector2(0, 120), Color("#568e9d") if guards == 0 else Color("#b74f41"))
		"mill", "forge", "clinic", "stable", "inn":
			var roofs: Dictionary = {"mill": Color("#a6824a"), "forge": Color("#78514a"), "clinic": Color("#537b78"), "stable": Color("#845e3e"), "inn": Color("#b26640")}
			Art._house(canvas, at, 37, 27, roofs[kind], Color("#b89d76"), "stone" if stone else "timber", 1.65)
			if kind == "mill":
				for direction: Vector2 in [Vector2(-23, -23), Vector2(21, -23), Vector2(-23, 23), Vector2(21, 23)]:
					Art._stroke(canvas, at, Vector2(24, -50), Vector2(24, -50) + direction, Color("#dfcd96"), 5.0)
			else:
				Art._crate(canvas, at + Vector2(28, 16))
		_:
			Art.building(canvas, kind, at)
			if kind == "b_barracks":
				for index: int in range(guards):
					Art._drill_soldier(canvas, at + Vector2((index - 2.5) * 24, 43 + index * 4), 0.0, index, false)
			elif kind == "b_ranch":
				Art.moving_units(canvas, kind, at, 0.0, Vector2i.ZERO, 1.0)


# 哨楼模块：村落使用木岗楼，旧堡使用石塔。
static func _tower(canvas: Control, at: Vector2, stone: bool) -> void:
	if stone:
		Art._tower(canvas, at, 24, 66)
	else:
		Art._house(canvas, at, 20, 35, Color("#684735"), Color("#aa8350"), "timber", 1.40)
