extends "res://tests/shift_test.gd"

# Seed 22 gives two different checked cars by the same Lindquist shoulder.
# Stage intervening work to concentrate this test on measuring the complete
# loaded trips, the hard copies, and the decision to give them to dispatch.
func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	game.dispatch_seed = 22
	game._action("play")
	rig = game.rig
	var measured: Array[Dictionary] = []
	for i in 8:
		game._action("rotation")
		var is_run: bool = game.job.get("run") == "farm/east" and game.job.kind == "hazard"
		if is_run:
			check(game.county.lengthened == (measured.size() == 1),"first loaded run on original grid, second on changed ground")
			haul_from_farm()
			if failures:
				break
		else:
			game._recovered(game.job.kind)
			if game.mode == "haul":
				game._dropped()
		rig.in_cab = false
		stand(game.FAX + Vector3.FORWARD, game.FAX)
		game._action("fax")
		check(game.mode == "available" and game.completed == i+1,"file each contract once at the office")
		if is_run:
			measured.append(game.slips.back())
		game.desk.dismiss()
		rig.in_cab = true
		await physics_frame
		await physics_frame
	if measured.size() == 2:
		var original := measured[0]
		var longer := measured[1]
		check(original.vin != longer.vin and original.run == longer.run, "different vehicles on the same measured run")
		var extra: float = (longer.drop_odo-longer.pickup_odo) - (original.drop_odo-original.pickup_odo)
		check(absf(extra-.1) < .005, "the extra ground adds forty metres of actual travel to within two metres")
		check(is_equal_approx(longer.loaded-original.loaded,.1), "the later carbon copy prints precisely one extra tenth")
		for slip: Dictionary in measured:
			check(is_equal_approx(slip.loaded,snappedf(slip.drop_odo-slip.pickup_odo,.1)), "each printed amount comes from its own odometer pair")
		var queried: Dictionary = original if game.survey.queried_slip == original.number else longer
		var query := "RE %04d   Pickup %.1f / drop %.1f. Your %.1f loaded mi, our schedule %.1f." % [
			queried.number,queried.pickup_odo,queried.drop_odo,queried.loaded,queried.schedule]
		check(game.survey.queried_slip == queried.number and query in game.faxes[queried.number-1001], "the clerk references actual readings on a loaded carbon copy")
		check(not game.survey.unit_reported and game.survey.hold_order == "" and game._radio_contact().is_empty(),"mileage and the fax alone leave the case unopened")
		file_authorized_hold()
		check(game._radio_contact().is_empty() and not game.book_read, "the two old carbon copies wait for the operator to choose them")
		for slip: Dictionary in measured:
			game.desk.show_document("slip",game.state)
			game.desk.slip_index = game.slips.find(slip)
			game.desk._activate("clip_slip")
			game.desk.dismiss()
			if slip == original:
				check(game._radio_contact().is_empty(),"a single clipped invoice is no basis for a comparison")
		resume_shift()
		check(game.paired_slips.size() == 2 and game.paired_slips[0].number == original.number and game.paired_slips[1].number == longer.number,
			"the paper clips stay on the selected carbon copies across a cold resume")
		var contact: Dictionary = game._radio_contact()
		check(contact.get("id") == "ask_farm" and str(original.number) in contact.label and str(longer.number) in contact.label, "the radio can put these two slips to Arlene after custody")
		game._action("ask_farm")
		check(game.survey.farm_order == "offered" and game.mode == "available","comparing the two slips requests the optional look-see")
		if not failures:
			print("CHECKS PASSED — same shoulder to storage, %.1f then %.1f loaded mi; measured evidence opens the voluntary follow-up" % [original.loaded,longer.loaded])
	else:
		check(false,"two real Kolpack hauls were filed")
	game.free()
	quit(1 if failures else 0)

func haul_from_farm() -> void:
	# The tow is at the side panel, ready to strap. From pickup to delivery
	# all mileage comes from tire travel under ordinary steering and pedals.
	var pickup: Vector3 = game.county.resolve_point(game.job.point)
	rig.set_spawn(Vector3(400,0,pickup.z),0)
	game._action("interact")
	rig.phase = "at_lift"
	stand(rig._panel()-rig.truck.global_basis.x,rig._panel())
	game._action("interact")
	check(rig.loaded and game.mode == "haul","the panel starts loaded billing at the pickup")
	stand_at_cab_door(-1)
	game._action("interact")
	for point: Vector3 in [Vector3(400,0,13),Vector3(395,0,4),Vector3(380,0,0),
			Vector3(16,0,0),Vector3(6,0,-4),Vector3(0,0,-18),Vector3(0,0,-55),
			Vector3(-6,0,-63),Vector3(-21,0,-68),Vector3(-36,0,-77),Vector3(-54,0,-77)]:
		drive_to(point)
		if failures:
			return
	stop()
	check(rig.at_dropoff(), "the actual loaded rig reached the storage pad: %s" % rig.car.position)
	game._action("interact")
	stand(rig._panel()-rig.truck.global_basis.x,rig._panel())
	game._action("interact")
	check(not rig.loaded and game.mode == "invoice","the delivery panel ends loaded billing at storage")

func file_authorized_hold() -> void:
	visit_survey_turnout()
	game._action("report_unit")
	game._action("take_case")
	check(game.job.kind == "hold","received the deputy’s order")
	game._action("interact")
	var officer: Vector3 = rig.get_witness_position()
	stand(officer+Vector3.BACK,officer)
	game._action("interact")
	game.desk.dismiss()
	var tripod: Vector3 = game.county.hold_tripod_point()
	stand(tripod+Vector3.BACK,tripod)
	game._action("interact")
	check(game.signed_card and game.packed_tripod, "signed for the unit and its tripod")
	# Stage the transfer covered by shift_test. The chain, fax and book keep their ordinary behavior.
	game._recovered("hold")
	game._dropped()
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	var latch: Vector3 = game.county.bay_latch_point()
	stand(latch+Vector3(1.1,0,-1.1),latch)
	game._action("interact")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("fax")
	check(game.held and game.bay_locked and game.survey.hold_order == "filed", "Unit 38 is held on its filed card")
	game.desk.dismiss()
	rig.in_cab = true
	game._refresh()
