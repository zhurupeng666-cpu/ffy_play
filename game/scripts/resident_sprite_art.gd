## 文件用途：按职业构造统一的等距像素人物，缓存步态、朝向及作业姿态。
extends RefCounted

const SIZE := Vector2i(60,58)
const FEET := Vector2(29,54)
const INK := Color("#352820")
const SKIN := Color("#dca478")
const SHADE := Color("#aa7054")
const LIGHT := Color("#efc296")
const HAIR := Color("#483226")
const WOOD := Color("#806046")
const GOLD := Color("#d8aa62")
const IRON := Color("#838b8d")
const ROLES: Array[String] = ["refugee","farmer","logger","mason","fisher","server","hawker","smith","healer","scholar",
	"merchant","performer","gentry","constable","magistrate","militia","guard","archer","rider","bandit",
	"builder","herder","buyer","child"]
# 职业配置：服色、帽型、随身物及衣袍轮廓组成独立造型。
const COSTUMES := {
	"refugee":["#84735c","rag","stick",false], "farmer":["#b3966d","straw","hoe",false],
	"logger":["#8b6d55","wrap","logs",false], "mason":["#877364","wrap","pick",false],
	"fisher":["#466779","straw","net",false], "server":["#867364","bun","tray",false],
	"hawker":["#99805f","wrap","pole",false], "smith":["#956c52","wrap","hammer",false],
	"healer":["#5b7f64","square","herbs",true], "scholar":["#7093aa","soft","fan",true],
	"merchant":["#8d565c","round","abacus",true], "performer":["#b86d7e","ornate","lute",true],
	"gentry":["#946352","round","cane",true], "constable":["#554c50","soft","saber",true],
	"magistrate":["#a05143","official","scroll",true], "militia":["#96806b","wrap","spear",false],
	"guard":["#a65447","helmet","shield",false], "archer":["#766046","hood","bow",false],
	"rider":["#825956","helmet","spear",false], "bandit":["#8e674e","rag","torch",false],
	"builder":["#9b7750","wrap","mallet",false], "herder":["#7e8262","straw","staff",false],
	"buyer":["#7c8b69","bun","basket",true], "child":["#b18068","bun","none",false],
}
static var frames: Dictionary = {}


# 帧入口：服装和装备按姿态、方向缓存，地图滚动时复用贴图。
static func texture(role: String, frame: int, flipped: bool = false, working: bool = false) -> ImageTexture:
	var kind: String = role if COSTUMES.has(role) else "buyer"
	var phase: int = posmod(frame,6)
	var key: String = "%s/%d/%d/%d" % [kind,phase,int(flipped),int(working)]
	if frames.has(key):
		return frames[key]
	var image := Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	var kit: Array = COSTUMES[kind]
	var cloth := Color(kit[0])
	var child: bool = kind=="child"
	var stride: int = 0 if working else [-4,-2,2,4,2,-2][phase]
	var bob: int = int(not working and phase in [1,4])
	var base := Vector2i(0,3 if child else 0)+Vector2i(0,bob)
	if kind=="rider":
		_horse(image)
		base+=Vector2i(0,-8)
		stride=0
	var item: String = kit[2]
	_equipment_back(image,item if not working or item not in ["hoe","pick"] else "none",base)
	_body(image,kind,kit[3],cloth,base,stride)
	_face(image,kind,base)
	_headwear(image,kit[1],base,cloth)
	var hand := Vector2i(39+stride/2,39+base.y+(-3 if working and phase%2==1 else 0))
	_equipment_front(image,item,hand,working)
	if flipped:
		image.flip_x()
	var result: ImageTexture = ImageTexture.create_from_image(image)
	frames[key]=result
	return result


# 地图投影：所有人物以鞋底为锚点，朝向变化时锚点保持一致。
static func draw(canvas: Control, foot: Vector2, role: String, frame: int, facing: float, working: bool = false) -> void:
	var flipped: bool = facing<0.0
	var sprite: ImageTexture = texture(role,frame,flipped,working)
	var scale: float = 0.88 if role=="child" else 1.06
	var pivot := Vector2(SIZE.x-1-FEET.x if flipped else FEET.x,FEET.y)
	var start: Vector2 = canvas.art_point(foot-pivot*scale)
	var finish: Vector2 = canvas.art_point(foot+(Vector2(SIZE)-pivot)*scale)
	var ground: Vector2 = canvas.art_point(foot)
	var shadow: Vector2 = Vector2(12.0,3.0)*canvas.art_zoom()
	canvas.art_canvas.draw_rect(Rect2(ground-shadow,shadow*2.0),Color("#30282062"))
	canvas.art_canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.art_canvas.draw_texture_rect(sprite,Rect2(start,finish-start),false)


# 衣身：裤腿交替落脚，交领、腰带和衬边保持独立颜色，甲片单独叠加。
static func _body(img: Image, role: String, robe: bool, cloth: Color, off: Vector2i, stride: int) -> void:
	var y: int = off.y
	var hem: int = 48 if robe else 43
	for leg: int in [-1,1]:
		var x: int = 27+leg*5+leg*stride
		var toe_y: int = 51+mini(1,leg*stride)+mini(0,y)
		var pants: Color = cloth.darkened(0.42 if leg<0 else 0.25)
		_poly(img,[[x-3,hem+y-1],[x+4,hem+y],[x+5,toe_y],[x-4,toe_y]],pants)
		_rect(img,x-4,toe_y,10,3,INK)
		_rect(img,x-2,toe_y,6,1,Color("#7c6250"))
		_rect(img,x-3,toe_y-3,7,2,Color("#be9b75") if role in ["militia","farmer","logger","mason"] else pants.lightened(0.15))
	var bottom: int = hem+y
	_poly(img,[[23,27+y],[33,27+y],[39,32+y],[37,42+y],[40 if robe else 35,bottom],[19,bottom],[21,39+y],[18,32+y]],cloth)
	_poly(img,[[31,30+y],[36,32+y],[35,42+y],[38 if robe else 34,bottom-2],[29,bottom-2]],cloth.darkened(0.24),false)
	_line(img,Vector2i(23,29+y),Vector2i(30,34+y),cloth.lightened(0.45),2)
	_line(img,Vector2i(33,29+y),Vector2i(24,40+y),Color("#cfb18a"),2)
	_line(img,Vector2i(23,41+y),Vector2i(35,40+y),Color("#584334"),3)
	_rect(img,28,39+y,4,3,GOLD)
	if role in ["server","smith","builder"]:
		_poly(img,[[23,34+y],[32,34+y],[34,45+y],[22,45+y]],Color("#79573f"))
		_line(img,Vector2i(24,36+y),Vector2i(24,42+y),Color("#ba9471"))
	if role in ["guard","archer","rider","militia"]:
		var plate: Color = IRON if role in ["guard","rider"] else Color("#9c7a5a")
		for row: int in range(3):
			for column: int in range(4):
				_rect(img,22+column*3+row%2,32+y+row*3,3,2,plate.lightened(0.14*float(column%2)))
		_line(img,Vector2i(21,42+y),Vector2i(35,42+y),INK,2)
	if role=="performer":
		_line(img,Vector2i(20,34+y),Vector2i(11,31+y),Color("#8abaad"),3)
		_line(img,Vector2i(11,31+y),Vector2i(10,42+y),Color("#8abaad"),3)
		_line(img,Vector2i(10,42+y),Vector2i(16,48+y),Color("#b7cbac"),3)
		_line(img,Vector2i(18,46+y),Vector2i(35,45+y),Color("#ceb9a6"),2)
	elif role in ["gentry","magistrate"]:
		_line(img,Vector2i(33,32+y),Vector2i(35,46+y),GOLD,2)
		_line(img,Vector2i(22,46+y),Vector2i(35,46+y),Color("#bf8757"),2)
	if robe:
		_line(img,Vector2i(24,43+y),Vector2i(24,bottom-2),cloth.lightened(0.21))
		_line(img,Vector2i(22,bottom-2),Vector2i(35,bottom-2),cloth.lightened(0.25))
	_poly(img,[[21,31+y],[17,33+y],[16-stride/2,40+y],[21-stride/2,42+y],[24,35+y]],cloth.darkened(0.15))
	_rect(img,16-stride/2,39+y,4,4,SKIN)
	_poly(img,[[33,31+y],[37,30+y],[40+stride/2,37+y],[37+stride/2,40+y],[32,36+y]],cloth.lightened(0.12))
	_rect(img,37+stride/2,37+y,4,4,SKIN)


# 面部：大头短身、鬓角、眉眼和脸颊高光提供参考图的剪影比例。
static func _face(img: Image, role: String, off: Vector2i) -> void:
	var y: int = off.y
	_poly(img,[[22,14+y],[31,13+y],[37,17+y],[37,24+y],[34,28+y],[24,28+y],[20,24+y],[19,18+y]],SKIN)
	_poly(img,[[21,17+y],[24,15+y],[24,26+y],[21,24+y]],SHADE,false)
	_rect(img,26,17+y,8,3,LIGHT)
	_rect(img,31,22+y,5,3,SKIN.lightened(0.13))
	_rect(img,24,20+y,3,1,HAIR)
	_rect(img,31,19+y,4,1,HAIR)
	_rect(img,26,21+y,2,2,INK)
	_rect(img,33,21+y,2,2,INK)
	_rect(img,29,24+y,3,1,SHADE)
	_line(img,Vector2i(21,17+y),Vector2i(22,22+y),HAIR,2)
	if role in ["refugee","farmer","logger","mason","fisher","smith","gentry","magistrate","guard","bandit"]:
		_line(img,Vector2i(25,25+y),Vector2i(33,26+y),HAIR,2)
		_rect(img,28,26+y,4,2,HAIR)
	else:
		_rect(img,28,25+y,4,1,Color("#a46253"))


# 帽饰：草编斗笠、软帽、乌纱和盔缨使用不同轮廓与局部纹理。
static func _headwear(img: Image, hat: String, off: Vector2i, cloth: Color) -> void:
	var y: int = off.y
	match hat:
		"straw":
			_poly(img,[[13,16+y],[19,12+y],[24,6+y],[30,5+y],[36,7+y],[41,13+y],[45,16+y],[38,19+y],[18,19+y]],Color("#bc9451"))
			_poly(img,[[19,14+y],[26,8+y],[31,7+y],[36,10+y],[40,14+y],[30,16+y]],Color("#e2bb72"),false)
			_line(img,Vector2i(18,15+y),Vector2i(39,16+y),Color("#967544"),2)
			_line(img,Vector2i(24,10+y),Vector2i(34,11+y),Color("#f0cc81"))
		"helmet":
			_poly(img,[[18,19+y],[18,13+y],[22,8+y],[27,7+y],[32,8+y],[37,13+y],[38,20+y],[34,24+y],[33,17+y],[24,17+y],[22,24+y]],IRON)
			_line(img,Vector2i(23,13+y),Vector2i(32,11+y),IRON.lightened(0.35),2)
			_poly(img,[[26,8+y],[24,5+y],[26,2+y],[31,2+y],[39,7+y],[33,8+y],[31,5+y]],Color("#a64d41"))
		"official","soft","square","round":
			var cap: Color = Color("#48525a")
			if hat=="round":
				cap=cloth.darkened(0.45)
			elif hat=="square":
				cap=Color("#514c40")
			if hat=="official":
				_rect(img,13,14+y,31,5,INK)
			_poly(img,[[18,17+y],[20,10+y],[24,7+y],[33,7+y],[36,10+y],[37,17+y]],cap)
			_line(img,Vector2i(22,11+y),Vector2i(33,10+y),cap.lightened(0.35),2)
			_line(img,Vector2i(21,16+y),Vector2i(35,16+y),INK,2)
			if hat in ["official","round"]:
				_rect(img,27,12+y,4,2,GOLD)
			elif hat=="square":
				_rect(img,21,8+y,14,2,cap.lightened(0.19))
			else:
				_line(img,Vector2i(36,13+y),Vector2i(42,23+y),cap.darkened(0.19),2)
		"hood":
			_poly(img,[[18,16+y],[19,11+y],[26,7+y],[33,9+y],[39,15+y],[37,19+y],[32,15+y],[22,18+y]],Color("#826647"))
			_line(img,Vector2i(21,13+y),Vector2i(34,11+y),Color("#bd9b69"),2)
		_:
			_poly(img,[[18,18+y],[18,13+y],[21,10+y],[23,7+y],[27,10+y],[33,8+y],[37,12+y],[38,17+y],[31,14+y],[24,16+y]],HAIR)
			_line(img,Vector2i(21,12+y),Vector2i(28,11+y),Color("#78604b"),2)
			if hat in ["wrap","bun","ornate"]:
				_line(img,Vector2i(18,15+y),Vector2i(35,13+y),Color("#c0ad92"),2)
			if hat in ["bun","ornate"]:
				_poly(img,[[23,10+y],[22,6+y],[26,3+y],[31,5+y],[31,10+y]],HAIR)
			if hat=="ornate":
				_rect(img,22,8+y,4,3,GOLD)
				_rect(img,34,9+y,4,3,Color("#dce3a5"))


# 背负道具：肩扛农具、双筐扁担和木捆在人物之后成形。
static func _equipment_back(img: Image, item: String, off: Vector2i) -> void:
	var y: int = off.y
	if item in ["hoe","pick","logs","pole"]:
		_line(img,Vector2i(8,29+y),Vector2i(51,16+y),INK,4)
		_line(img,Vector2i(8,28+y),Vector2i(50,16+y),WOOD.lightened(0.25),2)
	if item=="logs":
		for i: int in range(4):
			_rect(img,12+i*2,22+y+i*4,14,4,WOOD.darkened(0.12))
			_rect(img,12+i*2,23+y+i*4,3,2,Color("#c29b6b"))
		_line(img,Vector2i(17,23+y),Vector2i(22,40+y),GOLD,2)
	if item=="hoe":
		_poly(img,[[47,15+y],[53,17+y],[54,27+y],[47,26+y]],IRON)
	if item=="pick":
		_poly(img,[[43,8+y],[48,9+y],[53,15+y],[55,24+y],[50,17+y],[47,14+y]],IRON)
	if item=="pole":
		for x: int in [10,49]:
			_line(img,Vector2i(x,26+y if x<20 else 17+y),Vector2i(x-4,40+y),WOOD)
			_line(img,Vector2i(x,26+y if x<20 else 17+y),Vector2i(x+4,40+y),WOOD)
			_basket(img,Vector2i(x,40+y))


# 手持道具：按职业绘制可辨识的工作物件，并随手部姿态变化。
static func _equipment_front(img: Image, item: String, hand: Vector2i, working: bool) -> void:
	var x: int = hand.x
	var y: int = hand.y
	match item:
		"stick","cane","staff","spear","saber","torch":
			var top: Vector2i = hand+Vector2i(5,-22 if item!="saber" else -26)
			_line(img,hand+Vector2i(-3,13),top,INK,3)
			_line(img,hand+Vector2i(-3,13),top,IRON if item=="saber" else WOOD.lightened(0.22),1)
			if item=="spear":
				_poly(img,[[top.x-3,top.y+2],[top.x+1,top.y-9],[top.x+4,top.y+3]],IRON.lightened(0.32))
			elif item=="torch":
				_poly(img,[[top.x-4,top.y+2],[top.x-6,top.y-3],[top.x+1,top.y-12],[top.x+5,top.y-4],[top.x+3,top.y+2]],Color("#d68048"))
				_rect(img,top.x-1,top.y-4,4,5,Color("#efbd63"))
		"net":
			_poly(img,[[x,y-4],[x+7,y],[x+14,y+11],[x-1,y+13]],Color("#aa9a79"))
			for line: int in range(3):
				_line(img,hand+Vector2i(line*3,0),hand+Vector2i(line*4,11),Color("#e0cba5"))
			_basket(img,Vector2i(x-8,y+8))
		"basket":
			_basket(img,hand+Vector2i(4,4))
		"hoe","pick":
			if working:
				var blade: Vector2i = hand+Vector2i(11,11)
				_line(img,hand+Vector2i(-9,-8),blade,WOOD.lightened(0.18),3)
				if item=="pick":
					_line(img,blade+Vector2i(-4,-4),blade+Vector2i(6,3),INK,3)
					_line(img,blade+Vector2i(-3,-4),blade+Vector2i(6,2),IRON.lightened(0.24),2)
				else:
					_poly(img,[[blade.x-4,blade.y],[blade.x+6,blade.y-4],[blade.x+6,blade.y+1],[blade.x-2,blade.y+5]],IRON)
		"logs":
			if working:
				_line(img,hand+Vector2i(-4,10),hand+Vector2i(5,-11),WOOD,3)
				_poly(img,[[x+1,y-12],[x+10,y-13],[x+12,y-7],[x+7,y-5]],IRON)
		"hammer","mallet":
			var end: Vector2i = hand+Vector2i(5,-15 if working else -10)
			_line(img,hand+Vector2i(-2,4),end,WOOD,3)
			_poly(img,[[end.x-5,end.y-3],[end.x+3,end.y-5],[end.x+7,end.y+1],[end.x-3,end.y+4]],IRON if item=="hammer" else WOOD.lightened(0.21))
		"shield":
			_line(img,Vector2i(17,y+5),Vector2i(8,y-14),INK,4)
			_line(img,Vector2i(17,y+4),Vector2i(8,y-14),IRON.lightened(0.48),2)
			_poly(img,[[x-3,y-7],[x+5,y-10],[x+12,y-4],[x+10,y+7],[x+3,y+11],[x-3,y+5]],Color("#876449"))
			_line(img,Vector2i(x+4,y-7),Vector2i(x+4,y+7),Color("#bca681"),2)
			_rect(img,x+3,y-1,5,4,IRON)
		"bow":
			_line(img,hand+Vector2i(6,-15),hand+Vector2i(6,13),Color("#c5ae87"))
			_line(img,hand+Vector2i(6,-15),hand+Vector2i(13,-4),WOOD,2)
			_line(img,hand+Vector2i(13,-4),hand+Vector2i(13,4),WOOD,2)
			_line(img,hand+Vector2i(13,4),hand+Vector2i(6,13),WOOD,2)
			_line(img,hand+Vector2i(-7,-2),hand+Vector2i(16,-2),IRON)
		"tray","scroll","abacus","fan","herbs","lute":
			_small_prop(img,item,hand)


# 小型道具：茶碗、算盘、折扇、药草、文书和琵琶具有各自线条。
static func _small_prop(img: Image, item: String, hand: Vector2i) -> void:
	var x: int = hand.x
	var y: int = hand.y
	match item:
		"tray":
			_rect(img,x-1,y+1,17,3,WOOD)
			_rect(img,x+4,y-5,8,6,Color("#839b9c"))
			_rect(img,x+6,y-6,4,2,Color("#b5cecc"))
		"scroll","abacus":
			_rect(img,x-11,y-3,17,10,INK)
			_rect(img,x-10,y-2,15,8,Color("#d7bb84") if item=="scroll" else WOOD)
			for i: int in range(5):
				_rect(img,x-8+i*3,y,1,4,INK)
		"fan":
			_poly(img,[[x-7,y-8],[x+1,y-10],[x+10,y-7],[x+2,y+3]],Color("#e2cfaa"))
			for i: int in range(4):
				_line(img,hand+Vector2i(2,2),hand+Vector2i(-5+4*i,-6),WOOD)
		"herbs":
			_line(img,hand+Vector2i(0,3),hand+Vector2i(6,-9),Color("#7e9565"),2)
			_rect(img,x+2,y-7,7,3,Color("#a3af77"))
			_basket(img,hand+Vector2i(-8,4))
		"lute":
			_poly(img,[[x-12,y+7],[x-16,y+3],[x-13,y-3],[x-5,y-4],[x+7,y-14],[x+10,y-12],[x,y],[x-3,y+6]],Color("#b28a56"))
			_line(img,hand+Vector2i(-11,3),hand+Vector2i(8,-12),Color("#ebcf98"))


# 筐和坐骑：编织边线与坐骑的腿、鬃尾和鞍具使用统一明暗层级。
static func _basket(img: Image, at: Vector2i) -> void:
	_poly(img,[[at.x-5,at.y],[at.x+6,at.y],[at.x+4,at.y+7],[at.x-3,at.y+7]],Color("#ad854e"))
	_line(img,at+Vector2i(-4,2),at+Vector2i(5,2),GOLD)
	_line(img,at+Vector2i(-3,5),at+Vector2i(4,5),Color("#805d40"))


# 骑兵坐骑：人物单独锚在鞍上，马脚与步兵使用相同地面基准。
static func _horse(img: Image) -> void:
	for x: int in [18,24,37,43]:
		_line(img,Vector2i(x,43),Vector2i(x-2,53),HAIR,4)
	_poly(img,[[13,38],[22,35],[36,36],[42,31],[44,25],[49,26],[54,34],[51,39],[46,37],[43,46],[18,46]],Color("#956748"))
	_line(img,Vector2i(16,39),Vector2i(10,48),HAIR,3)
	_line(img,Vector2i(23,37),Vector2i(36,39),Color("#bd8a57"),3)
	_rect(img,47,30,2,2,INK)


# 像素原语：有界矩形、离散线段和扫描线多边形保持清晰硬边。
static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x,y,w,h).intersection(Rect2i(Vector2i.ZERO,SIZE)),color)


# 线段使用离散像素步，适用于器具和衣褶细线。
static func _line(img: Image, a: Vector2i, b: Vector2i, color: Color, width: int = 1) -> void:
	var steps: int = maxi(1,maxi(absi(a.x-b.x),absi(a.y-b.y)))
	for i: int in range(steps+1):
		var p := Vector2i(Vector2(a).lerp(Vector2(b),float(i)/steps).round())
		_rect(img,p.x-width/2,p.y-width/2,width,width,color)


# 多边形逐行填充并按需加墨边，模型不依赖外置背景。
static func _poly(img: Image, points: Array, color: Color, outline: bool = true) -> void:
	var low: int = SIZE.y
	var high: int = 0
	for p: Array in points:
		low=mini(low,p[1])
		high=maxi(high,p[1])
	for y: int in range(low,high):
		var cuts: Array[float] = []
		for index: int in range(points.size()):
			var p: Array = points[index]
			var q: Array = points[(index+1)%points.size()]
			if (p[1]>y)==(q[1]>y):
				continue
			cuts.append(lerpf(p[0],q[0],float(y-p[1])/float(q[1]-p[1])))
		cuts.sort()
		for i: int in range(0,cuts.size()-1,2):
			var start: int = ceili(cuts[i])
			_rect(img,start,y,maxi(1,floori(cuts[i+1])-start+1),1,color)
	if outline:
		for i: int in range(points.size()):
			var p: Array = points[i]
			var q: Array = points[(i+1)%points.size()]
			_line(img,Vector2i(p[0],p[1]),Vector2i(q[0],q[1]),INK)
