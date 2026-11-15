## 文件用途：定义建筑静态配置，供预览与后续建造共用，不保存玩家实例状态。
extends Resource

# 配置模块：尺寸为逻辑格数量，费用是后续建造使用的待平衡参数。
@export var id: String = ""
@export var display_name: String = ""
@export var footprint: Vector2i = Vector2i.ONE
@export var cost: Dictionary = {}
@export var buildable: bool = true

# 施工配置模块：工作量以标准工作份计，两名施工工人每战略秒投入一份。
@export var build_work: int = 40

# 生产配置模块：每人每日粮食量和岗位上限均为待平衡整数，渔场需要临水陆地。
@export var worker_slots: int = 0
@export var food_per_worker_day: int = 0
@export var requires_water: bool = false
