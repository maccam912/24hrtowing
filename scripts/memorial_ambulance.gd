extends RefCounted
## The empty cot goes back through Memorial's night doors after a handoff.
const Addresses := preload("res://scripts/fire_numbers.gd")
const Kit := preload("res://scripts/rig_mesh.gd")
const VARIANT := 9
const DRIVER := 6
const ATTENDANT := 7
const SITE := Vector3(888.2,0,8.8)
const YAW := 1.37
const RETURN_LANE := [Vector3(882,0,3),Vector3(879,0,11),Vector3(873,0,19),Vector3(853,0,19)]
const PLATE := "WI EMS 214"
const VIN := "1FDKE30G5RHA83214"
const TITLE := "Memorial ambulance"
const BODY := Color("#e4decf")
const RED := Color("#a83534")
const GLASS := Color("#445b63")
const METAL := Color("#949e9d")
const TIRE := Color("#292d2c")
const SIZE := Vector3(1.14,1.03,3.25)

static func ticket(completed: int, schedule: float) -> Dictionary:
	var plate := Addresses.number("county_seat")
	return {"id":"memorial_ems","number":1001+completed,"kind":"ditch","site":"county_seat","route":"memorial_emergency",
		"road":"Highway 64","address":plate,"location":"Highway 64 · Memorial east drive (opposite %s)" % plate,"point":SITE,"angle":YAW,"shoulder":"south",
		"variant":VARIANT,"driver_variant":DRIVER,"vehicle":TITLE,"person":"EMT Novak","plate":PLATE,"vin":VIN,
		"running":true,"reply":"ems_handoff","schedule":schedule,"run":"memorial_emergency/south","clearance_seconds":0.0,
		"dispatch":"Memorial ambulance on Highway 64, south shoulder by the hospital’s east drive. The patient is inside. Novak needs a pull. Ask Kit to wheel the empty cot in. County adds $24 for two minutes or less once the crew is clear. Regular rate either way.",
		"directions":"Go east on Highway 64 past County FF and the blue H. The red-and-white Memorial ambulance is beyond the east driveway, on the south shoulder opposite the county offices at %s." % plate}

static func vehicle(parent: Node3D) -> Node3D:
	var van := Kit.joint(parent,Vector3.ZERO,"MemorialAmbulance")
	van.set_meta("body_size",SIZE)
	van.set_meta("plate",PLATE)
	van.set_meta("vin",VIN)
	van.set_meta("driver_door",Vector3(-1.28,0,-1.56))
	van.set_meta("ems",true)
	var g := Kit.new(van)
	g.box(Vector3(0,.65,0),Vector3(1.54,.36,6.09),TIRE)
	g.box(Vector3(0,1.15,-2.55),Vector3(1.89,.75,1.39),BODY)
	g.box(Vector3(0,1.28,-1.52),Vector3(1.98,1.00,1.40),BODY)
	g.box(Vector3(0,1.96,-1.52),Vector3(1.86,.88,1.36),GLASS)
	g.box(Vector3(0,2.42,-1.50),Vector3(1.99,.15,1.49),BODY)
	g.box(Vector3(0,1.93,1.20),Vector3(SIZE.x*2,2.60,4.06),BODY)
	g.box(Vector3(0,3.27,1.20),Vector3(2.32,.12,4.16),Color("#dbe2e5"))
	g.box(Vector3(0,1.14,-3.28),Vector3(1.62,.37,.065),TIRE)
	for slat in 5:
		g.box(Vector3(0,1.00+slat*.064,-3.322),Vector3(1.17,.027,.04),METAL)
	g.box(Vector3(0,.74,-3.31),Vector3(2.01,.18,.19),METAL)
	g.box(Vector3(0,.58,3.29),Vector3(2.19,.14,.32),METAL)
	for side: float in [-1,1]:
		g.box(Vector3(side*1.147,1.66,1.20),Vector3(.024,.33,4.03),RED)
		g.box(Vector3(side*.999,1.46,-1.50),Vector3(.031,.18,1.30),RED)
		g.box(Vector3(side*.934,1.99,-2.17),Vector3(.096,.79,.077),BODY)
		g.box(Vector3(side*1.17,1.79,-1.77),Vector3(.11,.27,.15),METAL)
		g.beam(Vector3(side*.96,1.69,-1.74),Vector3(side*1.19,1.76,-1.77),.046,.045,METAL)
		for z: float in [-2.03,1.91]:
			var start := Vector3(side*.85,.55,z)
			var end := Vector3(side*1.16,.55,z)
			g.tube(start,end,.53,TIRE,12)
			g.tube(end,end+Vector3.RIGHT*side*.025,.26,METAL,9)
		g.box(Vector3(side*.76,1.26,-3.28),Vector3(.31,.23,.08),Color("#e7dcc3"))
		for z:float in [-.56,2.92]:
			g.box(Vector3(side*1.155,2.98,z),Vector3(.06,.23,.38),RED)
		for end:float in [-1,1]:
			g.box(Vector3(side*.83,2.98,1.20+end*2.066),Vector3(.38,.20,.065),RED)
		var door: float = side*.50
		g.box(Vector3(door,1.87,3.248),Vector3(.96,2.18,.046),METAL)
		g.box(Vector3(door,1.87,3.28),Vector3(.90,2.10,.05),BODY)
		g.box(Vector3(door,2.19,3.315),Vector3(.62,.58,.035),GLASS)
		g.box(Vector3(door,1.64,3.315),Vector3(.90,.28,.044),RED)
		g.box(Vector3(side*.19,1.41,3.34),Vector3(.078,.17,.062),TIRE)
		for arm: float in [0,PI/3,2*PI/3]:
			g.box(Vector3(side*1.169,2.30,-.24),Vector3(.025,.72,.22),Color("#326b87"),Vector3(arm,0,0))
		g.box(Vector3(side*1.187,2.30,-.24),Vector3(.022,.38,.056),BODY)
		Kit.label(van,"TAMARACK",Vector3(side*1.162,2.50,1.67),.32,RED,Vector3(0,side*PI*.5,0))
		Kit.label(van,"MEMORIAL EMS",Vector3(side*1.162,2.10,1.67),.25,TIRE,Vector3(0,side*PI*.5,0))
		Kit.label(van,"214",Vector3(side*1.160,1.08,2.44),.21,TIRE,Vector3(0,side*PI*.5,0))
	Kit.label(van,PLATE,Vector3(0,.80,3.36),.13,TIRE)
	g.finish()
	return van

static func warning_heads(lamps: Node3D) -> void:
	for side: float in [-1,1]:
		var bank := Kit.joint(lamps,Vector3.ZERO,"LeftWarning" if side < 0 else "RightWarning")
		var g := Kit.new(bank)
		for end:float in [-1,1]:
			g.box(Vector3(side*.83,2.98,1.20+end*2.11),Vector3(.34,.17,.04),Color("#fd584b"),Vector3.ZERO,"lamp")
			g.box(Vector3(side*1.188,2.98,1.18+end*1.74),Vector3(.024,.20,.32),Color("#ed5148"),Vector3.ZERO,"lamp")

		g.finish()

static func flash(lamps: Node3D, elapsed: float) -> void:
	var left := lamps.get_node_or_null("LeftWarning") as Node3D
	if left:
		left.visible = elapsed < .40
		lamps.get_node("RightWarning").visible = elapsed >= .50 and elapsed < .90

static func fit_uniform(person: Node3D, attendant: bool) -> void:
	var jacket := person.find_child("Jacket",true,false) as MeshInstance3D
	if jacket:
		var cloth := ShaderMaterial.new()
		cloth.shader = preload("res://assets/characters/ems_coat.gdshader")
		cloth.set_shader_parameter("palette",preload("res://assets/characters/winter_palette.png"))
		cloth.set_shader_parameter("coat",Color("#577f88") if attendant else Color("#3f636e"))
		jacket.material_override = cloth
	if not attendant:
		return
	var cot := Kit.joint(person,Vector3(0,0,-1.08),"EmptyCot")
	var g := Kit.new(cot)
	g.box(Vector3(0,.88,0),Vector3(.66,.11,1.74),METAL)
	g.box(Vector3(0,.97,-.06),Vector3(.57,.13,1.47),Color("#587a83"))
	g.box(Vector3(0,1.09,-.61),Vector3(.52,.11,.36),BODY)
	for side:float in [-1,1]:
		var x := side*.31
		g.beam(Vector3(x,.21,-.59),Vector3(x,.87,.63),.052,.052,METAL)
		g.beam(Vector3(x,.21,.59),Vector3(x,.87,-.63),.052,.052,METAL)
		g.tube(Vector3(x,.77,.80),Vector3(x,1.06,.95),.037,METAL)
		g.box(Vector3(x,1.09,0),Vector3(.035,.045,1.08),METAL)
		for z:float in [-.60,.60]:
			g.tube(Vector3(x-.044,.19,z),Vector3(x+.044,.19,z),.12,TIRE,9)
	g.finish()
