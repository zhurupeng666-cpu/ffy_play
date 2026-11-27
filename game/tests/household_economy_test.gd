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
	_check_royal_works()
	_check_rural_migration()
	_check_reclamation()
	_check_register()
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


# 皇家工程验收：发标、预算、材料、民居、自有店铺分红和自动读档共用现有世界。
func _check_royal_works() -> void:
	var works = State.Works
	var world: RefCounted = State.new()
	Economy.activate(world,71342)
	world.capital_layout = true
	var family: Dictionary = world.household_economy["families"][2]
	family["cash"] = 500
	var inn: String = Market.found(world,Vector2i(16,12),Catalog.INN)
	world.household_economy["property"][inn] = 2
	var initial: Dictionary = works.quote(world,inn)
	_check(initial["days"]==0 and works.distribute(world,inn,34)==0,"没有持股时也应记录净利")
	var offer: Dictionary = works.quote(world,inn)
	var balance: int = world.resources["gold"]
	var due: int = works.share_price(offer["value"],0,13)
	_check(offer["value"]>initial["value"] and not works.invest(world,inn,13,initial),"营业利润未影响估值或过时报价被接受")
	_check(works.invest(world,inn,13,offer) and world.resources["gold"]==balance-due and family["cash"]==500+due,"认购未按实际股比收费")
	_check(works.distribute(world,inn,34)==4 and world.royal_works["dividends"]==4,"分红未按净利和比例计算")
	var partial: Dictionary = works.quote(world,inn)
	_check(not works.invest(world,inn,87,partial),"资金不足仍可收购")
	world.resources["gold"] = 2000
	_check(works.invest(world,inn,87,partial) and works.quote(world,inn)["share"]==100,"收购未取得全部股份")
	_check(works.distribute(world,inn,34)==34 and works.distribute(world,inn,-8)==0,"全资分红或亏损记录错误")
	var road := Vector2i(13,12)
	_check(works.publish(world,road)["ok"] and not works.publish(world,road)["ok"],"重复投标覆盖地块")
	_check(State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot()))) != null,"待投标订单无法读档")
	world.paused = false
	Clock.new(world).advance(State.DAY_TICKS)
	var orders: Array = world.royal_works["roads"]
	_check(not orders.is_empty() and orders[0]["owner"]>=0 and orders[0]["bid"]>=30,"报价和中标未执行")
	Clock.new(world).advance(25)
	var roadwork: Dictionary = works.road_site(world,[road.x,road.y])
	_check(not roadwork.is_empty() and roadwork["work_done"]==25 and world.royal_works["paid"]==0,"未按施工进度修路或提前支付工程款")
	_check(State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot())))!=null,"道路承包工地和占位不能同时读档")
	Clock.new(world).advance(State.DAY_TICKS-25)
	_check(world.royal_works["roads"].is_empty() and world.royal_works["paid"]>=30,"发包工程未交工付款")
	_check(world.royal_works["wood"]>=3 and world.royal_works["stone"]>=6 and world.royal_works["sales"]>0,"没有向皇家收取材料费")
	_check(not world.royal_works["homes"].is_empty(),"人口住房压力未触发居民自建")
	var reports: Array = world.chancery["items"]
	_check(reports.any(func(row:Dictionary)->bool: return row["title"]=="道路工程中标") and reports.any(func(row:Dictionary)->bool: return row["title"]=="道路完工验收"),"工程中标或验收未归档")
	_check(State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot()))) != null,"施工、住宅产权或股权未恢复")

	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/exit_auto_%d.db" % Time.get_ticks_usec())
	var first: Control = scene.instantiate()
	first.store_path_override = path
	first.auto_lifecycle_for_test = true
	root.add_child(first)
	first.world = world
	_check(first._save_on_exit(),"退出自动保存写入失败")
	first.free()
	var second: Control = scene.instantiate()
	second.store_path_override = path
	second.auto_lifecycle_for_test = true
	root.add_child(second)
	_check(second.world.tick == world.tick and second.world.royal_works == world.royal_works,"进入游戏未自动读取最近存档")
	second.free()
	auto_accept_quit = true
	DirAccess.remove_absolute(path)


# 户籍验收：成年保留姓名，实征有据，住所和搜索可从读档恢复。
func _check_register() -> void:
	var world: RefCounted = State.new()
	Economy.activate(world,71342)
	world.capital_layout=true
	world.resources["food"]=500
	var entry: Dictionary = world.snapshot()["resident_register"][0]
	var child: Dictionary = entry["people"].back()
	var date: int = child["majority"]
	world.paused=false
	Clock.new(world).advance(State.DAY_TICKS*(date-1))
	world.paused=true
	var ready: Dictionary = world.resident_register[0]["people"][2]
	_check(ready["name"]==child["name"] and State.Register.age(ready,date)==18,"成年使登记姓名变化")
	var state: RefCounted = State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot())))
	_check(state!=null and state.resident_register==world.resident_register,"住址、成员及实征记录未成功恢复")
	_check(world.resident_register[0]["address"]!="","人口基础地址未分配")

# 郊地验收：旧档整块迁出并保留资产ID、人员、收据和户口，迁后可再次读档。
func _check_rural_migration() -> void:
	var world: RefCounted = State.new()
	Economy.activate(world,71342)
	world.capital_layout = true
	var farm: String = Market.found(world,Vector2i(29,14),Catalog.FARM)
	var ranch: String = Market.found(world,Vector2i(39,14),Catalog.for_construction("b_ranch",true))
	world.household_economy["property"][farm]=1
	var barracks: String = Market.found(world,Vector2i(63,14),Catalog.for_construction("b_barracks",true))
	var before: Dictionary = world.snapshot()
	before["version"]=31
	before["royal_works"].erase("profits")
	_check(State.from_snapshot(world.snapshot())==null,"新档允许农牧地与城市边界相交")
	var migrated: RefCounted = State.from_snapshot(JSON.parse_string(JSON.stringify(before)))
	_check(migrated!=null,"旧档城市农牧地无法迁移")
	if migrated==null:
		return
	var ranch_present: bool = false
	for record: Dictionary in migrated.buildings:
		if record["def_id"] in State.Rural.FARM_KINDS:
			var at := Vector2i(record["cell"][0],record["cell"][1])
			_check(not State.Capital.OUTER.intersects(Rect2i(at,Catalog.footprint(record))),"农牧地未完全迁出城")
			ranch_present=ranch_present or record["id"]==ranch
	var camps: Array = migrated.buildings.filter(func(record:Dictionary)->bool: return record["id"]==barracks)
	_check(ranch_present and migrated.household_economy["property"][farm]==1 and not camps.is_empty(),"迁址丢失牧场、军营或农田地契")
	_check(not State.Rural.Place.check_building(Vector2i(63,14),Catalog.BARRACKS,{},true)["ok"],"城内仍可新增军营")
	_check(migrated.resources==world.resources and State.from_snapshot(JSON.parse_string(JSON.stringify(migrated.snapshot())))!=null,"迁址扣费或新档无法读取")
	_check(not State.Rural.Place.check_building(Vector2i(39,14),Catalog.RANCH,{},true)["ok"],"城内仍可新增牧场")
	var lots: Array[Dictionary] = State.Rural.lots(migrated)
	var routes: Dictionary = State.Rural.routes(migrated,lots)
	_check(not routes.is_empty() and routes.size()==lots.size(),"迁后农户没有通勤路线")

# 审批验收：田权在批准前不入账，重复审批和驳回不扣款，结算与奏章跨存档可复核。
func _check_reclamation() -> void:
	var world: RefCounted = State.new()
	world.capital_layout=true
	Economy.activate(world,71342)
	var owner: int = 1
	var family: Dictionary = world.household_economy["families"][owner]
	family["cash"]=140
	var request: Dictionary = {"owner":owner,"day":1,"crop":1,"acres":4}
	var rejected: Dictionary = {"owner":2,"day":1,"crop":0,"acres":3}
	world.chancery["claims"].append_array([request,rejected])
	var old_wood: int = world.resources["wood"]
	_check(family["land"]==0 and world.chancery["fields"].is_empty(),"未审批就出现农田或地权")
	_check(State.Rural.rule(world,rejected,false)=="" and world.chancery["fields"].is_empty(),"驳回误发地权")
	_check(State.Rural.rule(world,request,true)=="" and family["land"]==4 and family["cash"]==100 and world.resources["wood"]==old_wood-4,"批准账目不一致")
	_check(State.Rural.rule(world,request,true)!="" and world.chancery["fields"].size()==1,"重复审批产生新田")
	var field: Dictionary = world.chancery["fields"].values()[0]
	var record: Dictionary = world.buildings.back()
	_check(record["state"]=="constructing" and record["work_done"]==0 and State.Rural.harvest(world,owner,4,100)==0 and field["yield"]==-1,"批准后的田块越过垦田过程或提前产粮")
	world.paused=false
	Clock.new(world).advance(7)
	_check(record["state"]=="constructing" and record["work_done"]==7,"垦田没有逐步推进")
	var mid: RefCounted = State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot())))
	_check(mid!=null and mid.buildings.back()["work_done"]==7 and mid.buildings.back()["state"]=="constructing","施工中存档丢失工序")
	Clock.new(world).advance(9)
	_check(record["state"]=="ready","完成整地播种后没有转为可用田块")
	var result: int = State.Rural.harvest(world,owner,4,100)
	_check(field["crop"]==1 and field["yield"]==result and result==6,"单田作物或收成公式不正确")
	var restored: RefCounted = State.from_snapshot(JSON.parse_string(JSON.stringify(world.snapshot())))
	_check(restored!=null and restored.chancery==world.chancery,"奏章、拒绝历史或产量未跨存档保持")
