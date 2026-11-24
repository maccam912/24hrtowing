extends RefCounted

# Each interval starts when the preceding case slip is filed.
const ORDER := ["unit", "farm", "commission", "bridge", "mail", "line", "ride", "angie"]
const GAPS := [5, 6, 5, 7, 6, 8, 5, 6]
const LEADS := {
	"unit":"HIGHWAY GARAGE / Arlene needs a door number off the white truck at the Section 3 turnout on Swamp Rd. Check for its equipment before you call.",
	"farm":"TC-96-031 / The pickup is cleared for a records check. Read the field book in the hold bay. Mark Tou’s sketch or clip two different mileage readings from the same Kolpack run.",
	"commission":"KOWALSKI / Bring a pencil to the brass cap east of N5104. Call me for the tape detail. The state plat puts that corner under water.",
	"bridge":"COUNTY HIGHWAY / Our crew needs the brass inventory plates checked at both ends of the Highway 64 river bridge. Pick up the detail on your radio.",
	"mail":"RURAL ROUTE 2 / Yesterday’s driver added a box to the Kolpack delivery sheet. The relief carrier says she’s been filling it for years. Arlene has the box check.",
	"line":"COUNTY SURVEY / Mail for T. Vang came back with a turn penciled on it. Left before the barricade on Swamp Rd. Pick up the corner check on the radio.",
	"ride":"DISPATCH / Tou checked in on the portable. He’s at the witness stake you logged. I told him you know the way. Call for the pickup.",
	"angie":"COUNTY BOARD / Resolution 96-14 adopts T. Vang’s resurvey. File the Alder Cut supplement in Sheet 03. Ban extended pending conditions. Nurse at N5420 requests a tow. Sheriff authorizes.",
}
const DETAILS := {
	"commission":{
		"title":"Kowalski’s tape detail", "label":"Take the tape detail", "road":"Kolpack Rd", "landmark":"N5104 crossroad",
		"point":Vector3(445,0,326), "unmapped":true,
		"dispatch":"Kowalski left a roll of checked tape in your door pocket. Rub the cap east of N5104, then check and initial the sedan yourself. Leave it there.",
		"directions":"Kolpack past Lindquist’s. At N5104, the brass cap is between two posts just east of the porch.",
		"report":"Copy S4 northeast. The printed corner is in the swamp. Siebert wants cars checked where they sit. People keep walking for those yard lights. That’s why the ban stays on.",
		"receipt":"TC-96-031 / Added S4 NE rubbing. N5104 sedan checked B.T. Brandt authorized to check vehicles on the survey line."},
	"bridge":{
		"title":"Two ends of TC-14", "label":"Check the bridge plates", "road":"Highway 64", "landmark":"river bridge",
		"point":Vector3(-447,0,0),
		"dispatch":"Highway crew needs the TC-14 plates for a repair order. Park on the Esker side. Get the brass plate on the south rail, then walk it across and read the other.",
		"directions":"West on Highway 64 to the river. Stay on the south rail between the two ends.",
		"report":"Both say east? That explains why the west bearing never came with the parts order. I’ll have them use your pencil copies.",
		"receipt":"HIGHWAY GARAGE / Two EAST ABUTMENT plates, same casting and job number. West bearing to be ordered by photograph."},
	"mail":{
		"title":"The relief carrier’s stop", "label":"Take the route check", "road":"Kolpack Rd", "landmark":"N5104 mailboxes",
		"point":Vector3(437,0,331), "unmapped":true,
		"dispatch":"Back to N5104. Carrier’s route has six stops after the dairy. She brought back a bundle for six-A. Read the band under the lid for me.",
		"directions":"Turn into the N5104 lane south of Lindquist’s silo. Look for the pair of boxes between the road and the house.",
		"report":"Tou had it held there. His wife says he never had a box out that way. I’ll get the highway garage to read the note he sent them.",
		"receipt":"RURAL ROUTE 2 / Box 6A, HOLD AT BOX for T. Vang. The carrier’s substitute book has four winters of plow detours penciled beside that stop."},
	"line":{
		"title":"Tou’s last corner", "label":"Run the survey line", "road":"Swamp Rd", "landmark":"Alder Cut turn",
		"point":Vector3(441,0,-400),
		"dispatch":"Head for the east closure on Swamp. Just short of it there’s a left called Alder Cut. Follow it north to the witness stake. I need the full stamp off the cap.",
		"directions":"North on K, right on Swamp. Turn left just before the east barricade. Red and white stakes mark the corner up Alder Cut.",
		"report":"S3 northwest, 1936. Same corner on his first sheet. Garage found his figures: 5,280 feet the first night, 5,402.6 on the last pass. He asked for your tow slips by name.",
		"receipt":"OFFICE OF THE SURVEYOR / Corner recovered. Original monument retained. T. Vang requested Brandt’s independent mileage readings before leaving the office."},
	"ride":{
		"title":"A ride for the surveyor", "label":"Pick up Tou", "road":"Swamp Rd", "landmark":"Alder Cut turn",
		"point":Vector3(441,0,-400),
		"dispatch":"Brandt, one passenger, no hook. Tou’s by the lamp past the last cap. Pull the truck up and offer him the passenger seat. His pickup’s still at your yard.",
		"directions":"Left before the east barricade on Swamp. Up Alder Cut, just beyond the red and white witness stake.",
		"receipt":"TC-96-031 / Resurvey received at Brandt yard. Unit 38 released by J. Kowalski. T. Vang signed for truck and tripod."},
	"angie":{
		"title":"Angie’s last tow", "label":"Answer N5420", "road":"Alder Cut Rd", "landmark":"N5420",
		"point":Vector3(446.4,0,-466),
		"dispatch":"N5420 Alder Cut. Angie Kraemer wants her old sedan hauled to storage. Talk to her at the porch before you hook it. Sheriff’s cleared the move.",
		"directions":"North on K, right on Swamp, left just before the closure. Halfway up Alder Cut, N5420 is on the right.",
		"receipt":"ACCOUNTS PAYABLE / From this slip forward, loaded miles paid as recorded. Prior overages accepted. The tow ban remains in effect. — D. Pfaff"},
}
const QUESTIONS := [
	["Ask about the corners","The corners haven’t moved. I set that north one myself. Every time I chain the line there’s more ground to cross.","Tou · old corners still in place"],
	["Ask about the drivers","They make it to the light. Stove works. There’s a bed. A fellow tried to walk back three times. Each time it took longer to reach his own gate.","Tou · the walk home gets longer"],
	["Ask why he wanted your slips","Your odometer and mine were the only two things in this county that agreed. Doreen gave me the carbons. I kept every one.","Tou · Brandt’s slips match his log"],
	["Ask if it stops","It isn’t speeding up. It isn’t slowing down. You can drop me by my truck. Somebody’s got to keep the corners.","Tou · rate of change steady"],
]

var stage := 0
var ordinary_since := 0
var evidence := {}
var asked := []
var released := false

func chapter() -> String:
	return ORDER[stage] if stage < ORDER.size() else ""

func due() -> bool:
	return stage < ORDER.size() and ordinary_since >= GAPS[stage]

func on_file(kind: String, case_id: String) -> String:
	# A deferred order stays put. Extra rotation work never buys out the next gap.
	if not chapter().is_empty() and case_id == chapter():
		stage += 1
		ordinary_since = 0
	elif kind in ["hazard","ditch"] and case_id.is_empty() and not due() and stage < ORDER.size():
		ordinary_since += 1
		if due():
			return LEADS[chapter()]
	return ""

func ticket(number: int) -> Dictionary:
	var id := chapter()
	var order: Dictionary = DETAILS[id].duplicate()
	order.merge({"number":number,"id":id,"site":id,"route":id,"case_id":id,"angle":0.0,
		"location":order.road+" · "+order.landmark,"kind":"looksee","vehicle":"Field service","plate":"—","vin":"—"})
	if id == "angie":
		var angie: Dictionary = preload("res://scripts/legacy_dispatch.gd").JOBS.angie
		order.merge({"kind":"hazard","vehicle":angie.vehicle,"plate":angie.plate,"vin":angie.vin,"variant":0},true)
	return order

func landmarks() -> Array:
	var result := []
	if (stage == 3 and due()) or stage > 3:
		result.append("bridge_plate")
	if (stage == 4 and due()) or stage > 4:
		result.append("mailboxes")
	if (stage == 5 and due()) or stage > 5:
		result.append("last_cap")
	if stage == 6 and due() and not evidence.has("passenger"):
		result.append("tou")
	if (stage == 7 and due()) or stage > 7:
		result.append("angie_house")
		if stage == 7:
			result.append("angie")
	if evidence.has("mailboxes"):
		result.append("mail_open")
	if evidence.has("checked_sedan"):
		result.append("checked_sedan")
	return result

func save_state() -> Dictionary:
	return {"next":chapter(),"ordinary_since":ordinary_since,"evidence":evidence.duplicate(),
		"asked":asked.duplicate(),"released":released}

func restore(data: Dictionary, survey: RefCounted, slips: Array) -> void:
	if not data.is_empty():
		stage = ORDER.find(data.get("next",""))
		if stage < 0:
			stage = ORDER.size()
		ordinary_since = maxi(0,int(data.get("ordinary_since",0)))
		evidence = data.get("evidence",{}).duplicate()
		asked = data.get("asked",[]).map(func(n): return int(n))
		released = data.get("released",false)
		return
	stage = 2 if survey.farm_order == "filed" else (1 if survey.hold_order == "filed" else 0)
	ordinary_since = 0
	evidence = {}
	asked = []
	released = false
	for i in range(slips.size()-1,-1,-1):
		if slips[i].get("kind") in ["hold","looksee"]:
			break
		if slips[i].get("kind") in ["ditch","hazard"]:
			ordinary_since += 1
	if not survey.pending_order().is_empty():
		ordinary_since = GAPS[stage]
