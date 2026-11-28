extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.dispatch_seed = 35
	game._action("play")
	rig = game.rig

	# Drive the generator through three Duane calls, with the same carbon
	# copies it would see from the clipboard or the county fax.
	var slips := []
	var calls := []
	var first_history := []
	var passengers := 0
	for i in 60:
		var ticket: Dictionary = game.Dispatch.ordinary(i,game.dispatch_seed,slips,true)
		check(game.Dispatch.ordinary(i,game.dispatch_seed,slips,false).id != "stuck_plow", "Duane needs a fitted block")
		if ticket.id == "stuck_plow":
			if calls.is_empty():
				first_history = slips.duplicate(true)
			else:
				check(i-int(calls.back()) >= 14, "Duane has other roads between pulls")
			calls.append(i)
			check(ticket.vin == rig.Scene.Snowplow.VIN and ticket.plate == rig.Scene.Snowplow.PLATE and ticket.site in ["farm","dairy","frames","ff_barn"], "the same truck works the county routes")
		passengers += int(ticket.kind == "passenger")
		slips.append(game.Dispatch.issue_slip(ticket,100,101,102,12,"03:20"))
	check(calls.size() >= 3 and passengers >= 1 and first_history.size() >= 8,"plows recur without crowding out a passenger")
	if calls.is_empty():
		game.free()
		quit(1)
		return
	game.slips = first_history
	game.completed = first_history.size()
	game.rotation_offer = {}
	game.account.equipment["snatch_block"] = true
	game.fit_equipment()
	game._prepare_offers()
	game._action("radio")
	game.desk._activate("respond")
	var ticket: Dictionary = game.job
	check(ticket.id == "stuck_plow" and "rear eye" in ticket.dispatch,"Arlene issues the heavy pull over the cab radio")
	var vehicle: Node3D = rig.car
	check(vehicle.name == "CountySnowplow" and vehicle.has_node("Blade") and rig.duane_on_scene(),"the call has a marked plow with its own blade and driver")
	var rear: Vector3 = vehicle.global_basis.z.slide(Vector3.UP).normalized()
	rig.set_spawn(vehicle.position+rear*18,ticket.angle+PI)
	game._action("interact")
	var duane: Vector3 = rig.get_witness_position()
	stand(duane + rear, duane)
	game._action("interact")
	check(game.speaker == "DUANE" and game.talked, "Duane answers from the ditch")
	stand(vehicle.position-vehicle.global_basis.x*2.2,vehicle.position)
	game._action("interact")
	var panel: Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	game._action("interact")
	var nose: Vector3 = rig.eyelet_point(-1)
	stand(nose-rear*1.5,nose)
	check(rig.action_id() == "plow_blade","the moldboard has no cable point")
	game._action("interact")
	check(rig.phase == "cable", "the hook stays in hand at the blade")
	var eye: Vector3 = rig.eyelet_point(1)
	stand(eye+rear,eye)
	game._action("interact")
	resume_shift()
	check(rig.phase == "rigged" and rig.line_end == 1 and rig.car.has_node("Blade") and rig.duane_on_scene(),"resuming a hooked plow keeps the rear block and driver")
	panel = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	for tick in 2700:
		if rig.phase != "rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,rig.tension < .94,false,DT)
		game.seconds_worked += DT
	check(rig.phase == "departing" and game.mode == "available" and not rig.loaded and game.pending_slips.size() == 1,"Duane takes his plow back on the road with a single bill")
	if game.pending_slips.is_empty():
		game.free()
		quit(1)
		return
	var slip: Dictionary = game.pending_slips[0]
	check(slip.vin == ticket.vin and slip.loaded == 0 and slip.storage == 0 and slip.heavy_fee == 36 and slip.pay == 38 + 16 + slip.winch + 36,"plow pays heavy field recovery only")
	var cleared_at: Vector3 = rig.car.position
	for tick in 1200:
		rig._trail(DT)
	check(not rig.witness.visible and rig.car.position.distance_to(cleared_at)>9 and rig.car.get_node("Blade").position.y>0,"Duane climbs in, raises the blade and drives away")
	file_at_office()
	check(game.slips.back().vin == ticket.vin and game.account.earned == slip.pay and "Heavy recovery" in game.faxes.back(),"fax files the field slip and pays once")
	game.free()
	if not failures:
		print("CHECKS PASSED — repeat county plow dispatch, rear-eye double-line recovery, resuming, departure and pay")
	quit(int(failures > 0))
