## 文件用途：把城镇军需短缺换算为全军士气变化，并提供存档复算依据。
extends RefCounted

# 平衡参数：士气与居民满意度独立，当前数值供原型测试。
const INITIAL: int = 60
const MAXIMUM: int = 100
const RECOVERY: int = 2
const FOOD_PENALTY: int = 12
const WAGE_PENALTY: int = 8

# 比例扣分模块：将单项缺额占应付的比例换算为整数扣分。
static func _penalty(missing: int, due: int, maximum: int) -> int:
	if due == 0:
		return 0
	return ceili(float(missing * maximum) / due)

# 日结换算模块：两项足额恢复，否则分别计算并叠加扣分。
static func after(before: int, bill: Dictionary) -> int:
	var food_loss: int = _penalty(bill["food_shortage"], bill["food_needed"], FOOD_PENALTY)
	var wage_loss: int = _penalty(bill["wage_shortage"], bill["wage_needed"], WAGE_PENALTY)
	if food_loss + wage_loss == 0:
		return mini(MAXIMUM, before + RECOVERY)
	return maxi(0, before - food_loss - wage_loss)

# 写入模块：只有活动部队当日产生整份军需才记一条士气日结。
static func settle(world: RefCounted, active_due: bool) -> void:
	world.last_morale_before = null
	if active_due:
		world.last_morale_before = world.army_morale
		world.army_morale = after(world.army_morale, world.last_army_ledger)
