## 文件用途：定义建筑静态配置，供预览与后续建造共用，不保存玩家实例状态。
extends Resource

# 配置模块：尺寸为逻辑格数量，费用是后续建造使用的待平衡参数。
@export var id: String = ""
@export var display_name: String = ""
@export var footprint: Vector2i = Vector2i.ONE
@export var cost: Dictionary = {}
@export var buildable: bool = true
