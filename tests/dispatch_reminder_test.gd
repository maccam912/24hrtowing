extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	check(game.state.case_lead.is_empty(), "dispatch keeps undiscovered chapters off the radio")
	game.campaign.ordinary_since = game.Campaign.GAPS[0]
	game._refresh()
	check("Optional unpaid favor" in game.state.case_lead and "white survey truck" in game.state.case_lead,
		"the dispatch offer names the unpaid stop before choosing a contract")
	var earlier := "HIGHWAY GARAGE / Arlene needs a door number off the white truck at the Section 3 turnout on Swamp Rd. Check for its equipment before you call."
	game.faxes.append("TAMARACK COUNTY / Service slip\f" + earlier)
	game.desk.show_document("fax",game.state)
	game.desk.fax_sheet = 1
	await tap_control("toggle_lead")
	check(game.survey.tracked_lead == "unit", "the original garage memo also selects the current turnout")
	game._action("toggle_lead")
	game._action("rotation")
	var ticket: int = game.job.number
	var acceptance: String = game.subtitle
	game._check_lead_reminder(1)
	check(game.subtitle == acceptance and game.campaign.last_reminder == -1, "the tow assignment plays in full first")
	game.sub_time = 0
	game._check_lead_reminder(1)
	check("Small favor" in game.subtitle and game.campaign.last_reminder == 0 and game.job.number == ticket,
		"Arlene mentions the favor without switching destinations")
	resume_shift()
	game.sub_time = 0
	game._check_lead_reminder(1)
	check(game.campaign.calls_past_lead == 1 and game.sub_time == 0, "resuming does not repeat an earlier reminder")
	game.campaign.calls_past_lead = 3
	game._check_lead_reminder(1)
	check("Track it on the radio" in game.subtitle and "follow up on the survey case" in game._dispatch_lead_briefing(),
		"taking more paid calls makes the radio choice explicit")
	game.survey.record("unit",rig.odo)
	game.campaign.lead_drive_seconds = 599
	rig.speed = 3.0
	game.sub_time = 0
	game._check_lead_reminder(2)
	check("boot prints" in game.subtitle and "boot prints" in game._dispatch_lead_briefing(),
		"time on the road brings a specific clue for the remaining observation")
	game.survey.tracked_lead = "unit"
	game.campaign.last_reminder = -1
	game.sub_time = 0
	game._check_lead_reminder(1)
	check(game.sub_time == 0, "dispatch leaves the operator to follow the selected lead")
	game.campaign.on_file("hold","unit")
	check(game.campaign.last_reminder == -1 and game.campaign.calls_past_lead == 0 and game.campaign.lead_drive_seconds == 0,
		"the next chapter starts with a fresh reminder schedule")
	game.free()
	if not failures:
		print("CHECKS PASSED — optional dispatch favors, reminders by calls and driving time, evidence and save continuity")
	quit(int(failures > 0))
