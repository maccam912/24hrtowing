extends "res://tests/sighting_reports_test.gd"
const Sedan:=preload("res://scripts/oncoming_sedan.gd")

func run() -> void:
	game=load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	game._action("play")
	game._take_rotation()
	rig=game.rig
	game.desk._touch_mode=true
	var first:int=game.job.number
	var dir=game.sightings
	for southbound: bool in [false,true]:
		var heading:=PI if southbound else 0.
		var along:=Vector3.FORWARD.rotated(Vector3.UP,heading)
		var right:=along.cross(Vector3.UP)
		rig.in_cab=true
		rig.driving_view="cab"
		rig.set_spawn(Vector3(0,0,602 if southbound else 595)+right*2.25,heading)
		dir.drive=first+(1 if southbound else 0)
		dir.level=3
		dir._start("empty_oncoming",game,rig.truck.position,"County K",false)
		check(dir.active=="empty_oncoming","a straight winter road accepts the moving car in both directions")
		if dir.active.is_empty(): game.free();quit(1);return
		var actor:Node3D=dir.scene.actor
		var lamp:Node3D=actor.get_node("VehicleLamps/LeftHeadlight")
		check(actor.has_node("EmptyCabin") and actor.find_children("*","AnimationPlayer",true,false).is_empty(),"the visible cabin contains seats and wheel without an animated driver")
		var mark: Vector3=dir.shoulder
		var lane:float=mark.dot(right)
		dir._advance_live(dir.duration*.12,game,rig.truck.position)
		watch(actor.to_global(Sedan.DRIVER))
		check(choice("Oncoming car").is_empty(),"headlights and distant glass alone do not identify an empty seat")
		check(-actor.global_basis.z.dot(along)<-.99 and lamp.is_visible_in_tree(),"a pair of headlamps points at the parked cab")
		dir._advance_live(dir.duration*.27,game,rig.truck.position)
		check(is_equal_approx(actor.position.dot(right),lane) and (actor.position-mark).dot(along)<-35.0 and lane<0.,"the sedan has stayed in its own opposing lane")
		check(not dir.scene.lights.visible,"the sedan has only its own lamps")
		var behind:Vector3=rig.get_camera().global_position-along*12.
		if southbound:
			watch(behind)
			check(choice("Oncoming car").is_empty(),"facing away through the pass leaves no report")
		else:
			watch(actor.to_global(Sedan.DRIVER))
			check(not choice("Oncoming car").is_empty(),"looking through the close windshield establishes the empty driver's seat")
			await file_report("Oncoming car")
			check("nobody at the wheel" in game.subtitle and game.job.number==first,"dispatch records exactly what the driver saw")
		dir._advance_live(dir.duration*.17,game,rig.truck.position)
		check(not actor.visible and dir.scene.live_evidence("empty_oncoming").is_empty(),"once the sedan clears the cab, there are no tail lamps in either real mirror")
		resume_shift()
		dir=game.sightings
		check(dir.active=="empty_oncoming" and not dir.scene.actor.visible,"reloading after the pass cannot bring the vanished taillights back")
		dir.finish(game)
		check(not dir.aftermath.has("empty_oncoming") and choice("Oncoming car").is_empty(),"a missed or reported pass leaves no ground trace or duplicate call")
	game.free()
	if not failures: print("CHECKS PASSED — opposite-lane headlamps, empty steering wheel, both headings, witnessed and missed passes, absent mirror lamps, resume")
	quit(int(failures>0))
