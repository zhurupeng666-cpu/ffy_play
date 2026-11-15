## 文件用途：验证取消训练退款、现役解散、兵源归还、未结军需保留及历史幂等与界面确认。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Army = preload("res://scripts/army_service.gd")
const Disband = preload("res://scripts/army_disband_service.gd")
const Build = preload("res://scripts/construction_service.gd")
const Remove = preload("res://scripts/removal_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
var failed: bool = false

# 启动模块：在真实管理场景可以加入树之后执行。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：记录失败并以非零退出码阻止构建。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 夹具模块：建立完工军营并对齐日界，便于核对训练退款和军需。
func _prepare() -> RefCounted:
	var world: RefCounted = State.new()
	Build.execute(world, "b_barracks", Vector2i(2, 4), "camp")
	world.paused = false
	Clock.new(world).advance(120)
	return world

# 经济与幂等模块：退款只发生一次，兵源可重新使用，旧招募命令不会复活旧批次。
func _run() -> void:
	var world: RefCounted = _prepare()
	Army.recruit(world, "building_000002", "first")
	Clock.new(world).advance(30)
	var before: Dictionary = world.snapshot()
	var offer: Dictionary = Disband.quote(world, "troop_000001")
	_check(offer["refund"]["gold"] == 25 and offer["refund"]["wood"] == 2 and offer["ration_credit"] == 150 and world.snapshot() == before, "半程退款、军需或只读预览错误")
	_check(Disband.execute(world, "troop_000001", "cancel-first")["ok"] and world.idle_workers() == 22 and world.resources["gold"] == 265 and world.resources["wood"] == 87 and world.retired_army_cost["ration_credit"] == 150, "取消未返还兵源、退款或保留军需")
	before = world.snapshot()
	_check(Disband.execute(world, "troop_000001", "cancel-first").get("replayed", false) and world.snapshot() == before, "重复退役重复退款或转移军需")
	_check(not Disband.execute(world, "troop_000002", "cancel-first")["ok"] and not Disband.execute(world, "troop_000001", "again")["ok"] and world.snapshot() == before, "冲突或失效目标改变了世界")
	_check(Army.recruit(world, "building_000002", "first").get("replayed", false) and world.snapshot() == before, "旧招募命令复活退役批次")
	_check(Army.recruit(world, "building_000002", "second")["troop_id"] == "troop_000002" and world.idle_workers() == 17, "不能重新招募或复用旧ID")
	world.paused = true
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/disband_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "同时活动与退役记录保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.troops.size() == 1 and loaded.retired_troops.size() == 1 and loaded.retired_army_cost["wage_credit"] == 150, "退役历史或待结费用读档丢失")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	before = loaded.snapshot()
	_check(Disband.execute(loaded, "troop_000001", "cancel-first").get("replayed", false) and loaded.snapshot() == before, "重开后重复退款")
	# 未结军需模块：多个退役零头合并，日结后保留余数且不再新增服役费用。
	loaded.paused = false
	Clock.new(loaded).advance(30)
	Disband.execute(loaded, "troop_000002", "cancel-second")
	_check(loaded.retired_army_cost["ration_credit"] == 300 and loaded.idle_workers() == 22, "两次取消的军需被清除或重复占人")
	Clock.new(loaded).advance(60)
	_check(loaded.last_army_ledger["food_needed"] == 2 and loaded.last_army_ledger["wage_needed"] == 2 and loaded.resources["food"] == 148 and loaded.resources["gold"] == 258 and loaded.retired_army_cost["ration_credit"] == 60, "退役军需没有正确兑付和保留零头")
	before = loaded.snapshot()
	loaded.settle_days()
	_check(loaded.snapshot() == before, "同日多次扣退役军需")
	Clock.new(loaded).advance(120)
	_check(loaded.last_army_ledger["food_needed"] == 0 and loaded.retired_army_cost["ration_credit"] == 60, "退役之后继续累计军需或丢失零头")
	# 现役与建筑模块：现役不退款，清空后军营可拆，历史仍可引用退役军营并存档。
	Army.recruit(loaded, "building_000002", "third")
	Clock.new(loaded).advance(60)
	before = loaded.snapshot()
	_check(Disband.quote(loaded, "troop_000003")["refund"]["gold"] == 0, "现役解散仍退款")
	Disband.execute(loaded, "troop_000003", "dismiss-third")
	_check(loaded.resources == before["resources"] and loaded.retired_army_cost["ration_credit"] == 360, "解散现役改变库存或丢维护")
	Clock.new(loaded).advance(60)
	_check(loaded.last_army_ledger["food_needed"] == 3 and loaded.retired_army_cost["ration_credit"] == 0 and loaded.retired_army_cost["ration_settled"] == 5, "现役退役开销不守恒")
	_check(Remove.execute(loaded, "building_000002", "remove-empty-camp")["ok"], "清空部队后仍不能拆军营")
	_check(store.save_world(loaded), "退役部队引用已拆军营时不能保存")
	store.close_store()
	store.open_store(path)
	var reopened: RefCounted = store.load_world()
	_check(reopened != null and reopened.retired_troops.size() == 3 and reopened.buildings.size() == 1 and reopened.idle_workers() == 22, "已拆军营的退役历史不能恢复")
	# 边界与坏档模块：退款上限明确损失，伪造退款或抹掉待结军需必须拒绝。
	world = _prepare()
	Army.recruit(world, "building_000002", "max")
	world.resources["gold"] = 999999999
	world.resources["wood"] = 1000000000
	offer = Disband.quote(world, "troop_000001")
	_check(offer["refund"]["gold"] == 1 and offer["overflow"]["gold"] == 49 and offer["refund"]["wood"] == 0 and offer["overflow"]["wood"] == 5, "取消退款突破安全上限")
	Disband.execute(world, "troop_000001", "max-cancel")
	_check(State.from_snapshot(world.snapshot()) != null, "上限退款回执无法恢复")
	var bad: Dictionary = loaded.snapshot()
	bad["disband_commands"]["cancel-first"]["refund"]["gold"] = 999
	_check(State.from_snapshot(bad) == null, "接受超额退役退款")
	bad = loaded.snapshot()
	bad["retired_army_cost"]["ration_settled"] = 0
	_check(State.from_snapshot(bad) == null, "接受抹掉已结军需证明的坏档")
	bad = loaded.snapshot()
	bad["disband_commands"] = {}
	_check(State.from_snapshot(bad) == null, "退役批次丢失回执仍可读取")
	bad = loaded.snapshot()
	bad["retired_troops"][1]["id"] = "troop_000001"
	_check(State.from_snapshot(bad) == null, "接受重复军队ID")
	# 迁移模块：v10活动批次补冻结实付费用，不产生退役、退款或维护追缴。
	world = _prepare()
	Army.recruit(world, "building_000002", "legacy")
	Clock.new(world).advance(30)
	var legacy: Dictionary = world.snapshot()
	legacy["version"] = 10
	for key: String in ["retired_troops", "disband_commands", "retired_army_cost"]:
		legacy.erase(key)
	for troop: Dictionary in legacy["troops"]:
		troop.erase("paid_cost")
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.resources == world.resources and migrated.troops[0]["work_done"] == 30 and Disband.quote(migrated, "troop_000001")["refund"]["gold"] == 25, "v10迁移改变了原批次或费用")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 确认界面模块：保留无副作用，过期预览拒绝，成功后当前军营列表与人口同步。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main.world = _prepare()
	main.clock = Clock.new(main.world)
	main.world.paused = true
	main._sync_building_view()
	main._inspect_building("building_000002", false)
	main._recruit_infantry()
	main.world.paused = false
	main.clock.advance(30)
	main._refresh()
	before = main.world.snapshot()
	main._request_army_disband()
	main.clock.advance(100)
	_check(main.world.paused and main.army_disband_dialog.dialog_text.contains("退金币25、木材2"), "取消训练确认没有冻结时间或列明退款")
	main._cancel_army_disband()
	_check(main.world.snapshot() == before, "保留部队改变了时间状态、人口或库存")
	main._request_army_disband()
	main.world.resources["gold"] += 1
	main._confirm_army_disband()
	_check(main.world.troops.size() == 1 and main.status_label.text.contains("状态已变化"), "过期退役预览仍执行")
	main._request_army_disband()
	main._confirm_army_disband()
	_check(main.world.troops.is_empty() and main.world.idle_workers() == 22 and main.world.resources["gold"] == 266 and main.army_troop_picker.item_count == 0 and main.army_label.text.contains("退役待结"), "取消训练没有刷新批次、兵源和待结开销")
	main.world.paused = true
	main._save()
	main._load()
	main._inspect_building("building_000002", false)
	_check(main.army_troop_picker.item_count == 0 and main.world.retired_army_cost["ration_credit"] == 150, "读档复活部队或清掉未结军需")
	main.world.paused = false
	main.clock.advance(90)
	main.world.paused = true
	main._refresh()
	_check(main.army_bill_label.visible and main.world.last_army_ledger["food_needed"] == 1 and main.world.retired_army_cost["ration_credit"] == 30, "全部退役后军需账单被隐藏或费用丢失")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("DISBAND_PASS: refund, workforce, commands, pending upkeep, history, migration, empty camp, confirmation, UI")
	quit(1 if failed else 0)
