## 文件用途：绘制城内行人的步态、服饰、货物和地面投影，近距离可区分身份。
extends RefCounted

const INK := Color("#30282b")
const SKIN := Color("#dca17c")
const SKIN_LIGHT := Color("#f0bd92")
const HAIR := Color("#493431")
const PALETTES: Array[Color] = [
	Color("#bc7949"), Color("#648d68"), Color("#647b93"), Color("#ba6860"), Color("#8a7b56"),
]
static var textures: Dictionary = {}


# 行人模块：姿态、镜像和服装贴图缓存，移动只提交贴图与影子。
static func draw(canvas: Control, foot: Vector2, role: int, step: int, facing: float, waiting: bool) -> void:
	var texture: ImageTexture = _texture(role, step, facing < 0.0, waiting)
	var scale: float = 1.68 if role != 3 else 1.48
	var half_width: float = texture.get_width() * scale * 0.5
	var height: float = texture.get_height() * scale
	var ground: Vector2 = canvas.art_point(foot)
	var shadow_size: Vector2 = Vector2(12, 3) * canvas.zoom_level
	canvas.art_canvas.draw_rect(Rect2(ground - shadow_size, shadow_size * 2.0), Color("#332b2959"))
	var top: Vector2 = canvas.art_point(foot - Vector2(half_width, height))
	var bottom: Vector2 = canvas.art_point(foot + Vector2(half_width, 0))
	canvas.art_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.art_canvas.draw_texture_rect(texture, Rect2(top, bottom - top), false)


# 取帧模块：挑担脚夫、篮客、长衫商旅、孩童和披风护卫具有独立识别物。
static func _texture(role: int, step: int, flipped: bool, waiting: bool) -> ImageTexture:
	var key := Vector4i(role, step, int(flipped), int(waiting))
	if textures.has(key):
		return textures[key]
	var sheet := Image.create(34, 36, false, Image.FORMAT_RGBA8)
	var stride: int = 0 if waiting else [-3, -1, 2, 3, 1, -2][step]
	var lift: int = 0 if waiting else int(step == 1 or step == 4)
	var head: int = 8 + lift + (7 if role == 3 else 0)
	var belt: int = 23 + lift + (4 if role == 3 else 0)
	var cloth: Color = PALETTES[role]
	var hem: int = 29 if role == 2 or role == 4 else belt + 1
	# 交替落脚与深浅裤腿在不同方向仍能辨认。
	_pixel(sheet, 15 + stride, hem - 2, 3, 32 - hem, cloth.darkened(0.45))
	_pixel(sheet, 19 - stride, hem - 2, 3, 33 - hem, cloth.darkened(0.26))
	_pixel(sheet, 14 + stride, 31 + int(stride > 0), 5, 2, INK)
	_pixel(sheet, 18 - stride, 32 - int(stride > 0), 5, 2, INK)
	_pixel(sheet, 12, head + 6, 12, hem - head - 5, INK)
	_pixel(sheet, 13, head + 7, 10, hem - head - 5, cloth)
	_pixel(sheet, 20, head + 8, 3, maxi(3, hem - head - 8), cloth.darkened(0.30))
	_pixel(sheet, 14, head + 8, 3, maxi(2, hem - head - 9), cloth.lightened(0.22))
	if role != 3:
		_pixel(sheet, 13, belt - 2, 10, 2, Color("#6e523f"))
		_pixel(sheet, 19, belt - 2, 2, 1, Color("#d8b475"))
	_pixel(sheet, 14, head + 5, 7, 4, Color("#d6b99b"))
	_pixel(sheet, 14, head - 1, 8, 7, HAIR)
	_pixel(sheet, 16, head, 7, 6, SKIN)
	_pixel(sheet, 17, head + 1, 5, 2, SKIN_LIGHT)
	_pixel(sheet, 22, head + 2, 2, 2, SKIN)
	_pixel(sheet, 20, head + 2, 1, 1, INK)
	_pixel(sheet, 20, head + 5, 2, 1, Color("#915f57"))
	_hat(sheet, role, head)
	var arm: int = 1 if waiting else stride
	_pixel(sheet, 10, head + 9, 5, 4, cloth.darkened(0.25))
	_pixel(sheet, 21, head + 10 + arm, 5, 3, cloth.lightened(0.1))
	_pixel(sheet, 25, head + 11 + arm, 2, 2, SKIN_LIGHT)
	_cargo(sheet, role, head, arm, waiting)
	if flipped:
		sheet.flip_x()
	var result: ImageTexture = ImageTexture.create_from_image(sheet)
	textures[key] = result
	return result


# 服饰模块：斗笠、包巾、方巾、发髻和头盔分别勾勒剪影。
static func _hat(sheet: Image, role: int, head: int) -> void:
	match role:
		0:
			_pixel(sheet, 15, head - 5, 5, 2, Color("#e3bb76"))
			_pixel(sheet, 12, head - 3, 12, 2, Color("#c99153"))
			_pixel(sheet, 10, head - 1, 16, 2, Color("#80593b"))
		1:
			_pixel(sheet, 13, head - 2, 9, 3, Color("#cfad76"))
			_pixel(sheet, 12, head + 1, 3, 6, Color("#a08155"))
		2:
			_pixel(sheet, 14, head - 6, 9, 5, Color("#48505d"))
			_pixel(sheet, 12, head - 2, 13, 2, INK)
		3:
			_pixel(sheet, 16, head - 4, 4, 3, HAIR)
			_pixel(sheet, 13, head - 1, 9, 2, Color("#74494a"))
		4:
			_pixel(sheet, 15, head - 4, 7, 3, Color("#9d9d84"))
			_pixel(sheet, 13, head - 2, 12, 3, Color("#6c7371"))


# 随身物模块：担筐和手篮抖动，旅客停步时把手抬向身前。
static func _cargo(sheet: Image, role: int, head: int, arm: int, waiting: bool) -> void:
	if role == 0:
		var bob: int = floori(arm / 2.0)
		_pixel(sheet, 3, head + 7, 28, 2, Color("#8a6445"))
		_pixel(sheet, 6, head + 8, 1, 5 + bob, Color("#c0a07b"))
		_pixel(sheet, 28, head + 8, 1, 5 - bob, Color("#b89973"))
		_basket(sheet, 3, head + 13 + bob)
		_basket(sheet, 25, head + 13 - bob)
	elif role == 1:
		_basket(sheet, 24, head + 13 + arm)
	elif role == 2:
		_pixel(sheet, 24, head + (9 if waiting else 13), 5, 3, Color("#c6a673"))
		_pixel(sheet, 26, head + (9 if waiting else 13), 1, 3, Color("#7d5a4a"))
	elif role == 4:
		_pixel(sheet, 25, head + 5, 2, 15, Color("#956d50"))
		_pixel(sheet, 25, head + 4, 2, 3, Color("#a9aca5"))


# 器物模块：编筐包含把手、反光边和暗脚。
static func _basket(sheet: Image, x: int, y: int) -> void:
	_pixel(sheet, x + 2, y - 2, 3, 2, Color("#c39a62"))
	_pixel(sheet, x, y, 8, 4, Color("#b48c53"))
	_pixel(sheet, x, y, 8, 1, Color("#e2bf7e"))
	_pixel(sheet, x + 1, y + 3, 6, 2, Color("#82623c"))
	_pixel(sheet, x + 2, y + 1, 1, 2, Color("#dcc391"))
	_pixel(sheet, x + 5, y + 1, 1, 2, Color("#d4a66d"))


# 像素模块：局部着色始终限制在帧内。
static func _pixel(sheet: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	if width > 0 and height > 0:
		sheet.fill_rect(Rect2i(x, y, width, height), color)
