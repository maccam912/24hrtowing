extends SceneTree
const Dispatch := preload("res://scripts/dispatch.gd")
var failed := false

func check(ok: bool, note: String) -> void:
	if not ok:
		failed = true
		printerr(note)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://game.tscn").instantiate()
	root.add_child(game)
	var lines: Dictionary = game.audio.lines
	for id in lines:
		game._say(id)
		var stream := game.audio.chatter.stream as AudioStreamWAV
		check(stream != null and stream.get_length() > 0, "Missing chatter for " + id)
		check(game.speaker == lines[id][0] and game.subtitle == lines[id][1], "Subtitle for " + id)
		check(stream != null and game.sub_time > stream.get_length(), "Reading time for " + id)
		var radio: bool = game.speaker in ["DISPATCH", "COUNTY PLOW"]
		check(game.audio.chatter.bus == (&"County radio" if radio else &"Master"), "Audio routing for " + id)
	var first_sites := {}
	for seed_value in [1197, 8820, 91317, 44, 98]:
		var slips := []
		var sites := {}
		var shoulders := {}
		var setups := {}
		var forms := {}
		var nurse_calls := 0
		for i in 20:
			var ticket := Dispatch.ordinary(i,seed_value,slips)
			if i == 0:
				check(ticket.kind == "ditch" and Dispatch.SITES[ticket.site].local,"A new operator gets a local ditch pull")
				first_sites[ticket.site] = true
			check(ticket.kind in ["ditch","hazard"] and ticket.number == 1001+i, "Ordinary work always stays on rotation")
			check(ticket.plate != "WI CO 038" and ticket.vin != Dispatch.Legacy.JOBS.hold.vin, "Unit 38 is reserved")
			check(ticket.road in ticket.dispatch and ticket.shoulder in ticket.dispatch and ticket.shoulder in ticket.directions,
				"Radio describes the recorded road and shoulder")
			check(ticket.vehicle in ticket.dispatch and ticket.vehicle.to_lower() in ticket.directions,"Vehicle description matches both calls")
			check(ticket.vehicle == Dispatch.VEHICLES[ticket.variant], "Vehicle matches the scene")
			var site: Dictionary = Dispatch.SITES[ticket.site]
			var station: Vector2 = site.station
			match ticket.shoulder:
				"east": check(ticket.point.x > station.x and is_equal_approx(ticket.point.z, station.y), "Car on east side")
				"west": check(ticket.point.x < station.x and is_equal_approx(ticket.point.z, station.y), "Car on west side")
				"south": check(ticket.point.z > station.y and is_equal_approx(ticket.point.x, station.x), "Car on south side")
				"north": check(ticket.point.z < station.y and is_equal_approx(ticket.point.x, station.x), "Car on north side")
			var saved := Dispatch.unpack(JSON.parse_string(JSON.stringify(Dispatch.pack(ticket))))
			check(saved.point.is_equal_approx(ticket.point) and saved.vin == ticket.vin and saved.directions == ticket.directions,
				"Save preserves the actual scene and call")
			if ticket.site == "swamp":
				check(ticket.point.x > Dispatch.Legacy.JOBS.hold.point.x + 40, "Ordinary Swamp Road call passes the separate survey truck")
			check(lines.has(ticket.reply), "Driver has a recorded reply")
			nurse_calls += int(ticket.id == "angie")
			sites[ticket.site] = true
			shoulders[ticket.shoulder] = true
			setups[roundi(rad_to_deg(ticket.angle))] = true
			forms[ticket.kind] = true
			var slip := Dispatch.issue_slip(ticket,19240,19241.2,19242.48,83,"04:30")
			check(slip.pay >= 60 and slip.winch == 12, "County schedule pays each recovery")
			if ticket.kind == "hazard":
				check(is_equal_approx(slip.loaded,1.3) and slip.storage == 12 and slip.schedule > 0, "Metered loaded haul and printed schedule")
			else:
				check(slip.loaded == 0 and slip.storage == 0, "No loaded charges for a self-departing driver")
			slips.append(slip)
		check(nurse_calls <= 1, "Angie has one introduction")
		check(sites.size() == Dispatch.SITES.size() and shoulders.size() == 4 and setups.size() > 8 and forms.size() == 2,
			"A twenty-call shift covers the county, both recoveries and different approaches")
	check(first_sites.size() >= 2, "Different saves have different local first pulls")
	var legacy := Dispatch.legacy_ticket(3,lines)
	check(legacy.id == "bridge" and legacy.number == 1004 and legacy.plate == "EWG 044", "Legacy active ticket keeps its original vehicle")
	check(Dispatch.legacy_ticket(9,lines).plate == Dispatch.Legacy.ticket(9,lines).plate, "Legacy repeat dispatch remains reproducible")
	var hold := Dispatch.hold_ticket(22,lines)
	check(hold.kind == "hold" and hold.number == 1023 and hold.vin == Dispatch.Legacy.JOBS.hold.vin, "A requested hold uses the original county truck and current slip number")
	var visit := Dispatch.issue_slip(Dispatch.looksee(23),19240,19241,19242,0,"04:30")
	check(visit.pay == 38 and visit.loaded == 0 and visit.storage == 0 and visit.winch == 0 and visit.hookup == 0, "A look-see pays the visit only")
	var pair := [
		{"kind":"hazard","site":"farm","run":"farm/east","number":1012,"loaded":2.0},
		{"kind":"hazard","site":"farm","run":"farm/west","number":1022,"loaded":2.1}]
	check(Dispatch.matching_kolpack_slips(pair).is_empty(), "Different shoulders cannot establish a repeated run")
	pair.append({"kind":"hazard","site":"farm","run":"farm/east","number":1041,"loaded":2.1})
	check(Dispatch.matching_kolpack_slips(pair) == [pair[0],pair[2]], "The differences refer back to two real carbon copies")
	test_waiting_hazard(game)
	if not failed:
		print("CHECKS PASSED — local rotation, invoicing, generated directions, identity and case paperwork")
	quit(1 if failed else 0)

func test_waiting_hazard(game) -> void:
	game._action("play")
	game.set_physics_process(false)
	# The next caller is already checked and waiting when Brandt reports the rod case.
	game.completed = 1
	game.slips = [Dispatch.issue_slip(game.rotation_offer,19240,19241,19241,24,"04:30")]
	game.rotation_offer = {}
	game.county.set_lengthened(true)
	game._prepare_offers()
	var offer: Dictionary = game.rotation_offer.duplicate()
	var parked: Node3D = game.waiting_hazard
	var pose := parked.transform
	game.survey.record("unit",19241)
	game.survey.record("rod",19241)
	game.campaign.ordinary_since = 5
	game._action("report_unit")
	game._action("take_case")
	check(game.job.kind == "hold" and game.waiting_hazard == parked and parked.transform == pose,
		"A separate case leaves the offered taped car where it was seen")
	game._save()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	game.free()
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.saved_data = snapshot
	game._action("play")
	check(game.job.kind == "hold" and game.rotation_offer.vin == offer.vin and game.waiting_hazard.transform.is_equal_approx(pose),
		"Resume restores both scenes at their own places")
	# shift_test exercises the actual transfer. Here, file it and take the waiting tow.
	game.rig.end_job()
	game.held = true
	game.bay_locked = true
	game.mode = "invoice"
	game.rig.in_cab = false
	game.rig.foot = game.FAX
	game._file_invoice()
	check(game.rotation_offer.number == offer.number + 1 and game.rotation_offer.vin == offer.vin,
		"The county assigns the next blank slip to the original waiting vehicle")
	check(game.waiting_hazard.transform.is_equal_approx(pose),"Filing a separate slip preserves the parked car's pose")
	game.rig.in_cab = true
	game._action("rotation")
	check(game.waiting_hazard == null and game.rig.car.transform.is_equal_approx(pose) and game.rig.vehicle_identity.vin == offer.vin,
		"Accepting the hazard hands the single vehicle at the original position to the rig")
