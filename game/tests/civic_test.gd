## 文件用途：验证税率切换、满意度供粮联动、日结顺序、边界、旧档迁移和界面存档恢复。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Civic = preload("res://scripts/civic_economy.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Build = preload("res://scripts/construction_service.gd")
var failed: bool = false

# 启动模块：等待场景树可创建真实管理界面。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：规则失败时记录原因并返回非零退出码。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 规则模块：三个政策的收入和满意度绑定同一日结，不可分别获取好处。
func _run() -> void:
	var bill: Dictionary = Civic.calculate(1, "low", 50, 30, 0, 300)
	_check(bill["tax"] == 15 and bill["after"] == 52, "低税初始数值错误")
	bill = Civic.calculate(1, "standard", 50, 30, 0, 300)
	_check(bill["tax"] == 20 and bill["after"] == 50, "标准税破坏旧基准")
	bill = Civic.calculate(1, "high", 50, 30, 0, 300)
	_check(bill["tax"] == 30 and bill["after"] == 47, "高税初始数值错误")
	bill = Civic.calculate(1, "standard", 50, 30, 2, 300)
	_check(bill["food_penalty"] == 2 and bill["after"] == 48, "缺粮未按缺口比例扣分")
	bill = Civic.calculate(1, "standard", 40, 30, 0, 300)
	_check(bill["tax"] == 16 and bill["recovery"] == 1 and bill["after"] == 41, "供粮恢复或税前满意度顺序错误")
	bill = Civic.calculate(1, "low", 100, 30, 0, 300)
	_check(bill["after"] == 100 and bill["delta"] == 0, "满意度超过上限")
	bill = Civic.calculate(1, "high", 0, 30, 15, 300)
	_check(bill["after"] == 0 and bill["tax"] == 0, "满意度负数或零满意度仍收税")
	bill = Civic.calculate(1, "standard", 50, 30, 0, 999999999)
	_check(bill["tax_stored"] == 1 and bill["tax_overflow"] == 19 and bill["gold_after"] == 1000000000, "金币上限账目错误")
	# 切换与时钟模块：政策只在日结生效，暂停不收税，跨进程午夜续接只结算一次。
	var world: RefCounted = State.new()
	var before: Dictionary = world.snapshot()
	_check(not world.set_tax_policy("unknown") and world.snapshot() == before, "未知政策改变状态")
	for index: int in range(100):
		world.set_tax_policy("low")
		world.set_tax_policy("high")
	_check(world.resources["gold"] == 300 and world.satisfaction == 50 and world.tick == 0, "切换政策即时发钱或改满意度")
	var clock: RefCounted = Clock.new(world)
	clock.advance(120)
	_check(world.tick == 0, "暂停时发生政务日结")
	world.paused = false
	clock.advance(119.5)
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/civic_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "政策午夜前保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.tax_policy == "high" and loaded.satisfaction == 50, "政策或满意度读档失败")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	loaded.paused = false
	clock = Clock.new(loaded)
	clock.advance(0.5)
	_check(loaded.resources["gold"] == 330 and loaded.satisfaction == 47 and loaded.last_civic_ledger["policy"] == "high", "午夜高税实际日结错误")
	before = loaded.snapshot()
	loaded.settle_days()
	_check(loaded.snapshot() == before, "同日重复征税或改变满意度")
	loaded.set_tax_policy("low")
	loaded.speed = 4
	clock.advance(30)
	_check(loaded.resources["gold"] == 344 and loaded.satisfaction == 50 and loaded.last_civic_ledger["recovery"] == 1, "低税恢复或倍速改变日结")
	loaded.set_tax_policy("high")
	_check(loaded.last_civic_ledger["policy"] == "low", "切换政策改写历史账单")
	loaded.paused = true
	_check(store.save_world(loaded), "政务账单保存失败")
	store.close_store()
	store.open_store(path)
	var reopened: RefCounted = store.load_world()
	_check(reopened != null and reopened.last_civic_ledger == loaded.last_civic_ledger, "政务账单内容或数值类型未恢复")
	# 供粮模块：缺粮降低后续征收，恢复供粮后缓慢恢复，不生成叛乱或人口损失。
	world = State.new()
	world.resources["food"] = 0
	world.paused = false
	clock = Clock.new(world)
	clock.advance(120)
	_check(world.satisfaction == 40 and world.resources["gold"] == 320, "缺粮当日税收或满意度错误")
	clock.advance(120)
	_check(world.satisfaction == 30 and world.resources["gold"] == 336 and world.population == 30, "缺粮没有影响后续税收或错误扣人口")
	world.resources["food"] = 15
	clock.advance(120)
	_check(world.satisfaction == 31 and world.last_civic_ledger["food_penalty"] == 0, "恢复供粮后没有恢复满意度")
	world = State.new()
	world.resources["food"] = 0
	Build.execute(world, "b_farm", Vector2i(2, 4), "civic-farm")
	world.paused = false
	clock = Clock.new(world)
	clock.advance(120)
	world.assign_producers("building_000002", 3)
	clock.advance(120)
	_check(world.satisfaction == 41 and world.last_food_ledger["produced"] == 18 and world.last_civic_ledger["shortage"] == 0, "政务没有使用同日粮食生产结算结果")
	# 坏档与迁移模块：政策、范围与同日账单关系必须有效，旧档不追收税。
	var bad: Dictionary = loaded.snapshot()
	bad["tax_policy"] = "unknown"
	_check(State.from_snapshot(bad) == null, "接受未知税率存档")
	bad = loaded.snapshot()
	bad["satisfaction"] = 101
	_check(State.from_snapshot(bad) == null, "接受满意度越界")
	bad = loaded.snapshot()
	bad["last_civic_ledger"]["tax"] = 999
	_check(State.from_snapshot(bad) == null, "接受不合法税收账单")
	bad = loaded.snapshot()
	bad["last_civic_ledger"]["shortage"] = 15
	_check(State.from_snapshot(bad) == null, "政务和粮食缺口不一致仍读档")
	bad = loaded.snapshot()
	bad.erase("last_civic_ledger")
	_check(State.from_snapshot(bad) == null, "接受缺字段v9")
	var legacy: Dictionary = loaded.snapshot()
	legacy["version"] = 8
	for key: String in ["tax_policy", "satisfaction", "last_civic_ledger"]:
		legacy.erase(key)
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.resources == loaded.resources and migrated.satisfaction == 50 and migrated.tax_policy == "standard" and migrated.last_civic_ledger.is_empty(), "旧档迁移扣税、丢资源或错误默认政策")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 实际界面模块：政策按钮、当前预测与历史账单明确区分，并随读档恢复。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.legacy_economy_fixture = true
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main.tax_buttons["high"].pressed.emit()
	_check(main.tax_buttons["high"].disabled and main.numbers["forecast"].text == "30" and main.world.resources["gold"] == 300, "政策按钮预测或即时收入错误")
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	main._refresh()
	_check(main.numbers["satisfaction"].text == "47 / 100" and main.numbers["forecast"].text == "28" and main.numbers["tax_stored"].text == "+30", "界面混淆当前预测和历史收税")
	main._save()
	main._set_tax_policy("low")
	main._load()
	_check(main.world.tax_policy == "high" and main.world.satisfaction == 47 and main.tax_buttons["high"].disabled, "界面读档未恢复政策满意度")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("CIVIC_PASS: policy, satisfaction, shortage, recovery, midnight, bounds, migration, snapshot, UI")
	quit(1 if failed else 0)
