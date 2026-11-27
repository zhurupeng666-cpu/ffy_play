## 文件用途：按固定一秒逻辑步推进战略时间，支持暂停及倍速，避免卡顿跳过日结。
extends RefCounted
const REAL_SECONDS_PER_DAY: float = 1800.0
const March = preload("res://scripts/region_march.gd")
const Woods = preload("res://scripts/woods_battle.gd")
const Fortress = preload("res://scripts/fort_siege.gd")
const Army = preload("res://scripts/army_service.gd")

# 引用模块：时钟只持有权威世界状态，不维护另一份日期或资源。
var state: RefCounted


# 初始化模块：绑定新世界或经过校验的读档对象。
func _init(world: RefCounted) -> void:
	state = world


# 实时入口：一倍速三十分钟一天，已有存档、军粮和工程继续使用原有逻辑步。
func advance_real(real_seconds: float) -> void:
	advance(real_seconds * state.DAY_TICKS / REAL_SECONDS_PER_DAY)


# 固定步入口：战役、施工和日结共享逻辑秒，供模拟与测试精确推进。
func advance(logical_seconds: float) -> void:
	if state.paused or not is_finite(logical_seconds) or logical_seconds < 0:
		return
	state.subsecond += logical_seconds * state.speed
	while state.subsecond >= 1.0:
		state.subsecond -= 1.0
		state.tick += 1
		March.advance(state)
		if state.capital_layout:
			_report_combat()
		Army.advance(state)
		state.advance_production()
		state.advance_construction()
		state.settle_days()


# 军报模块：仅在战况刚结束时上报，重读档案和后续时钟步不会重复记录。
func _report_combat() -> void:
	for item: Array in [[Woods,state.woods_battle,"北部林地"],[Fortress,state.fort_siege,"旧堡"]]:
		if item[1].is_empty():
			continue
		var previous: Dictionary = item[0].report(state,state.tick-1)
		var latest: Dictionary = item[0].report(state,state.tick)
		if previous["status"]=="running" and latest["status"] in ["victory","defeat"]:
			state.post_report("军务","战事结束","%s战报：%s，剩余友军 %d。" % [item[2],"胜利" if latest["status"]=="victory" else "战败",latest["allies"]])
