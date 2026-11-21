## 文件用途：验证军营招募训练、城镇兵源占用、军需日结、重复命令及军事存档与界面恢复。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Army = preload("res://scripts/army_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Remove = preload("res://scripts/removal_service.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
var failed: bool = false

# 启动模块：在场景树可用后执行真实界面测试。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：收集失败原因并用非零退出码阻止失败版本构建。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 夹具模块：真实建造军营，推进到第2日，不自动招募士兵。
func _prepare() -> RefCounted:
	var world: RefCounted = State.new()
	_check(Build.execute(world, "b_barracks", Vector2i(2, 4), "barracks")["ok"], "军营建造失败")
	var before: Dictionary = world.snapshot()
	_check(not Army.recruit(world, "building_000002", "unfinished")["ok"] and world.snapshot() == before, "军营工地能招募或失败扣费")
	world.paused = false
	Clock.new(world).advance(120)
	_check(world.resources["gold"] == 290 and world.resources["wood"] == 90 and world.resources["stone"] == 70 and world.troops.is_empty(), "军营成本或默认空军队错误")
	return world

# 招募与时钟模块：占用兵源与扣费只发生一次，暂停倍速和中途读档不改变训练时长。
func _run() -> void:
	var world: RefCounted = _prepare()
	world.resources["gold"] = 0
	var before: Dictionary = world.snapshot()
	_check(not Army.recruit(world, "building_000002", "poor")["ok"] and world.snapshot() == before, "招募失败修改了人口或库存")
	world.resources["gold"] = 290
	_check(Army.recruit(world, "building_000002", "first")["ok"] and world.resources["gold"] == 240 and world.resources["wood"] == 85 and world.idle_workers() == 17, "招募成本或城镇劳动力占用错误")
	before = world.snapshot()
	_check(Army.recruit(world, "building_000002", "first").get("replayed", false) and world.snapshot() == before, "重复招募重复扣费")
	_check(not Army.recruit(world, "building_000001", "first")["ok"] and not Army.recruit(world, "building_000002", "busy")["ok"] and world.snapshot() == before, "命令冲突或忙碌军营仍招募")
	_check(not Remove.quote(world, "building_000002")["ok"], "仍有训练部队的军营可以拆除")
	world.paused = true
	var clock: RefCounted = Clock.new(world)
	clock.advance(100)
	_check(world.troops[0]["work_done"] == 0 and world.troops[0]["ration_credit"] == 0, "暂停仍训练或产生开销")
	world.paused = false
	clock.advance(30)
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/army_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "军事中途保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.troops.size() == 1 and loaded.troops[0]["work_done"] == 30 and loaded.troops[0]["wage_credit"] == 150 and loaded.idle_workers() == 17, "军事读档丢失进度、信用或占用人数")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	loaded.paused = false
	loaded.speed = 4
	clock = Clock.new(loaded)
	clock.advance(7.5)
	_check(loaded.troops[0]["state"] == "ready" and Army.people(loaded.troops, false, true) == 5 and loaded.idle_workers() == 17, "训练完工重复占用或释放兵员")
	_check(Army.recruit(loaded, "building_000002", "second")["ok"], "第一批完成后不能训练第二批")
	clock.advance(15)
	_check(Army.people(loaded.troops, false, true) == 10 and loaded.resources["food"] == 143 and loaded.resources["gold"] == 203 and loaded.last_army_ledger["wage_needed"] == 7, "两批跨日军需或先收税后发饷错误")
	before = loaded.snapshot()
	_check(not Army.recruit(loaded, "building_000002", "full")["ok"] and loaded.snapshot() == before, "超过军营编额招募")
	loaded.settle_days()
	_check(loaded.snapshot() == before, "重复日结多扣军粮军饷")
	clock.advance(30)
	_check(loaded.last_army_ledger["food_needed"] == 10 and loaded.last_army_ledger["wage_needed"] == 10 and loaded.resources["food"] == 118 and loaded.resources["gold"] == 213, "完整服役一日开销错误")
	loaded.paused = true
	_check(store.save_world(loaded), "军事账单保存失败")
	store.close_store()
	store.open_store(path)
	var reopened: RefCounted = store.load_world()
	_check(reopened != null and reopened.troops == loaded.troops and reopened.last_army_ledger == loaded.last_army_ledger, "军事账单或整数恢复错误")
	# 共享人口模块：生产/施工不能再次占用服役兵源。
	loaded.builders = 0
	loaded.dependents = 20
	_check(loaded.idle_workers() == 0 and not loaded.assign_builders(1), "服役人口被重复分配施工")
	loaded.builders = 2
	loaded.dependents = 6
	# 多军营模块：可以同时训练，各自限额，全镇兵源不足时拒绝而不扣费。
	world = _prepare()
	Build.execute(world, "b_barracks", Vector2i(10, 10), "barracks-2")
	clock = Clock.new(world)
	clock.advance(80)
	Army.recruit(world, "building_000002", "a")
	Army.recruit(world, "building_000003", "b")
	clock.advance(60)
	_check(Army.people(world.troops, false, true) == 10, "多军营不能同时训练")
	Army.recruit(world, "building_000002", "c")
	Army.recruit(world, "building_000003", "d")
	Build.execute(world, "b_barracks", Vector2i(10, 5), "barracks-3")
	clock.advance(80)
	before = world.snapshot()
	_check(world.idle_workers() == 2 and not Army.recruit(world, "building_000004", "no-people")["ok"] and world.snapshot() == before, "兵源不足仍征募或扣费")
	# 按时开销模块：日结前最后一秒招募仅累计一秒，不强扣整日维护。
	world = _prepare()
	clock = Clock.new(world)
	clock.advance(119)
	Army.recruit(world, "building_000002", "last-second")
	clock.advance(1)
	_check(world.last_army_ledger["food_needed"] == 0 and world.troops[0]["ration_credit"] == 5, "最后一秒招募按整日扣费")
	clock.advance(120)
	_check(world.last_army_ledger["wage_needed"] == 5 and world.troops[0]["wage_credit"] == 5, "跨日零头丢失或重复计费")
	# 不足模块：库存不出现负数，本版只记录短缺，不删除士兵或累计债务。
	world = _prepare()
	Army.recruit(world, "building_000002", "shortage")
	world.resources["food"] = 0
	world.resources["gold"] = 0
	world.satisfaction = 0
	world.paused = false
	Clock.new(world).advance(120)
	_check(world.resources["food"] == 0 and world.resources["gold"] == 0 and world.last_army_ledger["food_shortage"] == 5 and world.last_army_ledger["wage_shortage"] == 5 and Army.people(world.troops) == 5 and State.from_snapshot(world.snapshot()) != null, "军需不足出现负数、丢兵或不能存档")
	# 士气模块：验证短缺比例、跨日恢复、同日不重算与旧档迁移。
	_check(world.army_morale == 40 and world.last_morale_before == 60, "两项全缺应扣20士气")
	var morale_save: Dictionary = world.snapshot()
	var morale_loaded: RefCounted = State.from_snapshot(morale_save)
	_check(morale_loaded != null and morale_loaded.army_morale == 40 and morale_loaded.last_morale_before == 60, "士气日结存档恢复失败")
	world.settle_days()
	_check(world.army_morale == 40, "同一天重复扣士气")
	morale_save["army_morale"] = 39
	_check(State.from_snapshot(morale_save) == null, "接受与军需账单不符的士气")
	morale_save["version"] = 12
	morale_save.erase("army_morale")
	morale_save.erase("last_morale_before")
	morale_loaded = State.from_snapshot(morale_save)
	_check(morale_loaded != null and morale_loaded.army_morale == 60 and morale_loaded.last_morale_before == null, "旧档应从60士气开始")
	world.resources["food"] = 17
	world.resources["gold"] = 10
	Clock.new(world).advance(120)
	_check(world.last_army_ledger["food_shortage"] == 3 and world.army_morale == 32, "部分短缺扣分向上取整错误")
	world.resources["food"] = 30
	world.resources["gold"] = 10
	Clock.new(world).advance(120)
	_check(world.army_morale == 34 and world.last_morale_before == 32 and world.idle_workers() == 17, "供给恢复未加士气或兵员变化")
	# 坏档模块：军营引用、兵源来源、人数、进度、回执和账目均必须一致。
	var bad: Dictionary = loaded.snapshot()
	bad["troops"][0]["barracks_id"] = "building_000001"
	_check(State.from_snapshot(bad) == null, "接受非军营归属")
	bad = loaded.snapshot()
	bad["troops"][0]["source"] = "external"
	_check(State.from_snapshot(bad) == null, "改变兵源绕过劳动力占用")
	bad = loaded.snapshot()
	bad["troops"][0]["count"] = 6
	_check(State.from_snapshot(bad) == null, "接受非法兵员数")
	bad = loaded.snapshot()
	bad["troops"][0]["wage_credit"] = -1
	_check(State.from_snapshot(bad) == null, "接受负开销信用")
	bad = loaded.snapshot()
	bad["recruit_commands"] = {}
	_check(State.from_snapshot(bad) == null, "接受丢失招募回执")
	bad = loaded.snapshot()
	bad["last_army_ledger"]["food_used"] = 999
	_check(State.from_snapshot(bad) == null, "接受错误军需账单")
	bad = loaded.snapshot()
	bad["dependents"] = 20
	_check(State.from_snapshot(bad) == null, "读档允许人口超配")
	# 迁移模块：旧档保留经济、满意度和建筑，默认没有军队，不追缴维护。
	var legacy: Dictionary = _prepare().snapshot()
	legacy["version"] = 9
	for key: String in ["troops", "next_troop_id", "recruit_commands", "last_army_ledger"]:
		legacy.erase(key)
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.troops.is_empty() and migrated.resources == legacy["resources"] and migrated.satisfaction == 50, "旧档迁移丢状态或凭空产生部队费用")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 界面模块：选中军营实际点击招募，训练与占用提示随保存读取恢复。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main._start_preview(Catalog.BARRACKS)
	main.town_map.hovered = Vector2i(2, 4)
	main._on_placement_clicked({})
	_check(main.army_recruit_button.disabled, "军营工地招募按钮未禁用")
	main.world.paused = false
	main.clock.advance(80)
	main.world.paused = true
	main._refresh()
	_check(not main.army_recruit_button.disabled, "完工军营招募按钮未启用")
	main.army_recruit_button.pressed.emit()
	_check(main.army_label.text.contains("训练5人") and main.labor_label.text.contains("空闲17") and main.army_recruit_button.disabled, "招募界面未刷新人数与岗位")
	main.world.paused = false
	main.clock.advance(30)
	main.world.paused = true
	main._refresh()
	_check(main.army_detail_label.text.contains("训练50%"), "界面未显示50%训练进度")
	main._save()
	main._load()
	main._inspect_building("building_000002", false)
	_check(main.army_detail_label.text.contains("训练50%") and main.world.idle_workers() == 17, "读档未恢复军事详情")
	main.world.paused = false
	main.clock.advance(10)
	main.world.paused = true
	main._refresh()
	main._toggle_food_details()
	_check(main.food_detail_label.text.contains("军需后余粮164") and main.bill_label.text.contains("军粮-1"), "口粮与军粮余额说明不一致")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("ARMY_PASS: recruit, workforce, training, payroll, shortfall, commands, guards, migration, snapshot, UI")
	quit(1 if failed else 0)

