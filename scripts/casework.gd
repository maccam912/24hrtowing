extends RefCounted

const Campaign := preload("res://scripts/county_case.gd")
const PROMPTS := {
	"checked_sedan":"Initial the check tape on the mirror", "bridge_plate":"Copy the east bridge plate",
	"bridge_plate_far":"Copy the west bridge plate", "mailboxes":"Lift the lid on box 6A",
	"last_cap":"Brush off the last cap", "tou":"Offer Tou the passenger seat",
	"release":"Countersign Unit 38’s release", "angie":"Speak to Angie at the porch",
}
const NOTES := {
	"checked_sedan":"N5104 · mirror taped B.T.", "bridge_plate":"East rail · TC-14 EAST ABUTMENT",
	"bridge_plate_far":"West rail · TC-14 EAST ABUTMENT", "mailboxes":"Route 2, box 6A · hold for T. Vang",
	"last_cap":"Alder Cut · S3 NW / 1936", "passenger":"T. Vang found north of S3 NW",
	"release":"TC-96-031 · Unit 38 released", "angie_consent":"N5420 · A. Kraemer signed for tow",
}
const INSPECTIONS := {
	"checked_sedan":"Empty seats. I looped the yellow tape through the mirror and wrote B.T. beside the date.",
	"bridge_plate":"South rail, Esker end. TC-14 / EAST ABUTMENT / 1931. Four square nails. Copper stain below the fourth.",
	"bridge_plate_far":"South rail, River Lanes end. TC-14 / EAST ABUTMENT / 1931. Same copper stain. There’s river under the whole walk back.",
	"mailboxes":"The band inside 6A says HOLD AT BOX / T. VANG. There’s a groove in the hinge deep enough to catch my glove.",
	"last_cap":"S3 NW / 1936. A red stake marks the line. Tou’s pencil lies in the snow groove where he set his clipboard down.",
}
var game
var campaign: Campaign

func _init(owner_game: Node, county_case: Campaign) -> void:
	game = owner_game
	campaign = county_case

func contact() -> Dictionary:
	var id := campaign.chapter()
	if game.mode == "available" and game._case_due() and Campaign.DETAILS.has(id):
		return {"id":"take_detail","label":Campaign.DETAILS[id].label}
	if game.job.get("case_id","") == "ride" and campaign.evidence.has("passenger") and not campaign.released:
		return {"id":"talk_tou","label":"Talk to Tou"}
	if game.mode == "fieldwork" and ready_to_report():
		return {"id":"report_detail","label":"Radio in the " + {"commission":"tape check","bridge":"two plates","mail":"route band","line":"cap stamp"}[id]}
	return {}

func ready_to_report() -> bool:
	match game.job.get("case_id",""):
		"commission": return campaign.evidence.has("checked_sedan")
		"bridge": return campaign.evidence.has("bridge_plate") and campaign.evidence.has("bridge_plate_far")
		"mail": return campaign.evidence.has("mailboxes")
		"line": return campaign.evidence.has("last_cap")
	return false

func site() -> String:
	var id: String = game.job.get("case_id","")
	if id == "ride" and game.mode in ["return","invoice"] and not campaign.released:
		if not game.bay_locked and game.rig.get_truck_position().distance_to(game.BAY) < 60 and game._facing(game.county.bay_latch_point(),3.0):
			return "release"
	if game.mode != "fieldwork" or id.is_empty():
		return ""
	var locations: Array
	match id:
		"commission":
			if game.survey.notes.has("cap") and not campaign.evidence.has("checked_sedan") and game._facing(game.county.story_point("vin"),3.2):
				return "checked_sedan"
		"bridge": locations = ["bridge_plate","bridge_plate_far"]
		"mail": locations = ["mailboxes"]
		"line": locations = ["last_cap"]
		"ride": locations = ["tou"]
		"angie":
			if not campaign.evidence.has("angie_consent"):
				locations = ["angie"]
	for item: String in locations:
		if not campaign.evidence.has(item) and game._facing(game.county.story_point(item),3.3):
			return item
	return ""

func inspect(item: String) -> void:
	if INSPECTIONS.has(item):
		campaign.evidence[item] = game.rig.odo
		game._message("BRANDT",INSPECTIONS[item])
		if item == "checked_sedan":
			game.audio.effect("ratchet")
		if item in ["checked_sedan","mailboxes"]:
			game._sync_survey_scene()
	elif item == "tou":
		if game.rig.get_truck_position().distance_to(game.county.story_point("tou")) > 23.0:
			game._speak("TOU","Bring the cab up here, would you? I’ve been carrying this book all night.")
			return
		campaign.evidence["passenger"] = game.rig.odo
		game._record_visit()
		game.mode = "return"
		game._sync_survey_scene()
		game._speak("TOU","I’ve got my book. Take me to Thirty-eight. Heater still work on your side?")
	elif item == "release":
		campaign.evidence["release"] = game.rig.odo
		campaign.released = true
		game.held = false
		game.filed_card += "\nRELEASE  %s  ·  J. Kowalski / T. Vang / Brandt" % game._clock()
		game._sync_survey_scene()
		game._speak("TOU","That’s my signature. The tripod goes back on the seat. Send the county my figures, would you?")
	elif item == "angie":
		campaign.evidence["angie_consent"] = game.rig.odo
		var met: bool = (game.slips + game.pending_slips).any(func(s): return s.get("vin","") == game.job.vin)
		var intro := "You pulled this one out for me once." if met else "I’m Angie Kraemer. Blue sedan’s mine."
		game._speak("ANGIE",intro + " Take it in. I can walk to work from here now. No, I don’t need a lift.")

func procedure() -> String:
	match game.job.get("case_id",""):
		"commission":
			if not game.survey.notes.has("cap"):
				return "Rub the brass cap between the posts east of the N5104 porch."
			if not campaign.evidence.has("checked_sedan"):
				return "Check the sedan and initial the tape at its windshield."
		"bridge":
			if not campaign.evidence.has("bridge_plate"):
				return "Copy the plate on the south rail at the Esker end of the bridge."
			if not campaign.evidence.has("bridge_plate_far"):
				return "Walk the south rail west toward River Lanes. Copy the plate at the far end."
		"mail":
			if not campaign.evidence.has("mailboxes"):
				return "Find the two boxes in the N5104 lane. Read the band inside 6A."
		"line":
			if not campaign.evidence.has("last_cap"):
				return "Turn left before the Swamp Rd barricade. Read the cap beside the striped stakes."
		"ride":
			if game.mode == "fieldwork":
				return "Park at the mercury lamp north of the last cap on Alder Cut. Speak to Tou."
			if not campaign.released:
				return "Drive Tou to the yard. Open the bay and countersign Unit 38’s release at the chain."
			return "File Tou’s signed release at the office fax."
		"angie":
			if not campaign.evidence.has("angie_consent"):
				return "At N5420 Alder Cut, get the owner’s signature at the porch before rigging."
			return ""
	if ready_to_report():
		return "Back in the cab, radio your findings to Arlene."
	return ""

func notebook() -> Array:
	var rows := []
	for item: String in NOTES:
		if campaign.evidence.has(item):
			rows.append(NOTES[item])
			if item == "passenger":
				for question: int in campaign.asked:
					rows.append(Campaign.QUESTIONS[question][2])
	return rows
