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
