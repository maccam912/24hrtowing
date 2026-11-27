extends "res://tests/tree_recovery_test.gd"

func walk_to_point(at: Vector3, stop_at := .38) -> void:
	for tick in 2200:
		var offset: Vector3 = at-rig.foot
		if Vector2(offset.x,offset.z).length() <= stop_at: return
		rig.camera_yaw = atan2(-offset.x,-offset.z)
		rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,DT)
	check(false,"Brandt can walk to %s from %s" % [at,rig.foot])

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	var order: Dictionary = game.campaign.ticket(1024,"bridge")
	game._accept(order)
	var vin: String = order.vin
	check(rig.flowage != null and rig.car_lamps.visible,"the case sedan is running on the frozen flowage")
	var directions: Dictionary = game.current_road_map().nearest_section(Vector2(-434.,-85.))
	check(directions.section.name=="River Rd","the east approach has a road in the printed road graph")
	# Drive from the highway through the actual turn and parking apron.
	rig.set_spawn(Vector3(-393,0,0),PI/2)
	drive_to(Vector3(-424,0,0))
	drive_to(Vector3(-434,0,-21))
	drive_to(Vector3(-434,0,-124))
	drive_to(Vector3(-433,0,-139))
	drive_to(Vector3(-424,0,-143))
	stop()
	check(rig.flowage.supported(rig),"the drivable highway turn and landing allow a fully banked wrecker aimed toward the sedan")
	var parked: Vector3 = rig.truck.position
	var aim: float = rig.heading
	game._action("interact")
	check(not rig.in_cab,"Brandt steps down at the end of the road")
	var panel: Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.7,panel)
	game._action("interact")
	game._action("interact")
	check(rig.phase=="cable","the controls release a long steel line on the bank")
	# Walk the hook away from the load before paying it out across the ice.
	var drum: Vector3 = rig.drum_point()
	var point := Vector3(drum.x,0,drum.z-50.)
	stand(point,point+Vector3.FORWARD)
	for tick in 140: rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,DT)
	check(rig.flowage.end_reached and rig.flat_distance(rig.foot,drum)<52.,"the hook cannot be carried past the last wrap on the drum")
	for tick in 70: rig.set_controls(Vector2.DOWN,Vector2.ZERO,false,false,DT)
	check(not rig.flowage.end_reached and rig.flat_distance(rig.foot,drum)<50.,"a fully paid-out hook can be carried back without dropping the job")
	stand(panel-rig.truck.global_basis.x*.7,panel)
	var old_cable: Dictionary = rig.save_state()
	old_cable.erase("flowage")
	old_cable.truck = [-503.,0.,-134.]
	old_cable.heading = PI/2
	rig.restore_state(old_cable)
	panel = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.65,panel)
	check(rig.action_id()=="ice_repack","an old unfinished setup on the wrong bank offers to rewind and move the rig")
	rig.interact()
	check(rig.phase=="flared" and not rig.is_chocked() and "River Rd" in rig.info,"rewinding releases the truck and gives the operator the actual access road")
	var stranded: Dictionary = old_cable.duplicate(true)
	stranded.phase = "rigged"
	stranded.truck = [-495.,-2.,-134.]
	stranded.car = [-496.,-2.,-135.]
	rig.restore_state(stranded)
	panel = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.65,panel)
	check(rig.flowage.west_salvage and rig.action_id()=="ice_repack","an old partly hauled car can be recovered from its nearest solid bank")
	rig.interact()
	rig.set_spawn(Vector3(-512.,0.,-135.),PI/2)
	rig.in_cab = false
	await use_panel()
	check(rig.phase=="cable" and rig.car.position.x == -496.,"rewinding an old westward pull preserves the car's position and VIN")
	rig.restore_state(old_cable)
	panel = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.65,panel)
	rig.interact()
	rig.set_spawn(parked,aim)
	rig.in_cab=false
	await use_panel()
	var fairlead: Vector3 = rig.drum_point()
	var rear: Vector3 = rig.truck.global_basis.z
	walk_to_point(fairlead+rear*2.7-rig.truck.global_basis.x*1.8)
	var eye: Vector3 = rig.eyelet_point(1)
	var shore_eye: Vector3 = eye+Vector3(1.39,0,0)
	walk_to_point(shore_eye)
	stand(shore_eye,eye)
	game._refresh()
	check(rig.flowage.cable_out > 44. and rig.flowage.markers.multimesh.visible_instance_count>=10 and "FT MARK" in game.state.ice_line,"walking the hook onto the ice pays out enough line to pass the hundred-foot mark")
	await tap_control("interact")
	check(rig.phase=="rigged","Brandt can reach and attach the hook at the bumper on foot")
	walk_to_point(fairlead+rear*2.7-rig.truck.global_basis.x*1.8)
	panel = rig.panel_point()
	walk_to_point(panel-rig.truck.global_basis.x*.75)
	stand(panel-rig.truck.global_basis.x*.67,panel)
	check(rig.action_id()=="ice_creep","the bank has a low-speed drum setting")
	game._action("interact")
	var start: Vector3 = rig.car.position
	for tick in 4400:
		if rig.flowage.lip: break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.flowage.lip and not rig.flowage.seated and rig.car.position.x > start.x+17.,"the slow pull brings the front tires to the ice lip")
	var paused: Vector3 = rig.car.position
	for tick in 100: rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.car.position.is_equal_approx(paused),"a held winch cannot drag the car through the lip")
	resume_shift()
	check(rig.phase=="rigged" and rig.flowage.creep and rig.flowage.lip and rig.car.position.is_equal_approx(paused),"resuming an ice pull preserves the car, long line and drum setting")
	for tick in 36: rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.flowage.seated,"easing the winch lets the tires settle on the shore")
	for tick in 3000:
		if rig.phase == "at_lift": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.phase=="at_lift","the wrecker draws the sedan all the way onto firm ground")
	await use_panel()
	check(game.mode=="haul" and rig.loaded,"the case continues only with the car strapped to the lift")
	park_tow(game.YardDrop.STORAGE.center,PI/2)
	rig.in_cab=false
	await use_panel()
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.slips.back().vin==vin and "three hours gone" in game.faxes.back(),"storage and the sheriff’s missing-time report remain part of the original case")
	if not failures: print("CHECKS PASSED — drive River Rd, east bank, old rigging, real payout, ice lip, bank, stored case sedan and report")
	game.free()
	quit(int(failures > 0))
