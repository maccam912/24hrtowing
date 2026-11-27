extends "res://tests/touch_controls_test.gd"

func run() -> void:
	root.add_child(screen)
	screen.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	desk = game.desk
	game.campaign.stage = game.Campaign.ORDER.find("commission")
	game.campaign.ordinary_since = game.Campaign.GAPS[game.campaign.stage]
	game._accept(game.campaign.ticket(1001))
	var ladder: Vector3 = game.county.story_point("tower_ladder")
	for resolution: Vector2i in [Vector2i(800,600),Vector2i(2400,1080)]:
		screen.size = resolution
		game.campaign.evidence.erase("car_ring")
		game.rig.in_cab = false
		game.rig.foot = Vector3(ladder.x+1.2,0,ladder.z)
		game.rig.camera_yaw = PI*.5
		game.rig.camera_pitch = 0.0
		game.rig.update_eyes()
		game._refresh()
		var center := Vector2(screen.size)*.5
		touch(0,center,true)
		touch(0,center,false)
		await process_frame
		await process_frame
		await tap_key("interact")
		var controls := check_layout(["stick","interact"])
		var stick: Vector2 = controls.stick
		var up: Vector2 = stick+Vector2.UP*game.desk.surface.unit*77
		touch(1,stick,true)
		drag(1,stick,up)
		ticks(120)
		touch(2,center,true)
		drag(2,center,center+Vector2(80,-27))
		ticks(1)
		touch(2,center+Vector2(80,-27),false)
		touch(1,up,false)
		var rung: float = game.casework.tower_height
		check(rung > 0 and rung < 12 and not is_equal_approx(game.rig.camera_yaw,PI*.5),"thumb climbs while the other hand turns the view")
		ticks(55)
		check(is_equal_approx(rung,game.rig.foot.y),"taking both fingers off holds the rung")
		touch(1,up,true)
		ticks(550)
		touch(1,up,false)
		game._refresh()
		await process_frame
		check(game.state.tower_action == "tower_glass" and not game.campaign.evidence.has("car_ring"),"touch climb reaches the tank without making an observation")
		# Pan across the section using successive swipes that fit on either phone.
		var sight: Vector3 = game.rig.eyes.global_position.direction_to(game.county.story_point("car_ring"))
		var delta := Vector2(angle_difference(atan2(-sight.x,-sight.z),game.rig.camera_yaw),game.rig.camera_pitch-asin(sight.y)) / .0039
		while delta.length() > .05:
			var swipe := delta.limit_length(140)
			touch(2,center,true)
			drag(2,center,center+swipe)
			touch(2,center+swipe,false)
			ticks(1)
			delta -= swipe
		await tap_key("interact")
		check(game.casework.glasses and game._site_action()=="tower_note","field glasses can be aimed over the rig's ordinary touch look")
		await tap_key("interact")
		check(game.campaign.evidence.has("car_ring"),"the second tap records the visible formation")
		var down: Vector2 = stick+Vector2.DOWN*game.desk.surface.unit*77
		touch(1,down,true)
		ticks(530)
		touch(1,down,false)
		check(game.casework.tower_height < 0 and not game.casework.glasses,"thumb-down brings the operator back to the co-op")
	if not failed:
		print("CHECKS PASSED — two-handed tank ladder, field glasses and deliberate notebook entry on touch")
	quit(int(failed))
