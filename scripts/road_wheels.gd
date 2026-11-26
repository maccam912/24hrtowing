extends Node3D

const Kit := preload("res://scripts/rig_mesh.gd")
const RUBBER := Color("#272b2c")
const STEEL := Color("#929895")
const DOLLY_RISE := .14
var hubs: Array[Node3D] = []
var previous := PackedVector3Array()
var radius: float
var track: float
var axle_z: float

static func wheel(kit, at: Vector3, side: float, tire_radius: float, show_lugs := false) -> void:
	kit.tube(at-Vector3.RIGHT*side*.135,at+Vector3.RIGHT*side*.095,tire_radius,RUBBER,16)
	kit.tube(at+Vector3.RIGHT*side*.099,at+Vector3.RIGHT*side*.108,tire_radius*.61,STEEL,12)
	kit.tube(at+Vector3.RIGHT*side*.111,at+Vector3.RIGHT*side*.12,tire_radius*.25,Color("#535955"),8)
	if not show_lugs: return
	for lug in 5:
		var angle := TAU*lug/5
		var bolt := at+Vector3(side*.11,tire_radius*.38*cos(angle),tire_radius*.38*sin(angle))
		kit.tube(bolt,bolt+Vector3.RIGHT*side*.014,.025,Color("#515751"),6)

func assemble(vehicle: Node3D, size: Vector3, tire_radius: float) -> void:
	name = "RoadWheels"
	vehicle.add_child(self)
	track = size.x
	axle_z = size.z*.61
	radius = tire_radius
	for side:float in [-1.,1.]:
		for end:float in [-1.,1.]:
			var hub := Kit.joint(self,Vector3(side*track,radius,end*axle_z))
			var kit := Kit.new(hub)
			wheel(kit,Vector3.ZERO,side,radius,true)
			kit.finish()
			hubs.append(hub)
			previous.append(Vector3.INF)

func roll_on_ground(index: int, held: bool) -> void:
	var hub := hubs[index]
	if not held and previous[index].is_finite():
		var travel := (hub.global_position-previous[index]).dot(-global_basis.z)
		hub.rotation.x = wrapf(hub.rotation.x-travel/radius,-PI,PI)
	previous[index] = hub.global_position

func ground_axle(end: int, ground: Callable, dollies: Node3D) -> void:
	var lift := DOLLY_RISE if dollies else 0.0
	for i in hubs.size():
		var hub := hubs[i]
		if signf(hub.position.z) == end:
			continue
		var point := hub.global_position
		var foot := float(ground.call(point))
		var body_at := to_global(Vector3(hub.position.x,0,hub.position.z)).y
		var sprung := (foot+radius+lift-body_at)/maxf(global_basis.y.y,.65)
		hub.position.y = clampf(sprung,radius-.14,radius+.14)
		roll_on_ground(i,dollies!=null)
		if dollies:
			var cart := dollies.get_child(i/2) as Node3D
			cart.global_basis = Basis(Vector3.UP,global_rotation.y)
			cart.global_position = Vector3(hub.global_position.x,foot,hub.global_position.z)

func fit_dollies(end: int) -> Node3D:
	var dollies := Kit.joint(self,Vector3.ZERO,"WheelDollies")
	for side:float in [-1.,1.]:
		var cart := Kit.joint(dollies,Vector3(side*track,0,-end*axle_z))
		var k := Kit.new(cart)
		for dz:float in [-.30,.30]:
			k.box(Vector3(0,.227,dz),Vector3(.50,.09,.10),Color("#a98456"))
			k.tube(Vector3(-.31,.115,dz),Vector3(.31,.115,dz),.042,STEEL,8)
			for s:float in [-1.,1.]:
				k.tube(Vector3(s*.22,.115,dz),Vector3(s*.32,.115,dz),.115,RUBBER,10)
		k.box(Vector3(side*.203,.22,0),Vector3(.08,.10,.72),Color("#875c44"))
		k.finish()
	return dollies

func release(dollies: Node3D) -> void:
	for hub in hubs: hub.position.y = radius
	if dollies: dollies.hide()
