## 文件用途：根据完工道路生成可重复步行路径，只绘制镜头内的行人。
extends RefCounted

const Grid = preload("res://scripts/isometric_grid.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const Pedestrians = preload("res://scripts/capital_pedestrian_art.gd")
const MAX_STREET_ROUTES: int = 42


# 路线模块：沿接通的道路走到下一段路，门可通行，墙和房屋不参与。
static func routes(ways: Dictionary) -> Array[PackedVector2Array]:
	var anchors: Array[Vector2i] = []
	for cell: Vector2i in ways:
		if ways[cell] in ["b_road", "b_gate"]:
			anchors.append(cell)
	anchors.sort()
	var paths: Array[PackedVector2Array] = []
	if anchors.is_empty():
		return paths
	var limit: int = mini(MAX_STREET_ROUTES, ceili(anchors.size() / 2.0))
	for i: int in range(limit):
		var at: Vector2i = anchors[floori(i * anchors.size() / float(limit))]
		var path := PackedVector2Array([Grid.cell_to_world(at)])
		var direction := Vector2i.ZERO
		for step: int in range(20):
			var next_direction := Vector2i.ZERO
			for offset: int in range(Terrain.CARDINALS.size()):
				var side: Vector2i = Terrain.CARDINALS[(offset + i + floori(step / 5.0)) % 4]
				if side != -direction and ways.get(at + side) in ["b_road", "b_gate"]:
					next_direction = side
					break
			if next_direction == Vector2i.ZERO:
				break
			at += next_direction
			direction = next_direction
			path.append(Grid.cell_to_world(at))
		if path.size() > 1:
			paths.append(path)
	return paths


# 人物位置模块：不同步速与出发时机，走到终点后沿街返回。
static func draw(canvas: Control, paths: Array[PackedVector2Array], time: float, view: Rect2, population: int) -> void:
	if population <= 0:
		return
	var budget: int = mini(54, ceili(population * 0.68))
	for i: int in range(paths.size()):
		if budget <= 0:
			return
		var path: PackedVector2Array = paths[i]
		var length: float = 0.0
		for point: int in range(1, path.size()):
			length += path[point - 1].distance_to(path[point])
		var pace: float = 34.0 + (i % 4) * 6.0
		var duration: float = length / pace
		var pause: float = 0.6 + (i % 5) * 0.33
		var clock: float = fposmod(time + fposmod(i * 0.618, 1.0) * 2.0 * (duration + pause), 2.0 * (duration + pause))
		var backward: bool = clock >= duration + pause
		var local: float = clock - (duration + pause if backward else 0.0)
		var waiting: bool = local >= duration
		var travel: float = clampf(local * pace, 0.0, length)
		var distance: float = length - travel if backward else travel
		var segment: int = 0
		while segment < path.size() - 2:
			var span: float = path[segment].distance_to(path[segment + 1])
			if distance <= span:
				break
			distance -= span
			segment += 1
		var start: Vector2 = path[segment]
		var finish: Vector2 = path[segment + 1]
		var heading: Vector2 = (finish - start).normalized()
		var direction: float = -1.0 if backward else 1.0
		var lane: Vector2 = heading.orthogonal() * ((i % 3 + 1) * 4.0 * direction)
		var at: Vector2 = start + heading * distance + lane
		if view.has_point(at) and not canvas.street_view_hidden(at):
			budget -= 1
			Pedestrians.draw(canvas, at, i % 5, posmod(floori(travel / 7.0 + i), 6), heading.x * direction, waiting)
