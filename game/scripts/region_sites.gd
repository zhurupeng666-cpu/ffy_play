## 文件用途：在等距世界中定位区域据点，预设营地、要塞和驻军画面。
extends RefCounted

const Art = preload("res://scripts/town_art.gd")
const LAYOUT = preload("res://data/regions/frontier.tres")
const SITE_EXTENT: int = 7


# 占地预留：阻止城镇建筑覆盖据点设施和围墙。
static func overlaps(area: Rect2i) -> bool:
	for id: String in ["r_woods", "r_fort"]:
		var center: Vector2i = LAYOUT.regions[id]["position"]
		if area.intersects(Rect2i(center - Vector2i.ONE * SITE_EXTENT, Vector2i.ONE * (SITE_EXTENT * 2 + 1))):
			return true
	return false


# 据点美术：围墙四角按等距地面的前后顺序落位，近侧留出营门。
static func draw_site(canvas: Control, id: String, center: Vector2, guards: int) -> void:
	var stone: bool = id == "r_fort"
	var back := Vector2(0, -176)
	var left := Vector2(-352, 0)
	var right := Vector2(352, 0)
	var front := Vector2(0, 176)
	var shade: Color = Color("#85887c") if stone else Color("#806340")
	Art._poly(canvas, center, [back, right, front, left], Color("#8c7854") if stone else Color("#786346"))
	_wall(canvas, center, back, left, shade, stone)
	_wall(canvas, center, back, right, shade.darkened(0.15), stone)
	_turret(canvas, center + back, stone)
	Art._house(canvas, center + Vector2(30, -78), 48, 42, Color("#655970") if stone else Color("#8f543e"), Color("#aba697") if stone else Color("#b69262"), "stone" if stone else "timber", 2.05)
	Art._house(canvas, center + Vector2(-145, -13), 32, 26, Color("#9b643b"), Color("#b39360"), "store", 1.72)
	Art._house(canvas, center + Vector2(145, 16), 29, 22, Color("#745d4e"), Color("#bc9e69"), "timber", 1.62)
	for offset: Vector2 in [Vector2(-111, 18), Vector2(-98, 24), Vector2(108, 40), Vector2(121, 46)]:
		Art._crate(canvas, center + offset)
	for index: int in range(guards):
		var row: int = floori(index / 6.0)
		var column: int = index % 6
		var post := Vector2((column - 2.5) * 29.0 + row * 9, 37 + row * 25.0 + column * 2)
		Art._drill_soldier(canvas, center + post, 0.0, index, false)
	_turret(canvas, center + left, stone)
	_turret(canvas, center + right, stone)
	var left_gate: Vector2 = front.lerp(left, 0.16)
	var right_gate: Vector2 = front.lerp(right, 0.16)
	_wall(canvas, center, left, left_gate, shade.darkened(0.2), stone)
	_wall(canvas, center, right, right_gate, shade, stone)
	_turret(canvas, center + left_gate, stone)
	_turret(canvas, center + right_gate, stone)
	Art._flag(canvas, center + left_gate - Vector2(0, 75), Color("#568e9d") if guards == 0 else Color("#b74f41"))


# 围墙：石墙画出女墙与石缝，木寨用分段栅柱标示轮廓。
static func _wall(canvas: Control, center: Vector2, a: Vector2, b: Vector2, color: Color, stone: bool) -> void:
	var height: float = 45.0 if stone else 27.0
	var top := Vector2(0, -height)
	Art._poly(canvas, center, [a, b, b + top, a + top], color)
	Art._stroke(canvas, center, a + top, b + top, color.lightened(0.24), 4.0)
	var pieces: int = ceili(a.distance_to(b) / (22.0 if stone else 15.0))
	for index: int in range(pieces):
		var base: Vector2 = a.lerp(b, float(index) / pieces)
		if stone:
			Art._stroke(canvas, center, base + top, base + top - Vector2(0, 7), color.lightened(0.25), 9.0)
			Art._stroke(canvas, center, base, base + top * 0.65, color.darkened(0.28), 2.0)
		else:
			Art._stroke(canvas, center, base, base + top - Vector2(0, index % 3), color.lightened(0.14), 3.0)


# 哨楼：按据点类型选用石制塔身或木制岗亭。
static func _turret(canvas: Control, point: Vector2, stone: bool) -> void:
	if stone:
		Art._tower(canvas, point, 30, 70)
	else:
		Art._house(canvas, point, 18, 30, Color("#684735"), Color("#aa8350"), "timber", 1.35)
