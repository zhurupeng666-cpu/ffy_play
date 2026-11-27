## 文件用途：为有真实住址、岗位和店铺的家庭生成出门办事与返家的时间表。
extends RefCounted

const Streets = preload("res://scripts/street_frontage.gd")
const Grid = Streets.Capital.Grid
const Catalog = Streets.Catalog
const Capital = Streets.Capital
const Pedestrians = preload("res://scripts/capital_pedestrian_art.gd")
const LIMIT: int = 48


# 目的地模块：覆盖值勤、工地、开店、集市与客栈采购；无可达目标的住户留在家里。
static func routes(world: RefCounted, farming: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var addresses: Dictionary = {}
	var private_jobs: Dictionary = {}
	var public_jobs: Array[Dictionary] = []
	var shops: Array[Dictionary] = []
	for record: Dictionary in world.buildings:
		addresses[record["id"]]=record
		var kind: String = record["def_id"]
		var cell := Vector2i(record["cell"][0],record["cell"][1])
		if not Capital.OUTER.has_point(cell):
			continue
		var owner: int = world.builder_owner(record)
		if record["state"]=="constructing":
			if owner>=0:
				private_jobs[owner]={"record":record,"activity":"build"}
			elif owner!=-3:
				var count: int = world.builders if owner==-1 and public_jobs.is_empty() else int(owner==-2)
				for person: int in range(count):
					public_jobs.append({"record":record,"activity":"build"})
		elif kind in ["b_market","b_tavern","b_restaurant","b_bakery","b_inn","b_granary","b_smithy"]:
			shops.append(record)
			if owner>=0:
				private_jobs[owner]={"record":record,"activity":"sell"}
		elif kind=="b_gate":
			public_jobs.append({"record":record,"activity":"guard"})
	if private_jobs.is_empty() and public_jobs.is_empty() and shops.is_empty():
		return result
	var pathfinder := AStarGrid2D.new()
	pathfinder.region=Capital.OUTER
	pathfinder.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	pathfinder.update()
	var occupied: Dictionary = world.occupied_cells()
	for cell: Vector2i in occupied:
		if Capital.OUTER.has_point(cell):
			pathfinder.set_point_solid(cell)
	var ways: Dictionary = Streets.network(world.buildings,true)
	for cell: Vector2i in ways:
		if Capital.OUTER.has_point(cell):
			pathfinder.set_point_solid(cell,false)
			pathfinder.set_point_weight_scale(cell,0.60)
	var rotating_job: int = 0
	for i: int in range(world.resident_register.size()):
		if result.size()>=LIMIT:
			break
		var home: Dictionary = addresses.get(world.resident_register[i]["address"],{})
		if home.is_empty() or world.households[i]["adults"]<=0:
			continue
		var start: Vector2i = _entry(home,ways,pathfinder)
		if start==Grid.INVALID:
			continue
		if farming.has(i) and world.households[i]["adults"]<2:
			continue
		var destination: Dictionary = private_jobs.get(i,{})
		if destination.is_empty():
			if farming.has(i):
				continue
			if rotating_job<public_jobs.size():
				destination=public_jobs[rotating_job]
				rotating_job+=1
			elif not shops.is_empty():
				destination={"record":shops[posmod(hash(Vector2i(i,world.current_day())),shops.size())],"activity":"buy"}
		if destination.is_empty():
			continue
		var stop: Vector2i = _entry(destination["record"],ways,pathfinder)
		if stop==Grid.INVALID or stop==start:
			continue
		var path: Array[Vector2i] = pathfinder.get_id_path(start,stop)
		if path.size()<2:
			continue
		var points := PackedVector2Array()
		var distances := PackedFloat32Array()
		var length: float = 0.0
		for cell: Vector2i in path:
			var point: Vector2 = Grid.cell_to_world(cell)
			if not points.is_empty():
				length+=points[-1].distance_to(point)
			points.append(point)
			distances.append(length)
		var activity: String = destination["activity"]
		var leave: float = (9.2 if activity=="buy" else 7.0)+(i%11)*0.16
		var work: float = 0.85 if activity=="buy" else 6.0
		var actor: String = _role(world,i,activity,destination["record"]["def_id"])
		result.append({"owner":i,"target":destination["record"]["id"],"activity":activity,"role":actor,"points":points,"distances":distances,
			"length":length,"start":leave,"work":work,"travel":clampf(length/2000.0,0.25,1.10)})
	return result


# 通勤人物：显眼装束来自岗位和登记身份，同一条路线可区分旅客与当值人员。
static func _role(world: RefCounted, owner: int, activity: String, kind: String) -> String:
	if activity=="build":
		return "builder"
	if activity=="guard":
		return "constable"
	if activity=="sell":
		return {"b_restaurant":"server","b_inn":"merchant","b_tavern":"merchant","b_smithy":"smith","b_market":"hawker"}.get(kind,"merchant")
	if owner==world.household_economy.get("civil",-1):
		return "magistrate"
	var families: Array = world.household_economy.get("families",[])
	if owner>=families.size():
		return "buyer"
	var family: Dictionary = families[owner]
	if family["cash"]>=240:
		return "gentry"
	if family["boats"]>0:
		return "fisher"
	if family["cash"]<60 and world.resident_register[owner]["registered"]>=world.current_day()-1:
		return "refugee"
	return "scholar" if kind=="b_inn" else "buyer"


# 门外落脚：优先门向旁的道路，入城建筑只在外围可步行的格子选点。
static func _entry(record: Dictionary, ways: Dictionary, finder: AStarGrid2D) -> Vector2i:
	var at := Vector2i(record["cell"][0],record["cell"][1])
	var footprint: Vector2i = Catalog.footprint(record)
	var front: int = Streets.for_record(record,ways)
	for index: int in range(4):
		var side: int = (front+index)%4
		var origin: Vector2i = Streets.edge_start(at,footprint,side)+Streets.SIDES[side]
		var along := Vector2i.RIGHT if side%2==0 else Vector2i.DOWN
		var span: int = footprint.x if side%2==0 else footprint.y
		for offset: int in range(span):
			var cell: Vector2i = origin + along*((span/2+offset)%span)
			if Capital.OUTER.has_point(cell) and not finder.is_point_solid(cell):
				return cell
	return Grid.INVALID


# 行为模块：到达后停留接货或执勤，办完事沿同一条有效路径回家。
static func draw(canvas: Control, plans: Array[Dictionary], hour: float, time: float, view: Rect2) -> void:
	for plan: Dictionary in plans:
		var elapsed: float = hour-plan["start"]
		var travel: float = plan["travel"]
		var work: float = plan["work"]
		if elapsed<0.0 or elapsed>=2.0*travel+work:
			continue
		var returning: bool = elapsed>=travel+work
		var on_site: bool = elapsed>=travel and not returning
		var distance: float = clampf(minf(elapsed,2.0*travel+work-elapsed)/travel,0.0,1.0)*plan["length"]
		var distances: PackedFloat32Array = plan["distances"]
		var next: int = _segment(distances,distance)
		var points: PackedVector2Array = plan["points"]
		var start: Vector2 = points[next-1]
		var target: Vector2 = points[next]
		var facing: float = signf(target.x-start.x)*(-1.0 if returning else 1.0)
		var point: Vector2 = start.lerp(target,(distance-distances[next-1])/maxf(1.0,distances[next]-distances[next-1]))
		if not view.has_point(point) or canvas.street_view_hidden(point):
			continue
		Pedestrians.draw(canvas,point,plan["role"],posmod(floori(time*7.0)+plan["owner"],6),facing,on_site)
		if on_site and plan["activity"] in ["buy","sell"]:
			var mark: Vector2 = canvas.art_point(point-Vector2(0,58))
			canvas.art_canvas.draw_circle(mark,maxf(1.0,canvas.zoom_level*2.0),Color("#edd293"))


# 位置查找：累计距离使用二分搜索，长距离通勤也只查询当前小段。
static func _segment(distances: PackedFloat32Array, distance: float) -> int:
	var first: int = 1
	var last: int = distances.size()-1
	while first<last:
		var middle: int = (first+last)/2
		if distances[middle]<distance:
			first=middle+1
		else:
			last=middle
	return first
