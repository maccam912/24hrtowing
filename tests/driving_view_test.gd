extends SceneTree

const GameScene := preload("res://game.tscn")

var game
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("Driving view: ", message)

func check_view(expected: String) -> void:
	var camera: Camera3D = game.world_view.get_camera_3d()
	var rig = game.rig
	check(game.state.driving_view == expected, "HUD should show " + expected)
	if not rig.in_cab:
		check(camera.global_position.is_equal_approx(rig.foot + Vector3.UP * rig.WALK_EYES), "walking uses the operator's eye position")
	elif expected == "cab":
		check(camera.global_position.is_equal_approx(rig.body.to_global(rig.Truck.EYE)), "cab camera should be in the driver's seat")
	else:
		var position_in_truck: Vector3 = rig.truck.to_local(camera.global_position)
		check(position_in_truck.z > 4.0 and position_in_truck.y > 2.5, "chase camera should be behind and above the wrecker")
		check((-camera.global_basis.z).dot(-rig.truck.global_basis.z) > 0.5, "chase camera should face the road ahead")

func key_c() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.physical_keycode = KEY_C
	key.pressed = true
	root.push_input(key, true)
	key.pressed = false
	root.push_input(key, true)

func tap(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func start_shift(snapshot := {}) -> void:
	game = GameScene.instantiate()
	root.add_child(game)
	game.test_session = true
	await physics_frame
	game.set_physics_process(false)
	game.saved_data = snapshot
	game.desk._activate("play")

func run() -> void:
	await start_shift()
	check_view("chase")
	key_c()
	check_view("cab")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	check(snapshot.get("rig", {}).get("driving_view") == "cab", "switching view should save the preference immediately")
	if failed:
		quit(1)
		return

	# Exercise the same Continue path as a freshly launched process.
	game.free()
	await start_shift(snapshot)
	check_view("cab")
	game._action("interact")
	check(not game.rig.in_cab, "operator stepped out")
	key_c()
	check_view("cab")
	game._action("interact")
	check(game.rig.in_cab, "operator re-entered the driving seat")
	check_view("cab")

	# The first neutral touch enables the touch HUD in a desktop test viewport.
	tap(root.get_visible_rect().get_center())
	await process_frame
	await process_frame
	var surface: Control = game.desk.surface
	var camera_control := Rect2()
	for entry in surface.hit_boxes:
		if entry.id == "camera":
			camera_control = entry.rect
	check(camera_control.has_area(), "driving HUD has a directly tappable camera switch")
	if camera_control.has_area():
		tap(camera_control.get_center() * surface.unit)
		check_view("chase")
		game._action("interact")
		check(not game.rig.in_cab, "chase driver stepped out")
		check_view("chase")
		game._action("interact")
		check(game.rig.in_cab, "operator re-entered the chase view")
		check_view("chase")

	# Older routes have no driving view in the rig snapshot.
	key_c()
	snapshot.rig.erase("driving_view")
	game._restore(snapshot)
	game._refresh()
	check_view("chase")
	var rig = game.rig
	var start := Vector3(0, 0, 30)
	rig.set_spawn(start)
	rig.set_controls(Vector2.ZERO, Vector2(1.4, 0), false, false, 1.0 / 60.0)
	check(absf(rig.truck.to_local(rig.get_camera().global_position).x) > 4.0, "looking around should orbit the truck")
	for tick in 270:
		rig.set_controls(Vector2(0, -1), Vector2.ZERO, false, false, 1.0 / 60.0)
	check(rig.truck.position.distance_to(start) > 5.0, "truck should move during the chase test")
	check_view("chase")
	if not failed:
		print("CHECKS PASSED — driving camera poses, keyboard and touch switch, saved preference and legacy routes")
	quit(1 if failed else 0)
