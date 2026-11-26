extends RefCounted

const Kit := preload("res://scripts/rig_mesh.gd")
const VARIANT := 6
const DRIVER := 5
const LIMIT_SECONDS := 120.0
const PREMIUM := 24.0
const PAINT := Color("#e0dfcc")
const GREEN := Color("#395749")
const UNITS := [
	{"plate":"WI CO 412","vin":"2FALP71W5TX164412","person":"Deputy Pelz","reply":"pelz_pull"},
	{"plate":"WI CO 426","vin":"2FALP71W7TX182426","person":"Deputy Ruiz","reply":"ruiz_pull"},
]

static func clock(seconds: float) -> String:
	var elapsed := ceili(maxf(0.0,seconds))
	return "%d:%02d" % [floori(elapsed/60.0),elapsed%60]

static func fit(car: Node3D, g, width: float, base: float, roof: float, plate: String) -> void:
	car.set_meta("patrol",true)
	var metal := Color("#4b5150")
	# Low steel pushbar and a pillar-mounted spotlight on the driver's side.
	for side:float in [-1,1]:
		var x := side*width
		g.box(Vector3(side*.39,base+.23,-2.21),Vector3(.072,.54,.078),metal)
		g.box(Vector3(x*1.012,base+.26,.12),Vector3(.033,.245,2.38),GREEN)
		Kit.label(car,"SHERIFF",Vector3(x*1.042,base+.26,-.04),.161,PAINT,Vector3(0,side*PI/2,0))
		Kit.label(car,plate.right(3),Vector3(x*1.017,base+.27,1.61),.091,GREEN,Vector3(0,side*PI/2,0))
	g.box(Vector3(0,base+.30,-2.24),Vector3(.88,.073,.06),metal)
	g.beam(Vector3(-.82,base+.68,-.90),Vector3(-.99,base+.88,-1.02),.042,.042,metal)
	g.tube(Vector3(-.99,base+.89,-.98),Vector3(-.99,base+.89,-1.10),.093,metal,10)
	g.tube(Vector3(-.99,base+.89,-1.10),Vector3(-.99,base+.89,-1.11),.082,PAINT,10)
	g.box(Vector3(0,roof+.17,-.06),Vector3(1.38,.08,.31),metal)
	g.box(Vector3(-.38,roof+.27,-.06),Vector3(.52,.14,.28),Color("#ad4247"))
	g.box(Vector3(.38,roof+.27,-.06),Vector3(.52,.14,.28),Color("#486392"))
	g.box(Vector3(0,roof+.25,-.06),Vector3(.22,.09,.25),Color("#a9acac"))
	g.beam(Vector3(.69,base+.44,1.76),Vector3(.70,base+1.43,1.84),.022,.022,metal)

static func add_patrol_lights(g, height: float) -> void:
	for z:float in [-.204,.084]:
		g.box(Vector3(-.38,height+1.43,z),Vector3(.43,.112,.021),Color("#e4584c"),Vector3.ZERO,"lamp")
		g.box(Vector3(.38,height+1.43,z),Vector3(.43,.112,.021),Color("#688eca"),Vector3.ZERO,"lamp")
