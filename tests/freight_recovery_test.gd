extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	var seed_value := 23 if "--south" in OS.get_cmdline_user_args() else 22
	game.dispatch_seed = seed_value
	game._action("play")
	rig = game.rig
	var history := []
	var before_freight := []
	var sites := {}
	for i in 55:
		var ticket:Dictionary = game.Dispatch.ordinary(i,seed_value,history,true,true)
		check(game.Dispatch.ordinary(i,seed_value,history,true,false).get("recovery") != "semi" and game.Dispatch.ordinary(i,seed_value,history,false,true).get("recovery") != "semi","both drums and the block are needed for a semi")
		if ticket.get("recovery") == "semi":
			if sites.is_empty(): before_freight = history.duplicate(true)
			sites[ticket.site] = true
		history.append(game.Dispatch.issue_slip(ticket,100,101,103,12,"03:50"))
	check(sites.size() == 2 and before_freight.size() >= 12, "freight rotates between the two turnouts on 59")
	if before_freight.is_empty():
		game.free()
		quit(1)
		return
	game.slips = before_freight
	game.completed = before_freight.size()
	game.rotation_offer = {}
	game.account.equipment["snatch_block"] = true
	game.account.cash = 340
	game.save()
	var older_save: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	older_save.erase("received_freight")
	older_save.rig.erase("freight")
	older_save.account.equipment.erase("second_winch")
	game._restore(older_save)
	check(game.heavy_job_filed and not rig.auxiliary_drum,"a filed heavy ticket in an older ledger qualifies the stock truck for a new drum")
	game.desk._touch_mode = true
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._refresh()
	await tap_control("interact")
	await tap_control("parts_leaf")
	await tap_control("buy_second_winch")
	check(game.account.owns("second_winch") and game.account.cash == 0 and rig.auxiliary_drum and rig.auxiliary_drum.visible,"a funded operator fits the $340 auxiliary drum from the equipment catalog")
	game.desk.dismiss()
	rig.in_cab = true
	for turn in 5:
		if game.rotation_offer.get("recovery") == "semi":
			break
		game._action("radio")
		file_rotation()
	var previous_earnings:float = game.account.earned
	var stored_before:int = game.stored.size()
	game._action("radio")
	game.desk._activate("respond")
	var north := seed_value == 22
	var expected_site := "freight_north" if north else "freight_south"
	check(rig.semi != null and game.job.site == expected_site, "the radio opens the articulated turnout call")
	if not rig.semi:
		game.free()
		quit(1)
		return
	var ticket:Dictionary = game.job.duplicate(true)
	check(rig.semi.get_meta("vin") == ticket.vin and absf(angle_difference(rig.semi.rotation.y,rig.semi.trailer.global_rotation.y))>1.0,"the freight manifest matches the folded combination")
	var target:Vector3 = rig.car.position
	var forward:Vector3 = -rig.car.global_basis.z
	rig.set_spawn(target+forward*20+Vector3.LEFT*6,game.job.angle)
	game._action("interact")
	var driver:Vector3 = rig.get_witness_position()
	stand(driver+forward*.9,driver)
	game._action("interact")
	check(game.speaker == "FREIGHT DRIVER","driver can explain the box and the truck stop")
	stand(target+rig.car.global_basis.x*2.4,target)
	game._action("interact")
	work_at_panel("cable")
	var eye:Vector3 = rig.eyelet_point(-1)
	stand(eye+forward,eye)
	operate_at("freight_tractor")
	work_at_panel("freight_second")
	var axle:Vector3 = rig.semi.axle_eye(-1)
	stand(axle-rig.semi.trailer.global_basis.x*.85,axle)
	operate_at("freight_axle")
	var panel:Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	for i in 180:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	var bend:float = angle_difference(rig.semi.rotation.y,rig.semi.trailer.global_rotation.y)
	rig._cable_curve()
	check(rig.phase == "rigged" and rig.semi.rigging == "both" and rig.cable_mesh.get_surface_count() == 3 and absf(bend) < 1.0,"separate check drum draws the tandem back toward the tractor")
	resume_shift()
	check(rig.auxiliary_drum.visible and is_equal_approx(bend,angle_difference(rig.semi.rotation.y,rig.semi.trailer.global_rotation.y)) and rig.semi.rigging == "both" and rig.semi.chain_side == -1, "resuming keeps the fitted drum, live check chain and actual fifth-wheel angle")
	for i in 1500:
		if rig.phase != "rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.semi.rigging == "release", "straightening halts for the operator to remove the check chain")
	axle = rig.semi.axle_eye(-1)
	stand(axle-rig.semi.trailer.global_basis.x*.85,axle)
	operate_at("freight_unpin")
	work_at_panel("freight_stow")
	for i in 3400:
		if rig.phase != "rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
		game.seconds_worked += DT
	work_at_panel("lift")
	stand_at_cab_door(-1)
	game._action("interact")
	game._refresh()
	check(game.mode == "haul" and rig.in_cab and game.county.freight_guide.visible and not game.county.drop_guide.visible and "River Lanes" in game._route_note().title,"haul points to the receiving apron on 59")
	if not rig.loaded:
		game.free()
		quit(1)
		return
	game.save()
	var field_save:Dictionary = game.saved_data.duplicate(true)
	for bend_at_rest:float in [-.24,.24]:
		rig.semi.set_trailer_heading(rig.semi.rotation.y+bend_at_rest,rig.ground_height)
		var parked_yaw:float = rig.semi.trailer.global_rotation.y
		for tick in 900:
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,DT)
		check(absf(angle_difference(parked_yaw,rig.semi.trailer.global_rotation.y)) < deg_to_rad(.01),"a stopped freight trailer holds its fifth-wheel angle in either direction")
	rig.truck.position = rig.YardDrop.STORAGE.center
	rig.car.position = rig.YardDrop.STORAGE.center
	check(not rig.at_dropoff(),"the county storage bay cannot accept freight")
	rig.in_cab = false
	var trial_panel:Vector3 = rig.panel_point()
	stand(trial_panel-rig.truck.global_basis.x,trial_panel)
	game._action("interact")
	check(rig.loaded and game.mode == "haul" and game.pending_slips.is_empty(),"the panel keeps the combination attached at the wrong bay")
	game._restore(field_save)
	drive_to(Vector3(-608,0,-85 if north else 160))
	drive_to(Vector3(-608,0,-21 if north else 119))
	drive_to(Vector3(-599,0,17 if north else 92))
	drive_to(Vector3(-596,0,38 if north else 71))
	check(not rig.at_dropoff(),"the tractor entering the bay is insufficient with a trailer outside")
	drive_to(Vector3(-596,0,66 if north else 41))
	stop()
	game._refresh()
	check(rig.at_dropoff(),"driver can pull the full articulated rig between the four receiver's posts")
	var pin: Vector3 = rig.semi.to_global(rig.Semi.KINGPIN)
	check(pin.distance_to(rig.semi.trailer.global_position)<.01 and rig.odo>game.pickup_odo+.30,"wheel-lift and fifth-wheel connections stay together for a metered haul")
	if not rig.at_dropoff():
		printerr("Receiving pose ",rig.truck.position," / ",rig.car.position," / ",rig.semi.trailer.to_global(Vector3.BACK*rig.Semi.BACK))
		game.free()
		quit(1)
		return
	resume_shift()
	check(rig.at_dropoff(),"loaded freight resumes inside the same bay")
	game._action("interact")
	work_at_panel("drop")
	check(game.mode == "available" and game.received_freight != null and game.pending_slips.size()==1 and game.stored.size()==stored_before, "receiver takes the complete combination and releases the next shift immediately")
	resume_shift()
	check(game.received_freight and game.received_freight.get_meta("plate") == ticket.plate, "delivered freight stays on the apron across a restart")
	file_at_office()
	var slip:Dictionary = game.slips.back()
	check(slip.vin == ticket.vin and slip.storage == 0 and slip.loaded > .3 and slip.heavy_fee == 36 and slip.destination == rig.RiverLanes.DROP.sign and is_equal_approx(game.account.earned,previous_earnings+slip.pay), "county pays the freight invoice and loaded miles without a yard storage charge")
	check("River Lanes truck stop" in game.faxes.back() and not game.received_freight, "Doreen's receipt names the receiver and the distant crew frees the lane")
	game.free()
	if not failures:
		print("CHECKS PASSED — repeat semi dispatch, both drums, player-run straightening, loaded articulation, pull-through receipt and saves")
	quit(int(failures>0))

func operate_at(id: String) -> void:
	check(rig.action_id()==id,"operator expected "+id+", got "+rig.action_id())
	game._action("interact")

func work_at_panel(id: String) -> void:
	var panel: Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	operate_at(id)
