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
	await tap_control("map")
	await tap_control("plat_pencil")
	await tap_control("pencil_lights")
	var mark := Vector2(430,-140)
	await touch_sheet(mark)
	check(game.plat_pencil.marks == [[430,-140,"lights"]],"tapping a field pencils the chosen symbol at that field")
	await tap_control("pencil_vehicle")
	await touch_sheet(Vector2(128,612))
	await tap_control("plat_pencil")
	check(not game.desk.pencil_open and game.plat_pencil.marks.size() == 2,"putting the pencil away keeps both observations")
	game.desk.dismiss()
	resume_shift()
	check(game.state.plat_marks == [[430,-140,"lights"],[128,612,"vehicle"]] and game.job.number == ticket,"a penciled field and vehicle survive loading an open tow")
	game.rig.speed = 2.0
	game._refresh()
	press_key(KEY_M)
	check(game.desk.glance,"a moving driver can only glance at the marked sheet")
	game._action("pencil_mark")
	check(game.plat_pencil.marks.size() == 2,"lap view cannot make a pencil mark")
	game.desk.dismiss()
	game.rig.speed = 0
	game._refresh()
	press_key(KEY_M)
	await tap_control("plat_pencil")
	await tap_control("pencil_erase")
	await touch_sheet(mark+Vector2(9,-12))
	check(game.plat_pencil.marks == [[128,612,"vehicle"]],"the rubber erases just the closest pencil mark")
	await tap_control("pencil_return")
	game.desk.pencil_point = Vector2(200,200)
	press_key(KEY_RIGHT)
	press_key(KEY_ENTER)
	check(game.plat_pencil.marks.back() == [222,200,"return"],"a keyboard operator can place a mark with arrows and Enter")
	check(game.survey.notes.is_empty() and game.sightings.report_options().is_empty(),"personal marks do not count as county evidence")
	game.free()
	if not failures:
		print("CHECKS PASSED — personal plat marks by touch and keyboard, erasing, lap view and save continuity")
	quit(int(failures > 0))

func touch_sheet(world: Vector2) -> void:
	await process_frame
	await process_frame
	var surface: Control = game.desk.surface
	var event := InputEventScreenTouch.new()
	event.position = (surface.docs.pencil_projection*world)*surface.unit
	for pressed: bool in [true,false]:
		event.pressed = pressed
		root.push_input(event,true)
