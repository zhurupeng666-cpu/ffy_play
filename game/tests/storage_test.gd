## 文件用途：验证粮仓完工容量、溢出算账、旧档超额粮保护及界面和数据库持久化。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Ledger = preload("res://scripts/food_ledger.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
var failed: bool = false

# 启动模块：场景树初始化后开始独立验收。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：收集失败原因，通过退出码阻止失败构建发布。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 边界验收模块：证明产出、入库、溢出与消耗的账目守恒。
func _run() -> void:
	var sources: Dictionary = {"b_farm": 18, "b_ranch": 15, "b_fishery": 8}
	var bill: Dictionary = Ledger.calculate(1, 295, 300, sources, 30)
	_check(bill["produced"] == 41 and bill["stored"] == 5 and bill["overflow"] == 36 and bill["consumed"] == 15 and bill["closing"] == 285 and bill["net"] == -10 and Ledger.valid(bill, 1, 30), "满仓算账错误")
	bill = Ledger.calculate(1, 295, 600, sources, 30)
	_check(bill["stored"] == 41 and bill["overflow"] == 0 and bill["closing"] == 321 and bill["net"] == 26, "扩容后产粮算账错误")
	bill = Ledger.calculate(1, 450, 300, sources, 30)
	_check(bill["stored"] == 0 and bill["overflow"] == 41 and bill["closing"] == 435, "旧有超额存粮被删除")
	bill = Ledger.calculate(1, 0, 300, {"b_farm": 0, "b_ranch": 0, "b_fishery": 8}, 30)
	_check(bill["consumed"] == 8 and bill["shortage"] == 7 and bill["closing"] == 0, "缺粮出现负库存或没有先吃新粮")
	# 真实时钟模块：午夜前保存后只收获一次，建造未完成不增加容量。
	var world: RefCounted = State.new()
	_check(Build.execute(world, "b_farm", Vector2i(2, 4), "storage-farm")["ok"], "农场建造失败")
	world.paused = false
	var clock: RefCounted = Clock.new(world)
	clock.advance(120)
	world.assign_producers("building_000002", 3)
	world.resources["food"] = 295
	clock.advance(119)
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/storage_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "午夜前保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null, "午夜前读档失败")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	loaded.paused = false
	clock = Clock.new(loaded)
	clock.advance(1)
	_check(loaded.resources["food"] == 285 and loaded.last_food_ledger["overflow"] == 13 and loaded.last_food_ledger["by_source"]["b_farm"] == 18, "真实满仓日结错误")
	var before: Dictionary = loaded.snapshot()
	loaded.settle_days()
	_check(loaded.snapshot() == before, "满仓后重复日结")
	_check(Build.execute(loaded, "b_granary", Vector2i(10, 10), "granary")["ok"] and loaded.food_capacity() == 300 and loaded.resources["stone"] == 70, "粮仓费用或工地容量错误")
	_check(not loaded.assign_producers("building_000003", 1), "粮仓错误提供生产岗位")
	loaded.paused = true
	clock.advance(100)
	_check(loaded.food_capacity() == 300, "暂停时完成粮仓")
	loaded.paused = false
	clock.advance(59)
	_check(loaded.food_capacity() == 300, "粮仓提前增加容量")
	clock.advance(1)
	_check(loaded.food_capacity() == 600, "粮仓完工未加容量")
	clock.advance(60)
	_check(loaded.resources["food"] == 288 and loaded.last_food_ledger["overflow"] == 0 and loaded.last_food_ledger["capacity"] == 600, "扩容后仍损失粮食")
	_check(Build.execute(loaded, "b_granary", Vector2i(10, 5), "granary-2")["ok"], "第二粮仓开工失败")
	clock.advance(60)
	_check(loaded.food_capacity() == 900, "多座粮仓未叠加")
	loaded.paused = true
	_check(store.save_world(loaded), "账单保存失败")
	store.close_store()
	store.open_store(path)
	var reopened: RefCounted = store.load_world()
	_check(reopened != null and reopened.food_capacity() == 900 and reopened.last_food_ledger == loaded.last_food_ledger, "粮仓或历史账单未恢复")
	# 坏档模块：账单内部关系错误、日期错误或缺字段均拒绝。
	var bad: Dictionary = loaded.snapshot()
	bad["last_food_ledger"]["overflow"] = 1
	_check(State.from_snapshot(bad) == null, "接受不守恒账单")
	bad = loaded.snapshot()
	bad["last_food_ledger"]["day"] = 1
	_check(State.from_snapshot(bad) == null, "接受旧日期账单")
	bad = loaded.snapshot()
	bad.erase("last_food_ledger")
	_check(State.from_snapshot(bad) == null, "接受缺字段v6")
	bad = loaded.snapshot()
	bad["last_food_ledger"]["by_source"]["b_farm"] = 1.5
	_check(State.from_snapshot(bad) == null, "接受小数来源产量")
	# 迁移模块：超容量旧粮食原样恢复，下一日只发生正常消费。
	var legacy: Dictionary = State.new().snapshot()
	legacy["version"] = 5
	legacy.erase("last_food_ledger")
	legacy["resources"]["food"] = 450
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.resources["food"] == 450 and migrated.last_food_ledger.is_empty(), "迁移丢存粮或虚构历史账单")
	migrated.paused = false
	Clock.new(migrated).advance(120)
	_check(migrated.resources["food"] == 435 and migrated.last_food_ledger["overflow"] == 0 and store.save_world(migrated), "超容量旧粮消费或新档保存失败")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 界面模块：实际建粮仓、展开账单并跨存档恢复来源和容量。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main._start_preview(Catalog.GRANARY)
	_check(main.status_label.text.contains("石材10"), "粮仓预览遗漏石材成本")
	main.town_map.hovered = Vector2i(2, 4)
	main._on_placement_clicked({})
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	main._refresh()
	main._toggle_food_details()
	_check(main.storage_label.text.contains("165 / 600") and main.food_detail_label.visible and main.food_detail_label.text.contains("期初180") and main.food_detail_label.text.contains("净变化-15"), "粮仓界面或明细不正确")
	main._save()
	main.world.resources["food"] = 1
	main._load()
	_check(main.storage_label.text.contains("165 / 600") and main.food_detail_label.text.contains("期初180"), "界面读档未恢复容量或账单")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("STORAGE_PASS: capacity, overflow, ledger, shortage, midnight, migration, snapshot, UI")
	quit(1 if failed else 0)

