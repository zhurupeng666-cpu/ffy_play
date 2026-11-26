## 文件用途：计算和校验税收、领地金币及满意度日结，记录入库和溢出。
extends RefCounted
const SETTINGS = preload("res://data/economy/civic_settings.tres")
const POLICIES: Array[String] = ["low", "standard", "high"]
const GOLD_LIMIT: int = 1000000000

# 名称模块：稳定政策ID与中文名称分离，未知政策不在玩家入口出现。
static func policy_name(policy: String) -> String:
	return {"low": "低税", "standard": "标准", "high": "高税"}.get(policy, "未知")

# 预估模块：用日结前满意度计算当日税收，不在切换政策时发金币。
static func estimate(population: int, satisfaction: int, policy: String) -> int:
	return roundi(population * float(SETTINGS.tax_rates[policy]) * satisfaction / float(SETTINGS.tax_divisor))

# 日结模块：先收税再改变满意度，粮食不足按实际缺口扣分，收入上限明确记录。
static func calculate(day: int, policy: String, before: int, population: int, shortage: int, gold: int, fort_income: int = 0, shop_income: int = 0) -> Dictionary:
	var needed: int = ceili(population * 0.5)
	var penalty: int = ceili(float(SETTINGS.full_shortage_penalty) * shortage / maxi(needed, 1))
	var recovery: int = int(SETTINGS.recovery_per_day) if shortage == 0 and before < int(SETTINGS.recovery_target) else 0
	var policy_delta: int = int(SETTINGS.policy_deltas[policy])
	var after: int = clampi(before + policy_delta + recovery - penalty, 0, int(SETTINGS.satisfaction_limit))
	var tax: int = estimate(population, before, policy)
	var stored: int = mini(tax, GOLD_LIMIT - gold)
	var result: Dictionary = {"day": day, "policy": policy, "before": before, "after": after, "tax": tax, "policy_delta": policy_delta, "recovery": recovery, "shortage": shortage, "food_penalty": penalty, "delta": after - before, "gold_before": gold, "tax_stored": stored, "tax_overflow": tax - stored, "gold_after": gold + stored}
	if fort_income > 0:
		var fort_stored: int = mini(fort_income, GOLD_LIMIT - int(result["gold_after"]))
		result["fort_gold"] = {"income": fort_income, "stored": fort_stored, "overflow": fort_income - fort_stored}
		result["gold_after"] += fort_stored
	if shop_income > 0:
		var shop_stored: int = mini(shop_income, GOLD_LIMIT - int(result["gold_after"]))
		result["shop_gold"] = {"income": shop_income, "stored": shop_stored, "overflow": shop_income - shop_stored}
		result["gold_after"] += shop_stored
	return result

# 数值模块：只接受有限整数，JSON浮点表示的整数会在恢复时统一类型。
static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high and float(value) == floor(float(value))

# 账单校验模块：日期、供粮和满意度结果必须与同日世界状态一致，历史金币可与当前余额不同。
static func valid(raw: Variant, day: int, population: int, satisfaction: int, food_bill: Dictionary) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	var field_count: int = 14 + int(raw.has("fort_gold")) + int(raw.has("shop_gold"))
	if raw.size() != field_count or not raw.get("policy") is String or raw["policy"] not in POLICIES or food_bill.is_empty():
		return false
	for key: String in ["day", "before", "after", "tax", "recovery", "shortage", "food_penalty", "gold_before", "tax_stored", "tax_overflow", "gold_after"]:
		if not _integer(raw.get(key), 0, GOLD_LIMIT):
			return false
	for key: String in ["policy_delta", "delta"]:
		if not _integer(raw.get(key), -100, 100):
			return false
	if raw["day"] != day or day < 1 or raw["before"] > SETTINGS.satisfaction_limit or raw["after"] != satisfaction or raw["shortage"] != food_bill["shortage"]:
		return false
	var fort_income: int = 0
	if raw.has("fort_gold"):
		var fort: Variant = raw["fort_gold"]
		if not fort is Dictionary or fort.size() != 3 or not _integer(fort.get("income"), 1, GOLD_LIMIT):
			return false
		fort_income = int(fort["income"])
	var shop_income: int = 0
	if raw.has("shop_gold"):
		var shop: Variant = raw["shop_gold"]
		if not shop is Dictionary or shop.size() != 3 or not _integer(shop.get("income"), 1, GOLD_LIMIT):
			return false
		shop_income = int(shop["income"])
	var expected: Dictionary = calculate(day, raw["policy"], int(raw["before"]), population, int(raw["shortage"]), int(raw["gold_before"]), fort_income, shop_income)
	for account: String in ["fort_gold", "shop_gold"]:
		if raw.has(account):
			for key: String in ["stored", "overflow"]:
				if not _integer(raw[account].get(key), 0, GOLD_LIMIT) or int(raw[account][key]) != int(expected[account][key]):
					return false
	for key: String in expected:
		if key not in ["policy", "fort_gold", "shop_gold"] and int(raw[key]) != int(expected[key]):
			return false
	return true

# 恢复模块：已验证账单按同一公式重建，避免读取后的数字类型不一致。
static func restore(raw: Dictionary, population: int) -> Dictionary:
	if raw.is_empty():
		return {}
	var fort_income: int = int(raw.get("fort_gold", {}).get("income", 0))
	return calculate(int(raw["day"]), raw["policy"], int(raw["before"]), population, int(raw["shortage"]), int(raw["gold_before"]), fort_income, int(raw.get("shop_gold", {}).get("income", 0)))
