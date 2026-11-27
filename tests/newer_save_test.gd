extends SceneTree

const Ledger := preload("res://scripts/ledger.gd")
# A private folder keeps the operator's real shift out of reach.
const FOLDER := "user://ledger-check"
const FILE := FOLDER + "/brandt-operations.json"
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("CHECK FAILED: " + message)
		failed = true

func put(name: String, value) -> void:
	var f := FileAccess.open(name, FileAccess.WRITE)
	f.store_string(value if value is String else JSON.stringify(value))
	f.close()

func text(name: String) -> String:
	return FileAccess.get_file_as_string(name) if FileAccess.file_exists(name) else ""

func clear() -> void:
	for name in [FILE, FILE+".previous", FILE+".new"]:
		if FileAccess.file_exists(name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(name))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	clear()
	var later := {"version":Ledger.VERSION+1,"rig":{},"completed":40,"marker":"LATER BUILD"}
	var current := {"version":Ledger.VERSION,"rig":{},"completed":7,"marker":"THIS BUILD"}

	# A later build's shift is neither loaded nor rotated out by this build's autosave.
	put(FILE, later)
	put(FILE+".previous", current)
	check(Ledger.read(FILE).is_empty(), "a later build's save does not load")
	check(Ledger.newer_build, "a later build's save locks this build's writes")
	for i in 3:
		check(not Ledger.write({"rig":{},"completed":0}, FILE), "autosave is refused while a later save is on file")
	check("LATER BUILD" in text(FILE) and "THIS BUILD" in text(FILE+".previous") and not FileAccess.file_exists(FILE+".new"),
		"both files keep their shifts after repeated autosaves")

	# An unreadable primary falls back to the backup, and a later backup locks too.
	clear()
	put(FILE, "{\"version\": 5, \"rig\"")
	put(FILE+".previous", later)
	check(Ledger.read(FILE).is_empty() and Ledger.newer_build, "a later backup behind a damaged file locks writes")

	# This build's own saves still load, write and rotate as before.
	clear()
	put(FILE, current)
	var loaded := Ledger.read(FILE)
	check(not Ledger.newer_build and loaded.get("marker") == "THIS BUILD", "this build's save loads")
	check(Ledger.write({"rig":{},"completed":8}, FILE), "this build's save writes")
	check(int(Ledger.read(FILE).get("completed",-1)) == 8 and "THIS BUILD" in text(FILE+".previous"), "a write rotates the last shift into the backup")
	check(Ledger.read(FILE+".missing").is_empty() and not Ledger.newer_build, "no save starts a fresh shift")
	clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))

	# The title tells the operator why the route is missing and that it is safe.
	var game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(not game.state.get("newer_save", true), "an ordinary launch shows no newer-save note")
	Ledger.newer_build = true
	game._refresh()
	check(game.state.get("newer_save", false) and not game.state.has_save, "the title offers a fresh shift and explains the later save")
	game.desk.surface.queue_redraw()
	await process_frame
	Ledger.newer_build = false
	game.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("CHECKS PASSED — a later build's shift stays on file")
	quit(0)
