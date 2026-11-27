# 数值图标：用原创像素轮廓表示经营指标，纹理在同一次运行中共用。
extends RefCounted

const PIXELS := {
	"idle": ["...xx.....", "...xx.....", "..xxxx....", ".xxxxxx...", ".xxxxxx..x", "...xx...xx", "...xx..xx.", "..xx.xxxx.", "..xx..xx..", ".........."],
	"people": ["..xx..xx..", "..xx..xx..", "..........", ".xxxx.xxxx", "xxxxxx.xxx", "xxxxxx.xxx", "..xx..xx..", "..xx..xx..", "..xx..xx..", ".........."],
	"food": [".......xx.", ".....xx.x.", ".....x.x..", "...xx.xx..", "...x.xx...", "..x.xx....", "..xxx.....", ".xxx......", "xx........", "x........."],
	"gold": ["..xxxxxx..", ".xxxxxxxx.", "xxx....xxx", "xx.xxxx.xx", "xx.xx...xx", "xx...xx.xx", "xx.xxxx.xx", "xxx....xxx", ".xxxxxxxx.", "..xxxxxx.."],
	"wood": ["....xx....", "...xxxx...", "..xxxxxx..", "...xxxx...", "..xxxxxx..", ".xxxxxxxx.", "..xxxxxx..", ".xxxxxxxx.", "....xx....", "....xx...."],
	"stone": ["...xxx....", "..xxxxx...", "..xxxxxx..", ".xxxxxxxx.", "xxxxxx.xxx", "xxxxx..xxx", "xxx...xxxx", "xxxxxxxxxx", ".xxxxxxxx.", ".........."],
	"clock": ["...xxxx...", "..x....x..", ".x..x...x.", "x...x....x", "x...xxx..x", "x........x", "x........x", ".x......x.", "..x....x..", "...xxxx..."],
	"work": ["..xxxx....", ".xxxxxx...", ".x...xxx..", ".....xxxxx", "....xx.xx.", "...xx.....", "..xx......", ".xx.......", "xx........", "x........."],
	"house": ["....xx....", "...xxxx...", "..xxxxxx..", ".xxxxxxxx.", "xxxxxxxxxx", ".xxxxxxxx.", ".xxx..xxx.", ".xxx..xxx.", ".xxx..xxx.", ".xxx..xxx."],
	"happy": ["..xxxxxx..", ".xx....xx.", "xx......xx", "x..x..x..x", "x........x", "x.x....x.x", "x..xxxx..x", "xx......xx", ".xx....xx.", "..xxxxxx.."],
	"shield": ["..xxxxxx..", "xxxxxxxxxx", "xxxx..xxxx", "xxxx..xxxx", "xx......xx", "xxxx..xxxx", ".xxx..xxx.", ".xxxxxxxx.", "..xxxxxx..", "....xx...."],
	"book": ["xxxxxxxxx.", "x.......xx", "x.xxxxx.xx", "x.......xx", "x.xxxxx.xx", "x.......xx", "x.xxxxx.xx", "x.......xx", "xxxxxxxxx.", "..xxxxxxxx"],
	"fish": [".....xx...", "..xxxxxx..", "xxxxxxxx.x", "xxxxxx.xxx", "xxxxxxxx.x", "..xxxxxx..", ".....xx...", "..........", "..........", ".........."],
	"ranch": ["xx......xx", "xxx....xxx", ".xxxxxxxx.", "..xxxxxx..", "..x.xx.x..", "..xxxxxx..", "...xxxx...", "..xx..xx..", "..xxxxxx..", "...xxxx..."],
	"map": ["xxxx......", "x..x......", "x..x......", "xxxx......", "....xx....", ".....xx...", "......xx..", ".......xx.", "........xx", ".........x"],
	"warn": ["....xx....", "....xx....", "...xxxx...", "...x.xx...", "..xx.xx..", "..xx.xx..", ".xxx.xxx.", "xxxx.xxxxx", "xxxxxxxxxx", ".........."],
}
const COLORS := {
	"people": "#b3cfe8", "idle": "#a9ce87", "food": "#e9cb79", "gold": "#f4d274", "wood": "#a9ce87",
	"stone": "#c5cbd4", "clock": "#d0c6b4", "work": "#ddbb91", "house": "#c9bf96",
	"happy": "#a6d9a0", "shield": "#e4a790", "book": "#a9c2d8", "fish": "#96d2d5",
	"ranch": "#d1ac90", "warn": "#f2a780", "map": "#b8c4aa",
}
static var textures: Dictionary = {}


# 纹理缓存：透明像素不参与显示，轮廓在小字号旁仍清楚可辨。
static func texture(id: String) -> ImageTexture:
	if not textures.has(id):
		var bitmap := Image.create(10, 10, false, Image.FORMAT_RGBA8)
		var pixels: Array = PIXELS[id]
		var color := Color(COLORS[id])
		for y: int in range(10):
			for x: int in range(10):
				if x < String(pixels[y]).length() and pixels[y][x] == "x":
					bitmap.set_pixel(x, y, color)
		textures[id] = ImageTexture.create_from_image(bitmap)
	return textures[id]
