extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.dispatch_seed = 841
	game._action("play")
	rig = game.rig

	var history := []
	var first_history := []
	var plates := {}
	var previous := -1
	for i in 62:
		var ticket: Dictionary = game.Dispatch.ordinary(i,game.dispatch_seed,history)
		if ticket.id == "squad_pull":
			if previous<0:
				first_history = history.duplicate(true)
			check(previous<0 or i-previous >= 17, "response calls have ordinary shifts between them")
			previous = i
			plates[ticket.plate] = true
		history.append(game.Dispatch.issue_slip(ticket,100,101,102,10,"03:54"))
	check(first_history.size() >= 12 and plates.size() == 2, "two different deputies rotate after the early calls")
	if first_history.is_empty():
		game.free()
		quit(1)
		return
	game.slips = first_history
	game.completed = first_history.size()
	game.rotation_offer = {}
	game._prepare_offers()
	game._action("radio")
	game.desk._activate("respond")
	var job: Dictionary = game.job
	check(job.id == "squad_pull" and job.person in ["Deputy Pelz","Deputy Ruiz"] and "Regular rate either way" in job.dispatch,"county explains the optional bonus over the radio")
	check(rig.car.get_meta("patrol",false) and rig.car.get_meta("plate") == job.plate and rig.witness != null,"marked patrol car and deputy match the call")
	# Stage on the road, with the rear controls facing the shoulder.
	var target: Vector3 = rig.car.position
	var roadward := Vector3(12,0,-signf(target.z)*8).normalized()
	rig.set_spawn(target+roadward*18,atan2(-roadward.x,-roadward.z))
	game._physics_process(1.0)
	game._action("interact")
	var officer: Vector3 = rig.get_witness_position()
	stand(officer + Vector3.FORWARD,officer)
	game._action("interact")
	check(game.speaker == job.person.to_upper(), "assigned deputy speaks at the car")
	game._physics_process(.5)
	check(game.job.clearance_seconds == 0, "arrival and conversation before the flare are off the clock")
	stand(target+rig.car.global_basis.x*2.2,target)
	game._action("interact")
	check(rig.phase == "flared","scene work starts with the player's flare")
	game._physics_process(.25)
	var elapsed: float = game.job.clearance_seconds
	game.desk._activate("slip")
	game._physics_process(1.)
	check(elapsed > 0 and game.job.clearance_seconds == elapsed,"reading the slip stops the scene clock")
	game.desk.dismiss()
	var panel: Vector3 = rig._panel()
	stand(panel-rig.truck.global_basis.x,panel)
	game._action("interact")
	var end := 1 if roadward.dot(rig.car.global_basis.z)>0 else -1
	var eye: Vector3 = rig._eyelet(end)
	stand(eye+rig.car.global_basis.z*end,eye)
	game._action("interact")
	stand(panel-rig.truck.global_basis.x,panel)
	resume_shift()
	check(rig.phase == "rigged" and game.job.clearance_seconds == elapsed,"a saved line keeps the county's elapsed time")
	game._save()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	for late in [false,true]:
		if late:
			game._restore(snapshot)
			for tick in 610:
				game._physics_process(.20)
			check(game.job.clearance_seconds>120 and rig.phase == "rigged","taking longer keeps the same recoverable car")
		game.desk._touches[0] = {"id":"work"}
		for tick in 2400:
			if rig.phase != "rigged": break
			game._physics_process(DT)
		game.desk._touches.clear()
		if game.pending_slips.size() != 1:
			check(false,"squad clears for the next job")
			break
		var slip: Dictionary = game.pending_slips[0]
		var base: float = slip.call_out + slip.hookup + slip.winch
		check(slip.loaded == 0 and slip.storage == 0 and slip.clearance_bonus == (0 if late else game.Dispatch.Squad.PREMIUM) and slip.pay == base+slip.clearance_bonus,"only the optional premium changes")
		file_at_office()
		check(game.faxes.back().contains("Bonus  $%.2f" % slip.clearance_bonus) and game.account.earned == slip.pay,"fax records and pays the early or late result exactly once")
		game._action("rotation")
		check(game.mode == "fieldwork" and game.job.get("id") != "squad_pull","ordinary work continues after either result")
	game.free()
	if not failures:
		print("CHECKS PASSED — sheriff calls, scene clock and save, early bonus, late base rate, next dispatch")
	quit(int(failures>0))
