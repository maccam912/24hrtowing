extends "res://tests/shift_test.gd"

func gate_blocked() -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(-58,1.3,-64), Vector3(-64,1.3,-64))
	return not game.county.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	game.account.cash = 250.00
	# Two generations of old saves, including a car whose details live on its carbon.
	game.stored.append("river")
	for n in range(1,7):
		game.stored.append({"route":"river","number":1000+n,"variant":2})
	game.slips.append({"number":1006,"vehicle":"1989 station wagon","vin":"STAMPED106","plate":"KTR 518","time":"04:12","location":"Boom Road bridge","pay":66.5})
	game._display_storage()
	await physics_frame
	await physics_frame
	check(gate_blocked() and game.physical_cars.size() == 5,"old west fence encloses the five front stalls")
	check(game._storage_tag(0).get("route") == "river","a pre-numbered impound still has a yard tag")
	game._action("interact")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._refresh()
	await tap_control("interact")
	await tap_control("parts_prev")
	await tap_control("buy_west_lot")
	game.desk.dismiss()
	await physics_frame
	await physics_frame
	check(not gate_blocked() and game.county.west_lot_open and game.physical_cars.size() == 7,"the actual west gate opens onto occupied numbered stalls")
	check(game.account.cash == 5.0 and game.county.yard_contains(Vector2(-85,-65)),"extension clears the invoice and becomes drivable yard")
	var west: Vector3 = game.county.Fittings.west_stall(1)
	var parked: Node3D = game.physical_cars[6]
	check(is_equal_approx(parked.global_position.x,west.x) and is_equal_approx(parked.global_position.z,west.z),"seventh impound stands in W-02")
	stand(west+Vector3.FORWARD*2.5,west)
	game._refresh()
	check(game._site_action() == "storage_tag","approaching the stored car presents its windshield ticket")
	await tap_control("interact")
	check(game.desk.page == "storage_tag" and game.state.storage_tag.get("plate") == "KTR 518" and game.state.storage_tag.get("stall") == "WEST  W-02","physical windshield tag matches the filed carbon and the numbered stall")
	game.desk.dismiss()
	game._turn_storage_north()
	resume_shift()
	parked = game.physical_cars[6]
	check(game.county.west_lot_open and game.physical_cars.size() == 7 and is_zero_approx(parked.rotation.y) and game._storage_tag(6).get("vin") == "STAMPED106","reload keeps the extension, original identity and changed parked heading")
	game.free()
	if not failures:
		print("CHECKS PASSED — fenced west lot, open drive, overflow, original impound tags and saved headings")
	quit(int(failures > 0))
