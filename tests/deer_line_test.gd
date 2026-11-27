extends "res://tests/sighting_reports_test.gd"
const Deer := preload("res://scripts/deer_crossing.gd")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	game._action("play")
	game._take_rotation()
	game.desk._touch_mode = true
	rig = game.rig
	var ticket: int = game.job.number
	var director = game.sightings
	director.drive = ticket
	director.level = 2
	rig.set_spawn(Vector3(1.8,0,-165),0.)
	director._start("deer_line",game,rig.truck.position,"County K",false)
	check(director.active=="deer_line","the northbound lane has a clear forest crossing")
	if director.active != "deer_line": game.free();quit(1);return
	var herd = director.scene.herd
	var center: Vector3 = herd.origin
	var before: PackedVector3Array = herd.head_points()
	check(before.size()==5 and before[0].x< -5.0 and before[4].x>5.0,"five animals span both shoulders and both lanes")
	check(herd.heads.all(func(head: Node3D)->bool: return head.rotation.x>.60),"the buck and does tip their muzzles into the air")
	rig.set_spawn(center+Vector3(1.8,0,24),0.)
	director._advance_live(director.duration*.17,game,rig.truck.position)
	check(herd.deer[2].position.x==center.x,"a slowly approaching operator can stop and watch from the cab")
	game._action("horn")
	for tick in 6: game._physics_process(DT)
	check(game.audio.recovery.driving.horn.volume_db>-22. and herd.deer[2].position.x==center.x and herd.heads[2].rotation.x>.60,"the roof horn sounds through the calm while the line holds")
	var eye: Vector3 = rig.get_camera().global_position
	watch(eye+(eye-center))
	check(choice("Deer standing in a line").is_empty(),"turning away from the moving set piece does not earn a report")
	watch(before[2])
	check(not choice("Deer standing in a line").is_empty(),"a sustained look past the windshield at two or more animals earns the radio choice")
	await file_report("Deer standing in a line")
	check("room to clear" in game.subtitle and game.job.number==ticket,"Arlene acknowledges the live herd and keeps the current paid slip")
	director._advance_live(director.duration*.52,game,rig.truck.position)
	check(herd.deer[2].position.x > center.x and game.county.calm<.01,"the calm ends and the herd walks off toward the same bank")
	var halfway: PackedVector3Array = herd.head_points()
	resume_shift()
	director=game.sightings
	herd=director.scene.herd
	check(herd!=null and herd.head_points()[2].distance_to(halfway[2])<.001,"an interrupted crossing restores the buck to the same stride")
	rig.set_spawn(center+Vector3(1.8,0,31),0.)
	for tick in 500:
		rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,DT)
		director._advance_live(DT,game,rig.truck.position)
		if (rig.truck.position-center).dot(director.forward)> -9.: break
	check(herd.deer.all(func(deer: Node3D)->bool: return game.county.road_distance(deer.position.x,deer.position.z)>6.),"every hoof has left the traveled lanes before the bumper arrives")
	director.finish(game)
	var prints: PackedVector3Array = director.scene.remnant_evidence("hoofprints")
	check(prints.size()==3 and prints[0].x< -5. and prints[2].x>23. and absf(prints[0].z-prints[2].z)<.35,"a continuous straight set of cloven tracks reaches both ditches")
	check(director.aftermath.hoofprints.road=="County K" and choice("Straight line of hoofprints").is_empty(),"dispatch needs an actual look at the separate ground trace")
	resume_shift()
	director = game.sightings
	rig.in_cab=false
	stand(prints[2]+Vector3.BACK*1.6,prints[2])
	rig.get_camera().look_at(prints[2],Vector3.UP)
	check(game._site_action()=="inspect_sighting","on-foot USE can inspect the far bank's surviving hoofprints")
	game._action("interact")
	rig.in_cab=true
	rig.update_eyes()
	await file_report("Straight line of hoofprints")
	check("snow cover" in game.subtitle and game.job.number==ticket,"dispatch logs the tracks without interrupting the tow")
	check(not Deer.has_room(game,Vector3(0,0,0),Vector3.FORWARD,"County K"),"the herd will not walk across an intersecting traffic lane")
	rig.set_spawn(Vector3(798.1,0,145),PI)
	director._start("deer_line",game,rig.truck.position,"County FF",false)
	check(director.active=="deer_line","southbound traffic can encounter the opposite bank")
	if director.active=="deer_line":
		herd=director.scene.herd
		var south_center: Vector3 = herd.origin
		rig.speed=21.0
		for remaining: float in [43.,35.,27.,19.,11.,8.]:
			director._advance_live(DT,game,south_center+Vector3.FORWARD*remaining)
		check(herd.deer.all(func(deer: Node3D)->bool: return deer.position.x<794.0),"a faster southbound rig leaves the whole line on the west bank before passing")
	game.free()
	if not failures: print("CHECKS PASSED — whitetails across both banks, driver observation, calm release, moving approach, resumed gait and cloven tracks")
	quit(int(failures>0))
