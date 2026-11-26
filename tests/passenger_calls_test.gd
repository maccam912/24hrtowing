extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game.desk._touch_mode = true
	rig = game.rig
	var history := []
	var riders := {}
	var summer_calls := 0
	for n in 180:
		var call: Dictionary = game.Dispatch.ordinary(n,23,history,true)
		history.append(game.Dispatch.issue_slip(call,100,101,103,0,"03:30"))
		if call.kind != "passenger":
			continue
		var rider: Dictionary = game.Rides.rider(call)
		check(rider.person.to_lower() in call.dispatch.to_lower() or rider.id == "summer_driver","radio names the requested passenger")
		check(game.Rides.destination(call) in call.dispatch and history.back().rider == rider.id,"ticket, destination and filed ride match")
		if rider.id == "summer_driver":
			summer_calls += 1
		else:
			riders[rider.id] = call
	check(riders.size() == 4 and summer_calls == 1,"four rotating rural riders without a second summer-driver encounter")
	for who: String in ["switchboard","creamery"]:
		await ride_to_counter(riders[who])
	# Old summer rides used the job kind and model, without a destination key.
	var legacy: Dictionary = riders.switchboard.duplicate(true)
	legacy.erase("rider")
	legacy.id = "summer_driver"
	legacy.driver_variant = 2
	check(game.Rides.destination(legacy) == "Esker Fuel & Food","legacy summer ride keeps the original destination")
	game.free()
	if not failures:
		print("CHECKS PASSED — recurring passenger calls, walking both doors, physical drops, continued rotation and saved pedestrians")
	quit(int(failures > 0))

func ride_to_counter(call: Dictionary) -> void:
	game._accept(call)
	var driver: Vector3 = rig.get_witness_position()
	rig.set_spawn(driver+Vector3(5,0,7))
	inspect_at("offer_ride",driver)
	check(rig.phase == "boarding" and rig.witness.visible,"driver starts outside the cab")
	for tick in 55:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	var walking: Vector3 = rig.witness.position
	check(walking.distance_to(driver) > .5,"the person actually walks to the passenger side")
	resume_shift()
	check(rig.phase == "boarding" and rig.witness.position.is_equal_approx(walking),"restart resumes the walk from the same prints")
	for tick in 1000:
		if rig.phase == "passenger": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.phase == "passenger" and not rig.witness.visible and rig.survey_passenger.visible,"one person reaches a visible cab seat")
	var inside_model: int = rig.survey_passenger.get_meta("model")
	resume_shift()
	check(rig.phase == "passenger" and rig.survey_passenger.get_meta("model")==inside_model and rig.survey_passenger.get_node("AnimationPlayer").current_animation=="seated","restart keeps the rider and seated animation")
	rig.in_cab = true
	var curb: Vector3 = game.Rides.target(call)
	rig.set_spawn(Vector3(curb.x,0,0))
	game._survey()
	check(game._site_action() != "let_out" and game.mode == "fieldwork","stopping on the highway does not drop anyone at a building")
	rig.set_spawn(curb)
	rig.speed = .7
	check(game._site_action() != "let_out","a moving wrecker keeps the door closed")
	rig.speed = 0
	game._survey()
	check(game._site_action()=="let_out" and game.mode == "fieldwork","the passenger waits for the operator to use the latch")
	game._refresh()
	await tap_control("interact")
	check(game.mode == "available" and not rig.exiting_riders.is_empty() and not rig.survey_passenger.visible,"front seat is empty and the rider is walking when rotation reopens")
	var slip: Dictionary = game.pending_slips.back()
	check(slip.number == call.number and slip.pay == 38 and slip.destination == game.Rides.destination(call),"one county transport slip pays the call-out without a hookup")
	game._action("rotation")
	check(game.mode == "fieldwork","take another call before the passenger reaches the door")
	for tick in 40:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	var sidewalk: Vector3 = rig.exiting_riders[0].person.position
	resume_shift()
	check(rig.exiting_riders.size() == 1 and rig.exiting_riders[0].person.position.is_equal_approx(sidewalk),"pedestrian and next ticket both survive a cold save")
	var last: Vector3 = sidewalk
	for tick in 1600:
		if rig.exiting_riders.is_empty(): break
		last = rig.exiting_riders[0].person.position
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.exiting_riders.is_empty() and last.distance_to(game.Rides.inside_door(call)) < .30,"rider crosses the actual doorway before leaving the scene")
