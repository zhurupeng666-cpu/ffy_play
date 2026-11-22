## 文件用途：定义区域地理位置、初始可见性、进入条件和双向道路。
extends Resource

# 配置模块：区域坐标是总览比例坐标，道路的两个端点使用稳定区域 ID。
@export var home_id: String
@export var regions: Dictionary
@export var roads: Array[PackedStringArray]
# 侦察参数：费用在出发时结算，耗时以战略秒计算。
@export var scout_food: int = 2
@export var scout_ticks: int = 120
