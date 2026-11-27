extends "res://tests/shift_test.gd"

const Pool := preload("res://scripts/pool_repair.gd")
const Deck := preload("res://scripts/rollback_deck.gd")

func point(at: Vector3, offset: Vector3) -> void:
	rig.in_cab = false
	stand(at+offset,at)
	game._refresh()

func act(expected: String, at: Vector3, offset: Vector3) -> void:
	point(at,offset)
	var action: String = game._site_action()
	if action.is_empty(): action = rig.action_id()
	check(expected==action,expected+" offered at work point (got "+action+", phase "+str(rig.phase)+")")
	game._action("interact")

func lever(id: String) -> void:
	act(id,rig.panel_point(),-rig.truck.global_basis.x)

func work(count: int, operate := false) -> void:
	for i in count: rig.set_controls(Vector2.ZERO,Vector2.ZERO,operate and rig.tension<.95,false,DT)

func bad_wheel(id: String) -> void:
	act(id,rig.axle_fault.wheel_position(rig),rig.car.global_basis.x*rig.axle_fault.side*.90)

func belt(side: int, id: String) -> void:
	var bed: Node3D = rig.rollback_deck.bed
	act(id,bed.to_global(Vector3(side*.89,.3,Deck.CAR_CENTER)),bed.global_basis.x*side*1.03)

func accept_repair(seed_value: int) -> Dictionary:
	game.dispatch_seed = seed_value
	game.rotation_offer.clear()
	var held: Dictionary = game.Dispatch.hold_ticket(0,game.audio.lines,true)
	game.slips = []
	for i in 10:
		var prior: Dictionary = game.Dispatch.ordinary(i+1,seed_value,game.slips)
		prior.kind = "ditch" if i<6 else "hazard"
		game.slips.append(game.Dispatch.issue_slip(prior,10,11,12,60,"03:50"))
	var untouched: Dictionary = game.Dispatch.ordinary(10,seed_value,game.slips)
	check(not untouched.has("wheel_fault"),"experienced fleets without the dolly handover keep their ordinary calls")
	var first_dollies: Dictionary = game.Dispatch.issue_slip(held,10,11,12,60,"03:50")
	first_dollies.case_id = "unit"
	game.slips.push_front(first_dollies)
	game.completed = game.slips.size()
	game._prepare_offers()
	var offer: Dictionary = game.rotation_offer
	var ledger: Array = game.slips.duplicate(true)
	ledger.append(game.Dispatch.issue_slip(offer,10,11,12,60,"03:50"))
	var repeat: Dictionary = {}
	for i in 25:
		var next: Dictionary = game.Dispatch.ordinary(ledger.size(),seed_value,ledger)
		if next.has("wheel_fault"):
			check(i>=12,"at least twelve ordinary services separate repair jobs")
			repeat = next
			break
		ledger.append(game.Dispatch.issue_slip(next,10,11,12,60,"03:50"))
	check(not repeat.is_empty() and repeat.wheel_fault!=offer.wheel_fault and repeat.vin!=offer.vin and repeat.point!=offer.point,"later repair has a different fault, vehicle and site")
	check(offer.has("wheel_fault") and game.waiting_hazard.has_node("RoadWheels"),"dispatch generated a waiting motor pool car after the first dolly job")
	rig.in_cab = true
	game._action("radio")
	game.desk._activate("respond")
	check(game.mode=="fieldwork" and rig.axle_fault!=null,"ordinary radio opens the recovery")
	return offer

func recover(on_carrier: bool, lift_bad_end: bool, seed_value: int) -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	var before: Dictionary = game.Dispatch.ordinary(9,seed_value,[{"kind":"ditch","site":"bridge"}])
	check(not before.has("wheel_fault"),"learning rotation remains independent of later repair calls")
	if on_carrier:
		game.account.equipment.rollback = true
		game.fleet.receive(rig)
		var door: Vector3 = game.fleet.door()
		act("fleet_door",door,-game.fleet.model.global_basis.x)
		check(rig.rollback_active,"operator took the keys at the parked carrier")
	var ticket := accept_repair(seed_value)
	var original_cash: float = game.account.cash
	var start_count: int = game.completed
	var end: int = rig.axle_fault.end if lift_bad_end else -rig.axle_fault.end
	if on_carrier: end = -1
	for hub: Node3D in rig.road_wheels.hubs:
		check(absf(hub.global_position.y-rig.road_wheels.radius-rig.ground_height(hub.global_position))<.065,"four tires rest on the actual shoulder")
	var target: Vector3 = rig.car.position
	var direction: Vector3 = rig.car.global_basis.z*end
	var yaw: float = ticket.angle+(PI if end==1 else 0.)
	rig.set_spawn(target+direction*16,yaw)
	act("flare",target,rig.car.global_basis.x*2.4)
	var marked: Vector3 = rig.axle_fault.wheel_position(rig)
	var correct_side: Vector3 = rig.car.global_basis.x*rig.axle_fault.side
	point(marked-correct_side*rig.road_wheels.track*2,-correct_side)
	check(rig.action_id()!="axle_inspect" and not rig.axle_fault.checked,"the diagnosis is at the bound wheel")
	bad_wheel("axle_inspect")
	check(rig.axle_fault.checked and rig.info.contains(rig.axle_fault.corner()),"the operator identifies the actual wheel and its fault")
	if not on_carrier: resume_shift()
	if on_carrier:
		lever("deck_out")
		work(130)
	else: lever("cable")
	var eye: Vector3 = rig.eyelet_point(end)
	act("attach",eye,rig.car.global_basis.z*end*.74)
	check(rig.line_end==end,"operator can select the nearest front or rear eye")
	if on_carrier:
		lever("axle_needs_skates")
		var parked: Vector3 = rig.car.position
		work(60,true)
		check(parked.is_equal_approx(rig.car.position),"carrier winch holds until the stuck axle is on skates")
		bad_wheel("axle_skate")
		resume_shift()
		check(is_instance_valid(rig.axle_fault.skates) and rig.axle_fault.checked,"loading skates and the diagnosed corner survive interrupted rigging")
	point(rig.panel_point(),-rig.truck.global_basis.x)
	work(200,true)
	var locked_index: int = (2 if rig.axle_fault.side>0 else 0)+(1 if rig.axle_fault.end>0 else 0)
	check(absf(rig.road_wheels.hubs[locked_index].rotation.x)<.001 and absf(rig.road_wheels.hubs[locked_index^1].rotation.x)>.02,"the stuck tire drags while the sound axle rolls under cable tension")
	work(1800,true)
	check(rig.phase=="at_lift","the selected tow eye reached the lifting gear")
	if on_carrier:
		belt(-1,"deck_strap")
		belt(1,"deck_strap")
		lever("deck_home")
		work(140)
	else:
		if not lift_bad_end:
			lever("axle_needs_dollies")
			check(not rig.loaded,"the operator cannot tow a damaged trailing axle on its tires")
			bad_wheel("axle_dollies")
			resume_shift()
			check(rig.phase=="dollies" and is_instance_valid(rig.dollies),"the trailing Go-Jacks stay seated across restart")
		lever("lift")
	check(game.mode=="haul" and rig.loaded,"field rigging clears the road")
	rig.in_cab=true
	check(game._route_note().title.contains("REPAIR 03") and game._procedure().contains("REPAIR 03"),"loaded directions name the highway garage")
	var handling: String = game.job.handling
	check(("skates" in handling if on_carrier else ("carried" in handling if lift_bad_end else "dollies" in handling)),"the service copy retains the operator’s recovery choice")
	var highway := Vector3(1668,0,1.7)
	if on_carrier: rig.set_spawn(highway,-PI/2)
	else: park_tow(highway,-PI/2)
	for i in 1050: rig.set_controls(Vector2.UP,Vector2.ZERO,false,false,DT)
	stop()
	rig.set_spawn(game.YardDrop.STORAGE.center)
	if not on_carrier: park_tow(game.YardDrop.STORAGE.center,-PI/2)
	check(not rig.at_dropoff(),"the yard cannot take the county shop’s repair")
	var bay := Pool.CENTER
	if on_carrier:
		rig.set_spawn(bay-Vector3.RIGHT*11.82,PI/2)
		work(3)
		lever("deck_unload")
		work(130)
		belt(-1,"deck_unstrap")
		belt(1,"deck_unstrap")
		lever("deck_pay")
		work(460,true)
	else:
		park_tow(bay+Vector3.RIGHT*6.,-PI/2)
		check(rig.at_dropoff(),"all four corners fit in the repair stripes")
		lever("drop")
	check(game.mode=="available" and game.stored.is_empty() and is_instance_valid(game.received_pool_car),"the county receives its own vehicle outside door three")
	if game.mode!="available":
		game.free()
		return
	var landed: Vector3 = game.received_pool_car.position
	resume_shift()
	check(game.received_pool_car.position.distance_to(landed)<.02 and game.received_pool_car.get_meta("vin")==ticket.vin,"the same pool car resumes in the actual drop position")
	point(game.FAX,Vector3.FORWARD)
	game._action("interact")
	var filed: Dictionary = game.slips.back()
	check(game.completed==start_count+1 and filed.get("handling","")==handling and filed.storage==0 and filed.loaded>0 and filed.pay>=60,"the garage job faxes its own handling, mileage and county amount")
	check(game.fax_text.contains("REPAIR 03") and game.fax_text.contains("wheel" if ticket.wheel_fault==Pool.Fault.REAR_AXLE else "caliper"),"the repair diagnosis is on the fax")
	check(game.account.pending==0 and is_equal_approx(game.account.cash-original_cash,filed.pay),"the third receipt pays the loaded repair into the shop till")
	game.free()

func run() -> void:
	await recover(false,false,4)
	await recover(false,true,3)
	await recover(true,false,2)
	if not failures: print("CHECKS PASSED — damaged wheel inspection; direct lift, trailing Go-Jacks and rollback loading skates; wheel rotation, repair bay, receipt, payment and resume.")
	quit(int(failures>0))
