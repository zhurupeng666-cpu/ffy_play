## 文件用途：为已有家庭登记稳定人员姓名、年龄、住址和实际赋税，不重复创建人口。
extends RefCounted

const SURNAMES = ["陈","林","徐","沈","顾","周","许","赵","韩","宋","郑","庄","裴","江","叶","陆"]
const NAMES = ["明远","春禾","景安","云岫","成礼","玉兰","庭竹","若水","秀宁","守义","长乐","素琴","望舒","小满","清和","子正","云舟","文成","知秋"]
const START_HOUSING: int = 30


# 人员登记：成熟日保留在个人记录中，儿童成年后原姓名继续使用。
static func sync_people(world: RefCounted) -> void:
	var entries: Array = world.resident_register
	var day: int = mini(world.current_day(),world.last_settled_day+1)
	for index: int in range(world.households.size()):
		var family: Dictionary = world.households[index]
		if index >= entries.size():
			entries.append({"people":[],"address":"","registered":day,"grain":0,"fish":0,"commerce":0})
		var people: Array = entries[index]["people"]
		var child_dates: Array = family["children"].duplicate()
		var adult_count: int = 0
		for person: Dictionary in people:
			if person["majority"] <= day:
				adult_count += 1
			else:
				child_dates.erase(person["majority"])
		while adult_count < family["adults"]:
			var age: int = 19 + posmod(hash(Vector2i(index,adult_count)),36)
			people.append({"majority":day - (age-18)*120,"name":_name(index,people.size())})
			adult_count += 1
		for date: int in child_dates:
			people.append({"majority":date,"name":_name(index,people.size())})


# 名称模块：给同户成员相同姓氏，名和字序在登记时固定。
static func _name(index: int, number: int) -> String:
	return SURNAMES[index % SURNAMES.size()] + NAMES[(index*7 + number*3) % NAMES.size()]


# 年龄模块：成年前按现有游戏成年日历换算，成年后每120游戏日进一岁。
static func age(person: Dictionary, day: int) -> int:
	var span: int = day - int(person["majority"])
	return 18 + floori(span / 120.0) if span >= 0 else clampi(18 + span,0,17)


# 房屋分配：优先自有府邸和自建住宅，其次保留旧址，再分配有余量的民居。
static func assign_homes(world: RefCounted) -> void:
	var homes: Dictionary = {}
	var remaining: Dictionary = {"building_000001":START_HOUSING}
	var property: Dictionary = world.household_economy.get("property",{})
	var deeds: Dictionary = world.royal_works["homes"]
	for record: Dictionary in world.buildings:
		if record["state"] != "ready" or record["def_id"] not in ["b_house","b_manor"]:
			continue
		var id: String = record["id"]
		if record["def_id"] == "b_house":
			remaining[id] = 10
		var owner: int = property.get(id,-1) if record["def_id"] == "b_manor" else deeds.get(id,-1)
		if owner >= 0 and (not homes.has(owner) or record["def_id"]=="b_manor"):
			homes[owner]=id
	var entries: Array = world.resident_register
	for owner: int in range(entries.size()):
		var entry: Dictionary = entries[owner]
		if homes.has(owner):
			entry["address"]=homes[owner]
			if remaining.has(entry["address"]):
				remaining[entry["address"]] -= entry["people"].size()
	# 已入住的完整家庭优先留在原址，空屋随后分配。
	for index: int in range(entries.size()):
		if homes.has(index):
			continue
		var entry: Dictionary = entries[index]
		var address: String = entry["address"]
		if remaining.has(address) and remaining[address] >= entry["people"].size():
			remaining[address] -= entry["people"].size()
			homes[index]=address
	for index: int in range(entries.size()):
		if homes.has(index):
			continue
		var entry: Dictionary = entries[index]
		entry["address"] = ""
		for address: String in remaining:
			if address != "building_000001" and remaining[address] >= entry["people"].size():
				entry["address"] = address
				break
		if entry["address"].is_empty() and remaining["building_000001"] >= entry["people"].size():
			entry["address"] = "building_000001"
		if not entry["address"].is_empty():
			remaining[entry["address"]] -= entry["people"].size()


# 旧府邸迁址：相邻院落之间留六格，先找道路周边合法空地。
static func spread_manors(world: RefCounted) -> void:
	var Streets = preload("res://scripts/street_frontage.gd")
	var P = preload("res://scripts/placement_validator.gd")
	var Catalog = Streets.Catalog
	var ways: Dictionary = Streets.network(world.buildings,true)
	var placed: Array[Rect2i] = []
	var taken: Dictionary = world.occupied_cells()
	var definition: Resource = Catalog.for_construction("b_manor",true)
	for record: Dictionary in world.buildings:
		if record["def_id"] != "b_manor" or not record.get("large",false):
			continue
		var start := Vector2i(record["cell"][0],record["cell"][1])
		var area := Rect2i(start,Vector2i(15,15))
		if _spaced(area,placed):
			placed.append(area)
			continue
		var site: Vector2i = Streets.Capital.Grid.INVALID
		var best: int = 1000000000
		for road: Vector2i in ways:
			for side: Vector2i in Streets.SIDES:
				var cell: Vector2i = road + side*(15 if side.x<0 or side.y<0 else 1)
				cell -= Vector2i(7,0) if side.y!=0 else Vector2i(0,7)
				var candidate := Rect2i(cell,Vector2i(15,15))
				var cost: int = cell.distance_squared_to(start)
				if cost>=best or not Streets.Capital.OUTER.encloses(candidate) or not _spaced(candidate,placed):
					continue
				if P.check_building(cell,definition,taken,true)["ok"]:
					best=cost
					site=cell
		if site == Streets.Capital.Grid.INVALID:
			placed.append(area)
			continue
		for cell: Vector2i in P.footprint_cells(start,area.size):
			taken.erase(cell)
		for cell: Vector2i in P.footprint_cells(site,area.size):
			taken[cell]=record["id"]
		record["cell"]=[site.x,site.y]
		record["front"]=Streets.direction(site,area.size,ways)
		for receipt: Dictionary in world.applied_commands.values():
			if receipt["building_id"]==record["id"]:
				receipt["cell"]=record["cell"].duplicate()
				break
		placed.append(Rect2i(site,area.size))


# 查验院落留白：扩边后不能与其他府邸占地相交。
static func _spaced(area: Rect2i, placed: Array[Rect2i]) -> bool:
	for other: Rect2i in placed:
		if other.grow(6).intersects(area):
			return false
	return true


# 反查住户：空屋返回空集合，合住住宅逐户列出。
static func residents(world: RefCounted,id: String) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(world.resident_register.size()):
		if world.resident_register[i]["address"]==id:
			result.append(i)
	return result


# 身份模块：户主承担实际官职；儿童和其他家庭成员分别登记。
static func identity(world: RefCounted,house: int,person: int) -> String:
	var record: Dictionary = world.resident_register[house]["people"][person]
	if record["majority"]>world.current_day():
		return "未成年"
	if person==0:
		if world.household_economy.get("civil")==house:
			return "户主 · 税务官"
		if world.household_economy.get("general")==house:
			return "户主 · 武将"
		if house < world.household_economy.get("families",[]).size():
			return "户主 · " + world.household_economy["families"][house]["occupation"]
		return "户主"
	return "成年家属"


# 格式化模块：成员信息和同一套年龄模型供建筑卡与户帖使用。
static func member_line(world: RefCounted,house: int,person: int) -> String:
	var record: Dictionary = world.resident_register[house]["people"][person]
	return "%s  ·  %d岁  ·  %s" % [record["name"],age(record,world.current_day()),identity(world,house,person)]


# 恢复模块：人口数量、姓名、成年日期、住宅与实际税额必须可核对。
static func restore(world: RefCounted,raw: Variant) -> bool:
	if not raw is Array or raw.size()!=world.households.size():
		return false
	var valid_addresses: Dictionary = {"building_000001":true,"":true}
	for record: Dictionary in world.buildings:
		if record["state"]=="ready" and record["def_id"] in ["b_house","b_manor"]:
			valid_addresses[record["id"]]=true
	var entries: Array = []
	var day: int = world.current_day()
	for i: int in range(raw.size()):
		var info: Variant = raw[i]
		var family: Dictionary = world.households[i]
		if not info is Dictionary or info.size()!=6 or not info.get("people") is Array or not valid_addresses.has(info.get("address")):
			return false
		if info["people"].size() != int(family["adults"])+family["children"].size():
			return false
		var entry: Dictionary = {"address":info["address"],"people":[]}
		for key: String in ["registered","grain","fish","commerce"]:
			var number: Variant = info.get(key)
			if not _whole(number,0,1000000000) or (key=="registered" and (number<1 or number>day)):
				return false
			entry[key]=int(number)
		var dates: Array = []
		for person: Variant in info["people"]:
			if not person is Dictionary or person.size()!=2 or not person.get("name") is String or person["name"].is_empty() or person["name"].length()>12 or not _whole(person.get("majority"),-12000000,day+120):
				return false
			var born: int = int(person["majority"])
			if born>day:
				dates.append(born)
			entry["people"].append({"name":person["name"],"majority":born})
		dates.sort()
		if dates!=family["children"]:
			return false
		entries.append(entry)
	world.resident_register=entries
	return true


# 数字模块：统一整数和 JSON 中的整数型浮点。
static func _whole(value: Variant,low: int,high: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and value==floor(float(value)) and value>=low and value<=high
