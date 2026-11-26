extends Node3D

const Kit := preload("res://scripts/rig_mesh.gd")
const VARIANT := 8
const SIZE := Vector3(1.22,.89,4.64)
const FRONT_AXLE := -3.28
const REAR_AXLE := 2.58
const WHEEL_RADIUS := .52
const BLACK := Color("#292f2c")
const CREAM := Color("#e3e4ce")
const STEEL := Color("#b4c1bf")
const GREEN := Color("#3c6851")
const GLASS := Color("#41565d")
const CABINET := Vector3(0,1.22,4.58)
var shell: Node3D
var gallons := 1650
var seal := ""
var checked := false
# x is sideways, y is toward the nose. Motion lags the forces on a baffled tank.
var surge := Vector2.ZERO
var liquid_speed := Vector2.ZERO
var last_pull_speed := 0.0

func build(parent: Node3D, ticket: Dictionary) -> void:
	name = "BulkMilkTruck"
	parent.add_child(self)
	gallons = int(ticket.get("gallons",1650))
	seal = str(ticket.get("seal",""))
	set_meta("body_size",SIZE)
	set_meta("plate",ticket.get("plate",""))
	set_meta("vin",ticket.get("vin",""))
	var wheels := Kit.new(self)
	for side:float in [-1,1]:
		for z:float in [FRONT_AXLE,REAR_AXLE-.53,REAR_AXLE+.53]:
			wheels.truck_wheel(side,z,WHEEL_RADIUS,1.04,0)
	wheels.finish()
	shell = Kit.joint(self,Vector3.UP*.74,"TankSuspension")
	var g := Kit.new(shell)
	g.box(Vector3(0,.02,0),Vector3(.96,.34,8.95),BLACK)
	g.box(Vector3(0,.91,-2.45),Vector3(2.08,1.08,1.62),CREAM)
	g.box(Vector3(0,1.68,-3.22),Vector3(1.96,.68,.072),GLASS,Vector3(.155,0,0))
	g.box(Vector3(0,2.09,-2.45),Vector3(2.15,.13,1.69),GREEN)
	g.box(Vector3(0,.79,-3.89),Vector3(1.64,.84,1.33),CREAM)
	g.box(Vector3(0,.17,-4.57),Vector3(2.32,.28,.15),STEEL)
	g.box(Vector3(0,.72,-4.56),Vector3(1.23,.72,.055),BLACK)
	for i in 9:
		g.box(Vector3((i-4)*.135,.72,-4.60),Vector3(.045,.63,.03),STEEL)
	g.ring(Vector3(0,SIZE.y-.827,-SIZE.z*1.016),.075,.128,Color("#bf9a62"),Vector3(PI/2,0,0))
	for side:float in [-1,1]:
		g.box(Vector3(side*1.032,1.70,-2.43),Vector3(.043,.65,1.31),GLASS)
		g.box(Vector3(side*1.043,.99,-2.51),Vector3(.061,.13,1.56),GREEN)
		g.box(Vector3(side*1.01,.39,-3.69),Vector3(.46,.35,1.48),CREAM)
		g.box(Vector3(side*.99,.55,-4.46),Vector3(.33,.18,.055),CREAM,Vector3.ZERO,"lamp")
		g.box(Vector3(side*1.08,.02,-2.37),Vector3(.40,.13,1.52),STEEL)
		g.beam(Vector3(side*1.04,1.73,-3.03),Vector3(side*1.37,1.81,-3.13),.036,.036,STEEL)
		g.box(Vector3(side*1.37,1.81,-3.13),Vector3(.13,.36,.13),BLACK)
		g.box(Vector3(side*.74,.24,1.25),Vector3(.31,.42,5.5),GREEN)
		g.box(Vector3(side*1.05,.15,2.61),Vector3(.53,.12,2.45),STEEL)
		g.box(Vector3(side*1.06,-.18,3.78),Vector3(.45,.69,.07),BLACK)
		Kit.label(shell,"BRZEZINSKI",Vector3(side*1.08,.75,-2.44),.092,GREEN,Vector3(0,side*PI/2,0))
	# A sanitary stainless tank has domed heads, bands, sealed manholes and a rear pump cabinet.
	var tube := CylinderMesh.new()
	tube.height = 1
	tube.top_radius = 1
	tube.bottom_radius = 1
	tube.radial_segments = 36
	tube.rings = 1
	var radial := Basis(Vector3.RIGHT,PI/2)
	var tube_center := Vector3(0,1.37,1.34)
	g.mesh_at(tube,tube_center,radial*Basis.from_scale(Vector3(1.19,4.97,1.01)),STEEL,"metal")
	var cap := SphereMesh.new()
	cap.radial_segments = 36
	cap.rings = 12
	for end:float in [-1.,1.]:
		g.mesh_at(cap,tube_center+Vector3.BACK*end*2.485,Basis.from_scale(Vector3(2.38,2.02,.94)),STEEL,"metal")
	for z:float in [-.90,.53,2.13,3.60]:
		g.mesh_at(tube,Vector3(0,1.37,z),radial*Basis.from_scale(Vector3(1.205,.062,1.023)),Color("#818e8d"),"metal")
	for z:float in [-.30,1.84]:
		g.tube(Vector3(0,2.34,z),Vector3(0,2.45,z),.35,STEEL,20)
		g.box(Vector3(0,2.47,z),Vector3(.72,.037,.070),BLACK)
	g.box(Vector3(-.78,2.16,1.15),Vector3(.34,.072,5.2),STEEL)
	for z:float in [-1.1,.3,1.9,3.4]:
		g.beam(Vector3(-.88,2.13,z),Vector3(-.91,2.53,z),.045,.045,STEEL)
	g.beam(Vector3(-.91,2.53,-1.13),Vector3(-.91,2.53,3.43),.045,.045,STEEL)
	for x:float in [-.84,-.42]:
		g.tube(Vector3(x,.30,4.05),Vector3(x,2.23,3.93),.043,STEEL)
	for y:float in [.45,.80,1.15,1.50,1.85,2.2]:
		g.tube(Vector3(-.84,y,4.06-y*.065),Vector3(-.42,y,4.06-y*.065),.040,STEEL)
	g.box(Vector3(.20,.61,4.27),Vector3(1.15,1.05,.53),CREAM)
	g.box(Vector3(.20,.65,4.55),Vector3(.94,.85,.04),GREEN)
	g.box(Vector3(.54,.72,4.60),Vector3(.15,.042,.060),STEEL)
	g.box(Vector3(.55,.61,4.60),Vector3(.04,.17,.03),Color("#de8a57"))
	Kit.label(shell,"PUMP  /  SEAL "+seal,Vector3(.20,.89,4.59),.054,CREAM)
	Kit.label(shell,str(get_meta("plate")),Vector3(-.34,.22,-4.66),.089,CREAM,Vector3(0,PI,0))
	for side:float in [-1,1]:
		Kit.label(shell,"GRADE A   •   BULK MILK",Vector3(side*1.215,1.43,1.24),.17,GREEN,Vector3(0,side*PI/2,0))
		g.box(Vector3(side*1.04,.14,4.43),Vector3(.27,.14,.06),Color("#ac4640"))
	g.finish()

func step_liquid(dt: float, demand: Vector2) -> void:
	# Less headspace near a full tank damps the wave. A partial tank stores more momentum.
	var fill := clampf(float(gallons)/2850.0,.25,.93)
	var target := demand.limit_length(1.25)*(1.36-fill*.52)
	liquid_speed += ((target-surge)*7.25 - liquid_speed*(1.10+fill*.56))*dt
	surge = (surge+liquid_speed*dt).limit_length(1.6)
	shell.rotation = Vector3(surge.y*.047,0,surge.x*.073)

func update_during_pull(dt: float, speed_along_line: float, local_pull: Vector3) -> void:
	var acceleration := (speed_along_line-last_pull_speed)/maxf(.001,dt)
	last_pull_speed = speed_along_line
	var fore := Vector2(-local_pull.x,local_pull.z)
	# The initial jerk and each release start a wave. A steady pull lets it die away.
	liquid_speed += fore*clampf(acceleration*dt,-1.4,1.4)*2.10
	step_liquid(dt,fore*speed_along_line*.53)

func snapshot() -> Dictionary:
	return {"checked":checked,"x":surge.x,"y":surge.y,"vx":liquid_speed.x,"vy":liquid_speed.y,"pull":last_pull_speed}

func is_settled() -> bool:
	return surge.length()<.25 and liquid_speed.length()<.45

func restore(state: Dictionary) -> void:
	checked = state.get("checked",false)
	surge = Vector2(state.get("x",0.),state.get("y",0.))
	liquid_speed = Vector2(state.get("vx",0.),state.get("vy",0.))
	last_pull_speed = state.get("pull",0.)
	shell.rotation = Vector3(surge.y*.047,0,surge.x*.073)

func fits(bay: Rect2) -> bool:
	for end:float in [-SIZE.z,SIZE.z]:
		for side:float in [-SIZE.x,SIZE.x]:
			var p := to_global(Vector3(side,0,end))
			if not bay.has_point(Vector2(p.x,p.z)): return false
	return true

func settle(ground: Callable) -> void:
	rotation.x = 0
	rotation.z = 0
	position.y = ground.call(position)
	shell.rotation = Vector3.ZERO
	var body := StaticBody3D.new()
	add_child(body)
	var box := BoxShape3D.new()
	box.size = Vector3(2.4,2.9,9.23)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = 1.55
	body.add_child(shape)

func delivery_record() -> Dictionary:
	return {"variant":VARIANT,"gallons":gallons,"seal":seal,"plate":get_meta("plate"),"vin":get_meta("vin"),
		"x":position.x,"z":position.z,"yaw":rotation.y}

func restore_delivery(parent: Node3D, data: Dictionary, ground: Callable) -> void:
	build(parent,data)
	position = Vector3(data.x,0,data.z)
	rotation.y = data.yaw
	settle(ground)
