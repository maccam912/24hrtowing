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
	check(not county.survey_pickup.visible and not county.tripod.visible,"collecting evidence removes it from the turnout")
	check(county.road_distance(442,336)<.01 and county.map_places().any(func(place): return "N5104" in place.name),"the Hoffmann place is reachable on the original plat")
	var approach := Vector3(408,0,336)
	var door := county.story_point("house")
	var ring := county.story_point("farm_ring")
	rig.foot = approach
	walk(rig,Vector3(ring.x,0,approach.z))
	walk(rig,ring)
	walk(rig,Vector3(ring.x,0,approach.z))
	walk(rig,Vector3(door.x,0,approach.z))
	walk(rig,door+Vector3.BACK*.4)
	walk(rig,door+Vector3.FORWARD*.5)
	await check_case_landmarks(county,rig)
	var identity := {"variant":2,"driver_variant":1,"plate":"ARB 608","vin":"2BRWK15P7PB226310"}
	rig.start_job("ditch",Vector3(9,0,140),.31,identity)
	var state: Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
	rig.restore_state(state)
	check(rig.car.get_meta("plate")==identity.plate and rig.vehicle_identity.variant==2,"restored ditch car keeps its assigned wagon and plate")
	var parked := rig.store_vehicle("hazard",Vector3.ZERO,0,identity)
	check(parked.get_meta("vin")==identity.vin,"stored car retains the ticket VIN")
	if not failed:
		print("CHECKS PASSED — walk the survey sites, tank ladder and porches; drive Alder Cut; persist physical case evidence")
	quit(1 if failed else 0)

func check_case_landmarks(county: Node3D, rig: Node3D) -> void:
	var landmarks := ["car_ring","hoffmann_ring","carrier_prints","last_cap","tou","angie"]
	var alder = county.map_roads().filter(func(r): return r.name == "Alder Cut Rd")
	check(alder.size()==1 and alder.front().points[-1].y > -490,"the printed Alder road stops at N5420")
	check(county.road_distance(441,-505) > 20 and county.case_models.has("angie_house"),"the house predates discovery of the logging road")
	county.set_case_landmarks(landmarks)
	await process_frame
	await physics_frame
	await physics_frame
	check(county.case_models.has("car_ring") and county.case_models.hoffmann_ring.has_node("HoffmannSedan"),"the car ring includes the missing blue sedan")
	check(county.case_models.mailboxes != null and county.case_models.carrier_prints != null,"the mail route has a witness trail and its pair of boxes")
	check(not county.survey_pickup.visible and not county.tripod.visible and is_equal_approx(county.rod_case.rotation.x,PI),"rebuilding the logging road preserves custody and the rod case")
	var ladder: Vector3 = county.story_point("tower_ladder")
	rig.foot = ladder+Vector3.RIGHT*5
	walk(rig,ladder+Vector3.RIGHT*.6)
	var boxes: Vector3 = county.story_point("mailboxes")
	rig.foot = Vector3(boxes.x,0,county.story_point("house").z+5)
	walk(rig,boxes+Vector3.BACK)
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

func walk(rig: Node3D, target: Vector3) -> void:
	for tick in 1300:
		var delta: Vector3 = target-rig.foot
		delta.y = 0
		if delta.length()<.14:
			return
		var direction := delta.normalized().rotated(Vector3.UP,-rig.camera_yaw)
		rig._walk(Vector2(direction.x,direction.z),1.0/60.0)
	check(false,"walk from %s to %s" % [rig.foot,target])
