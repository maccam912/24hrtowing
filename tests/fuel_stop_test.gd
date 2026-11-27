extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game.desk._touch_mode = true
	rig = game.rig
	rig.fuel = 0.5
	game._action("interact")
	stand(game.FAX + Vector3.FORWARD,game.FAX)
	game._refresh()
	await tap_control("interact")
	check(game.desk.page == "parts" and game.state.can_refuel, "office opens the shop with the truck in its starting space")
	var opening: float = game.account.cash
	await tap_control("buy_fuel")
	check(rig.fuel == 1.0 and is_equal_approx(game.account.cash, opening-24.0), "buy diesel at the office with the displayed price")
	game._action("buy_fuel")
	check(is_equal_approx(game.account.cash, opening-24.0) and game.state.earned == 0, "a full tank cannot be charged again")
	game.desk.dismiss()

	rig.fuel = .5
	var island: Vector3 = game.PUMP_ISLANDS[0]
	stand(island+Vector3.FORWARD*1.8,island)
	game._refresh()
	await tap_control("interact")
	check(game.desk.page == "parts" and game.state.at_pump and not game.state.can_refuel, "a walk to Esker cannot remotely fuel the truck in the yard")
	game._action("buy_fuel")
	check(rig.fuel == .5, "fuel purchase rechecks the truck location")
	game.desk.dismiss()
	rig.set_spawn(game.PUMP+Vector3(0,0,-8))
	island = game.PUMP_ISLANDS[1]
	stand(island+Vector3.FORWARD*1.8,island)
	game._refresh()
	await tap_control("interact")
	var quote: Dictionary = game.state.fuel_quote
	check(game.state.can_refuel and not game.state.can_order and quote.fuel_after < 1, "the second pump quotes an affordable partial fill")
	await tap_control("buy_fuel")
	check(game.account.cash == 0.0 and rig.fuel == quote.fuel_after, "Esker charges only for fuel supplied")
	game.desk.dismiss()
	resume_shift()
	check(game.account.cash == 0 and is_equal_approx(rig.fuel,quote.fuel_after), "a cold restart keeps purchased fuel and the matching debit")

	rig.in_cab = true
	game._action("rotation")
	var ticket: int = game.job.number
	rig.fuel = 0.0
	game._survey()
	game._refresh()
	check(rig.fuel == 0 and game.state.fuel_help, "empty tank offers roadside help")
	press_key(KEY_R)
	check(game.desk.page == "radio", "keyboard radio can request fuel during a job")
	var clock_before: float = game.shift_seconds
	await tap_control("roadside_fuel")
	game._action("roadside_fuel")
	check(game.state.fuel_eta == 18 and "18 min" in game.state.feedback and not game.state.fuel_help and rig.fuel == 0 and game.account.fuel_due == 0, "a single request shows an ETA before any fuel or charge")
	game._physics_process(.5)
	var approach_from: Vector3 = game.fuel_can.plow.position
	press_key(KEY_R)
	game._physics_process(4.5)
	check(game.desk.page == "radio" and game.state.fuel_eta == 13 and game.fuel_can.plow.position.distance_to(approach_from) > 1, "the plow approaches while the driver monitors the radio")
	game.desk.dismiss()
	game.desk.toggle_pause()
	game._physics_process(4.0)
	check(game.state.fuel_eta == 13 and rig.fuel == 0.0, "pause suspends the delivery")
	game.desk.dismiss()
	resume_shift()
	check(game.state.fuel_eta == 13 and rig.fuel == 0 and game.account.fuel_due == 0, "restarting mid-wait resumes the dispatch")
	press_key(KEY_R)
	game._physics_process(12.5)
	check(rig.fuel == 0 and game.fuel_can.wait_left == .5, "can still in transit until ETA")
	game._physics_process(.5)
	check(rig.fuel == game.ShopAccount.CAN_FILL and game.account.fuel_due == game.ShopAccount.CAN_PRICE and "$19.20 on the county IOU" in game.subtitle, "one delivered can restarts a broke operator and records one IOU")
	check(is_equal_approx(game.shift_seconds,clock_before+18*60) and game.job.number == ticket, "the service call leaves the tow in progress")
	resume_shift()
	check(game.job.number == ticket and game.account.fuel_due == game.ShopAccount.CAN_PRICE and game.state.fuel_eta == 0, "county fuel advance and active contract survive resume")
	game._action("roadside_fuel")
	check(game.fuel_can.wait_left == 0, "a delivered order cannot charge again")

	rig.fuel = 0.0
	game.account.cash = 35
	game.account.fuel_due = 0
	game.county.set_case_landmarks(["last_cap"])
	var dead_end := Vector3(game.county.CaseSites.ALDER_X,0,game.county.CaseSites.ALDER_END)
	rig.set_spawn(dead_end,PI*.5)
	rig.speed = .5
	game._action("roadside_fuel")
	check(game.fuel_can.wait_left == 0, "the moving wrecker must stop before calling for fuel")
	rig.speed = 0
	game._refresh()
	await tap_control("radio")
	await tap_control("roadside_fuel")
	check(game.account.cash == 35 and rig.fuel == 0, "cash is collected at the truck")
	press_key(KEY_R)
	game._physics_process(game.ShopAccount.CAN_ETA_MINUTES)
	check(is_equal_approx(game.account.cash,15.8) and game.account.fuel_due == 0 and rig.fuel == game.ShopAccount.CAN_FILL and "$19.20 paid" in game.subtitle, "drivers with money pay twice the pump price when the can arrives")
	var plow = game.fuel_can.plow
	check(plow.start.distance_to(plow.stop)>80 and plow.position.distance_to(dead_end)<15 and plow.position.distance_to(dead_end)>10, "the plow approaches the open Alder Cut dead end and stops clear of a sideways wrecker")
	await test_dry_rigging()
	game.free()
	if not failures:
		print("CHECKS PASSED — yard and Esker fuel sales, partial fills, location checks, roadside service and resume")
	quit(int(failures > 0))

func test_dry_rigging() -> void:
	game.desk.dismiss()
	# Stage the three jobs at their chocked cable step. The roll uses both slings.
	var truck_at := Vector3(0,0,160)
	game.account.equipment["snatch_block"] = true
	game.fit_equipment()
	for id: String in ["shoulder_car","roof_car","field_car"]:
		rig.set_spawn(truck_at)
		var site := truck_at + Vector3(-2,4.75 if id == "roof_car" else 0.0,14)
		game.accept(game.Dispatch.impossible(8,id,site,id,"County K","east shoulder","Follow County K."))
		rig.phase = "cable"
		rig.set_chocks()
		rig.fuel = 0.0
		rig.in_cab = false
		stand_at_cab_door(-1.0)
		game._refresh()
		check(game.state.can_enter_cab, "both lines and the boom leave the dry cab radio accessible: "+id)
		game._action("interact")
		check(rig.in_cab and rig.phase == "cable" and game.state.fuel_help, "radio works without stowing the cable: "+id)
		game._action("roadside_fuel")
		game._advance_shift_clock(game.ShopAccount.CAN_ETA_MINUTES)
		for frame in 10:
			rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,DT)
		check(rig.is_stopped() and rig.get_truck_position().distance_to(truck_at) < 0.1 and rig.phase == "cable", "refilled rig stays chocked: "+id)
		game._action("interact")
		stand_at_cab_door(1.0)
		game._action("interact")
		check(not rig.in_cab, "fuelled chocked rig still requires stowing before cab entry: "+id)
		if id != "shoulder_car":
			continue
		var eye: Vector3 = rig.eyelet_point(-1)
		stand(eye+Vector3.FORWARD*.75,eye)
		game._action("interact")
		check(rig.phase == "rigged","operator resumes with the delivered can and attaches the staged hook")
		var panel: Vector3 = rig.panel_point()
		stand(panel-rig.truck.global_basis.x,panel)
		rig.fuel = rig.WINCH_FUEL_PER_SECOND*.95
		for tick in 180:
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
		game._refresh()
		check(rig.fuel == 0.0 and rig.tension == 0.0 and not rig.working and not game.state.work_available and "cab" in game.state.hint_action, "empty PTO stops, releases tension and explains the radio")
		var line_length: float = rig.free_line
		var car_pose: Transform3D = rig.car.transform
		stand_at_cab_door(1.0)
		await tap_control("interact")
		await tap_control("radio")
		await tap_control("roadside_fuel")
		resume_shift()
		game._advance_shift_clock(game.ShopAccount.CAN_ETA_MINUTES)
		check(rig.in_cab and rig.phase == "rigged" and is_equal_approx(rig.free_line,line_length) and car_pose.is_equal_approx(rig.car.transform) and rig.fuel > 0, "delivery and restart preserve the attached cable and casualty")
		game._action("interact")
		stand(panel-rig.truck.global_basis.x,panel)
		for tick in 30:
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
		check(rig.working and rig.free_line < line_length and not rig.car.transform.is_equal_approx(car_pose), "the same pull can continue after a radio refill")
