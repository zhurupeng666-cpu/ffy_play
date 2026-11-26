## 文件用途：以原创像素图绘制城镇角色和牲畜，保存每种着色与姿态的纹理。
extends RefCounted

const PERSON := [
	".....dddd.....", "....dHHhhd....", "...dHHHhhhd...", "..dddddddddd..",
	"....dSsSFd....", "....dSEsFd....", ".....dssd.....", "....dEEd......",
	"...dCCCcd.....", "..dCCaAccd....", "..dCSAaCCd....", "...dCAAcd.....",
	"....dbbd......",
]
const BOOTS := [
	["....dTTdTd....", "...dTTddTdd...", "...ddd..ddd..."],
	["....dTTdTd....", "....dTddTd....", "....ddd.dd...."],
	["....dTTdTdd...", "....dTddTTd...", "...ddd..ddd..."],
]
const COW := [
	"...................dd...", ".................ddHDd..", ".d..dddddddddddd.dDHDd..",
	"d.ddCCHCCCCCCCCddhHEdd..", ".dHHHHCCCHHHCCddhddmd..", "..dHHHCCCHHHCCHhHHHmmd.",
	"..dCCCCHHHHCCChHHHhdd..", "...dcccccchhhcccddd.....", "....dTd..dTddTd.........",
	"....ddd...dddTdd........",
]
const SHEEP := [
	".....ddd.ddd.......", "...ddHHHdHHHd......", "..dHHCCHHHCCHddd...",
	".dHHHCHHHHCHHdHd..", ".dHHCCHCHHHCHdEd..", "..dCCCCHHCChhdmd...",
	"...dhhhccchhddd....", "....dTd...dTd.....", "....ddd...ddd.....",
]
const BASE := {
	"d": "#372c30", "H": "#ffd894", "h": "#ba8658", "S": "#f6bf8b", "s": "#c98667",
	"F": "#65473a", "E": "#493333", "C": "#4f9397", "c": "#396575",
	"a": "#aab9ab", "A": "#e5d3a1", "b": "#78513c", "T": "#664a4c",
	"D": "#ddbd88", "m": "#a86c61",
}
const PALETTES := {
	"farmer": {},
	"fisher": {"C": "#64a6ae", "c": "#3d6a76"},
	"logger": {"C": "#c38e53", "c": "#77523b", "H": "#b8a67b", "h": "#7b6248"},
	"mason": {"C": "#c68169", "c": "#80514a", "H": "#9aafa6", "h": "#687d77"},
	"herder": {"C": "#839755", "c": "#4a6241", "H": "#d6a16f", "h": "#9c684b", "F": "#8b543e"},
	"trainee": {"C": "#c28e56", "c": "#825144", "H": "#ae9a7b", "h": "#785e53", "A": "#ead0a5"},
	"guard": {"C": "#af5752", "c": "#753c45", "H": "#c7d1c8", "h": "#7b8987", "A": "#d6b87b"},
	"cow": {"C": "#b58159", "c": "#976046", "H": "#faf0d6", "h": "#c7ac94"},
	"sheep": {"C": "#eee1c1", "c": "#c6aa91", "H": "#fff4d9", "h": "#d0b19d", "T": "#66504d"},
}
static var textures: Dictionary = {}


# 纹理按角色和步态各生成一次，透明像素保留，移动时只提交贴图。
static func _texture(kind: String, phase: int, flipped: bool) -> ImageTexture:
	var key: String = kind + str(phase) + str(flipped)
	if textures.has(key):
		return textures[key]
	var animal: bool = kind == "cow" or kind == "sheep"
	var rows: Array = (COW if kind == "cow" else SHEEP).duplicate() if animal else PERSON + BOOTS[phase]
	if animal and phase == 1:
		rows[-1] = ".....ddd.ddd"
	var width: int = 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	var colors: Dictionary = BASE.merged(PALETTES[kind], true)
	for y: int in range(rows.size()):
		var line: String = rows[y]
		for x: int in range(line.length()):
			if colors.has(line[x]):
				image.set_pixel(x, y, Color(colors[line[x]]))
	if flipped:
		image.flip_x()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	textures[key] = texture
	return texture


# 投影绘制：以脚下为锚点，镜像只改变面向，人与牛羊共用地图比例。
static func draw(canvas: Control, at: Vector2, kind: String, phase: int, facing: float = 1.0) -> void:
	var texture: ImageTexture = _texture(kind, phase, facing < 0.0)
	var size: Vector2 = texture.get_size() * (1.85 if kind == "sheep" else 2.05)
	var start: Vector2 = canvas.art_point(at - Vector2(size.x * 0.5, size.y - 1))
	var finish: Vector2 = canvas.art_point(at + Vector2(size.x * 0.5, 1))
	canvas.art_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.art_canvas.draw_texture_rect(texture, Rect2(start, finish - start), false)
