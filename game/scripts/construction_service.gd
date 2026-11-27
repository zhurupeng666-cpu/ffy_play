## 文件用途：原子执行建筑落地命令，统一检查位置、费用和命令幂等，不直接操作界面。
extends RefCounted

const Costs = preload("res://scripts/building_costs.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Streets = preload("res://scripts/street_frontage.gd")


# 费用校验模块：完整检查所有成本后才允许扣费，拒绝配置中的非法资源和负数。
static func check_cost(cost: Dictionary, available: Dictionary) -> Dictionary:
	for key: Variant in cost:
		if not key is String or not available.has(key) or typeof(cost[key]) != TYPE_INT or cost[key] < 0:
			return {"ok": false, "code": "INVALID_COST", "reason": "建筑费用配置无效"}
	for key: String in cost:
		if available[key] < cost[key]:
			var names: Dictionary = {"wood": "木材", "gold": "金币", "stone": "石材", "food": "粮食"}
			return {"ok": false, "code": "INSUFFICIENT", "reason": "%s不足：需要%d，当前%d" % [names.get(key, key), cost[key], available[key]]}
	return {"ok": true, "code": "OK", "reason": "可以建造"}


# 建造模块：先完成全部校验，再一次替换库存、实例和回执，失败没有副作用。
static func execute(world: RefCounted, definition_id: String, anchor: Vector2i, command_id: String, large: bool = false) -> Dictionary:
	if command_id.is_empty() or command_id.length() > 64:
		return {"ok": false, "code": "INVALID_COMMAND", "reason": "建造命令ID无效"}
	large = large or definition_id == "b_fishery" or (world.capital_layout and definition_id == "b_road")
	var cell: Array = [anchor.x, anchor.y]
	if world.applied_commands.has(command_id):
		var receipt: Dictionary = world.applied_commands[command_id]
		if receipt["def_id"] != definition_id or receipt["cell"] != cell or receipt.get("large", false) != large:
			return {"ok": false, "code": "COMMAND_CONFLICT", "reason": "同一命令ID不能用于不同建筑或位置"}
		return {"ok": true, "code": "REPLAYED", "building_id": receipt["building_id"], "replayed": true, "cost": {}}
	if not world.household_economy.is_empty() and definition_id in ["b_farm", "b_fishery"]:
		return {"ok": false, "code": "RESIDENT_PROPERTY", "reason": "耕作和捕鱼由居民自主经营"}
	var definition: Resource = Catalog.for_construction(definition_id, large)
	if definition == null or not definition.get("buildable"):
		return {"ok": false, "code": "UNKNOWN_BUILDING", "reason": "此建筑不能建造"}
	var geometry: Dictionary = Placement.check_building(anchor, definition, world.occupied_cells(), world.capital_layout)
	if not geometry["ok"]:
		return geometry
	var front: int = Streets.NO_FRONT
	if world.capital_layout and definition_id == "b_house":
		front = Streets.direction(anchor, definition.get("footprint"), Streets.network(world.buildings, true))
		if front == Streets.NO_FRONT:
			return {"ok": false, "code": "NEEDS_STREET", "reason": "住宅大门必须接到已铺好的道路"}
	var affordability: Dictionary = check_cost(definition.get("cost"), world.resources)
	if not affordability["ok"]:
		return affordability
	if world.buildings.size() + world.Works.pending_slots(world) >= 256 or world.next_building_id >= 1000000:
		return {"ok": false, "code": "LIMIT", "reason": "达到当前原型建筑数量上限"}
	if int(definition.get("build_work")) <= 0 or int(definition.get("build_work")) > 100000:
		return {"ok": false, "code": "INVALID_WORK", "reason": "施工工作量配置无效"}
	var resources: Dictionary = world.resources.duplicate()
	for key: String in definition.get("cost"):
		resources[key] -= definition.get("cost")[key]
	var id: String = "building_%06d" % world.next_building_id
	var buildings: Array = world.buildings.duplicate(true)
	buildings.append({"id": id, "def_id": definition_id, "large": large, "cell": cell, "level": 1, "state": "constructing", "work_done": 0, "work_required": int(definition.get("build_work")), "workers": 0, "food_credit": 0, "material_credit": 0, "paid_cost": Costs.normalize(definition.get("cost"))})
	if front != Streets.NO_FRONT:
		buildings.back()["front"] = front
	var receipts: Dictionary = world.applied_commands.duplicate(true)
	receipts[command_id] = {"def_id": definition_id, "large": large, "cell": cell, "building_id": id}
	world.resources = resources
	world.buildings = buildings
	world.applied_commands = receipts
	world.next_building_id += 1
	return {"ok": true, "code": "BUILT", "building_id": id, "replayed": false, "cost": definition.get("cost").duplicate()}
