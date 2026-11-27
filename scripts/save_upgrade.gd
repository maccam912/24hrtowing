extends RefCounted
## Brings a shift saved by an earlier build up to the shape this build
## restores. Each step names the saves it serves and leaves a current save
## as it is, so the steps run on every load.

const Dispatch := preload("res://scripts/dispatch.gd")
const Campaign := preload("res://scripts/county_case.gd")

## Steps that need only the saved data. Returns an upgraded copy.
static func before_restore(save: Dictionary, lines: Dictionary) -> Dictionary:
	var s := save.duplicate(true)
	var ticket: Dictionary = s.get("ticket",{})
	# Aftermath tickets from before the observation log named only their trace.
	if ticket.has("aftermath_key") and not ticket.has("observation_key"):
		ticket.observation_key = "order/%d/%s" % [int(ticket.number),ticket.aftermath_key]
	# Version 1 kept an open job only as its call index and the rig's physical state.
	if s.get("mode","available") != "available" and ticket.is_empty():
		s.ticket = Dispatch.pack(Dispatch.legacy_ticket(int(s.completed),lines))
	# The growing-county build lengthened Kolpack Road by 40 m south of the
	# Lindquist farm. Its rig snapshots kept world metres on that longer road.
	if not s.has("sightings") and s.get("longer",false):
		_plat_positions(s.rig)
		for departure: Dictionary in s.rig.get("departures",[]):
			_plat_positions(departure)
	return s

static func _plat_positions(snapshot: Dictionary) -> void:
	for key in ["truck","foot","site","car","witness","flare"]:
		var point = snapshot.get(key)
		if point is Array and point.size() == 3:
			var z := float(point[2])
			point[2] = z - 40.0 * clampf((z - 164.0) / 112.0,0,1)

## Saves from before the shop account offered Unit 38 from the survey's own
## pending order. Runs once the survey is restored.
static func hold_offer(game, s: Dictionary) -> void:
	if not s.has("account") and game.survey.pending_order() == "hold" and game.case_offer.is_empty():
		game.case_offer = Dispatch.hold_ticket(game.completed,game.audio.lines)
		game.case_offer.point = game.county.survey_point
		game.case_offer.angle = game.county.survey_yaw

## Saves from before the sighting director told the old story's case calls.
## Runs once the campaign is restored, before the rig.
static func case_ticket(game, s: Dictionary, rig_state: Dictionary) -> void:
	if s.has("sightings"):
		return
	if game.case_offer.get("id") == "n5104":
		game.case_offer = Dispatch.looksee(int(game.case_offer.number)-1001)
	if game.job.get("id") == "n5104":
		game.job = Dispatch.looksee(int(game.job.number)-1001)
	var id: String = game.job.get("case_id","")
	if not Campaign.DETAILS.has(id) or id != game.campaign.chapter():
		return
	var original_kind: String = game.job.kind
	game.job = game.campaign.ticket(int(game.job.number))
	var job: Dictionary = game.job
	if game.mode == "fieldwork" and original_kind == "looksee" and job.kind == "hazard":
		# The former bridge and mailbox inspections now dispatch actual recoveries.
		rig_state.merge({"kind":job.kind,"phase":"scene","site":[job.point.x,job.point.y,job.point.z],
			"site_yaw":job.angle,"identity":job.duplicate(),"loaded":false,"line_end":-1},true)
		for key in ["car","car_rot","flare"]:
			rig_state.erase(key)

## Older rig snapshots kept the casualty's identity, or its case, only on the
## dispatch ticket.
static func rig_identity(rig_state: Dictionary, job: Dictionary) -> void:
	if not job.is_empty() and not rig_state.has("identity"):
		rig_state.identity = job
	elif job.has("case_id") and job.kind == rig_state.get("kind"):
		rig_state.identity.case_id = job.case_id

## Older shifts kept finished roadside work as the open ticket until the yard
## fax. That work now waits on the clipboard instead.
static func finished_roadside(mode: String, job: Dictionary) -> bool:
	return mode in ["return","invoice"] and job.get("kind") in ["ditch","looksee"] and job.get("case_id") != "ride"
