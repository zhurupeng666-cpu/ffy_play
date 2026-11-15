## 文件用途：定义原型城镇河道、森林与石矿，统一检查陆地占地及对应资源相邻要求。
extends RefCounted
const Grid = preload("res://scripts/isometric_grid.gd")

# 地形模块：地图北侧y=0为河道，规则为静态地图配置，不存储重复格表。
static func is_water(cell: Vector2i) -> bool:
	return Grid.contains(cell) and cell.y == 0

# 地形校验模块：建筑完整落在陆地，渔场至少一格正交邻接河道。
static func check(cells: Array[Vector2i], requires_water: bool, required_deposit: String = "") -> Dictionary:
	var waterfront: bool = false
	var deposit_nearby: bool = false
	for cell: Vector2i in cells:
		if is_water(cell):
			return {"ok": false, "code": "WATER", "reason": "河道水域不能建造，请选择岸上空地"}
		if not deposit_at(cell).is_empty():
			return {"ok": false, "code": "DEPOSIT", "reason": "资源点不能直接建造，请选择紧邻资源点的空地"}
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if is_water(cell + offset):
				waterfront = true
			if not required_deposit.is_empty() and deposit_at(cell + offset) == required_deposit:
				deposit_nearby = true
	if requires_water and not waterfront:
		return {"ok": false, "code": "NEEDS_WATER", "reason": "渔场必须沿水建造：占地至少一格紧邻蓝色河道"}
	if not required_deposit.is_empty() and not deposit_nearby:
		return {"ok": false, "code": "NEEDS_DEPOSIT", "reason": "须紧邻森林资源点" if required_deposit == "forest" else "须紧邻石矿资源点"}
	return {"ok": true}


# 资源点模块：固定林地和石矿不枯竭，未来扩展枯竭时再引入动态矿量与地图版本。
static func deposit_at(cell: Vector2i) -> String:
	if cell.x == 0 and cell.y in [11, 12, 13]:
		return "forest"
	if cell.x == 15 and cell.y in [4, 5, 6]:
		return "stone"
	return ""
