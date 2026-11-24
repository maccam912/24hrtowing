extends SceneTree

const Dispatch := preload("res://scripts/dispatch.gd")
var failed := false
var game

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr(message)
		failed = true

func old_save() -> Dictionary:
	game._save()
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	data.version = 1
	data.paid = game.account.cash
	data.pending = game.account.pending
	for key in ["offer","case_offer","ticket","survey","dispatch_seed","survey_anchor","campaign","account","pending_slips"]:
		data.erase(key)
	data.rig.erase("identity")
	data.rig.erase("snatch_block")
	return data

func load_shift(data: Dictionary) -> void:
	game.free()
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.saved_data = data
	game._action("play")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	# A released v1 ditch was still the active ticket until the next yard visit.
	game._accept(Dispatch.legacy_ticket(0,game.audio.lines))
	var roadside := old_save()
	roadside.mode = "return"
	roadside.rig.phase = "departing"
	roadside.pickup = 19241.1
	roadside.drop = roadside.pickup
	roadside.pickup_time = "03:24"
	roadside.drop_time = roadside.pickup_time
	load_shift(roadside)
	check(game.mode == "available" and game.pending_slips.size() == 1 and game.completed == 0, "an unfiled legacy ditch resumes ready for dispatch")
	game._action("rotation")
	check(game.job.number == 1002 and game.job.kind == "hazard", "the recovered v1 ditch counts toward the next numbered call")
	game.rig.in_cab = false
	game.rig.foot = game.FAX
	game._action("fax")
	check(game.slips.size() == 1 and game.slips[0].vin == Dispatch.Legacy.JOBS.angie.vin and is_equal_approx(game.slips[0].pickup_odo,roadside.pickup), "the legacy slip still files with its original VIN and pickup")
	load_shift({})
	# A v1 recovery existed only as its index and the physical rig state.
	game.completed = 3
	var ticket := Dispatch.legacy_ticket(3,game.audio.lines)
	game._accept(ticket)
	var old := old_save()
	old.paid = 21.50
	old.pending = 66.15
	old.slips = [
		{"number":1001,"kind":"ditch","loaded":0,"pay":95,"location":"County K"},
		{"number":1002,"kind":"hazard","loaded":0.5,"pay":66.15,"location":"Highway 64"}]
	old.rig.chains = true
	old.rig.phase = "rigged"
	old.rig.cab = false
	old.rig.line_end = 1
	old.rig.car = [-432.5,0,4.1]
	old.rig.foot = [-433.2,0,3.1]
	load_shift(old)
	check(is_equal_approx(game.account.earned,161.15) and is_equal_approx(game.account.cash,21.5) and is_equal_approx(game.account.pending,66.15), "a migrated account preserves archived invoices and the till after spending")
	check(game.account.owns("chains") and game.rig.tire_chains and not game.account.owns("snatch_block"), "old fitted chains survive as owned equipment")
	check(game.job.plate == "EWG 044" and game.job.id == "bridge" and game.job.number == 1004,"old bridge ticket changed its terms")
	check(game.rig.phase == "rigged" and game.rig.car.position.is_equal_approx(Vector3(-432.5,0,4.1)) and not game.rig.in_cab,"legacy rigging or operator pose changed")
	check(game.rig.vehicle_identity.plate == game.job.plate,"migrated casualty plate differs from its slip")
	var pickup: float = game.rig.odo
	game._recovered("hazard")
	game.rig.odo += 1.5
	game._dropped()
	game.rig.foot = game.FAX
	game._action("fax")
	var slip: Dictionary = game.slips.back()
	check(slip.number == 1004 and slip.loaded == 1.5 and slip.pickup_odo == pickup and slip.plate == ticket.plate,"migrated job failed to file its actual miles")
	check(game.rotation_offer.kind in ["ditch","hazard"] and game.survey.pending_order() == "","old fourth slip should not force a fifth-call hold")
	# Another operator already has the truck and a signed paper card in the yard.
	var archived := old_save()
	archived.completed = 5
	archived.held = true
	archived.bay_locked = true
	archived.signed = true
	archived.tripod = true
	archived.longer = true
	archived.book_read = true
	archived.filed_card = "TC-96-031  /  Survey Unit 38\nOriginal signatures and odometer readings"
	archived.faxes = ["Original county correspondence"]
	archived.rig.cab = true
	archived.rig.truck = [-22,0,-65]
	load_shift(archived)
	check(game.survey.hold_order == "filed" and game.held and game.bay_locked,"custody was lost on migration")
	check(not game.survey.unit_reported and not game.survey.can_report_unit(),"migration invented a player report or reopened a settled case")
	check(game.filed_card == archived.filed_card and game.faxes == archived.faxes,"historical signed paperwork changed on migration")
	check(not game.county.survey_pickup.visible and game.physical_cars[0].visible and game.case_offer.is_empty(),"generated a second copy of a secured unit")
	game.campaign.ordinary_since = 6
	game.desk.show_document("field",game.state)
	game.desk._activate("mark_sketch")
	check(game._radio_contact().get("id") == "ask_farm","an older operator cannot follow the next lead")
	# A version-two operator reported Unit 38 while out on a different run.
	# The hold could be authorized before there was a separate saved offer.
	var deferred := old.duplicate(true)
	deferred.version = 2
	deferred.survey = {"unit_reported":true,"hold_order":"deferred"}
	deferred.campaign = {"next":"unit","ordinary_since":5}
	deferred.ticket = Dispatch.pack(ticket)
	load_shift(deferred)
	check(game.job.id == "bridge" and not game.account.owns("snatch_block"), "migration continues the active ordinary tow on its own terms")
	game._save()
	load_shift(JSON.parse_string(JSON.stringify(game.saved_data)))
	game._recovered("hazard")
	game._dropped()
	game.rig.in_cab = false
	game.rig.foot = game.FAX
	game._action("fax")
	game.desk.dismiss()
	game.rig.in_cab = true
	game._action("take_case")
	check(game.job.get("kind") == "hold" and not game.job.get("heavy_recovery",false) and not game.account.owns("snatch_block"), "an already authorized county hold still opens at its old rate without a purchase, even after a second resume")
	game.free()
	if not failed:
		print("CHECKS PASSED — version-one active rigging, payable bridge ticket, existing custody and later lead")
	quit(int(failed))
