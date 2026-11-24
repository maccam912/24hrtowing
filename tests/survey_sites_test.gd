extends SceneTree

const County := preload("res://scripts/county.gd")
const Rig := preload("res://scripts/rig.gd")
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		printerr("CHECK FAILED: ",message)

func run() -> void:
	var county := County.new()
	root.add_child(county)
	var rig := Rig.new()
	root.add_child(rig)
	rig.setup(county)
	rig.set_spawn(Vector3(-28,0,-64))
	await physics_frame
	await physics_frame
	var unit := county.survey_pickup
	check(unit.is_visible_in_tree() and county.tripod.visible,"Unit 38 and its tripod are already at the turnout")
	check(unit.get_meta("plate")==County.Scene.UNIT_PLATE and unit.get_meta("vin")==County.Scene.UNIT_VIN,"the parked unit carries its registered identity")
	var bumper := unit.global_position+Vector3.UP*.8
	var through_car := unit.global_basis.z*3.8
	check(rig._obstructed(bumper+through_car,-through_car*2),"the parked pickup occupies the turnout")
	var leg: Vector3 = county.hold_tripod_point()
	var gear: Vector3 = county.rod_case_point()
	rig.in_cab = false
	rig.foot = leg
	walk(rig,gear+Vector3.BACK*1.1)
	county.set_rod_case_read(true)
	county.set_survey_pickup_parked(false)
	county.set_tripod_collected(true)
	await physics_frame
	check(not rig._obstructed(bumper+through_car,-through_car*2),"accepting custody frees the parked pickup's collision")
	rig.start_job("hold",County.SURVEY_PICKUP,County.SURVEY_YAW)
	check(rig.car.global_position.is_equal_approx(unit.global_position) and rig.car.get_meta("vin")==unit.get_meta("vin"),"hold starts with the original vehicle pose and identity")
	rig.end_job()
	county.set_kolpack_open(true)
	await process_frame
	await physics_frame
	check(not county.survey_pickup.visible and not county.tripod.visible,"a county rebuild preserves removal of evidence")
	check(is_equal_approx(county.rod_case.rotation.x,PI),"the turned case keeps its stencil exposed after rebuilding")
	check(not county.lengthened and county.road_distance(442,336)<.01,"the unprinted road can open before the section line lengthens")
	var approach := county.resolve_point(Vector3(408,0,336))
	var door := county.story_point("house")
	var vin := county.story_point("vin")
	var cap := county.story_point("cap")
	rig.foot = approach
	walk(rig,Vector3(vin.x-2,0,approach.z))
	walk(rig,Vector3(vin.x-2,0,vin.z))
	walk(rig,Vector3(vin.x-2,0,approach.z))
	walk(rig,Vector3(door.x,0,approach.z))
	walk(rig,door+Vector3.BACK*.4)
	walk(rig,door+Vector3.FORWARD*.5)
	walk(rig,Vector3(door.x,0,approach.z))
	walk(rig,Vector3(cap.x,0,approach.z))
	walk(rig,cap+Vector3.BACK*.5)
	county.set_lengthened(true)
	await process_frame
	await physics_frame
	check(is_equal_approx(county.story_point("house").z-door.z,40) and is_zero_approx(county.road_distance(442,376)),"the accessible farmhouse and its lane follow the extended section")
	var identity := {"variant":2,"driver_variant":1,"plate":"ARB 608","vin":"2BRWK15P7PB226310"}
	rig.start_job("ditch",Vector3(9,0,140),.31,identity)
	var state: Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
	rig.restore_state(state)
	check(rig.car.get_meta("plate")==identity.plate and rig.vehicle_identity.variant==2,"restored ditch car keeps its assigned wagon and plate")
	var parked := rig.store_vehicle("hazard",Vector3.ZERO,0,identity)
	check(parked.get_meta("vin")==identity.vin,"stored car retains the ticket VIN")
	if not failed:
		print("CHECKS PASSED — walk the survey trail, N5104 porch, VIN and cap; preserve active and stored vehicle identities")
	quit(1 if failed else 0)

func walk(rig: Node3D, target: Vector3) -> void:
	for tick in 1300:
		var delta: Vector3 = target-rig.foot
		delta.y = 0
		if delta.length()<.14:
			return
		var direction := delta.normalized().rotated(Vector3.UP,-rig.camera_yaw)
		rig._walk(Vector2(direction.x,direction.z),1.0/60.0)
	check(false,"walk from %s to %s" % [rig.foot,target])
