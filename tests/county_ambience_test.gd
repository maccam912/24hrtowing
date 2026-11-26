extends "res://tests/shift_test.gd"

func settle() -> void:
	for frame in 140:
		game._physics_process(DT)

func walk_listen(at: Vector3) -> void:
	rig.in_cab = false
	stand(at,at+Vector3.FORWARD)
	settle()

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	var sources: Dictionary = game.ambience.sources
	for id: String in sources:
		var loop: AudioStreamWAV = sources[id].stream
		check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.get_length() > 7.9, "the " + id + " source loops from an offline sample")

	walk_listen(Vector3(92,0,421))
	check(sources.dairy.volume_db > -11 and sources.dam.volume_db < -65, "the pump strokes carry to the Brzezinski driveway")
	check(game.audio.engines.diesel.volume_db < -65, "walking across the county leaves the parked truck's idle behind")
	var diesel: AudioStreamPlayer3D = game.audio.parked_diesel
	check(diesel.get_parent() == rig.truck and diesel.volume_db < -65, "the exterior exhaust sits over the parked truck's front axle")
	var open_cutoff: float = game.audio.wind_filter.cutoff_hz
	var field_level: float = sources.dairy.volume_db
	rig.set_spawn(Vector3(92,0,421),PI)
	walk_listen(rig.truck.to_global(Vector3(2,0,-2)))
	check(diesel.volume_db > -29 and game.audio.engines.diesel.volume_db < -65, "beside the hood the engine comes from the truck")
	rig.in_cab = true
	settle()
	check(diesel.volume_db < -65 and game.audio.engines.diesel.volume_db > -22, "closing the cab returns the engine to the cabin mix")
	check(sources.dairy.volume_db < field_level - 12 and game.audio.wind_filter.cutoff_hz < open_cutoff * .30, "closing the cab muffles both the pump and the blizzard")

	walk_listen(Vector3(-452,0,-124))
	check(sources.dam.volume_db > -10 and sources.dairy.volume_db < -70, "water carries up the bank to the flowage recovery")
	game.audio.set_sighting(1,0)
	game.county.set_sighting_weather("the_calm",1,.5)
	settle()
	check(sources.dam.volume_db < -70 and game.audio.engines.wind.volume_db < -65, "the rush of water leaves with the wind in the calm")
	game.audio.set_sighting(0,0)
	game.county.set_sighting_weather("",0,0)
	settle()
	check(sources.dam.volume_db > -10,"the spillway comes back when the calm passes")

	rig.warmth = .42
	walk_listen(Vector3(-53,0,-46))
	check(rig.warmth > .44 and not game.county.is_heated_shelter(Vector3(-53,5.6,-46)), "the furnace warms Brandt under the canopy")
	var warm_at_bay: float = rig.warmth
	walk_listen(Vector3(-53,0,-52))
	check(rig.warmth < warm_at_bay, "the open apron outside the chain is still cold")
	check(sources.yard.volume_db > -15 and sources.dam.volume_db < -70, "the heated bay has its own blower")
	walk_listen(game.PUMP)
	var open_wind: float = game.audio.engines.wind.volume_db
	var outside_cooler: float = sources.cooler.volume_db
	walk_listen(Vector3(-76,0,26))
	check(sources.cooler.volume_db > outside_cooler + 10 and sources.cooler.volume_db > -20, "the refrigerated case is audible at Mai's counter")
	check(game.audio.engines.wind.volume_db < open_wind - 14 and game.audio.wind_filter.cutoff_hz < 750, "the shop doorway cuts the wind and its high hiss")
	if not failures:
		print("CHECKS PASSED — localized county sounds, cab and shop shelter, and silence during the calm")
	quit(int(failures > 0))
