extends RefCounted

# Each interval starts when the preceding case slip is filed.
const Dispatch := preload("res://scripts/dispatch.gd")
const ORDER := ["unit", "farm", "commission", "bridge", "mail", "line", "ride", "angie"]
const GAPS := [5, 6, 5, 7, 6, 8, 5, 6]
const FAVOR_REQUESTS := {
	"unit":"The highway garage wants the door number off the white survey truck on Swamp Road.",
	"farm":"The milk hauler asked if you could look in at the Hoffmann place on Kolpack.",
	"commission":"Kowalski wants another pair of eyes at the Esker water tower.",
	"mail":"The relief carrier mentioned tracks at the Route 2 boxes. Can you take a look?",
	"line":"County Survey wants someone to check Tou’s old line up Alder Cut.",
}
const LEADS := {
	"unit":"HIGHWAY GARAGE / Get the door number off the white truck at the Section 3 turnout on Swamp. Look for the surveyor before you call.",
	"farm":"MILK ROUTE / Every light is on at N5104 Kolpack. The hauler knocked twice. Tou circled the Hoffmann place in the field book in Unit 38.",
	"commission":"KOWALSKI / Tou drew the Esker water tower in his book. Go up the tank ladder and take a look across Lindquist’s section.",
	"bridge":"SHERIFF / Motor running on the flowage above the dam. No tracks from shore. Bring that sedan to storage.",
	"mail":"RURAL ROUTE 2 / Relief carrier turned up in Marathon County. She’s fine and she’d like her car. Check the N5104 boxes.",
	"line":"COUNTY SURVEY / Follow Tou’s line past the Kraemer place up Alder Cut. The logging road is on the 1936 plat. Fit chains.",
	"ride":"DISPATCH / I picked up Tou’s portable out by the striped stakes. Drive up there and bring him home.",
	"angie":"N5420 ALDER CUT / Angie Kraemer called for her own car to go to storage. Sheriff authorizes. She’ll meet you at the porch.",
}
# Faxes are kept verbatim in the ledger. Earlier copies of the same memo
# still open the current case even when the county's wording has changed.
const EARLIER_MEMOS := {
	"unit":"HIGHWAY GARAGE / Arlene needs a door number",
	"farm":"TC-96-031 / The pickup is cleared for a records check",
	"commission":"KOWALSKI / Bring a pencil to the brass cap",
	"bridge":"COUNTY HIGHWAY / Our crew needs the brass inventory plates",
	"mail":"RURAL ROUTE 2 / Yesterday’s driver added a box",
	"line":"COUNTY SURVEY / Mail for T. Vang came back",
	"ride":"DISPATCH / Tou checked in on the portable",
	"angie":"COUNTY BOARD / Resolution 96-14 adopts T. Vang",
}
const DETAILS := {
	"commission":{
		"title":"The view from the tank", "label":"Go up the Esker tank", "road":"Highway 64", "landmark":"Esker water tower",
		"point":Vector3(48,0,-65),
		"dispatch":"Get up the tank behind the Esker Co-op. Tou drew something on the dairy grid. See if it’s there.",
		"directions":"Behind the co-op at 64 and County K. Park at the tank and look for the ladder on its east leg.",
		"report":"A ring around Lindquist’s, nose to tail? Copy. That blue one sounds like the Hoffmanns’ car. Leave them where they are.",
		"receipt":"TC-96-031 / Vehicles facing nose to tail around the Lindquist section. One blue Hoffmann sedan. No approach tracks."},
	"bridge":{
		"title":"Headlights on the ice", "label":"Take the flowage recovery", "road":"Highway 64", "landmark":"dam landing",
		"point":Vector3(-477,0,-135), "angle":PI, "kind":"hazard", "recovery":"ice", "running":true,
		"vehicle":"Gray sedan", "plate":"GWK 741", "vin":"2G1WL52M2T9171043", "variant":2,
		"dispatch":"Headlights shining at the dam. Car’s level on the ice. Set the truck on the east bank and take every foot of line.",
		"directions":"West on 64 to the river. Before the bridge, follow the east bank north past the dam. Back down the marked landing to pay out the cable.",
		"receipt":"KOWALSKI / The driver came to two counties over, three hours gone. The ones we can reach come home warm. A few are still out. The less traffic there is at night, the fewer it moves. That’s the tow ban."},
	"mail":{
		"title":"The carrier’s last stop", "label":"Tow the Route 2 car", "road":"Kolpack Rd", "landmark":"N5104 mailboxes",
		"point":Vector3(432,0,332), "angle":0.38, "kind":"hazard", "running":true, "mail":true,
		"vehicle":"Relief carrier’s wagon", "plate":"RUH 220", "vin":"1G1BL83P4TR203096", "variant":2,
		"dispatch":"Relief carrier says the last thing she saw was the N5104 boxes. Take her wagon in. Marathon County’s driving her back.",
		"directions":"South on Kolpack past Lindquist’s. At the Hoffmann lane the wagon is beside the Route 2 boxes, mail on the seat.",
		"receipt":"ROUTE 2 / Carrier reunited with wagon. Last delivery still on the front seat. Found forty miles from the route."},
	"line":{
		"title":"The old logging road", "label":"Follow Tou’s line", "road":"Swamp Rd", "landmark":"Alder Cut turn",
		"point":Vector3(441,0,-400),
		"dispatch":"Get the chains on. Past N5420 there’s an old logging road on the 1936 plat. Look for Tou at the striped stakes.",
		"directions":"North on K, right on Swamp. Left before the barricade. Pass the Kraemer place and keep going to the striped witness stakes.",
		"report":"His pencil on the cap? Stay on a minute, Brandt. I’ve got his portable coming through. Tou, county dispatch. Go again.",
		"receipt":"COUNTY SURVEY / T. Vang’s pencil recovered at the 1936 cap. His portable came up on the county channel."},
	"ride":{
		"title":"A ride for the surveyor", "label":"Pick up Tou", "road":"Swamp Rd", "landmark":"Alder Cut turn",
		"point":Vector3(441,0,-400),
		"dispatch":"One passenger, no hook. Tou’s at the end of Alder Cut. Bring the cab right up to him. He wants his truck.",
		"directions":"Left before the east barricade on Swamp. Take the logging road past the house to the clearing beyond the stakes.",
		"receipt":"TC-96-031 / Field book received. T. Vang signed for Unit 38 and tripod. J. Kowalski releases the hold.\fCOUNTY BOARD / Emergency session. Ban extended pending conditions. Sheriff may recover vehicles wherever found."},
	"angie":{
		"title":"Angie at N5420", "label":"Answer N5420", "road":"Alder Cut Rd", "landmark":"N5420",
		"point":Vector3(446.4,0,-466),
		"dispatch":"Angie Kraemer’s on her porch. Wants her sedan taken to storage. Talk to her first.",
		"directions":"North on K, right on Swamp, left before the closure. N5420 is on your right.",
		"receipt":"PUBLIC AUCTION / Unclaimed vehicles in county storage. Owners or representatives may collect before sale. Lot 3: blue sedan, Hoffmann household, N5104 Kolpack."},
}
const QUESTIONS := [
	["Where were you?","Taking a shot on the corner. The wind quit. Forty minutes, maybe. It’s been how long? Then my book’s wrong.","Tou · thought he was gone forty minutes"],
	["The sunburn?","It was warm where I was. That’s all I’ve got.","Tou · it was warm"],
	["The rings?","The ones out in the fields all sit on section corners. It knows where the corners are. Took me twenty years to learn them.","Tou · rings on section corners"],
	["The cars?","Not a dent on one of them. I don’t know if it’s taking them or trying to put them back.","Tou · cars set down undamaged"],
	["The people?","Most come back. They’re all fine. That’s the part I don’t like.","Tou · most people come back"],
	["Why does it follow me?","You’re the only other thing out here that moves cars.","Tou · the lights watch the wrecker"],
	["Is it stopping?","It hasn’t hurried once since the snow started.","Tou · still here"],
	["Why go back out?","Somebody ought to keep the corners.","Tou · will go back to the corners"],
]

var stage := 0
var ordinary_since := 0
var calls_past_lead := 0
var lead_drive_seconds := 0.0
var last_reminder := -1
var evidence := {}
var asked := []
var angie_walked := 0.0
var released := false

static func matches_memo(id: String, sheet: String) -> bool:
	return LEADS.has(id) and (sheet.begins_with(LEADS[id]) or (EARLIER_MEMOS.has(id) and sheet.begins_with(EARLIER_MEMOS[id])))

func chapter() -> String:
	return ORDER[stage] if stage < ORDER.size() else ""

func due() -> bool:
	return stage < ORDER.size() and ordinary_since >= GAPS[stage]

func reminder_level() -> int:
	if calls_past_lead >= 5 or lead_drive_seconds >= 600:
		return 2
	if calls_past_lead >= 3 or lead_drive_seconds >= 300:
		return 1
	return 0

func required_equipment() -> String:
	match chapter():
		"unit": return "snatch_block"
		"line": return "chains"
	return ""

func equipment_note() -> String:
	match chapter():
		"unit": return "Kowalski wants a double line on the loaded survey pickup. Fit a snatch block at the yard office."
		"line": return "Alder Cut is iced over. Fit tire chains at the yard office before taking the corner check."
	return ""

func on_file(kind: String, case_id: String) -> String:
	# A deferred order stays put. Extra rotation work never buys out the next gap.
	if not chapter().is_empty() and case_id == chapter():
		stage += 1
		ordinary_since = 0
		calls_past_lead = 0
		lead_drive_seconds = 0.0
		last_reminder = -1
	elif kind in ["hazard","ditch","passenger"] and case_id.is_empty() and not due() and stage < ORDER.size():
		ordinary_since += 1
		if due():
			return LEADS[chapter()]
	return ""

func ticket(number: int, id := "") -> Dictionary:
	if id.is_empty():
		id = chapter()
	var order: Dictionary = DETAILS[id].duplicate()
	order.merge({"number":number,"id":id,"site":id,"route":id,"case_id":id,"angle":0.0,
		"location":order.road+" · "+order.landmark,"kind":"looksee","vehicle":"Field service","plate":"—","vin":"—"})
	if id == "ride":
		order.receipt += "\fREVISED RATE SCHEDULE / D. Pfaff\nAdditional recovery charges, effective immediately."
		for type: String in ["roof_car","ice_car","field_car"]:
			var rate: Array = Dispatch.RECOVERIES[type]
			order.receipt += "\n%s  $%.2f" % [rate[3],rate[4]]
		order.receipt += "\nStorage as scheduled."
	elif id == "angie":
		var angie: Dictionary = preload("res://scripts/legacy_dispatch.gd").JOBS.angie
		order.merge({"kind":"hazard","vehicle":angie.vehicle,"plate":angie.plate,"vin":angie.vin,"variant":0},true)
	return order

func landmarks() -> Array:
	var result := []
	if (stage == 2 and due()) or stage > 2:
		result.append("car_ring")
		result.append("auction_car" if stage == ORDER.size() else "hoffmann_ring")
	if (stage == 4 and due()) or stage > 4:
		result.append("carrier_prints")
	if (stage == 5 and due()) or stage > 5:
		result.append("last_cap")
	if stage == 6 and due() and not evidence.has("passenger"):
		result.append("tou")
	if stage == 7 and due() and not evidence.has("angie_left"):
		result.append("angie_walking" if evidence.has("angie_consent") else "angie")
	return result

func save_state() -> Dictionary:
	return {"revision":2,"next":chapter(),"ordinary_since":ordinary_since,"evidence":evidence.duplicate(),
		"asked":asked.duplicate(),"released":released,"angie_walked":angie_walked,
		"calls_past_lead":calls_past_lead,"lead_drive_seconds":lead_drive_seconds,"last_reminder":last_reminder}

func restore(data: Dictionary, survey: RefCounted, slips: Array) -> void:
	calls_past_lead = maxi(0, int(data.get("calls_past_lead",0)))
	lead_drive_seconds = maxf(0.0, float(data.get("lead_drive_seconds",0.0)))
	last_reminder = clampi(int(data.get("last_reminder",-1)),-1,2)
	angie_walked = maxf(0,float(data.get("angie_walked",0.0)))
	if not data.is_empty():
		stage = ORDER.find(data.get("next",""))
		if stage < 0:
			stage = ORDER.size()
		ordinary_since = maxi(0,int(data.get("ordinary_since",0)))
		evidence = data.get("evidence",{}).duplicate()
		asked = []
		if int(data.get("revision",1)) >= 2:
			for q in data.get("asked",[]):
				if int(q) >= 0 and int(q) < QUESTIONS.size() and int(q) not in asked:
					asked.append(int(q))
		else:
			for old_key: String in ["checked_sedan","bridge_plate","bridge_plate_far","mailboxes"]:
				evidence.erase(old_key)
			if stage > 2:
				evidence["car_ring"] = 0
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
		if slips[i].get("kind") in ["ditch","hazard","passenger"]:
			ordinary_since += 1
	if not survey.pending_order().is_empty():
		ordinary_since = GAPS[stage]
