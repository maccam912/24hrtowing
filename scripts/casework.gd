extends RefCounted

const Campaign := preload("res://scripts/county_case.gd")
const Sites := preload("res://scripts/county_case_sites.gd")
const PROMPTS := {
	"tower_ladder":"Take hold of the Esker tank ladder", "tower_off":"Step off the ladder",
	"tower_glass":"Raise the field glasses", "tower_lower":"Lower the glasses", "tower_note":"Note the ring of cars",
	"carrier_prints":"Look at the last footprint", "last_cap":"Brush the snow off Tou’s pencil",
	"tou":"Offer Tou the passenger seat", "release":"Countersign Unit 38’s release",
	"angie":"Speak to Angie at the porch",
}
const NOTES := {
	"car_ring":"Esker tank · cars nose to tail around the Lindquist section",
	"carrier_prints":"Route 2 · one set of prints quits mid-stride",
	"last_cap":"Alder Cut · Tou’s pencil at the striped stakes",
	"passenger":"T. Vang · bare ground, warm thermos, one cheek sunburned",
	"release":"TC-96-031 · Unit 38 released to T. Vang", "angie_consent":"N5420 · Angie walked up Alder Cut",
}
const INSPECTIONS := {
	"carrier_prints":"Left boot. Toe dug in like she was taking the next step. Smooth snow from here to the fence.",
	"last_cap":"S3 NW / 1936. Tou’s pencil is lying across the cap. I can see each flake in the headlights, hanging there.",
}
var game
var campaign: Campaign
# A negative height puts Brandt back on foot. The same camera turns on every rung.
var tower_height := -1.0
var glasses := false
var usual_far := 570.0
var released_pickup: Node3D
var departure_path := Curve3D.new()
var departure_distance := 0.0
var departure_speed := 0.0

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
		return {"id":"report_detail","label":"Report the ring of cars" if id == "commission" else "Call in Tou’s pencil"}
	return {}

func ready_to_report() -> bool:
	return not report_label(game.job.get("case_id","")).is_empty()

func report_label(chapter: String) -> String:
	match chapter:
		"farm":
			if game.survey.notes.has("house") and game.survey.notes.has("farm_ring"):
				return "Report the empty Hoffmann place"
		"commission":
			if campaign.evidence.has("car_ring"):
				return "Report the ring of cars"
		"line":
			if campaign.evidence.has("last_cap"):
				return "Call in Tou’s pencil"
	return ""

# These observations are possible on the same trip as an ordinary call. A tow,
# passenger or custody transfer still needs its own dispatch ticket.
func lead_site() -> String:
	match campaign.chapter():
		"unit":
			if not game.survey.unit_reported and game.survey.hold_order.is_empty() and not game.survey.can_report_unit():
				return "survey_pickup"
		"farm":
			if not game.survey.notes.has("house") or not game.survey.notes.has("farm_ring"):
				return "house"
		"commission":
			if not campaign.evidence.has("car_ring"):
				return "tower_ladder"
		"mail":
			if not campaign.evidence.has("carrier_prints"):
				return "carrier_prints"
		"line":
			if game.account.owns("chains") and not campaign.evidence.has("last_cap"):
				return "last_cap"
	return ""

func lead_label() -> String:
	match campaign.chapter():
		"unit": return "Section 3 turnout" if game.survey.hold_order.is_empty() else "Unit 38 evidence hold"
		"farm": return "N5104 Kolpack"
		"line": return "N5420 on Alder Cut"
	return str(Campaign.DETAILS.get(campaign.chapter(),{}).get("landmark",""))

func lead_point(site_id: String) -> Vector3:
	match site_id:
		"survey_pickup": return game.county.resolve_point(game.county.survey_point) + Vector3(-3.6,0,3.4)
		"house": return game.county.story_point("house") + Vector3(-2.8,0,4.0)
		"tower_ladder": return game.county.story_point("tower_ladder") + Vector3(2.6,0,1.8)
		"carrier_prints": return game.county.story_point("mailboxes") + Vector3(-1.5,0,3.4)
		"last_cap": return Vector3(Sites.ALDER_X-4.2,0,-466)
	return Vector3.INF

func lead_instruction() -> String:
	var chapter := campaign.chapter()
	if chapter == "unit" and game.survey.hold_order.is_empty():
		return game.survey.stop_instruction(game.rig.in_cab)
	match lead_site():
		"house":
			return "Check the open door at N5104 Kolpack." if not game.survey.notes.has("house") else "Inspect the bare ring in the Hoffmanns’ drive."
		"tower_ladder": return "Climb the ladder on the east leg of the Esker tank and look across Lindquist’s section."
		"carrier_prints": return "At the Route 2 boxes, follow the prints into the field. Examine the last footprint."
		"last_cap": return "Follow Alder Cut north beyond N5420 on chains. Check the striped stakes for Tou’s pencil."
	if chapter == "line" and not game.account.owns("chains"):
		return campaign.equipment_note()
	if not report_label(chapter).is_empty():
		if game.mode == "available":
			return "Your observations are in the notebook. Call in your report on the cab radio."
		return "Your observations are in the notebook. Finish slip %04d, then radio in the report." % int(game.job.number)
	if game.mode != "available":
		return "Finish slip %04d, then call dispatch for %s." % [int(game.job.number),lead_label()]
	if not game._case_lock().is_empty():
		return game._case_lock()
	return "Use the cab radio to take the county assignment for %s." % lead_label()

func site() -> String:
	if tower_height >= 0.0:
		return tower_action()
	if game.county.case_landmarks.has("car_ring") and game._facing(game.county.story_point("tower_ladder"),3.2):
		return "tower_ladder"
	var id: String = game.job.get("case_id","")
	if id == "ride" and game.mode in ["return","invoice"] and not campaign.released:
		if not game.bay_locked and game.rig.get_truck_position().distance_to(game.BAY) < 60 and game._facing(game.county.bay_latch_point(),3.0):
			return "release"
	if not game.survey.tracked_lead.is_empty():
		var stop := lead_site()
		if stop in ["carrier_prints","last_cap"] and game._facing(game.county.story_point(stop),3.3):
			return stop
	if game.mode != "fieldwork":
		return ""
	var item: String = {"mail":"carrier_prints","line":"last_cap","ride":"tou","angie":"angie"}.get(id,"")
	if item.is_empty() or campaign.evidence.has("angie_consent" if item == "angie" else item):
		return ""
	return item if game._facing(game.county.story_point(item),3.3) else ""

func tower_action() -> String:
	if tower_height == 0.0:
		return "tower_off"
	if tower_height < Sites.TANK_PLATFORM:
		return ""
	if not glasses:
		return "tower_glass"
	if not campaign.evidence.has("car_ring") and ring_in_glass():
		return "tower_note"
	return "tower_lower"

func ring_in_glass() -> bool:
	if not glasses or tower_height != Sites.TANK_PLATFORM or not game.county.case_landmarks.has("car_ring"):
		return false
	var camera: Camera3D = game.rig.get_camera()
	var ring: Vector3 = camera.to_local(game.county.story_point("car_ring"))
	# The whole east-west arc spans about thirteen degrees at this distance.
	# A look at either half of it through the glasses is enough to record it.
	return ring.z < 0.0 and absf(atan2(ring.x,-ring.z)) < deg_to_rad(6.5) and absf(atan2(ring.y,-ring.z)) < deg_to_rad(2.6)

func mount_tower(height: float = 0.0, raised: bool = false) -> void:
	var camera: Camera3D = game.rig.get_camera()
	usual_far = camera.far
	camera.far = 1100.0
	tower_height = clampf(height,0.0,Sites.TANK_PLATFORM)
	glasses = raised and tower_height == Sites.TANK_PLATFORM
	_place_climber()
	game.rig._update_eyes()
	apply_glasses()

func climb(axis: float, dt: float) -> void:
	if tower_height < 0.0 or absf(axis) < .12:
		return
	var next := clampf(tower_height-clampf(axis,-1.0,1.0)*dt*4.2,0.0,Sites.TANK_PLATFORM)
	if next == 0.0 and axis > 0:
		leave_tower()
		game._save()
		return
	if next == tower_height:
		return
	if next == Sites.TANK_PLATFORM:
		game._message("BRANDT","Made the catwalk. Lindquist’s section is southeast, past the dairy silos.")
	tower_height = next
	glasses = false
	_place_climber()

func _place_climber() -> void:
	var ladder: Vector3 = game.county.story_point("tower_ladder")
	game.rig.foot = Vector3(ladder.x+.58,tower_height,ladder.z)

func apply_glasses() -> void:
	if glasses:
		game.rig.get_camera().fov = 11.0

func leave_tower() -> void:
	if tower_height < 0.0:
		return
	tower_height = 0.0
	_place_climber()
	tower_height = -1.0
	glasses = false
	game.rig._update_eyes()
	game.rig.get_camera().far = usual_far

func tower_instruction() -> String:
	var controls := "Push the thumb pad up or down" if game.desk.is_touch_mode() else "Hold W to climb or S to descend"
	if tower_height < Sites.TANK_PLATFORM:
		return controls + ". Let go of the control to rest on a rung."
	if campaign.evidence.has("car_ring"):
		return "The ring is in your field notes. Climb down to the cab when you’re ready."
	return "Look southeast past the dairy silos. Raise the field glasses and use them to record what you can see."

func inspect(item: String) -> void:
	if INSPECTIONS.has(item):
		campaign.evidence[item] = game.rig.odo
		game._finish_favor("mail" if item == "carrier_prints" else "line")
		game._message("BRANDT",INSPECTIONS[item])
	elif item == "tower_ladder":
		mount_tower()
	elif item == "tower_off":
		leave_tower()
	elif item in ["tower_glass","tower_lower"]:
		glasses = item == "tower_glass"
		game.rig._update_eyes()
		apply_glasses()
	elif item == "tower_note" and ring_in_glass():
		campaign.evidence["car_ring"] = game.rig.odo
		game._finish_favor("commission")
		game._message("BRANDT","There’s the Hoffmanns’ blue car. Every hood points at the trunk ahead of it.")
	elif item == "tou":
		if game.rig.get_truck_position().distance_to(game.county.story_point("tou")) > 23.0:
			game._speak("TOU","Bring the cab up here, would you? There’s a seat in there I could use.")
			return
		campaign.evidence["passenger"] = game.rig.odo
		game._record_visit()
		game.mode = "return"
		game._sync_survey_scene()
		game._speak("TOU","Coffee’s still warm. Been forty minutes, maybe. I’d like a ride to my truck.")
	elif item == "release":
		campaign.evidence["release"] = game.rig.odo
		campaign.released = true
		game.held = false
		_start_departure()
		game.filed_card += "\nRELEASE  %s  ·  J. Kowalski / T. Vang / Brandt" % game._clock()
		game._sync_survey_scene()
		game._speak("TOU","There’s my signature. Tell Kowalski she can keep the book. I’ll take Thirty-eight home.")
	elif item == "angie":
		campaign.evidence["angie_consent"] = game.rig.odo
		var met: bool = (game.slips + game.pending_slips).any(func(s): return s.get("vin","") == game.job.vin)
		var intro := "You pulled this one out for me once." if met else "I’m Angie Kraemer. Blue sedan’s mine."
		game._speak("ANGIE",intro + " Take it in, would you? I’m walking up to wait for them. I’m not scared of it. I’d just like to see.")
		game._sync_survey_scene()

func _start_departure() -> void:
	for car in game.physical_cars:
		if is_instance_valid(car) and car.get_meta("vin","") == game.county.Scene.UNIT_VIN:
			released_pickup = car
			break
	if not is_instance_valid(released_pickup):
		return
	game.physical_cars.erase(released_pickup)
	campaign.evidence["unit_departed"] = game.rig.odo
	game.county.Scene.car_lamps(released_pickup,"running",-1)
	# Nose out through the open bay. Round the office, pass through the
	# gate and turn north into the right-hand lane of County K.
	var points: Array[Vector3] = [released_pickup.position,Vector3(-35,0,-45),Vector3(-24,0,-54),
		Vector3(-12,0,-61),Vector3(-4,0,-63),Vector3(2,0,-69),Vector3(2,0,-88),Vector3(2,0,-275)]
	departure_path.clear_points()
	for i in points.size():
		var before := points[maxi(0,i-1)]
		var after := points[mini(points.size()-1,i+1)]
		var tangent := before.direction_to(after)
		departure_path.add_point(points[i],-tangent*points[i].distance_to(before)*.28,tangent*points[i].distance_to(after)*.28)
	departure_distance = 0.0
	departure_speed = 0.0

func advance_departure(dt: float) -> void:
	if game.county.case_models.has("angie_walking"):
		var walking: Node3D = game.county.case_models.angie_walking.get_node("AngieKraemer")
		campaign.angie_walked += dt*1.32
		if Sites.place_angie(game.county,walking,campaign.angie_walked):
			campaign.evidence["angie_left"] = game.rig.odo
			game._sync_survey_scene()
			game._save()
	if not is_instance_valid(released_pickup):
		return
	var length := departure_path.get_baked_length()
	var nose := departure_path.sample_baked(minf(length,departure_distance+3.5))
	if game.rig._in_wrecker(nose) or (not game.rig.in_cab and nose.distance_to(game.rig.foot)<1.1):
		departure_speed = 0.0
		return
	departure_speed = move_toward(departure_speed,3.5 if departure_distance<42 else 10.0,dt*1.75)
	departure_distance = minf(length,departure_distance+dt*departure_speed)
	var at := departure_path.sample_baked(departure_distance)
	var ahead := departure_path.sample_baked(minf(length,departure_distance+.75))
	released_pickup.position = Vector3(at.x,game.county.ground_height(at.x,at.z),at.z)
	if departure_distance < length-.1:
		released_pickup.rotation.y = atan2(at.x-ahead.x,at.z-ahead.z)
	else:
		released_pickup.queue_free()
		released_pickup = null

func procedure() -> String:
	match game.job.get("case_id",""):
		"commission":
			if tower_height >= 0.0:
				return tower_instruction()
			if not campaign.evidence.has("car_ring"):
				return "Find the ladder on the east leg of the Esker water tower. Climb to the tank."
		"bridge":
			if game.rig.phase == "scene":
				return "West on 64. Take the east bank past the dam to the landing. Keep the wrecker ashore and run the line onto the ice."
		"mail":
			if game.rig.phase == "scene":
				return "Recover the carrier’s wagon at the N5104 boxes. One set of boot prints leads into the field."
		"line":
			if not campaign.evidence.has("last_cap"):
				return "Pass N5420 on Alder Cut. Find Tou’s pencil at the striped stakes."
		"ride":
			if game.mode == "fieldwork":
				return "Beyond the stakes at the end of Alder Cut, park beside the bare ring. Speak to Tou."
			if not campaign.released:
				return "Drive Tou to the yard. Open the bay and countersign Unit 38’s release at the chain."
			return "File Tou’s signed release at the office fax."
		"angie":
			if not campaign.evidence.has("angie_consent"):
				return "At N5420 Alder Cut, get Angie’s signature at the porch before rigging."
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
