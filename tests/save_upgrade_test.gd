extends SceneTree

const SaveUpgrade := preload("res://scripts/save_upgrade.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("CHECK FAILED: " + message)
		failed = true

func run() -> void:
	var game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game._action("rotation")
	game.save()
	var lines: Dictionary = game.audio.lines

	# A save written by this build passes through untouched, and the caller's copy is never edited.
	var current: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	var before := JSON.stringify(current)
	var upgraded := SaveUpgrade.before_restore(current,lines)
	check(JSON.stringify(upgraded) == before, "a current save is unchanged by the upgrade")
	check(JSON.stringify(current) == before, "the upgrade works on a copy")

	# An aftermath ticket from before the observation log gains its order key.
	var aftermath := current.duplicate(true)
	aftermath.ticket.aftermath_key = "roof_car"
	aftermath.ticket.erase("observation_key")
	var keyed := SaveUpgrade.before_restore(aftermath,lines)
	check(keyed.ticket.observation_key == "order/%d/roof_car" % int(aftermath.ticket.number), "an aftermath ticket names its order")
	check(not aftermath.ticket.has("observation_key"), "the original aftermath save is left alone")

	# A version 1 job kept only its call index; the upgrade writes the ticket it implied.
	var first := current.duplicate(true)
	first.version = 1
	first.mode = "fieldwork"
	first.completed = 3
	first.erase("ticket")
	var rebuilt := SaveUpgrade.before_restore(first,lines)
	var expected := Dispatch.legacy_ticket(3,lines)
	check(rebuilt.ticket.number == expected.number and rebuilt.ticket.vin == expected.vin and rebuilt.ticket.point is Array,
		"a version 1 call becomes its packed legacy ticket")
	check(SaveUpgrade.finished_roadside("invoice",{"kind":"ditch"}) and not SaveUpgrade.finished_roadside("invoice",{"kind":"ditch","case_id":"ride"}),
		"finished roadside work leaves the open ticket, but Tou's ride stays")

	# The upgraded version 1 shift loads with its legacy call open.
	game.free()
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.saved_data = first
	game._action("play")
	check(game.job.get("vin") == expected.vin and game.mode == "fieldwork", "the rebuilt legacy call resumes")
	game.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("CHECKS PASSED — older saves upgrade before restore and current saves pass through")
	quit(0)
