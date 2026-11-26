extends Node3D
## Once a checked car clears the apron the volunteers bring Tanker 2 out.
const Town := preload("res://scripts/esker_main_street.gd")
const Kit := preload("res://scripts/rig_mesh.gd")
const DRIVE_OUT := 10.0
const LANE := Rect2(Town.TANKER_X-2.3,12.2,4.6,23.)
const RED := Color("#993a31")
const CREAM := Color("#e1d7b1")
const BLACK := Color("#282f30")
const STEEL := Color("#a0a6a1")
var panels: Array[Node3D] = []
var gate_collision: CollisionShape3D
var tanker: Node3D
var lift := 0.0
var travel := 0.0

func build(world) -> void:
	position = Vector3(Town.TANKER_X,0,Town.HALL.y)
	var door := Kit.joint(self,Vector3.ZERO,"TankerDoor")
	for i in 9:
		var panel := Kit.joint(door,Vector3.ZERO)
		panels.append(panel)
		var gate := Kit.new(panel)
		gate.box(Vector3.ZERO,Vector3(7.32,.56,.18),RED)
		if i == 5:
			for x: float in [-2.71,-.91,.91,2.71]:
				gate.box(Vector3(x,0,-.099),Vector3(1.50,.44,.042),Color("#7f989b"))
		if i == 7:
			Kit.label(panel,"TANKER  2",Vector3(0,0,-.11),.52,CREAM,Vector3(0,PI,0)).visibility_range_end = 75
		gate.finish().visibility_range_end = 145
	var frame := StaticBody3D.new()
	door.add_child(frame)
	gate_collision=CollisionShape3D.new()
	gate_collision.shape=BoxShape3D.new()
	frame.add_child(gate_collision)
	tanker = Kit.joint(self,Vector3.ZERO,"EskerTankerTwo")
	var g := Kit.new(tanker)
	g.box(Vector3(0,.79,0),Vector3(1.95,.42,7.0),BLACK)
	g.box(Vector3(0,1.13,-2.82),Vector3(2.06,.91,1.51),RED)
	g.box(Vector3(0,1.58,-1.53),Vector3(2.33,1.35,1.81),RED)
	g.box(Vector3(0,2.53,-1.46),Vector3(2.18,.77,1.65),Color("#607777"))
	g.box(Vector3(0,2.97,-1.47),Vector3(2.37,.17,1.87),CREAM)
	g.box(Vector3(0,1.16,-3.61),Vector3(1.28,.59,.09),STEEL)
	for bar in 6: g.box(Vector3(0,.94+bar*.078,-3.67),Vector3(1.13,.031,.04),BLACK)
	g.box(Vector3(0,.74,-3.65),Vector3(2.42,.19,.26),STEEL)
	g.tube(Vector3(0,1.76,-.42),Vector3(0,1.76,3.21),1.07,RED,12,"paint")
	g.tube(Vector3(0,2.77,.56),Vector3(0,2.87,.56),.37,STEEL)
	for side: float in [-1,1]:
		g.box(Vector3(side*1.02,1.06,1.31),Vector3(.31,.62,3.38),RED)
		g.box(Vector3(side*1.17,1.58,-1.50),Vector3(.02,.15,1.77),CREAM)
		g.box(Vector3(side*1.13,1.21,1.53),Vector3(.10,.22,3.44),CREAM)
		g.box(Vector3(side*.87,1.24,-3.61),Vector3(.24,.21,.095),CREAM,Vector3.ZERO,"lamp")
		for z:float in [-2.54,2.20]:
			var hub := Vector3(side*1.17,.59,z)
			g.tube(hub-Vector3.RIGHT*side*.42,hub,.59,BLACK,12)
			g.tube(hub,hub+Vector3.RIGHT*side*.031,.31,STEEL,12)
		g.box(Vector3(side*.67,3.12,-1.43),Vector3(.37,.19,.27),Color("#af302d"))
		Kit.label(tanker,"ESKER",Vector3(side*1.18,1.90,-1.42),.28,CREAM,Vector3(0,side*PI*.5,0)).visibility_range_end = 55
		for pipe in 3:
			g.tube(Vector3(side*1.05,1.78+pipe*.16,.30),Vector3(side*1.05,1.78+pipe*.16,3.3),.077,STEEL)
	g.finish().visibility_range_end = 145
	var shell = world.Batch.new(tanker,world.materials)
	shell.solid_box(Vector3(0,1.55,-.02),Vector3(2.35,2.51,7.20))
	_place()

func advance(cleared: bool, rig, dt: float) -> void:
	if not cleared and is_zero_approx(lift) and is_zero_approx(travel): return
	# A body about to cross the apron yields to the operator and whole tow rig.
	var blocked := LANE.grow(4.7).has_point(Vector2(rig.truck.position.x,rig.truck.position.z))
	if not rig.in_cab:
		blocked = blocked or LANE.grow(.63).has_point(Vector2(rig.foot.x,rig.foot.z))
	if rig.car and rig.car.visible:
		blocked = blocked or LANE.grow(2.6).has_point(Vector2(rig.car.position.x,rig.car.position.z))
	if blocked: return
	if cleared:
		lift = move_toward(lift,1.0,dt*.42)
		if lift >= 1.0: travel = move_toward(travel,DRIVE_OUT,dt*1.28)
	else:
		travel = move_toward(travel,0.0,dt*.90)
		if is_zero_approx(travel): lift = move_toward(lift,0.0,dt*.35)
	_place()

func restore(state: Dictionary) -> void:
	travel = clampf(state.get("travel",0.),0,DRIVE_OUT)
	lift = 1.0 if travel>0 else clampf(state.get("lift",0.),0,1)
	_place()

func _place() -> void:
	# Each section turns over the header and runs back under the ceiling.
	for i in panels.size():
		var height := .31+i*.59+lift*5.64
		var run := maxf(0,height-5.1)
		var bend := minf(PI*.5,run/.68)
		panels[i].position = Vector3(0,minf(height,5.1)+.68*sin(bend),.68*(1-cos(bend))+maxf(0,run-.68*PI*.5))
		panels[i].rotation.x = bend
	var open := minf(5.33,lift*5.64)
	var remaining := maxf(.03,5.33-open)
	gate_collision.disabled = remaining < .04
	(gate_collision.shape as BoxShape3D).size = Vector3(7.32,remaining,.18)
	gate_collision.position.y = open+remaining*.5
	tanker.position.z = 5.85-travel
