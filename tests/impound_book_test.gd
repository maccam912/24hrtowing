extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode = true
	game._action("interact")
	var station: Vector3 = game.county.Fittings.REGISTER
	stand(station+Vector3.BACK*1.4,station)
	game._refresh()
	await tap_control("interact")
	check(game.desk.page == "impound_register" and game.state.impound_rows.is_empty(),"new yard has an accessible empty register")
	game.desk.dismiss()
	game.stored.append("bridge")
	for i in range(1,21):
		game.stored.append({"number":1000+i,"route":"river","variant":2})
		game.slips.append({"number":1000+i,"vehicle":"County wagon","vin":"VIN-%02d" % i,"plate":"EWR %03d" % i,"time":"04:17","location":"Boom Road","pay":78})
	game._display_storage()
	game._refresh()
	await tap_control("interact")
	check(game.state.impound_rows.size() == 3 and game.state.impound_pages == 7 and game.state.impound_rows[0].number == 1020,"newest receipts come first, including overflow beyond seventeen cars")
	await tap_control("impound_0")
	check(game.desk.page == "register_card" and game.state.storage_tag.stall == "COUNTY OVERFLOW" and game.state.storage_tag.vin == "VIN-20","overflow has a readable matching carbon and an honest location")
	await tap_control("impound_index")
	await tap_control("impound_next")
	await tap_control("impound_1")
	check(game.state.storage_tag.number == 1016,"turning the leaf opens the matching original carbon")
	await tap_control("impound_index")
	check(game.state.impound_leaf == 1,"returning to the index keeps its place")
	for i in 5:
		await tap_control("impound_next")
	check(game.state.impound_rows[2].route == "bridge" and game.state.impound_rows[2].stall == "FRONT  01","old unnumbered register entries stay accessible on the last leaf")
	await tap_control("impound_prev")
	check(game.state.impound_leaf == 5,"newer pages remain reachable")
	game.free()
	if not failures:
		print("CHECKS PASSED — impound register, overflow carbons, paging and old impounds")
	quit(int(failures > 0))
