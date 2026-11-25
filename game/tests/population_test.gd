## 文件用途：验证迁入、出生、儿童成年和领主劳役的分账与存档。
extends SceneTree

const State = preload("res://scripts/world_state.gd")
const Clock = preload("res://scripts/strategic_clock.gd")
const Build = preload("res://scripts/construction_service.gd")
const Removal = preload("res://scripts/removal_service.gd")
const Population = preload("res://scripts/population_service.gd")
const Estate = preload("res://scripts/estate_labor.gd")
const Store = preload("res://scripts/world_save_repository.gd")
var failed: bool = false


# 启动验收：覆盖真实日结和隔离的SQLite读写。
func _initialize() -> void:
	call_deferred("_run")


# 断言收集：失败时汇报并给构建返回非零结果。
func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


# 人口验收：先迁入再结算新增人口口粮，儿童到期才增加劳动力。
func _check_families(store: RefCounted) -> void:
	var world: RefCounted = State.new()
	_check(not Population.growth_block(world, 3).is_empty(), "住房满仍具备迁入资格")
	world.resources["food"] = 1000
	var house: Dictionary = Build.execute(world, "b_house", Vector2i(2, 2), "family-house")
	_check(house["ok"], "人口测试住宅建造失败")
	world.paused = false
	Clock.new(world).advance(2 * State.DAY_TICKS)
	_check(world.housing_capacity() == 40 and world.population == 30, "人口在检查日前增长")
	_check(Population.growth_block(world, 3).contains("满意度"), "满意度不足未拦截移民")
	world.satisfaction = 60
	var saved_food: int = world.resources["food"]
	world.resources["food"] = 48
	_check(Population.growth_block(world, 3).contains("51"), "居民增员未按入住后计算口粮储备")
	world.resources["food"] = saved_food
	Clock.new(world).advance(State.DAY_TICKS)
	_check(world.current_day() == 4 and world.population == 33 and world.dependents == 7 and world.workforce_capacity() == 26, "移民家庭增量错误")
	_check(world.last_food_ledger["needed"] == 15 and world.households[-1]["children"] == [16], "迁入档日结归属或移民儿童成年日有误")
	Clock.new(world).advance(3 * State.DAY_TICKS)
	_check(world.current_day() == 7 and world.population == 37 and world.dependents == 9 and world.last_food_ledger["needed"] == 17, "出生或第二户移民未正确计数")
	var has_birth: bool = false
	for family: Dictionary in world.households:
		has_birth = has_birth or family["children"].has(25)
	_check(has_birth and world.population_report["born"] == 1, "新生儿童成年计划丢失")
	_check(store.save_world(world), "增长当日无法保存")
	var loaded: RefCounted = store.load_world()
	_check(loaded != null and loaded.snapshot() == world.snapshot(), "增长当天历史粮食、税收或家庭无法恢复")
	if loaded == null:
		return
	var bad: Dictionary = loaded.snapshot()
	bad["households"][0]["children"] = [loaded.current_day()]
	_check(State.from_snapshot(bad) == null, "接受已到期仍标为儿童的坏档")
	var before: Dictionary = loaded.snapshot()
	loaded.settle_days()
	_check(loaded.snapshot() == before, "读档重复出生或迁入")
	Clock.new(loaded).advance(8 * State.DAY_TICKS)
	var before_adult: int = loaded.workforce_capacity()
	var old_pop: int = loaded.population
	Clock.new(loaded).advance(State.DAY_TICKS)
	_check(loaded.current_day() == 16 and loaded.population == old_pop and loaded.workforce_capacity() == before_adult + 1 and loaded.population_report["matured"] == 1, "移民儿童未按期成年或成年时重复增加人口")
	Clock.new(loaded).advance(8 * State.DAY_TICKS)
	before_adult = loaded.workforce_capacity()
	Clock.new(loaded).advance(State.DAY_TICKS)
	_check(loaded.current_day() == 25 and loaded.workforce_capacity() == before_adult + 1, "出生儿童没有转为劳动力")


# 劳役验收：购买不改变居民与军需，半粮跨档，并在拆除后返还到独立池。
func _check_estate(store: RefCounted) -> void:
	var world: RefCounted = State.new()
	var idle: int = world.idle_workers()
	var gold: int = world.resources["gold"]
	_check(Estate.purchase(world) and world.resources["gold"] == gold - Estate.PRICE, "购买未准确扣金币")
	_check(world.population == 30 and world.dependents == 6 and world.idle_workers() == idle and world.estate_idle() == 1, "领主劳役错误并入居民")
	world.paused = false
	Clock.new(world).advance(State.DAY_TICKS)
	_check(world.resources["food"] == 165 and world.estate_food_remainder == 1, "半份口粮未结转")
	_check(store.save_world(world), "半份口粮存档失败")
	world = store.load_world()
	if world == null:
		_check(false, "半份口粮读档失败")
		return
	Clock.new(world).advance(State.DAY_TICKS)
	_check(world.resources["food"] == 149 and world.estate_food_remainder == 0 and world.last_food_ledger["needed"] == 15 and world.estate_food_report["paid"] == 1, "两日劳役扣粮不是1或混入居民")
	_check(world.assign_builders(1) and world.assign_estate_builders(1) and world.builders == 2 and world.estate_idle() == 0, "独立施工未使用共用槽位")
	_check(not world.assign_estate_builders(1) and world.assign_estate_builders(-1), "领主施工越过上限或无法调回")
	var farm: Dictionary = Build.execute(world, "b_farm", Vector2i(2, 4), "estate-farm")
	Clock.new(world).advance(2 * State.DAY_TICKS)
	var id: String = farm["building_id"]
	idle = world.idle_workers()
	_check(world.assign_estate_producers(id, 1) and world.idle_workers() == idle and world.estate_idle() == 0, "领主生产挤占了居民岗位")
	_check(not world.assign_producers(id, 0) and not world.assign_estate_producers(id, 1), "居民按钮误撤领主岗位或领主人手超配")
	_check(store.save_world(world) and store.load_world() != null, "独立分配无法读档")
	_check(Removal.execute(world, id, "estate-demolish")["ok"] and world.estate_idle() == 1 and world.estate_posts.is_empty(), "拆除后未释放领主岗位")
	var legacy: Dictionary = State.new().snapshot()
	legacy["version"] = 24
	for field: String in ["households", "population_report", "estate"]:
		legacy.erase(field)
	var migrated: RefCounted = State.from_snapshot(legacy)
	_check(migrated != null and migrated.households.size() == 12 and migrated.estate_workers == 0, "旧档迁移未补家庭或误发领主劳役")


# 测试入口：完成两组对账并关闭临时数据库。
func _run() -> void:
	var path: String = ProjectSettings.globalize_path("res://local_data/tests/population_%s.db" % Time.get_ticks_usec())
	var store: RefCounted = Store.new()
	if not store.open_store(path):
		quit(1)
		return
	_check_families(store)
	_check_estate(store)
	store.close_store()
	DirAccess.remove_absolute(path)
	if not failed:
		print("POPULATION_PASS: families, immigration, births, adulthood, isolated labor, rations, save migration")
	quit(1 if failed else 0)
