## 文件用途：保存奏章、垦荒申请和田块账，供领主审批及回顾臣属处置。
extends RefCounted

const CAPACITY: int = 120
const CLAIM_LIMIT: int = 12
const CROPS: Array[String] = ["小麦","粟米","高粱"]
const SECTIONS: Array[String] = ["农政","工程","臣属","军务","民生","财务"]


# 初始档案：审批队列、田块台账和已办事项使用独立存储。
static func initial() -> Dictionary:
	return {"claims":[],"fields":{},"items":[]}


# 记事模块：常规奏报限量保留，待批申请单独保存。
static func note(world: RefCounted, category: String, title: String, detail: String) -> void:
	if not world.capital_layout:
		return
	var entries: Array = world.chancery["items"]
	entries.append({"day":world.current_day(),"group":category,"title":title,"detail":detail})
	if entries.size()>CAPACITY:
		entries.pop_front()


# 数字校验：存档 JSON 只允许有界整数，不接受浮点半亩或负数。
static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high


# 读档模块：核验待审批人的身份、审批时效和田块现有地契。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary or raw.size()!=3 or not raw.get("claims") is Array or not raw.get("fields") is Dictionary or not raw.get("items") is Array:
		return false
	if raw["claims"].size()>CLAIM_LIMIT or raw["items"].size()>CAPACITY:
		return false
	var copy: Dictionary = initial()
	var claimed: Dictionary = {}
	for row: Variant in raw["claims"]:
		if not row is Dictionary or row.size()!=4 or not _integer(row.get("owner"),0,world.households.size()-1) or not _integer(row.get("day"),1,world.current_day()) or not _integer(row.get("crop"),0,CROPS.size()-1) or not _integer(row.get("acres"),2,6):
			return false
		var owner: int = int(row["owner"])
		if claimed.has(owner):
			return false
		claimed[owner]=true
		copy["claims"].append({"owner":owner,"day":int(row["day"]),"crop":int(row["crop"]),"acres":int(row["acres"])})
	var buildings: Dictionary = {}
	for record: Dictionary in world.buildings:
		if record["def_id"]=="b_farm" and world.household_economy["property"].has(record["id"]):
			buildings[record["id"]]=true
	if raw["fields"].size()!=buildings.size():
		return false
	var acreage: Dictionary = {}
	for id: Variant in raw["fields"]:
		var plot: Variant = raw["fields"][id]
		if not buildings.has(id) or not plot is Dictionary or plot.size()!=3 or not _integer(plot.get("crop"),0,CROPS.size()-1) or not _integer(plot.get("acres"),0,500) or not _integer(plot.get("yield"),-1,2000):
			return false
		var owner: int = world.household_economy["property"][id]
		acreage[owner]=int(acreage.get(owner,0))+int(plot["acres"])
		copy["fields"][id]={"crop":int(plot["crop"]),"acres":int(plot["acres"]),"yield":int(plot["yield"])}
	for owner: int in acreage:
		if acreage[owner]!=world.household_economy["families"][owner]["land"]:
			return false
	for item: Variant in raw["items"]:
		if not item is Dictionary or item.size()!=4 or not _integer(item.get("day"),1,world.current_day()) or item.get("group") not in SECTIONS:
			return false
		if not item.get("title") is String or item["title"].length()>60 or not item.get("detail") is String or item["detail"].length()>256:
			return false
		copy["items"].append({"day":int(item["day"]),"group":item["group"],"title":item["title"],"detail":item["detail"]})
	world.chancery=copy
	return true
