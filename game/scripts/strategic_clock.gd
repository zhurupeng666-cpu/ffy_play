## 文件用途：按固定一秒逻辑步推进战略时间，支持暂停及倍速，避免卡顿跳过日结。
extends RefCounted

# 引用模块：时钟只持有权威世界状态，不维护另一份日期或资源。
var state: RefCounted


# 初始化模块：绑定新世界或经过校验的读档对象。
func _init(world: RefCounted) -> void:
	state = world


# 推进模块：每120个逻辑秒完成一日，倍速影响积累速度而不改变结算公式。
func advance(real_seconds: float) -> void:
	if state.paused or not is_finite(real_seconds) or real_seconds < 0:
		return
	state.subsecond += real_seconds * state.speed
	while state.subsecond >= 1.0:
		state.subsecond -= 1.0
		state.tick += 1
		state.advance_construction()
		state.settle_days()
