extends "res://tests/shift_test.gd"

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig=game.rig
	rig.set_spawn(Vector3(0,0,-210),0.)
	var director = game.sightings
	var scene = director.scene
	director.drive=1032
	director.level=3
	director._start("woods_car",game,rig.get_truck_position(),"County K",false)
	check(director.active=="woods_car","an open stretch of the K treeline can stage the approaching taillights")
	var car: Node3D = scene.actor
	var start: Vector3 = car.position
	check(game.county.road_distance(start.x,start.z)<3. and (start-rig.get_truck_position()).dot(director.forward)>35.,"the car starts ahead in the travel lane")
	check((-car.global_basis.z).dot(director.forward)>.99 and car.get_node("LeftTailGlow").is_visible_in_tree(),"both red taillights face the approaching driver")
	check(scene.live_evidence("woods_car").is_empty(),"a pair of taillights on the road alone cannot identify the sighting")
	director._advance_live(director.duration*.41,game,rig.get_truck_position())
	var before := car.position
	director._advance_live(.06,game,rig.get_truck_position())
	check((car.position-before).normalized().dot(-car.global_basis.z)>.97 and absf(car.position.y-start.y)<.25,"the level car follows its nose through the turn")
	var resume_at := car.position
	var state: Dictionary = JSON.parse_string(JSON.stringify(director.save_state()))
	director.restore(state,game.county)
	scene = director.scene
	car = scene.actor
	check(resume_at.distance_to(car.position)<.02,"an interrupted crossing returns to the same part of the curve")
	var track_direction: Vector3 = director.forward.cross(Vector3.UP)
	var first_print: Vector3 = director.shoulder+track_direction*scene.Woods.TRACK_START
	director._advance_live(director.duration*.33,game,rig.get_truck_position())
	check(not scene.live_evidence("woods_car").is_empty() and (-car.global_basis.z).dot(track_direction)>.99,"the car enters the narrow passage in line with the eventual tracks")
	director._advance_live(director.duration*.17,game,rig.get_truck_position())
	check(not car.visible and scene.live_evidence("woods_car").is_empty(),"the car and its lamps go dark at the far end of that passage")
	director.finish(game)
	var remnant: Dictionary = director.aftermath.woods_tracks
	var prints: PackedVector3Array = scene.remnant_evidence("woods_tracks")
	check(prints.size()==3 and Vector2(first_print.x,first_print.z).distance_to(Vector2(prints[0].x,prints[0].z))<.1,"the wet tracks begin inside the timber beyond the unbroken roadside snow")
	check((prints[2]-prints[0]).dot(track_direction)>20. and remnant.road=="County K","the tracks lead to the ring and retain their road for dispatch")
	game.free()
	if not failures: print("CHECKS PASSED — level taillights, narrow passage, reload and continuous field evidence")
	quit(int(failures>0))
