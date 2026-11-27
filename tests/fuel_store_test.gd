extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game._action("interact")
	await physics_frame
	var counter: Vector3 = game.county.coffee_counter_point()
	var entrance: Vector3 = game.county.fuel_door.global_position
	var clerk: Node3D = game.county.county_model.get_node("MaiXiong")
	check(clerk.visible and clerk.get_node("AnimationPlayer").current_animation == "idle","Mai is at the counter")
	for pump: Vector3 in game.PUMP_ISLANDS:
		var lot := pump + Vector3.BACK*1.1
		stand(lot,entrance)
		game.county.follow_camera(rig.get_camera().global_position)
		check(not game.county.inside_fuel_store(rig.foot), "pump island stays outdoors")
		await walk_past_door(Vector3(entrance.x,0,entrance.z-1.2))
		await walk_past_door(counter+Vector3.FORWARD*.85)
		check(game.county.inside_fuel_store(rig.foot),"walk in from either diesel pump")
		face(counter)
		check(game.is_facing(counter,2.5),"the posted coffee counter is within reach")
		var eye: Vector3 = rig.get_camera().global_position
		check(rig.cast_ray(eye,clerk.global_position+Vector3.UP*1.60).is_empty(),"cashier visible above the service counter")
		# The collision at waist height keeps the clerk's side of the register private.
		for step in 45:
			rig._walk(Vector2.DOWN.rotated(rig.camera_yaw),DT)
		check(rig.foot.z < counter.z,"counter stops the operator")
		await walk_past_door(entrance+Vector3.FORWARD*1.4)
		await walk_past_door(lot)
		for step in 61:
			game.county.fuel_door.sense(lot+Vector3.UP*1.7,DT)
		check(not game.county.inside_fuel_store(rig.foot) and is_zero_approx(game.county.fuel_door.travel),"door closes behind the operator in the forecourt")
	check(not game.county.inside_fuel_store(counter+Vector3.UP*5),"roof is outside the heated room")
	game.free()
	if not failures:
		print("CHECKS PASSED — diesel pump to coffee counter, automatic entrance, shelter and clerk")
	quit(int(failures > 0))

func walk_past_door(target: Vector3) -> void:
	for step in 330:
		var direction: Vector3 = target-rig.foot
		direction.y = 0.0
		if direction.length() < .15:
			return
		var move := direction.normalized().rotated(Vector3.UP,-rig.camera_yaw)
		rig.set_controls(Vector2(move.x,move.z),Vector2.ZERO,false,false,DT)
		game.county.follow_camera(rig.get_camera().global_position)
		await physics_frame
	check(false,"entry blocked walking from %s to %s" % [rig.foot,target])
