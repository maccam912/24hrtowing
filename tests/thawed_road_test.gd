extends "res://tests/shift_test.gd"

func stop_distance(at: Vector3) -> float:
	rig.in_cab = true
	rig.set_spawn(at,0.)
	rig.speed = 10.
	rig.motion = Vector3.FORWARD*rig.speed
	for frame in 225:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,1./60.)
		if rig.is_stopped(): break
	return rig.get_truck_position().distance_to(at)

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	var weather = game.sightings
	game.completed = 19
	rig.set_spawn(Vector3(400,0,246),0.)
	weather.drive = 1020
	weather.level = 2
	weather._start("dry_road",game,rig.get_truck_position(),"Kolpack Rd",false)
	check(weather.active=="dry_road","a straight rural road can receive a thaw")
	var strip = game.county.thawed_roads.dry_road
	var middle := Vector3(strip.center.x,0,strip.center.y)
	var verge := middle+Vector3.RIGHT*7.2
	check(strip.half_length==52.5 and game.county.road_contact(verge)==Vector2(1.,0.),"the quarter-mile footprint follows the pavement and leaves the shoulder snowbound")
	check(strip.vapor.get_child_count()==6 and strip.vapor.visible,"steam rises over fresh exposed asphalt")
	check(game.county.materials.road.get_shader_parameter("dry_road_strip")==strip.geometry(),"the road material and tire contact use the same place")
	weather.finish(game)
	rig.fuel = 1
	rig.climate.blower = 0
	rig.climate.air = .1
	rig.set_spawn(middle,0.)
	for frame in 180: rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,1./60.)
	check(rig.climate.air>.22,"heat from the wet lane reaches the cab with the blower off")
	var dry := stop_distance(middle)
	game.completed += 2
	weather.snow_over(game.completed)
	check(is_equal_approx(strip.freeze,.82) and not strip.vapor.visible,"the same lane refreezes and stops steaming across later jobs")
	var ice := stop_distance(middle)
	check(ice>dry*1.38,"the glazed surface needs a longer stop: %.2f wet / %.2f ice" % [dry,ice])
	rig.tire_chains = true
	var chains := stop_distance(middle)
	check(chains<ice*.83,"chains bite through the glaze: %.2f with chains" % chains)
	game.save()
	game._restore(JSON.parse_string(JSON.stringify(game.saved_data)))
	check(is_equal_approx(game.county.thawed_roads.dry_road.freeze,.82),"the ice and its age survive a reload before another driving frame")
	weather.snow_over(game.completed+2)
	await process_frame
	check(not game.county.thawed_roads.has("dry_road") and is_zero_approx(game.county.materials.road.get_shader_parameter("dry_road_half")),"falling snow covers the patch and restores the ordinary road")
	rig.set_spawn(Vector3(400,0,253),0.)
	weather._start("snow_roof",game,rig.get_truck_position(),"Kolpack Rd",false)
	var roof = game.county.thawed_roads.snow_roof
	var inside := Vector3(roof.center.x,0,roof.center.y)
	rig.set_spawn(inside,0.)
	weather._advance_live(3.,game,inside)
	var covered: Vector2 = game.county.snow_shader.get_shader_parameter("roof_span")
	check(covered.x>90 and covered.y>.85 and game.county.storm.visible,"snow is clipped at the two-hundred-metre roof while the surrounding storm keeps drawing")
	rig.set_spawn(inside+Vector3.RIGHT*24,0.)
	weather._advance_live(.1,game,rig.get_truck_position())
	check(rig.sighting_calm<.01 and game.county.roof_strength>.85,"wind returns on the shoulder while the gap remains visible across the field")
	weather.finish(game)
	check(game.county.roof_strength==0,"flakes return after the roof passes")
	game.free()
	if not failures: print("CHECKS PASSED — wet lane, tire contact, refreezing, warm cab and localized snow roof")
	quit(int(failures>0))
