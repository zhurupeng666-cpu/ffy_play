## 文件用途：规范化建筑实付费用，并为旧存档提供冻结的历史费用，避免调价后退款异常。
extends RefCounted
const KEYS: Array[String] = ["wood", "stone", "gold"]
const LEGACY: Dictionary = {"b_hall": {}, "b_house": {"wood": 20, "gold": 10}, "b_farm": {"wood": 25, "gold": 10}, "b_ranch": {"wood": 30, "gold": 15}, "b_fishery": {"wood": 20, "gold": 15}, "b_granary": {"wood": 25, "stone": 10, "gold": 15}, "b_lumber": {"gold": 10}, "b_quarry": {"wood": 25, "gold": 15}}

# 规范模块：实付费用固定三个字段，以整数保留玩家当时付出的成本。
static func normalize(cost: Dictionary) -> Dictionary:
	return {"wood": int(cost.get("wood", 0)), "stone": int(cost.get("stone", 0)), "gold": int(cost.get("gold", 0))}

# 费用校验模块：拒绝额外字段、缺字段、小数及超出原型费用范围的数据。
static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != KEYS.size():
		return false
	for key: String in KEYS:
		var value: Variant = raw.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value > 1000000 or float(value) != floor(float(value)):
			return false
	return true
