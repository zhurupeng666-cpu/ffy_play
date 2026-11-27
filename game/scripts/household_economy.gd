## 文件用途：经营居民私产、雇工、店铺、税粮和官将选任，生成可独立验证的日结账。
extends RefCounted

const Terrain = preload("res://scripts/town_terrain.gd")
const Grid = preload("res://scripts/isometric_grid.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Market = preload("res://scripts/district_market.gd")
const Streets = preload("res://scripts/street_frontage.gd")
const Works = preload("res://scripts/royal_works.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const March = preload("res://scripts/region_march.gd")

const LEGACY: Array[String] = ["b_farm", "b_fishery"]
const SHOPS: Array[String] = ["b_tavern", "b_restaurant", "b_bakery", "b_inn"]
const TITLES: Dictionary = {"b_farm": "民田", "b_fishery": "民用码头", "b_tavern": "酒馆", "b_restaurant": "酒楼", "b_bakery": "烘焙铺", "b_inn":"客栈", "b_manor": "府邸"}
const LAND_RATES: Dictionary = {"low": 12, "standard": 18, "high": 25}
const SHOP_RATES: Dictionary = {"low": 14, "standard": 22, "high": 31}
const OFFICE_WEALTH: int = 240
const MANOR_WEALTH: int = 350
const MONEY_CAP: int = 1000000


# 放款与地契迁移：保持户口、工地进度和位置，解除原官营岗位。
static func activate(world: RefCounted, fresh_seed: int = 0) -> void:
	if not world.household_economy.is_empty():
		return
	world.household_economy = {"seed": fresh_seed if fresh_seed > 0 else 61403 + posmod(world.tick * 47 + world.population * 103, 900000), "families": [],
		"property": {}, "civil": -1, "general": -1, "legion": "", "report": {}}
	enroll(world)
	var field_index: int = 0
	var boat_index: int = 0
	for building: Dictionary in world.buildings:
		var kind: String = building["def_id"]
		if kind not in LEGACY:
			continue
		var families: Array = world.household_economy["families"]
		var candidates: Array = []
		for index: int in range(families.size()):
			if world.households[index]["adults"] > 0:
				candidates.append(index)
		if candidates.is_empty():
			continue
		var offset: int = field_index if kind == "b_farm" else boat_index
		var owner: int = candidates[offset % candidates.size()]
		world.household_economy["property"][building["id"]] = owner
		if kind == "b_farm":
			var area: Vector2i = Catalog.footprint(building)
			var family: Dictionary = families[owner]
			family["land"] = mini(500, int(family["land"]) + maxi(3, floori(area.x * area.y / 15.0)))
			field_index += 1
		else:
			families[owner]["boats"] = mini(5, int(families[owner]["boats"]) + 1)
			boat_index += 1
		building["workers"] = 0
		building["food_credit"] = 0
		world.estate_posts.erase(building["id"])
	world.labor_credit = 0 if field_index + boat_index > 0 else world.labor_credit


# 登记模块：家庭只追加，序号为永久编号；同一存档重读后日结结果一致。
static func enroll(world: RefCounted) -> void:
	var state: Dictionary = world.household_economy
	var families: Array = state["families"]
	for index: int in range(families.size(), world.households.size()):
		var seed_value: int = _roll(state["seed"], world.current_day(), index, 1, 100)
		var wealth: int = 25 + floori(seed_value * seed_value * 0.028)
		var acreage: int = (2 + seed_value % 8) if world.households[index]["adults"] > 0 and seed_value % 7 != 0 else 0
		families.append({"cash": wealth, "land": acreage, "boats": 0, "civil": 35 + _roll(state["seed"], 1, index, 2, 57),
			"marshal": 35 + _roll(state["seed"], 1, index, 3, 57), "occupation": "待业", "income": 0, "hired": 0, "tax": 0})


# 可重放扰动：资产、熟练度和每日天气使用独立的抽样通道。
static func _roll(seed: int, day: int, household: int, channel: int, ceiling: int) -> int:
	var key := Vector3i(seed + channel * 21997, day, household)
	return posmod(int(hash(key)), ceiling)


# 财产模块：户内现金之外计入田亩、渔船和不动产的估值。
static func worth(world: RefCounted, index: int) -> int:
	var state: Dictionary = world.household_economy
	var family: Dictionary = state["families"][index]
	var fixed: int = 0
	for id: String in state["property"]:
		if state["property"][id] == index:
			fixed += 80
	return family["cash"] + family["land"] * 14 + family["boats"] * 95 + fixed


# 地籍模块：独立记录私产的归属，不在官府可招工、拆除的建筑名单中。
static func owns(world: RefCounted, id: String) -> bool:
	return world.household_economy.get("property", {}).has(id)


# 结算入口：先释放可用人手，再安排自营和雇工，最后计算税与居民的私粮缺口。
static func settle(world: RefCounted) -> Dictionary:
	var state: Dictionary = world.household_economy
	enroll(world)
	var day: int = world.last_settled_day + 1
	var families: Array = state["families"]
	var jobs: Array[Dictionary] = []
	var fishing: Dictionary = _fishing_access(world)
	var public_jobs: int = world.workforce_capacity() - world.idle_workers()
	var shops: Dictionary = _by_trade(world)
	for offset: int in range(families.size()):
		var index: int = (offset + day) % families.size()
		var adults: int = world.households[index]["adults"]
		# 官府和军队先占用人手，轮换分摊，避免永远扣在最早登记的家庭。
		var assigned: int = mini(adults, maxi(0, public_jobs))
		public_jobs -= assigned
		families[index]["hired"] = 0
		families[index]["income"] = 0
		families[index]["tax"] = 0
		jobs.append({"id": index, "workers": adults - assigned, "assigned": assigned, "farm": 0, "fish": 0, "shop": 0, "catch": 0, "grain": 0, "due": 0})
	for job: Dictionary in jobs:
		var owner: int = job["id"]
		var family: Dictionary = families[owner]
		_reinvest(world, state["seed"], day, owner, family, job["workers"], fishing)
		if shops.has(owner):
			job["shop"] = mini(job["workers"], 2)
		job["fish"] = mini(job["workers"] - job["shop"], int(family["boats"]) * 2)
		job["farm"] = mini(job["workers"] - job["fish"] - job["shop"], ceili(int(family["land"]) / 5.0))
		job["workers"] -= int(job["farm"]) + int(job["fish"]) + int(job["shop"])
	var hands: Array[Dictionary] = []
	for job: Dictionary in jobs:
		if job["workers"] > 0:
			hands.append(job)
	_hire(families, jobs, hands)
	var result: Dictionary = {"day": day, "harvest": 0, "fish": 0, "tax_grain": 0, "fish_levy": 0, "shop_tax": 0, "relief": 0, "hires": 0}
	var season: int = 58 + _roll(state["seed"], day, 0, 11, 64)
	if _roll(state["seed"], day, 0, 19, 100) < 8:
		season -= 21
	var stall_demand: int = mini(12, ceili(world.population / 13.0) + shops.size())
	for job: Dictionary in jobs:
		var index: int = job["id"]
		var family: Dictionary = families[index]
		var wage: int = job.get("wage", 0)
		var cultivated: int = mini(family["land"], job["farm"] * 5)
		var yield_percent: int = season + _roll(state["seed"], day, index, 12, 39)
		job["grain"] = floori(cultivated * 1.4 * yield_percent / 100.0)
		job["catch"] = job["fish"] * (3 + _roll(state["seed"], day, index, 13, 5))
		result["harvest"] += job["grain"]
		result["fish"] += job["catch"]
		var rate: int = LAND_RATES[world.tax_policy]
		var grain_due: int = mini(job["grain"], roundi(job["grain"] * rate / 100.0))
		var fish_due: int = mini(job["catch"], roundi(job["catch"] * rate / 150.0))
		result["tax_grain"] += grain_due
		result["fish_levy"] += fish_due
		job["grain"] += int(job["catch"]) - grain_due - fish_due
		var gross: int = job["shop"] * (4 + stall_demand + _roll(state["seed"], day, index, 14, 7))
		var supplies: int = job["shop"] * 3
		var shop_due: int = roundi(gross * (SHOP_RATES[world.tax_policy] + tax_bonus(world)) / 100.0)
		result["shop_tax"] += shop_due
		result["hires"] += int(family["hired"])
		var net: int = maxi(0,gross-supplies-shop_due)
		if net > 0 and world.capital_layout and not world.royal_works["shares"].is_empty():
			for building: Dictionary in world.buildings:
				var id: String = building["id"]
				if world.royal_works["shares"].has(id) and state["property"].get(id,-1)==index and building["def_id"]==shops.get(index):
					net -= Works.distribute(world,id,net)
					break
		var earnings: int = wage + (int(job["assigned"]) * 2) + net + int(job["workers"])
		_earn(family, earnings)
		# 家用与偶发修缮形成支出，家大业大的账也可能从盈转亏。
		var members: int = int(world.households[index]["adults"]) + world.households[index]["children"].size()
		var repairs: int = 4 + family["boats"] * 2 if _roll(state["seed"], day, index, 22, 100) < 12 else 0
		var expenses: int = mini(family["cash"], floori(members / 2.0) + repairs)
		family["cash"] -= expenses
		family["income"] -= expenses
		family["tax"] = shop_due
		family["occupation"] = _occupation(job, shops.get(index, ""))
		job["due"] = ceili((int(world.households[index]["adults"]) + world.households[index]["children"].size()) * 0.5)
	_trade(world, jobs, result)
	_private_construction(world)
	_invest_in_buildings(world, day, shops)
	state["report"] = result
	return result


# 行业再投资：余钱、家庭工时与水路可达共同决定买田、置船和转行。
static func _reinvest(world: RefCounted, seed: int, day: int, index: int, family: Dictionary, workers: int, fishing: Dictionary) -> void:
	if workers <= 0:
		return
	var chance: int = _roll(seed, day, index, 10, 100)
	if fishing.has(index) and family["boats"] < 5 and family["cash"] >= 105 and chance < 20:
		if world.capital_layout and not Works.buy(world,family,8,0):
			return
		family["cash"] -= 85
		family["boats"] += 1
	elif family["cash"] >= 58 and family["land"] < mini(60, workers * 10 + 5) and chance < 49:
		family["cash"] -= 32
		family["land"] += 2


# 雇工模块：地主和船主向可上工家庭付工钱，同一份工时不能重复雇用。
static func _hire(families: Array, jobs: Array[Dictionary], hands: Array[Dictionary]) -> void:
	var available: int = 0
	for buyer: Dictionary in jobs:
		var owner: Dictionary = families[buyer["id"]]
		var boats_left: int = maxi(0, int(owner["boats"]) * 2 - int(buyer["fish"]))
		var acres_left: int = maxi(0, ceili(int(owner["land"]) / 5.0) - int(buyer["farm"]))
		var vacancies: int = mini(4, boats_left + acres_left)
		while available < hands.size() and vacancies > 0 and int(owner["cash"]) >= 8:
			var worker: Dictionary = hands[available]
			if worker["workers"] <= 0:
				available += 1
				continue
			if worker["id"] == buyer["id"]:
				break
			var task: String = "fish" if boats_left > 0 else "farm"
			buyer[task] += 1
			boats_left -= int(task == "fish")
			worker["workers"] -= 1
			worker["wage"] = int(worker.get("wage", 0)) + 2
			owner["cash"] -= 2
			owner["income"] -= 2
			owner["hired"] += 1
			vacancies -= 1


# 交易模块：先吃自家粮，再按每份1金币买卖本地余粮，公共仓只补当日缺口。
static func _trade(world: RefCounted, jobs: Array[Dictionary], result: Dictionary) -> void:
	var families: Array = world.household_economy["families"]
	var suppliers: Array[Dictionary] = []
	for job: Dictionary in jobs:
		var consumed: int = mini(job["grain"], job["due"])
		job["grain"] -= consumed
		job["due"] -= consumed
		if job["grain"] > 0:
			suppliers.append(job)
	var next: int = 0
	for job: Dictionary in jobs:
		var buyer: Dictionary = families[job["id"]]
		while job["due"] > 0 and buyer["cash"] > 0 and next < suppliers.size():
			var supplier: Dictionary = suppliers[next]
			var bought: int = mini(mini(job["due"], buyer["cash"]), supplier["grain"])
			buyer["cash"] -= bought
			buyer["income"] -= bought
			job["due"] -= bought
			supplier["grain"] -= bought
			_earn(families[supplier["id"]], bought)
			if supplier["grain"] == 0:
				next += 1
		result["relief"] += job["due"]
	for job: Dictionary in suppliers:
		# 本地未售出的余粮只允许有限外销，过剩会压低收益。
		_earn(families[job["id"]], mini(5, floori(int(job["grain"]) / 2.0)))


# 财务模块：规范居民现金上限并保留实际到账收入。
static func _earn(family: Dictionary, amount: int) -> void:
	var stored: int = mini(amount, MONEY_CAP - int(family["cash"]))
	family["cash"] += stored
	family["income"] += stored


# 户籍职业：按实际投入记录业主、受雇者和领取官府工钱的居民。
static func _occupation(job: Dictionary, shop: String) -> String:
	var activities: PackedStringArray = []
	if job["farm"] > 0:
		activities.append("耕作")
	if job["fish"] > 0:
		activities.append("捕鱼")
	if job["shop"] > 0:
		activities.append(TITLES[shop])
	if job.get("wage", 0) > 0:
		activities.append("受雇")
	if job["assigned"] > 0:
		activities.append("公役或军职")
	if job["workers"] > 0:
		activities.append("杂工")
	return "、".join(activities) if not activities.is_empty() else "暂未就业"


# 商业档案：只按完工店铺结算，不将迁移中的农地与渔业资产当商铺。
static func _by_trade(world: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	var property: Dictionary = world.household_economy["property"]
	for building: Dictionary in world.buildings:
		if building["state"] == "ready" and building["def_id"] in SHOPS and property.has(building["id"]):
			result[property[building["id"]]] = building["def_id"]
	return result


# 居住环境：码头主人始终可出海，临水住宅为其他家庭提供购船机会。
static func _fishing_access(world: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	var property: Dictionary = world.household_economy["property"]
	var house_index: int = 0
	for record: Dictionary in world.buildings:
		if record["state"] != "ready":
			continue
		if record["def_id"] == "b_fishery" and property.has(record["id"]):
			result[property[record["id"]]] = true
		elif record["def_id"] == "b_house":
			var cell := Vector2i(record["cell"][0], record["cell"][1])
			var shore: Vector2i = Terrain.river_span(cell.x)
			var gap: int = mini(absi(cell.y - shore.x), absi(cell.y - shore.y))
			var first: int = 12 + house_index * 3
			if gap <= 10:
				for index: int in range(first, mini(first + 3, world.households.size())):
					result[index] = true
			house_index += 1
	return result


# 私人工地：保留历史进度，接手的家庭自行完工，不占用官府施工队。
static func _private_construction(world: RefCounted) -> void:
	var state: Dictionary = world.household_economy
	for record: Dictionary in world.buildings:
		if record["state"] != "constructing" or not state["property"].has(record["id"]):
			continue
		var owner: int = state["property"][record["id"]]
		record["work_done"] = mini(record["work_required"], record["work_done"] + maxi(1, int(world.households[owner]["adults"])) * 10)
		if record["work_done"] == record["work_required"]:
			record["state"] = "ready"


# 商铺与府邸：成熟市场附近择址，先检查地段再扣住户资产，不占官府账。
static func _invest_in_buildings(world: RefCounted, day: int, trades: Dictionary) -> void:
	var state: Dictionary = world.household_economy
	if world.buildings.size() + world.royal_works["roads"].size() >= 256 or world.next_building_id >= 1000000:
		return
	var markets: Array[Vector2i] = []
	var ways: Array[Vector2i] = []
	var manors: Dictionary = {}
	var field_owners: Dictionary = {}
	for record: Dictionary in world.buildings:
		if record["state"] != "ready":
			continue
		var cell := Vector2i(record["cell"][0], record["cell"][1])
		match record["def_id"]:
			"b_market": markets.append(cell)
			"b_road":
				ways.append_array(Placement.footprint_cells(cell, Catalog.footprint(record)))
			"b_manor": manors[state["property"].get(record["id"], -1)] = true
			"b_farm": field_owners[state["property"].get(record["id"], -1)] = true
	if ways.is_empty():
		return
	var families: Array = state["families"]
	if families.is_empty():
		return
	var occupied: Dictionary = world.occupied_cells()
	var established: Dictionary = Streets.network(world.buildings, world.capital_layout)
	for offset: int in range(families.size()):
		var owner: int = (day + offset) % families.size()
		var family: Dictionary = families[owner]
		if world.households[owner]["adults"] < 1 or family["cash"] < 130 or _roll(state["seed"], day, owner, 16, 100) >= 25:
			continue
		var kind: String = ""
		var price: int = 95
		if not markets.is_empty() and not trades.has(owner) and trades.size() < markets.size() * 4:
			kind = SHOPS[_roll(state["seed"], day, owner + trades.size(), 17, SHOPS.size())]
		elif not manors.has(owner) and family["cash"] >= 225 and worth(world, owner) >= MANOR_WEALTH:
			kind = "b_manor"
			price = 160
		elif family["land"] >= 6 and not field_owners.has(owner) and field_owners.size() * 5 < ways.size():
			kind = "b_farm"
			price = 0
		if kind.is_empty():
			continue
		var definition: Resource = Catalog.for_construction(kind, world.capital_layout and kind == "b_manor")
		var slot: Vector2i = _shop_site(ways, markets, definition, occupied, world.capital_layout)
		if slot != Grid.INVALID:
			if world.capital_layout:
				var wood: int = 28 if kind=="b_manor" else (4 if kind=="b_farm" else 12)
				var stone: int = 16 if kind=="b_manor" else (0 if kind=="b_farm" else 6)
				if family["cash"] < price+Works.price(wood,stone) or not Works.buy(world,family,wood,stone):
					continue
			family["cash"] -= price
			family["income"] -= price
			var id: String = Market.found(world, slot, definition)
			if kind != "b_farm":
				var front: int = Streets.direction(slot, definition.get("footprint"), established)
				if front >= 0:
					world.buildings.back()["front"] = front
			state["property"][id] = owner
			return


# 临街选址：商铺距集市有限；府邸也需道路，且不能挤占既有建筑。
static func _shop_site(ways: Array[Vector2i], markets: Array[Vector2i], definition: Resource, occupied: Dictionary, cleared_city: bool = false) -> Vector2i:
	ways.sort()
	for road: Vector2i in ways:
		var near: bool = definition.id in ["b_manor", "b_farm"]
		for market: Vector2i in markets:
			if road.distance_squared_to(market) <= 196:
				near = true
				break
		if not near:
			continue
		for direction: Vector2i in Terrain.CARDINALS:
			var shift := Vector2i(-int(definition.footprint.x) if direction.x < 0 else direction.x,
				-int(definition.footprint.y) if direction.y < 0 else direction.y)
			var centered := Vector2i(floori((definition.footprint.x - 1) * 0.5) if direction.y != 0 else 0, floori((definition.footprint.y - 1) * 0.5) if direction.x != 0 else 0)
			var candidate: Vector2i = road + shift - centered
			if Placement.check_building(candidate, definition, occupied, cleared_city)["ok"]:
				return candidate
	return Grid.INVALID


# 选人门槛：至少一名成人，家资达标，且相应文武能力合格。
static func eligible(world: RefCounted, index: int, military: bool) -> bool:
	if world.household_economy.is_empty() or index < 0 or index >= world.household_economy["families"].size():
		return false
	if world.households[index]["adults"] == 0 or worth(world, index) < OFFICE_WEALTH:
		return false
	var family: Dictionary = world.household_economy["families"][index]
	return int(family["marshal"] if military else family["civil"]) >= 60


# 任命规则：文武不能由同户兼任，武将要绑定一支驻主城的现役军团。
static func appoint(world: RefCounted, index: int, military: bool, legion: String = "") -> bool:
	if not eligible(world, index, military):
		return false
	var state: Dictionary = world.household_economy
	if military:
		if state["civil"] == index or not _active_legion(world, legion) or March.away(world, legion):
			return false
		if not state["legion"].is_empty() and March.away(world, state["legion"]):
			return false
		state["general"] = index
		state["legion"] = legion
	else:
		if state["general"] == index:
			return false
		state["civil"] = index
	return true


# 军团校验：只认权威军团清单中的可出战现役队伍。
static func _active_legion(world: RefCounted, id: String) -> bool:
	for legion: Dictionary in world.legions:
		if legion["id"] == id and legion["state"] == "active" and not legion["members"].is_empty():
			return true
	return false


# 恢复模块：校验私产对应真实建筑、家庭编号与同日公仓、税账。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != 7 or not _integer(raw.get("seed"), 1, 1000000):
		return false
	var people: Variant = raw.get("families")
	var titles: Variant = raw.get("property")
	if not people is Array or people.size() != world.households.size() or not titles is Dictionary:
		return false
	var families: Array = []
	var limits: Dictionary = {"cash": Vector2i(0, MONEY_CAP), "land": Vector2i(0, 500), "boats": Vector2i(0, 5),
		"civil": Vector2i(35, 91), "marshal": Vector2i(35, 91), "income": Vector2i(-1000, 1000), "hired": Vector2i(0, 4), "tax": Vector2i(0, 1000)}
	for person: Variant in people:
		if not person is Dictionary or person.size() != 9 or not person.get("occupation") is String or person["occupation"].length() > 80:
			return false
		var family: Dictionary = {"occupation": person["occupation"]}
		for key: String in limits:
			var span: Vector2i = limits[key]
			if not _integer(person.get(key), span.x, span.y):
				return false
			family[key] = int(person[key])
		families.append(family)
	var property: Dictionary = {}
	for building: Dictionary in world.buildings:
		var id: String = building["id"]
		if building["def_id"] in LEGACY + SHOPS + ["b_manor"]:
			if not _integer(titles.get(id), 0, people.size() - 1) or int(building["workers"]) > 0:
				return false
			property[id] = int(titles[id])
	if property.size() != titles.size():
		return false
	var civil: Variant = raw.get("civil")
	var general: Variant = raw.get("general")
	var legion: Variant = raw.get("legion")
	if not _integer(civil, -1, people.size() - 1) or not _integer(general, -1, people.size() - 1) or not legion is String:
		return false
	if (general == -1) != legion.is_empty() or (civil >= 0 and civil == general) or legion.length() > 32:
		return false
	var saved_report: Variant = raw.get("report")
	if not saved_report is Dictionary:
		return false
	var report: Dictionary = {}
	if not saved_report.is_empty():
		if saved_report.size() != 8:
			return false
		for key: String in ["day", "harvest", "fish", "tax_grain", "fish_levy", "shop_tax", "relief", "hires"]:
			if not _integer(saved_report.get(key), 0, 1000000):
				return false
			report[key] = int(saved_report[key])
		var sources: Dictionary = world.last_food_ledger.get("by_source", {})
		if report["day"] != world.last_settled_day or report["tax_grain"] > report["harvest"] or report["fish_levy"] > report["fish"]:
			return false
		if report["tax_grain"] != sources.get("tax_grain") or report["fish_levy"] != sources.get("fish_levy") or report["relief"] != world.last_food_ledger.get("relief_needed"):
			return false
		if report["shop_tax"] != world.last_civic_ledger.get("shop_gold", {}).get("income", 0):
			return false
	elif world.last_food_ledger.has("relief_needed") or world.last_civic_ledger.has("shop_gold"):
		return false
	world.household_economy = {"seed": int(raw["seed"]), "families": families, "property": property, "civil": int(civil),
		"general": int(general), "legion": legion, "report": report}
	return true


# 数值模块：限制整数区间并统一 JSON 的数值表示。
static func _integer(value: Variant, lower: int, upper: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(float(value)) and value >= lower and value <= upper


# 官员效果：文官按能力提高清收，武将只影响亲自指挥部队的开战值。
static func tax_bonus(world: RefCounted) -> int:
	var state: Dictionary = world.household_economy
	var index: int = state.get("civil", -1)
	return floori(int(state["families"][index]["civil"]) / 9.0) if index >= 0 else 0


# 战场加成：只在开战时结算，避免中途换将改写已保存战斗。
static func commander_bonus(world: RefCounted, legion: String) -> int:
	var state: Dictionary = world.household_economy
	var index: int = state.get("general", -1)
	if index >= 0 and state.get("legion") == legion and _active_legion(world, legion):
		return mini(14, floori(int(state["families"][index]["marshal"]) / 6.0))
	return 0
