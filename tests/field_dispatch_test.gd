extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.dispatch_seed = 84
	# A county detail is also available while the operator runs rotation.
	game.campaign.stage = game.Campaign.ORDER.find("commission")
	game.campaign.ordinary_since = game.Campaign.GAPS[game.campaign.stage]
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig

	await tap_control("radio")
	await tap_control("respond")
	var ditch: Dictionary = game.job.duplicate()
	rig.set_spawn(ditch.point)
	rig.odo += 0.7
	var pickup: float = rig.odo
	game.seconds_worked = 70
	rig.phase = "departing"
	game._recovered(ditch.kind)
	check(game.mode == "available" and game.completed == 0 and game.pending_slips.size() == 1, "field recovery queues the first slip")
	resume_shift()
	game._action("fax")
	check(game.slips.is_empty() and game.account.earned == 0 and game.pending_slips.size() == 1, "resuming in the field leaves the slip unpaid")
	press_key(KEY_R)
	await tap_control("take_detail")
	check(game.job.get("case_id") == "commission" and game.job.number == 1002 and rig.truck.position.distance_to(ditch.point) < 5, "cab radio takes the next numbered call from the ditch")
	follow_detail("commission")
	check(game.pending_slips.size() == 2 and game.campaign.chapter() == "commission", "both field slips await the fax before the case advances")
	resume_shift()
	await tap_control("slip")
	check(game.desk.slip_index == 1, "the clipboard opens on the latest completed field slip")
	game.desk.dismiss()
	await tap_control("radio")
	await tap_control("respond")
	var tow: Dictionary = game.job.duplicate()
	check(game.mode == "fieldwork" and tow.get("kind") == "hazard" and tow.number == 1003, "dispatch uses the unfiled ditch in the rotation and reserves a third number")
	await tap_control("slip")
	check(game.desk.slip_index == -1, "the clipboard opens on the new active tow")
	await tap_control("prev_slip")
	check(game.desk.slip_index == 1, "the pending detail remains accessible behind the active tow slip")
	game.desk.dismiss()
	if failures:
		game.free()
		quit(1)
		return

	# Revisit this save after checking the operator can fax before finishing the tow.
	game._save()
	var before_filing: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	rig.set_spawn(game.SPAWN)
	rig.in_cab = false
	stand(game.FAX + Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.completed == 2 and game.pending_slips.is_empty() and game.campaign.chapter() == "bridge", "one trip to the office files both field slips")
	check(game.mode == "fieldwork" and game.job.vin == tow.vin and rig.car != null, "filing preserves the next active recovery")

	game.desk.dismiss()
	game._restore(before_filing)
	rig.set_spawn(tow.point)
	rig.in_cab = false
	rig.phase = "at_lift"
	stand(rig._panel() - rig.truck.global_basis.x,rig._panel())
	game._action("interact")
	check(rig.loaded and game.mode == "haul", "strapping the hazard still starts a haul")
	stand_at_cab_door(-1)
	game._action("interact")
	game._action("rotation")
	check(rig.loaded and game.mode == "haul" and game.job.number == tow.number, "dispatch cannot replace a tow on the lift")
	resume_shift()
	check(rig.loaded and game.pending_slips.size() == 2, "the loaded vehicle and both slips survive resuming mid-haul")
	rig.odo += 1.3
	park_tow(game.YardDrop.STORAGE.center + Vector3(4,0,0),PI/2)
	game._action("interact")
	stand(rig._panel() - rig.truck.global_basis.x,rig._panel())
	game._action("interact")
	check(not rig.loaded and game.mode == "invoice", "the hazard reaches storage before filing")
	stand(game.FAX + Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.completed == 3 and game.faxes.size() == 3 and game.pending_slips.is_empty(), "a single fax files all three completed jobs")
	if game.slips.size() == 3:
		var pay := 0.0
		for i in 3:
			var slip: Dictionary = game.slips[i]
			check(slip.number == 1001 + i and str(1001 + i) in game.faxes[i], "individual receipt in dispatch order")
			pay += slip.pay
		var first: Dictionary = game.slips.front()
		check(first.vin == ditch.vin and is_equal_approx(first.pickup_odo,pickup) and first.winch == 12 and first.loaded == 0, "the ditch retains its original identity, meter and winch time")
		check(game.slips[1].get("case_id") == "commission" and game.slips[2].vin == tow.vin and is_equal_approx(game.slips[2].loaded,1.3), "case and tow keep their own paperwork")
		check("BATCH PAYMENT ISSUED" in game.faxes.back() and game.account.pending == 0 and is_equal_approx(game.account.cash,game.ShopAccount.OPENING_CASH+pay), "the third invoice settles all three once")
		game._action("fax")
		check(game.completed == 3 and game.faxes.size() == 3 and is_equal_approx(game.account.earned,pay), "refaxing a submitted stack is harmless")
	game.free()
	if not failures:
		print("CHECKS PASSED — roadside dispatch, pending slips across saves, active tow, ordered filing and payment")
	quit(int(failures > 0))
