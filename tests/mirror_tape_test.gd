extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	var lines = game.Rig.Scene.Tape
	check(lines.write("County K",0,0,true).date == "01/14" and lines.write("County K",0,22*3600.,true).date == "01/15","a deputy dates the check when the order is written")
	var original: Dictionary = game.sightings.aftermath.tape_swamp
	var details: Dictionary = original.vehicle.checked_tape.duplicate()
	check(details.road == "Swamp Rd" and details.date == "01/13","a longstanding roadside car carries the previous night's physical check")
	game.sightings._record("field_car",Vector3(383,0,275),PI,20,0,"Kolpack Rd",original.vehicle,"moved_test")
	var order: Dictionary = game.sightings.recovery_offer(22,game.county,true,false)
	check(order.checked_tape == details and order.road == "Kolpack Rd","a displaced sedan keeps the deputy's original road")
	game.accept(order)
	rig.phase = "flared"
	rig.in_cab = false
	var strip: Node3D = rig.car.get_node("SheriffTape")
	rig.car.rotation = Vector3.ZERO
	var at := strip.global_position
	stand(at+Vector3.LEFT*1.0,at)
	game._refresh()
	check(game._site_action() == "checked_tape","reading the tape is available at the driver's mirror")
	await tap_control("interact")
	check(game.desk.page == "checked_tape" and game.state.checked_tape.road == "Swamp Rd" and game.state.checked_tape.plate == order.plate,"unfolding the tape reads the right car at the right mirror")
	await tap_control("close")
	rig.in_cab = true
	game._recovered("hazard")
	game._dropped()
	var saved: Dictionary = game.stored.back()
	check(saved.checked_tape == details and not saved.untaped,"the very same tape goes into the yard with the car")
	resume_shift()
	var yard_strip: Node3D = game.physical_cars.back().get_node("SheriffTape")
	check(yard_strip.get_meta("imprint") == details and game._current_slip().checked_tape == details,"a cold restart keeps both mirror and county carbon")
	var bare: Node3D = rig.store_vehicle("field",Vector3(36,0,46),0,{"untaped":true,"variant":1})
	check(not bare.has_node("SheriffTape"),"an unchecked recovery stays bare in storage")
	var old: Node3D = rig.store_vehicle("river",Vector3(40,0,46),0,{"variant":1})
	check(old.get_node("SheriffTape").get_meta("imprint").date == "11/23","an older impound retains the original date and Kowalski's badge")
	game.free()
	if not failures:
		print("CHECKS PASSED — the checked car, moved car, yard mirror and tow record share one strip")
	quit(int(failures > 0))
