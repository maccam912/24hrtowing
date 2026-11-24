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
	check(rig.fuel == game.ShopAccount.CAN_FILL and game.account.fuel_due == game.ShopAccount.CAN_PRICE, "one can restarts a broke operator and records one charge")
	check(game.shift_seconds == clock_before+18*60 and game.job.number == ticket, "the service call leaves the tow in progress")
	resume_shift()
	check(game.job.number == ticket and game.account.fuel_due == game.ShopAccount.CAN_PRICE, "county fuel advance and active contract survive resume")
	game.free()
	if not failures:
		print("CHECKS PASSED — yard and Esker fuel sales, partial fills, location checks, roadside service and resume")
	quit(int(failures > 0))
