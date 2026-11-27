extends "res://tests/tree_recovery_test.gd"

const Roof := preload("res://scripts/coop_roof.gd")

func foot_to(point: Vector3, margin := .14) -> void:
	for i in 700:
		var direction: Vector3 = point-rig.foot
		if Vector2(direction.x,direction.z).length() <= margin: return
		rig.camera_yaw = atan2(-direction.x,-direction.z)
		rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,DT)
	check(false,"walk from %s to %s" % [rig.foot,point])

func face(point: Vector3) -> void:
	var next: Vector3 = point-rig.eyes.global_position
	rig.camera_yaw = atan2(-next.x,-next.z)
	rig.camera_pitch = atan2(next.y,Vector2(next.x,next.z).length())
	rig.update_eyes()
	game._refresh()

func touch(expected: String, target: Vector3) -> void:
	face(target)
	check(rig.action_id()==expected,"operator gets %s at %s (found %s)" % [expected,rig.foot,rig.action_id()])
	await tap_control("interact")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	game.sightings._record("roof_car",Roof.SITE,0.,18,Roof.TOP,"Highway 64")
	var order: Dictionary = game.sightings.recovery_offer(22,game.county,true,false,true)
	check(order.get("canopy_spreader",false) and game.sightings.aftermath.has("roof_car"),"dispatch retains the recorded roof sedan until acceptance")
	if not order.get("canopy_spreader",false):
		game.free()
		quit(1)
		return
	game.accept(order)
	rig.set_spawn(Vector3(79.,0,-1.6),PI/2)
	drive_to(Vector3(54.,0,-4.7))
	drive_to(Vector3(35.,0,-7.14))
	drive_to(Vector3(24.,0,-7.10))
	stop()
	check(rig.roof.properly_parked(rig),"the westbound highway approach reaches the marked working pocket")
	game._action("interact")
	await use_panel()
	await use_panel()
	check(rig.phase=="cable" and rig.roof.installed and rig.roof.spreader.visible,"parked wrecker plants stabilizers and sets the headframe over the canopy")
	foot_to(Vector3(30.7,0,-10.3))
	foot_to(Roof.LADDER+Vector3.LEFT*.48)
	await touch("roof_ladder",Roof.LADDER+Vector3.UP*1.34)
	stroke(Vector2.UP,65)
	var partial: float = rig.roof.ladder
	resume_shift()
	check(partial>1. and partial<4. and is_equal_approx(rig.roof.ladder,partial) and rig.foot.y>1.,"Brandt resumes partway up the west service ladder")
	stroke(Vector2.UP,150)
	await touch("roof_top",Roof.LADDER+Vector3.UP*Roof.TOP)
	check(rig.roof.on_roof and rig.foot.y>4.7,"operator steps onto the actual canopy")
	foot_to(Vector3(35.38,0,-13.60))
	await touch("roof_shackle",rig.roof.pin(rig,-1.))
	check(rig.roof.slings==1 and rig.phase=="cable","one side of the spreader is pinned but cannot be lifted")
	foot_to(Vector3(35.35,0,-10.88))
	foot_to(Vector3(38.67,0,-10.88))
	foot_to(Vector3(38.67,0,-13.60))
	await touch("roof_shackle",rig.roof.pin(rig,1.))
	check(rig.roof.slings==3 and rig.phase=="rigged","walking round the parked sedan ties both wheel bridles")
	foot_to(Vector3(38.67,0,-10.88))
	foot_to(Vector3(32.35,0,-10.88))
	foot_to(Vector3(31.88,0,-12.65))
	await touch("roof_down",Roof.LADDER+Vector3.UP*Roof.TOP)
	stroke(Vector2.DOWN,175)
	await touch("roof_off",Roof.LADDER+Vector3.UP)
	var panel: Vector3 = rig.panel_point()
	foot_to(rig.truck.to_global(Vector3(2.45,0,6.15)))
	foot_to(rig.truck.to_global(Vector3(-2.38,0,6.15)))
	foot_to(panel-rig.truck.global_basis.x*.65)
	await touch("roof_boom",panel)
	check(rig.roof.controls and game.state.roof_slew,"touch panel names the outward slew")
	var initial: Vector3 = rig.car.position
	stroke(Vector2.LEFT,100)
	check(rig.car.position.distance_to(initial)<.03 and rig.roof.sweep==0.,"the wheels cannot slew through the canopy lip")
	stroke(Vector2.UP,67)
	stroke(Vector2.LEFT,110)
	var suspended:Vector3 = rig.car.position
	var progress: float = rig.roof.sweep
	var hook: Vector3 = rig.car.to_global(Vector3.UP*2.80)
	var sheave: Vector3 = rig.body.boom_tip.global_position
	check(rig.flat_distance(sheave,hook)<.03 and sheave.y>hook.y+1.15,"the sheave stays directly over the suspended spreader with a vertical hoist cable")
	check(progress>.25 and progress<.75 and suspended.z>initial.z+2.,"the boom rotates a raised car away from the delivery canopy")
	stroke(Vector2.DOWN,90)
	check(rig.car.position.y>=Roof.TOP+Roof.CLEARANCE-.04,"the lower lever holds the load above the eave")
	resume_shift()
	check(rig.roof.controls and is_equal_approx(rig.roof.sweep,progress) and rig.roof.slings==3,"the spreader and its swing angle resume with both bridles")
	stroke(Vector2.UP,70)
	stroke(Vector2.LEFT,260)
	stroke(Vector2.DOWN,460)
	check(rig.special_work==1. and rig.car.position.distance_to(Roof.LANDING)<.13 and not rig.roof.controls,"wheels land inside the four delivery chalk marks")
	var desk_panel: Vector3 = rig.panel_point()
	stand(desk_panel-rig.truck.global_basis.x*.65,desk_panel)
	for i in 1500:
		if rig.phase=="at_lift": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	await use_panel()
	check(game.mode=="haul" and rig.loaded,"street-side landing leaves an accessible paying underlift tow")
	park_tow(game.YardDrop.STORAGE.center,PI/2)
	rig.in_cab=false
	await use_panel()
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.slips.size()==1 and game.slips.back().vin==order.vin and game.slips.back().pay>0.,"the clerk receives the exact co-op sedan and its tow invoice")
	game.desk.dismiss()
	var legacy: Dictionary = order.duplicate(true)
	legacy.erase("canopy_spreader")
	rig.set_spawn(Vector3(25,0,-7),PI/2)
	rig.start_job("hazard",Roof.SITE,0.,legacy)
	rig.phase="rigged"
	rig.special_work=.32
	var old_car:Vector3 = rig.car.position
	var old:Dictionary=rig.save_state()
	rig.restore_state(old)
	check(rig.roof==null and rig.phase=="rigged" and rig.special_work==.32 and rig.car.position.is_equal_approx(old_car),"already accepted single-sling recoveries retain their original progress")
	panel = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.65,panel)
	for i in 1500:
		if rig.phase=="at_lift": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.special_work==1. and rig.phase=="at_lift","old single-sling controls still finish the roof recovery")
	game.free()
	if not failures: print("CHECKS PASSED — real canopy ladder, rooftop footwork, both slings, outward slew, storage delivery and legacy rigging")
	quit(int(failures>0))
