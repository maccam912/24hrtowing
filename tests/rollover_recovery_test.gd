extends "res://tests/tree_recovery_test.gd"

func touch_at(at: Vector3, facing: Vector3) -> void:
	stand(at,facing)
	game._refresh()
	await tap_control("interact")

func land_and_file() -> void:
	var panel: Vector3 = rig._panel()
	stand(panel-rig.truck.global_basis.x*.75,panel)
	for i in 3000:
		if rig.phase == "at_lift": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.phase == "at_lift","the car travels from the hay to the wheel-lift")
	await use_panel()
	check(game.mode == "haul" and rig.loaded,"the straps secure the car for the trip to storage")
	park_tow(game.YardDrop.STORAGE.center,PI/2)
	rig.in_cab = false
	await use_panel()
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	game.desk.dismiss()

func operate_both(id: String, at: Vector3) -> void:
	game.sightings._record(id,at,0,game.completed,0,"Kolpack Rd")
	var order: Dictionary = game.sightings.recovery_offer(11,game.county,true,false,true)
	check(order.get("id")==id and order.two_drum_roll,"the sheriff releases the same car when both winches are available")
	game._accept(order)
	var vin: String = order.vin
	rig.set_spawn(at+Vector3(0,0,-16),0)
	rig.in_cab = false
	await touch_at(rig.car.position+Vector3.LEFT*2.,rig.car.position)
	await use_panel()
	var near: Vector3 = rig._side_eye(-1.)
	var far: Vector3 = rig._side_eye(1.)
	await touch_at(near+Vector3.LEFT*.85,near)
	stand(far+Vector3.RIGHT*.85,far)
	check(rig.action_id().is_empty(),"the second hook is still on its own truck drum")
	await use_panel()
	check(rig.rollover.fetched,"the operator takes the second hook at the side panel")
	await touch_at(far+Vector3.RIGHT*.85,far)
	await use_panel()
	check(rig.rollover.controls and game.state.has("drum_instruction"),"the fitted drums have their own usable controls")
	var initial: Transform3D = rig.car.transform
	stroke(Vector2.UP,100)
	check(rig.car.transform.is_equal_approx(initial) and rig.special_work == 0.,"the main drum holds until the check line takes the slack")
	stroke(Vector2.LEFT,140)
	check(rig.rollover.preload_fraction==1. and rig.special_work==0.,"the check drum takes the weight without upsetting the car")
	stroke(Vector2.UP,105)
	var progress: float = rig.special_work
	var pose: Transform3D = rig.car.transform
	resume_shift()
	check(rig.rollover.controls and rig.rollover.preload_fraction == 1. and is_equal_approx(rig.special_work,progress) and rig.car.transform.is_equal_approx(pose),"both drum brakes hold the exact load through a restart")
	stroke(Vector2.UP,240)
	check(rig.special_work == .5,"the main drum reaches the balance point without lowering the opposite side")
	stroke(Vector2.DOWN,360)
	check(rig.special_work == 1. and rig.rollover != null and not rig.rollover.controls and absf(rig.car.rotation.x)+absf(rig.car.rotation.z)<.01,"easing the check line sets this car back on four tires")
	await use_panel()
	check(rig.phase == "rigged" and not rig.rollover.check_cleared,"an attached check line holds the wheel-lift tow at the panel")
	far = rig._side_eye(1.)
	await touch_at(far+Vector3.RIGHT*.85,far)
	check(rig.rollover.check_cleared,"the check hook comes out on the far side")
	await land_and_file()
	check(game.slips.back().vin==vin and game.slips.back().heavy_fee==game.Dispatch.HEAVY_FEE,"filing pays the two-drum recovery for the observed VIN")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	game.campaign.stage = 2
	game.account.cash = 0
	var held := Vector3(377,0,144)
	game.sightings._record("field_car",held,0,0,0,"Kolpack Rd")
	var original: String = game.sightings.aftermath.field_car.vehicle.vin
	game.rotation_offer = {}
	game._prepare_offers()
	game._action("radio")
	await tap_control("respond")
	check(game.job.get("id") == "level_field_car" and game.job.vin != original and game.sightings.aftermath.field_car.vehicle.vin==original,"a stock truck can earn a separate Act 2 tow while the inverted car stays in its field")
	if game.job.get("id")!="level_field_car":
		game.free()
		quit(1)
		return
	var field: Vector3 = game.job.point
	rig.set_spawn(field+Vector3(20,0,0),-PI*.5)
	rig.in_cab=false
	await touch_at(field+Vector3.LEFT*2.,rig.car.position)
	await use_panel()
	var eye: Vector3 = rig._eyelet(rig._nearest_eyelet())
	await touch_at(eye+Vector3(.8,0,.5),eye)
	await land_and_file()
	check(game.slips.back().recovery=="level_field" and game.slips.back().heavy_fee == 0 and game.account.earned > 0 and not rig.second_winch,"the stock equipment earns a normal call-out, hook and storage fee")
	check(game.sightings.recovery_offer(11,game.county,false,false,false).is_empty(),"the clerk only issues one stock fallback for the same waiting car")
	game.account.equipment.snatch_block = true
	game.account.equipment.second_winch = true
	rig.snatch_block = true
	rig.second_winch = true
	await operate_both("field_car",held)
	await operate_both("nose_car",Vector3(376,0,159))
	var old: Dictionary = game.Dispatch.impossible(22,"nose_car",held,"nose_old","Kolpack Rd","the hay strip","Kolpack Rd")
	old.erase("two_drum_roll")
	game._accept(old)
	rig.set_spawn(held+Vector3(0,0,-16),0)
	rig.in_cab=false
	game.account.equipment.erase("second_winch")
	rig.second_winch=false
	await touch_at(held+Vector3.LEFT*2.,rig.car.position)
	await use_panel()
	var first: Vector3 = rig._side_eye(-1.)
	await touch_at(first+Vector3.LEFT*.85,first)
	var second: Vector3 = rig._side_eye(1.)
	await touch_at(second+Vector3.RIGHT*.85,second)
	resume_shift()
	check(rig.rollover==null and rig.phase=="rigged" and not rig.second_winch,"an already accepted older two-line order keeps its original rigging after restore")
	await land_and_file()
	check(game.slips.back().vin==old.vin and game.slips.back().recovery=="nose","the grandfathered check-line setup finishes and pays without a new purchase")
	game.free()
	if not failures:
		print("CHECKS PASSED — stock inland tow, retained field VIN, independent drums on roof and nose, and completed pre-upgrade rollover")
	quit(int(failures>0))
