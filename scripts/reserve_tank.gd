extends Node3D

const Kit := preload("res://scripts/rig_mesh.gd")
# Fuel volume is measured in main-tank equivalents, so either tank costs the same per unit.
const CAPACITY := .50
const TRANSFER_RATE := .050
const PUMP := Vector3(1.37,2.03,1.08)
const CREAM := Color("#dcd7be")
const GREEN := Color("#646f5c")
const STEEL := Color("#a2aaa2")
const DARK := Color("#343937")
const AMBER := Color("#c99b5f")
var needle: Node3D
var glass_float: MeshInstance3D

func install(body: Node3D) -> void:
	name = "AuxiliaryDieselTank"
	body.add_child(self)
	var g := Kit.new(self)
	# The reserve sits on the curb-side bed rail behind the exhaust stack.
	g.box(Vector3(.98,1.96,1.13),Vector3(.57,.52,1.39),GREEN,Vector3.ZERO,"metal")
	g.box(Vector3(.98,2.22,1.13),Vector3(.59,.046,1.41),STEEL,Vector3.ZERO,"metal")
	for z:float in [.57,1.66]:
		g.box(Vector3(.98,2.25,z),Vector3(.60,.043,.068),DARK)
		g.box(Vector3(1.279,1.96,z),Vector3(.034,.54,.068),DARK)
		g.box(Vector3(.699,1.96,z),Vector3(.034,.54,.068),DARK)
	g.tube(Vector3(1.06,2.23,.81),Vector3(1.06,2.34,.81),.107,STEEL,14)
	g.tube(Vector3(1.06,2.34,.81),Vector3(1.06,2.37,.81),.13,DARK,12)
	g.box(Vector3(1.29,2.00,1.38),Vector3(.033,.18,.43),CREAM)
	Kit.label(self,"AUX DIESEL",Vector3(1.31,2.00,1.38),.047,DARK,Vector3(0,PI/2,0))
	g.box(Vector3(1.28,1.97,.96),Vector3(.12,.23,.28),DARK)
	g.tube(Vector3(1.32,2.03,1.02),Vector3(1.39,2.03,1.02),.059,AMBER,12)
	# Fixed transfer line runs to the existing saddle-tank filler below the step.
	var bends := [Vector3(1.29,1.87,1.02),Vector3(1.31,1.75,.83),Vector3(1.30,1.73,.40),Vector3(1.27,1.62,.16),Vector3(1.21,1.16,-.09),Vector3(1.03,1.08,-.23)]
	for i in bends.size()-1:
		g.tube(bends[i],bends[i+1],.034,DARK,7)
	# The sight glass gives a second reading on the actual fitted tank.
	g.box(Vector3(1.279,2.,.68),Vector3(.024,.37,.064),CREAM)
	g.finish()
	needle = Kit.joint(self,PUMP,"TransferSwitch")
	needle.rotation.y = PI/2
	var lever := Kit.new(needle)
	lever.beam(Vector3.ZERO,Vector3(.015,.092,.018),.031,.028,AMBER)
	lever.finish()
	var float_kit := Kit.new(self)
	float_kit.box(Vector3.ZERO,Vector3(.031,.054,.062),AMBER)
	glass_float = float_kit.finish()
	set_reading(0.)

func set_reading(volume: float, running := false) -> void:
	glass_float.position = Vector3(1.299,lerpf(1.85,2.15,clampf(volume/CAPACITY,0,1)),.68)
	needle.rotation.z = -.72 if running else .26
