extends RefCounted

const Kit := preload("res://scripts/rig_mesh.gd")
const VARIANT := 5
const DRIVER := 4
const PLATE := "WI CO 017"
const VIN := "1HTSDPNR7PH482017"
const SIZE := Vector3(1.18,.98,3.24)
const ORANGE := Color("#b96d34")
const DARK := Color("#322e29")
const METAL := Color("#87877c")
const GLASS := Color("#34464c")
const SNOW := Color("#c8cdd0")

static func build(parent: Node3D) -> Node3D:
	var truck := Kit.joint(parent,Vector3.ZERO,"CountySnowplow")
	truck.set_meta("plate",PLATE)
	truck.set_meta("vin",VIN)
	truck.set_meta("body_size",SIZE)
	truck.set_meta("driver_door",Vector3(-1.37,0,-.89))
	var g := Kit.new(truck)
	# Short conventional cab, tall dump box and a salt chute on the curb side.
	g.box(Vector3(0,.78,0),Vector3(1.62,.38,6.3),DARK)
	g.box(Vector3(0,1.39,-2.45),Vector3(1.76,.75,1.54),ORANGE)
	g.box(Vector3(.07,1.775,-2.41),Vector3(1.51,.025,1.42),SNOW)
	g.box(Vector3(0,1.4,-3.23),Vector3(1.29,.52,.04),DARK)
	for x in 11:
		g.box(Vector3((x-5)*.108,1.4,-3.26),Vector3(.044,.44,.04),METAL)
	g.box(Vector3(0,.88,-3.25),Vector3(2.26,.25,.16),METAL)
	g.box(Vector3(0,1.51,-.98),Vector3(2.21,1.05,1.5),ORANGE)
	g.box(Vector3(0,2.37,-1.61),Vector3(1.98,.72,.05),GLASS,Vector3(.19,0,0))
	g.box(Vector3(0,2.37,-1.65),Vector3(.045,.73,.055),METAL,Vector3(.19,0,0))
	g.box(Vector3(0,2.8,-.95),Vector3(2.17,.12,1.48),ORANGE)
	g.box(Vector3(0,2.875,-.95),Vector3(2.09,.04,1.44),SNOW)
	g.box(Vector3(0,2.35,-.32),Vector3(2.13,.78,.09),ORANGE)
	for side:float in [-1,1]:
		var x := side*1.04
		g.box(Vector3(side*1.02,1.32,-3.09),Vector3(.43,.38,.31),ORANGE)
		g.box(Vector3(side*1.02,1.32,-3.255),Vector3(.31,.20,.035),Color("#c7c9b8"))
		g.box(Vector3(side*1.05,1.30,-2.43),Vector3(.43,.15,1.27),ORANGE)
		for z:float in [-1.56,-.31]:
			g.beam(Vector3(x,2.01,z),Vector3(x*.96,2.77,z+.095 if z < -1 else z),.088,.085,ORANGE)
		# The driver's window is down far enough to see him in the parked cab.
		var pane_height := .24 if side < 0 else .64
		g.box(Vector3(x,2.02+pane_height*.5,-.95),Vector3(.036,pane_height,1.10),GLASS)
		g.box(Vector3(x,1.04,-.93),Vector3(.43,.12,1.39),METAL)
		g.beam(Vector3(x,2.19,-1.36),Vector3(side*1.39,2.28,-1.41),.045,.045,DARK)
		g.box(Vector3(side*1.39,2.28,-1.41),Vector3(.10,.38,.18),METAL)
		Kit.label(truck,"TAMARACK COUNTY\nHIGHWAY  •  17",Vector3(side*1.118,1.61,-.90),.136,DARK,Vector3(0,side*PI/2,0))
		for z:float in [-2.14,1.40,2.45]:
			g.tube(Vector3(x-side*.18,.53,z),Vector3(x+side*.17,.53,z),.53,DARK,16)
			g.tube(Vector3(x+side*.17,.53,z),Vector3(x+side*.19,.53,z),.31,METAL,12)
			g.tube(Vector3(x+side*.19,.53,z),Vector3(x+side*.23,.53,z),.12,Color("#686963"),10)
			for stud in 6:
				var hub := Vector3(x+side*.19,.53+.20*sin(stud*TAU/6),z+.20*cos(stud*TAU/6))
				g.tube(hub,hub+Vector3.RIGHT*side*.018,.027,DARK,6)
		g.box(Vector3(x,.55,3.04),Vector3(.42,.82,.07),DARK)
		g.box(Vector3(side*1.06,1.64,1.52),Vector3(.15,1.18,3.24),ORANGE)
		g.box(Vector3(side*1.06,2.25,1.52),Vector3(.20,.10,3.35),SNOW)
		for z:float in [.06,1.05,2.04,3.04]:
			g.box(Vector3(side*1.15,1.63,z),Vector3(.08,1.10,.11),Color("#92552e"))
	g.box(Vector3(0,1.24,1.54),Vector3(2.12,.28,3.21),DARK)
	g.box(Vector3(0,1.93,-.05),Vector3(2.23,1.44,.15),ORANGE)
	g.box(Vector3(0,1.57,3.11),Vector3(2.16,.93,.13),ORANGE)
	for x:float in [-.95,-.32,.32,.95]:
		g.box(Vector3(x,1.60,3.198),Vector3(.063,.77,.055),Color("#92552e"))
	g.box(Vector3(0,1.70,1.54),Vector3(2.02,.43,2.97),Color("#b5b3a6"))
	g.box(Vector3(.75,1.03,3.23),Vector3(.49,.55,.31),DARK)
	g.tube(Vector3(.75,.74,3.24),Vector3(.75,.79,3.24),.37,METAL,10)
	g.box(Vector3(0,.85,3.20),Vector3(1.91,.22,.13),DARK)
	g.ring(Vector3(0,SIZE.y-.087,SIZE.z*1.016),.085,.144,Color("#caa559"),Vector3(PI/2,0,0))
	g.box(Vector3(-.61,1.34,3.185),Vector3(.49,.22,.03),Color("#d9d8ba"))
	Kit.label(truck,PLATE,Vector3(-.61,1.34,3.21),.079,DARK)
	var vin_at := Vector3(-.42,2.08,-1.72)
	g.box(vin_at,Vector3(.49,.066,.025),DARK)
	Kit.label(truck,VIN,vin_at+Vector3.FORWARD*.018,.034,SNOW,Vector3(0,PI,0),"plex_mono")
	for x:float in [-.79,.79]:
		g.box(Vector3(x,2.95,-.98),Vector3(.32,.19,.26),Color("#c78536"))
		g.beam(Vector3(x*.68,.92,-3.21),Vector3(x,.48,-3.91),.13,.13,DARK)
	g.finish()
	var blade := Kit.joint(truck,Vector3(0,0,-3.98),"Blade")
	blade.rotation.y = .23
	var steel := Kit.new(blade)
	# The curved moldboard tips the cut snow up and out past the right wing.
	for section: Array in [[.23,.05,.40,.24],[.57,.16,.38,.30],[.89,.17,.34,-.22]]:
		steel.box(Vector3(0,section[0],section[1]),Vector3(3.66,section[2],.13),ORANGE,Vector3(section[3],0,0))
	steel.box(Vector3(0,.077,0),Vector3(3.74,.14,.17),METAL)
	for x:float in [-1.72,1.72]:
		steel.tube(Vector3(x,.88,.17),Vector3(x*1.04,1.69,.16),.023,Color("#eda45a"))
		steel.box(Vector3(x*1.04,1.6,.16),Vector3(.045,.15,.045),SNOW)
	steel.finish()
	return truck
