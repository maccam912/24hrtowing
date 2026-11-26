extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game._action("rotation")
	rig = game.rig
	var ticket: int = game.job.number
	game.desk._touch_mode = true
	rig.set_spawn(game.PUMP+Vector3(0,0,-8))
	game._action("interact")
	var counter: Vector3 = game.county.coffee_counter_point()
	stand(counter+Vector3(0,0,-1.4), counter)
	rig.warmth = .25
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.warmth > .25,"the store warms an operator who only stops to talk")
	game._refresh()
	await tap_control("interact")
	check(game.desk.page == "coffee","the on-foot till opens Mai’s counter check")
	var cash: float = game.account.cash
	await tap_control("buy_coffee")
	check(game.account.cash == cash-.75 and rig.warmth == 1 and rig.coffee_left == rig.HOT_COFFEE_SECONDS and game.desk.page == "","buying the quoted coffee warms the operator and debits the till")
	game._action("buy_coffee")
	check(game.account.cash == cash-.75,"a repeated order cannot charge the same cup twice")
	resume_shift()
	check(rig.coffee_left == rig.HOT_COFFEE_SECONDS and game.job.number == ticket and game.account.cash == cash-.75,"the coffee and the matching debit survive a cold start during a tow")
	stand(game.PUMP,game.PUMP+Vector3.FORWARD)
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.coffee_left < rig.HOT_COFFEE_SECONDS and rig.warmth == 1,"coffee keeps hands warm outside")
	rig.coffee_left = 0
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.warmth < 1,"ordinary outdoor cooling resumes")
	game.sightings.seen["streetlights_out"] = true
	stand(counter+Vector3(0,0,-1.4),counter)
	game._refresh()
	await tap_control("interact")
	await tap_control("talk_mai")
	check(game.mai_lot_heard and game.speaker == "MAI" and game.subtitle == game.audio.lines.mai_lot[1],"Mai remembers the lot blackout when asked about it")
	game.account.cash = .50
	game._action("interact")
	game._action("buy_coffee")
	check(game.account.cash == .50 and rig.coffee_left == 0,"the shop leaves an unaffordable cup on the counter")
	game.free()
	if not failures:
		print("CHECKS PASSED — walk-in coffee sale, warmth, conversation and active-slip resume")
	quit(int(failures > 0))
