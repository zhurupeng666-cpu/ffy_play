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
		var size: Vector2i = Catalog.find(building["def_id"]).get("footprint")
		var anchor: Vector2i = Vector2i(int(building["cell"][0]), int(building["cell"][1]))
		if cell.x >= anchor.x and cell.y >= anchor.y and cell.x < anchor.x + size.x and cell.y < anchor.y + size.y:
			return str(building["id"])
	return ""

# 详情模块：输出展示文本与可用操作，操作仍需世界层再次校验。
static func describe(world: RefCounted, id: String) -> Dictionary:
	var building: Dictionary = find(world, id)
	if building.is_empty():
		return {"text": "点击地图建筑查看详情；右键取消选择", "increase": false, "decrease": false}
	var definition: Resource = Catalog.find(building["def_id"])
	var lines: PackedStringArray = ["%s Lv.%d · %s" % [definition.get("display_name"), building["level"], id.trim_prefix("building_")], "位置(%d,%d) · 占地%d×%d" % [building["cell"][0], building["cell"][1], definition.get("footprint").x, definition.get("footprint").y]]
	var slots: int = int(definition.get("worker_slots"))
	var ready: bool = building["state"] == "ready"
	if not ready:
		var queue: int = 0
		for record: Dictionary in world.buildings:
			if record["state"] == "constructing":
				queue += 1
			if record["id"] == id:
				break
		lines.append("施工%d%%（%d/%d）；队列第%d" % [floori(100.0 * building["work_done"] / building["work_required"]), building["work_done"], building["work_required"], queue])
		lines.append("施工队0人，已停工" if world.builders == 0 else "施工队%d人；%s" % [world.builders, "当前施工" if queue == 1 else "等待前序工地"])
		if world.paused:
			lines.append("世界已暂停，施工暂停")
		if slots > 0:
			lines.append("完工后开放%d个生产岗位" % slots)
	else:
		lines.append("已完工")
		if slots > 0:
			var material: String = str(definition.get("material_resource"))
			var unit: String = "粮食" if material.is_empty() else ("木材" if material == "wood" else "石材")
			var rate: int = int(definition.get("food_per_worker_day")) if material.is_empty() else int(definition.get("material_per_worker_day"))
			var credit: int = int(building["food_credit"] if material.is_empty() else building["material_credit"])
			lines.append("岗位%d/%d；全镇空闲%d人" % [building["workers"], slots, world.idle_workers()])
			lines.append("全天折算%d%s；待入库%.2f%s" % [int(building["workers"]) * rate, unit, credit / 120.0, unit])
			lines.append("无人工作，已停产" if building["workers"] == 0 else ("世界已暂停，生产暂停" if world.paused else "工作中，日结入库"))
		elif building["def_id"] == "b_house":
			lines.append("本住宅提供10住房容量；当前无生产岗位")
		elif int(definition.get("food_capacity")) > 0:
			lines.append("本粮仓提供%d储粮容量；无需生产工人" % definition.get("food_capacity"))
		else:
			lines.append("领主厅：提供初始住房与公共储粮；无生产岗位")
	return {"producer": slots > 0, "text": "\n".join(lines), "increase": ready and slots > int(building["workers"]) and world.idle_workers() > 0, "decrease": ready and slots > 0 and int(building["workers"]) > 0}
