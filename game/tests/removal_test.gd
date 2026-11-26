## 文件用途：验证取消施工退款、拆除影响、历史幂等、存档迁移及确认窗口的无副作用取消。
extends SceneTree
const State = preload("res://scripts/world_state.gd")
const Build = preload("res://scripts/construction_service.gd")
const Remove = preload("res://scripts/removal_service.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
var failed: bool = false

# 启动模块：场景树就绪后使用隔离数据库执行完整验收。
func _initialize() -> void:
	call_deferred("_run")

# 断言模块：失败时记录原因并使用非零退出码阻断构建。
func _check(value: bool, reason: String) -> void:
	if not value:
		failed = true
		push_error(reason)

# 退款与历史模块：取消后释放占地，旧命令无法重建或重复发放材料。
func _run() -> void:
	var world: RefCounted = State.new()
	var before: Dictionary = world.snapshot()
	_check(not Remove.execute(world, "building_000001", "hall")["ok"] and world.snapshot() == before, "领主厅可拆除或失败修改了世界")
	Build.execute(world, "b_house", Vector2i(2, 2), "house")
	Build.execute(world, "b_farm", Vector2i(2, 4), "farm")
	world.paused = false
	Clock.new(world).advance(10)
	var offer: Dictionary = Remove.quote(world, "building_000002")
	_check(offer["refund"]["wood"] == 15 and offer["refund"]["stone"] == 0, "25%住宅未按剩余比例退款")
	var house_definition: Resource = Catalog.HOUSE
	var old_cost: Dictionary = house_definition.get("cost").duplicate()
	var changed_cost: Dictionary = old_cost.duplicate()
	changed_cost["wood"] = 200
	house_definition.set("cost", changed_cost)
	_check(Remove.quote(world, "building_000002")["refund"]["wood"] == 15, "调价改变了实付费用退款")
	house_definition.set("cost", old_cost)
	_check(Remove.execute(world, "building_000002", "remove-house")["ok"] and world.resources["wood"] == 90 and world.resources["gold"] == 280 and not world.occupied_cells().has(Vector2i(2, 2)), "取消退款或占地释放错误")
	before = world.snapshot()
	_check(Remove.execute(world, "building_000002", "remove-house").get("replayed", false) and world.snapshot() == before, "重复退款")
	_check(not Remove.execute(world, "building_000003", "remove-house")["ok"] and not Remove.execute(world, "building_000002", "second")["ok"] and world.snapshot() == before, "冲突或已移除目标改变了世界")
	_check(Build.execute(world, "b_house", Vector2i(2, 2), "house").get("replayed", false) and world.snapshot() == before, "旧建造命令复活了已移除建筑")
	_check(Build.execute(world, "b_house", Vector2i(2, 2), "new-house")["building_id"] == "building_000004", "原址重建失败或ID复用")
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/removal_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	_check(store.open_store(path) and store.save_world(world), "重叠历史存档保存失败")
	store.close_store()
	store.open_store(path)
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.buildings.size() == 3 and loaded.retired_buildings.size() == 1, "退役和活动占地重叠导致读档失败")
	if loaded == null:
		store.close_store()
		quit(1)
		return
	before = loaded.snapshot()
	_check(Remove.execute(loaded, "building_000002", "remove-house").get("replayed", false) and loaded.snapshot() == before, "重开后重复退款")
	# 进度边界模块：向下取整且取消当前工地清空半份施工信用。
	world = State.new()
	Build.execute(world, "b_farm", Vector2i(2, 4), "rounding")
	world.paused = false
	Clock.new(world).advance(1)
	_check(Remove.quote(world, "building_000002")["refund"]["wood"] == 24, "退款没有向下取整")
	world = State.new()
	Build.execute(world, "b_house", Vector2i(2, 2), "half-house")
	Build.execute(world, "b_farm", Vector2i(2, 4), "half-farm")
	world.assign_builders(1)
	world.paused = false
	Clock.new(world).advance(1)
	Remove.execute(world, "building_000002", "half-remove")
	Clock.new(world).advance(1)
	_check(world.buildings[1]["work_done"] == 0 and world.labor_credit == 1, "已取消工地的半份工作转移到了下一个工地")
	# 完工拆除模块：释放人员，丢弃未入库产量，粮仓减容但不删除已有粮食。
	world = State.new()
	Build.execute(world, "b_farm", Vector2i(2, 4), "ready-farm")
	world.paused = false
	Clock.new(world).advance(120)
	world.assign_producers("building_000002", 3)
	Clock.new(world).advance(10)
	offer = Remove.quote(world, "building_000002")
	_check(offer["workers"] == 3 and offer["food_credit"] == 180 and offer["refund"]["wood"] == 0, "拆除影响预览错误")
	Remove.execute(world, "building_000002", "ready-remove")
	_check(world.idle_workers() == 22 and world.resources["wood"] == 95, "完工拆除错误退款或未释放工人")
	Build.execute(world, "b_granary", Vector2i(10, 5), "grain")
	Clock.new(world).advance(60)
	world.resources["food"] = 500
	Remove.execute(world, "building_000003", "grain-remove")
	_check(world.food_capacity() == 300 and world.resources["food"] == 500, "拆粮仓截断了已有库存")
	Clock.new(world).advance(50)
	_check(world.resources["food"] == 485 and world.last_food_ledger["produced"] == 0, "已拆建筑继续产粮")
	# 数值上限模块：退款溢出被准确记录，不突破安全上限。
	world = State.new()
	Build.execute(world, "b_house", Vector2i(2, 2), "max")
	world.resources["wood"] = 999999999
	offer = Remove.quote(world, "building_000002")
	_check(offer["refund"]["wood"] == 1 and offer["overflow"]["wood"] == 19, "退款安全上限错误")
	Remove.execute(world, "building_000002", "max-remove")
	_check(world.resources["wood"] == 1000000000 and State.from_snapshot(world.snapshot()) != null, "溢出退款不能存档")
	# 历史坏档模块：退款、引用、字段和退役身份必须完整一致。
	var bad: Dictionary = loaded.snapshot()
	bad["removal_commands"]["remove-house"]["refund"]["wood"] = 999
	_check(State.from_snapshot(bad) == null, "接受超额退款历史")
	bad = loaded.snapshot()
	bad["removal_commands"] = {}
	_check(State.from_snapshot(bad) == null, "接受缺移除回执的退役建筑")
	bad = loaded.snapshot()
	bad["retired_buildings"][0]["id"] = "building_000004"
	_check(State.from_snapshot(bad) == null, "接受退役与活动建筑重复ID")
	bad = loaded.snapshot()
	bad["buildings"][1]["paid_cost"]["wood"] = -1
	_check(State.from_snapshot(bad) == null, "接受非法实付费用")
	# 旧档模块：历史费用冻结迁移，旧建筑与资源不变。
	world = State.new()
	Build.execute(world, "b_house", Vector2i(2, 2), "legacy")
	var legacy: Dictionary = world.snapshot()
	legacy["version"] = 7
	legacy.erase("retired_buildings")
	legacy.erase("removal_commands")
	for record: Dictionary in legacy["buildings"]:
		record.erase("paid_cost")
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.resources == world.resources and Remove.quote(migrated, "building_000002")["refund"]["wood"] == 20, "旧档费用或退款迁移失败")
	store.close_store()
	DirAccess.remove_absolute(path)
	# 确认窗口模块：取消完全恢复原状态，确认后世界校验拦截过期预览。
	var main: Control = load("res://scenes/world_prototype.tscn").instantiate()
	main.legacy_economy_fixture = true
	main.store_path_override = path + "-ui.db"
	root.add_child(main)
	main._start_preview(Catalog.HOUSE)
	main.town_map.hovered = Vector2i(2, 2)
	main._on_placement_clicked({})
	main.world.paused = false
	before = main.world.snapshot()
	main._request_removal()
	main.clock.advance(100)
	_check(main.world.paused and main.world.tick == 0 and main.removal_dialog.dialog_text.contains("退木材20"), "确认窗口未冻结时间或退款说明错误")
	main._cancel_removal()
	_check(main.world.snapshot() == before, "取消确认改变了世界或没有恢复运行状态")
	main._request_removal()
	main.world.resources["gold"] += 1
	main._confirm_removal()
	_check(main.world.buildings.size() == 2 and main.status_label.text.contains("状态已变化"), "确认过期快照仍拆除")
	main._request_removal()
	main._confirm_removal()
	_check(main.world.buildings.size() == 1 and main.world.resources["wood"] == 120 and main.inspected_building_id.is_empty(), "确认取消未释放工地或更新详情")
	main.world.paused = true
	main._save()
	main._load()
	_check(main.world.retired_buildings.size() == 1 and not main.town_map.occupied_cells.has(Vector2i(2, 2)), "界面读档复活已移除工地")
	main.free()
	DirAccess.remove_absolute(path + "-ui.db")
	if not failed:
		print("REMOVAL_PASS: refund, rounding, replay, rebuild, staffing, capacity, history, migration, confirmation, UI")
	quit(1 if failed else 0)

