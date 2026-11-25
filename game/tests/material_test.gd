## 文件用途：验证林矿建造限制、材料按时间生产、劳动力守恒、日结与存档迁移及真实界面。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Terrain = preload("res://scripts/town_terrain.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Ledger = preload("res://scripts/material_ledger.gd")
var failed: bool = false

# 启动模块：延迟到场景树可以接收真实管理界面时执行。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：规则失败时给出原因并通过退出码阻断构建。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 夹具模块：使用真实建造与时钟完成两座材料建筑，不分配生产工人。
func _prepare() -> RefCounted:
	var world: RefCounted = State.new()
	_check(Build.execute(world, "b_lumber", Vector2i(46, 46), "material-lumber")["ok"], "临林伐木场建造失败")
	_check(Build.execute(world, "b_quarry", Vector2i(101, 37), "material-quarry")["ok"], "临矿采石场建造失败")
	_check(not world.assign_producers("building_000002", 1), "工地可分配岗位")
	world.paused = false
	Clock.new(world).advance(240)
	_check(world.resources["wood"] == 95 and world.resources["stone"] == 80 and world.resources["gold"] == 315, "默认无人生产却增材料或建造费用错误")
	return world

# 地形与生产验收模块：对应资源点、正交相邻、空地占地与失败原子性一致。
func _run() -> void:
	var world: RefCounted = State.new()
	var before: Dictionary = world.snapshot()
	_check(Build.execute(world, "b_lumber", Vector2i(2, 4), "away")["code"] == "NEEDS_DEPOSIT" and world.snapshot() == before, "远离森林仍可建造")
	_check(Build.execute(world, "b_lumber", Vector2i(101, 37), "wrong-type")["code"] == "NEEDS_DEPOSIT" and world.snapshot() == before, "森林建筑接受石矿")
	_check(Build.execute(world, "b_quarry", Vector2i(46, 46), "wrong-type-2")["code"] == "NEEDS_DEPOSIT" and world.snapshot() == before, "采石场接受森林")
	_check(Build.execute(world, "b_lumber", Vector2i(50, 46), "on-deposit")["code"] == "DEPOSIT" and world.snapshot() == before, "直接压资源点未拒绝")
	_check(not Placement.check_building(Vector2i(46, 31), Catalog.LUMBER, {})["ok"], "仅斜角接触森林却允许建造")
	_check(Placement.check_building(Vector2i(46, 46), Catalog.LUMBER, {})["ok"], "合法伐木场预览拒绝")
	# 重启生产模块：基础伐木营地只收金币，木材耗尽时仍能恢复建设资源。
	world.resources["wood"] = 0
	_check(Build.execute(world, "b_lumber", Vector2i(46, 46), "bootstrap")["ok"], "木材耗尽时无法建立基础伐木场")
	world.paused = false
	Clock.new(world).advance(120)
	world.assign_producers("building_000002", 3)
	Clock.new(world).advance(120)
	_check(world.resources["wood"] == 24, "零木材开局没有恢复材料生产")
	world = _prepare()
	_check(world.assign_producers("building_000002", 3) and world.assign_producers("building_000003", 3) and world.idle_workers() == 16, "岗位未使用共享劳动力")
	before = world.snapshot()
	_check(not world.assign_producers("building_000002", 4) and not world.assign_producers("building_000003", -1) and world.snapshot() == before, "超额分配改变世界")
	world.paused = true
	var clock: RefCounted = Clock.new(world)
	clock.advance(120)
	_check(world.buildings[1]["material_credit"] == 0 and world.tick == 240, "暂停仍在生产")
	world.paused = false
	clock.advance(119)
	_check(world.resources["wood"] == 95 and world.buildings[1]["material_credit"] == 2856 and world.buildings[2]["material_credit"] == 1785, "提前入库或信用累计错误")
	# 持久化模块：日结前重开恢复人数与整数信用，结算只发生一次。
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/material_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "材料保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.buildings[1]["material_credit"] == 2856 and loaded.production_workers() == 6, "材料读档丢进度或岗位")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	loaded.paused = false
	clock = Clock.new(loaded)
	clock.advance(1)
	_check(loaded.resources["wood"] == 119 and loaded.resources["stone"] == 95 and loaded.resources["food"] == 135 and loaded.last_material_ledger["wood"]["produced"] == 24, "木石日结或粮食隔离错误")
	before = loaded.snapshot()
	loaded.settle_days()
	_check(loaded.snapshot() == before, "重复日结发放材料")
	loaded.speed = 4
	clock.advance(30)
	_check(loaded.resources["wood"] == 143 and loaded.resources["stone"] == 110, "倍速改变整日产量")
	_check(store.save_world(loaded), "材料账单保存失败")
	store.close_store()
	store.open_store(path)
	var reopened: RefCounted = store.load_world()
	_check(reopened != null and reopened.last_material_ledger == loaded.last_material_ledger, "材料账单重开改变数据类型或内容")
	# 防刷模块：最后一秒安排工人仅计一秒贡献，撤岗保留零头但不继续累计。
	world = _prepare()
	clock = Clock.new(world)
	clock.advance(119)
	world.assign_producers("building_000002", 3)
	clock.advance(1)
	_check(world.resources["wood"] == 95 and world.buildings[1]["material_credit"] == 24, "日结前调岗获得全天木材")
	world.assign_producers("building_000002", 0)
	clock.advance(120)
	_check(world.resources["wood"] == 95 and world.buildings[1]["material_credit"] == 24, "撤岗仍产材料或丢失零头")
	# 上限与坏档模块：安全边界溢出可追踪，非法进度与不守恒账单被拒绝。
	var bill: Dictionary = Ledger.calculate(1, {"wood": 999999998, "stone": 999999999}, {"wood": 24, "stone": 15})
	_check(bill["wood"]["stored"] == 2 and bill["stone"]["overflow"] == 14 and Ledger.valid(bill, 1), "材料安全边界算账错误")
	var bad: Dictionary = loaded.snapshot()
	bad["buildings"][1]["material_credit"] = -1
	_check(State.from_snapshot(bad) == null, "接受负材料进度")
	bad = loaded.snapshot()
	bad["buildings"][1]["food_credit"] = 1
	_check(State.from_snapshot(bad) == null, "伐木场持有粮食进度")
	bad = loaded.snapshot()
	bad["last_material_ledger"]["wood"]["stored"] = 999
	_check(State.from_snapshot(bad) == null, "接受不守恒材料账单")
	bad = loaded.snapshot()
	bad["buildings"][2]["cell"] = [10, 2]
	bad["applied_commands"]["material-quarry"]["cell"] = [10, 2]
	_check(State.from_snapshot(bad) == null, "接受离矿采石场存档")
	bad = loaded.snapshot()
	bad.erase("last_material_ledger")
	_check(State.from_snapshot(bad) == null, "接受缺字段v7")
	# 迁移模块：v6建筑和粮食岗位保持不变，新增材料信用为零，不补发历史收益。
	world = State.new()
	Build.execute(world, "b_farm", Vector2i(2, 4), "legacy-farm")
	world.paused = false
	clock = Clock.new(world)
	clock.advance(120)
	world.assign_producers("building_000002", 2)
	clock.advance(1)
	var legacy: Dictionary = world.snapshot()
	legacy["version"] = 6
	legacy.erase("last_material_ledger")
	for record: Dictionary in legacy["buildings"]:
		record.erase("material_credit")
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.resources == world.resources and migrated.buildings[1]["food_credit"] == 12 and migrated.buildings[1]["material_credit"] == 0 and migrated.last_material_ledger.is_empty(), "旧档迁移改变粮食生产或补发材料")
	# 旧地图保护模块：旧建筑即使位于新增资源点上也不被强制移动或拆除。
	world = State.new()
	Build.execute(world, "b_house", Vector2i(2, 2), "legacy-house")
	legacy = world.snapshot()
	legacy["version"] = 6
	legacy["buildings"][1]["cell"] = [0, 11]
	legacy["applied_commands"]["legacy-house"]["cell"] = [0, 11]
	migrated = State.from_snapshot(legacy)
	_check(migrated != null and migrated.buildings[1]["cell"] == [0, 11], "新增资源点导致旧建筑丢失")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 界面模块：生产下拉框支持采石场，单位与日结材料摘要随保存读取恢复。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main.world = _prepare()
	main.world.paused = true
	main.clock = Clock.new(main.world)
	main._sync_building_view()
	main._refresh()
	main.producer_picker.select(1)
	main._change_producers(1)
	_check(main.numbers["b_quarry_jobs"].text == "1 / 3" and main.numbers["producer_credit"].text.ends_with("石材"), "界面材料岗位或单位错误")
	_check(main.town_map.staff_by_site.get("building_000003") == 1, "采石场分配后地图工人数错误")
	for id: String in ["building_000002", "building_000003"]:
		var area: Dictionary = main.town_map.work_areas.get(id, {})
		_check(area.get("sites", []).size() == 3, "采集场未分配完整工位")
		for cell: Vector2i in area.get("sites", []):
			_check(Terrain.deposit_at(cell) == area["kind"], "设备或工人站位不在对应资源格内")
	main._save()
	main._change_producers(1)
	main._load()
	_check(main.world.buildings[2]["workers"] == 1, "界面读档未恢复材料岗位")
	main._start_preview(Catalog.LUMBER)
	main.town_map.hovered = Vector2i(2, 4)
	main.town_map._update_preview()
	_check(main.town_map.preview_result["code"] == "NEEDS_DEPOSIT", "界面遗漏森林建造限制")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("MATERIAL_PASS: deposits, atomic placement, workers, accrual, daily, bounds, migration, snapshot, UI")
	quit(1 if failed else 0)

