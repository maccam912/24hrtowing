extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://game.tscn").instantiate()
	root.add_child(game)
	if not game.test_session:
		printerr("A scripted shift can reach the operator’s live save")
		quit(1)
		return
	game._action("play")
	game.rig.odo += 17.0
	game._save()
	if not is_equal_approx(float(game.saved_data.rig.odo), game.rig.odo):
		printerr("Scripted shift failed to keep its own in-memory ledger")
		quit(1)
		return
	game.queue_free()
	await process_frame
	print("CHECKS PASSED — scripted shifts keep their own ledger")
	quit(0)
