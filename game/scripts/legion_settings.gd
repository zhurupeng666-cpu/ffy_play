## 文件用途：定义军团编制容量与原型数量限制，数值均为待平衡参数。
extends Resource
# 编制模块：成员可按整数人数分配，同一兵员在不同军团的合计不能超过部队人数。
@export var people_capacity: int = 20
@export var active_limit: int = 8
@export var history_limit: int = 512
