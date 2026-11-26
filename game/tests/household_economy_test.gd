## 文件用途：验证居民私产迁移、雇工、商税、任命与存档重放。
extends SceneTree

const State = preload("res://scripts/world_state.gd")
const Economy = preload("res://scripts/household_economy.gd")
const Build = preload("res://scripts/construction_service.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Market = preload("res://scripts/district_market.gd")
const Removal = preload("res://scripts/removal_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Army = preload("res://scripts/army_service.gd")
const Legions = preload("res://scripts/legion_service.gd")
var failed: bool = false


# 启动模块：先等待游戏树初始化再执行测试。
func _initialize() -> void:
	call_deferred("_run")


# 断言模块：每项失败保留原因并返回非零退出码。
func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


# 迁移和经济验收：从旧版设施进入新版户籍，明确私产和官府的分工。
func _run() -> void:
	var world: RefCounted = State.new()
	world.resources = {"wood": 5000, "stone": 1000, "gold": 5000, "food": 2000}
	_build(world, "b_farm", Vector2i(16, 3), true)
	_build(world, "b_fishery", Vector2i(8, 71), false)
	_build(world, "b_barracks", Vector2i(28, 3), true)
	_check(world.assign_producers("building_000002", 1), "旧版农场岗位样本失败")
	var old: RefCounted = State.from_snapshot(world.snapshot())
	_check(old != null, "旧版经济档无法校验")
	if old == null:
		quit(1)
		return
	Economy.activate(old, 71287)
	var economy: Dictionary = old.household_economy
	var families: Array = economy["families"]
	_check(families.size() == old.households.size() and economy["property"].size() == 2, "迁移丢失户籍或资产归属")
	_check(old.buildings[1]["workers"] == 0 and old.buildings[2]["state"] == "constructing", "迁移未解除官营岗位或丢失私人工地")
	_check(not old.assign_producers("building_000002", 1) and not old.assign_estate_producers("building_000002", 1) and not Removal.quote(old, "building_000002")["ok"], "私产还能被官府派工或拆除")
	_check(Build.execute(old, "b_farm", Vector2i(23, 3), "deny-farm")["code"] == "RESIDENT_PROPERTY", "新版仍允许建官营农场")
	for index: int in range(families.size()):
		families[index]["land"] = 0
		families[index]["cash"] = 10
	families[0]["land"] = 21
	families[0]["cash"] = 600
	families[0]["civil"] = 90
	families[1]["cash"] = 550
	families[1]["marshal"] = 90
	var shop: String = Market.found(old, Vector2i(41, 2), Catalog.TAVERN)
	economy["property"][shop] = families.size() - 1
	_check(Economy.appoint(old, 0, false) and Economy.tax_bonus(old) == 10, "税务官未按文才生效")
	_check(not Economy.appoint(old, 2, false) and not Economy.appoint(old, 1, true), "任命绕过家资或驻军校验")
	var recruits: Dictionary = Army.recruit(old, "building_000004", "civil-troop")
	_check(recruits["ok"], "征兵样本失败")
	old.paused = false
	Clock.new(old).advance(State.DAY_TICKS)
	var legion: Dictionary = Legions.create(old, "civil-legion")
	_check(legion["ok"] and Legions.set_count(old, legion["legion_id"], recruits.get("troop_id", ""), 2)["ok"], "军团样本失败")
	_check(not Economy.appoint(old, 0, true, legion["legion_id"]) and Economy.appoint(old, 1, true, legion["legion_id"]), "武将任命或同户兼任规则错误")
	_check(old.effective_battle_morale(legion["legion_id"]) > old.army_morale and old.effective_battle_morale("other") == old.army_morale, "指挥加成影响了其他军团")
	var fiscal: Dictionary = economy["report"]
	_check(fiscal["tax_grain"] > 0 and fiscal["fish"] > 0 and fiscal["shop_tax"] > 0 and fiscal["hires"] > 0, "税粮、渔获、直营店铺或雇工未结算 %s" % fiscal)
	_check(old.last_food_ledger["by_source"]["tax_grain"] == fiscal["tax_grain"] and old.last_civic_ledger.get("shop_gold", {}).get("income", -1) == fiscal["shop_tax"], "私产税未进入官府账本")
	var snapshot: Dictionary = old.snapshot()
	var replay: RefCounted = State.from_snapshot(JSON.parse_string(JSON.stringify(snapshot)))
	_check(replay != null and replay.snapshot() == snapshot, "新版户籍快照或账本恢复失败")
	if replay != null:
		Clock.new(old).advance(3 * State.DAY_TICKS)
		Clock.new(replay).advance(3 * State.DAY_TICKS)
		_check(replay.snapshot() == old.snapshot(), "读档后居民随机生产不可重放")
	_check(Legions.dissolve(old, legion["legion_id"])["ok"] and economy["general"] == -1, "解散军团后留下悬空武将")
	_check_investment()
	_check_player_view()
	if not failed:
		print("HOUSEHOLD_PASS: migration, property, farming, fishing, paid labor, shop tax, appointment, deterministic save and UI")
	quit(1 if failed else 0)


# 建造夹具：使用正式建设和回执，测试需要时直接完成指定施工。
func _build(world: RefCounted, kind: String, cell: Vector2i, complete: bool) -> void:
	var result: Dictionary = Build.execute(world, kind, cell, "household-" + kind)
	_check(result["ok"], "夹具建造失败 " + kind)
	if result["ok"] and complete:
		var building: Dictionary = world.buildings.back()
		building["state"] = "ready"
		building["work_done"] = building["work_required"]


# 自营验收：有临街市场和足够家资时，居民投资并在随后日结缴纳营业税。
func _check_investment() -> void:
	var world: RefCounted = State.new()
	Economy.activate(world, 91715)
	for family: Dictionary in world.household_economy["families"]:
		family["cash"] = 420
	for x: int in range(20, 45):
		var point := Vector2i(x, 0)
		var command: Dictionary = Build.execute(world, "b_road", point, "road-%d" % x)
		if not command["ok"]:
			_check(false, "连通商街样本失败")
			return
		var street: Dictionary = world.buildings.back()
		street["state"] = "ready"
		street["work_done"] = street["work_required"]
	Market.found(world, Vector2i(30, 1), Catalog.MARKET)
	var shop_days: int = 0
	world.paused = false
	var clock: RefCounted = Clock.new(world)
	for day: int in range(20):
		clock.advance(State.DAY_TICKS)
		if world.household_economy["report"]["shop_tax"] > 0:
			shop_days += 1
	var shops: int = 0
	var manors: int = 0
	for building: Dictionary in world.buildings:
		if building["def_id"] in Economy.SHOPS:
			shops += 1
			_check(Economy.owns(world, building["id"]), "自营店铺没有户主")
		if building["def_id"] == "b_manor":
			manors += 1
	_check(shops > 0 and shops <= 4 and shop_days > 0 and manors > 0, "商街未按需求开店、缴税或营建府邸 %s" % [Vector3i(shops, shop_days, manors)])
	_check(State.from_snapshot(world.snapshot()) != null, "长期自营后存档无法恢复")


# 正常界面验收：没有旧测试开关，默认启用户籍并显示新建造分类。
func _check_player_view() -> void:
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.store_path_override = ProjectSettings.globalize_path("res://local_data/tests/household_%d.db" % Time.get_ticks_usec())
	root.add_child(main)
	_check(main.household_list.item_count == 12 and main.household_list.get_item_text(0).contains("亩") and main.household_detail.text.contains("文才"), "默认界面未打开新版户籍")
	_check(main.build_toolbar.get_child(1).get_popup().item_count == 1 and main.build_toolbar.get_child(3).get_popup().item_count == 4, "新版仍展示官营农渔或缺少市政建造")
	main.world.paused = false
	main.clock.advance(State.DAY_TICKS)
	main.world.paused = true
	main._refresh()
	main._save()
	_check(main.store.load_world() != null, "正常界面的新版存档无法重读")
	var path: String = main.store_path_override
	main.free()
	DirAccess.remove_absolute(path)
