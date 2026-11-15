## 文件用途：验证农牧渔建造、临水规则、真实工作产粮、岗位守恒及生产存档与界面。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Placement = preload("res://scripts/placement_validator.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
var failed: bool = false

# 启动模块：在场景树就绪后测试真实界面。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：失败时记录原因并返回非零退出码。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 建筑夹具模块：真实扣费建造三类建筑，推进施工后对齐日界，保持默认无人生产。
func _prepare() -> RefCounted:
	var world: RefCounted = State.new()
	_check(Build.execute(world, "b_farm", Vector2i(2, 4), "food-farm")["ok"], "农场开工失败")
	_check(Build.execute(world, "b_ranch", Vector2i(10, 10), "food-ranch")["ok"], "牧场开工失败")
	_check(Build.execute(world, "b_fishery", Vector2i(2, 1), "food-fish")["ok"], "临水渔场开工失败")
	_check(not world.assign_producers("building_000002", 1), "允许工地安排生产")
	world.paused = false
	Clock.new(world).advance(240)
	_check(world.resources["food"] == 150 and world.resources["wood"] == 45 and world.resources["gold"] == 300, "未分配岗位却产粮或建造费用错误")
	return world

# 规则验收模块：预览和实际放置共用临水校验，失败不会扣费或产生回执。
func _run() -> void:
	var world: RefCounted = State.new()
	var before: Dictionary = world.snapshot()
	_check(Build.execute(world, "b_fishery", Vector2i(2, 4), "inland")["code"] == "NEEDS_WATER" and world.snapshot() == before, "内陆渔场未原子拒绝")
	_check(Build.execute(world, "b_farm", Vector2i(2, 0), "water")["code"] == "WATER" and world.snapshot() == before, "农场可建在水上")
	_check(Placement.check_building(Vector2i(2, 1), Catalog.FISHERY, {}).get("ok", false), "岸上渔场预览失败")
	_check(Placement.check_building(Vector2i(2, 0), Catalog.FISHERY, {}).get("code") == "WATER", "渔场可建在河里")
	world = _prepare()
	_check(world.assign_producers("building_000002", 3) and world.assign_producers("building_000003", 3) and world.assign_producers("building_000004", 2), "生产分配失败")
	_check(world.production_workers() == 8 and world.idle_workers() == 14, "岗位未扣减同一劳动力池")
	before = world.snapshot()
	_check(not world.assign_producers("building_000004", 3) and not world.assign_producers("building_000002", -1) and not world.assign_producers("missing", 1) and world.snapshot() == before, "非法岗位改变状态")
	var clock: RefCounted = Clock.new(world)
	world.paused = true
	clock.advance(120)
	_check(world.snapshot() == before.merged({"paused": true}, true), "暂停时仍累计生产")
	world.paused = false
	clock.advance(119)
	_check(world.resources["food"] == 150 and world.buildings[1]["food_credit"] == 2142, "提前入库或累计工作错误")
	# 存档模块：午夜前保存并跨连接读取，保留所有岗位与整数余数。
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/food_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "生产存档失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.production_workers() == 8 and loaded.buildings[1]["food_credit"] == 2142, "生产读档丢失岗位或累计")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	clock = Clock.new(loaded)
	clock.advance(1)
	_check(loaded.resources["food"] == 176 and loaded.last_bill.contains("产粮 +41"), "三类全天产粮或消耗结算错误")
	before = loaded.snapshot()
	loaded.settle_days()
	_check(loaded.snapshot() == before, "同日重复产粮")
	loaded.speed = 4
	clock.advance(30)
	_check(loaded.resources["food"] == 202, "倍速改变每日产量")
	# 防刷模块：最后一秒分配不获得全天粮食，撤岗仍保留此前实际工作。
	world = _prepare()
	clock = Clock.new(world)
	clock.advance(119)
	world.assign_producers("building_000002", 3)
	clock.advance(1)
	_check(world.resources["food"] == 135 and world.buildings[1]["food_credit"] == 18, "日结前调岗刷出全天粮食")
	world.assign_producers("building_000002", 0)
	clock.advance(120)
	_check(world.resources["food"] == 120 and world.buildings[1]["food_credit"] == 18, "停工产粮或丢失零头")
	# 坏档与迁移模块：共享人口不可超配，旧档建筑默认零生产且保留已有施工岗位。
	var bad: Dictionary = loaded.snapshot()
	bad["buildings"][1]["workers"] = 4
	_check(State.from_snapshot(bad) == null, "接受超岗位坏档")
	bad = loaded.snapshot()
	bad["dependents"] = 23
	_check(State.from_snapshot(bad) == null, "接受超人口岗位")
	bad = loaded.snapshot()
	bad["buildings"][1]["food_credit"] = -1
	_check(State.from_snapshot(bad) == null, "接受负生产进度")
	# 地形坏档模块：即使回执与坐标一起篡改，内陆渔场也不能载入。
	bad = loaded.snapshot()
	bad["buildings"][3]["cell"] = [10, 4]
	bad["applied_commands"]["food-fish"]["cell"] = [10, 4]
	_check(State.from_snapshot(bad) == null, "接受内陆渔场坏档")
	var legacy: Dictionary = loaded.snapshot()
	legacy["version"] = 4
	for record: Dictionary in legacy["buildings"]:
		record.erase("workers")
		record.erase("food_credit")
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.production_workers() == 0 and migrated.builders == loaded.builders and migrated.resources == loaded.resources, "旧档迁移补发生产或丢资源")
	# 共享岗位模块：没有空闲人口时，施工和生产都不得继续抢占人口。
	world = _prepare()
	world.dependents = 28
	_check(not world.assign_producers("building_000002", 1), "生产超额占用人口")
	world.assign_builders(0)
	world.assign_producers("building_000002", 2)
	_check(not world.assign_builders(1), "施工未考虑生产占用人口")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 界面模块：列表选中渔场并加人，日结账单、保存和读取保持一致。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main.world = _prepare()
	main.world.paused = true
	main.clock = Clock.new(main.world)
	main._sync_building_view()
	main._refresh()
	main.producer_picker.select(2)
	main._change_producers(1)
	_check(main.world.buildings[3]["workers"] == 1 and main.production_label.text.contains("渔场：1/2人"), "界面未分配渔场岗位")
	main._save()
	main._change_producers(1)
	main._load()
	_check(main.world.buildings[3]["workers"] == 1 and main.production_label.text.contains("渔场：1/2人"), "界面读取未恢复生产")
	main._start_preview(Catalog.FISHERY)
	main.town_map.hovered = Vector2i(10, 4)
	main.town_map._update_preview()
	_check(main.town_map.preview_result["code"] == "NEEDS_WATER", "界面渔场未检查临水")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("FOOD_PASS: farm, ranch, fishery, shoreline, staffing, accrual, daily, snapshot, migration, UI")
	quit(1 if failed else 0)

