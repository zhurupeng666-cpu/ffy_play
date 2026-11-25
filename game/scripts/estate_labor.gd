## 文件用途：维护领主劳役的人数、独立分配与半单位口粮，不修改居民家庭。
extends RefCounted

# 平衡参数：每次购买一人，口粮以半单位累计。
const PRICE: int = 30
const MAX_WORKERS: int = 64


# 空闲核算：领主岗位与居民岗位分别从各自劳动力池扣减。
static func production_count(world: RefCounted) -> int:
	var result: int = 0
	for count: int in world.estate_posts.values():
		result += count
	return result


# 购买核算：检查国库和编额，失败时保持整个世界不变。
static func purchase_block(world: RefCounted) -> String:
	if world.estate_workers >= MAX_WORKERS:
		return "已达%d人上限" % MAX_WORKERS
	if int(world.resources["gold"]) < PRICE:
		return "需要%d金币" % PRICE
	return ""


# 购买操作：扣费后新成员先计入领主空闲人手。
static func purchase(world: RefCounted) -> bool:
	if not purchase_block(world).is_empty():
		return false
	world.resources["gold"] -= PRICE
	world.estate_workers += 1
	return true


# 口粮日结：每人半单位，满一单位才从整份库存扣除，零头跨日保存。
static func settle(world: RefCounted) -> void:
	if world.estate_workers == 0:
		return
	var halves: int = world.estate_workers + world.estate_food_remainder
	@warning_ignore("integer_division")
	var need: int = halves / 2
	var paid: int = mini(need, int(world.resources["food"]))
	world.resources["food"] -= paid
	world.estate_food_remainder = halves % 2
	world.estate_food_report = {"day": world.last_settled_day, "workers": world.estate_workers, "paid": paid, "shortage": need - paid}


# 存档数值：只接受具有明确上界的完整人数和资源量。
static func _valid(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high and floor(float(value)) == float(value)


# 存档恢复：核对已分配人数、有效生产建筑、口粮零头和最近一次日结。
static func restore(world: RefCounted, raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != 5 or not _valid(raw.get("workers"), 0, MAX_WORKERS) or not _valid(raw.get("builders"), 0, world.builders):
		return false
	if not _valid(raw.get("food_remainder"), 0, 1) or not raw.get("posts") is Dictionary or not raw.get("food_report") is Dictionary:
		return false
	var workers: int = int(raw["workers"])
	var builders: int = int(raw["builders"])
	var remainder: int = int(raw["food_remainder"])
	var posts: Dictionary = {}
	var assigned: int = builders
	for building: Dictionary in world.buildings:
		var id: String = building["id"]
		if not raw["posts"].has(id):
			continue
		if building["state"] != "ready" or not _valid(raw["posts"][id], 1, int(building["workers"])):
			return false
		posts[id] = int(raw["posts"][id])
		assigned += posts[id]
	if posts.size() != raw["posts"].size() or assigned > workers:
		return false
	var bill: Dictionary = raw["food_report"]
	if bill.is_empty():
		if remainder != 0:
			return false
	else:
		if bill.size() != 4 or world.last_settled_day < 1 or not _valid(bill.get("day"), world.last_settled_day, world.last_settled_day) or not _valid(bill.get("workers"), 1, workers):
			return false
		if not _valid(bill.get("paid"), 0, MAX_WORKERS) or not _valid(bill.get("shortage"), 0, MAX_WORKERS):
			return false
		var prior: int = (remainder - int(bill["workers"])) & 1
		if (int(bill["paid"]) + int(bill["shortage"])) * 2 + remainder != int(bill["workers"]) + prior:
			return false
		world.estate_food_report = {"day": world.last_settled_day, "workers": int(bill["workers"]), "paid": int(bill["paid"]), "shortage": int(bill["shortage"])}
	world.estate_workers = workers
	world.estate_builders = builders
	world.estate_posts = posts
	world.estate_food_remainder = remainder
	return true
