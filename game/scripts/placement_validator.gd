## 文件用途：纯数据检查建筑矩形占地的尺寸、边界和重叠，不扣费也不创建建筑。
extends RefCounted

const Grid = preload("res://scripts/isometric_grid.gd")


# 占地模块：将锚点及尺寸展开为独立逻辑格，尺寸异常时不执行大循环。
static func footprint_cells(anchor: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if size.x <= 0 or size.y <= 0 or size.x > Grid.SIZE.x or size.y > Grid.SIZE.y:
		return cells
	for y: int in range(size.y):
		for x: int in range(size.x):
			cells.append(anchor + Vector2i(x, y))
	return cells


# 校验模块：先检查尺寸和整块边界，再检查占用，返回稳定错误码与可读原因。
static func check(anchor: Vector2i, size: Vector2i, occupied: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = footprint_cells(anchor, size)
	if cells.is_empty():
		return {"ok": false, "code": "INVALID_SIZE", "reason": "建筑尺寸配置无效", "cells": cells}
	for cell: Vector2i in cells:
		if not Grid.contains(cell):
			return {"ok": false, "code": "OUT_OF_BOUNDS", "reason": "占地越界：建筑必须完整位于地图内", "cells": cells}
	for cell: Vector2i in cells:
		if occupied.has(cell):
			return {"ok": false, "code": "OCCUPIED", "reason": "占地重叠：(%d,%d)已被建筑占用" % [cell.x, cell.y], "cells": cells}
	return {"ok": true, "code": "OK", "reason": "位置合法（仅预览，未建造、未扣费）", "cells": cells}


# 建筑校验模块：几何、占用和地形共用同一入口，预览与确认不会出现规则分歧。
static func check_building(anchor: Vector2i, definition: Resource, occupied: Dictionary) -> Dictionary:
	var result: Dictionary = check(anchor, definition.get("footprint"), occupied)
	if result["ok"]:
		var terrain: Dictionary = preload("res://scripts/town_terrain.gd").check(result["cells"], definition.get("requires_water"))
		if not terrain["ok"]:
			result["ok"] = false
			result["code"] = terrain["code"]
			result["reason"] = terrain["reason"]
	return result
