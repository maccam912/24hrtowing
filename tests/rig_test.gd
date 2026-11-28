extends SceneTree

const Rig = preload("res://scripts/rig.gd")
const STEP := 1.0 / 60.0
const TEST_SPEED := 12.0
var rig
var failed := false

class TestRoad extends Node3D:
	func road_distance(x: float, _z: float) -> float:
		return absf(x)

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("CHECK FAILED: ", message)

func run() -> void:
	var floor_world := TestRoad.new()
	root.add_child(floor_world)
	rig=Rig.new()
	floor_world.add_child(rig)
	rig.setup(floor_world)
	await physics_frame
	test_footsteps()
	test_road_speed()
	var empty := drive_sample(false)
	var heavy := drive_sample(true)
	require(heavy.accel_seconds > empty.accel_seconds * 1.3, "underlift load changes acceleration")
	require(heavy.braking > empty.braking * 1.18, "same-speed loaded braking needs more road")
	require(heavy.yaw < empty.yaw * .95, "loaded front axle steers lighter at the same entry speed")
	var utility := drive_sample(true,true)
	require(utility.accel_seconds > heavy.accel_seconds * 1.2, "utility pickup takes longer to accelerate than a sedan")
	require(utility.braking > heavy.braking * 1.15, "utility pickup needs more stopping distance than a sedan")
	rig.tire_chains=true
	var chained := drive_sample(false)
	require(chained.braking < empty.braking * .83 and chained.yaw > empty.yaw * 1.15, "fitted chains improve braking and corner grip")
	require(rig.body.wheel_chains.size() == 4 and rig.body.wheel_chains[0].visible, "chains wrap the tandem drive wheels")
	var snow_chained := snow_run()
	rig.tire_chains=false
	var snow_stock := snow_run()
	require(snow_chained > snow_stock*1.24, "chains pull the truck through deep snow faster")
	test_axle_steering()
	test_line()
	test_double_line()
	test_impossible_recoveries()
	test_sighting_interference()
	test_beacons()
	test_departing_driver()
	if not failed:
		print("CHECKS PASSED — steering, braking, cable relief, chains, utility, field, ice and boom recoveries, truck electrics and customer departures. Stops from 12 m/s: empty %.1f m / chained %.1f m / sedan %.1f m / utility %.1f m." % [empty.braking,chained.braking,heavy.braking,utility.braking])
	quit(1 if failed else 0)

func test_footsteps() -> void:
	var parked: Dictionary = rig.save_state()
	rig.interact()
	var sounds: Array[String] = []
	var listen := func(id: String): sounds.append(id)
	rig.sound_event.connect(listen)
	for tick in 360:
		rig.set_controls(Vector2.LEFT,Vector2.ZERO,false,false,STEP)
	var full_speed := sounds.count("footstep")
	require(full_speed in [9,10,11], "full-speed walking sounds about ten steps in six seconds")
	sounds.clear()
	for tick in 360:
		rig.set_controls(Vector2.LEFT*.5,Vector2.ZERO,false,false,STEP)
	require(sounds.count("footstep") in [4,5,6], "half-speed walking spaces steps farther apart in time")
	sounds.clear()
	for tick in 120:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,STEP)
	require(not sounds.has("footstep"), "standing still is quiet")
	rig.sound_event.disconnect(listen)
	rig.restore_state(parked)

func test_road_speed() -> void:
	for hauling: bool in [false, true]:
		rig.loaded = hauling
		rig.set_spawn(Vector3(0, 0, 900))
		rig.speed = 0.0
		rig.motion = Vector3.ZERO
		var seconds_to_35 := 0.0
		var seconds_to_40 := 0.0
		var peak_mph := 0.0
		for tick in 3900:
			rig.set_controls(Vector2.UP, Vector2.ZERO, false, false, STEP)
			var mph: float = rig.get_status().speed_mph
			peak_mph = maxf(peak_mph, mph)
			if mph >= 35.0 and seconds_to_35 == 0.0:
				seconds_to_35 = (tick + 1) * STEP
			if mph >= 39.99 and seconds_to_40 == 0.0:
				seconds_to_40 = (tick + 1) * STEP
		if hauling:
			require(peak_mph >= 33.0 and peak_mph < 35.0, "a regular tow stays below 35 mph on a long straight")
		else:
			require(seconds_to_35 >= 30.0, "35 mph takes sustained full throttle")
			require(seconds_to_40 >= seconds_to_35 + 12.0, "the last five mph come gradually")
			require(peak_mph >= 39.99 and peak_mph <= 40.01, "empty truck tops out at 40 mph")
			print("Full throttle from rest: 35 mph at %.1f s, 40 mph at %.1f s." % [seconds_to_35, seconds_to_40])
	rig.loaded = false

func drive_sample(hauling: bool, heavy_recovery := false) -> Dictionary:
	rig.end_job()
	rig.set_spawn(Vector3.ZERO)
	rig.loaded=hauling
	rig.vehicle_identity["heavy_recovery"]=heavy_recovery
	rig.speed=0
	rig.motion=Vector3.ZERO
	rig.steering=0
	var ticks:=0
	while rig.speed<TEST_SPEED and ticks<1800:
		rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,STEP)
		ticks+=1
	require(ticks<1800,"operating speed attainable")
	var start:Vector3=rig.get_truck_position()
	for i in 350:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,STEP)
	var stopping_distance:=start.distance_to(rig.get_truck_position())
	require(rig.speed<.01,"brake reaches a standstill")
	# Start both cornering passes at exactly the same velocity and heading.
	rig.set_spawn(Vector3.ZERO)
	rig.speed=TEST_SPEED
	rig.motion=Vector3.FORWARD*TEST_SPEED
	for i in 36:
		rig.set_controls(Vector2(.7,0),Vector2.ZERO,false,false,STEP)
	return {"accel_seconds":ticks*STEP,"braking":stopping_distance,"yaw":absf(rig.heading)}

func snow_run() -> float:
	rig.end_job()
	rig.set_spawn(Vector3(60,0,0))
	rig.speed=0
	rig.motion=Vector3.ZERO
	rig.steering=0
	for tick in 420:
		rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,STEP)
	return rig.speed

func test_axle_steering() -> void:
	rig.end_job()
	var front := Vector3.BACK * Rig.Truck.FRONT_AXLE_Z
	var rear := Vector3.BACK * Rig.Truck.REAR_AXLE_Z
	for direction: float in [1.0, -1.0]:
		rig.set_spawn(Vector3.ZERO)
		rig.speed = 0.0
		rig.motion = Vector3.ZERO
		rig.steering = 0.0
		for i in 60:
			rig.set_controls(Vector2.RIGHT,Vector2.ZERO,false,false,STEP)
		require(is_zero_approx(rig.heading) and rig.truck.position.is_zero_approx(), "turning the wheel at rest leaves the truck parked")
		var left: Node3D = rig.body.wheels[0].get_parent_node_3d()
		var right: Node3D = rig.body.wheels[3].get_parent_node_3d()
		require(right.rotation.y < left.rotation.y and left.rotation.y < -.4, "inside front wheel turns more sharply at parking lock")
		rig.speed = direction * 2.8
		for i in 12:
			rig.set_controls(Vector2.RIGHT,Vector2.ZERO,false,false,STEP)
		var front_travel: Vector3 = rig.truck.to_global(front) - front
		var rear_travel: Vector3 = rig.truck.to_global(rear) - rear
		require(front_travel.x * direction > .30, "steered axle swings into the forward or reverse arc")
		require(absf(rear_travel.x) < .04 and rear_travel.z * direction < -.49, "rear tandem rolls along its heading at yard speed")
		require(rig.heading * direction < -.06, "backing up reverses yaw with the same steering lock")
		require(rig.body.wheels[3].basis.x.is_equal_approx(Vector3.RIGHT), "wheel spin stays on its own axle at full lock")
	rig.steering = 0.0

func walk_to(point:Vector3) -> void:
	for i in 950:
		var delta:Vector3=point-rig.get_player_position()
		delta.y=0
		if delta.length()<.12:
			return
		var local:=delta.normalized().rotated(Vector3.UP,-rig.camera_yaw)
		rig.set_controls(Vector2(local.x,local.z),Vector2.ZERO,false,false,STEP)
	require(false,"path to the gear is walkable")

func aim_at(point:Vector3) -> void:
	var dir:Vector3=point-rig.get_camera().global_position
	var yaw:=atan2(-dir.x,-dir.z)
	var pitch:=atan2(dir.y,Vector2(dir.x,dir.z).length())
	var look:=Vector2(wrapf(rig.camera_yaw-yaw,-PI,PI),rig.camera_pitch-pitch)
	rig.set_controls(Vector2.ZERO,look,false,false,STEP)

func operate(expected: String, at: Vector3) -> void:
	aim_at(at)
	require(rig.action_id()==expected,"operator can "+expected)
	rig.interact()

func test_line() -> void:
	rig.set_spawn(Vector3.ZERO)
	rig.speed=0
	rig.motion=Vector3.ZERO
	rig.start_job("hazard",Vector3(-5,0,14),.15)
	rig.interact()
	walk_to(Vector3(-3,0,9))
	operate("flare",rig.car.position+Vector3.UP)
	walk_to(Vector3(-2.1,0,2.35))
	operate("cable",rig.panel_point())
	walk_to(Vector3(-4.8,0,10.8))
	operate("attach",rig.eyelet_point(-1))
	walk_to(Vector3(-2.1,0,2.35))
	aim_at(rig.panel_point())
	var initial:Vector3=rig.car.position
	for i in 160:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,STEP)
	var taut:float=rig.tension
	require(taut>.35 and initial.distance_to(rig.car.position)>.5,"tension moves the disabled vehicle")
	var snow := rig.car.get_node_or_null("SettledSnow") as Node3D
	require(snow != null and snow.global_position.is_equal_approx(initial), "the winch pulls the car out of its drift")
	for i in 54:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,STEP)
	require(rig.tension<taut-.3,"releasing the drum eases line pressure")

func test_double_line() -> void:
	var ticket := {"variant":4,"heavy_recovery":true,"plate":"HWY 212","vin":"HWY212"}
	rig.set_spawn(Vector3.ZERO)
	rig.start_job("hazard",Vector3(-5,0,14),.15,ticket)
	require(rig.car.name=="UtilityPickup" and rig.car.get_meta("plate")==ticket.plate,
		"utility pickup gets its service body and its own plate")
	require(rig.beacons_active(), "approaching a checked pickup flashes the wrecker beacons")
	rig.in_cab=false
	walk_to(Vector3(-3,0,9))
	operate("flare",rig.car.position+Vector3.UP)
	walk_to(Vector3(-2.1,0,2.35))
	operate("need_block",rig.panel_point())
	require(rig.phase=="flared","heavy pull cannot start on the stock line")
	rig.snatch_block=true
	operate("cable",rig.panel_point())
	walk_to(Vector3(-4.8,0,10.8))
	operate("attach",rig.eyelet_point(-1))
	walk_to(Vector3(-2.1,0,2.35))
	aim_at(rig.panel_point())
	var saved: Dictionary = rig.save_state()
	rig.restore_state(saved)
	require(rig.vehicle_identity.heavy_recovery and rig.car.get_meta("body_size")==Rig.Scene.PICKUP_SIZE,
		"resuming the rigged utility job keeps the heavy load and its geometry")
	var initial: Vector3 = rig.car.position
	for i in 180:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,STEP)
	require(rig.cable_mesh.get_surface_count()==2 and rig.pulley.visible and rig.pulley.global_position.distance_to(rig.eyelet_point(-1))<.25,
		"both parts of the line pass through the block at the tow eye")
	require(initial.distance_to(rig.car.position)>.5,"fitted block pulls the heavier utility truck")
	for i in 1800:
		if rig.phase=="at_lift": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,STEP)
	require(rig.phase=="at_lift","double-line pull brings the utility pickup to the underlift")
	operate("lift",rig.panel_point())
	require(rig.loaded,"heavy utility pickup can be secured for the return haul")

func stand_at(at: Vector3) -> void:
	rig.in_cab=false
	rig.foot=Vector3(at.x,0,at.z)
	rig.update_eyes()
	aim_at(at)

func test_impossible_recoveries() -> void:
	var modes := ["ice","roll","nose","roof","tree","gate"]
	for recovery: String in modes:
		var ice := recovery=="ice"
		var raised := recovery in ["roof","tree"]
		var rolling := recovery in ["roll","nose"]
		var point := Vector3(-2,6.75 if raised else 0.0,43.0 if ice else 14.0)
		rig.set_spawn(Vector3.ZERO)
		rig.start_job("hazard",point,.12,{"recovery":recovery, "running":true, "heavy_recovery": rolling or recovery=="tree"})
		rig.snatch_block=true
		require(rig.car_lamps.get_node_or_null("TailpipeVapor")!=null, recovery+" still runs at the site")
		stand_at(rig.panel_point() if ice or raised else rig.car.position+Vector3.LEFT*2.5)
		operate("flare",rig.panel_point() if ice or raised else rig.car.position)
		stand_at(rig.panel_point())
		operate("cable",rig.panel_point())
		if recovery == "tree":
			var sling: Vector3 = rig.tree_recovery.eye
			stand_at(sling)
			operate("tree_block",sling)
			stand_at(rig.panel_point())
			operate("tree_boom",rig.panel_point())
		elif raised:
			operate("sling",rig.panel_point())
		elif rolling:
			stand_at(rig.side_eye(-1))
			operate("roll_hook",rig.side_eye(-1))
			stand_at(rig.side_eye(1))
			operate("check_line",rig.side_eye(1))
		else:
			var eye: Vector3 = rig.eyelet_point(-1)
			stand_at(eye+Vector3.FORWARD*.60)
			operate("attach",eye)
		stand_at(rig.panel_point())
		aim_at(rig.panel_point())
		if raised or rolling:
			var command := Vector2.UP if recovery == "tree" else Vector2.ZERO
			for tick in (25 if recovery == "tree" else 150): rig.set_controls(command,Vector2.ZERO,true,false,STEP)
			var reserve: float = rig.fuel
			rig.fuel = Rig.WINCH_FUEL_PER_SECOND * STEP * .5
			rig.set_controls(command,Vector2.ZERO,true,false,STEP)
			var before: float = rig.special_work
			var pose: Transform3D = rig.car.transform
			for tick in 90: rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,STEP)
			require(rig.fuel == 0.0 and not rig.working and rig.tension == 0.0 and rig.special_work == before and pose.is_equal_approx(rig.car.transform),
				recovery+" stops and holds the casualty when the PTO runs dry")
			rig.fuel = reserve
			rig.restore_state(rig.save_state())
			require(before>0 and rig.special_work==before and pose.is_equal_approx(rig.car.transform),
				recovery+" resumes partway through rigging with its pose intact")
		if recovery == "tree":
			stand_at(rig.panel_point())
			operate("tree_boom",rig.panel_point())
			for tick in 120: rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,STEP)
			for tick in 460: rig.set_controls(Vector2.RIGHT,Vector2.ZERO,false,false,STEP)
			for tick in 650:
				if not rig.tree_recovery.controls: break
				rig.set_controls(Vector2.DOWN,Vector2.ZERO,false,false,STEP)
			stand_at(rig.panel_point())
		for tick in 3500:
			if rig.phase=="at_lift": break
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,STEP)
		require(rig.phase=="at_lift",recovery+" reaches the underlift")
		require(absf(rig.car.rotation.z)<.001 and absf(rig.car.rotation.x)<.001,recovery+" comes down upright")
		operate("lift",rig.panel_point())
		require(rig.loaded,recovery+" can be strapped for the haul")
		rig.end_job()

func test_sighting_interference() -> void:
	rig.set_spawn(Vector3.ZERO)
	rig.in_cab=false
	rig.warmth=.40
	rig.set_sighting(1.0,Vector3(200,40,0),1.0)
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,STEP)
	require(rig.warmth>.40 and rig.body.headlamps[0].light_energy<.1,"the windless air warms Brandt while the lamps go dark")
	require(absf(rig.get_status().heading-90)<.1 and rig.engine_rpm>500,"dash compass points at the lights while the diesel idles")
	rig.set_sighting(0.0,Vector3.INF,0.0)
	require(rig.body.headlamps[0].light_energy>3 and absf(rig.get_status().heading)<.1,"headlights and compass recover")

func test_beacons() -> void:
	rig.in_cab = true
	rig.set_spawn(Vector3.ZERO)
	rig.start_job("hazard",Vector3(0,0,12),0)
	require(rig.beacons_active(), "a nearby pickup flashes the wrecker beacons")
	rig.beacon_target = Vector3(0,0,160)
	require(not rig.beacons_active(), "a selected stop takes priority over the nearby pickup")
	rig.loaded = true
	require(not rig.beacons_active(), "a car on the hook does not activate distant destination guidance")
	rig.beacon_target = Vector3(0,0,60)
	require(rig.beacons_active(), "approaching the delivery point flashes the wrecker beacons")
	rig.beacon_target = Vector3.INF
	require(not rig.beacons_active(), "without a destination a loaded car does not trigger the proximity cue")
	rig.end_job()

func test_departing_driver() -> void:
	rig.set_spawn(Vector3.ZERO)
	var site := Vector3(10,0,15)
	rig.start_job("ditch",site,0,{"vin":"FIRST","variant":1})
	require(rig.beacons_active(), "an accepted ditch pull flashes nearby proximity beacons")
	var snapshot: Dictionary = rig.save_state()
	rig.restore_state(snapshot)
	require(rig.beacons_active(), "an outbound save keeps the pickup's proximity beacons active")
	snapshot.phase = "departing"
	snapshot.driver_boarded = false
	rig.restore_state(snapshot)
	require(not rig.beacons_active(), "a departing customer clears the pickup cue")
	var driver: Node3D = rig.witness
	var customer_car: Node3D = rig.car
	var original: Vector3 = driver.position
	rig.start_job("hazard",Vector3(40,0,10),0,{"vin":"NEXT"})
	require(rig.beacons_active(), "the newly assigned car activates the wrecker's proximity beacons")
	require(not customer_car.is_queued_for_deletion() and not driver.is_queued_for_deletion(),
		"taking a new tow keeps the previous customer and car on the road")
	rig._trail(STEP)
	require(driver.position.distance_to(original)>0 and customer_car.position.is_equal_approx(site),
		"the previous customer continues walking to the car while the new tow is active")
	snapshot = JSON.parse_string(JSON.stringify(rig.save_state()))
	rig.restore_state(snapshot)
	require(rig.departures.size()==1 and rig.departures[0].identity.vin=="FIRST" and rig.vehicle_identity.vin=="NEXT",
		"resume restores the departing customer independently of the active tow")
	var waiting: Vector3 = rig.car.position
	for i in 720:
		rig._trail(STEP)
	if rig.departures.is_empty():
		require(false, "the previous customer remains visible within the storm horizon")
		return
	var released = rig.departures[0]
	require(not released.witness.visible and released.car.position.distance_to(site)>25.0 and rig.car.position.is_equal_approx(waiting),
		"the released car drives away while the next vehicle stays at its site")
	for i in 1800:
		rig._trail(STEP)
	require(rig.departures.is_empty() and rig.phase=="scene", "a departing driver clears the horizon independently of the current call")
