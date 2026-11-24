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


# 资源点模块：保留原地块，新增树林和矿点分布在外围建设带。
const DEPOSITS: Dictionary = {
	Vector2i(0, 11): "forest", Vector2i(0, 12): "forest", Vector2i(0, 13): "forest",
	Vector2i(15, 4): "stone", Vector2i(15, 5): "stone", Vector2i(15, 6): "stone",
	Vector2i(27, 11): "forest", Vector2i(28, 11): "forest", Vector2i(28, 12): "forest", Vector2i(29, 11): "forest",
	Vector2i(14, 26): "forest", Vector2i(15, 26): "forest", Vector2i(15, 27): "forest",
	Vector2i(43, 28): "forest", Vector2i(44, 28): "forest", Vector2i(44, 29): "forest",
	Vector2i(56, 12): "stone", Vector2i(57, 12): "stone", Vector2i(57, 13): "stone",
	Vector2i(31, 40): "stone", Vector2i(32, 40): "stone", Vector2i(33, 40): "stone",
	Vector2i(66, 41): "forest", Vector2i(67, 41): "forest", Vector2i(67, 42): "forest",
	Vector2i(58, 55): "stone", Vector2i(59, 55): "stone", Vector2i(59, 56): "stone",
	Vector2i(101, 28): "forest", Vector2i(102, 28): "forest", Vector2i(102, 29): "forest",
	Vector2i(157, 37): "stone", Vector2i(158, 37): "stone", Vector2i(158, 38): "stone",
	Vector2i(37, 102): "forest", Vector2i(38, 102): "forest", Vector2i(38, 103): "forest",
	Vector2i(86, 121): "stone", Vector2i(87, 121): "stone", Vector2i(86, 122): "stone",
	Vector2i(131, 103): "forest", Vector2i(132, 103): "forest", Vector2i(132, 104): "forest",
	Vector2i(176, 114): "stone", Vector2i(177, 114): "stone", Vector2i(177, 115): "stone",
	Vector2i(49, 164): "stone", Vector2i(50, 164): "stone", Vector2i(50, 165): "stone",
	Vector2i(129, 168): "forest", Vector2i(130, 168): "forest", Vector2i(130, 169): "forest",
	Vector2i(179, 179): "forest", Vector2i(180, 179): "forest", Vector2i(180, 180): "forest",
}

# 查询模块：静态资源表同供建造规则和场景渲染使用。
static func deposit_at(cell: Vector2i) -> String:
	return DEPOSITS.get(cell, "")
