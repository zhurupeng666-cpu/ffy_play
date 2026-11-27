## 文件用途：处理皇家木石销售、居民自建、道路工程招标和店铺入股。
extends RefCounted

const Market = preload("res://scripts/district_market.gd")
const Catalog = Market.Catalog
const Streets = Market.Streets
const Place = Market.Placement
const Capital = Streets.Capital
const Grid = Capital.Grid
const WOOD_PRICE: int = 2
const STONE_PRICE: int = 3
const ROAD_BUDGET: int = 42
const INVESTMENT: int = 60
const MAX_SHARE: int = 50
const ROAD_STOCK := Vector2i(3,6)
const ELIGIBLE_SHOPS: Array[String] = ["b_restaurant","b_inn"]


# 初始账本：订单、产权与累计交易分开保存。
static func initial() -> Dictionary:
	return {"roads":[],"homes":{},"shares":{},"wood":0,"stone":0,"sales":0,"dividends":0,"paid":0}


# 标准售价：所有私人项目用同一价目。
static func price(wood: int, stone: int) -> int:
	return wood * WOOD_PRICE + stone * STONE_PRICE


# 材料交易：完整检查前不调整任何一方账目。
static func buy(world: RefCounted, family: Dictionary, wood: int, stone: int) -> bool:
	var due: int = price(wood,stone)
	if wood < 0 or stone < 0 or family["cash"] < due or world.resources["wood"] < wood or world.resources["stone"] < stone:
		return false
	if world.resources["gold"] > 1000000000 - due:
		return false
	family["cash"] -= due
	family["income"] -= due
	world.resources["wood"] -= wood
	world.resources["stone"] -= stone
	world.resources["gold"] += due
	world.royal_works["wood"] += wood
	world.royal_works["stone"] += stone
	world.royal_works["sales"] += due
	return true


# 发标：占地与最高预算一起登记，重复点击无法重复占用或扣款。
static func publish(world: RefCounted, cell: Vector2i) -> Dictionary:
	var definition: Resource = Catalog.for_construction("b_road",true)
	var check: Dictionary = Place.check_building(cell,definition,world.occupied_cells(),true)
	if not check["ok"]:
		return check
	var roads: Array = world.royal_works["roads"]
	if roads.size() >= 64 or world.buildings.size()+roads.size() >= 256 or world.resources["gold"] < ROAD_BUDGET:
		return {"ok":false,"reason":"工程名额或皇家招标预算不足"}
	world.resources["gold"] -= ROAD_BUDGET
	roads.append({"cell":[cell.x,cell.y],"posted":world.last_settled_day,"owner":-1,"due":0,"bid":0})
	return {"ok":true}


# 预留格：防止其他工地在投标或施工期间覆盖道路。
static func reserved(roads: Array) -> Dictionary:
	var taken: Dictionary = {}
	for order: Dictionary in roads:
		var cell := Vector2i(order["cell"][0],order["cell"][1])
		for tile: Vector2i in Place.footprint_cells(cell,Vector2i(3,3)):
			taken[tile] = "road-contract"
	return taken


# 工程日结：先选择最低价的合格富商，下一日验收付款并结清皇家材料费用。
static func settle(world: RefCounted) -> void:
	var day: int = world.last_settled_day
	var families: Array = world.household_economy["families"]
	var finished: Array = []
	var active: Dictionary = {}
	for order: Dictionary in world.royal_works["roads"]:
		if order["owner"] >= 0:
			active[order["owner"]] = true
	for order: Dictionary in world.royal_works["roads"]:
		var worker: int = order["owner"]
		if worker < 0 and day > order["posted"]:
			_award(world,order,active,day)
		elif worker >= 0 and day >= order["due"] and world.buildings.size() < 256 and world.next_building_id < 1000000:
			var amount: int = order["bid"]
			var refund: int = ROAD_BUDGET-amount
			var family: Dictionary = families[worker]
			var materials: int = price(ROAD_STOCK.x,ROAD_STOCK.y)
			if rights_blocked(world,refund,materials):
				continue
			family["cash"] += amount
			if not buy(world,family,ROAD_STOCK.x,ROAD_STOCK.y):
				family["cash"] -= amount
				continue
			family["income"] += amount
			family["cash"] = mini(family["cash"],1000000)
			world.resources["gold"] += refund
			world.royal_works["paid"] += amount
			var cell := Vector2i(order["cell"][0],order["cell"][1])
			Market.found(world,cell,Catalog.for_construction("b_road",true))
			finished.append(order)
	for order: Dictionary in finished:
		world.royal_works["roads"].erase(order)
	_build_home(world,day)


# 资金保护：材料收入及未用预算都须可完整入账。
static func rights_blocked(world: RefCounted, refund: int, materials: int) -> bool:
	return world.resources["gold"] > 1000000000 - refund - materials


# 投标：家资、商业地产及成人资格设置门槛，同户同时承建一项。
static func _award(world: RefCounted, order: Dictionary, active: Dictionary, day: int) -> void:
	var best: int = ROAD_BUDGET+1
	var owner: int = -1
	var assets: Dictionary = world.household_economy["property"]
	var merchants: Dictionary = {}
	for building: Dictionary in world.buildings:
		if building["def_id"] in ["b_tavern","b_bakery","b_restaurant","b_inn","b_manor"] and building["state"] == "ready" and assets.has(building["id"]):
			merchants[assets[building["id"]]] = true
	for index: int in range(world.households.size()):
		if active.has(index) or world.households[index]["adults"] < 1:
			continue
		var family: Dictionary = world.household_economy["families"][index]
		if family["cash"] + family["land"]*14 + (85 if merchants.has(index) else 0) < 240:
			continue
		var offer: int = 30 + posmod(hash(Vector3i(world.household_economy["seed"],order["posted"],index)),13)
		if offer < best:
			best = offer
			owner = index
	if owner >= 0:
		order["owner"] = owner
		order["bid"] = best
		order["due"] = day+1
		active[owner] = true


# 民居自建：住房压力触发，按日轮换家庭并靠近现有住区找临街地。
static func _build_home(world: RefCounted,day: int) -> void:
	if world.housing_capacity()-world.population >= 12 or world.buildings.size()+world.royal_works["roads"].size() >= 256 or world.next_building_id >= 1000000:
		return
	var families: Array = world.household_economy["families"]
	var owners: Array = world.royal_works["homes"].values()
	var chosen: int = -1
	for offset: int in range(families.size()):
		var index: int = (day+offset)%families.size()
		if index not in owners and families[index]["cash"] >= 44 and world.households[index]["adults"] > 0:
			chosen = index
			break
	if chosen < 0:
		return
	var ways: Dictionary = Streets.network(world.buildings,true)
	var candidates: Array = ways.keys()
	candidates.sort_custom(func(a:Vector2i,b:Vector2i)->bool:
		var hub := Vector2i(7,7)
		var left: int = a.distance_squared_to(hub)
		var right: int = b.distance_squared_to(hub)
		return left < right if left != right else a < b)
	var blocked: Dictionary = world.occupied_cells()
	for road: Vector2i in candidates:
		for side: Vector2i in Streets.SIDES:
			var cell: Vector2i = road + side*(2 if side.x<0 or side.y<0 else 1)
			if not Capital.OUTER.encloses(Rect2i(cell,Vector2i(2,2))) or not Place.check_building(cell,Catalog.HOUSE,blocked,true)["ok"]:
				continue
			var front: int = Streets.direction(cell,Vector2i(2,2),ways)
			if front < 0 or not buy(world,families[chosen],12,6):
				continue
			families[chosen]["cash"] -= 2
			families[chosen]["income"] -= 2
			var id: String = Market.found(world,cell,Catalog.HOUSE)
			world.buildings.back()["front"] = front
			world.royal_works["homes"][id] = chosen
			return


# 股权入口：皇室以十个百分点为一份认购，最多占股一半。
static func invest(world: RefCounted, id: String) -> bool:
	var shares: Dictionary = world.royal_works["shares"]
	if shares.get(id,0) >= MAX_SHARE or world.resources["gold"] < INVESTMENT:
		return false
	var owner: int = world.household_economy["property"].get(id,-1)
	if owner < 0:
		return false
	for record: Dictionary in world.buildings:
		if record["id"] == id and record["state"] == "ready" and record["def_id"] in ELIGIBLE_SHOPS:
			var family: Dictionary = world.household_economy["families"][owner]
			if family["cash"] > 1000000-INVESTMENT:
				return false
			world.resources["gold"] -= INVESTMENT
			family["cash"] += INVESTMENT
			shares[id] = int(shares.get(id,0))+10
			return true
	return false


# 分红按店铺当日净利计算，款从商户收益中划拨。
static func distribute(world: RefCounted, shop_id: String, net_profit: int) -> int:
	var share: int = world.royal_works["shares"].get(shop_id,0)
	var paid: int = mini(1000000000-world.resources["gold"],floori(net_profit*share/100.0))
	world.resources["gold"] += paid
	world.royal_works["dividends"] += paid
	return paid


# 恢复模块：核验产权、工程时间与地块，保证旧档和坏档都可安全判断。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary or raw.size()!=8:
		return false
	var loaded: Dictionary = initial()
	for label: String in ["wood","stone","sales","dividends","paid"]:
		if not _integer(raw.get(label),0,1000000000000):
			return false
		loaded[label]=int(raw[label])
	var records: Dictionary = {}
	for record: Dictionary in world.buildings:
		records[record["id"]]=record
	for key: String in ["homes","shares"]:
		if not raw.get(key) is Dictionary:
			return false
		for id: Variant in raw[key]:
			if not records.has(id):
				return false
			var kind: String = records[id]["def_id"]
			var value: Variant = raw[key][id]
			if key == "homes" and (kind!="b_house" or not _integer(value,0,world.households.size()-1)):
				return false
			if key == "shares" and (kind not in ELIGIBLE_SHOPS or not world.household_economy["property"].has(id) or not _integer(value,10,MAX_SHARE) or int(value)%10!=0):
				return false
			loaded[key][id]=int(value)
	if not raw.get("roads") is Array or raw["roads"].size()>64 or world.buildings.size()+raw["roads"].size()>256:
		return false
	var occupied: Dictionary = world.occupied_cells()
	for order: Variant in raw["roads"]:
		if not order is Dictionary or order.size()!=5 or not order.get("cell") is Array or order["cell"].size()!=2:
			return false
		if not _integer(order["cell"][0],-Grid.WORLD_LIMIT,Grid.WORLD_LIMIT) or not _integer(order["cell"][1],-Grid.WORLD_LIMIT,Grid.WORLD_LIMIT):
			return false
		if not _integer(order.get("owner"),-1,world.households.size()-1) or not _integer(order.get("posted"),0,world.last_settled_day):
			return false
		if not _integer(order.get("due"),0,world.last_settled_day+1) or not _integer(order.get("bid"),0,ROAD_BUDGET):
			return false
		if (order["owner"]<0 and (order["bid"]!=0 or order["due"]!=0)) or (order["owner"]>=0 and (order["bid"]<30 or order["due"]<=order["posted"])):
			return false
		var cell := Vector2i(int(order["cell"][0]),int(order["cell"][1]))
		if not Place.check_building(cell,Catalog.for_construction("b_road",true),occupied,true)["ok"]:
			return false
		var normalized: Dictionary = {"cell":[cell.x,cell.y],"posted":int(order["posted"]),"owner":int(order["owner"]),"due":int(order["due"]),"bid":int(order["bid"])}
		loaded["roads"].append(normalized)
		occupied.merge(reserved([normalized]))
	world.royal_works = loaded
	return true


# 数值模块：拒绝不完整字段，统一 JSON 整数。
static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and value==floor(float(value)) and value>=minimum and value<=maximum
