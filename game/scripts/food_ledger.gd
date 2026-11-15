## 文件用途：独立计算和校验最近一日粮食账单，统一仓储入库、溢出与消费顺序。
extends RefCounted
const SOURCES: Array[String] = ["b_farm", "b_ranch", "b_fishery"]

# 结算模块：先接收容量内的新粮，再供居民消费，旧有超容量库存不被删除。
static func calculate(day: int, opening: int, capacity: int, sources: Dictionary, population: int) -> Dictionary:
	var produced: int = 0
	var normalized: Dictionary = {}
	for id: String in SOURCES:
		normalized[id] = int(sources[id])
		produced += normalized[id]
	var stored: int = mini(produced, maxi(0, capacity - opening))
	var needed: int = ceili(population * 0.5)
	var consumed: int = mini(needed, opening + stored)
	var closing: int = opening + stored - consumed
	return {"day": day, "opening": opening, "capacity": capacity, "by_source": normalized, "produced": produced, "stored": stored, "overflow": produced - stored, "needed": needed, "consumed": consumed, "shortage": needed - consumed, "closing": closing, "net": closing - opening}

# 数值模块：JSON数字必须为有限整数，避免小数或异常值进入账单。
static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high and float(value) == floor(float(value))

# 校验模块：旧档允许无历史账单，新账单的各项收支必须可以按同一规则重算。
static func valid(raw: Variant, settled_day: int, population: int) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if raw.size() != 12 or not raw.get("by_source") is Dictionary or raw["by_source"].size() != SOURCES.size():
		return false
	for id: String in SOURCES:
		if not _integer(raw["by_source"].get(id), 0, 1000000000):
			return false
	for key: String in ["day", "opening", "capacity", "produced", "stored", "overflow", "needed", "consumed", "shortage", "closing"]:
		if not _integer(raw.get(key), 0, 1000000000):
			return false
	if not _integer(raw.get("net"), -1000000000, 1000000000) or raw["day"] != settled_day or settled_day < 1 or raw["capacity"] < 300:
		return false
	var expected: Dictionary = calculate(int(raw["day"]), int(raw["opening"]), int(raw["capacity"]), raw["by_source"], population)
	for key: String in expected:
		if key != "by_source" and int(raw[key]) != int(expected[key]):
			return false
	return true
