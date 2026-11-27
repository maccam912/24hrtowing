extends RefCounted

const Kit := preload("res://scripts/rig_mesh.gd")
const FRONT_BRAKE := "bound_caliper"
const REAR_AXLE := "bent_axle"
var kind: String
var end: int
var side: int
var checked := false
var skates: Node3D

func _init(ticket: Dictionary) -> void:
	kind = ticket.wheel_fault
	end = 1 if kind==REAR_AXLE else -1
	side = 1 if int(ticket.get("wheel_side",-1))>0 else -1

func corner() -> String:
	return ("right " if side>0 else "left ")+("rear" if end>0 else "front")

func finding() -> String:
	if kind==REAR_AXLE:
		return "The %s wheel leans into the arch. The axle tube is bent and the tire binds." % corner()
	return "The %s rotor won't turn. The caliper is locked against the disc." % corner()

func method(rig) -> String:
	if rig.rollback_active: return "Rollback · loading skates"
	var lifted := "Front lift" if rig.line_end<0 else "Rear lift"
	if rig.dollies: return lifted+" · "+("rear" if end>0 else "front")+" dollies"
	return lifted+" · damaged axle carried"

func wheel_position(rig) -> Vector3:
	var index := (2 if side > 0 else 0) + (1 if end > 0 else 0)
	return rig.road_wheels.hubs[index].global_position

func roll_free_wheels(rig) -> void:
	var wheels = rig.road_wheels
	for i in wheels.hubs.size():
		var local: Vector3 = wheels.hubs[i].position
		var held := signf(local.z)==end and (skates!=null or signf(local.x)==side)
		wheels.roll_on_ground(i,held)

func at_wheel(rig) -> bool:
	return rig.in_range(wheel_position(rig),1.75) and rig.car.to_local(rig.foot).x*side > .58

func action(rig, panel: bool) -> String:
	if rig.phase in ["flared","cable","rigged","at_lift"] and not checked and at_wheel(rig):
		return "axle_inspect"
	if rig.rollback_active:
		if not skates and rig.phase in ["flared","cable","rigged"]:
			if checked and at_wheel(rig): return "axle_skate"
			if panel and rig.phase == "rigged": return "axle_needs_skates"
	elif rig.phase=="at_lift" and rig.line_end != end and not rig.dollies:
		if at_wheel(rig) and checked: return "axle_dollies"
		if panel: return "axle_needs_dollies"
	return ""

func instruction(rig) -> String:
	if rig.phase=="flared" and not checked: return "Walk round the car and check the wheel that left the drag mark."
	if rig.rollback_active and not skates and rig.phase in ["cable","rigged"]:
		return "Check the marked wheel and place the loading skates under its axle before reeling in."
	if not rig.rollback_active and rig.phase=="at_lift" and rig.line_end!=end and not rig.dollies:
		return "Check the %s wheel. Set the Go-Jacks under the trailing pair before raising the lift." % corner()
	return ""

func prompt(action_id: String) -> String:
	match action_id:
		"axle_inspect": return "Check the %s wheel" % corner()
		"axle_skate": return "Fit loading skates under the bound axle"
		"axle_needs_skates": return "Check the wheel and set loading skates beside it"
		"axle_dollies": return "Raise the trailing axle on Go-Jacks"
		"axle_needs_dollies": return "The trailing axle won't roll. Set its dollies at the car."
	return ""

func fit_skates(rig) -> void:
	if skates: return
	skates = Kit.joint(rig.car,Vector3.ZERO,"LoadingSkates")
	var kit := Kit.new(skates)
	var wheels = rig.road_wheels
	for s:float in [-1.,1.]:
		var x:float=s*wheels.track
		var z:float=end*wheels.axle_z
		kit.box(Vector3(x,.024,z),Vector3(.34,.047,.62),Color("#a67e46"))
		for tip:float in [-1.,1.]:
			kit.box(Vector3(x,.078,z+tip*.34),Vector3(.34,.052,.16),Color("#b48c50"),Vector3(-tip*.50,0,0))
		kit.box(Vector3(x+s*.137,.08,z),Vector3(.041,.11,.36),Color("#cca06d"))
	kit.finish()

func handle(rig, id:String) -> void:
	match id:
		"axle_inspect":
			checked = true
			rig.show_note(finding()+(" Put the skates under this axle." if rig.rollback_active else " Lift that end, or dolly it if it trails."),8.)
		"axle_skate":
			fit_skates(rig)
			rig.sound_event.emit("ratchet")
			rig.show_note("Skates seated. The locked wheels can slide up the runners.",5.)
		"axle_dollies":
			rig.fit_dollies()
			rig.phase = "dollies"
			rig.sound_event.emit("ratchet")
			rig.show_note("Both tires clear of the ground. The side panel can lift the other axle.",5.)
		_: rig.show_note(prompt(id),4.)

static func settle_on_shoulder(car: Node3D, ground: Callable) -> void:
	var wheels = car.get_node("RoadWheels")
	var yaw := car.rotation.y
	var ground_y := PackedFloat32Array()
	for hub: Node3D in wheels.hubs:
		var offset := Vector3(hub.position.x,0,hub.position.z).rotated(Vector3.UP,yaw)
		ground_y.append(ground.call(car.global_position+offset))
	# Hubs are ordered left front, left rear, right front, right rear.
	var roll := atan2(ground_y[2]+ground_y[3]-ground_y[0]-ground_y[1],4.*wheels.track)
	var pitch := atan2(ground_y[0]+ground_y[2]-ground_y[1]-ground_y[3],4.*wheels.axle_z)
	car.rotation = Vector3(pitch,yaw,roll)
	car.position.y = (ground_y[0]+ground_y[1]+ground_y[2]+ground_y[3])*.25
	for i in wheels.hubs.size():
		var hub: Node3D = wheels.hubs[i]
		var sill := car.to_global(Vector3(hub.position.x,0,hub.position.z))
		hub.position.y = (ground_y[i]+wheels.radius-sill.y)/car.global_basis.y.y

static func mark_car(wheels, ticket: Dictionary) -> void:
	var broken: bool = ticket.wheel_fault==REAR_AXLE
	var s := 1 if int(ticket.get("wheel_side",-1))>0 else -1
	var idx := (2 if s>0 else 0)+(1 if broken else 0)
	var hub: Node3D = wheels.hubs[idx]
	var mesh: Node3D = hub.get_child(0)
	if broken:
		mesh.rotation.z = s*.34
		# The break is exposed below the rear arch. The drifting wheel keeps its camber.
		var link := Kit.new(wheels)
		var z:float=wheels.axle_z
		link.beam(Vector3(s*.22,.30,z),Vector3(s*.63,.27,z),.12,.14,Color("#575852"))
		link.beam(Vector3(s*.64,.26,z),Vector3(s*.87,.20,z-.06),.12,.14,Color("#674f41"))
		link.finish()
	else:
		var caliper := Kit.new(hub)
		caliper.box(Vector3(s*.126,.08,wheels.radius*.44),Vector3(.07,.22,.115),Color("#9c7054"))
		caliper.finish()

func drag_mark(rig) -> void:
	var hub := wheel_position(rig)
	var at := Vector3(hub.x,rig.ground_height(hub)+.043,hub.z)
	var mark := Kit.joint(rig.car,Vector3.ZERO,"LockedWheelTrack")
	mark.top_level=true
	mark.global_position=at
	mark.rotation.y=rig.car.rotation.y
	var k:=Kit.new(mark)
	for i in 12:
		var z:=.35+i*.24
		var h:float = rig.ground_height(mark.to_global(Vector3(0,0,z)))-at.y+.048
		k.box(Vector3(sin(i*.44)*.028,h,z),Vector3(.19+.025*cos(i*.54),.022,.27),Color("#676c72"))
		k.box(Vector3(side*.13,h+.014,z),Vector3(.049,.042,.25),Color("#b0bac2"))
	k.finish()
