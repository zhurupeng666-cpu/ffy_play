## 文件用途：用等距像素绘制皇城、重檐楼门、外城墙与可观察的府邸院落。
extends RefCounted

const Layout = preload("res://scripts/capital_layout.gd")
const Grid = Layout.Grid
const Art = preload("res://scripts/town_art.gd")
const Courts = preload("res://scripts/palace_courtyards.gd")
const GOLD := Color("#cc9c41")
const JADE := Color("#568671")
const RUBY := Color("#995649")


# 地面模块：皇家禁地使用石砖广场，外城主干道保留宽路肩和中线。
static func ground(canvas: Control, view: Rect2) -> void:
	if _visible(canvas, Layout.INNER, view):
		_tile(canvas, Layout.INNER, Color("#b2a082"))
		for x: int in range(Layout.INNER.position.x + 6, Layout.INNER.end.x, 9):
			Art._stroke(canvas, Grid.cell_to_world(Vector2i(x, Layout.INNER.position.y)), Vector2.ZERO,
				Grid.cell_to_world(Vector2i(0, Layout.INNER.size.y - 1)), Color("#a89677"), 3.0)
	for road: Rect2i in Layout.BOULEVARDS:
		if not _visible(canvas, road, view):
			continue
		_tile(canvas, road, Color("#897963"))
		var stone: Rect2i = road.grow(-1)
		_tile(canvas, stone, Color("#c0ad8b"))
		if road.size.x > road.size.y:
			_tile(canvas, Rect2i(road.position + Vector2i(0, road.size.y / 2), Vector2i(road.size.x, 1)), Color("#d3bf97"))
		else:
			_tile(canvas, Rect2i(road.position + Vector2i(road.size.x / 2, 0), Vector2i(1, road.size.y)), Color("#d3bf97"))


# 城墙模块：长墙按区块裁剪，拐角、墙台和女墙保有可辨识的轮廓。
static func walls(canvas: Control, view: Rect2, palace: bool) -> void:
	var bounds: Rect2i = Layout.INNER if palace else Layout.OUTER
	var main: Color = Color("#923f35") if palace else Color("#737676")
	var rim: Color = Color("#c58d55") if palace else Color("#adb3ad")
	for wall: Rect2i in Layout.walls(bounds, palace):
		var long_x: bool = wall.size.x > wall.size.y
		var count: int = wall.size.x if long_x else wall.size.y
		for index: int in range(0, count, 18):
			var offset := Vector2i(index, 0) if long_x else Vector2i(0, index)
			var length: int = mini(18, count - index)
			var span := Vector2i(length, wall.size.y) if long_x else Vector2i(wall.size.x, length)
			var segment := Rect2i(wall.position + offset, span)
			if not _visible(canvas, segment, view):
				continue
			var high: float = 80.0 if palace else 102.0
			_box(canvas, segment, 0.0, high, main, rim)
			for merlon: int in range(0, length, 3):
				var edge := Vector2i(merlon, span.y - 1) if long_x else Vector2i(span.x - 1, merlon)
				_box(canvas, Rect2i(segment.position + edge, Vector2i.ONE), high, 18.0, main.lightened(0.12), rim)


# 地标模块：前朝、后宫、祀典、园林与内务使用不同形制。
static func landmark(canvas: Control, record: Dictionary) -> void:
	var area := Rect2i(Vector2i(record["cell"][0],record["cell"][1]), record["size"])
	match record["def_id"]:
		"gate_ns", "gate_ew":
			_gate(canvas, area, record["def_id"] == "gate_ns", not record["id"].begins_with("capital/palace_"))
		"garden":
			_garden(canvas, area)
		"residence":
			_tile(canvas, area, Color("#9f755d"))
			for row: int in range(3):
				for column: int in range(2):
					_manor_court(canvas, Rect2i(area.position + Vector2i(column * 14, row * 9), Vector2i(13,8)), RUBY)
		"altar":
			_tile(canvas, area, Color("#8f9674"))
			var stage := Rect2i(area.position + Vector2i(7,3), Vector2i(13,8))
			_box(canvas, stage, 0.0, 32.0, Color("#9a8880"), Color("#d4ba96"))
			_box(canvas, stage.grow(-2), 32.0, 24.0, Color("#a48d72"), Color("#dbc99c"))
			_hall(canvas, Rect2i(area.position + Vector2i(1,2), Vector2i(4,8)), RUBY, 42.0, false)
			_hall(canvas, Rect2i(area.end - Vector2i(6,11), Vector2i(5,8)), RUBY, 42.0, false)
		_:
			var royal: bool = record["def_id"] in ["ruby", "gold"]
			var roof: Color = GOLD if record["def_id"] == "gold" else (RUBY if record["def_id"] == "ruby" else JADE)
			_tile(canvas, area, Color("#d2c3a5") if royal else Color("#a39378"))
			var main: Rect2i = area.grow(-1)
			if canvas.palace_cutaway and record["def_id"] in ["ruby","gold","jade","service"] and area.size.x >= 10:
				_room(canvas, main, record["id"])
			else:
				_hall(canvas, main, roof, float(clampi(area.size.y * 9, 48, 155)), royal)
			if area.size.x >= 18:
				for offset: Vector2i in [Vector2i(2, area.size.y - 2), Vector2i(area.size.x - 3, area.size.y - 2)]:
					_incense(canvas, area.position + offset)


# 内景模块：揭开屋顶后显示不同用途的家具、隔扇、地毯和矮墙。
static func _room(canvas: Control, area: Rect2i, id: String) -> void:
	var residential: bool = id.ends_with("/living") or id.ends_with("/queen") or id.ends_with("/dowager") or id.ends_with("/retirement")
	var primary: bool = id.ends_with("/ceremony")
	var fabric: Color = Color("#a24d39") if primary else (Color("#687d69") if residential else Color("#6e8292"))
	_box(canvas, area, 0, 16, Color("#87775f"), Color("#cfb78e"))
	_box(canvas, Rect2i(area.position,Vector2i(area.size.x,1)), 16, 58, Color("#8e4741"), Color("#b8795d"))
	_box(canvas, Rect2i(area.position,Vector2i(1,area.size.y)), 16, 37, Color("#ab6650"), Color("#be8d70"))
	var mid: int = floori(area.size.x / 2.0)
	var aisle := Rect2i(area.position + Vector2i(mid-1,2),Vector2i(3,area.size.y-2))
	_box(canvas, aisle, 16, 2, fabric.darkened(0.28), fabric)
	var dais := Rect2i(area.position + Vector2i(mid-1,1),Vector2i(3,2))
	for y: int in range(3, area.size.y - 1, 2):
		for x: int in [mid-1,mid+1]:
			_box(canvas,Rect2i(area.position+Vector2i(x,y),Vector2i.ONE),18,2,fabric,Color("#d4b572"))
	if primary:
		_box(canvas,dais,16,24,Color("#9f6c3c"),Color("#d3a658"))
		_box(canvas,Rect2i(dais.position + Vector2i(1,0),Vector2i(1,2)),40,35,Color("#a56338"),Color("#ebb26e"))
		for x: int in [mid-3,mid+3]:
			_box(canvas,Rect2i(area.position + Vector2i(x,1),Vector2i(1,2)),16,48,Color("#704c43"),Color("#d6a76d"))
	elif residential:
		_box(canvas,dais,16,26,Color("#8f6051"),Color("#bb8580"))
		_box(canvas,Rect2i(dais.position + Vector2i(0,1),Vector2i(3,1)),42,6,Color("#c19367"),Color("#edbe8f"))
	else:
		_box(canvas,dais,16,26,Color("#775042"),Color("#b0835a"))
	for x: int in [2, area.size.x - 3]:
		for y: int in range(2,area.size.y-1,3):
			var cell: Vector2i = area.position + Vector2i(x,y)
			_box(canvas,Rect2i(cell,Vector2i.ONE),16,18,Color("#7e563e"),Color("#af8357"))
			_box(canvas,Rect2i(cell,Vector2i.ONE),34,13 if y == 2 else 4,Color("#81694c"),Color("#6d9e88") if y == 2 else Color("#c1aa7e"))
			if area.size.x >= 12:
				var chair: Vector2i = cell + (Vector2i.RIGHT if x == 2 else Vector2i.LEFT)
				_box(canvas,Rect2i(chair,Vector2i.ONE),16,12,Color("#634336"),Color("#a36d52"))


# 院落模块：地砖和独立陈设均是真实地图格子，摆放后立刻重画。
static func courts(canvas: Control, view: Rect2, layout: Dictionary) -> void:
	var colors: Array[Color] = [Color("#9eacad"),Color("#c8b295"),Color("#829274")]
	for i: int in range(Courts.AREAS.size()):
		var area: Rect2i = Courts.AREAS[i]
		if not _visible(canvas,area,view):
			continue
		_tile(canvas,area,colors[layout["styles"][i]].darkened(0.24))
		_tile(canvas,area.grow(-1),colors[layout["styles"][i]])
		var plaza := Rect2i(area.position + Vector2i(area.size.x / 2,0),Vector2i(1,area.size.y))
		_tile(canvas,plaza,colors[layout["styles"][i]].lightened(0.25))
		if i == 3:
			_box(canvas,Rect2i(area.position,Vector2i(area.size.x,1)),0,38,RUBY,Color("#bf967a"))
			_box(canvas,Rect2i(area.position,Vector2i(1,area.size.y)),0,28,RUBY,Color("#bf967a"))
	var ordered: Array = layout["items"].duplicate()
	ordered.sort_custom(func(a: Array,b: Array) -> bool: return a[1]+a[2] < b[1]+b[2])
	for item: Array in ordered:
		var area := Rect2i(Vector2i(item[1],item[2]),Courts.size_for(item[0]))
		if _visible(canvas,area,view):
			_ornament(canvas,area,item[0])


# 陈设模块：用各自的体块和色彩区分石灯、盆景、石几、池、亭、屏风。
static func _ornament(canvas: Control, area: Rect2i, kind: int) -> void:
	match kind:
		0:
			_box(canvas,area,0,12,Color("#676e6a"),Color("#b9c3ac"))
			_box(canvas,area,14,37,Color("#8e8170"),Color("#e9c867"))
			_roof(canvas,area,57,JADE,9)
		1:
			_box(canvas,area,0,15,RUBY,Color("#836541"))
			Art.deposit(canvas,Grid.cell_to_world(area.position) - Vector2(0,15),"forest")
		2:
			_box(canvas,area,0,22,Color("#777e78"),Color("#c2bbad"))
		3:
			_tile(canvas,area,Color("#a6b0a4"))
			_tile(canvas,area.grow(-1),Color("#55938f"))
			_box(canvas,Rect2i(area.position+Vector2i.ONE,Vector2i.ONE),0,3,Color("#478c79"),Color("#80a76f"))
		4:
			_hall(canvas,area,JADE,58,true)
		5:
			_box(canvas,area,0,47,Color("#8c5843"),Color("#c49763"))


# 北南门与东西门保留中间门洞，门楼以横跨洞口的台梁连接两座墩台。
static func _gate(canvas: Control, area: Rect2i, ns: bool, outer: bool) -> void:
	var main: Color = Color("#6e7474") if outer else Color("#a74f42")
	var rim: Color = Color("#b7b4a3")
	var plaza: Rect2i = area.grow(1)
	_tile(canvas, plaza, Color("#b6a389"))
	var one: Rect2i = Rect2i(area.position, Vector2i(5, area.size.y)) if ns else Rect2i(area.position, Vector2i(area.size.x, 5))
	var two: Rect2i = Rect2i(Vector2i(area.end.x - 5, area.position.y), one.size) if ns else Rect2i(Vector2i(area.position.x, area.end.y - 5), one.size)
	_box(canvas, one, 0.0, 105.0, main, rim)
	_box(canvas, two, 0.0, 105.0, main, rim)
	_box(canvas,area.grow(-1),105.0,30.0,main,rim)
	var pavilion: Rect2i = area.grow(-3)
	var roof: Color = GOLD if not outer else Color("#586568")
	_box(canvas,pavilion,135.0,62.0,Color("#884e3e"),Color("#a18969"))
	var corners: PackedVector2Array = canvas._footprint_outline(pavilion.position,pavilion.size,true)
	for face: int in range(1,3):
		var left: Vector2 = corners[face]
		var right: Vector2 = corners[face+1]
		for index: int in range(1,6):
			var slot: float = index/7.0
			Art._wall_opening(canvas,Vector2.ZERO,left,right,slot,slot+0.095,149,182,Color("#c19a68"),false)
	_roof(canvas,area.grow(-1),197.0,roof,40.0)
	_roof(canvas,pavilion,237.0,roof.lightened(0.12),26.0)
	var mast: Vector2 = Grid.cell_to_world(area.position + Vector2i(2,2))
	Art._flag(canvas, mast - Vector2(0, 103), Color("#ac533a"))


# 府邸模块：十五格院区包含正厅、东西厢房、穿院路、水池与植栽。
static func manor(canvas: Control, cell: Vector2i, extent: Vector2i, noble: bool, front: int = 0) -> void:
	if extent.x < 15:
		Art.building(canvas, "b_manor", Grid.cell_to_world(cell) + Grid.cell_to_world(extent - Vector2i.ONE) * 0.5)
		return
	var area := Rect2i(cell, extent)
	_tile(canvas, area, Color("#a99573"))
	var color: Color = JADE if noble else RUBY
	_manor_court(canvas, area, color, front, true)
	_box(canvas, _court_plot(area, Rect2i(0,14,6,1), front), 0.0, 31.0, Color("#95664e"), Color("#6b685a"))
	_box(canvas, _court_plot(area, Rect2i(9,14,6,1), front), 0.0, 31.0, Color("#95664e"), Color("#6b685a"))
	_box(canvas, _court_plot(area, Rect2i(6,13,1,2), front), 0.0, 44.0, Color("#8c544a"), Color("#b19b79"))
	_box(canvas, _court_plot(area, Rect2i(8,13,1,2), front), 0.0, 44.0, Color("#8c544a"), Color("#b19b79"))
	_roof(canvas, _court_plot(area, Rect2i(6,13,3,2), front), 48.0, color, 18.0)


# 府邸朝向模块：院墙、门楼和院内建筑共用同一次四向变换。
static func _court_plot(area: Rect2i, local: Rect2i, front: int) -> Rect2i:
	var start: Vector2i = local.position
	var size: Vector2i = local.size
	var finish: Vector2i = local.end
	match front:
		1:
			return Rect2i(area.position + Vector2i(start.y, area.size.y - finish.x), Vector2i(size.y,size.x))
		2:
			return Rect2i(area.position + area.size - finish, size)
		3:
			return Rect2i(area.position + Vector2i(area.size.x - finish.y,start.x), Vector2i(size.y,size.x))
	return Rect2i(area.position + start, size)


# 院落模块：墙围三面、前廊开口，正厅与厢房围绕院心。
static func _manor_court(canvas: Control, area: Rect2i, roof: Color, front: int = 0, landscaped: bool = false) -> void:
	_tile(canvas, area.grow(-1), Color("#c0ad8c"))
	_tile(canvas, _court_plot(area, Rect2i((area.size.x - 3) / 2,5,3,area.size.y - 5), front), Color("#ded0aa"))
	if landscaped:
		_garden(canvas, _court_plot(area, Rect2i(4,8,7,5), front))
	_box(canvas, _court_plot(area, Rect2i(0,0,area.size.x,1), front), 0.0, 31.0, Color("#936751"), Color("#6d6b63"))
	_box(canvas, _court_plot(area, Rect2i(0,0,1,area.size.y), front), 0.0, 28.0, Color("#95664e"), Color("#6b685a"))
	_box(canvas, _court_plot(area, Rect2i(area.size.x - 1,0,1,area.size.y), front), 0.0, 28.0, Color("#936453"), Color("#6b685a"))
	_hall(canvas, _court_plot(area, Rect2i(3,2,area.size.x - 6,3), front), roof, 53.0, true)
	_hall(canvas, _court_plot(area, Rect2i(1,5,2,3), front), roof.darkened(0.14), 31.0, false)
	_hall(canvas, _court_plot(area, Rect2i(area.size.x - 3,5,2,3), front), roof.darkened(0.14), 31.0, false)


# 御苑模块：蓝绿水池、栏杆、石桥、亭榭和种植边界。
static func _garden(canvas: Control, area: Rect2i) -> void:
	_tile(canvas, area, Color("#68865d"))
	var water := Rect2i(area.position + Vector2i(2,1), Vector2i(maxi(2, area.size.x - 4),maxi(2,area.size.y - 2)))
	_tile(canvas, water, Color("#6ca7a1"))
	_tile(canvas, water.grow(-1), Color("#397579"))
	var bridge := Rect2i(area.position + Vector2i((area.size.x - 1) / 2,0), Vector2i(1,area.size.y))
	_box(canvas, bridge, 0.0, 10.0, Color("#887554"), Color("#d0bc94"))
	if area.size.x > 10:
		_hall(canvas, Rect2i(area.position + Vector2i(2,2), Vector2i(4,4)), JADE, 43.0, false)
		_hall(canvas, Rect2i(area.end - Vector2i(7,7), Vector2i(5,4)), GOLD, 43.0, false)
	for column: int in range(1, area.size.x, 3):
		var point: Vector2 = Grid.cell_to_world(area.position + Vector2i(column, area.size.y - 1))
		Art.deposit(canvas, point, "forest")


# 殿堂模块：石台、朱柱、窗槅与重檐构成可点选的立体轮廓。
static func _hall(canvas: Control, area: Rect2i, roof: Color, height: float, double_roof: bool) -> void:
	var stone: Color = Color("#b8aa91")
	_box(canvas, area, 0.0, 20.0, stone.darkened(0.2), stone)
	_box(canvas, area, 20.0, height, Color("#8d4940"), Color("#715346"))
	var at: Vector2 = Grid.cell_to_world(Vector2i(area.position.x, area.end.y - 1))
	var edge: Vector2 = Grid.cell_to_world(Vector2i(area.size.x - 1,0))
	for col: int in range(0, area.size.x, 2):
		var spot: Vector2 = edge * (float(col) / maxi(1, area.size.x - 1))
		Art._stroke(canvas, at, spot - Vector2(0,20), spot - Vector2(0,height + 18), Color("#bf7553"), 8.0)
	_roof(canvas, area, height + 28.0, roof, maxf(14.0, height * 0.37))
	if double_roof and area.size.x >= 4 and area.size.y >= 3:
		_roof(canvas, area.grow(-1), height * 1.26 + 34.0, roof.lightened(0.08), maxf(12.0,height * 0.23))


# 屋面模块：两端挑檐和四坡面相接，斜线表示瓦垄。
static func _roof(canvas: Control, area: Rect2i, elevation: float, roof: Color, ridge_height: float) -> void:
	if not area.has_area():
		return
	var shape: PackedVector2Array = canvas._footprint_outline(area.position, area.size, true)
	var shift := Vector2(0, -elevation)
	var n: Vector2 = shape[0] + shift
	var e: Vector2 = shape[1] + shift + Vector2(8,-1)
	var s: Vector2 = shape[2] + shift
	var w: Vector2 = shape[3] + shift - Vector2(8,1)
	var r0: Vector2 = n.lerp(w, 0.45) + (e - n) * 0.18 - Vector2(0,ridge_height)
	var r1: Vector2 = n.lerp(w, 0.45) + (e - n) * 0.82 - Vector2(0,ridge_height)
	Art._poly(canvas, Vector2.ZERO, [n,e,r1,r0], roof.darkened(0.24))
	Art._poly(canvas, Vector2.ZERO, [e,s,r1], roof.darkened(0.32))
	Art._poly(canvas, Vector2.ZERO, [s,w,r0,r1], roof)
	Art._poly(canvas, Vector2.ZERO, [w,n,r0], roof.lightened(0.12))
	Art._stroke(canvas, Vector2.ZERO, w, s, roof.darkened(0.34), 8.0)
	Art._stroke(canvas, Vector2.ZERO, r0, r1, roof.lightened(0.28), 8.0)
	for index: int in range(1,10):
		var ratio: float = index / 10.0
		Art._stroke(canvas, Vector2.ZERO, r0.lerp(r1,ratio), w.lerp(s,ratio), roof.darkened(0.16), 2.0)


# 地面与高台模块：复用地图同一套格网投影。
static func _tile(canvas: Control, area: Rect2i, color: Color) -> void:
	if area.has_area():
		canvas.art_canvas.draw_colored_polygon(canvas._footprint_outline(area.position, area.size, true), color)


# 台基模块：仅画朝向镜头的两面和顶面。
static func _box(canvas: Control, area: Rect2i, elevation: float, height: float, wall: Color, surface: Color) -> void:
	if not area.has_area():
		return
	var shape: PackedVector2Array = canvas._footprint_outline(area.position, area.size, true)
	var shift := Vector2(0, -elevation)
	var up := Vector2(0, -height)
	var front: Vector2 = shape[2] + shift
	var east: Vector2 = shape[1] + shift
	var west: Vector2 = shape[3] + shift
	Art._poly(canvas, Vector2.ZERO, [east,front,front+up,east+up], wall.darkened(0.21))
	Art._poly(canvas, Vector2.ZERO, [front,west,west+up,front+up], wall)
	Art._poly(canvas, Vector2.ZERO, [shape[0]+shift+up,east+up,front+up,west+up], surface)


# 香炉模块：台边点缀可近看。
static func _incense(canvas: Control, at: Vector2i) -> void:
	_box(canvas, Rect2i(at, Vector2i.ONE), 0.0, 20.0, Color("#6a6854"), Color("#7e8a65"))


# 可见性模块：使用等距包围盒裁剪长城墙。
static func _visible(canvas: Control, area: Rect2i, view: Rect2) -> bool:
	var poly: PackedVector2Array = canvas._footprint_outline(area.position, area.size, true)
	return view.intersects(Rect2(Vector2(poly[3].x, poly[0].y - 170), Vector2(poly[1].x - poly[3].x, poly[2].y - poly[0].y + 170)))


# 商旅院落：正楼采用重檐，酒楼带二层宴厅，客栈内布置厢房、门廊和车马院。
static func hostelry(canvas: Control, area: Rect2i, kind: String, front: int) -> void:
	var center: Vector2i = area.get_center()
	var inn: bool = kind=="b_inn"
	var tavern: bool = kind=="b_tavern"
	var roof: Color = Color("#586265") if inn else (Color("#79765a") if tavern else Color("#454e57"))
	var yard: Color = Color("#b2a48b") if inn else Color("#aa9072")
	_tile(canvas,area,yard.darkened(0.18))
	_tile(canvas,area.grow(-1),yard)
	for x: int in range(area.position.x+1,area.end.x-1):
		for y: int in range(area.position.y+1,area.end.y-1):
			if (x+y)%2==0:
				_tile(canvas,Rect2i(x,y,1,1),yard.lightened(0.08))
	var span := Vector2i(3,2) if tavern else Vector2i(4,3)
	var outward: Vector2i = [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT][front]
	var main: Vector2i = center-span/2-outward
	var pavilion := Rect2i(main,span)
	var height: float = 58.0 if tavern else (69.0 if inn else 88.0)
	_hall(canvas,pavilion,roof,height,true)
	_hostelry_front(canvas,pavilion,height,inn)
	var cross := Vector2i(-outward.y,outward.x)
	for side: int in [-1,1]:
		var wing_gap: int = 1 if tavern else 2
		var wing: Vector2i = center+outward+cross*side*wing_gap-Vector2i.ONE
		var annex := Rect2i(wing,Vector2i(2,2))
		_hall(canvas,annex,roof.darkened(0.09),39.0,false)
		_hostelry_front(canvas,annex,39.0,inn)
		var lantern: Vector2 = Grid.cell_to_world(wing+outward+Vector2i.ONE)
		Art._stroke(canvas,lantern,Vector2.ZERO,Vector2(0,-36),Color("#50372b"),4.0)
		Art._pixel(canvas,lantern,Vector2(-5,-35),Vector2(10,13),Color("#d6813c"))
		Art._pixel(canvas,lantern,Vector2(-2,-32),Vector2(4,7),Color("#f3ce75"))
	var stoop: Vector2 = Grid.cell_to_world(center+outward*2)
	Art._shop_sign(canvas,stoop-Vector2(0,28),Color("#e9c583" if inn else "#d39249"))
	if inn:
		for side: int in [-1,1]:
			Art._cask(canvas,stoop+Vector2(side*24,13),Color("#b19c72"))
		Art._sack(canvas,stoop+Vector2(16,18))
	else:
		for offset: Vector2 in [Vector2(-23,6),Vector2(-34,12),Vector2(-12,13)]:
			Art._cask(canvas,stoop+offset,Color("#a45c43"))
		var bench: Vector2 = stoop+Vector2(27,11)
		Art._stroke(canvas,bench,Vector2(-12,0),Vector2(11,9),Color("#896449"),5)
		Art._stroke(canvas,bench,Vector2(-10,-4),Vector2(13,5),Color("#d2a575"),6)


# 门面细节：窗格、木栏、层间线脚与石阶在近景可辨。
static func _hostelry_front(canvas: Control, area: Rect2i, height: float, inn: bool) -> void:
	var bevel: PackedVector2Array = canvas._footprint_outline(area.position,area.size,true)
	var bronze := Color("#e1ac66") if inn else Color("#f4c783")
	for face: int in range(1,3):
		var left: Vector2 = bevel[face]
		var right: Vector2 = bevel[face+1]
		var low: float = 20.0
		Art._stroke(canvas,Vector2.ZERO,left-Vector2(0,low),right-Vector2(0,low),Color("#907661"),5)
		for window: int in range(3):
			var slot: float = 0.1+window*0.29
			var door: bool = face==2 and window==1
			Art._wall_opening(canvas,Vector2.ZERO,left,right,slot,slot+0.19,low+2.0 if door else low+8.0,low+27.0,bronze.darkened(0.44) if door else bronze,door)
			if height>=58.0:
				Art._wall_opening(canvas,Vector2.ZERO,left,right,slot,slot+0.19,low+38.0,low+53.0,bronze.lightened(0.12),false)
		if height>=58.0:
			var rail: Vector2 = Vector2(0,-low-39.0)
			Art._stroke(canvas,Vector2.ZERO,left+rail,right+rail,Color("#d0a172"),4)
			for spindle: int in range(1,8):
				var at: Vector2 = left.lerp(right,spindle/8.0)+rail
				Art._stroke(canvas,at,Vector2.ZERO,Vector2(0,9),Color("#aa7452"),2)


# 田畴底图：同一片耕地铺统一水渠田埂，细线区分每户的小块与作物。
static func field_district(canvas: Control, area: Rect2i) -> void:
	_tile(canvas,area.grow(1),Color("#59604b"))
	_tile(canvas,area,Color("#8d7952"))
	var edge := Rect2i(area.position-Vector2i(1,0),Vector2i(1,area.size.y))
	_tile(canvas,edge,Color("#527f79"))
	var bank := Rect2i(area.position-Vector2i(0,1),Vector2i(area.size.x,1))
	_tile(canvas,bank,Color("#a58a59"))


# 作物渲染：小麦、粟米、高粱使用不同色带，田埂保留独立点选边界。
static func field_plot(canvas: Control, area: Rect2i, crop: int) -> void:
	var colors: Array[Color] = [Color("#cfb86e"),Color("#b0bd67"),Color("#ae7450")]
	var crop_color: Color = colors[crop]
	_tile(canvas,area,Color("#8f7850"))
	for row: int in range(area.size.y):
		for column: int in range(area.size.x):
			var at: Vector2 = Grid.cell_to_world(area.position+Vector2i(column,row))
			var shade: Color = crop_color.lightened(0.13) if (column+row)%3==0 else crop_color
			Art._poly(canvas,at,[Vector2(-26,1),Vector2(-8,-8),Vector2(26,8),Vector2(10,16)],Color("#685439"))
			Art._stroke(canvas,at,Vector2(-25,0),Vector2(3,-14),shade,3.0)
			Art._stroke(canvas,at,Vector2(-15,5),Vector2(14,-9),shade,3.0)
			Art._stroke(canvas,at,Vector2(-5,10),Vector2(23,-4),shade.darkened(0.12),2.0)
	var frame: PackedVector2Array = canvas._footprint_outline(area.position,area.size,true)
	frame.append(frame[0])
	canvas.art_canvas.draw_polyline(frame,Color("#ad935e"),3.0)
