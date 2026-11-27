## 文件用途：安排城外农牧地块、迁移旧地契，并生成农户每日过城门的通勤路线。
extends RefCounted

const Market = preload("res://scripts/district_market.gd")
const Place = Market.Placement
const Catalog = Market.Catalog
const Capital = Market.Streets.Capital
const Grid = Capital.Grid
const Pedestrians = preload("res://scripts/capital_pedestrian_art.gd")
const Activity = preload("res://scripts/town_compound_art.gd")
const Book = preload("res://scripts/memorial_book.gd")
const FARM_KINDS: Array[String] = ["b_farm","b_ranch","b_barracks"]
const CLAIM_DURATION: int = 9
const CROP_FACTORS: Array[float] = [1.4,1.5,1.35]
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


# 田畴分块：同一片先布完再开下一片，按四格对齐并让相邻地块共享田埂。
static func field_site(definition: Resource, occupied: Dictionary) -> Vector2i:
	var span: Vector2i = definition.footprint
	for district: Rect2i in Capital.FIELD_DISTRICTS:
		for y: int in range(district.position.y,district.end.y-span.y+1,4):
			for x: int in range(district.position.x,district.end.x-span.x+1,4):
				var at := Vector2i(x,y)
				if Place.check_building(at,definition,occupied,true)["ok"]:
					return at
	return Grid.INVALID


# 迁址模块：旧农田优先按规模归并，城内军营和牧场保留驻军、岗位、进度与原ID。
static func relocate(world: RefCounted, migrate: bool) -> bool:
	var occupied: Dictionary = world.occupied_cells()
	var receipts: Dictionary = {}
	for receipt: Dictionary in world.applied_commands.values():
		receipts[receipt["building_id"]]=receipt
	var fields: Array[Dictionary] = []
	for record: Dictionary in world.buildings:
		if record["def_id"] not in FARM_KINDS:
			continue
		var anchor := Vector2i(record["cell"][0],record["cell"][1])
		var span: Vector2i = Catalog.footprint(record)
		var must_move: bool = Capital.OUTER.intersects(Rect2i(anchor,span))
		if record["def_id"]=="b_farm" and migrate:
			fields.append(record)
			for tile: Vector2i in Place.footprint_cells(anchor,span):
				occupied.erase(tile)
			continue
		if migrate:
			for district: Rect2i in Capital.FIELD_DISTRICTS:
				must_move=must_move or district.intersects(Rect2i(anchor,span))
		if not must_move:
			continue
		if not migrate:
			return false
		var definition: Resource = Catalog.find(record["def_id"]).duplicate()
		definition.footprint=span
		var target: Vector2i = site(definition,occupied)
		if target==Grid.INVALID:
			return false
		for tile: Vector2i in Place.footprint_cells(anchor,span):
			occupied.erase(tile)
		_move(record,receipts[record["id"]],target,span,occupied)
	fields.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var width_a: int = Catalog.footprint(a).x
		var width_b: int = Catalog.footprint(b).x
		return a["id"]<b["id"] if width_a==width_b else width_a>width_b)
	for field: Dictionary in fields:
		var span: Vector2i = Catalog.footprint(field)
		var definition: Resource = Catalog.FARM.duplicate()
		definition.footprint=span
		var target: Vector2i = field_site(definition,occupied)
		if target==Grid.INVALID:
			return false
		_move(field,receipts[field["id"]],target,span,occupied)
	return true


# 坐标同步：后续选择、招募和存档仍使用同一建筑和同一命令回执。
static func _move(record: Dictionary, receipt: Dictionary, target: Vector2i, span: Vector2i, occupied: Dictionary) -> void:
	for tile: Vector2i in Place.footprint_cells(target,span):
		occupied[tile]=record["id"]
	record["cell"]=[target.x,target.y]
	receipt["cell"]=record["cell"].duplicate()


# 旧地籍补录：只登记历史上已经拥有的亩数，不批准新的地权。
static func survey(world: RefCounted) -> void:
	var titles: Dictionary = world.household_economy["property"]
	var farms: Dictionary = {}
	for record: Dictionary in world.buildings:
		if record["def_id"]=="b_farm" and titles.has(record["id"]):
			farms[titles[record["id"]]]=true
	var occupied: Dictionary = world.occupied_cells()
	for index: int in range(world.households.size()):
		if world.buildings.size()+world.Works.pending_slots(world)>=256 or world.next_building_id>=1000000:
			break
		if farms.has(index) or world.household_economy["families"][index]["land"]<=0:
			continue
		var cell: Vector2i = field_site(Catalog.FARM,occupied)
		if cell==Grid.INVALID:
			break
		var id: String = Market.found(world,cell,Catalog.FARM)
		titles[id]=index
		for tile: Vector2i in Place.footprint_cells(cell,Catalog.FARM.footprint):
			occupied[tile]=id
	sync_titles(world)


# 分亩模块：旧田按地块大小分摊已有亩数，新批田保留原有分块及种植记录。
static func sync_titles(world: RefCounted) -> void:
	var by_house: Dictionary = {}
	var titles: Dictionary = world.household_economy["property"]
	var fields: Dictionary = world.chancery["fields"]
	for record: Dictionary in world.buildings:
		if record["def_id"]=="b_farm" and titles.has(record["id"]):
			var owner: int = titles[record["id"]]
			if not by_house.has(owner):
				by_house[owner]=[]
			by_house[owner].append(record)
	for owner: int in by_house:
		var remaining: int = world.household_economy["families"][owner]["land"]
		var weight: int = 0
		for record: Dictionary in by_house[owner]:
			if fields.has(record["id"]):
				remaining-=fields[record["id"]]["acres"]
			else:
				weight+=Catalog.footprint(record).x
		for record: Dictionary in by_house[owner]:
			var id: String = record["id"]
			if fields.has(id):
				continue
			var width: int = Catalog.footprint(record).x
			var acres: int = floori(maxi(0,remaining)*width/float(weight))
			fields[id]={"crop":posmod(hash(id),Book.CROPS.size()),"acres":acres,"yield":-1}
			remaining-=acres
			weight-=width


# 申请生成：有可支配劳力及启动资金的家庭按种子抽取，每日最多两份、每户一份。
static func petition(world: RefCounted, owner: int, day: int, workers: int) -> void:
	var queue: Array = world.chancery["claims"]
	var family: Dictionary = world.household_economy["families"][owner]
	if workers<=0 or family["cash"]<40 or family["land"]>=mini(58,workers*10+5) or queue.size()>=Book.CLAIM_LIMIT:
		return
	var today: int = 0
	for item: Dictionary in queue:
		if item["owner"]==owner:
			return
		today+=int(item["day"]==day)
	var roll: int = posmod(hash(Vector3i(world.household_economy["seed"],day,owner)),100)
	if today>=2 or roll>=34:
		return
	queue.append({"owner":owner,"day":day,"crop":roll%Book.CROPS.size(),"acres":2+roll%mini(5,workers+2)})


# 到期模块：陈旧申请归入奏章历史，随后的日期可以重新呈报。
static func expire(world: RefCounted) -> void:
	var queue: Array = world.chancery["claims"]
	for index: int in range(queue.size()-1,-1,-1):
		var claim: Dictionary = queue[index]
		if world.current_day()-int(claim["day"])<CLAIM_DURATION:
			continue
		world.post_report("农政","垦荒申请到期",world.household_name(claim["owner"])+"的申请逾期，农户可重新呈报。")
		queue.remove_at(index)


# 朱批模块：先校验原申请、可用田块、库存和额度，再扣农户费用并登记地权。
static func rule(world: RefCounted, claim: Dictionary, approved: bool) -> String:
	var queue: Array = world.chancery["claims"]
	var index: int = queue.find(claim)
	if index<0:
		return "该奏请已经处理"
	var owner: int = claim["owner"]
	var detail: String = "%s · %d亩 · %s" % [world.household_name(owner),claim["acres"],Book.CROPS[claim["crop"]]]
	if not approved:
		queue.remove_at(index)
		world.post_report("农政","垦荒申请驳回",detail)
		return ""
	if world.buildings.size()+world.Works.pending_slots(world)>=256 or world.next_building_id>=1000000:
		return "郊区地契名额已满"
	var site_cell: Vector2i = field_site(Catalog.FARM,world.occupied_cells())
	if site_cell==Grid.INVALID:
		return "暂无可开垦地块"
	var family: Dictionary = world.household_economy["families"][owner]
	if family["cash"]<40 or world.households[owner]["adults"]<=0 or family["land"]+claim["acres"]>500:
		return "该户暂缺开垦资金、劳力或剩余土地额度"
	if not world.Works.buy(world,family,4,0):
		return "皇家木材或库存额度不足"
	family["cash"]-=32
	family["land"]+=int(claim["acres"])
	var id: String = Market.found(world,site_cell,Catalog.FARM,8+int(claim["acres"])*2)
	world.household_economy["property"][id]=owner
	world.chancery["fields"][id]={"crop":claim["crop"],"acres":claim["acres"],"yield":-1}
	queue.remove_at(index)
	world.post_report("农政","垦荒申请获准",detail+" · 已划地，进入清地、整地和播种工序。")
	return ""


# 闭合账目：同户劳力按比例耕种各块，累计取整确保耕种亩数不会超出户内劳力。
static func harvest(world: RefCounted, owner: int, cultivated: int, weather: int, active: Variant = null) -> int:
	var available: Dictionary = active_fields(world) if active==null else active
	var group: Dictionary = available.get(owner,{"acres":0,"plots":[]})
	var fields: Dictionary = world.chancery["fields"]
	var total: int = int(group["acres"])
	var prior: int = 0
	var acres_so_far: int = 0
	var grain: int = 0
	for id: String in group["plots"]:
		var plot: Dictionary = fields[id]
		acres_so_far+=int(plot["acres"])
		var worked: int = 0 if total==0 else floori(float(acres_so_far)*cultivated/total)
		var modifier: float = CROP_FACTORS[plot["crop"]]
		var amount: int = floori(maxi(0,worked-prior)*modifier*weather/100.0)
		plot["yield"]=amount
		grain+=amount
		prior=worked
	return grain


# 生产边界：权属可在施工前登记，只有播种完工的地块纳入耕种和收成。
static func active_fields(world: RefCounted) -> Dictionary:
	var grouped: Dictionary = {}
	var fields: Dictionary = world.chancery["fields"]
	var titles: Dictionary = world.household_economy["property"]
	for record: Dictionary in world.buildings:
		var id: String = record["id"]
		if record["state"]!="ready" or not fields.has(id):
			continue
		var owner: int = titles[id]
		if not grouped.has(owner):
			grouped[owner]={"acres":0,"plots":[]}
		grouped[owner]["acres"]+=fields[id]["acres"]
		grouped[owner]["plots"].append(id)
	return grouped


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
			var furrow: int = posmod(floori((hour-7.5)*1.1)+owner,4)
			var stride: float = pingpong(scenery*0.7+owner,1.0)
			at+=Vector2((stride-0.5)*62,(stride-0.5)*30)+Vector2((furrow-1.5)*14,-(furrow-1.5)*7)
		if view.has_point(at) and (work or not canvas.street_view_hidden(at)):
			var facing: float = signf((target.x-start.x)*(1.0 if outbound<inbound else -1.0))
			if work:
				Activity._field_worker(canvas,at,sin(scenery*4.0+owner),true,owner)
			else:
				Pedestrians.draw(canvas,at,"farmer",floori(scenery*7.0)%6,facing,false)


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
