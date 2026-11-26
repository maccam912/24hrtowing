extends "res://tests/plat_pencil_test.gd"
const Highway := preload("res://scripts/tamarack_highway.gd")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game._action("rotation")
	rig = game.rig
	var ticket: Dictionary = game.job.duplicate(true)
	var old_pickup: Vector3 = rig.car.position
	rig.set_spawn(Vector3(800,0,2.4),-PI*.5)
	rig.in_cab = true
	var before: float = rig.odo
	for x in [1040,1280,1520,1760,1938]:
		drive_to(Vector3(x,0,2.4))
	drive_to(Vector3(1972,0,2.4))
	drive_to(Vector3(1980,0,20))
	drive_to(Highway.CURB)
	stop()
	var east_miles: float = rig.odo-before
	check(east_miles > 2.98 and east_miles < 3.12, "eastbound County FF to crew curb is three miles on the rig odometer")
	check(game.Rides.at_drop({"rider":"plow_relief"},rig.truck.position),"relief driver recognizes the normal entrance reached by the road")
	var curb: Vector3 = rig.truck.position
	rig.speed = 0
	game._refresh()
	game.desk._touch_mode = true
	await tap_control("map")
	await tap_control("turn_plat")
	await tap_control("plat_pencil")
	await tap_control("pencil_vehicle")
	await touch_sheet(Vector2(2001,24))
	check(game.plat_pencil.marks == [[2001,24,"vehicle"]],"the east sheet accepts a touch pencil mark at the garage")
	game.desk.dismiss()
	resume_shift()
	check(rig.truck.position.is_equal_approx(curb) and rig.car.position.is_equal_approx(old_pickup) and game.job.number==ticket.number,"east-end cold save preserves rig, original casualty and dispatched ticket")
	check(game.plat_pencil.marks == [[2001,24,"vehicle"]],"the eastern survey mark survives a cold save")
	for waypoint in [Vector3(2032,0,22),Vector3(2040,0,6),Vector3(2023,0,-2.4),Vector3(1790,0,-2.4),Vector3(1560,0,-2.4),Vector3(1325,0,-2.4),Vector3(1090,0,-2.4),Vector3(800,0,-2.4)]:
		drive_to(waypoint)
	stop()
	var round_trip: float = rig.odo-before
	check(round_trip>6.13 and round_trip<6.50,"round trip includes the full loop at the east service center and the three miles home")
	check(rig.truck.position.distance_to(Vector3(800,0,-2.4))<7,"westbound truck returns to County FF")
	check(game.county.ground_height(1770,0)==0.0 and game.county.ground_height(1770,9)<-.4,"new route has a plowed crown and a genuine ditch")
	check(game.Rides.target({"rider":"switchboard"})==Vector3(852,0,19) and game.Rides.target({})==Vector3(-71,0,14),"archived Memorial and original summer-driver tickets retain both old drop coordinates")
	game.free()
	if not failures:
		print("CHECKS PASSED — County FF to Tamarack east via throttle and steering, %.2f mi out, %.2f mi round trip, cold save and touch plat" % [east_miles,round_trip])
	quit(int(failures>0))
