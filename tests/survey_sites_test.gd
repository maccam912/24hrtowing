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
	await check_case_landmarks(county,rig)
	var identity := {"variant":2,"driver_variant":1,"plate":"ARB 608","vin":"2BRWK15P7PB226310"}
	rig.start_job("ditch",Vector3(9,0,140),.31,identity)
	var state: Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
	rig.restore_state(state)
	check(rig.car.get_meta("plate")==identity.plate and rig.vehicle_identity.variant==2,"restored ditch car keeps its assigned wagon and plate")
	var parked := rig.store_vehicle("hazard",Vector3.ZERO,0,identity)
	check(parked.get_meta("vin")==identity.vin,"stored car retains the ticket VIN")
	if not failed:
		print("CHECKS PASSED — walk the survey sites, bridge and porches; drive Alder Cut; persist physical case evidence")
	quit(1 if failed else 0)

func check_case_landmarks(county: Node3D, rig: Node3D) -> void:
	var landmarks := ["bridge_plate","mailboxes","last_cap","tou","checked_sedan"]
	check(county.road_distance(441,-490) > 20 and not county.sedan_tape.visible,"Alder Cut and the operator's tape start absent")
	county.set_case_landmarks(landmarks)
	await process_frame
	await physics_frame
	await physics_frame
	check(not county.map_roads().any(func(r): return r.name == "Alder Cut Rd"),"the drivable spur stays off the original printed plat")
	landmarks.append_array(["angie_house","angie"])
	county.set_case_landmarks(landmarks)
	check(county.map_roads().any(func(r): return r.name == "Alder Cut Rd") and county.map_places().any(func(p): return p.name == "N5420 Alder Cut"),"the adopted plat includes the complete spur and Angie's fire number")
	check(county.case_models.has("bridge_plate_far") and county.sedan_tape.visible,"both rail plates and taped mirror are visible")
	var east: Vector3 = county.story_point("bridge_plate")
	var west: Vector3 = county.story_point("bridge_plate_far")
	rig.foot = east + Vector3.FORWARD*1.25
	walk(rig,west+Vector3.FORWARD*1.25)
	var boxes: Vector3 = county.story_point("mailboxes")
	rig.foot = Vector3(boxes.x,0,county.story_point("house").z+5)
	walk(rig,boxes+Vector3.BACK)
	landmarks.append("mail_open")
	county.set_case_landmarks(landmarks)
	var lid: Node3D = county.case_models.mailboxes.get_node("Box6ALid")
	await create_timer(.50).timeout
	check(lid.rotation.x > 1.5,"the carrier's band swings into view inside the opened lid")
	rig.set_spawn(Vector3(441,0,-404))
	rig.in_cab = true
	for i in 1200:
		if rig.truck.position.z <= -540:
			break
		rig._drive(Vector2(0,-1),false,1.0/60.0)
	check(rig.truck.position.z <= -540,"wrecker can drive from the Swamp turn through the entire new spur")
	rig.in_cab = false
	rig.foot = rig.truck.position + Vector3.RIGHT*2
	walk(rig,county.story_point("tou")+Vector3.BACK*.85)
	walk(rig,county.story_point("last_cap")+Vector3.BACK*.75)
	rig.foot = Vector3(445,0,-467)
	walk(rig,county.story_point("angie")+Vector3.BACK)
	landmarks.erase("tou")
	landmarks.erase("angie")
	county.set_case_landmarks(landmarks)
	check(not county.case_models.has("tou") and not county.case_models.has("angie") and county.case_models.has("angie_house"),"both people can leave while the adopted house stays")
	county.set_lengthened(false)
	await process_frame
	await physics_frame
	check(county.sedan_tape.visible and county.case_models.mailboxes.get_node("Box6ALid").rotation.x > 1.5,"a rebuild retains the tape and open box")

func walk(rig: Node3D, target: Vector3) -> void:
	for tick in 1300:
		var delta: Vector3 = target-rig.foot
		delta.y = 0
		if delta.length()<.14:
			return
		var direction := delta.normalized().rotated(Vector3.UP,-rig.camera_yaw)
		rig._walk(Vector2(direction.x,direction.z),1.0/60.0)
	check(false,"walk from %s to %s" % [rig.foot,target])
