## 文件用途：把步行计划和旧图标验收接到统一的人物模型。
extends RefCounted

const People = preload("res://scripts/resident_sprite_art.gd")
const WALKER_ROLES: Array[String] = ["hawker","buyer","scholar","child","constable"]


# 行人绘制：既有整数身份或新的职业名均使用同一套脚底锚点。
static func draw(canvas: Control, foot: Vector2, role: Variant, step: int, facing: float, waiting: bool) -> void:
	var kind: String = WALKER_ROLES[role] if role is int else str(role)
	People.draw(canvas,foot,kind,step,facing,waiting)


# 帧查询：继续为行走验收提供缓存纹理。
static func _texture(role: int, step: int, flipped: bool, waiting: bool) -> ImageTexture:
	return People.texture(WALKER_ROLES[role],step,flipped,waiting)
