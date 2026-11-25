extends "res://tests/shift_test.gd"

func choice(label: String) -> String:
	for option: Dictionary in game.sightings.report_options():
		if option.label == label or str(option.label).begins_with(label + " · "):
			return option.key
	return ""

func watch(target: Vector3) -> void:
	rig.get_camera().look_at(target,Vector3.UP)
	for tick in 10:
		game.sightings.observations.sample(.15,game,game.sightings)

func file_report(label: String) -> void:
	var key := choice(label)
	check(not key.is_empty(),"operator can identify " + label)
	if key.is_empty(): return
	game._refresh()
	await tap_control("radio")
	await tap_control("report_sighting")
	await tap_control("sighting:" + key)
	check(game.desk.page.is_empty() and choice(label).is_empty(),"selected report is filed from the cab")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	game._take_rotation()
	game.campaign.stage = 2
	rig = game.rig
	var ticket: int = game.job.number
	var director = game.sightings
	director.drive = ticket
	# A second, unreported heavy recovery is already waiting in rotation.
	director._record("tree_car",director.FIXED.tree_car,0.,0,5.,"Swamp Rd")
	rig.set_spawn(Vector3(0,0,530),PI)
	director._start("field_car",game,rig.truck.position,"County K",false)
	director.finish(game)
	var spot: Vector3 = director.scene.remnant_evidence("field_car")[0]
	rig.in_cab = false
	stand(spot+Vector3.BACK*22.,spot)
	var eye: Vector3 = rig.get_camera().global_position
	watch(eye+(eye-spot))
	check(choice("Upside-down car").is_empty(),"a field car behind the driver stays off the radio")

	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(14,9,1)
	collision.shape = slab
	wall.add_child(collision)
	game.county.add_child(wall)
	wall.global_position = (eye+spot)*.5
	await physics_frame
	await physics_frame
	watch(spot)
	check(choice("Upside-down car").is_empty(),"an opaque roadside obstacle hides the car")
	wall.queue_free()
	await physics_frame
	await physics_frame
	game.sightings.observations.sample(.15,game,director)
	check(choice("Upside-down car").is_empty(),"a single glimpse does not identify the car")
	watch(spot)
	check(not choice("Upside-down car").is_empty(),"an older field car seen on foot can be reported back in the cab")

	rig.in_cab = true
	rig.set_spawn(Vector3(0,0,650),PI)
	director._start("green_circle",game,rig.truck.position,"County K",false)
	director.finish(game)
	var grass: Vector3 = director.scene.remnant_evidence("green_circle")[0]
	rig.in_cab = false
	stand(grass+Vector3.BACK*3.,grass)
	rig.get_camera().look_at(grass,Vector3.UP)
	check(game._site_action() == "inspect_sighting","USE identifies the physical grass on foot")
	game._action("interact")
	check(not choice("Circle of green grass").is_empty() and "grass" in game.subtitle.to_lower(),
		"inspecting the grass immediately adds it to the radio")
	rig.in_cab = true
	rig.set_spawn(grass+Vector3.BACK*20.)
	resume_shift()
	director = game.sightings
	check(not choice("Circle of green grass").is_empty() and not choice("Upside-down car").is_empty(),
		"both unfiled reports are still on the cab radio after resuming")
	await file_report("Circle of green grass")
	check("grass" in game.subtitle.to_lower() and "leave" in game.subtitle.to_lower(),"Arlene identifies the grass and gives an instruction")
	watch(grass)
	check(choice("Circle of green grass").is_empty(),"looking back at the same grass does not create another report")
	await file_report("Upside-down car")
	check("snatch block" in game.subtitle.to_lower() and game.job.number == ticket,
		"dispatch holds the field tow for the proper gear and leaves the current ticket open")
	check(director.recovery_offer(5,game.county,false,false).is_empty(),"a reported field car still requires a snatch block")
	check(director.recovery_offer(1,game.county,true,false).is_empty(),"the normal dispatch cadence is preserved")
	var offer: Dictionary = director.recovery_offer(5,game.county,true,false)
	check(offer.get("vin","") == director.aftermath.field_car.vehicle.vin,
		"the equipped truck is offered the exact reported car ahead of another eligible recovery")

	rig.set_spawn(Vector3(0,0,450),PI)
	director._start("empty_oncoming",game,rig.truck.position,"County K",false)
	director._advance_live(director.duration*.27,game,rig.truck.position)
	watch(director.scene.actor.to_global(Vector3.UP))
	director.finish(game)
	resume_shift()
	director = game.sightings
	await file_report("Oncoming car")
	check("wheel" in game.subtitle.to_lower() and "let it go" in game.subtitle.to_lower(),
		"dispatch acknowledges the passing driverless car after it has gone")
	check(choice("Upside-down car").is_empty() and choice("Circle of green grass").is_empty(),"filed reports remain filed across a reload")

	director.restore({"reportable":"swamp_lights"},game.county)
	check(director.report_options().is_empty(),"old saves do not turn a reserved encounter into a witnessed report")
	director._start("swamp_lights",game,rig.truck.position,"County K",false)
	watch(director.scene.sky_origin)
	check(choice("Lights over the swamp").is_empty(),"an event with unlit lamps has nothing to call in")
	director._advance_live(director.duration*.4,game,rig.truck.position)
	for view: String in ["chase","cab"]:
		if rig.driving_view != view: rig.toggle_driving_view()
		var camera := rig.get_camera() as Camera3D
		watch(camera.global_position+(camera.global_position-director.scene.lights.global_position))
		check(choice("Lights over the swamp").is_empty(),"looking away in the %s camera doesn't identify distant lights" % view)
	rig.get_camera().look_at(director.scene.lights.global_position,Vector3.UP)
	director.observations.sample(.15,game,director)
	check(choice("Lights over the swamp").is_empty(),"a flash past the lights does not identify them")
	watch(director.scene.lights.global_position)
	await file_report("Lights over the swamp")
	check("swamp" in game.subtitle.to_lower(),"the original light report still works")
	director.finish(game)
	rig.set_spawn(Vector3(0,0,476))
	rig.start_job("ditch",Vector3(8,0,456),0,{"vin":"RELEASED","plate":"TMR 817","variant":1})
	rig.phase = "departing"
	var driver = rig._begin_departure()
	watch(driver.car.to_global(Vector3.UP))
	check(choice("Car driving away").is_empty(),"a customer who has not boarded is not moving traffic")
	for frame in 360: driver.advance(DT)
	watch(driver.car.to_global(Vector3.UP))
	await file_report("Car driving away")
	check("ditch" in game.subtitle.to_lower() and "clear" in game.subtitle.to_lower(),
		"a released customer gets a different answer from the driverless car")

	# Dispatch can issue a recovery before the operator sees its source. The
	# car on the slip stays reportable and Arlene recognizes the existing order.
	game.campaign.stage = 2
	game.account.equipment["snatch_block"] = true
	game._fit_equipment()
	director._record("field_car",Vector3(23,0,596),0.,0,0.,"County K")
	game.job = {}
	game.mode = "available"
	game.completed = 5
	game.rotation_offer = {}
	game._take_rotation()
	check(game.job.get("id") == "field_car" and not director.aftermath.has("field_car"),"taking the recovery replaces the scenery with the authorized car")
	resume_shift()
	rig.in_cab = false
	spot = rig.car.to_global(Vector3.UP*.85)
	stand(spot+Vector3.BACK*14.,spot)
	watch(spot)
	rig.in_cab = true
	await file_report("Upside-down car")
	check("slip %04d" % int(game.job.number) in game.subtitle and "storage" in game.subtitle,"calling in an assigned car gets instructions for the current tow")
	game.free()
	if not failures:
		print("CHECKS PASSED — witnessed roadside reports, occlusion, dispatch replies, tow priority and radio save continuity")
	quit(int(failures>0))
