extends SceneTree

const ShiftClock := preload("res://scripts/shift_clock.gd")
const Tape := preload("res://scripts/sheriff_tape.gd")
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("CHECK FAILED: " + message)
		failed = true

func at(minutes: float) -> String:
	return ShiftClock.label(minutes * 60.0)

func run() -> void:
	# The opening night runs from 03:14 to dawn, then each night is 17:00 to 07:00.
	check(at(0) == "03:14" and at(45) == "03:59" and at(225) == "06:59", "the opening night counts real minutes from 03:14")
	check(at(226) == "17:00" and at(226 + 419) == "23:59" and at(226 + 420) == "00:00", "dawn gives way to that evening's dusk")
	check(at(226 + 839) == "06:59" and at(226 + 840) == "17:00", "every later night ends at dawn too")
	var last := -INF
	var backward := false
	var daylight := 0
	for minute in range(0, 4 * 1440, 7):
		var wall := ShiftClock.wall_seconds(minute * 60.0)
		backward = backward or wall < last
		last = wall
		var hour := int(at(minute).left(2))
		if hour >= 7 and hour < 17:
			daylight += 1
	check(not backward, "the clock never runs backward")
	check(daylight == 0, "no slip, card or scanner entry is stamped in daylight")

	# Tape dates follow the same clock across midnight and between nights.
	check(Tape.write("County K",0,0,true).date == "01/14", "the opening night is January 14")
	check(Tape.write("County K",0,(226 + 419) * 60.0,true).date == "01/14", "the evening after the opening night is still January 14")
	check(Tape.write("County K",0,(226 + 420) * 60.0,true).date == "01/15", "midnight turns the tape date")
	check(Tape.write("Swamp Rd",0,-6 * 3600.0).date == "01/13", "a check before the shift keeps the previous night's date")

	# A shift in progress reads the night clock on every form.
	var game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game.shift_seconds = 225 * 60.0
	check(game.clock() == "06:59", "the dash clock reads the last minute before dawn")
	game.shift_seconds += 40 * 60.0
	game._refresh()
	check(game.clock() == "17:39" and game.state.night_time == "17:39", "missing time past dawn lands in the evening")
	game.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("CHECKS PASSED — the shift clock stays in the dark hours")
	quit(0)
