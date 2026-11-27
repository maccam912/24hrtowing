extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	game.account.cash = 210.00
	var room = game.ambience
	check(not room.brewer_fitted and room.activity.brewer < 0., "the empty shelf has no brewing cycle")
	game._action("buy_yard_pump")
	check(not game.county.yard_dispenser,"an off-site order cannot build the bulk pump")
	game._action("interact")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._refresh()
	await tap_control("interact")
	await tap_control("parts_prev")
	await tap_control("buy_yard_pump")
	await tap_control("buy_coffee_maker")
	check(game.county.yard_dispenser and game.county.yard_brewer and game.account.cash == 26.0,"the yard catalog sells each physical fixture")
	check(room.brewer_fitted and room.activity.brewer >= 0., "the first installed pot begins dripping")
	game.desk.dismiss()
	var hose: Vector3 = game.county.Fittings.NOZZLE
	stand(hose+Vector3.BACK*1.7,hose)
	rig.fuel = .25
	game._action("interact")
	check(game.desk.page == "bulk_pump" and not game.state.nozzle_ready,"the bulk hose cannot reach a wrecker clear across the yard")
	game.desk.dismiss()
	rig.set_spawn(hose+Vector3(4,0,5))
	stand(hose+Vector3.BACK*1.7,hose)
	game._refresh()
	await tap_control("interact")
	await process_frame
	await process_frame
	var box := Rect2()
	for hit in game.desk.surface.hit_boxes:
		if hit.id == "nozzle":
			box = hit.rect
	check(box.has_area(),"the handle becomes available at the truck")
	var event := InputEventScreenTouch.new()
	event.position = box.get_center()*game.desk.surface.unit
	event.pressed = true
	root.push_input(event,true)
	for tick in 60:
		game._physics_process(DT)
	event.pressed = false
	root.push_input(event,true)
	var level: float = rig.fuel
	check(is_equal_approx(game.nozzle_sale,3.60) and is_equal_approx(game.account.cash,22.4) and is_equal_approx(level,.325),"a one-second squeeze meters the same diesel and cash shown on the pump")
	game._physics_process(DT)
	check(rig.fuel == level,"letting go stops the sale immediately")
	resume_shift()
	room = game.ambience
	check(game.county.yard_dispenser and game.county.yard_brewer and is_equal_approx(rig.fuel,level) and is_equal_approx(game.account.cash,22.4),"partial fill, debit and fittings survive restarting")
	var bench: Vector3 = game.county.Fittings.COFFEE
	stand(bench+Vector3.FORWARD*1.25,bench)
	for i in 660: room.mix(bench,false,false,0.,true,DT)
	check(room.activity.brewer < 0. and room.sources.brewer.volume_db < -65., "the thermostat cuts out and the pot falls quiet")
	game.fit_equipment()
	check(room.activity.brewer < 0., "re-fitting other equipment leaves the full pot quiet")
	rig.warmth = .1
	check(game._site_action() == "yard_coffee","the bench can be reached at "+str(rig.foot)+" (site "+game._site_action()+")")
	game._action("interact")
	check(rig.warmth == 1.0 and rig.coffee_left == rig.HOT_COFFEE_SECONDS and is_equal_approx(game.account.cash,22.4),"shop coffee can warm an operator without a trip to Esker")
	check(room.activity.pour == 0., "a successful cup sounds at the pot")
	for i in 15: room.mix(bench,false,false,0.,true,DT)
	var first_pour: float = room.activity.pour
	game._action("interact")
	check(room.activity.pour == first_pour and room.sources.pour.volume_db > -12., "the full cup cannot repeat the pour")
	for i in 135: room.mix(bench,false,false,0.,true,DT)
	check(room.activity.brewer > 0. and room.activity.pour < 0., "the pot starts a top-up after the carafe is set down")
	game.county._build()
	check(game.county.fittings_model.is_inside_tree(),"a county rebuild keeps the installed equipment")
	game.free()
	if not failures:
		print("CHECKS PASSED — yard installations, reach, nozzle hold/release, partial-fill balance and coffee")
	quit(int(failures > 0))
