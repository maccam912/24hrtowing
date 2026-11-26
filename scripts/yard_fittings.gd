extends "res://scripts/county_sites.gd"
## The office hose still serves walk-in orders. The bulk-tank nozzle lets
## Brandt meter a partial fill on the storage side of the yard.
const NOZZLE := Vector3(-10.6,1.23,-79.6)
const COFFEE := Vector3(-29.6,1.16,-41.2)

func assemble(dispenser: bool, brewer: bool) -> void:
	if dispenser:
		_metered_hose()
	if brewer:
		_coffee_shelf()

func _metered_hose() -> void:
	origin = Vector3(NOZZLE.x,0,NOZZLE.z)
	b(0,.73,0,1.02,1.46,.54,"oxide",true)
	b(0,1.65,0,1.12,.49,.58,"cream")
	b(0,1.69,.31,.80,.22,.04,"dark")
	placard(Vector3(0,1.22,.29),"DIESEL",.90,.23,0,"green")
	label(Vector3(0,1.69,.34),"TOTAL SALE",.095,0,Color("#e4dabf"))
	beam(Vector3(.42,.94,.22),Vector3(.77,.24,.36),.093,.093,"black")
	beam(Vector3(.77,.24,.36),Vector3(1.01,.16,.51),.094,.094,"black")
	beam(Vector3(1.01,.16,.51),Vector3(1.17,.34,.59),.094,.094,"black")
	beam(Vector3(1.17,.34,.59),Vector3(.68,1.16,.32),.088,.088,"black")
	beam(Vector3(.67,1.15,.31),Vector3(.46,1.36,.30),.135,.115,"green")
	beam(Vector3(.46,1.36,.30),Vector3(.37,1.28,.11),.047,.047,"silver")
	beam(Vector3(0,.54,-.26),Vector3(.14,.51,-1.37),.09,.09,"post")
	for side: float in [-1.0,1.0]:
		cyl(side*1.48,.50,.05,.14,1.0,"oxide")
		cyl(side*1.48,.77,.05,.148,.12,"white")

func _coffee_shelf() -> void:
	origin = Vector3(COFFEE.x,0,COFFEE.z)
	b(0,.91,0,2.22,.12,.78,"wood",true)
	for x: float in [-.9,.9]:
		for z: float in [-.27,.27]:
			b(x,.43,z,.09,.86,.09,"post")
	b(0,1.01,0,.70,.10,.52,"dark")
	b(0,1.31,.18,.69,.55,.17,"silver")
	b(0,1.61,0,.72,.17,.51,"dark")
	cyl(0,1.20,-.08,.40,.26,"black")
	cyl(0,1.34,-.08,.31,.06,"cream")
	beam(Vector3(.19,1.28,-.08),Vector3(.28,1.22,-.08),.045,.045,"oxide")
	beam(Vector3(.28,1.22,-.08),Vector3(.20,1.10,-.08),.045,.045,"oxide")
	for i in range(4):
		cyl(.58,1.04+i*.031,-.06,.15,.15,"cream")
	placard(Vector3(.02,.76,-.42),"SHOP COFFEE",1.49,.25,PI,"green")

const WEST_LOT := Rect2(-99,-86,38,52)
const WEST_STALLS := 12

static func west_stall(i: int) -> Vector3:
	return Vector3(-93+(i%6)*5.0,0,-80 if i < 6 else -44)

func west_fence(expanded: bool) -> void:
	origin = Vector3.ZERO
	if not expanded:
		fence(Vector3(-61,0,-72),Vector3(-61,0,-57),2.3,true,true)
		return
	var nw := Vector3(WEST_LOT.position.x,0,WEST_LOT.position.y)
	var sw := Vector3(nw.x,0,WEST_LOT.end.y)
	var ne := Vector3(WEST_LOT.end.x,0,nw.z)
	var se := Vector3(ne.x,0,sw.z)
	fence(nw,sw,2.3,true,true)
	fence(nw,ne,2.3,true,true)
	fence(sw,se,2.3,true,true)
	var pavement := Vector3.UP*.025
	draw.quad(nw+pavement,ne+pavement,se+pavement,sw+pavement,"pavement")
	for i in WEST_STALLS:
		var at := west_stall(i)
		var side := -1 if i < 6 else 1
		b(at.x,.12,at.z+side*3.6,2.1,.19,.33,"cream")
		b(at.x-2.45,.037,at.z,.11,.02,7.2,"stripe")
		b(at.x,.8,at.z+side*4.35,.11,1.6,.13,"wood")
		placard(at+Vector3(0,1.5,side*4.35),"W-%02d" % (i+1),1.35,.32,0 if side < 0 else PI,"green")
	for post_z: float in [-72.,-57.]:
		cyl(-61,1.18,post_z,.25,2.36,"oxide",true)
		cyl(-61,1.79,post_z,.26,.26,"white")
	placard(Vector3(-61,2.5,-55),"WEST STORAGE",3.7,.65,PI*.5,"black",true)
