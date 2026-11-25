extends RefCounted

const Campaign := preload("res://scripts/county_case.gd")
const Sites := preload("res://scripts/county_case_sites.gd")
const PROMPTS := {
	"tower_ladder":"Climb the Esker tank ladder", "tower_down":"Climb back down",
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
var tower_view: Camera3D
var tower_climb: Tween
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
	match game.job.get("case_id",""):
		"commission": return campaign.evidence.has("car_ring")
		"line": return campaign.evidence.has("last_cap")
	return false

func site() -> String:
	if is_instance_valid(tower_view):
		return "tower_down"
	if game.county.case_landmarks.has("car_ring") and game._facing(game.county.story_point("tower_ladder"),3.2):
		return "tower_ladder"
	var id: String = game.job.get("case_id","")
	if id == "ride" and game.mode in ["return","invoice"] and not campaign.released:
		if not game.bay_locked and game.rig.get_truck_position().distance_to(game.BAY) < 60 and game._facing(game.county.bay_latch_point(),3.0):
			return "release"
	if game.mode != "fieldwork":
		return ""
	var item: String = {"mail":"carrier_prints","line":"last_cap","ride":"tou","angie":"angie"}.get(id,"")
	if item.is_empty() or campaign.evidence.has("angie_consent" if item == "angie" else item):
		return ""
	return item if game._facing(game.county.story_point(item),3.3) else ""

func _climb_tank() -> void:
	# A real view through the operator's binoculars from the catwalk. The same
	# ring stays in the fields if the operator goes looking at road level.
	tower_view = Camera3D.new()
	tower_view.name = "EskerTankView"
	tower_view.far = 1100.0
	tower_view.fov = 60
	game.world.add_child(tower_view)
	var target := Sites.POINTS.car_ring
	var start: Vector3 = game.county.story_point("tower_ladder") + Vector3.UP
	var top := Vector3(start.x+0.65,Sites.TANK_PLATFORM+1.55,start.z)
	tower_view.global_position = start
	tower_view.look_at(target, Vector3.UP)
	tower_view.make_current()
	var view := tower_view
	tower_climb = view.create_tween()
	tower_climb.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tower_climb.tween_method(func(t: float):
		view.global_position = start.lerp(top,t)
		view.look_at(target,Vector3.UP),0.0,1.0,2.2)
	tower_climb.tween_property(view,"fov",11.0,1.1)
	tower_climb.tween_callback(_see_ring)

func _see_ring() -> void:
	if not campaign.evidence.has("car_ring"):
		campaign.evidence["car_ring"] = game.rig.odo
		game._message("BRANDT","There’s the Hoffmanns’ blue car. Every hood points at the trunk ahead of it.")
		game._save()

func leave_tower() -> void:
	if is_instance_valid(tower_view):
		if tower_climb and tower_climb.is_valid():
			tower_climb.kill()
		game.rig.get_camera().make_current()
		tower_view.queue_free()
		tower_view = null

func inspect(item: String) -> void:
	if INSPECTIONS.has(item):
		campaign.evidence[item] = game.rig.odo
		game._message("BRANDT",INSPECTIONS[item])
	elif item == "tower_ladder":
		_climb_tank()
	elif item == "tower_down":
		leave_tower()
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
			if is_instance_valid(tower_view):
				return "Look across Lindquist’s section. Climb down when you’re ready."
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
