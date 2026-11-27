extends "res://tests/freight_recovery_test.gd"

const MilkTanker := preload("res://scripts/milk_tanker.gd")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	var east := "--east" in OS.get_cmdline_user_args()
	game.dispatch_seed = 37 if east else 36
	game._action("play")
	rig = game.rig
	var history := []
	var qualifying_history := []
	var sites := {}
	for i in 62:
		var ticket:Dictionary = game.Dispatch.ordinary(i,game.dispatch_seed,history,true,false)
		if ticket.get("recovery") == "milk":
			if sites.is_empty(): qualifying_history = history.duplicate(true)
			sites[ticket.site] = true
		history.append(game.Dispatch.issue_slip(ticket,70,71,73,20,"03:56"))
	check(sites.size() == 2 and qualifying_history.size() >= 16,"the milk route revisits both farms only after the operator has worked the grid")
	game.slips = qualifying_history
	game.completed = qualifying_history.size()
	game.rotation_offer = {}
	game.account.equipment.snatch_block = true
	game.fit_equipment()
	game._prepare_offers()
	game._action("radio")
	game.desk._activate("respond")
	var ticket:Dictionary = game.job.duplicate(true)
	check(rig.tanker and rig.warning_triangle and not rig.second_winch,"a single wrecker with a block takes the milk route from the county radio")
	if not rig.tanker:
		game.free()
		quit(1)
		return
	var road_x := 800.0 if east else 400.0
	var target:Vector3 = rig.car.position
	rig.set_spawn(Vector3(road_x,0,target.z+21.),PI)
	game._action("interact")
	var driver:Vector3 = rig.get_witness_position()
	stand(driver+Vector3.BACK,driver)
	game._action("interact")
	check(game.speaker == "MILK HAULER","working driver is present with the sealed load")
	stand(target+rig.car.global_basis.x*2.4,target)
	operate_at("flare")
	work_at_panel("milk_seal")
	var cabinet:Vector3 = rig.tanker.to_global(rig.Tanker.CABINET)
	stand(cabinet+rig.car.global_basis.z,cabinet)
	operate_at("milk_manifest")
	check(rig.tanker.checked and ticket.seal in rig.info and str(ticket.gallons) in rig.info,"operator copies the real seal and load from the cabinet")
	work_at_panel("cable")
	var eye:Vector3 = rig.eyelet_point(-1)
	stand(eye-rig.car.global_basis.z,eye)
	operate_at("attach")
	var panel:Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	var peak := 0.
	for i in 310:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
		peak = maxf(peak,rig.tanker.surge.length())
	var swinging:Vector2 = rig.tanker.surge
	var pulse:Vector2 = rig.tanker.liquid_speed
	check(peak>.20 and rig.tanker.shell.rotation.length()>.009,"the moving milk visibly shifts sprung weight under the line")
	resume_shift()
	check(rig.tanker.checked and rig.tanker.surge.is_equal_approx(swinging) and rig.tanker.liquid_speed.is_equal_approx(pulse),"the seal and the liquid's position and momentum survive a restart")
	for i in 520:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.tanker.surge.length()<.06,"the milk comes to rest when the operator holds the drum")
	for i in 4200:
		if rig.phase != "rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
		game.seconds_worked += DT
	work_at_panel("lift")
	stand_at_cab_door(-1)
	game._action("interact")
	game._refresh()
	check(game.mode == "haul" and rig.loaded and rig.in_cab and game.county.milk_guide.visible and not game.county.freight_guide.visible and "milk house" in game._route_note().title,"loaded instructions and the bay point to Brzezinski")
	if not rig.loaded:
		game.free()
		quit(1)
		return
	game.save()
	var field_save:Dictionary = game.saved_data.duplicate(true)
	rig.set_spawn(rig.RiverLanes.CENTER)
	rig.car.position = rig.RiverLanes.CENTER
	check(not rig.at_dropoff(),"the freight receiver on US 59 cannot sign a milk transfer")
	game._restore(field_save)
	drive_to(Vector3(road_x,0,373))
	for i in 64:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,DT)
	check(rig.tanker.surge.y>.45,"a firm brake application sends the milk toward the cab")
	drive_to(Vector3(road_x,0,392))
	drive_to(Vector3(road_x-10,0,400))
	drive_to(Vector3(road_x-38,0,400))
	for x in range(int(road_x)-85,155,-72):
		drive_to(Vector3(x,0,400))
	drive_to(Vector3(162,0,400))
	drive_to(Vector3(141,0,404))
	drive_to(Vector3(126,0,411))
	drive_to(Vector3(112,0,413))
	check(not rig.at_dropoff(),"the wrecker's nose in the receiving lane cannot sign for an outside tank")
	drive_to(Vector3(101,0,413))
	stop()
	check(rig.at_dropoff(),"the Hendricks approach fits the loaded tanker on the white transfer pad")
	if not rig.at_dropoff():
		printerr("Milk pad pose ",rig.truck.position," / ",rig.car.position)
		game.free()
		quit(1)
		return
	game._refresh()
	game._action("interact")
	var end_panel:Vector3 = rig.panel_point()
	stand(end_panel-rig.truck.global_basis.x,end_panel)
	check(rig.action_id() == "milk_settle","a freshly stopped fluid load must settle before unstrapping")
	game._action("interact")
	check(rig.loaded and game.mode=="haul","the lift stays up until the slosh damps out")
	resume_shift()
	check(rig.tanker.checked and rig.at_dropoff() and rig.action_id()=="milk_settle","a stopped load resumes with the same transfer pad and moving liquid")
	for i in 480:
		if rig.tanker.is_settled(): break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	work_at_panel("drop")
	check(game.mode=="available" and game.pending_slips.size()==1 and game.received_freight is MilkTanker and game.stored.is_empty(),"the milk house signs for the load and frees the operator")
	resume_shift()
	check(game.received_freight and game.received_freight.seal==ticket.seal,"a restarted shift keeps the correct sealed tanker by the hose")
	file_at_office()
	var slip:Dictionary = game.slips.back()
	check(slip.gallons==ticket.gallons and slip.seal==ticket.seal and slip.storage==0 and slip.heavy_fee==36 and slip.loaded>.55 and is_equal_approx(game.account.earned,slip.pay),"sealed gallons, loaded miles and the heavy recovery reach the paid carbon")
	check(str(ticket.gallons) in game.faxes.back() and str(ticket.seal) in game.faxes.back() and not game.received_freight,"the dairy receipt follows the physical seal and the cleared transfer")
	game.free()
	if not failures: print("CHECKS PASSED — farm dispatch, sealed milk ticket, spring load transfer, loaded road handling, milk house handoff and fax")
	quit(int(failures>0))
