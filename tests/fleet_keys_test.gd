extends "res://tests/shift_test.gd"

func at_parked_door() -> void:
	var knob: Vector3 = game.fleet.door()
	stand(knob-game.fleet.model.global_basis.x*.9,knob)
	game._refresh()
	check(game._site_action()=="fleet_door","the parked driver door has the other set of keys")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	game.account.cash = 700
	game._action("interact")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("buy_rollback")
	check(not game.account.owns("rollback"),"a new operator cannot buy the carrier before twelve filed slips")
	game.completed = 12
	game.account.equipment.aux_tank = true
	game.fit_equipment()
	game._refresh()
	await tap_control("interact")
	await tap_control("parts_prev")
	await tap_control("buy_rollback")
	check(game.account.cash == 60 and game.account.owns("rollback"),"touch catalog buys the truck and charges the till once")
	game._action("buy_rollback")
	check(game.account.cash == 60 and is_instance_valid(game.fleet.model),"a second press leaves one purchased carrier")
	game.desk.dismiss()
	var home: Vector3 = rig.get_truck_position()
	var base_miles: float = rig.odo
	rig.fuel = .67
	rig.reserve_fuel = .31
	rig.climate.blower = 0
	rig.climate.cracked = true
	rig.wear = .42
	var heavy: Dictionary = game.Dispatch.impossible(12,"roof_car",Vector3(37,4.75,-13.6),"coop","Main Street","feed co-op","Take Main.")
	game.rotation_offer = heavy.duplicate(true)
	at_parked_door()
	await tap_control("interact")
	check(rig.rollback_active and rig.in_cab and is_equal_approx(rig.odo,game.fleet.SALE_MILES),"climb into the delivered rollback at its own odometer")
	check(rig.reserve_fuel==0 and is_equal_approx(rig.fuel,.5) and rig.wear==0 and not rig.climate.cracked,"each truck has its own tanks, cable and cab")
	check(game.fleet.model.position.is_equal_approx(home) and not game.fleet.parked.rollback,"the original wrecker remains where it was left")
	var light: Dictionary = game._offered_rotation()
	check(game.RollbackDeck.supports(light) and game.rotation_offer.vin==heavy.vin and game.state.wrecker_waiting,"Arlene holds the heavy order and supplies a light ticket")
	game.accept(heavy)
	check(game.mode=="available" and game.job.is_empty(),"the carrier can leave a boom job on file")
	game._action("rotation")
	check(game.job.vin==light.vin and game.rotation_offer.vin==heavy.vin,"accepting the carrier's light ticket preserves the waiting heavy call")
	game._action("interact")
	at_parked_door()
	game._interact()
	check(rig.rollback_active and not rig.in_cab,"keys stay with the carrier while its ticket is open")
	game._clear_field_job()
	rig.fuel = .28
	rig.odo += 3.1
	rig.climate.blower = 2
	game.save()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	game._restore(saved)
	check(rig.rollback_active and game.fleet.model.position.is_equal_approx(home) and not game.fleet.parked.rollback,"a restart restores both distinct vehicles")
	at_parked_door()
	await tap_control("interact")
	check(not rig.rollback_active and is_equal_approx(rig.odo,base_miles) and is_equal_approx(rig.fuel,.67) and is_equal_approx(rig.reserve_fuel,.31),"wrecker keys restore original miles and both fuel tanks")
	check(is_equal_approx(rig.wear,.42) and rig.climate.cracked and rig.climate.blower==0 and game._offered_rotation().vin==heavy.vin,"wrecker wear, window and waiting dispatch order survive the exchange")
	game._action("interact")
	at_parked_door()
	await tap_control("interact")
	check(rig.rollback_active and is_equal_approx(rig.fuel,.28) and is_equal_approx(rig.odo,game.fleet.SALE_MILES+3.1),"switching again preserves the carrier's own last reading")
	game.free()
	if not failures: print("CHECKS PASSED — office purchase, physical key exchange, dispatch and two saved trucks")
	quit(int(failures>0))
