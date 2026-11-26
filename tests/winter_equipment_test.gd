extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	var truck = rig.body
	check(not truck.lamp_kit and not truck.heated_mirrors,"a new truck has stock halogens and plain glass")
	truck.weather_mirrors(180,0,12,true)
	check(truck.mirror_ice[0] > .4 and truck.mirror_ice[1] > .4,"road spray and snow collect on both unheated mirrors")
	game._action("interact")
	var glass: Vector3 = truck.mirror_centers[0].global_position
	var pos: Vector3 = glass-truck.global_basis.x*1.45
	stand(pos,glass)
	rig.eyes.look_at(glass,Vector3.UP)
	game._refresh()
	check(game._site_action() == "wipe_mirror","look up at the driver's mirror with a gloved hand")
	game._action("interact")
	check(truck.mirror_ice[0] == 0 and truck.mirror_ice[1] > .4,"one wipe clears just the glass within reach")
	game.account.cash = 200
	await tap_control("pause")
	game.desk.dismiss()
	game._action("buy_mirrors")
	check(game.account.cash == 200,"the catalog cannot fit heaters in the field")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._refresh()
	await tap_control("interact")
	await tap_control("parts_leaf")
	await tap_control("buy_mirrors")
	await tap_control("buy_lamps")
	check(game.account.cash == 30 and truck.heated_mirrors and truck.lamp_kit.visible,"the yard fits both winter parts at the quoted prices")
	var iced: float = truck.mirror_ice[1]
	truck.weather_mirrors(1,0,12,true)
	check(truck.mirror_ice[1] < iced and truck.mirror_glass[1].get_shader_parameter("frost") == truck.mirror_ice[1],"energized heating elements melt the visible frost")
	check(truck.headlamps[0].spot_range == 76 and truck.headlamps[1].spot_angle == 30,"the driving bar extends both beams")
	game.desk.dismiss()
	stand_at_cab_door(-1)
	game._action("interact")
	await tap_control("spot")
	rig.set_controls(Vector2.ZERO,Vector2(.42,0),false,false,DT)
	check(truck.search_beam.is_visible_in_tree() and absf(truck.search_head.rotation.y) > .2,"the fitted spot follows the driver's look in chase view")
	rig.toggle_driving_view()
	rig.set_controls(Vector2.ZERO,Vector2(-.7,.05),false,false,DT)
	check(is_equal_approx(truck.search_head.rotation.y,rig.camera_yaw),"the cab spot follows the driver's glance")
	rig.set_sighting(1,Vector3.INF,1)
	check(truck.search_beam.light_energy == 0 and truck.headlamps[0].light_energy == 0,"the fitted lamps follow the county electrical fade")
	rig.set_sighting(0,Vector3.INF,0)
	resume_shift()
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.body.heated_mirrors and rig.body.search_beam.is_visible_in_tree() and rig.body.mirror_ice[1] > 0 and game.account.cash == 30,"owned gear, switch position, glass and the paid balance survive a cold restart")
	press_key(KEY_L)
	check(not rig.spot_on,"the keyboard operates the same switch as the touch control")
	game.free()
	if not failures:
		print("CHECKS PASSED — stock glass, hand wipe, heated mirrors, wider beams and aimable spot in both views")
	quit(int(failures > 0))
