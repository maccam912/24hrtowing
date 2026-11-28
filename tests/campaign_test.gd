extends "res://tests/shift_test.gd"

# Drive the case from the radio to the fax. The rig tests cover the full
# winching and driving sequence, so repeat tows start at recovery or delivery.
const CHAPTERS := ["unit","farm","commission","bridge","mail","line","ride","angie"]
const INTERVALS := [5,6,5,7,6,8,5,6]

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.dispatch_seed = 22
	game._action("play")
	rig = game.rig
	visit_survey_turnout()
	check(game.survey.can_report_unit() and game._radio_contact().is_empty(), "early evidence waits for the first lead")
	for i in CHAPTERS.size():
		var id: String = CHAPTERS[i]
		check(game.campaign.chapter() == id, "next chapter " + id)
		for n in INTERVALS[i]:
			check(not game.campaign.due() and game._radio_contact().is_empty(), "no early lead for %s on ordinary slip %d" % [id, n+1])
			file_rotation()
			if id == "commission" and n == 1:
				check_legacy_progress()
		check(game.campaign.due() and game.Campaign.LEADS[id] in game.faxes.back(), "case lead arrives on its scheduled fax for " + id)
		if id == "bridge":
			var lead_fax: String = game.faxes.back()
			file_rotation()
			check(game.campaign.chapter() == id and game.campaign.ordinary_since == INTERVALS[i], "deferred lead stays on the same chapter")
			check(game.faxes.has(lead_fax) and not game.Campaign.LEADS[id] in game.faxes.back(), "deferred lead is archived once")
		await process_frame
		if failures:
			break
		match id:
			"unit": file_unit()
			"farm": file_farm()
			_:
				if id == "line":
					check(game._radio_contact().is_empty(), "Alder Cut is held until drive chains are fitted")
					game._action("take_detail")
					check(game.mode == "available" and game.job.is_empty(), "cannot accept the icy corner check with bare tires")
					fit_equipment("chains")
				use_contact("take_detail")
				check(game.job.get("case_id") == id and game.mode == "fieldwork", "accepted " + id)
				if failures:
					break
				await follow_detail(id)
				file_at_office()
		check(game.slips.back().get("case_id") == id and game.campaign.ordinary_since == 0, "case slip advances exactly one chapter and resets its interval for " + id)
		if failures:
			break
	if not failures:
		check(game.completed == 57 and game.campaign.chapter().is_empty(), "48 scheduled ordinary calls, one deferred call, eight case slips")
		check("Lot 3" in game.faxes.back() and game.slips.back().vin == game.Dispatch.Legacy.JOBS.angie.vin, "final fax and Angie's original identity on file")
		resume_shift()
		await process_frame
		check(game.campaign.released and not game.held and "RELEASE" in game.filed_card, "released custody survives the ending")
		check(game.state.pencil_notes.has(game.Casework.NOTES.car_ring) and game.state.pencil_notes.has(game.Casework.NOTES.angie_consent), "field evidence remains in the plat")
		check(game._radio_contact().is_empty() and not game.county.survey_pickup.visible, "settled case stays closed")
		check(not game.county.case_models.has("hoffmann_ring") and game.county.case_models.auction_car.get_node("HoffmannSedan").get_meta("plate")=="WLP 504","the empty space in the ring belongs to the blue sedan now at auction")
		file_rotation()
		check(game.completed == 58 and not game.slips.back().has("case_id"), "ordinary dispatch pays after the last case")
	game.free()
	if not failures:
		print("CHECKS PASSED — eight paced county cases, physical evidence, deferred and resumed calls, Tou’s release and post-case rotation")
	quit(int(failures > 0))

func file_rotation() -> void:
	game.desk._activate("respond")
	check(game.mode == "fieldwork" and game.job.get("kind") in ["ditch","hazard","passenger"] and not game.job.has("case_id"), "radio accepted an ordinary recovery")
	if game.job.is_empty():
		return
	if game.job.kind == "passenger":
		var driver: Vector3 = rig.get_witness_position()
		rig.set_spawn(driver+Vector3(3,0,4))
		inspect_at("offer_ride",driver)
		for tick in 1200:
			if rig.phase == "passenger":
				break
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
		check(rig.phase == "passenger","passenger reaches the cab")
		rig.in_cab = true
		rig.set_spawn(game.Rides.target(game.job))
		game._action("interact")
		check(game.mode == "available","a stopped cab drops its passenger at the requested destination")
	else:
		game._recovered(game.job.kind)
	if game.mode == "haul":
		rig.odo += 1.2
		game._dropped()
	file_at_office()

func file_at_office() -> void:
	var before: int = game.completed
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.completed == before+1 and game.desk.page == "fax", "office filed service slip %d" % (before+1001))
	game.desk._activate("send_fax")
	check(game.completed == before+1 and game.slips.size() == game.completed, "fax cannot file the same slip twice")
	game.desk.dismiss()
	rig.in_cab = true
	game._refresh()

func use_contact(id: String) -> void:
	rig.in_cab = true
	game._refresh()
	game._action("radio")
	check(game.desk.page == "radio" and game._radio_contact().get("id") == id, "cab radio offers " + id)
	game.desk._activate(id)

func inspect_at(id: String, point: Vector3) -> void:
	rig.in_cab = false
	stand(point+Vector3(0,0,1),point)
	check(point.is_finite() and game._site_action() == id, "field interaction available at " + id)
	game._action("interact")

func glass_lindquist_section() -> void:
	# Same stick channel used by the touch controls. Swipes use the ordinary
	# look calculation, with a smaller angle through the field glasses.
	game.desk.stick = Vector2.UP
	for tick in 96:
		game._physics_process(DT)
	game.desk.stick = Vector2.ZERO
	var height: float = game.casework.tower_height
	check(height > 3.0 and height < game.County.CaseSites.TANK_PLATFORM and not game.campaign.evidence.has("car_ring"),"the first rungs are climbed manually")
	resume_shift()
	var heading: float = rig.camera_yaw
	game._physics_process(DT)
	check(is_equal_approx(game.casework.tower_height,height) and rig.eyes.current,"continue on the same rung without moving")
	game.mouse_motion = Vector2(95,-120)
	game._physics_process(DT)
	check(rig.camera_yaw != heading and is_equal_approx(rig.foot.y,height),"free look does not move the operator off a rung")
	game.desk.stick = Vector2.UP
	for tick in 530:
		game._physics_process(DT)
	game.desk.stick = Vector2.ZERO
	check(game._site_action()=="tower_glass" and not game.campaign.evidence.has("car_ring"),"reaching the tank does not enter an observation")
	game._action("interact")
	check(game._site_action()=="tower_lower" and rig.eyes.fov < 15 and not game.campaign.evidence.has("car_ring"),"looking through glasses in the wrong direction leaves the notebook blank")
	var toward: Vector3 = rig.eyes.global_position.direction_to(game.county.story_point("car_ring"))
	var yaw := atan2(-toward.x,-toward.z)
	var pitch := asin(toward.y)
	game.mouse_motion = Vector2(angle_difference(yaw,rig.camera_yaw),rig.camera_pitch-pitch) / (.0023*.19)
	game._physics_process(DT)
	check(game._site_action()=="tower_note" and not game.campaign.evidence.has("car_ring"),"aim at the actual car ring before using the glasses to record it")
	resume_shift()
	check(game.casework.glasses and game._site_action()=="tower_note","the view and the unrecorded observation survive quitting on the landing")
	game._action("interact")
	check(game.campaign.evidence.has("car_ring") and game._site_action()=="tower_lower","deliberately record the ring once")
	game.desk.stick = Vector2.DOWN
	for tick in 510:
		game._physics_process(DT)
	game.desk.stick = Vector2.ZERO
	check(game.casework.tower_height < 0 and not game.casework.glasses and rig.eyes.current and rig.foot.y < 1 and rig.eyes.fov > 60,"climb down to the same ladder foot")

func check_legacy_progress() -> void:
	game.save()
	var old: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	old.erase("campaign")
	for slip: Dictionary in old.slips:
		slip.erase("case_id")
	game._restore(old)
	check(game.campaign.chapter() == "commission" and game.campaign.ordinary_since == 2 and game.held, "legacy N5104 report and subsequent ordinary slips survive migration")
	game._refresh()

func file_unit() -> void:
	use_contact("report_unit")
	game._action("take_case")
	check(game.mode == "available" and game.job.is_empty(), "report is on file but the heavy order waits for a block")
	resume_shift()
	game._action("take_case")
	check(game.mode == "available" and game.job.is_empty(), "reloading a newly issued order cannot bypass its gear requirement")
	fit_equipment("snatch_block")
	use_contact("take_case")
	check(game.job.kind == "hold" and game.job.get("heavy_recovery", false),"deputy issued a heavy custody order")
	inspect_at("sign",rig.get_witness_position())
	game.desk.dismiss()
	inspect_at("tripod",game.county.hold_tripod_point())
	game._recovered("hold")
	game._dropped()
	rig.set_spawn(game.SPAWN,-PI/2)
	var latch: Vector3 = game.county.bay_latch_point()
	stand(latch+Vector3(1.1,0,-1.1),latch)
	game._action("interact")
	check(game.bay_locked and game.held, "Unit 38 secured before filing")
	file_at_office()
	inspect_at("unlock",latch)
	inspect_at("field",game.BAY)
	game.desk._activate("mark_sketch")
	game.desk.dismiss()
	rig.in_cab = true
	game._refresh()

func fit_equipment(id: String) -> void:
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._refresh()
	game.desk.show_document("parts",game.state)
	var cash_before: float = game.account.cash
	game.desk._activate("buy_" + id)
	check(game.account.owns(id) and is_equal_approx(game.account.cash, cash_before - game.account.PRICES[id]), "county calls funded the purchase of " + id)
	game.desk.dismiss()
	rig.in_cab = true
	game._refresh()

func file_farm() -> void:
	use_contact("ask_farm")
	use_contact("take_case")
	for id: String in ["house","farm_ring"]:
		inspect_at(id,game.county.story_point(id))
	use_contact("report_farm")
	file_at_office()

func follow_detail(id: String) -> void:
	check(game._radio_contact().is_empty(), "taking the call alone cannot report " + id)
	match id:
		"commission":
			inspect_at("tower_ladder",game.county.story_point("tower_ladder"))
			glass_lindquist_section()
		"bridge","mail":
			if id == "bridge":
				check(game.job.get("recovery")=="ice" and game.rig.car.position.distance_to(Vector3(-477,-2,-135))<2,"the running sedan sits in the middle of the flowage")
			else:
				inspect_at("carrier_prints",game.county.story_point("carrier_prints"))
			resume_shift()
			check(game.job.case_id==id and game.job.kind=="hazard" and is_instance_valid(rig.car),"reload retains the active physical case recovery")
			var car: Vector3 = rig.car.position
			rig.set_spawn(car+Vector3(0,0,10))
			rig.in_cab = false
			rig.phase = "at_lift"
			var panel: Vector3 = rig.panel_point()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(rig.loaded and game.mode=="haul","the case vehicle goes on the wheel-lift")
			park_tow(game.YardDrop.STORAGE.center+Vector3(4,0,0),PI/2)
			panel = rig.panel_point()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(game.mode=="invoice" and not rig.loaded,"case recovery requires a physical storage delivery")
			return
		"line": inspect_at("last_cap",game.county.story_point("last_cap"))
		"ride":
			pick_up_tou()
			return
		"angie":
			var car: Vector3 = rig.car.position
			rig.set_spawn(car+Vector3(3,0,-9))
			rig.in_cab = false
			stand(car+Vector3(2,0,0),car)
			game._action("interact")
			check(rig.phase == "scene" and not game.campaign.evidence.has("angie_consent"), "cannot start rigging before getting the owner's signature")
			inspect_at("angie",game.county.story_point("angie"))
			game.casework.advance_departure(20.0)
			var walked: float = game.campaign.angie_walked
			# Older rigs saved the case number on the ticket only.
			rig.vehicle_identity.erase("case_id")
			resume_shift()
			await process_frame
			check(rig.vehicle_identity.get("case_id") == "angie", "the porch tow recovers its case identity when an older rig snapshot resumes")
			game.casework.advance_departure(0.0)
			check(is_equal_approx(game.campaign.angie_walked,walked) and game.county.case_models.angie_walking.get_node("AngieKraemer").position.z < -470.0,"Angie resumes up Alder Cut, past the porch")
			game.casework.advance_departure(90.0)
			resume_shift()
			await process_frame
			check(game.campaign.evidence.has("angie_left") and not game.county.case_landmarks.has("angie_walking"),"Angie stays gone after leaving the clearing")
			rig.in_cab = false
			stand(car+Vector3(2,0,0),car)
			game._action("interact")
			check(rig.phase == "flared" and game.campaign.evidence.has("angie_consent"), "owner consent unlocks the recovery")
			rig.phase = "at_lift"
			var panel: Vector3 = rig.panel_point()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(rig.loaded and rig.dropoff.sign == "STORAGE", "Angie's car is accepted as a storage tow")
			rig.odo += 2
			park_tow(game.YardDrop.STORAGE.center+Vector3(4,0,0),PI/2)
			panel = rig.panel_point()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(game.mode == "invoice" and not rig.loaded, "yard panel receives Angie's sedan")
			return
	use_contact("report_detail")
	check(game.mode == "available" and game._radio_contact().is_empty(), "reporting " + id + " frees the rig without reoffering the same detail")

func pick_up_tou() -> void:
	var point: Vector3 = game.county.story_point("tou")
	inspect_at("tou",point)
	check(game.mode == "fieldwork", "Tou waits while the wrecker is still at the yard")
	rig.set_spawn(point+Vector3(0,0,8))
	inspect_at("tou",point)
	use_contact("talk_tou")
	check(game.desk.page == "passenger", "passenger questions open in the cab")
	game.desk._activate("tou_5")
	check(game.speaker == "TOU" and "moves cars" in game.subtitle, "Tou answers why the lights follow the wrecker")
	resume_shift()
	check(game.mode == "return" and game.campaign.asked == [5] and game._radio_contact().get("id") == "talk_tou", "resume keeps Tou on the ride and remembers the question")
	check(is_instance_valid(rig.survey_passenger) and rig.survey_passenger.is_visible_in_tree(), "Tou is physically in the passenger seat after resuming")
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("fax")
	check(game.job.get("case_id") == "ride" and game.held, "the fax still requires the signed release")
	inspect_at("release",game.county.bay_latch_point())
	check(game.campaign.released and not game.held, "operator signed for Unit 38's release")
	check(is_instance_valid(game.casework.released_pickup),"Tou takes the same pickup out of the evidence bay")
	if is_instance_valid(game.casework.released_pickup):
		var bay: Vector3 = game.casework.released_pickup.position
		for n in 75:
			game.casework.advance_departure(.1)
		check(game.casework.released_pickup.position.distance_to(bay)>8,"the released pickup drives away under its running lights")
