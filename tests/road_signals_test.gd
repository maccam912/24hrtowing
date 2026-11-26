extends "res://tests/wheel_lift_test.gd"

func run() -> void:
	root.add_child(road)
	rig = Rig.new()
	road.add_child(rig)
	rig.setup(road)
	await physics_frame
	for eye: int in [-1,1]:
		attach_vehicle("hazard",2,eye)
		var bar: Node3D = rig.tow_signals
		require(is_instance_valid(bar) and bar.global_basis.z.dot(rig.truck.global_basis.z)>.95,"the red faces point back down the road from either hookup")
		cycle_pedals(rig.body.signals,bar)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
		rig.restore_state(saved)
		check_filaments(rig.tow_signals,false,false,"resumed tow at rest")
	rig.end_job()
	rig.use_rollback(true)
	cycle_pedals(rig.rollback_deck.signals,null)
	require(rig.rollback_deck.signals.get_parent()==rig.rollback_deck.bed and not rig.body.signals.is_visible_in_tree(),"the carrier shows lights on its sliding bed")
	rig.use_rollback(false)
	cycle_pedals(rig.body.signals,null)
	var freight = rig.Semi.new()
	freight.build(road,{})
	var freight_bar: Node3D = freight.freight_lamps().get_node("RoadSignals")
	freight_bar.set_lit(true,false)
	require(freight.trailer.is_ancestor_of(freight_bar) and freight_bar.brakes.visible and freight_bar.global_position.z>freight.trailer.position.z+8.,"the stop lamps ride behind the articulated freight box")
	road.queue_free()
	await process_frame
	if not failed: print("CHECKS PASSED — connected stop lamps, running lenses and reverse lamps on both hookups, fleet beds and the freight trailer")
	quit(int(failed))

func cycle_pedals(truck_lamps: Node3D, bar: Node3D) -> void:
	rig.in_cab=true
	rig.speed=4.
	rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,STEP)
	verify_pair(truck_lamps,bar,false,false,"forward")
	rig.set_controls(Vector2(0,1),Vector2.ZERO,false,false,STEP)
	verify_pair(truck_lamps,bar,true,false,"opposing throttle slows a moving rig")
	for i in 75:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,STEP)
	require(is_zero_approx(rig.speed),"held brake brings rig to rest")
	verify_pair(truck_lamps,bar,true,false,"brake pedal still down at rest")
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,STEP)
	verify_pair(truck_lamps,bar,false,false,"release at rest")
	for i in 12: rig.set_controls(Vector2(0,1),Vector2.ZERO,false,false,STEP)
	verify_pair(truck_lamps,bar,false,true,"rolling backward")
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,STEP)
	verify_pair(truck_lamps,bar,true,true,"braking a reversing load")
	rig._stop_motion()
	rig.in_cab=false
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,STEP)
	verify_pair(truck_lamps,bar,false,false,"operator on foot")

func verify_pair(truck_lamps: Node3D, bar: Node3D, red: bool, white: bool, state: String) -> void:
	check_filaments(truck_lamps,red,white,"truck "+state)
	if bar: check_filaments(bar,red,white,"tow "+state)

func check_filaments(lamps: Node3D, red: bool, white: bool, state: String) -> void:
	require(lamps.brakes.is_visible_in_tree()==red and lamps.reverse.is_visible_in_tree()==white,state)
