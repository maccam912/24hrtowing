extends "res://tests/rig_test.gd"

class BankedRoad extends Node3D:
	var crossfall := 0.0
	func ground_height(x: float, _z: float) -> float: return x*crossfall
	func road_distance(_x: float, _z: float) -> float: return 0.0

var road := BankedRoad.new()

func run() -> void:
	root.add_child(road)
	rig = Rig.new()
	road.add_child(rig)
	rig.setup(road)
	await physics_frame
	for eye: int in [-1,1]:
		attach_vehicle("hazard",2,eye)
		var idle_pitch: float = rig.pitch
		require(idle_pitch > .014,"the rear tandem settles under the supported wagon axle")
		check_wheels(0.005)
		var max_articulation := 0.0
		for tick in 90:
			rig.speed = 5.
			rig.set_controls(Vector2(1,-.27),Vector2.ZERO,false,false,STEP)
			max_articulation = maxf(max_articulation,absf(bend()))
			check_baskets()
		require(max_articulation>.4 and max_articulation<=PI/3+.01,"the kingpin swings on a loaded turn")
		require(absf(rig.roll)>.006,"the body rolls under cornering load")
		check_wheels(.012)
		var rotations := tire_angles()
		rig.speed = -3.0
		for tick in 45: rig.set_controls(Vector2(-1,.8),Vector2.ZERO,false,false,STEP)
		check_baskets()
		for i in rig.road_wheels.hubs.size():
			var held := signf(rig.road_wheels.hubs[i].position.z)==eye
			require(is_equal_approx(rotations[i],tire_angles()[i]) == held,"only grounded wheels turn when backing")
		var resume: Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
		var attitude: Vector3 = rig.body.rotation
		rig.restore_state(resume)
		require(attitude.is_equal_approx(rig.body.rotation),"loaded ride height and attitude survive saving in a turn")
		resume.erase("ride")
		rig.restore_state(resume)
		require(rig.loaded and rig.line_end==eye and rig.body.crossbar.straps[0].visible,"an older loaded-tow save reattaches straps at the recorded eye")
		check_baskets()
		await test_clearance_pole()
	attach_vehicle("hold",0,-1)
	var parked := tire_angles()
	for tick in 90: rig.set_controls(Vector2(.6,-1),Vector2.ZERO,false,false,STEP)
	var after := tire_angles()
	for i in after.size(): require(is_equal_approx(after[i],parked[i]),"a dolly carries the locked tire")
	for cart: Node3D in rig.dollies.get_children():
		require(absf(cart.global_position.y-road.ground_height(cart.global_position.x,cart.global_position.z))<.001,"dolly tires roll on the road surface")
	check_wheels(.012)
	road.crossfall = .075
	attach_vehicle("hazard",4,1)
	require(absf(rig.roll-atan(road.crossfall))<.007,"the body settles to the shoulder crossfall")
	check_wheels(.012)
	check_baskets()
	road.queue_free()
	await process_frame
	await process_frame
	if not failed: print("CHECKS PASSED — both wheel-lift hookups, forward and reverse turns, six suspension contacts, rolling wheels, locked dollies, banked ground, obstacle clearance and saved hookups")
	quit(1 if failed else 0)

func attach_vehicle(kind: String, variant: int, eye: int) -> void:
	rig.end_job()
	rig._stop_motion()
	rig.set_spawn(Vector3.ZERO)
	var yaw := PI if eye > 0 else 0.
	rig.start_job(kind,Vector3(0,0,14),yaw,{"variant":variant,"heavy_recovery":variant==4})
	rig.snatch_block = true
	stand_at(rig.car.position+Vector3.RIGHT*2)
	operate("flare",rig.car.position+Vector3.UP)
	stand_at(rig._panel())
	operate("cable",rig._panel())
	var hook: Vector3 = rig._eyelet(eye)
	stand_at(hook+rig.car.global_basis.z*eye*.58)
	operate("attach",hook)
	stand_at(rig._panel())
	aim_at(rig._panel())
	for tick in 3000:
		if rig.phase != "rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,rig.tension<.94,false,STEP)
	require(rig.phase=="at_lift","winch brings the chosen axle to the stinger")
	if kind=="hold":
		stand_at(rig.car.position+rig.car.global_basis.x*1.55)
		operate("dollies",rig.car.position)
	stand_at(rig._panel())
	operate("lift",rig._panel())
	require(rig.line_end==eye and rig.loaded,"side controls secure the chosen axle")
	rig.in_cab = true
	for tick in 150: rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,STEP)

func bend() -> float:
	var axis: Vector3 = rig.body.crossbar.global_basis.z
	return angle_difference(rig.heading,atan2(axis.x,axis.z))

func tire_angles() -> Array[float]:
	var result: Array[float] = []
	for hub: Node3D in rig.road_wheels.hubs: result.append(hub.rotation.x)
	return result

func check_baskets() -> void:
	for i in 2:
		var side := -1. if i==0 else 1.
		var held: Node3D = rig.road_wheels.hubs[i*2 + (1 if rig.line_end>0 else 0)]
		var shoe: Node3D = rig.body.crossbar.shoes[i if rig.line_end<0 else 1-i]
		var supported: Vector3 = shoe.to_global(Vector3(0,.255,0))
		require(held.global_position.distance_to(supported)<.003,"both tires remain between their crossbar rails throughout the bend (side %.0f)" % side)

func check_wheels(tolerance: float) -> void:
	for wheel: Node3D in rig.body.wheels:
		var p := wheel.global_position
		require(absf(p.y-road.ground_height(p.x,p.z)-Rig.Truck.TIRE_RADIUS)<tolerance,"each tandem and steering tire follows the road through its own spring")
	for hub: Node3D in rig.road_wheels.hubs:
		if signf(hub.position.z)==rig.line_end: continue
		var p := hub.global_position
		var rise: float = Rig.Scene.RoadWheels.DOLLY_RISE if rig.dollies else 0.0
		require(absf(p.y-road.ground_height(p.x,p.z)-rig.road_wheels.radius-rise)<tolerance,"the trailing tires follow the road or dolly rollers")

func test_clearance_pole() -> void:
	var step: Vector3 = -rig.truck.global_basis.z*1.8
	var turn := .19
	var z: float = rig.line_end*rig.road_wheels.axle_z
	var pose: Transform3D = rig.forecast_tow(step,turn,z,-z)
	var size: Vector3 = rig.car.get_meta("body_size")
	var local := Vector3(size.x,.72,-rig.line_end*size.z)
	var target: Vector3 = rig.car.to_global(local).lerp(pose*local,.5)
	var pole := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.20,2,.20)
	collision.shape=shape
	pole.add_child(collision)
	road.add_child(pole)
	pole.position=target
	await physics_frame
	rig.loaded=false
	require(not rig._truck_obstacle(step,turn),"the wrecker clears the inside post")
	rig.loaded=true
	require(rig._truck_obstacle(step,turn),"the towed rear quarter catches that same post")
	require(not rig._truck_obstacle(-step,-turn),"the operator can back away from the post")
	pole.queue_free()
	await physics_frame
