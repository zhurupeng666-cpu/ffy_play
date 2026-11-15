## 文件用途：计算和校验木材石材最近一日日结，保留数值安全上限的入库与溢出记录。
extends RefCounted
const KEYS: Array[String] = ["wood", "stone"]
const LIMIT: int = 1000000000

# 日结模块：分别记录材料期初、生产、入库与期末，材料当前没有游戏性仓储容量。
static func calculate(day: int, resources: Dictionary, outputs: Dictionary) -> Dictionary:
	var result: Dictionary = {"day": day}
	for key: String in KEYS:
		var opening: int = int(resources[key])
		var produced: int = int(outputs[key])
		var stored: int = mini(produced, maxi(0, LIMIT - opening))
		result[key] = {"opening": opening, "produced": produced, "stored": stored, "overflow": produced - stored, "closing": opening + stored}
	return result

# 数值模块：材料账目仅接收有限非负整数。
static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= LIMIT and float(value) == floor(float(value))

# 校验模块：迁移档可没有历史记录，有记录时必须满足日期与库存守恒。
static func valid(raw: Variant, settled_day: int) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if raw.size() != 3 or not _integer(raw.get("day")) or raw["day"] != settled_day or settled_day < 1:
		return false
	var opening: Dictionary = {}
	var outputs: Dictionary = {}
	for key: String in KEYS:
		if not raw.get(key) is Dictionary or raw[key].size() != 5:
			return false
		for field: String in ["opening", "produced", "stored", "overflow", "closing"]:
			if not _integer(raw[key].get(field)):
				return false
		opening[key] = int(raw[key]["opening"])
		outputs[key] = int(raw[key]["produced"])
	var expected: Dictionary = calculate(settled_day, opening, outputs)
	for key: String in KEYS:
		for field: String in expected[key]:
			if int(raw[key][field]) != int(expected[key][field]):
				return false
	return true

# 恢复模块：只对已校验账单调用，统一JSON读取后的整数类型。
static func restore(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	return calculate(int(raw["day"]), {"wood": raw["wood"]["opening"], "stone": raw["stone"]["opening"]}, {"wood": raw["wood"]["produced"], "stone": raw["stone"]["produced"]})
