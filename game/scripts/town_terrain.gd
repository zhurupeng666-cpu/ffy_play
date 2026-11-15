## 文件用途：定义原型城镇固定水域，并统一检查陆地占地和渔场临水要求。
extends RefCounted
const Grid = preload("res://scripts/isometric_grid.gd")

# 地形模块：地图北侧y=0为河道，规则为静态地图配置，不存储重复格表。
static func is_water(cell: Vector2i) -> bool:
	return Grid.contains(cell) and cell.y == 0

# 地形校验模块：建筑完整落在陆地，渔场至少一格正交邻接河道。
static func check(cells: Array[Vector2i], requires_water: bool) -> Dictionary:
	var waterfront: bool = false
	for cell: Vector2i in cells:
		if is_water(cell):
			return {"ok": false, "code": "WATER", "reason": "河道水域不能建造，请选择岸上空地"}
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if is_water(cell + offset):
				waterfront = true
	if requires_water and not waterfront:
		return {"ok": false, "code": "NEEDS_WATER", "reason": "渔场必须沿水建造：占地至少一格紧邻蓝色河道"}
	return {"ok": true}
