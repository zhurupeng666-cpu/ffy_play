## 文件用途：安排城外农牧地块、迁移旧地契，并生成农户每日过城门的通勤路线。
extends RefCounted

const Market = preload("res://scripts/district_market.gd")
const Place = Market.Placement
const Catalog = Market.Catalog
const Capital = Market.Streets.Capital
const Grid = Capital.Grid
const Pedestrians = preload("res://scripts/capital_pedestrian_art.gd")
const Activity = preload("res://scripts/town_compound_art.gd")
const FARM_KINDS: Array[String] = ["b_farm","b_ranch"]
const GATE_CELLS: Array[Vector2i] = [Vector2i(149,-230),Vector2i(149,69),Vector2i(-15,-71),Vector2i(284,-71)]
const OUTWARD: Array[Vector2i] = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]


# 郊地选址：按宽间距交替向东西郊扩张，避开河道、资源地和据点。
static func site(definition: Resource, occupied: Dictionary) -> Vector2i:
	var span: Vector2i = definition.footprint
	for row: int in range(18):
		for index: int in range(17):
			var band: int = (index+1)/2
			var y: int = -65 + band * (span.y+4) * (1 if index%2==1 else -1)
			if y+span.y > 84:
				continue
			for x: int in [-31-span.x-row*24,301+row*24]:
				var cell := Vector2i(x,y)
				if Place.check_building(cell,definition,occupied,true)["ok"]:
					return cell
	return Grid.INVALID


# 迁址模块：整块用地出城，建筑、产权、岗位、施工及历史回执继续沿用原ID。
static func relocate(world: RefCounted, migrate: bool) -> bool:
	var occupied: Dictionary = world.occupied_cells()
	var receipts: Dictionary = {}
	for receipt: Dictionary in world.applied_commands.values():
		receipts[receipt["building_id"]]=receipt
	for record: Dictionary in world.buildings:
		if record["def_id"] not in FARM_KINDS:
			continue
		var anchor := Vector2i(record["cell"][0],record["cell"][1])
		var span: Vector2i = Catalog.footprint(record)
		if not Capital.OUTER.intersects(Rect2i(anchor,span)):
			continue
		if not migrate:
			return false
		var definition: Resource = Catalog.find(record["def_id"]).duplicate()
		definition.footprint = span
		var target: Vector2i = site(definition,occupied)
		if target == Grid.INVALID:
			return false
		for cell: Vector2i in Place.footprint_cells(anchor,span):
			occupied.erase(cell)
		for cell: Vector2i in Place.footprint_cells(target,span):
			occupied[cell]=record["id"]
		record["cell"]=[target.x,target.y]
		receipts[record["id"]]["cell"]=record["cell"].duplicate()
	return true


# 地籍补绘：已有田亩而没有可见田地的家庭获得城外地块，面积数值与库存保持原样。
static func survey(world: RefCounted) -> void:
	var titles: Dictionary = world.household_economy["property"]
	var farms: Dictionary = {}
	for record: Dictionary in world.buildings:
		if record["def_id"]=="b_farm" and titles.has(record["id"]):
			farms[titles[record["id"]]]=true
	var occupied: Dictionary = world.occupied_cells()
	for index: int in range(world.households.size()):
		if world.buildings.size()+world.royal_works["roads"].size()>=256 or world.next_building_id>=1000000:
			return
		if farms.has(index) or world.household_economy["families"][index]["land"]<=0:
			continue
		var cell: Vector2i = site(Catalog.FARM,occupied)
		if cell == Grid.INVALID:
			return
		var id: String = Market.found(world,cell,Catalog.FARM)
		titles[id]=index
		for tile: Vector2i in Place.footprint_cells(cell,Catalog.FARM.footprint):
			occupied[tile]=id


# 起点模块：优先取住户门外，城外或未分配住户沿用镇中心住区入口。
static func _door(home: Dictionary) -> Vector2i:
	if home.is_empty():
		return Vector2i(5,7)
	var span: Vector2i = Catalog.footprint(home)
	var anchor := Vector2i(home["cell"][0],home["cell"][1])
	var side: int = home.get("front",0)
	var along := Vector2i.RIGHT if side%2==0 else Vector2i.DOWN
	var middle: int = (span.x if side%2==0 else span.y)/2
	return Market.Streets.edge_start(anchor,span,side)+along*middle+Market.Streets.SIDES[side]


# 通勤地图：避开真实建筑、外墙和皇城；大道与所选城门保持通行。
static func routes(world: RefCounted, lots: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	var navigation := AStarGrid2D.new()
	navigation.region=Capital.OUTER
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	var occupied: Dictionary = world.occupied_cells()
	for cell: Vector2i in occupied:
		if Capital.OUTER.has_point(cell):
			navigation.set_point_solid(cell)
	for cell: Vector2i in Market.Streets.network(world.buildings,true):
		if Capital.OUTER.has_point(cell):
			navigation.set_point_solid(cell,false)
	for lot: Dictionary in lots:
		var owner: int = lot["owner"]
		var farm: Vector2i = lot["farm"]
		var start: Vector2i = lot["door"]
		var gate: int = 0
		var nearest: float = INF
		for i: int in range(GATE_CELLS.size()):
			var axis: Vector2i = OUTWARD[i]
			var offset: Vector2i = farm-GATE_CELLS[i]
			if offset.x*axis.x+offset.y*axis.y<=0 or offset.length_squared()>=nearest:
				continue
			gate=i
			nearest=offset.length_squared()
		var city_exit: Vector2i = GATE_CELLS[gate]
		var axis: Vector2i = OUTWARD[gate]
		for i: int in range(11):
			navigation.set_point_solid(city_exit-axis*i,false)
		if not Capital.OUTER.has_point(start) or navigation.is_point_solid(start):
			start=Vector2i(5,7)
		if navigation.is_point_solid(start):
			continue
		var tiles: Array[Vector2i] = navigation.get_id_path(start,city_exit)
		if tiles.is_empty():
			continue
		var lane: Vector2i = city_exit+axis*5
		tiles.append(lane)
		tiles.append(Vector2i(farm.x,lane.y) if axis.y!=0 else Vector2i(lane.x,farm.y))
		tiles.append(farm)
		var path := PackedVector2Array()
		var distances := PackedFloat32Array()
		var length: float = 0.0
		for tile: Vector2i in tiles:
			var point: Vector2 = Grid.cell_to_world(tile)
			if not path.is_empty():
				length+=path[-1].distance_to(point)
			path.append(point)
			distances.append(length)
		result[owner]={"points":path,"distances":distances,"length":length}
	return result


# 家户入口：只为有成年劳动力且分配了可见农田的家庭建立代表性通勤行人。
static func lots(world: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var buildings: Dictionary = {}
	for record: Dictionary in world.buildings:
		buildings[record["id"]]=record
	var seen: Dictionary = {}
	for id: String in world.household_economy["property"]:
		var record: Dictionary = buildings[id]
		var owner: int = world.household_economy["property"][id]
		if record["def_id"]!="b_farm" or record["state"]!="ready" or seen.has(owner) or world.households[owner]["adults"]<=0:
			continue
		var anchor := Vector2i(record["cell"][0],record["cell"][1])
		var home: String = world.resident_register[owner]["address"] if owner<world.resident_register.size() else ""
		seen[owner]=true
		result.append({"owner":owner,"farm":anchor+Catalog.footprint(record)/2,"door":_door(buildings.get(home,{}))})
	return result


# 昼夜作息：六至八时依次出城，十七至十九时归家；田间动作集中在白天。
static func draw_workers(canvas: Control, paths: Dictionary, hour: float, scenery: float, view: Rect2) -> void:
	if hour<6.0 or hour>=19.0:
		return
	for owner: int in paths:
		var route: Dictionary = paths[owner]
		var stagger: float = (owner%8)*0.09
		var outbound: float = (hour-6.0-stagger)/1.35
		var inbound: float = (19.0-hour-stagger)/1.35
		if outbound<0.0 or inbound<0.0:
			continue
		var work: bool = outbound>=1.0 and inbound>=1.0
		var travelled: float = clampf(minf(outbound,inbound),0.0,1.0)*route["length"]
		var distances: PackedFloat32Array = route["distances"]
		var points: PackedVector2Array = route["points"]
		var next: int = _segment(distances,travelled)
		var start: Vector2 = points[next-1]
		var target: Vector2 = points[next]
		var at: Vector2 = target if target==start else start.lerp(target,(travelled-distances[next-1])/maxf(1.0,distances[next]-distances[next-1]))
		if work:
			at+=Vector2(sin(scenery*0.8+owner)*32,cos(scenery*0.8+owner)*14)
		if view.has_point(at) and (work or not canvas.street_view_hidden(at)):
			var facing: float = signf((target.x-start.x)*(1.0 if outbound<inbound else -1.0))
			if work:
				Activity._field_worker(canvas,at,sin(scenery*4.0+owner),true,owner)
			else:
				Pedestrians.draw(canvas,at,owner%5,floori(scenery*7.0)%6,facing,false)


# 路段查询：二分沿路累计距离，缩放和移动时不复制长路径。
static func _segment(distances: PackedFloat32Array, travelled: float) -> int:
	var first: int = 1
	var last: int = distances.size()-1
	while first<last:
		var middle: int = (first+last)/2
		if distances[middle]<travelled:
			first=middle+1
		else:
			last=middle
	return first
