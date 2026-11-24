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
				follow_detail(id)
				file_at_office()
		check(game.slips.back().get("case_id") == id and game.campaign.ordinary_since == 0, "case slip advances exactly one chapter and resets its interval for " + id)
		if failures:
			break
	if not failures:
		check(game.completed == 57 and game.campaign.chapter().is_empty(), "48 scheduled ordinary calls, one deferred call, eight case slips")
		check("as recorded" in game.faxes.back() and game.slips.back().vin == game.Dispatch.Legacy.JOBS.angie.vin, "final fax and Angie's original identity on file")
		resume_shift()
		check(game.campaign.released and not game.held and "RELEASE" in game.filed_card, "released custody survives the ending")
		check(game.state.pencil_notes.has(game.Casework.NOTES.bridge_plate_far) and game.state.pencil_notes.has(game.Casework.NOTES.angie_consent), "field evidence remains in the plat")
		check(game._radio_contact().is_empty() and not game.county.survey_pickup.visible, "settled case stays closed")
		file_rotation()
		check(game.completed == 58 and not game.slips.back().has("case_id"), "ordinary dispatch pays after the last case")
	game.free()
	if not failures:
		print("CHECKS PASSED — eight paced county cases, physical evidence, deferred and resumed calls, Tou’s release and post-case rotation")
	quit(int(failures > 0))

func file_rotation() -> void:
	game.desk._activate("respond")
	check(game.mode == "fieldwork" and game.job.get("kind") in ["ditch","hazard"] and not game.job.has("case_id"), "radio accepted an ordinary recovery")
	if game.job.is_empty():
		return
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

func check_legacy_progress() -> void:
	game._save()
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
	for id: String in ["house","vin"]:
		inspect_at(id,game.county.story_point(id))
	use_contact("report_farm")
	file_at_office()

func follow_detail(id: String) -> void:
	check(game._radio_contact().is_empty(), "taking the call alone cannot report " + id)
	match id:
		"commission":
			inspect_at("cap",game.county.story_point("cap"))
			inspect_at("checked_sedan",game.county.story_point("vin"))
		"bridge":
			inspect_at("bridge_plate",game.county.story_point("bridge_plate"))
			resume_shift()
			rig.in_cab = true
			check(game.job.case_id == id and game.campaign.evidence.has("bridge_plate") and game._radio_contact().is_empty(), "resume keeps first plate and still requires the second")
			inspect_at("bridge_plate_far",game.county.story_point("bridge_plate_far"))
		"mail": inspect_at("mailboxes",game.county.story_point("mailboxes"))
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
			stand(car+Vector3(2,0,0),car)
			game._action("interact")
			check(rig.phase == "flared" and game.campaign.evidence.has("angie_consent"), "owner consent unlocks the recovery")
			rig.phase = "at_lift"
			var panel: Vector3 = rig._panel()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(rig.loaded and rig.dropoff.sign == "STORAGE", "Angie's car is accepted as a storage tow")
			rig.odo += 2
			park_tow(game.YardDrop.STORAGE.center+Vector3(4,0,0),PI/2)
			panel = rig._panel()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(game.mode == "invoice" and not rig.loaded, "yard panel receives Angie's sedan")
			return
	use_contact("report_detail")
	check(game.mode == "return", "reported " + id)

func pick_up_tou() -> void:
	var point: Vector3 = game.county.story_point("tou")
	inspect_at("tou",point)
	check(game.mode == "fieldwork", "Tou waits while the wrecker is still at the yard")
	rig.set_spawn(point+Vector3(0,0,8))
	inspect_at("tou",point)
	use_contact("talk_tou")
	check(game.desk.page == "passenger", "passenger questions open in the cab")
	game.desk._activate("tou_2")
	check(game.speaker == "TOU" and "odometer" in game.subtitle, "Tou answers the question about the carbons")
	resume_shift()
	check(game.mode == "return" and game.campaign.asked == [2] and game._radio_contact().get("id") == "talk_tou", "resume keeps Tou on the ride and remembers the question")
	check(is_instance_valid(rig.survey_passenger) and rig.survey_passenger.is_visible_in_tree(), "Tou is physically in the passenger seat after resuming")
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("fax")
	check(game.job.get("case_id") == "ride" and game.held, "the fax still requires the signed release")
	inspect_at("release",game.county.bay_latch_point())
	check(game.campaign.released and not game.held, "operator signed for Unit 38's release")
