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
	var empty := drive_sample(false)
	var heavy := drive_sample(true)
	require(heavy.accel_seconds > empty.accel_seconds * 1.3, "underlift load changes acceleration")
	require(heavy.braking > empty.braking * 1.18, "same-speed loaded braking needs more road")
	require(heavy.yaw < empty.yaw * .95, "loaded front axle steers lighter at the same entry speed")
	test_line()
	if not failed:
		print("CHECKS PASSED — at 12 m/s, empty braking %.1f m, loaded %.1f m; control, cable and tension relief" % [empty.braking,heavy.braking])
	quit(1 if failed else 0)

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
	for i in 54:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,STEP)
	require(rig.tension<taut-.3,"releasing the drum eases line pressure")
