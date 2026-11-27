extends "res://tests/campaign_test.gd"

const Visits := preload("res://scripts/county_visits.gd")
const Dispatch := preload("res://scripts/dispatch.gd")

func run() -> void:
	for seed_value in 3:
		new_shift(seed_value)
		await run_visit(Visits.CHECKS.keys()[seed_value])
		game.free()
	new_shift(1)
	var ordinary: Dictionary = game.rotation_offer.duplicate()
	game._action("take_visit")
	game._action("pass_visit")
	check(game.mode == "available" and game.visit_offer.is_empty() and game.pending_slips.is_empty(),"passing it back releases the operator without a false finding or pay")
	resume_shift()
	check(game.visit_offer.is_empty() and game.rotation_offer.vin == ordinary.vin,"radio keeps the original tow across a declined visit and restart")
	game._action("rotation")
	check(game.job.vin == ordinary.vin,"regular tow proceeds immediately")
	game.free()
	var history := []
	var offered := []
	for i in 24:
		var call := Visits.offer(42,history,i,-1)
		if not call.is_empty():
			offered.append(call.id)
		var ticket := Dispatch.ordinary(i,82,history)
		history.append(Dispatch.issue_slip(ticket,100,101,102,40,"03:52"))
	check(offered.size() == 3 and offered[0] != offered[1] and offered[1] != offered[2] and offered[0] != offered[2],"three different optional observations recur after spaced ordinary pickups")
	check(Dispatch.looksee(4).id == "n5104" and Dispatch.looksee(4).kind == "looksee","the case look-see retains its reserved history")
	if not failures:
		print("CHECKS PASSED — optional field visits, physical evidence, radio findings, alternative tow, paid slips and restart")
	quit(int(failures > 0))

func new_shift(seed_value: int) -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	game.dispatch_seed = seed_value
	game.slips.clear()
	for i in 4:
		var ticket := Dispatch.ordinary(i,seed_value,game.slips)
		game.slips.append(Dispatch.issue_slip(ticket,100,101,102,40,"03:52"))
	game.completed = 4
	game.campaign.ordinary_since = 4
	game.rotation_offer = {}
	game._prepare_offers()
	game._refresh()

func run_visit(id: String) -> void:
	var ordinary: Dictionary = game.rotation_offer.duplicate()
	check(game.visit_offer.id == id,"ordinary tow and optional check reach the radio together")
	game._action("radio")
	await tap_control("visit_call")
	check(game.desk.page == "visit_call" and game.job.is_empty(),"read the request before accepting it")
	await tap_control("take_visit")
	check(game.job.id == id and game.mode == "fieldwork" and not rig.car,"paid visit starts without spawning a tow customer")
	var target: Vector3 = Visits.point(game.county,id,0)
	rig.set_spawn(target+Vector3(3,0,0))
	check(game._radio_contact().id == "pass_visit","parking at the site alone cannot report an outcome")
	for step in 2:
		game._action("report_visit")
		check(game.mode == "fieldwork" and game.pending_slips.is_empty(),"an unobserved finding cannot be called in")
		target = Visits.point(game.county,id,step)
		var offset := Vector3(0,0,1.9)
		if id == "landing":
			offset = Vector3(2,0,.05)
		elif id == "dryhouse":
			offset = Vector3(-9.2,0,1) if step == 0 else Vector3(-1.9,0,.05)
		elif id == "parish" and step == 1:
			offset = Vector3(-1.7,0,.35)
		rig.in_cab = false
		var feet := Vector3(target.x+offset.x,0,target.z+offset.z)
		rig.foot = Vector3(feet.x,game.county.ground_height(feet.x,feet.z),feet.z)
		face(target+offset*4)
		check(game._site_action() != "visit_stop","the wrong view cannot identify "+id)
		face(target)
		if id == "dryhouse" and step == 0:
			game._action("interact")
			check(game.job.visit_step == 0,"an unobserved pair of flashes cannot be called a signal")
			for tick in 180:
				game.visits.advance(DT,game)
		check(game._site_action()=="visit_stop","field step %s/%d is visible and within reach" % [id,step])
		game._refresh()
		await tap_control("interact")
		check(int(game.job.visit_step) == step+1,"on-site finding advances "+id+" without issuing pay")
		if step == 0:
			resume_shift()
			check(game.job.id == id and int(game.job.visit_step)==1,"a half-checked visit survives a restart")
	check(game._radio_contact().is_empty(),"dispatch needs the truck radio")
	rig.in_cab = true
	game._refresh()
	game._action("radio")
	await tap_control("report_visit")
	check(game.mode=="available" and game.pending_slips.size() == 1 and game.visit_offer.is_empty(),"explicit report closes and pays exactly one check")
	var slip: Dictionary = game.pending_slips.front()
	check(slip.finding == Visits.CHECKS[id].result and slip.pay == 38 and slip.hookup==0 and slip.storage==0 and slip.loaded==0,"paper retains the finding and only the county call-out")
	check(game.subtitle == Visits.CHECKS[id].ack and game.rotation_offer.vin==ordinary.vin and game.rotation_offer.number == ordinary.number+1,"dispatch acknowledges the outcome and preserves the waiting tow")
	if id == "landing":
		check(is_zero_approx(game.visits.gate_target),"rehung rail stays up after radio signoff")
	rig.in_cab = false
	stand(game.FAX,game.FAX+Vector3.BACK)
	game._file_invoice()
	check(game.slips.back().finding == slip.finding and slip.finding in game.fax_text and game.campaign.ordinary_since==5,"county files the actual finding and counts one ordinary job")
	resume_shift()
	check(game.slips.back().finding == slip.finding and game.visit_offer.is_empty(),"fax and offer interval survive a new session")

func face(target: Vector3) -> void:
	rig.update_eyes()
	var ray: Vector3 = rig.eyes.global_position.direction_to(target)
	rig.camera_yaw = atan2(-ray.x,-ray.z)
	rig.camera_pitch = asin(ray.y)
	rig.update_eyes()
