extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	rig.speed = 3.
	game._action("cab_heat")
	check(game.desk.page.is_empty(),"stopped-cab panel stays stowed while moving")
	rig.speed = 0.
	game._refresh()
	game.desk.toggle_pause()
	await tap_control("cab_heat")
	check(game.desk.page == "cab_heat","a stopped operator can reach the heater from the truck log")
	await tap_control("blower_off")
	await tap_control("window_latch")
	var pose: Vector3 = rig.truck.position
	for i in 60:
		game._physics_process(DT)
	check(rig.climate.air < 1. and rig.truck.position.distance_to(pose) < .02 and rig.body.side_glass.position.y < -.19,"the blower and crank keep working while the operator sits at the controls")
	await tap_control("close")
	rig.climate.advance(rig,180.)
	rig.body.move_driver_window(rig.climate.cracked,1.)
	check(rig.climate.air < .01 and rig.warmth < .01 and rig.body.side_glass.position.y < -.19,"an open, unheated cab cools down and the driver’s glass lowers")
	resume_shift()
	check(rig.climate.blower == rig.climate.OFF and rig.climate.cracked and rig.climate.air < .01 and rig.body.side_glass.position.y < -.19,"the fan, cab air and physical window survive a cold launch")
	press_key(KEY_V)
	await tap_control("window_latch")
	await tap_control("blower_high")
	await tap_control("close")
	for i in 60:
		rig.climate.advance(rig,1.0)
	rig.body.move_driver_window(rig.climate.cracked,1.)
	check(rig.climate.air > .99 and rig.warmth > .9 and is_zero_approx(rig.body.side_glass.position.y),"the high blower warms the cab, operator and windshield")
	rig.fuel = 0.
	rig.climate.advance(rig,120.)
	check(rig.climate.air < .8,"the engine cannot supply heat after it runs dry")
	rig.in_cab = false
	rig.warmth = .05
	game._physics_process(DT)
	check(game.picture.material.get_shader_parameter("operator_frost") > .9,"cold hands bring frost to the edges of the outdoor view")
	rig.warmth = 1.
	game._physics_process(DT)
	check(is_zero_approx(game.picture.material.get_shader_parameter("operator_frost")),"warming up completely restores the outdoor view")
	game.free()
	if not failures:
		print("CHECKS PASSED — blower and window, cab air, outdoor frost, heat loss and saved controls")
	quit(int(failures > 0))
