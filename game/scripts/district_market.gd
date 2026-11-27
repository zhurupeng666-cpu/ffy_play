## 文件用途：按步行道路与完工住宅数量选址，日结时自动为成熟街区建立集市。
extends RefCounted

const Catalog = preload("res://scripts/building_catalog.gd")
const Costs = preload("res://scripts/building_costs.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Streets = preload("res://scripts/street_frontage.gd")
const HOUSE_THRESHOLD: int = 20
const WALK_RANGE: int = 14
const MARKET_SPACING: int = 2 * WALK_RANGE


# 日结模块：只用并入道路网的住宅，每天最多形成一处新集市。
static func settle(world: RefCounted) -> void:
	if world.buildings.size() >= 256 or world.next_building_id >= 1000000:
		return
	var ways: Dictionary = Streets.network(world.buildings)
	var houses: Array[Dictionary] = []
	var markets: Array[Vector2i] = []
	for building: Dictionary in world.buildings:
		if building["state"] != "ready":
			continue
		var kind: String = building["def_id"]
		var point := Vector2i(building["cell"][0], building["cell"][1])
		if kind == "b_house":
			houses.append(building)
		elif kind == Catalog.MARKET.id:
			markets.append(point)
	if houses.size() < HOUSE_THRESHOLD or ways.is_empty():
		return
	var entrances: Dictionary = _entrances(houses, ways)
	var occupied: Dictionary = world.occupied_cells()
	var anchors: Array = ways.keys()
	anchors.sort()
	var best: Vector2i = Vector2i.ZERO
	var score: int = HOUSE_THRESHOLD - 1
	for road: Vector2i in anchors:
		if ways[road] != "b_road" or _has_nearby_market(road, markets):
			continue
		var reached: int = _homes_on_foot(road, ways, entrances)
		if reached <= score:
			continue
		for direction: Vector2i in Terrain.CARDINALS:
			var candidate: Vector2i = road + Vector2i(direction.x * 2, direction.y * 2) - Vector2i.ONE
			if Placement.check_building(candidate, Catalog.MARKET, occupied, world.capital_layout)["ok"]:
				best = candidate
				score = reached
				break
	if score >= HOUSE_THRESHOLD:
		found(world, best, Catalog.MARKET)


# 住宅接入模块：同一栋房在同一条路或多条路有入口时只会被统计一次。
static func _entrances(houses: Array[Dictionary], ways: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for house: Dictionary in houses:
		var anchor := Vector2i(house["cell"][0], house["cell"][1])
		for cell: Vector2i in Placement.footprint_cells(anchor, Catalog.footprint(house)):
			for direction: Vector2i in Terrain.CARDINALS:
				var road: Vector2i = cell + direction
				if ways.has(road) and (not house.has("front") or direction == Streets.SIDES[house["front"]]):
					if not result.has(road):
						result[road] = {}
					result[road][house["id"]] = true
	return result


# 步行计数：沿道路和城门扩展，不把隔墙或断路另一端的住宅算进来。
static func _homes_on_foot(origin: Vector2i, ways: Dictionary, entrances: Dictionary) -> int:
	var queue: Array[Vector2i] = [origin]
	var distance: Dictionary = {origin: 0}
	var houses: Dictionary = {}
	var index: int = 0
	while index < queue.size():
		var point: Vector2i = queue[index]
		index += 1
		if entrances.has(point):
			houses.merge(entrances[point])
		if distance[point] >= WALK_RANGE:
			continue
		for direction: Vector2i in Terrain.CARDINALS:
			var next: Vector2i = point + direction
			if ways.has(next) and not distance.has(next):
				distance[next] = distance[point] + 1
				queue.append(next)
	return houses.size()


# 间距模块：既有集市覆盖本街区，附近成熟住宅无需重复开市。
static func _has_nearby_market(road: Vector2i, markets: Array[Vector2i]) -> bool:
	for market: Vector2i in markets:
		var offset: Vector2i = market + Vector2i.ONE - road
		if absi(offset.x) + absi(offset.y) <= MARKET_SPACING:
			return true
	return false


# 持久化模块：集市沿用建筑实例和历史回执，重读存档保留同一地址与标识。
static func found(world: RefCounted, point: Vector2i, definition: Resource) -> String:
	var id: String = "building_%06d" % world.next_building_id
	var cell: Array = [point.x, point.y]
	world.buildings.append({"id": id, "def_id": definition.id, "cell": cell, "level": 1, "state": "ready",
		"work_done": 0, "work_required": 0, "workers": 0, "food_credit": 0, "material_credit": 0, "paid_cost": Costs.normalize({})})
	world.applied_commands["resident-" + id] = {"def_id": definition.id, "cell": cell.duplicate(), "building_id": id}
	if definition.get_meta("large", false):
		world.buildings.back()["large"] = true
		world.applied_commands["resident-" + id]["large"] = true
	world.next_building_id += 1
	return id
