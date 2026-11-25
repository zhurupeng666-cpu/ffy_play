## 文件用途：只读查询建筑占地和详情，统一施工队列、生产岗位与容量信息，不修改世界。
extends RefCounted
const Catalog = preload("res://scripts/building_catalog.gd")

# 身份查询模块：每次从当前权威世界按稳定ID获取建筑，避免持有读档前的旧字典。
static func find(world: RefCounted, id: String) -> Dictionary:
	for building: Dictionary in world.buildings:
		if building["id"] == id:
			return building
	return {}

# 占地查询模块：建筑范围内任一逻辑格均命中同一实例，不只支持锚点。
static func at_cell(world: RefCounted, cell: Vector2i) -> String:
	for building: Dictionary in world.buildings:
		var size: Vector2i = Catalog.footprint(building)
		var anchor: Vector2i = Vector2i(int(building["cell"][0]), int(building["cell"][1]))
		if cell.x >= anchor.x and cell.y >= anchor.y and cell.x < anchor.x + size.x and cell.y < anchor.y + size.y:
			return str(building["id"])
	return ""

# 详情模块：返回建筑状态和独立指标，操作仍需世界层再次校验。
static func describe(world: RefCounted, id: String) -> Dictionary:
	var building: Dictionary = find(world, id)
	if building.is_empty():
		return {"text": "选择地图上的建筑", "numbers": {}, "increase": false, "decrease": false}
	var definition: Resource = Catalog.find(building["def_id"])
	var size: Vector2i = Catalog.footprint(building)
	var metrics: Dictionary = {"level": building["level"], "size": "%d × %d" % [size.x, size.y]}
	var slots: int = int(definition.get("worker_slots"))
	var ready: bool = building["state"] == "ready"
	var state_text: String = "已完工"
	if not ready:
		var queue: int = 0
		for record: Dictionary in world.buildings:
			if record["state"] == "constructing":
				queue += 1
			if record["id"] == id:
				break
		metrics["progress"] = "%d%%" % floori(100.0 * building["work_done"] / building["work_required"])
		metrics["queue"] = queue
		metrics["builders"] = world.builders
		if slots > 0:
			metrics["jobs"] = "0 / %d" % slots
		if world.builders == 0:
			state_text = "缺施工工人，已停工"
		elif queue > 1:
			state_text = "等待前序工地"
		else:
			state_text = "施工暂停" if world.paused else "施工中"
	elif slots > 0:
		var material: String = str(definition.get("material_resource"))
		var unit: String = "粮食" if material.is_empty() else ("木材" if material == "wood" else "石材")
		var rate: int = int(definition.get("food_per_worker_day")) if material.is_empty() else int(definition.get("material_per_worker_day"))
		var credit: int = int(building["food_credit"] if material.is_empty() else building["material_credit"])
		metrics["jobs"] = "%d / %d" % [building["workers"], slots]
		metrics["rate"] = "%d %s" % [int(building["workers"]) * rate, unit]
		metrics["credit"] = "%.2f %s" % [credit / 120.0, unit]
		state_text += " · " + ("无人工作" if building["workers"] == 0 else ("生产暂停" if world.paused else "工作中"))
	elif building["def_id"] == "b_house":
		metrics["housing"] = 10
	elif int(definition.get("food_capacity")) > 0:
		metrics["capacity"] = definition.get("food_capacity")
	return {
		"producer": slots > 0, "text": "%s · %s" % [definition.get("display_name"), state_text], "numbers": metrics,
		"increase": ready and slots > int(building["workers"]) and world.idle_workers() > 0,
		"decrease": ready and slots > 0 and int(building["workers"]) > 0,
	}
