## 文件用途：提供等距格网的坐标投影、反选和边界判断，不依赖画面节点。
extends RefCounted

# 格网参数模块：300×300城镇，菱形格尺寸为64×32逻辑像素。
const SIZE: Vector2i = Vector2i(300, 300)
const STARTER_SIZE: Vector2i = Vector2i(16, 16)
const HALF: Vector2 = Vector2(32.0, 16.0)
const INVALID: Vector2i = Vector2i(-1, -1)


# 投影模块：将逻辑格中心转换为等距世界坐标。
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)


# 反选模块：反解格坐标，边界采用向正方向归属的固定规则。
static func world_to_cell(point: Vector2) -> Vector2i:
	var x: float = (point.x / HALF.x + point.y / HALF.y) * 0.5
	var y: float = (point.y / HALF.y - point.x / HALF.x) * 0.5
	return Vector2i(floori(x + 0.5), floori(y + 0.5))


# 边界模块：禁止选择地图外的坐标。
static func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


# 中心模块：返回地图几何中心，便于镜头复位与窗口适配。
static func center() -> Vector2:
	return cell_to_world(Vector2i(SIZE.x - 1, SIZE.y - 1)) * 0.5
