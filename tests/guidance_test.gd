extends SceneTree

const Game := preload("res://scripts/game.gd")

# Record the actual text submitted by the HUD and menus, including fitted labels.
class Transcript extends "res://scripts/desk_surface.gd":
	var words := PackedStringArray()

	func text(_at: Vector2, value: String, _font: Font, _px: int, _colour: Color, _width := -1.0, _align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		words.append(value)

	func multiline(_at: Vector2, value: String, _font: Font, _px: int, _colour: Color, _width: float, _lines := -1, _align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		words.append(value)

var game := Game.new()
var surface := Transcript.new()
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("Guidance on '", game.desk.page, "': ", message)

func check_text(words: String, visible: bool) -> void:
	check(not words.is_empty() and ("\n".join(surface.words).contains(words) == visible),
		("Missing text: " if visible else "Unexpected text: ") + words)

func redraw() -> void:
	surface.words.clear()
	surface.queue_redraw()
	await process_frame
	await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	for pressed in [true, false]:
		event.pressed = pressed
		root.push_input(event, true)

func tap(id: String) -> void:
	for box in surface.hit_boxes:
		if box.id == id:
			var event := InputEventScreenTouch.new()
			event.position = box.rect.get_center() * surface.unit
			for pressed in [true, false]:
				event.pressed = pressed
				root.push_input(event, true)
			await redraw()
			return
	check(false, "Missing touch control " + id)

func run() -> void:
	root.add_child(game)
	game.set_physics_process(false)
	game.desk.surface.free()
	game.desk.surface = surface
	surface.desk = game.desk
	game.desk.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await redraw()
	key(KEY_ENTER)
	await redraw()
	var first_step: String = game.state.hint_action
	check_text(first_step, false)
	check_text(game.subtitle, true)
	key(KEY_ESCAPE)
	await redraw()
	for i in surface.key_choices().size():
		key(KEY_TAB)
		if surface.hover == "guidance":
			break
	key(KEY_ENTER)
	await redraw()
	check(game.desk.page == "guidance", "The pause menu should open job guidance by keyboard")
	check_text(first_step, true)
	var before: float = game.shift_seconds
	game._physics_process(1.0)
	check(game.shift_seconds == before, "The shift clock should stop while reading")
	key(KEY_ESCAPE)
	check(game.desk.page == "pause", "Back should return to the pause menu")
	key(KEY_ESCAPE)

	key(KEY_R)
	await redraw()
	check(game.desk.page == "radio" and game.job.is_empty(), "R opens the transceiver without taking a contract")
	check_text("Report a sighting", true)
	key(KEY_ENTER)
	await redraw()
	for i in ceili(game.sub_time):
		if "red triangle" in "\n".join(surface.words): break
		game.sub_time -= 1.
		game._refresh()
		await redraw()
	check_text("red triangle", true)
	var route := str(game._road_note().get("instruction", ""))
	var procedure := str(game.state.progress)
	check(game.job.plate in route and game.job.vehicle in route, "The talk-in should name the car on the current slip")
	check_text(route, false)
	check_text(procedure, false)
	# First contact enables the touch HUD on a desktop or headless runner.
	var contact := InputEventScreenTouch.new()
	contact.position = root.get_visible_rect().get_center()
	for pressed in [true, false]:
		contact.pressed = pressed
		root.push_input(contact, true)
	await redraw()
	await tap("pause")
	await tap("guidance")
	check_text(route, true)
	check_text(procedure, true)
	await tap("close")
	await tap("close")
	check_text(route, false)

	game.rig.in_cab = false
	game.rig.foot = game.FAX + Vector3.BACK
	game.rig.update_eyes()
	game.rig.show_note("Cable slipped", 2.0)
	game._refresh()
	await redraw()
	var nearby := str(game.state.prompt)
	check_text(nearby, false)
	check_text(game.rig.info, true)
	await tap("pause")
	await tap("guidance")
	check_text(nearby, true)
	check_text(route, false)
	check_text(game.job.plate, true)
	await tap("close")
	await tap("close")

	game.rig.in_cab = true
	game.rig.set_spawn(game.rig.job_site + Vector3.BACK * 12.0)
	key(KEY_T)
	check(game.job.plate in game.subtitle and "red triangle" in game.subtitle,
		"Asking again at the shoulder should identify the pickup")
	game.accept(game.campaign.ticket(1002,"mail"))
	key(KEY_T)
	check(game.job.plate in game.subtitle and game.job.vehicle in game.subtitle and "triangle" not in game.subtitle,
		"The talk-in should identify the carrier's wagon from its own slip")
	game.rig.phase = "loaded"
	game.mode = "haul"
	key(KEY_T)
	check(game.rig.dropoff.sign in game.subtitle and game.job.plate not in game.subtitle,
		"A loaded truck should get delivery directions")
	game.free()
	await process_frame
	if not failed:
		print("CHECKS PASSED — keyboard and touch pause guidance, route, recovery steps and nearby actions")
	quit(int(failed))
