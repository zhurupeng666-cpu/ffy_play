## 文件用途：验证日期边界、倍速、暂停、卡顿追赶、资源日结与跨连接快照。
extends SceneTree

const State = preload("res://scripts/world_state.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Store = preload("res://scripts/world_save_repository.gd")
var failed: bool = false


# 启动模块：执行独立领域测试，不使用玩家实际存档。
func _initialize() -> void:
	call_deferred("_run")


# 断言模块：记录所有失败并在结束时返回非零退出码。
func _check(condition: bool, reason: String) -> void:
	if not condition:
		failed = true
		push_error(reason)


# 规则验收模块：边界和日结必须独立于渲染帧率与倍速。
func _run() -> void:
	var real: RefCounted = State.new()
	var real_clock: RefCounted = Clock.new(real)
	real.paused = false
	real_clock.advance_real(1799.0)
	_check(real.current_day()==1 and real.tick==119,"一倍速未满半小时提前结算")
	real_clock.advance_real(1.0)
	_check(real.current_day()==2 and real.last_settled_day==1,"一倍速半小时未进入下一天")
	real.speed=4
	real_clock.advance_real(450.0)
	_check(real.current_day()==3,"四倍速未按七分半钟结算")
	var state: RefCounted = State.new()
	var clock: RefCounted = Clock.new(state)
	clock.advance(120.0)
	_check(state.tick == 0, "暂停期间推进了日期")
	state.paused = false
	clock.advance(119.5)
	_check(state.current_day() == 1 and state.resources["food"] == 180, "午夜前提前结算")
	clock.advance(0.5)
	_check(state.current_day() == 2 and state.resources["food"] == 165 and state.resources["gold"] == 320, "首日日结不正确")
	state.settle_days()
	_check(state.resources["food"] == 165, "同一天重复扣粮")
	state.speed = 4
	clock.advance(30.0)
	_check(state.current_day() == 3 and state.resources["food"] == 150 and state.resources["gold"] == 340, "4倍速日结公式改变")
	clock.advance(60.0)
	_check(state.current_day() == 5 and state.last_settled_day == 4, "卡顿追赶跳过日结")
	state.resources["food"] = 2
	state.speed = 1
	clock.advance(120.0)
	_check(state.resources["food"] == 0 and state.last_bill.contains("缺粮"), "缺粮出现负库存或无提示")
	var invalid: Dictionary = state.snapshot()
	invalid["last_settled_day"] = 0
	_check(State.from_snapshot(invalid) == null, "接受了可能重复日结的坏档")
	invalid = state.snapshot()
	invalid["resources"]["gold"] = -1
	_check(State.from_snapshot(invalid) == null, "接受负库存存档")
	# 持久化模块：保存午夜前一秒，重开后只结算一次。
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/world_%s.db" % Time.get_ticks_usec())
	var repository: RefCounted = Store.new()
	state = State.new()
	state.paused = false
	clock = Clock.new(state)
	clock.advance(119.25)
	_check(repository.open_store(path) and repository.save_world(state), "保存世界失败")
	repository.close_store()
	repository = Store.new()
	_check(repository.open_store(path), "重新打开世界库失败")
	var loaded: RefCounted = repository.load_world()
	_check(loaded != null, "读取快照失败")
	if loaded != null:
		_check(loaded.tick == 119 and is_equal_approx(loaded.subsecond, 0.25), "未恢复亚秒精度")
		clock = Clock.new(loaded)
		clock.advance(0.75)
		_check(loaded.current_day() == 2 and loaded.resources["food"] == 165, "读档后重复或漏日结")
		# 损坏模块：坏JSON必须被拒绝，已在内存中的进度保持不变。
		repository.database.query("UPDATE world_saves SET payload='broken';")
		_check(repository.load_world() == null and loaded.resources["food"] == 165, "坏档破坏当前世界")
	repository.close_store()
	DirAccess.remove_absolute(path)
	if not failed:
		print("STRATEGIC_PASS: pause, boundary, speed, catchup, daily ledger, snapshot, corrupt guard")
	quit(1 if failed else 0)
