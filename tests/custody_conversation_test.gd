extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game.desk._touch_mode = true
	rig = game.rig
	game.held = true
	game.survey.hold_order = "filed"
	game.filed_card = "TC-96-031 / J. Kowalski and Brandt"
	game._display_storage()
	rig.in_cab = false
	stand(game.BAY+Vector3.FORWARD,game.BAY)
	game.bay_locked = true
	game._action("read_field")
	check(not game.book_read,"a fresh field book cannot be taken through a locked chain")
	game.bay_locked = false
	game._action("interact")
	check(game.hold_door_open and game.desk.page == "field" and not is_zero_approx(game.held_pickup.get_node("DriverDoor").rotation.y),"physically opening the held pickup reveals the seat book")
	game.desk.dismiss()
	resume_shift()
	var hinge: Node3D = game.held_pickup.get_node("DriverDoor")
	check(game.hold_door_open and not is_zero_approx(hinge.rotation.y),"an open door stays open when the yard is reloaded")
	var handle: Vector3 = hinge.to_global(Vector3(-.07,.46,1.16))
	stand(handle+Vector3.FORWARD*.6,handle)
	game._action("interact")
	check(not game.hold_door_open and is_zero_approx(hinge.rotation.y),"you can shut the door after putting the book away")
	rig.in_cab = true
	rig.set_spawn(game.SPAWN)
	game._refresh()
	game.save()
	var before: Dictionary = game.saved_data.duplicate(true)
	for answer: String in ["told_closed","told_open"]:
		game._restore(before.duplicate(true))
		rig.in_cab = true
		game._refresh()
		game.desk.show_document("custody",game.state)
		await tap_control("return_deputy_call")
		check(game.desk.page == "deputy_call","the optional callback uses the cab radio")
		await tap_control("close")
		check(game.survey.custody_reply.is_empty() and game._deputy_callback(),"ending the call leaves it open for another evening")
		game.desk.show_document("custody",game.state)
		await tap_control("return_deputy_call")
		await tap_control(answer)
		check(game.survey.custody_reply == answer and game.speaker == "KOWALSKI" and not game._deputy_callback(),"Kowalski accepts either account without checking the book")
		resume_shift()
		check(game.survey.custody_reply == answer and game.held and game.book_read and game.filed_card == before.filed_card and game.account.cash == before.account.cash and game.completed == before.completed,"the chosen reply survives without changing the hold, pay or case")
	game.free()
	if not failures:
		print("CHECKS PASSED — optional custody callback, both answers, physical pickup door and unchanged case")
	quit(int(failures > 0))
