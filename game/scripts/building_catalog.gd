## 文件用途：集中查找稳定建筑定义ID，避免存档或命令直接加载任意资源路径。
extends RefCounted

# 注册模块：静态定义只读，实例存档只保存定义ID。
const HOUSE = preload("res://data/buildings/house.tres")
const FARM = preload("res://data/buildings/farm.tres")
const RANCH = preload("res://data/buildings/ranch.tres")
const FISHERY = preload("res://data/buildings/fishery.tres")
const GRANARY = preload("res://data/buildings/granary.tres")
const LUMBER = preload("res://data/buildings/lumber.tres")
const QUARRY = preload("res://data/buildings/quarry.tres")
const PRODUCERS: Array[String] = ["b_farm", "b_ranch", "b_fishery", "b_lumber", "b_quarry"]
const BARRACKS = preload("res://data/buildings/barracks.tres")
const HALL = preload("res://data/buildings/hall.tres")
const ROAD = preload("res://data/buildings/road.tres")
const WALL = preload("res://data/buildings/wall.tres")
const GATE = preload("res://data/buildings/gate.tres")
const SMITHY = preload("res://data/buildings/smithy.tres")
const MARKET = preload("res://data/buildings/market.tres")
const TAVERN = preload("res://data/buildings/tavern.tres")
const RESTAURANT = preload("res://data/buildings/restaurant.tres")
const BAKERY = preload("res://data/buildings/bakery.tres")
const MANOR = preload("res://data/buildings/manor.tres")
const INN = preload("res://data/buildings/inn.tres")


# 场地模块：独立维护大型用地尺寸，保留原类型、生产和军营归属。
const LARGE_SIZES: Dictionary = {"b_farm": Vector2i(20, 20), "b_ranch": Vector2i(20, 20), "b_barracks": Vector2i(20, 20), "b_granary": Vector2i(10, 10), "b_fishery": Vector2i(24, 20), "b_manor": Vector2i(15, 15), "b_road": Vector2i(3, 3), "b_restaurant": Vector2i(8, 7), "b_inn": Vector2i(8, 8), "b_tavern": Vector2i(6, 6)}


# 尺寸模块：实例规格同时用于占地校验、选择和绘制。
static func footprint(record: Dictionary, prior_large: bool = false) -> Vector2i:
	var id: String = record["def_id"]
	var base: Vector2i = find(id).get("footprint")
	if not record.get("large", false):
		return base
	if prior_large or record.get("legacy_large", false):
		return base * 2
	return LARGE_SIZES[id]


# 预览模块：生成独立配置，避免更改同类现有建筑的共享资源。
static func for_construction(id: String, large: bool) -> Resource:
	var definition: Resource = find(id)
	if not large:
		return definition
	if definition == null or not LARGE_SIZES.has(id):
		return null
	definition = definition.duplicate()
	definition.set("footprint", footprint({"def_id": id, "large": true}))
	if id == "b_road":
		definition.set("display_name", "宽街")
		definition.set("build_work", 12)
	definition.set_meta("large", true)
	return definition


# 查询模块：未知ID返回空值，不能通过存档指定脚本或文件路径。
static func find(id: String) -> Resource:
	match id:
		"b_house":
			return HOUSE
		"b_farm":
			return FARM
		"b_ranch":
			return RANCH
		"b_fishery":
			return FISHERY
		"b_granary":
			return GRANARY
		"b_lumber":
			return LUMBER
		"b_quarry":
			return QUARRY
		"b_barracks":
			return BARRACKS
		"b_hall":
			return HALL
		"b_road":
			return ROAD
		"b_wall":
			return WALL
		"b_gate":
			return GATE
		"b_smithy":
			return SMITHY
		"b_market":
			return MARKET
		"b_tavern":
			return TAVERN
		"b_restaurant":
			return RESTAURANT
		"b_bakery":
			return BAKERY
		"b_manor":
			return MANOR
		"b_inn":
			return INN
	return null
