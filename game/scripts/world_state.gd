## 文件用途：保存原型世界的日期、人口和资源，并提供可校验的存档快照。
extends RefCounted

# 状态模块：数值均为待平衡参数，资源以完整单位保存。
const DAY_TICKS: int = 120
var tick: int = 0
var subsecond: float = 0.0
var last_settled_day: int = 0
var population: int = 30
var resources: Dictionary = {"food": 180, "gold": 300, "wood": 120, "stone": 80}
var speed: int = 1
var paused: bool = true
var last_bill: String = "尚未日结；当前仅有居民消耗和基础税收"


# 日期模块：第0至119秒属于第1日，完成120秒才进入第2日。
func current_day() -> int:
	return int(tick / float(DAY_TICKS)) + 1


# 日结模块：每个完成的日期仅结算一次，粮食不足时不出现负库存。
func settle_days() -> void:
	while last_settled_day < current_day() - 1:
		var needed: int = ceili(population * 0.5)
		var consumed: int = mini(needed, int(resources["food"]))
		var tax: int = roundi(population * 0.8 * (50.0 / 60.0))
		resources["food"] -= consumed
		resources["gold"] += tax
		last_settled_day += 1
		last_bill = "第%d日日结：粮食 -%d，税收 +%d" % [last_settled_day, consumed, tax]
		if consumed < needed:
			last_bill += "；缺粮 %d（本阶段仅提示）" % (needed - consumed)


# 快照模块：只导出基础数据，不保存节点、数据库连接或脚本引用。
func snapshot() -> Dictionary:
	return {"version": 1, "tick": tick, "subsecond": subsecond, "last_settled_day": last_settled_day, "population": population, "resources": resources.duplicate(), "speed": speed, "paused": paused, "last_bill": last_bill}


# 载入模块：在临时对象中完整校验，失败返回空值，不改变当前世界。
static func from_snapshot(data: Variant) -> RefCounted:
	if not data is Dictionary:
		return null
	for key: String in ["version", "tick", "last_settled_day", "population", "speed"]:
		if not _valid_integer(data.get(key), 0, 120000000):
			return null
	if data["version"] != 1 or int(data["speed"]) not in [1, 2, 4] or data["population"] != 30:
		return null
	if data["last_settled_day"] != int(float(data["tick"]) / DAY_TICKS):
		return null
	var fraction: Variant = data.get("subsecond")
	if typeof(fraction) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(fraction)) or fraction < 0 or fraction >= 1:
		return null
	if not data.get("paused") is bool or not data.get("last_bill") is String or data["last_bill"].length() > 200:
		return null
	if not data.get("resources") is Dictionary:
		return null
	for key: String in ["food", "gold", "wood", "stone"]:
		if not _valid_integer(data["resources"].get(key), 0, 1000000000):
			return null
	var state: RefCounted = load("res://scripts/world_state.gd").new()
	state.tick = int(data["tick"])
	state.subsecond = float(fraction)
	state.last_settled_day = int(data["last_settled_day"])
	state.population = int(data["population"])
	for key: String in ["food", "gold", "wood", "stone"]:
		state.resources[key] = int(data["resources"][key])
	state.speed = int(data["speed"])
	state.paused = data["paused"]
	state.last_bill = data["last_bill"]
	return state


# 数值模块：拒绝空值、小数、负数、无穷值和超出边界的数据。
static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floor(float(value))
