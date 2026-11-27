## 文件用途：定义外城、皇城、城门、城墙和御用设施的固定格网布局。
extends RefCounted

const Grid = preload("res://scripts/isometric_grid.gd")
const OUTER := Rect2i(-15, -230, 300, 300)
# 农区按完整田畴划片，最东和最西两条城外驿道接入田间。
const FIELD_DISTRICTS: Array[Rect2i] = [
	Rect2i(303,-91,40,40), Rect2i(-73,-91,40,40), Rect2i(303,-141,40,40),
	Rect2i(-73,-141,40,40), Rect2i(303,-41,40,40), Rect2i(-73,-41,40,40),
	Rect2i(353,-91,40,40), Rect2i(-123,-91,40,40), Rect2i(353,-141,40,40),
	Rect2i(-123,-141,40,40), Rect2i(303,-191,40,40), Rect2i(-73,-191,40,40),
]
const INNER := Rect2i(90, -175, 120, 128)
const BOULEVARDS: Array[Rect2i] = [
	Rect2i(145, -237, 10, 68), Rect2i(145, -49, 10, 123),
	Rect2i(-21, -76, 114, 10), Rect2i(207, -76, 84, 10),
	Rect2i(142, -171, 16, 120), Rect2i(94, -104, 112, 7),
	Rect2i(94, -65, 112, 8), Rect2i(111, -44, 77, 22),
]
const ROYAL: Array[Array] = [
	["ceremony", "太和殿", "gold", Rect2i(137, -86, 26, 17), "外朝正殿，举行登基、册封和朝贺等典礼。"],
	["rest", "中和殿", "gold", Rect2i(144, -98, 12, 9), "大典前候仪、阅看礼文的小殿。"],
	["banquet", "保和殿", "gold", Rect2i(137, -117, 26, 15), "外朝后殿，设朝宴和殿试场地。"],
	["living", "乾清宫", "ruby", Rect2i(139, -132, 22, 12), "内廷前宫，用于起居和召见近臣。"],
	["seals", "交泰殿", "gold", Rect2i(144, -142, 12, 8), "保管皇室印信和仪礼器物。"],
	["queen", "坤宁宫", "ruby", Rect2i(138, -155, 24, 11), "内廷正宫，设生活院落与祭仪空间。"],
	["garden", "御花园", "garden", Rect2i(123, -172, 54, 14), "亭榭、曲径、花圃与水池组成的御苑。"],
	["culture", "文华殿", "jade", Rect2i(173, -95, 29, 13), "讲学、典籍和文治政务。"],
	["military", "武英殿", "jade", Rect2i(98, -95, 28, 13), "武臣典礼与宫廷典籍事务的外朝配殿。"],
	["ancestral", "太庙", "altar", Rect2i(173, -80, 29, 13), "祖先祭祀与皇家礼仪。"],
	["soil", "社稷坛", "altar", Rect2i(98, -80, 28, 13), "祭祀土地与五谷，设坛台和附属祀屋。"],
	["east_homes", "东六宫", "residence", Rect2i(173, -149, 30, 28), "六处相连但独立的内廷起居院。"],
	["west_homes", "西六宫", "residence", Rect2i(97, -149, 30, 28), "六处相连但独立的内廷起居院。"],
	["dowager", "慈宁宫", "ruby", Rect2i(97, -166, 21, 13), "供皇太后起居及宫廷礼仪的院落。"],
	["retirement", "宁寿宫", "ruby", Rect2i(182, -166, 21, 13), "皇室颐养及礼仪院落。"],
	["treasury", "内府库坊", "service", Rect2i(99, -119, 25, 13), "衣料、文书、器用等宫廷物资的库房。"],
	["steward", "内务府", "service", Rect2i(176, -119, 25, 13), "总理宫廷日用、修造、人员及采办。"],
	["cabinet", "内阁衙署", "service", Rect2i(100, -60, 26, 8), "处理章奏、起草诏令和存放文书的官署。"],
	["kitchen", "御膳房", "service", Rect2i(175, -60, 25, 8), "设灶间、备料房和御膳杂役院。"],
	["guard", "禁卫值房", "service", Rect2i(128, -65, 11, 9), "宫门值守、换班和器物检查。"],
	["clock", "钟鼓值楼", "jade", Rect2i(161, -65, 11, 9), "宫门更鼓、礼仪报时。"],
]
const GATES: Array[Array] = [
	["north_gate", "北城门", Rect2i(140, -234, 20, 12), true, "外城北门，连通北郊大道。"],
	["south_gate", "南城门", Rect2i(140, 61, 20, 12), true, "外城南门，连接城内主街与城外河港。"],
	["west_gate", "西城门", Rect2i(-19, -81, 12, 20), false, "外城西门，商旅往来通道。"],
	["east_gate", "东城门", Rect2i(277, -81, 12, 20), false, "外城东门，通往郊道与林矿。"],
	["palace_south", "午门", Rect2i(140, -53, 20, 10), true, "皇城正门，连接礼仪广场和外朝。"],
	["palace_north", "神武门", Rect2i(143, -179, 14, 10), true, "皇城北门，邻近后苑。"],
	["palace_west", "西华门", Rect2i(85, -110, 11, 13), false, "皇城西侧门。"],
	["palace_east", "东华门", Rect2i(204, -110, 11, 13), false, "皇城东侧门。"],
]
static var reserved: Dictionary = {}
static var landmarks: Dictionary = {}


# 地标模块：用稳定ID共享点选、导航和占地记录。
static func buildings() -> Dictionary:
	if landmarks.is_empty():
		for entry: Array in ROYAL:
			_add(entry[0], entry[1], entry[2], entry[3], entry[4])
		for entry: Array in GATES:
			_add(entry[0], entry[1], "gate_ns" if entry[3] else "gate_ew", entry[2], entry[4])
		for corner: Vector2i in [INNER.position, Vector2i(INNER.end.x - 4, INNER.position.y), INNER.end - Vector2i(4, 4), Vector2i(INNER.position.x, INNER.end.y - 4)]:
			_add("tower_%d" % landmarks.size(), "皇城角楼", "gold", Rect2i(corner,Vector2i(4, 4)), "皇城四角的望楼。")
	return landmarks


# 地标注册：保留足迹和用途说明，沿用建筑点选协议。
static func _add(key: String, label: String, kind: String, area: Rect2i, description: String) -> void:
	var id: String = "capital/" + key
	landmarks[id] = {"id": id, "title": label, "region": "capital", "def_id": kind,
		"cell": [area.position.x, area.position.y], "size": area.size, "description": description}


# 城墙模块：四边按城门洞口断开，渲染与占地使用相同墙段。
static func walls(area: Rect2i, palace: bool) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var thick: int = 3 if palace else 4
	for side: int in range(4):
		var gate: Array = GATES[(4 if palace else 0) + side]
		var opening: Rect2i = gate[2]
		if side < 2:
			var row: int = area.position.y if side == 0 else area.end.y - thick
			result.append(Rect2i(area.position.x, row, opening.position.x - area.position.x, thick))
			result.append(Rect2i(opening.end.x, row, area.end.x - opening.end.x, thick))
		else:
			var column: int = area.position.x if side == 2 else area.end.x - thick
			result.append(Rect2i(column, area.position.y + thick, thick, opening.position.y - area.position.y - thick))
			result.append(Rect2i(column, opening.end.y, thick, area.end.y - opening.end.y - thick))
	return result


# 摆放模块：仅保留城墙、大道、门楼和禁地，普通城区仍可扩建。
static func occupation() -> Dictionary:
	if reserved.is_empty():
		var areas: Array[Rect2i] = walls(OUTER, false)
		areas.append(INNER)
		for area: Rect2i in BOULEVARDS:
			areas.append(area.intersection(OUTER))
		for area: Rect2i in areas:
			for y: int in range(area.position.y, area.end.y):
				for x: int in range(area.position.x, area.end.x):
					reserved[Vector2i(x,y)] = "capital/reserved"
		for record: Dictionary in buildings().values():
			var cell := Vector2i(record["cell"][0], record["cell"][1])
			var span: Vector2i = record["size"]
			for y: int in range(span.y):
				for x: int in range(span.x):
					reserved[cell + Vector2i(x,y)] = record["id"]
	return reserved


# 交通模块：城墙外与宫苑核心使用景观路线，寻路不会穿过院落墙。
static func walks() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Grid.cell_to_world(Vector2i(149,-234)), Grid.cell_to_world(Vector2i(149,-183))]),
		PackedVector2Array([Grid.cell_to_world(Vector2i(149,-44)), Grid.cell_to_world(Vector2i(149,72))]),
		PackedVector2Array([Grid.cell_to_world(Vector2i(-19,-71)), Grid.cell_to_world(Vector2i(84,-71))]),
		PackedVector2Array([Grid.cell_to_world(Vector2i(219,-71)), Grid.cell_to_world(Vector2i(288,-71))]),
		PackedVector2Array([Grid.cell_to_world(Vector2i(114,-37)), Grid.cell_to_world(Vector2i(135,-37)), Grid.cell_to_world(Vector2i(150,-43))]),
		PackedVector2Array([Grid.cell_to_world(Vector2i(150,-54)), Grid.cell_to_world(Vector2i(150,-66))]),
	]
