extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game.desk.show_document("options",game.state)
	await tap_control("settings_anchors")
	check(not game.rig.assist,"title options change rigging assistance before the shift starts")
	await tap_control("close")
	game._action("play")
	game._take_rotation()
	rig = game.rig
	rig.in_cab = false
	rig.phase = "cable"
	var eye: Vector3 = rig._eyelet(-1)
	stand(eye+Vector3.FORWARD,eye)
	rig._update_highlight()
	check(not rig.highlight.visible and rig.action_id()=="attach","the real tow eye remains usable when suggestions are off")
	game.desk.toggle_pause()
	await tap_control("options")
	await tap_control("settings_anchors")
	check(rig.assist and rig.highlight.visible,"changing the toggle at the roadside immediately shows the eye")
	await tap_control("close")
	await tap_control("close")
	game._action("interact")
	check(rig.phase == "rigged","the suggested fitting still takes the shackle")
	game.free()
	if not failures:
		print("CHECKS PASSED — suggested tow eyes are optional at the title and at the worksite")
	quit(int(failures > 0))
