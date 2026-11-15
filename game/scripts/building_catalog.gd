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
const HALL = preload("res://data/buildings/hall.tres")


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
		"b_hall":
			return HALL
	return null
