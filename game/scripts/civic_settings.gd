## 文件用途：定义税率和居民满意度的静态平衡参数，不保存玩家动态状态。
extends Resource
# 税收模块：档位对应每人基础税额，满意度按基准60折算征收效率，全部参数待平衡。
@export var tax_rates: Dictionary = {"low": 0.6, "standard": 0.8, "high": 1.2}
@export var policy_deltas: Dictionary = {"low": 2, "standard": 0, "high": -3}
@export var initial_satisfaction: int = 50
@export var satisfaction_limit: int = 100
@export var tax_divisor: float = 60.0
# 恢复模块：正常供粮时低于基准50缓慢恢复，缺粮按缺口比例扣分。
@export var recovery_target: int = 50
@export var recovery_per_day: int = 1
@export var full_shortage_penalty: int = 10
