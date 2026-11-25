## 文件用途：按家庭记录儿童成年日，日结检查迁入与出生，并验证人口快照。
extends RefCounted

# 平衡参数：以游戏日衡量成年和增长周期。
const START_POPULATION: int = 30
const START_CHILDREN: int = 6
const MAX_POPULATION: int = 2580
const MIGRATION_PERIOD: int = 3
const BIRTH_PERIOD: int = 6
const MIGRANT_ADULTS: int = 2
const MIGRANT_CHILDREN: int = 1
const MIGRANT_SIZE: int = MIGRANT_ADULTS + MIGRANT_CHILDREN
const CHILD_GROWTH_DAYS: int = 18
const MIGRANT_GROWTH_DAYS: int = 12
const FOOD_RESERVE_DAYS: int = 3
const MIN_SATISFACTION: int = 60


# 初始家庭：按原存档成人与被抚养人数建户，儿童的成年日按家庭错开。
static func initial(population: int, children: int, day: int) -> Array:
	var adults: int = population - children
	var count: int = maxi(ceili(adults / 2.0), ceili(children / 2.0))
	var households: Array = []
	for i: int in range(count):
		var child_dates: Array = []
		for j: int in range(i, children, count):
			child_dates.append(day + CHILD_GROWTH_DAYS - (j % 3))
		child_dates.sort()
		households.append({"adults": clampi(adults - i * 2, 0, 2), "children": child_dates})
	return households


# 增长门槛：按入住或出生后的居民口粮计算剩余三天储备。
static func growth_block(world: RefCounted, added: int) -> String:
	if world.housing_capacity() - world.population < added:
		return "空住房不足%d个" % added
	if world.satisfaction < MIN_SATISFACTION:
		return "满意度需达到%d" % MIN_SATISFACTION
	var required: int = FOOD_RESERVE_DAYS * ceili((world.population + added) * 0.5)
	if int(world.resources["food"]) < required:
		return "至少需%d粮食作为%d天口粮" % [required, FOOD_RESERVE_DAYS]
	return ""


# 日结人口：先完成成年，再办理迁入和出生，新居民从新的一日计入收支。
static func settle(world: RefCounted) -> void:
	var settled: int = world.last_settled_day
	var new_day: int = settled + 1
	var matured: int = 0
	for family: Dictionary in world.households:
		var children: Array = family["children"]
		while not children.is_empty() and int(children[0]) <= new_day:
			children.pop_front()
			family["adults"] += 1
			matured += 1
	world.dependents -= matured
	var joined: int = 0
	if settled % MIGRATION_PERIOD == 0 and growth_block(world, MIGRANT_SIZE).is_empty():
		world.households.append({"adults": MIGRANT_ADULTS, "children": [new_day + MIGRANT_GROWTH_DAYS]})
		world.population += MIGRANT_SIZE
		world.dependents += MIGRANT_CHILDREN
		joined = MIGRANT_SIZE
	var born: int = 0
	if settled % BIRTH_PERIOD == 0 and growth_block(world, 1).is_empty():
		# 从已有两名成年人的家庭中轮流分配出生机会，每户最多同时照看两名儿童。
		var size: int = world.households.size() - int(joined > 0)
		var start: int = int(settled / float(BIRTH_PERIOD) - 1.0) % maxi(1, size)
		for offset: int in range(size):
			var family: Dictionary = world.households[(start + offset) % size]
			if int(family["adults"]) >= 2 and family["children"].size() < 2:
				family["children"].append(new_day + CHILD_GROWTH_DAYS)
				world.population += 1
				world.dependents += 1
				born = 1
				break
	world.population_report = {"day": settled, "joined": joined, "born": born, "matured": matured}


# 成年预告：统计最早到期的儿童，供人口面板展示。
static func next_adulthood(households: Array) -> Dictionary:
	var next_day: int = 0
	var count: int = 0
	for family: Dictionary in households:
		for day: int in family["children"]:
			if next_day == 0 or day < next_day:
				next_day = day
				count = 1
			elif day == next_day:
				count += 1
	return {"day": next_day, "count": count}


# 数值验证：SQLite的JSON解析可能将整数读成浮点，有限整数仍可恢复。
static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high and value == floor(float(value))


# 快照恢复：家庭汇总必须等于当前人口，日结报告用于对账人口变化。
static func restore(world: RefCounted, families: Variant, report: Variant) -> bool:
	if not families is Array or families.is_empty() or families.size() > world.population or not report is Dictionary:
		return false
	var children: int = 0
	var adults: int = 0
	var normalized: Array = []
	var day: int = world.current_day()
	for source: Variant in families:
		if not source is Dictionary or source.size() != 2 or not _integer(source.get("adults"), 0, world.population) or not source.get("children") is Array or source["children"].size() > 2:
			return false
		var dates: Array = []
		for date: Variant in source["children"]:
			if not _integer(date, day + 1, day + CHILD_GROWTH_DAYS) or (not dates.is_empty() and int(date) < dates[-1]):
				return false
			dates.append(int(date))
		if source["adults"] == 0 and dates.is_empty():
			return false
		adults += int(source["adults"])
		children += dates.size()
		normalized.append({"adults": int(source["adults"]), "children": dates})
	if children != world.dependents or adults + children != world.population:
		return false
	if not report.is_empty():
		var settled: int = world.last_settled_day
		if report.size() != 4 or not _integer(report.get("day"), settled, settled) or settled < 1:
			return false
		if not _integer(report.get("joined"), 0, MIGRANT_SIZE) or int(report["joined"]) not in [0, MIGRANT_SIZE]:
			return false
		if not _integer(report.get("born"), 0, 1) or not _integer(report.get("matured"), 0, adults):
			return false
		if (report["joined"] > 0 and settled % MIGRATION_PERIOD != 0) or (report["born"] > 0 and settled % BIRTH_PERIOD != 0):
			return false
		if world.population - int(report["joined"]) - int(report["born"]) < START_POPULATION:
			return false
		world.population_report = {"day": settled, "joined": int(report["joined"]), "born": int(report["born"]), "matured": int(report["matured"])}
	world.households = normalized
	return true
