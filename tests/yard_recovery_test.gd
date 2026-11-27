extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.dispatch_seed = 84
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	await check_haul_and_billing()
	check_custody()
	check_tower()
	check_passenger_and_release()
	await check_angie()
	game.free()
	if not failures:
		print("CHECKS PASSED — confirmed yard recovery, original contract and rigging, custody and release, passenger rides and billing")
	quit(int(failures > 0))

func check_haul_and_billing() -> void:
	game._action("rotation")
	game._recovered("ditch")
	var pending: Array = game.pending_slips.duplicate(true)
	game._action("rotation")
	var tow: Dictionary = game.job.duplicate(true)
	rig.set_spawn(tow.point)
	rig.in_cab = false
	rig.phase = "at_lift"
	stand(rig.panel_point()-rig.truck.global_basis.x,rig.panel_point())
	game._action("interact")
	check(game.mode == "haul" and rig.loaded, "wrecker has an active loaded contract")
	rig.odo += 1.5
	rig.wear = 0.42
	rig.fuel = 0.15
	var odo: float = rig.odo
	game.account.cash = 5.0
	game.survey.record("unit",odo)
	await tap_control("pause")
	await tap_control("yard_recovery")
	await tap_control("close")
	check(game.desk.page == "pause" and rig.loaded and game.account.cash == 5, "cancel leaves the job and cash alone")
	await tap_control("yard_recovery")
	await tap_control("confirm_yard_recovery")
	check(rig.in_cab and rig.is_stopped() and game._truck_in_yard() and rig.foot == game.SPAWN, "on-foot operator and wrecker recover together")
	check(game.mode == "fieldwork" and game.job == tow and rig.phase == "scene" and not rig.loaded and rig.car.position.distance_to(tow.point)<2.0,
		"the same vehicle, VIN and contract restart at the original scene")
	check(game.completed == 0 and game.stored.is_empty() and game.pending_slips == pending and game.survey.notes.unit == odo,
		"previous slips and notes survive without granting a delivery")
	check(game.pickup_time.is_empty() and game.seconds_worked == 0 and game.dispatch_odo == odo and rig.fuel == 0.15 and rig.wear == 0.42,
		"restart clears billable work and preserves operating costs")
	game._action("confirm_yard_recovery")
	resume_shift()
	check(rig.in_cab and game._truck_in_yard() and rig.phase == "scene" and game.job.vin == tow.vin and rig.odo == odo, "restart survives a reload")
	check(game.account.cash == 0.0 and game.account.recovery_due == 19.0 and game.account.fuel_due == 0.0, "one yard recovery charges cash and carries its own IOU")
	game._recovered("hazard")
	game._dropped()
	var stored: Array = game.stored.duplicate(true)
	pending = game.pending_slips.duplicate(true)
	confirm_from_pause()
	check(game.mode == "invoice" and game.stored == stored and game.pending_slips == pending, "recovery after a real delivery preserves its storage and paperwork")
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.completed == 2 and game.slips.size() == 2 and game.account.recovery_due == 43.0, "the two completed jobs file once")
	game.desk.dismiss()
	rig.in_cab = true
	game._refresh()
	file_rotation()
	check(game.account.recovery_due == 0.0 and is_equal_approx(game.account.cash,game.account.earned-43.0) and "Less yard recovery   $43.00" in game.faxes.back(),
		"the county check settles the outstanding yard tows once")

func check_custody() -> void:
	game.survey.hold_order = "offered"
	game.campaign.ordinary_since = game.Campaign.GAPS[0]
	game.account.equipment.snatch_block = true
	game.fit_equipment()
	use_contact("take_case")
	inspect_at("sign",rig.get_witness_position())
	game.desk.dismiss()
	inspect_at("tripod",game.county.hold_tripod_point())
	rig.phase = "rigged"
	rig.line_end = 1
	confirm_from_pause()
	check(game.survey.hold_order == "accepted" and not game.signed_card and not game.packed_tripod and rig.line_end == -1 and rig.phase == "scene",
		"custody starts again with the deputy, tripod and cable")
	inspect_at("sign",rig.get_witness_position())
	game.desk.dismiss()
	inspect_at("tripod",game.county.hold_tripod_point())
	game._recovered("hold")
	game._dropped()
	confirm_from_pause()
	check(game.mode == "invoice" and game.held and not game.filed_card.is_empty() and not game._filing_blocker().is_empty(),
		"the delivered evidence pickup stays at the bay and still requires locking")
	rig.in_cab = false
	var latch: Vector3 = game.county.bay_latch_point()
	stand(latch+Vector3(1.1,0,-1.1),latch)
	game._action("interact")
	file_at_office()
	inspect_at("unlock",latch)

func check_tower() -> void:
	game.campaign.stage = game.Campaign.ORDER.find("commission")
	game.campaign.ordinary_since = game.Campaign.GAPS[game.campaign.stage]
	game.accept(game.campaign.ticket(1001+game.completed))
	inspect_at("tower_ladder",game.county.story_point("tower_ladder"))
	confirm_from_pause()
	check(game.casework.tower_height < 0 and rig.eyes.current and game.mode == "fieldwork" and not game.campaign.evidence.has("car_ring"),
		"a recovery during the tower climb releases the view and keeps the unobserved ring unreported")

func check_passenger_and_release() -> void:
	game.campaign.stage = game.Campaign.ORDER.find("ride")
	game.campaign.ordinary_since = game.Campaign.GAPS[game.campaign.stage]
	game.accept(game.campaign.ticket(1001+game.completed))
	var pickup: Vector3 = game.county.story_point("tou")
	rig.set_spawn(pickup+Vector3(0,0,5))
	inspect_at("tou",pickup)
	check(game.mode == "return" and game.campaign.evidence.has("passenger"), "Tou has boarded")
	rig.in_cab = true
	rig.fuel = 0.0
	game.account.cash = 0.0
	game._refresh()
	game._action("roadside_fuel")
	check(game.fuel_can.en_route(), "an empty truck has an incoming fuel can")
	game._advance_shift_clock(1.0)
	game.sightings._start("the_calm",game,rig.get_truck_position(),"Alder Cut",false)
	rig.speed = 3.0
	rig.motion = Vector3(3,0,0)
	rig.steering = 0.1
	confirm_from_pause()
	check(game.mode == "fieldwork" and not game.campaign.evidence.has("passenger") and not rig.survey_passenger.visible and "tou" in game.county.case_landmarks,
		"passenger waits at the pickup again")
	check(rig.is_stopped() and rig.motion == Vector3.ZERO and rig.steering == 0.0 and rig.fuel == 0.0, "recovered truck is at rest with its original empty tank")
	check(game.sightings.active.is_empty() and game.sightings.seen.has("the_calm"), "roadside sighting ends and remains recorded when the rig is recovered")
	check(game.account.recovery_due == 24.0 and game.fuel_can.plow == null and game.fuel_can.wait_left == 0 and game.account.fuel_due == 0.0 and game.fuel_can.needed(game), "broke operator can call for fuel at the yard after cancelling an undelivered can")
	pick_up_tou()
	var released_card: String = game.filed_card
	confirm_from_pause()
	resume_shift()
	check(game.campaign.released and not game.held and game.filed_card == released_card and game.campaign.asked == [5] and game.mode in ["return","invoice"],
		"recovery after release preserves Tou's signature, conversation and returned truck")
	file_at_office()

func check_angie() -> void:
	game.campaign.ordinary_since = game.Campaign.GAPS[game.campaign.stage]
	game.accept(game.campaign.ticket(1001+game.completed))
	inspect_at("angie",game.county.story_point("angie"))
	await process_frame
	game.casework.advance_departure(130.0)
	confirm_from_pause()
	check(game.campaign.evidence.has("angie_left") and not game.county.case_landmarks.has("angie"), "restarting the tow preserves Angie's walk and consent")
	rig.in_cab = false
	stand(rig.car.position + Vector3(2,0,0),rig.car.position)
	game._action("interact")
	check(rig.phase == "flared", "operator can rig Angie's car after she has left")

func confirm_from_pause() -> void:
	game.desk.toggle_pause()
	game.desk._activate("yard_recovery")
	game.desk._activate("confirm_yard_recovery")
