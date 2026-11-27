extends SceneTree

const STEP := 1.0 / 30.0
const GameScene := preload("res://game.tscn")

var game
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("Finale credits: ", message)

func start_shift(snapshot := {}) -> void:
	if game:
		game.free()
	game = GameScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.saved_data = snapshot.duplicate(true)
	game.dispatch_seed = 22
	game.desk._activate("play")

func snapshot() -> Dictionary:
	game.save()
	return JSON.parse_string(JSON.stringify(game.saved_data))

func key_press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func tap(button: Button) -> void:
	var event := InputEventScreenTouch.new()
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func driving_camera() -> bool:
	return game.world_view.get_camera_3d() == game.rig.get_camera()

func entered_film() -> bool:
	for frame in 450:
		game._physics_process(STEP)
		if game.finale.active:
			return true
	return false

func run() -> void:
	start_shift()
	game.completed = 56
	game._take_rotation()
	game._action("camera")
	var view: String = game.rig.driving_view
	var ticket: String = game.job.vin
	game.rig.set_spawn(Vector3(0,0,430), PI)
	game.rig.speed = 12.0
	game.job.point = Vector3(8.4,0,750)
	game.campaign.stage = game.Campaign.ORDER.size() - 1
	game._physics_process(STEP)
	check(game.sightings.active.is_empty() and driving_camera(), "an ordinary drive before Angie has no finale")

	game.campaign.stage = game.Campaign.ORDER.size()
	game._physics_process(STEP)
	check(game.sightings.active == "set_down" and driving_camera(), "a completed case starts the descent in the selected driving view")
	if game.sightings.active != "set_down":
		finish()
		return
	var car_vin: String = game.sightings.scene.actor.get_meta("vin")
	var airborne := snapshot()
	game._recover_to_yard()
	game._physics_process(STEP)
	check(not game.finale.active and not game.sightings.aftermath.has("shoulder_car"), "rescuing the truck mid-descent leaves the finale for a later drive")
	game.rig.set_spawn(Vector3(0,0,430), PI)
	game.rig.speed = 12.0
	for frame in 20:
		game._physics_process(STEP)
		if game.sightings.active == "set_down":
			break
	check(game.sightings.active == "set_down", "the interrupted sighting can start again when the driver reaches the road")

	airborne.sightings.erase("credits_due") # Existing saves from before credits shipped.
	start_shift(airborne)
	game.rig.speed = 12.0
	check(not game.sightings.heard and not game.finale.active, "Continue preserves the unfinished descent")
	var touched := false
	var radio := false
	for frame in 450:
		game._physics_process(STEP)
		if game.sightings.active == "set_down":
			touched = touched or game.sightings.scene.actor.position.y <= game.sightings.shoulder.y + .02
			radio = radio or (game.sightings.heard and game.subtitle.contains("one on the shoulder"))
		if game.finale.active:
			break
	check(touched and radio, "the car touches down and Arlene calls before the film")
	check(game.finale.active and not driving_camera(), "the finale takes the camera after dispatch")
	if not game.finale.active:
		finish()
		return
	var shoulder: Vector3 = game.sightings.shoulder
	var sedan: Node3D = game.sightings.scene.remnants.shoulder_car.get_node("RoadCar")
	check(sedan.global_position.is_equal_approx(shoulder), "the parked sedan stays at its touchdown height")
	var position: Vector3 = game.rig.truck.position
	key_press(KEY_C)
	key_press(KEY_M)
	for frame in 200:
		game._physics_process(STEP)
	var credits: Array[String] = []
	for label: Label in game.finale.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.modulate.a > .9:
			credits.append(label.text)
	check("A game by maccam912" in credits and "With help from Astra 6.2" in credits, "both credits appear in the shot")
	var camera: Camera3D = game.world_view.get_camera_3d()
	check(camera.is_position_in_frustum(shoulder + Vector3.UP), "the shot frames the actual car")
	check(game.rig.truck.position.is_equal_approx(position) and game.job.vin == ticket, "the truck and current order stay put during credits")
	check(game.rig.driving_view == view and game.desk.page.is_empty(), "ordinary keys do not change view or open the atlas during credits")

	var in_film := snapshot()
	key_press(KEY_ESCAPE)
	check(not game.finale.active and driving_camera() and game.desk.page.is_empty(), "Escape skips directly back to the cab")
	check(game.rig.driving_view == view and game.job.vin == ticket and game.rig.is_stopped(), "skipping restores the selected driving view and leaves the active tow safely stopped")
	var after_skip: Dictionary = game.saved_data.duplicate(true)

	start_shift(in_film)
	check(entered_film(), "Continue during the film presents the credits again")
	await process_frame
	if game.finale.active:
		check(game.finale.skip_button.is_visible_in_tree(), "the film offers a touch skip")
		tap(game.finale.skip_button)
		check(not game.finale.active and driving_camera() and not game.desk.is_blocking(), "tapping Skip returns to driving")

	start_shift(in_film)
	check(entered_film(), "the saved film can finish unattended")
	for frame in 480:
		game._physics_process(STEP)
	check(not game.finale.active and driving_camera() and game.rig.driving_view == view, "the film returns to the chosen view automatically")

	check(not bool(game.saved_data.sightings.get("credits_due", true)), "automatic completion saves the finished credits")
	check(not bool(after_skip.sightings.get("credits_due", true)), "skipping writes a completed credits checkpoint")
	after_skip.sightings.erase("credits_due")
	start_shift(after_skip)
	game._physics_process(STEP)
	check(not game.finale.active and driving_camera() and game.job.vin == ticket, "the completed credits stay closed across Continue")
	key_press(KEY_C)
	check(game.rig.driving_view != view, "the camera switch works again after credits")
	game._recovered(game.job.kind)
	if game.mode == "haul":
		game._dropped()
	game._take_rotation()
	check(game.job.get("aftermath_key") == "shoulder_car" and game.job.vin == car_vin, "the next accepted order is the sedan from the film")
	check(game.rig.car.global_position.is_equal_approx(shoulder), "the recovery starts where all four wheels landed")
	check(not game.sightings.aftermath.has("shoulder_car"), "accepting the order claims the one saved sedan")
	finish()

func finish() -> void:
	game.free()
	if failures == 0:
		print("CHECKS PASSED — finale touchdown, credits, controls, skips, resume and continued dispatch")
	quit(int(failures > 0))
