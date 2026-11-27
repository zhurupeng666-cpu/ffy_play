## 文件用途：在原占地内绘制施工工序、材料和在岗工人，供动态层低频更新。
extends RefCounted

const Art = preload("res://scripts/town_art.gd")
const Pedestrian = preload("res://scripts/capital_pedestrian_art.gd")
const Catalog = preload("res://scripts/building_catalog.gd")
const Grid = Art.Grid


# 工序模块：农田、道路和建筑共用进度，按各自材料切换可见阶段。
static func phase(record: Dictionary) -> String:
	var step: int = _step(record)
	match record["def_id"]:
		"b_farm": return ["清地放线","翻土整畦","分垄播种"][step]
		"b_road": return ["清理路基","铺设基层","铺石整平"][step]
		"b_wall","b_gate": return ["场地放线","垒砌台基","砌墙装门"][step]
		_: return ["放线备料","立柱搭架","围护上瓦"][step]


# 选段模块：用真实工时划分三段，达到边界时才显示下一道工序。
static func _step(record: Dictionary) -> int:
	return mini(2,floori(3.0*record["work_done"]/maxi(1,record["work_required"])))


# 地块模块：大用地随工程展开，田垄、路石或脚手架分别表达工程性质。
static func draw(canvas: Control, record: Dictionary, crew: int, time: float) -> void:
	canvas.art_scale=1.0
	var cell := Vector2i(record["cell"][0],record["cell"][1])
	var span: Vector2i = Catalog.footprint(record)
	var polygon: PackedVector2Array = canvas._footprint_outline(cell,span,true)
	var rear: Vector2 = polygon[0].lerp(polygon[2],0.22)
	var front: Vector2 = polygon[0].lerp(polygon[2],0.77)
	var step: int = _step(record)
	var ground_job: bool = record["def_id"] in ["b_farm","b_road"]
	if ground_job:
		_ground(canvas,polygon,step,record["def_id"]=="b_road")
	else:
		_frame(canvas,polygon,step)
	var stock: Vector2 = rear.lerp(polygon[3],0.30)
	Art._crate(canvas,stock,Color("#a9774a"))
	Art._crate(canvas,stock+Vector2(14,6),Color("#ba986c"))
	for peg: Vector2 in polygon:
		var point: Vector2 = peg.lerp((rear+front)*0.5,0.09)
		Art._stroke(canvas,point,Vector2.ZERO,Vector2(0,-17),Color("#6d503a"),3)
		Art._stroke(canvas,point,Vector2(0,-15),Vector2(7,-12),Color("#d2aa69"),3)
	for worker: int in range(crew):
		var labor: float = fposmod(time*0.5+worker*0.25,2.0)
		var delivery: bool = labor<1.5
		var position: Vector2 = stock.lerp(front,clampf(labor,0.0,1.0)) if delivery else front.lerp(stock,(labor-1.5)*2.0)
		var busy: bool = labor>=1.0 and labor<1.5
		position+=Vector2(worker*15,worker*7)
		Pedestrian.draw(canvas,position,0,floori(time*8.0)%6,signf(front.x-stock.x)*(1.0 if delivery else -1.0),busy)
		if busy:
			var swing: float = sin(time*8.0+worker)
			Art._stroke(canvas,position,Vector2(10,-17),Vector2(22,-9+8*swing),Color("#ae7f4c"),3)
			Art._pixel(canvas,position,Vector2(22,-11+8*swing),Vector2(6,3),Color("#c0b5a1"))


# 整地模块：按逐行施工范围显示刨开的土、基层或已经整齐铺好的面层。
static func _ground(canvas: Control, corners: PackedVector2Array, step: int, road: bool) -> void:
	var line_count: int = [2,5,8][step]
	for row: int in range(line_count):
		var u: float = (row+0.7)/9.0
		var start: Vector2 = corners[0].lerp(corners[3],u)
		var finish: Vector2 = corners[1].lerp(corners[2],u)
		var shade: Color = Color("#bdac89") if road else Color("#6f5037")
		Art._stroke(canvas,Vector2.ZERO,start.lerp(finish,0.08),finish.lerp(start,0.08),shade,8.0 if road else 4.5)
		if step==2:
			for i: int in range(2,8):
				var at: Vector2 = start.lerp(finish,i/9.0)
				Art._pixel(canvas,at,Vector2(-3,-2),Vector2(6,3),Color("#e0cba4") if road else Color("#a7aa64"))


# 搭架模块：以基石、支柱斜撑和局部屋面表达前、中、后施工状态。
static func _frame(canvas: Control, corners: PackedVector2Array, step: int) -> void:
	var center: Vector2 = (corners[0]+corners[2])*0.5
	var rails: PackedVector2Array = []
	for point: Vector2 in corners:
		rails.append(point.lerp(center,0.31))
	var lift: float = [0.0,32.0,56.0][step]
	for i: int in range(4):
		var a: Vector2 = rails[i]
		var b: Vector2 = rails[(i+1)%4]
		Art._stroke(canvas,Vector2.ZERO,a,b,Color("#b1a08c"),6)
		if step>=1:
			var top := Vector2(0,-lift)
			Art._stroke(canvas,a,Vector2.ZERO,top,Color("#825b3d"),4.8)
			Art._stroke(canvas,Vector2.ZERO,a+top,b+top,Color("#c08a57"),5)
			Art._stroke(canvas,Vector2.ZERO,a.lerp(b,0.14),a.lerp(b,0.72)+top,Color("#936a45"),3)
	if step==2:
		var roof := Vector2(0,-lift-13.0)
		var ridge: Vector2 = (rails[0]+rails[1])*0.5+roof
		Art._poly(canvas,Vector2.ZERO,[rails[0]+roof,rails[1]+roof,rails[2].lerp(rails[3],0.45)+roof+Vector2(0,13)],Color("#535755"))
		for slat: int in range(5):
			Art._stroke(canvas,Vector2.ZERO,ridge.lerp(rails[0]+roof,slat/5.0),rails[3].lerp(rails[2],slat/10.0)+roof+Vector2(0,13),Color("#78817b"),2)
