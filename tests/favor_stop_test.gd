extends "res://tests/campaign_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.dispatch_seed = 84
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	game._action("toggle_lead")
	check(game.survey.tracked_lead.is_empty(),"the first memo must arrive before its stop can be marked")
	for i in 5:
		file_rotation()
	rig.in_cab = false
	game._refresh()
	game.desk.show_document("fax",game.state)
	await tap_control("toggle_lead")
	check(game.mode == "available" and game.job.is_empty() and game.survey.tracked_lead == "unit","the survey fax alone selects the unpaid visit")
	rig.in_cab = true
	game._refresh()
	var talk_in: String = game._road_note().instruction
	check("left" in talk_in and "north" in talk_in and "triangle" in talk_in and "Section 3" in talk_in,"the survey radio gives the real turn at the gate and the roadside landmarks")
	check(game.county.favor_guide.is_visible_in_tree() and game.county.favor_guide.position.distance_to(game.county.survey_pickup.position) < 7,"the lit red triangle stands by the parked survey pickup")
	game._action("radio")
	await tap_control("respond")
	var original: Dictionary = game.job.duplicate(true)
	check(game.survey.tracked_lead == "unit" and not rig.warning_triangle.visible,"the paying car waits while the selected stop has the only active guide")
	check("next stop is still Section 3 turnout" in game.subtitle,"accepting a paying contract acknowledges the selected unpaid stop")
	game._action("radio")
	await tap_control("toggle_lead")
	check(game.job == original and rig.warning_triangle.visible and not game.county.favor_guide.visible,"deferring immediately restores the paying car's guidance")
	game._action("radio")
	await tap_control("toggle_lead")
	resume_shift()
	check(game.survey.tracked_lead == "unit" and game.job.vin == original.vin and game.job.number == original.number and rig.job_site.is_equal_approx(original.point) and not rig.warning_triangle.visible,"resume retains both destinations and the selected stop")
	rig.set_spawn(game.county.survey_point+Vector3(0,0,9))
	inspect_at("unit",game.county.survey_door_point())
	check("prints north" in hint_text(),"the door inspection leads to the boot prints")
	inspect_at("rod",game.county.rod_case_point())
	check("cab" in hint_text(),"both observations point back to the radio")
	rig.in_cab = true
	game._refresh()
	check("Report" in game._road_note().instruction,"talk-in calls for the report from anywhere")
	var balance: float = game.account.cash
	game._action("radio")
	await tap_control("report_unit")
	check(game.survey.tracked_lead.is_empty() and game.survey.pending_order() == "hold" and game.job.vin == original.vin and rig.warning_triangle.visible,"the report returns guidance to the original paying ticket")
	check(game.completed == 5 and game.pending_slips.is_empty() and game.account.cash == balance,"the favor creates no paid slip")
	if failures == 0:
		await check_later_leads()
	game.free()
	if failures == 0:
		print("CHECKS PASSED — unpaid fax and radio stops, simultaneous paid work, field inspections, directions, markers and cold resume")
	quit(int(failures > 0))

func check_later_leads() -> void:
	for id: String in ["farm","commission","mail","line","bridge","ride","angie"]:
		game.campaign.stage = game.Campaign.ORDER.find(id)
		game.campaign.ordinary_since = game.Campaign.GAPS[game.campaign.stage]
		game.survey.hold_order = "filed"
		if id == "line":
			game.account.equipment["chains"] = true
		game.sync_survey_scene()
		rig.in_cab = true
		game._refresh()
		var slip := int(game.job.number)
		game._action("radio")
		await tap_control("toggle_lead")
		check(game.survey.tracked_lead == id,"can track current lead for " + id)
		if id in ["bridge","ride","angie"]:
			check(not game.county.favor_guide.visible and "finish slip" in hint_text(),"paid-only lead directs the player to clear the active ticket")
			game._action("toggle_lead")
			continue
		check(game.county.favor_guide.visible,"the unpaid field stop has roadside markers for " + id)
		match id:
			"farm":
				inspect_at("house",game.county.story_point("house"))
				inspect_at("farm_ring",game.county.story_point("farm_ring"))
			"commission":
				inspect_at("tower_ladder",game.county.story_point("tower_ladder"))
				glass_lindquist_section()
			"mail": inspect_at("carrier_prints",game.county.story_point("carrier_prints"))
			"line":
				check("N5420" in game._road_note().instruction,"the marked logging-road entrance is named on the talk-in")
				rig.set_spawn(Vector3(441,0,-495))
				check("stakes north" in game._road_note().instruction and "triangle" not in game._road_note().instruction,"after the marked entrance, the talk-in follows the stakes ahead")
				rig.set_spawn(game.county.story_point("last_cap")+Vector3(0,0,5))
				check("corner cap" in game._road_note().instruction,"arriving at the last stake gives the on-foot instruction")
				inspect_at("last_cap",game.county.story_point("last_cap"))
		check(game.survey.tracked_lead.is_empty() and not game.county.favor_guide.visible and rig.warning_triangle.visible,"a completed stop restores the original guide for " + id)
		check(game.job.number == slip and game.completed == 5,"unpaid observation preserves the paying ticket for " + id)
		if id in ["farm","commission","line"]:
			check_report_from_notebook(id)

func check_report_from_notebook(id: String) -> void:
	game.save()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	game._recovered(game.job.kind)
	if game.mode == "haul":
		game._dropped()
	file_at_office()
	var filed: int = game.completed
	check(game._radio_contact().get("id") == "report_notes","the completed visit can be reported without driving back to " + id)
	use_contact("report_notes")
	game._action("report_notes")
	check(game.mode == "available" and game.pending_slips.size() == 1 and game.pending_slips[0].case_id == id,"the radio acknowledgment records exactly one field report for " + id)
	file_at_office()
	check(game.completed == filed+1 and game.campaign.chapter() != id,"faxing the report pays and advances " + id)
	game._restore(snapshot)
	game._refresh()
