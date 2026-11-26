## 文件用途：从完工道路的占地计算住宅正门，供建造、地图与集市共用。
extends RefCounted

const Catalog = preload("res://scripts/building_catalog.gd")
const Capital = preload("res://scripts/capital_layout.gd")
const SIDES: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
const WAY_KINDS: Array[String] = ["b_road", "b_gate"]
const DEFAULT_FRONT: int = 0
const NO_FRONT: int = -1
static var avenues: Dictionary = {}


# 网格模块：道路和城门按全部完工占地接入，施工地块不算道路。
static func network(records: Array, include_capital: bool = false) -> Dictionary:
	if include_capital and avenues.is_empty():
		for area: Rect2i in Capital.BOULEVARDS:
			for y: int in range(area.position.y, area.end.y):
				for x: int in range(area.position.x, area.end.x):
					var tile := Vector2i(x,y)
					if not Capital.INNER.has_point(tile):
						avenues[tile] = "b_road"
	var result: Dictionary = avenues.duplicate() if include_capital else {}
	for record: Dictionary in records:
		var kind: String = record["def_id"]
		if record["state"] == "ready" and kind in WAY_KINDS:
			var at := Vector2i(record["cell"][0],record["cell"][1])
			var span: Vector2i = Catalog.footprint(record)
			for y: int in range(span.y):
				for x: int in range(span.x):
					result[at + Vector2i(x,y)] = kind
	return result


# 门向模块：优先接触路段最多的侧面，入口必须能从边缘中央连到路。
static func direction(anchor: Vector2i, span: Vector2i, ways: Dictionary) -> int:
	var best: int = NO_FRONT
	var most: int = 0
	for side: int in range(SIDES.size()):
		var start: Vector2i = edge_start(anchor, span, side)
		var length: int = span.x if SIDES[side].y != 0 else span.y
		var along := Vector2i.RIGHT if SIDES[side].y != 0 else Vector2i.DOWN
		var middle: int = floori((length - 1) * 0.5)
		if not ways.has(start + along * middle + SIDES[side]) and not ways.has(start + along * (length / 2) + SIDES[side]):
			continue
		var contacts: int = 0
		for i: int in range(length):
			contacts += int(ways.has(start + along * i + SIDES[side]))
		if contacts > most:
			best = side
			most = contacts
	return best


# 入口端点：从指定侧边的最小坐标开始沿边枚举。
static func edge_start(anchor: Vector2i, span: Vector2i, side: int) -> Vector2i:
	return anchor + Vector2i(span.x - 1 if side == 1 else 0, span.y - 1 if side == 0 else 0)


# 既存建筑：优先使用建成时记录的方向；旧房就近匹配现有道路。
static func for_record(record: Dictionary, ways: Dictionary) -> int:
	if record.has("front"):
		return record["front"]
	var cell := Vector2i(record["cell"][0],record["cell"][1])
	var inferred: int = direction(cell, Catalog.footprint(record), ways)
	return inferred if inferred != NO_FRONT else DEFAULT_FRONT
