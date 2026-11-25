## 文件用途：定义城外林矿、湖河和沿岸建造规则，兼容旧档地形校验。
extends RefCounted
const Grid = preload("res://scripts/isometric_grid.gd")

# 河道断面：每项记录横坐标、北岸和南岸，中央河段拓宽成湖盆。
const RIVER: Array[Vector3i] = [
	Vector3i(0, 94, 104), Vector3i(22, 91, 108), Vector3i(44, 96, 116),
	Vector3i(62, 101, 128), Vector3i(85, 94, 138), Vector3i(116, 88, 140),
	Vector3i(139, 93, 127), Vector3i(159, 103, 118), Vector3i(180, 108, 124),
	Vector3i(199, 101, 115),
]
const DISTRICTS: Array[Dictionary] = [
	{"kind": "forest", "bounds": Rect2i(49, 34, 36, 30), "title": "北岭林场"},
	{"kind": "stone", "bounds": Rect2i(104, 24, 36, 30), "title": "灰脊石矿"},
	{"kind": "forest", "bounds": Rect2i(42, 148, 36, 30), "title": "南岸密林"},
	{"kind": "stone", "bounds": Rect2i(124, 153, 36, 30), "title": "南岭石矿"},
]
const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
static var spans: Array[Vector2i] = []
static var deposits: Dictionary = {}


# 水域缓存：按列插值，渲染、建设和旧档迁移使用同一份河岸数据。
static func _prepare() -> void:
	if not spans.is_empty():
		return
	for index: int in range(RIVER.size() - 1):
		var start: Vector3i = RIVER[index]
		var finish: Vector3i = RIVER[index + 1]
		for x: int in range(start.x, finish.x):
			var ratio: float = float(x - start.x) / float(finish.x - start.x)
			spans.append(Vector2i(roundi(lerpf(start.y, finish.y, ratio)), roundi(lerpf(start.z, finish.z, ratio))))
	spans.append(Vector2i(RIVER[-1].y, RIVER[-1].z))
	for district: Dictionary in DISTRICTS:
		var bounds: Rect2i = district["bounds"]
		for y: int in range(bounds.size.y):
			var inset: int = maxi(0, 7 - mini(y, bounds.size.y - 1 - y))
			for x: int in range(inset, bounds.size.x - inset):
				deposits[bounds.position + Vector2i(x, y)] = district["kind"]


# 河岸查询：端点落在水中，两岸之间的格无法建造。
static func river_span(column: int) -> Vector2i:
	_prepare()
	return spans[column]


# 地形查询：旧档的原地图只在校验历史坐标时启用。
static func is_water(cell: Vector2i, legacy: bool = false) -> bool:
	if not Grid.contains(cell):
		return false
	if legacy:
		return cell.y == 0
	var span: Vector2i = river_span(cell.x)
	return cell.y >= span.x and cell.y <= span.y


# 地形校验：首轮检查占地，沿岸或林矿的接触从边缘正交格判定。
static func check(cells: Array[Vector2i], requires_water: bool, required_deposit: String = "", legacy: bool = false) -> Dictionary:
	var waterfront: bool = false
	var deposit_nearby: bool = false
	for cell: Vector2i in cells:
		if is_water(cell, legacy):
			return {"ok": false, "code": "WATER", "reason": "水域不能建造，请选择岸上空地"}
		if not deposit_at(cell, legacy).is_empty():
			return {"ok": false, "code": "DEPOSIT", "reason": "资源区不能直接建造，请选择边缘空地"}
		if (not requires_water or waterfront) and (required_deposit.is_empty() or deposit_nearby):
			continue
		for offset: Vector2i in CARDINALS:
			if requires_water and is_water(cell + offset, legacy):
				waterfront = true
			if not required_deposit.is_empty() and deposit_at(cell + offset, legacy) == required_deposit:
				deposit_nearby = true
	if requires_water and not waterfront:
		return {"ok": false, "code": "NEEDS_WATER", "reason": "渔场必须沿水建造，占地边缘需与河岸接触"}
	if not required_deposit.is_empty() and not deposit_nearby:
		return {"ok": false, "code": "NEEDS_DEPOSIT", "reason": "须紧邻森林资源区" if required_deposit == "forest" else "须紧邻石矿资源区"}
	return {"ok": true}


const LEGACY_DEPOSITS: Dictionary = {
	Vector2i(0, 11): "forest", Vector2i(0, 12): "forest", Vector2i(0, 13): "forest",
	Vector2i(15, 4): "stone", Vector2i(15, 5): "stone", Vector2i(15, 6): "stone",
	Vector2i(27, 11): "forest", Vector2i(28, 11): "forest", Vector2i(28, 12): "forest", Vector2i(29, 11): "forest",
	Vector2i(14, 26): "forest", Vector2i(15, 26): "forest", Vector2i(15, 27): "forest",
	Vector2i(43, 28): "forest", Vector2i(44, 28): "forest", Vector2i(44, 29): "forest",
	Vector2i(56, 12): "stone", Vector2i(57, 12): "stone", Vector2i(57, 13): "stone",
	Vector2i(31, 40): "stone", Vector2i(32, 40): "stone", Vector2i(33, 40): "stone",
	Vector2i(66, 41): "forest", Vector2i(67, 41): "forest", Vector2i(67, 42): "forest",
	Vector2i(58, 55): "stone", Vector2i(59, 55): "stone", Vector2i(59, 56): "stone",
	Vector2i(101, 28): "forest", Vector2i(102, 28): "forest", Vector2i(102, 29): "forest",
	Vector2i(157, 37): "stone", Vector2i(158, 37): "stone", Vector2i(158, 38): "stone",
	Vector2i(37, 102): "forest", Vector2i(38, 102): "forest", Vector2i(38, 103): "forest",
	Vector2i(86, 121): "stone", Vector2i(87, 121): "stone", Vector2i(86, 122): "stone",
	Vector2i(131, 103): "forest", Vector2i(132, 103): "forest", Vector2i(132, 104): "forest",
	Vector2i(176, 114): "stone", Vector2i(177, 114): "stone", Vector2i(177, 115): "stone",
	Vector2i(49, 164): "stone", Vector2i(50, 164): "stone", Vector2i(50, 165): "stone",
	Vector2i(129, 168): "forest", Vector2i(130, 168): "forest", Vector2i(130, 169): "forest",
	Vector2i(179, 179): "forest", Vector2i(180, 179): "forest", Vector2i(180, 180): "forest",
}

# 资源查询：返回真实占地所需的类型，也供地表纹理采样。
static func deposit_at(cell: Vector2i, legacy: bool = false) -> String:
	if legacy:
		return LEGACY_DEPOSITS.get(cell, "")
	_prepare()
	return deposits.get(cell, "")


# 码头查询：在占地外缘寻找最靠近中央的临水正交面。
static func dock_edge(anchor: Vector2i, extent: Vector2i) -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = INF
	var center: Vector2 = Vector2(anchor) + Vector2(extent - Vector2i.ONE) * 0.5
	for edge: Vector2i in CARDINALS:
		var length: int = extent.y if edge.x != 0 else extent.x
		for i: int in range(length):
			var cell := anchor
			if edge.x != 0:
				cell += Vector2i(extent.x - 1 if edge.x > 0 else 0, i)
			else:
				cell += Vector2i(i, extent.y - 1 if edge.y > 0 else 0)
			var candidate: float = Vector2(cell).distance_squared_to(center)
			if candidate < distance and is_water(cell + edge):
				distance = candidate
				nearest = {"cell": cell, "outward": edge}
	return nearest
