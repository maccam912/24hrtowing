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
	for key in ["offer","case_offer","ticket","survey","dispatch_seed","survey_anchor","campaign"]:
		data.erase(key)
	data.rig.erase("identity")
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
	# A v1 recovery existed only as its index and the physical rig state.
	game.completed = 3
	var ticket := Dispatch.legacy_ticket(3,game.audio.lines)
	game._accept(ticket)
	var old := old_save()
	old.rig.phase = "rigged"
	old.rig.cab = false
	old.rig.line_end = 1
	old.rig.car = [-432.5,0,4.1]
	old.rig.foot = [-433.2,0,3.1]
	load_shift(old)
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
	game.free()
	if not failed:
		print("CHECKS PASSED — version-one active rigging, payable bridge ticket, existing custody and later lead")
	quit(int(failed))
