## 文件用途：定义兵种分类、招募批次、训练时间和军粮军饷静态参数，不保存动态部队。
extends Resource
# 兵种模块：本版只有基础步兵，其余分类在后续逐步加入。
@export var id: String = "u_infantry"
@export var display_name: String = "民兵步兵"
@export var category: String = "infantry"
@export var batch_size: int = 5
@export var train_work: int = 60
@export var barracks_capacity: int = 10
# 费用模块：招募成本一次支付，军粮军饷按实际服役时间累计，全部参数待平衡。
@export var recruit_cost: Dictionary = {"gold": 50, "wood": 5}
@export var food_per_day: int = 1
@export var wage_per_day: int = 1

# 兵源模块：新招募批次记录来源，服役人口与城镇劳动力通过同一份状态统计。
@export var use_town_workers: bool = true
