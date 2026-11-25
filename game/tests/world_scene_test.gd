## 文件用途：在隔离数据库上验证战略面板加载、暂停按钮与保存读取后的界面同步。
extends SceneTree
const Army = preload("res://scripts/army_service.gd")
const Disband = preload("res://scripts/army_disband_service.gd")
const Build = preload("res://scripts/construction_service.gd")
const Legions = preload("res://scripts/legion_service.gd")
const Battle = preload("res://scripts/woods_battle.gd")
const Siege = preload("res://scripts/fort_siege.gd")
const March = preload("res://scripts/region_march.gd")
const Scout = preload("res://scripts/region_scout.gd")
const State = preload("res://scripts/world_state.gd")


# 启动模块：等待场景树可添加节点后开始界面回归。
func _initialize() -> void:
	call_deferred("_run")


# 验收模块：测试世界引用和界面显示均恢复，失败不影响用户存档。
func _run() -> void:
	var scene: PackedScene = load("res://scenes/world_prototype.tscn")
	var main: Control = scene.instantiate()
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/world_ui_%s.db" % Time.get_ticks_usec())
	main.store_path_override = path
	root.add_child(main)
	var hud_safe: bool = _check_hud(main)
	# 隔离模块：地图选择不应更改权威世界状态。
	var before_map: Dictionary = main.world.snapshot()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.town_map.world_to_screen(Vector2(0, 256))
	main.town_map._gui_input(click)
	var map_safe: bool = before_map == main.world.snapshot() and main.map_info.tooltip_text.contains("(8,8)")
	# 区域验收：切换会清理未确认施工，关闭视图或尝试进入锁定区域不会写世界。
	var city_zoom: float = main.town_map.zoom_level
	main._start_preview(load("res://data/buildings/house.tres"))
	main.region_toggle.pressed.emit()
	var overview: Control = main.region_overview
	overview.scout_shortcut.pressed.emit()
	var scout_entry_visible: bool = overview.scout_button.is_visible_in_tree() and overview.scout_button.disabled
	scout_entry_visible = scout_entry_visible and overview.detail.text.contains("现役士兵")
	scout_entry_visible = scout_entry_visible and overview.scout_row.get_index() < overview.board.get_index()
	overview.enter_button.pressed.emit()
	var region_safe: bool = scout_entry_visible and overview.visible and not main.town_view.visible \
		and main.town_map.active_definition == null and overview.enter_button.disabled \
		and not overview.markers.has("r_fort") and before_map == main.world.snapshot()
	overview.markers["r_home"].pressed.emit()
	overview.enter_button.pressed.emit()
	region_safe = region_safe and main.town_view.visible and not overview.visible \
		and main.town_map.zoom_level == city_zoom and before_map == main.world.snapshot()
	main._toggle_pause()
	main.clock.advance(120.0)
	main._toggle_pause()
	main._save()
	var first_save: Dictionary = main.store.list_saves()[0]
	var stamp_safe: bool = main.save_stamp.text == "最近存档 · 保存于 %s" % first_save["saved_local"]
	main.world.resources["gold"] = 999
	main._save()
	main._choose_save()
	var latest: Dictionary = main.store.list_saves()[0]
	var chooser: bool = main.save_items.item_count == 1 and main.save_items.get_item_text(0).contains("第2日")
	chooser = chooser and main.save_items.get_item_text(0).contains("保存于 %s" % latest["saved_local"])
	main.world.resources["gold"] = 0
	main._activate_save(0)
	stamp_safe = stamp_safe and main.save_stamp.text == "当前读档 · 保存于 %s" % latest["saved_local"]
	chooser = chooser and main.world.resources["gold"] == 999 and latest["id"] != first_save["id"]
	var delete_safe: bool = _check_save_deletion(main, int(latest["id"]))
	main.world.resources["gold"] = 320
	main._refresh()
	var passed: bool = hud_safe and stamp_safe and chooser and delete_safe and region_safe and map_safe and main.world.current_day() == 2 and main.world.resources["food"] == 165 and main.world.resources["gold"] == 320 and main.world.paused and main.numbers["gold"].text == "320"
	passed = _check_scout(main) and passed
	main.free()
	DirAccess.remove_absolute(path)
	if not passed:
		push_error("战略界面保存读取联动失败")
	else:
		print("WORLD_UI_PASS: scene, regions, scouting, march, battle, territory yield, fort siege, fort gold, pause, timed save, load, categorized HUD, resource display")
	quit(0 if passed else 1)


# 删除验收：首次点击和取消都保留存档，确认后只移除磁盘记录。
func _check_save_deletion(main: Control, save_id: int) -> bool:
	main._choose_save()
	main.save_delete_button.pressed.emit()
	if main.pending_save_delete != save_id or main.store.list_saves().size() != 1:
		return false
	main.save_delete_dialog.hide()
	main._cancel_save_delete()
	if main.pending_save_delete != 0 or main.store.list_saves().size() != 1:
		return false
	main._choose_save()
	main.save_delete_button.pressed.emit()
	main.save_delete_dialog.hide()
	main.save_delete_dialog.confirmed.emit()
	return main.store.list_saves().is_empty() and main.save_stamp.text == "暂无存档" and main.world.resources["gold"] == 999


# 布局验收：分类菜单进入真实建造预览，管理抽屉可按页切换并收起。
func _check_hud(main: Control) -> bool:
	if main.management_drawer.visible or not main.build_toolbar.visible or main.save_stamp.text != "暂无存档":
		return false
	for key: String in ["population", "food", "gold", "wood", "stone", "date"]:
		var value: Label = main.numbers[key]
		var icon: TextureRect = value.get_parent().get_parent().get_child(0)
		if icon.texture == null or value.text.is_empty():
			return false
	main._show_data_section(2, main.ledger_sections)
	if not main.ledger_sections[2].visible or main.ledger_sections[0].visible:
		return false
	main._show_data_section(0, main.ledger_sections)
	main._open_management(2, true)
	if not main.management_drawer.visible or main.management_tabs.get_tab_title(main.management_tabs.current_tab) != "军团":
		return false
	main._open_management(2, true)
	if main.management_drawer.visible:
		return false
	var farming_menu: MenuButton = main.build_toolbar.get_child(1)
	farming_menu.get_popup().id_pressed.emit(0)
	var valid: bool = main.town_map.active_definition != null and main.cancel_build_button.visible
	main._cancel_preview()
	return valid and main.town_map.active_definition == null and not main.cancel_build_button.visible


# 侦察验收：真实界面派遣，检查扣费、兵员锁定、跨读档计时和揭示。
func _check_scout(main: Control) -> bool:
	Build.execute(main.world, "b_barracks", Vector2i(2, 4), "scout-camp")
	main.world.paused = false
	main.clock.advance(80)
	var recruitment: Dictionary = Army.recruit(main.world, "building_000002", "scout-troop")
	if not recruitment["ok"]:
		return false
	main.clock.advance(60)
	main.world.paused = true
	var id: String = Legions.create(main.world, "scout-legion")["legion_id"]
	var troop: String = recruitment["troop_id"]
	Legions.set_count(main.world, id, troop, 2)
	main.region_toggle.pressed.emit()
	var overview: Control = main.region_overview
	overview.markers[Scout.WOODS].pressed.emit()
	var food: int = main.world.resources["food"]
	main.world.resources["food"] = 1
	overview.sync(main.world)
	overview.scout_button.pressed.emit()
	if not overview.scout_button.disabled or not main.world.woods_scout.is_empty() or main.world.resources["food"] != 1:
		return false
	main.world.resources["food"] = food
	overview.sync(main.world)
	overview.scout_button.pressed.emit()
	overview.scout_button.pressed.emit()
	if main.world.resources["food"] != food - 2 or not Scout.busy(main.world, id) or overview.scout_button.text != "侦察进行中":
		return false
	if Legions.set_count(main.world, id, troop, 0)["ok"] or Legions.dissolve(main.world, id)["ok"] or Disband.quote(main.world, troop)["ok"]:
		return false
	main.clock.advance(120)
	if not Scout.busy(main.world) or overview.markers.has(Scout.FORT):
		return false
	main._save()
	main._load()
	if not Scout.busy(main.world) or main.world.resources["food"] != food - 2:
		return false
	main.world.paused = false
	main.clock.advance(119)
	overview.sync(main.world)
	if overview.markers.has(Scout.FORT) or not overview.detail.text.contains("1 战略秒"):
		return false
	main.clock.advance(1)
	main.world.paused = true
	overview.sync(main.world)
	if not Scout.complete(main.world) or not overview.markers.has(Scout.FORT) or overview.scout_button.text != "侦察已完成" or not Disband.quote(main.world, troop)["ok"]:
		return false
	if not _check_march(main, id, troop):
		return false
	var legacy: Dictionary = main.world.snapshot()
	if not _check_battle(main, id, troop):
		return false
	Legions.dissolve(main.world, id)
	main._save()
	main._load()
	if not Scout.complete(main.world) or not overview.markers.has(Scout.FORT):
		return false
	legacy["version"] = 13
	legacy.erase("woods_scout")
	var migrated: RefCounted = State.from_snapshot(legacy)
	return migrated != null and migrated.woods_scout.is_empty()


# 行军验收：用真实面板往返，验证途中存档、驻地、锁定、旧档迁移与返回解锁。
func _check_march(main: Control, legion_id: String, troop_id: String) -> bool:
	var overview: Control = main.region_overview
	if not overview.march_button.is_visible_in_tree() or overview.march_button.disabled:
		return false
	if March.dispatch(main.world, legion_id, Scout.FORT):
		return false
	var food: int = main.world.resources["food"]
	overview.march_button.pressed.emit()
	overview.march_button.pressed.emit()
	if March.remaining(main.world, legion_id) != 120 or main.world.resources["food"] != food:
		return false
	if Legions.set_count(main.world, legion_id, troop_id, 0)["ok"] or Disband.quote(main.world, troop_id)["ok"]:
		return false
	main.world.paused = false
	main.clock.advance(60)
	main.world.paused = true
	main._save()
	main._load()
	if March.remaining(main.world, legion_id) != 60 or not overview.detail.text.contains("剩余 60"):
		return false
	var legacy: Dictionary = main.world.snapshot()
	legacy["version"] = 14
	legacy.erase("legion_trips")
	var migrated: RefCounted = State.from_snapshot(legacy)
	if migrated == null or not migrated.legion_trips.is_empty() or not Scout.complete(migrated):
		return false
	main.world.paused = false
	main.clock.advance(60)
	main.world.paused = true
	overview.sync(main.world)
	if not March.away(main.world, legion_id) or overview.march_button.text != "调回边境镇":
		return false
	if Legions.dissolve(main.world, legion_id)["ok"]:
		return false
	main._save()
	main._load()
	if not overview.detail.text.contains("驻地为北部林地"):
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	return main.world.legion_trips.is_empty() and Disband.quote(main.world, troop_id)["ok"] \
		and overview.march_button.text == "前往北部林地"


# 遭遇验收：验证出战位置、失利、战中读档、胜利归属和回城后的战果。
func _check_battle(main: Control, legion_id: String, troop_id: String) -> bool:
	var overview: Control = main.region_overview
	if Battle.start(main.world, legion_id) or not overview.battle_button.disabled:
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	overview.battle_button.pressed.emit()
	if not Battle.busy(main.world, legion_id) or not overview.march_button.disabled:
		return false
	main.world.paused = false
	main.clock.advance(160)
	main.world.paused = true
	overview.sync(main.world)
	if Battle.report(main.world)["status"] != "defeat" or March.dispatch(main.world, legion_id, Scout.FORT):
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	var reinforcement: Dictionary = Army.recruit(main.world, "building_000002", "woods-reinforcement")
	if not reinforcement["ok"]:
		return false
	main.clock.advance(60)
	main.world.paused = true
	if not Legions.set_count(main.world, legion_id, troop_id, 5)["ok"]:
		return false
	if not Legions.set_count(main.world, legion_id, reinforcement["troop_id"], 5)["ok"]:
		return false
	overview.sync(main.world)
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	# 把胜利对局放在日初附近，以便分别核对占领日和首个完整日。
	main.clock.advance(120 - main.world.tick % 120 + 5)
	main.world.paused = true
	overview.sync(main.world)
	var wood_before: int = main.world.resources["wood"]
	overview.battle_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(8)
	main.world.paused = true
	var battle_before: Dictionary = Battle.report(main.world)
	if battle_before["status"] != "running" or battle_before["allies"] >= 100:
		return false
	main._save()
	main._load()
	if Battle.report(main.world) != battle_before:
		return false
	main.world.paused = false
	for _second: int in range(90):
		if Battle.report(main.world)["status"] != "running":
			break
		main.clock.advance(1)
	main.world.paused = true
	overview.sync(main.world)
	if Battle.report(main.world)["status"] != "victory" or not overview.detail.text.contains("己方控制"):
		return false
	if main.world.resources["wood"] != wood_before:
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120 - main.world.tick % 120)
	if main.world.resources["wood"] != wood_before or main.world.last_material_ledger.has("woods_wood"):
		return false
	main.clock.advance(120)
	main.world.paused = true
	main._refresh()
	var bill: Dictionary = main.world.last_material_ledger
	if main.world.resources["wood"] != wood_before + 5 or bill.get("woods_wood") != 5:
		return false
	if not main.numbers["woods_wood"].text == "5" or not main.world.legion_trips.is_empty():
		return false
	main._save()
	main._load()
	main.world.settle_days()
	if main.world.last_material_ledger != bill or main.world.resources["wood"] != wood_before + 5:
		return false
	var invalid: Dictionary = main.world.snapshot()
	invalid["last_material_ledger"]["woods_wood"] = 6
	if State.from_snapshot(invalid) != null:
		return false
	main.world.resources["wood"] = 999999998
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	bill = main.world.last_material_ledger
	if bill.get("woods_wood") != 5 or bill["wood"]["stored"] != 2 or bill["wood"]["overflow"] != 3:
		return false
	return _check_fort_route(main, legion_id)


# 旧堡验收：在真实区域界面检查中转、旧版迁移、途中存读档和返程。
func _check_fort_route(main: Control, legion_id: String) -> bool:
	var overview: Control = main.region_overview
	overview.markers[Scout.FORT].pressed.emit()
	if not overview.march_button.disabled or March.dispatch(main.world, legion_id, Scout.FORT):
		return false
	overview.markers[Scout.WOODS].pressed.emit()
	overview.march_button.pressed.emit()
	var legacy: Dictionary = main.world.snapshot()
	legacy["version"] = 17
	legacy["legion_trips"][legion_id].erase("origin")
	var migrated: RefCounted = State.from_snapshot(legacy)
	if migrated == null or migrated.legion_trips[legion_id]["origin"] != Scout.LAYOUT.home_id:
		return false
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.markers[Scout.FORT].pressed.emit()
	if overview.march_button.disabled or overview.march_button.text != "前往旧堡":
		return false
	overview.march_button.pressed.emit()
	var invalid: Dictionary = main.world.snapshot()
	invalid["legion_trips"][legion_id]["origin"] = Scout.LAYOUT.home_id
	if State.from_snapshot(invalid) != null:
		return false
	main.world.paused = false
	main.clock.advance(60)
	main.world.paused = true
	main._save()
	main._load()
	if March.remaining(main.world, legion_id) != 60 or not overview.detail.text.contains("剩余 60"):
		return false
	main.world.paused = false
	main.clock.advance(60)
	main.world.paused = true
	overview.sync(main.world)
	if not overview.detail.text.contains("抵达堡外") or overview.march_button.text != "返回北部林地":
		return false
	if March.dispatch(main.world, legion_id, Scout.LAYOUT.home_id) or not _check_siege(main, legion_id):
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.markers[Scout.WOODS].pressed.emit()
	if not overview.detail.text.contains("驻地为北部林地"):
		return false
	overview.march_button.pressed.emit()
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	overview.sync(main.world)
	main._save()
	main._load()
	return main.world.legion_trips.is_empty() and Siege.report(main.world)["status"] == "victory"


# 攻城验收：校验城门承伤顺序、途中锁定、战斗恢复和胜利标记。
func _check_siege(main: Control, legion_id: String) -> bool:
	var overview: Control = main.region_overview
	if overview.battle_button.disabled or not overview.battle_button.is_visible_in_tree():
		return false
	# 将攻城放在日初，区分胜利当日账单及首个完整的控制日。
	main.world.paused = false
	main.clock.advance(120 - main.world.tick % 120 + 5)
	main.world.paused = true
	overview.sync(main.world)
	overview.battle_button.pressed.emit()
	if not Siege.busy(main.world, legion_id) or March.dispatch(main.world, legion_id, Scout.WOODS):
		return false
	main.world.paused = false
	main.clock.advance(4)
	main.world.paused = true
	var report: Dictionary = Siege.report(main.world)
	if report["gate"] >= Siege.LAYOUT.fort_gate_power or report["enemies"] != Siege.LAYOUT.fort_guards * 10:
		return false
	main._save()
	main._load()
	if Siege.report(main.world) != report or not overview.detail.text.contains("攻击城门"):
		return false
	main.world.paused = false
	for _second: int in range(90):
		if Siege.report(main.world)["status"] != "running":
			break
		main.clock.advance(1)
	main.world.paused = true
	overview.sync(main.world)
	if Siege.report(main.world)["status"] != "victory" or not overview.markers[Scout.FORT].text.contains("己方控制"):
		return false
	return _check_fort_gold(main) and not overview.march_button.disabled


# 收益验收：核对首日延迟、与军饷衔接、溢出及读档后不重复计费。
func _check_fort_gold(main: Control) -> bool:
	main.world.paused = false
	main.clock.advance(120 - main.world.tick % 120)
	if main.world.last_civic_ledger.has("fort_gold"):
		return false
	var legacy: Dictionary = main.world.snapshot()
	legacy["version"] = 19
	var migrated: RefCounted = State.from_snapshot(legacy)
	if migrated == null or Siege.report(migrated)["status"] != "victory":
		return false
	main.clock.advance(120)
	main.world.paused = true
	main._refresh()
	var bill: Dictionary = main.world.last_civic_ledger
	var source: Dictionary = bill.get("fort_gold", {})
	if source != {"income": 5, "stored": 5, "overflow": 0} or not main.numbers["fort_gold"].text == "+5":
		return false
	var before_wages: int = int(bill["gold_before"]) + int(bill["tax_stored"]) + 5
	var wages: Dictionary = main.world.last_army_ledger
	if wages["gold_before"] != before_wages or main.world.resources["gold"] != before_wages - int(wages["wage_paid"]):
		return false
	main._save()
	main._load()
	main.world.settle_days()
	if main.world.last_civic_ledger != bill or main.world.resources["gold"] != before_wages - int(wages["wage_paid"]):
		return false
	var invalid: Dictionary = main.world.snapshot()
	invalid["last_civic_ledger"]["fort_gold"]["overflow"] = 5
	if State.from_snapshot(invalid) != null:
		return false
	main.world.resources["gold"] = 1000000000
	main.world.paused = false
	main.clock.advance(120)
	main.world.paused = true
	return main.world.last_civic_ledger["fort_gold"] == {"income": 5, "stored": 0, "overflow": 5}
