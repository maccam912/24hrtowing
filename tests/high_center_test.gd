extends "res://tests/damaged_axle_test.gd"

const HighCenter := preload("res://scripts/high_center.gd")

func setup_at(end: int, sideways := false) -> void:
	var axis: Vector3 = rig.berm.patch.global_basis.z*end
	if sideways: axis = rig.berm.patch.global_basis.x
	var yaw := atan2(-axis.x,-axis.z)
	rig.set_spawn(rig.job_site+axis*17.5,yaw)

func attach(end: int) -> void:
	var eye: Vector3 = rig.eyelet_point(end)
	act("attach",eye,rig.car.global_basis.z*end*.84)

func crib_at(i: int) -> void:
	var at: Vector3 = rig.berm.wheel_point(i)
	act("crib_place",at,rig.car.global_basis.x*(-.91 if i==0 else .91))

func run_call(seed_value: int, use_cribs: bool, carrier: bool) -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig=game.rig
	if carrier:
		game.account.equipment.rollback=true
		game.fleet.receive(rig)
		act("fleet_door",game.fleet.door(),-game.fleet.model.global_basis.x)
	game.dispatch_seed=seed_value
	var prior: Array=[]
	for i in 80:
		var offered: Dictionary=game.Dispatch.ordinary(i,seed_value,prior)
		if offered.has("field_berm"): break
		prior.append(game.Dispatch.issue_slip(offered,0,0,0,45,"04:05"))
	check(prior.size()>=9,"the first job stays a simple ditch pull")
	game.slips=prior
	game.completed=prior.size()
	game.rotation_offer={}
	game._prepare_offers()
	var offer: Dictionary=game.rotation_offer
	check(offer.has("field_berm") and game.waiting_hazard.has_node("FrozenWindrow"),"a recurring taped hazard physically sits on the frozen ridge before the call")
	rig.in_cab=true
	game._action("radio")
	game.desk._activate("respond")
	var berm=rig.berm
	var high: int=berm.high_end
	var low_index:=0 if high>0 else 1
	var high_wheel: Vector3=berm.wheel_point(0)
	var low_wheel: Vector3=rig.road_wheels.hubs[low_index].global_position
	check(high_wheel.y-rig.road_wheels.radius-rig.ground_height(high_wheel)>.23,"suspended axle has visible daylight below its tire")
	check(absf(low_wheel.y-rig.road_wheels.radius-rig.ground_height(low_wheel))<.12,"the grounded axle actually carries its share")
	setup_at(high)
	rig.in_cab=false
	act("flare",rig.car.position,rig.car.global_basis.x*2.45)
	var rocker: Vector3=rig.car.to_global(Vector3(.89,.35,0))
	act("crib_inspect",rocker,rig.car.global_basis.x*.9)
	check(berm.inspected and rig.info.contains("Pan resting"),"the operator can inspect the contact from the sill")
	if carrier:
		lever("deck_out")
		work(140)
	else: lever("cable")
	attach(high)
	point(rig.panel_point(),-rig.truck.global_basis.x)
	if not use_cribs:
		work(140,true)
		check(berm.blocked,"a retry begins from a real stalled pull")
		var hooked: Vector3 = rig.eyelet_point(high)
		act("unhook",hooked,rig.car.global_basis.z*high*.73)
		check(not rig.is_chocked() and rig.phase=="flared","unhooking releases the line and shoring can be skipped")
		stand_at_cab_door(-1)
		game._action("interact")
		check(rig.in_cab,"operator can return to the truck to change ends")
		setup_at(-high)
		rig.in_cab=false
		lever("cable")
		attach(-high)
		point(rig.panel_point(),-rig.truck.global_basis.x)
	if use_cribs:
		var before: Vector3=rig.car.position
		work(180,true)
		check(berm.blocked and rig.tension>.76 and rig.car.position.distance_to(before)<.001,"a forward pull visibly loads the drum without dragging the belly across the obstruction")
		act("crib_fetch",berm.rack.global_position,-rig.truck.global_basis.x*.82)
		crib_at(0)
		work(20)
		resume_shift()
		berm=rig.berm
		check(berm.placed==1 and berm.wedges[0].visible and not berm.wedges[1].visible and berm.collected,"one wooden pack stays under its own wheel across restart")
		crib_at(1)
		check(berm.placed==3 and not berm.blocked and not berm.bundle.visible,"the second tire is supported")
		point(rig.panel_point(),-rig.truck.global_basis.x)
		work(100,true)
		var partial:Vector3=rig.car.position
		check(partial.distance_to(before)>.30 and not berm.cleared,"operator can stop partway across the physical packs")
		resume_shift()
		berm=rig.berm
		check(rig.car.position.distance_to(partial)<.01 and berm.wedges[1].visible,"the car and both blocks resume at their own world positions")
		point(rig.panel_point(),-rig.truck.global_basis.x)
	work(2200,true)
	check(berm.cleared and berm.used_blocks==use_cribs and rig.phase=="at_lift","the wheels settle off the ridge and normal loading takes over")
	if carrier:
		belt(-1,"deck_strap")
		belt(1,"deck_strap")
		lever("deck_home")
		work(140)
	else: lever("lift")
	check(game.mode=="haul" and rig.loaded,"the recovered vehicle is cleared for storage")
	var bill_method: String=game.job.get("handling","")
	var yard: Vector3=game.YardDrop.STORAGE.center
	if carrier:
		rig.set_spawn(yard-Vector3.RIGHT*11.82,PI/2)
		work(3)
		lever("deck_unload")
		work(130)
		belt(-1,"deck_unstrap")
		belt(1,"deck_unstrap")
		lever("deck_pay")
		work(460,true)
	else:
		park_tow(yard,-PI/2)
		lever("drop")
	check(game.mode=="invoice" and game.stored.back().vin==offer.vin,"only the real stored car goes on the slip")
	point(game.FAX,Vector3.FORWARD)
	game._action("interact")
	var slip: Dictionary=game.slips.back()
	check(slip.has("field_berm") and slip.handling==bill_method and game.fax_text.contains(bill_method) and game.account.earned>=slip.pay,"the actual cribbing choice reaches cash accounts and county fax")
	game.free()

func run() -> void:
	await run_call(4,true,false)
	await run_call(3,false,false)
	await run_call(3,true,true)
	if not failures: print("CHECKS PASSED — visible underbody contact, grounded and free wheels, blocked forward pull, field cribbing, reverse pull, loaded carrier, saved wooden packs, yard storage and paid invoice.")
	quit(int(failures>0))
