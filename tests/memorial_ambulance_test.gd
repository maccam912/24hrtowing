extends "res://tests/campaign_test.gd"
const EMS := preload("res://scripts/memorial_ambulance.gd")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game.desk._touch_mode = true
	rig = game.rig
	var history := []
	var first := {}
	var last_ems := -1
	var deputies := {}
	for i in 123:
		var ticket: Dictionary = game.Dispatch.ordinary(i,615,history,true,true)
		if ticket.vin == EMS.VIN:
			if first.is_empty(): first = ticket.duplicate(true)
			check(i >= 18 and (last_ems < 0 or i-last_ems >= 23),"ambulance and paying work are spaced apart")
			last_ems = i
		if ticket.id == "squad_pull": deputies[ticket.plate] = true
		history.append(game.Dispatch.issue_slip(ticket,100,101,102,1,"04:12"))
	check(not first.is_empty() and deputies.size()==2,"Memorial and both deputies keep distinct units")
	if first.is_empty():
		game.free(); quit(1); return
	game.accept(first)
	check(rig.car.get_meta("ems",false) and rig.car.get_meta("vin")==EMS.VIN and rig.ems_partner.get_node("EmptyCot")!=null,"EMS box body and both responding crew members are instantiated")
	EMS.flash(rig.car_lamps,.22)
	check(rig.car_lamps.get_node("LeftWarning").visible and not rig.car_lamps.get_node("RightWarning").visible,"the parked unit alternates its red corner heads while the steady beams stay on")
	var center: Vector3 = rig.car.position
	var roadward := Vector3(12,0,-8).normalized()
	rig.set_spawn(center+roadward*19,atan2(-roadward.x,-roadward.z))
	rig.in_cab = false
	var driver: Vector3 = rig.witness.position
	inspect_at("driver",driver)
	check(game.speaker=="EMT NOVAK","Novak reports the completed handoff")
	stand(center+rig.car.global_basis.x*2.2,center)
	game._action("interact")
	check(rig.phase=="flared","flare establishes the recovery scene")
	game._physics_process(.25)
	check(game.job.clearance_seconds==0 and rig.cot_at_line(),"crew handoff is off the clock")
	var kit: Vector3 = rig.ems_partner.position
	stand(kit+Vector3.BACK*1.1,kit)
	game._refresh()
	await tap_control("interact")
	check(not rig.ems_partner and rig.exiting_riders.size()==1,"Kit begins wheeling the empty cot after a real touch action")
	for i in 28: game._physics_process(DT)
	var moved: Vector3 = rig.exiting_riders[0].person.position
	check(moved.distance_to(kit)>.25 and game.job.clearance_seconds==0,"the cot visibly moves before the timer starts")
	resume_shift()
	check(not rig.ems_partner and rig.exiting_riders.size()==1 and rig.exiting_riders[0].person.get_node("EmptyCot") and rig.exiting_riders[0].person.position.is_equal_approx(moved),"cold save resumes one marked EMT and the cot on their actual route")
	for i in 630:
		if not rig.cot_at_line(): break
		game._physics_process(DT)
	check(not rig.cot_at_line() and not rig.exiting_riders.is_empty(),"Kit clears the pull and keeps going to the night entrance")
	var panel: Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	game._action("interact")
	var end := 1 if roadward.dot(rig.car.global_basis.z)>0 else -1
	var eye: Vector3 = rig.eyelet_point(end)
	stand(eye+rig.car.global_basis.z*end,eye)
	game._action("interact")
	stand(panel-rig.truck.global_basis.x,panel)
	check(rig.phase=="rigged","operator can rig the actual ambulance eye")
	game.save()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	for late in [false,true]:
		if late:
			game._restore(saved)
			for i in 630: game._physics_process(.20)
		game.desk._touches[0] = {"id":"work"}
		for i in 2800:
			if rig.phase!="rigged": break
			game._physics_process(DT)
		game.desk._touches.clear()
		if game.pending_slips.is_empty():
			check(false,"ambulance at road height can leave")
			break
		var slip: Dictionary = game.pending_slips[0]
		check(slip.vin==EMS.VIN and slip.pay==slip.call_out+slip.hookup+slip.winch+(0 if late else 24),"early and late pulls both pay with only the premium changing")
		var responder = rig.departures[0]
		for i in 2800:
			if responder.ems_leg == EMS.RETURN_LANE.size(): break
			game._physics_process(DT)
		check(responder.car.position.distance_to(EMS.RETURN_LANE.back()) < 2., "Novak drives the released unit to Memorial's real curb")
		check(rig.exiting_riders.is_empty(), "Kit rolls the cot through the hospital doorway")
		file_at_office()
		check("Ambulance clearance" in game.faxes.back() and game.account.earned == slip.pay,"fax pays the correct EMS unit and premium")
		game._action("rotation")
		check(game.mode=="fieldwork" and game.job.get("vin")!=EMS.VIN,"another paid shift opens when Novak is clear")
	game.free()
	if not failures: print("CHECKS PASSED — Memorial ambulance, physical cot handoff, saved EMT route, optional clearance premium and recurring work")
	quit(int(failures>0))
