## 文件用途：管理皇宫三处可布置院落和装饰存档，限制摆放范围与重叠。
extends RefCounted

const AREAS: Array[Rect2i] = [Rect2i(128,-150,10,25), Rect2i(163,-150,9,26), Rect2i(110,-67,16,7), Rect2i(128,-115,8,17)]
const NAMES: Array[String] = ["西苑小院", "东苑小院", "礼仪花庭", "西书房"]
const ITEMS: Array[String] = ["石灯", "盆景", "石几", "莲池", "凉亭", "屏风"]
const STYLES: Array[String] = ["青砖", "暖石", "青苔卵石"]


# 尺寸模块：水景和凉亭占用多个地格。
static func size_for(kind: int) -> Vector2i:
	return Vector2i(3,3) if kind in [3,4] else (Vector2i(2,1) if kind == 5 else Vector2i.ONE)


# 初始布局：示范品分散到三院，留出完整空地供玩家修改。
static func initial() -> Dictionary:
	return {"styles":[0,1,2,0],"items":[[0,129,-148],[1,135,-147],[2,130,-140],[3,130,-135],
		[4,166,-145],[1,164,-148],[0,170,-144],[5,165,-134],
		[1,111,-65],[1,123,-65],[0,115,-62],[2,120,-65],[5,130,-112],[2,132,-108],[0,134,-103]]}


# 命中模块：右键点到装饰任一占地格就能撤掉整件。
static func item_at(layout: Dictionary, cell: Vector2i) -> int:
	for i: int in range(layout["items"].size()):
		var item: Array = layout["items"][i]
		if Rect2i(Vector2i(item[1],item[2]),size_for(item[0])).has_point(cell):
			return i
	return -1


# 校验模块：整件留在所选院内，周围空地与已有装饰不发生重叠。
static func can_place(layout: Dictionary, court: int, kind: int, cell: Vector2i) -> bool:
	if court < 0 or court >= AREAS.size() or kind < 0 or kind >= ITEMS.size() or layout["items"].size() >= 96:
		return false
	var area := Rect2i(cell,size_for(kind))
	if not AREAS[court].grow(-1).encloses(area):
		return false
	for item: Array in layout["items"]:
		if area.intersects(Rect2i(Vector2i(item[1],item[2]),size_for(item[0]))):
			return false
	return true


# 读档模块：拒绝越界、重叠或非法类型，统一恢复整数。
static func restore(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("styles") is Array or raw["styles"].size() != AREAS.size() or not raw.get("items") is Array:
		return {}
	var result: Dictionary = {"styles":[],"items":[]}
	for style: Variant in raw["styles"]:
		if not _integer(style,0,STYLES.size()-1):
			return {}
		result["styles"].append(int(style))
	for item: Variant in raw["items"]:
		if not item is Array or item.size() != 3 or not _integer(item[0],0,ITEMS.size()-1) or not _integer(item[1],90,210) or not _integer(item[2],-175,-47):
			return {}
		var cell := Vector2i(int(item[1]),int(item[2]))
		var accepted: bool = false
		for court: int in range(AREAS.size()):
			if can_place(result,court,int(item[0]),cell):
				result["items"].append([int(item[0]),cell.x,cell.y])
				accepted = true
				break
		if not accepted:
			return {}
	return result


# 数字模块：兼容 JSON 中整数形式的小数类型。
static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and value == floor(float(value)) and value >= minimum and value <= maximum
