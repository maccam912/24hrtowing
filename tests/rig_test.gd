extends SceneTree

const Rig = preload("res://scripts/rig.gd")
const STEP := 1.0 / 60.0
const TEST_SPEED := 12.0
var rig
var failed := false

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("CHECK FAILED: ", message)

func run() -> void:
	var floor_world := Node3D.new()
	root.add_child(floor_world)
	rig=Rig.new()
	floor_world.add_child(rig)
	rig.setup(floor_world)
	await physics_frame
	test_footsteps()
	var empty := drive_sample(false)
	var heavy := drive_sample(true)
	require(heavy.accel_seconds > empty.accel_seconds * 1.3, "underlift load changes acceleration")
	require(heavy.braking > empty.braking * 1.18, "same-speed loaded braking needs more road")
	require(heavy.yaw < empty.yaw * .95, "loaded front axle steers lighter at the same entry speed")
	test_axle_steering()
	test_line()
	if not failed:
		print("CHECKS PASSED — front steering and rear axle paths in both gears, 12 m/s braking %.1f m empty / %.1f m loaded, cable and tension relief" % [empty.braking,heavy.braking])
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

func drive_sample(hauling: bool) -> Dictionary:
	rig.end_job()
	rig.set_spawn(Vector3.ZERO)
	rig.loaded=hauling
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
	operate("cable",rig._panel())
	walk_to(Vector3(-4.8,0,10.8))
	operate("attach",rig._eyelet(-1))
	walk_to(Vector3(-2.1,0,2.35))
	aim_at(rig._panel())
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
