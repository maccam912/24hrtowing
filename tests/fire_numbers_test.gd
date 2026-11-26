extends "res://tests/campaign_test.gd"

const Addresses := preload("res://scripts/fire_numbers.gd")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	check(Addresses.number("hoffmann") == "N5104" and Addresses.number("alder") == "N5420","existing case addresses match the marked lanes")
	for pair: Array in [["frames","angie"],["farm","south_farm"],["bridge","county_seat"]]:
		var a: Vector2 = Addresses.PARCELS[pair[0]].at
		var b: Vector2 = Addresses.PARCELS[pair[1]].at
		var along := absf(a.y-b.y) if Addresses.north_south(Addresses.PARCELS[pair[0]].road) else absf(a.x-b.x)
		var values := int(Addresses.number(pair[0]).substr(1))-int(Addresses.number(pair[1]).substr(1))
		check(absf(values-along*264.0/400.0) <= 1.0,"twenty feet per address in the printed order")
	for id: String in Addresses.PARCELS:
		for side: String in ["_A","_B"]:
			var face := game.county.find_child("FirePlate_"+id+side,true,false) as Label3D
			check(face and face.text == Addresses.number(id),"sign on each approach to "+id)
	var target := Addresses.post(game.county,"frames")
	rig.driving_view = "cab"
	rig.set_spawn(Vector3(1.7,0,-192))
	aim(target)
	check(Addresses.readable(rig,game.county).is_empty(),"a stock beam cannot resolve a distant number")
	game.account.equipment["lamps"] = true
	rig.body.fit_lamps(true)
	game._action("spot")
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(Addresses.readable(rig,game.county) == "frames","aiming the fitted pillar spot resolves the same post at the longer distance")
	rig.body.point_spot(true,-1.2,0)
	check(Addresses.readable(rig,game.county).is_empty(),"a live spot pointed elsewhere cannot reveal a number")
	rig.body.point_spot(true,rig.camera_yaw,rig.camera_pitch)
	var wall := StaticBody3D.new()
	game.world.add_child(wall)
	wall.position = rig.eyes.global_position.lerp(target,.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0,4.0,1.0)
	collision.shape = shape
	wall.add_child(collision)
	await physics_frame
	check(Addresses.readable(rig,game.county).is_empty(),"a fence or a wall that blocks sight also blocks the readback")
	wall.free()
	await physics_frame
	game.desk._touch_mode = true
	game._refresh()
	await tap_control("read_fire_plate")
	check(game.desk.page == "map" and game.desk.fire_parcel == "frames" and game.desk.fire_leaf == 0,"touch opens the stopped plat at the actual Duda parcel")
	await tap_control("fire_next")
	check(game.desk.fire_leaf == 1,"read the second sheet of indexed owners")
	await tap_control("plat_pencil")
	check(game.desk.fire_leaf < 0 and game.desk.pencil_open,"pencil can mark the researched stop")
	game.desk.dismiss()
	rig.body.fit_lamps(false)
	rig.spot_on = false
	rig.set_spawn(Vector3(2.4,0,-205.8))
	aim(target)
	check(Addresses.readable(rig,game.county) == "frames","ordinary wrecker can pull up to the same fire plate")
	rig.speed = 3.0
	game._action("read_fire_plate")
	check(game.desk.page.is_empty(),"a moving rig stays under control")
	rig.speed = 0.0
	rig.in_cab = false
	rig.foot = Vector3(target.x,0,target.z-3.2)
	aim(target)
	check(Addresses.readable(rig,game.county) == "frames","the other sign face can be read on foot")
	aim(target+Vector3(12,0,2))
	check(Addresses.readable(rig,game.county).is_empty(),"proximity alone does not spot a plate")
	var roman: Vector3 = game.County.Dryhouse.grower_position(game.county)
	stand(roman+Vector3(0,0,1.8),roman)
	check(game._site_action() == "grower" and "Roman" in game._prompt(),"the grower at the loading dock can be approached in person")
	game._action("interact")
	game._action("interact")
	check(game.speaker == "ROMAN DUDA" and Addresses.number("brandt") in game.subtitle,"the grower teaches the next signed drive along K")
	var history := []
	var found := {}
	for i in 40:
		var ticket: Dictionary = game.Dispatch.ordinary(i,44,history)
		var slip: Dictionary = game.Dispatch.issue_slip(ticket,100,101,102,28,"02:10")
		history.append(slip)
		if Addresses.PARCELS.has(ticket.site):
			var number := Addresses.number(ticket.site)
			check(number in ticket.location and number in ticket.directions and number in slip.location,"slip, radio and physical plate match")
			found[ticket.site] = true
	check(found.size() >= 7,"ordinary dispatch uses rural and highway addresses")
	game.free()
	if not failures:
		print("CHECKS PASSED — twenty-foot fire numbers, both sign faces, stock and aimed beams, sightlines, touch plat and printed dispatch")
	quit(int(failures > 0))

func aim(at: Vector3) -> void:
	rig._update_eyes()
	var direction: Vector3 = rig.eyes.global_position.direction_to(at)
	rig.camera_yaw = atan2(-direction.x,-direction.z) - (rig.heading if rig.in_cab else 0.0)
	rig.camera_pitch = asin(direction.y)
	rig._update_eyes()
