extends Node3D

const Kit := preload("res://scripts/rig_mesh.gd")
const IRON := Color("#404747")
const STEEL := Color("#858c86")
const STRAP := Color("#b87d40")
const BUCKLE := Color("#bdc1b7")
const AXLE_HEIGHT := .15
var shoes: Array[Node3D] = []
var straps: Array[Node3D] = []
var width := 0.
var radius := 0.

func assemble(stinger: Node3D, at: Vector3) -> void:
	name = "PivotingCrossbar"
	stinger.add_child(self)
	position = at
	var g := Kit.new(self)
	g.tube(Vector3(0,-.18,0),Vector3(0,.12,0),.145,STEEL,12)
	# The sliding ends run in the fixed center section.
	g.box(Vector3(0,-.06,0),Vector3(1.40,.18,.21),IRON)
	g.finish()
	for side:float in [-1,1]:
		var shoe := Kit.joint(self,Vector3.ZERO,"LeftBasket" if side<0 else "RightBasket")
		shoes.append(shoe)
		var metal := Kit.new(shoe)
		# The basket is centered at the axle. Two bars cradle the tire below its hub.
		metal.box(Vector3(-side*.17,0,0),Vector3(.115,.115,.66),IRON)
		for z:float in [-.235,.235]:
			metal.box(Vector3(.012*side,0,z),Vector3(.455,.092,.087),STEEL)
		metal.box(Vector3(-side*.28,.02,0),Vector3(.38,.108,.13),IRON)
		metal.finish()
		var strap := Kit.joint(shoe,Vector3.ZERO,"TireStrap")
		straps.append(strap)
		var webbing := Kit.new(strap)
		# Follow the tread from one basket bar to the other, over the top of the tire.
		var wheel := Vector3(0,.255,0)
		for i in 12:
			var a := lerpf(-.87,PI+.87,i/12.)
			var b := lerpf(-.87,PI+.87,(i+1)/12.)
			var start := wheel+Vector3(side*.040,sin(a)*.364,cos(a)*.364)
			var end := wheel+Vector3(side*.040,sin(b)*.364,cos(b)*.364)
			webbing.beam(start,end,.081,.021,STRAP)
		webbing.box(Vector3(side*.048,-.003,.253),Vector3(.12,.059,.088),BUCKLE)
		webbing.finish()
	set_size(.89,.355)
	release()

func set_size(half_track: float, tire: float) -> void:
	if is_equal_approx(width,half_track) and is_equal_approx(radius,tire): return
	width = half_track
	radius = tire
	var ratio := radius/.355
	for i in shoes.size():
		var side := -1. if i==0 else 1.
		shoes[i].position = Vector3(side*width,AXLE_HEIGHT-.255*ratio,0)
		shoes[i].scale = Vector3(1.,ratio,ratio)

func follow_axle(vehicle: Node3D, end: int, half_track: float, tire_radius: float) -> void:
	set_size(half_track,tire_radius)
	# At a rear hookup the casualty faces the wrecker. The crossbar still sweeps
	# around its kingpin in the same direction as the tires it actually supports.
	global_basis = vehicle.global_basis * Basis(Vector3.UP,PI if end>0 else 0.)
	for strap in straps: strap.visible = true

func release() -> void:
	rotation = Vector3.ZERO
	for strap in straps: strap.hide()
