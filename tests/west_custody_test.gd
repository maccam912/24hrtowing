extends "res://tests/shift_test.gd"
const Bay := preload("res://scripts/west_hold_bay.gd")

func point_at(point: Vector3, offset := Vector3(.9,0,0)) -> void:
	rig.in_cab=false
	stand(point+offset,point)
	game._refresh()

func interact_at(point: Vector3, action: String, offset := Vector3(.9,0,0)) -> void:
	point_at(point,offset)
	check(game._site_action()==action or (game._site_action().is_empty() and rig.action_id()==action),"reachable interaction "+action+" at "+str(point)+" (offered "+game._site_action()+"/"+rig.action_id()+")")
	game._action("interact")

func ray_locked() -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(-82,1,-64),Vector3(-85,1,-64))
	return not game.county.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig=game.rig
	game.desk._touch_mode=true
	game.dispatch_seed=9
	game.account.cash=500.0
	game.held=true
	game.bay_locked=true
	game.county.set_bay_locked(true)
	game._display_storage()
	game._action("interact")
	point_at(game.FAX)
	await tap_control("interact")
	await tap_control("parts_prev")
	game._action("buy_west_hold")
	check(not game.account.owns("west_hold") and not game.county.west_bay,"west fence is fitted first")
	await tap_control("buy_west_lot")
	await tap_control("buy_west_hold")
	var cash: float = game.account.cash
	await tap_control("close")
	check(game.account.owns("west_hold") and cash==70. and is_instance_valid(game.county.west_bay),"both yard fittings were bought through the office")
	await physics_frame
	check(not ray_locked(),"the new bay is physically open")
	resume_shift()
	check(is_instance_valid(game.county.west_bay) and game.held and game.bay_locked,"the existing survey hold stays secure alongside the installed second bay")
	game._prepare_offers()
	var normal: String = game.rotation_offer.vin
	interact_at(Bay.BOOK,"west_order_book")
	check(game.desk.page=="west_custody","physical book opens West Hold paperwork")
	await tap_control("close")
	check(game.job.is_empty() and game.rotation_offer.vin==normal,"leaving the book keeps the desk’s ordinary contract available")
	interact_at(Bay.BOOK,"west_order_book")
	await tap_control("west_accept")
	check(game.mode=="fieldwork" and game.job.has("sheriff_order") and game.rotation_offer.vin==normal,"accepting signs out a distinct optional order")
	var ticket: Dictionary = game.job.duplicate(true)
	var point: Vector3 = game.job.point
	var yaw: float = game.job.angle
	var forward := Vector3.FORWARD.rotated(Vector3.UP,yaw)
	rig.set_spawn(point+forward*13,yaw)
	point_at(point,rig.car.global_basis.x*2.4)
	game._action("interact")
	check(rig.phase=="scene" and not game.job.has("pickup_signature"),"the car stays put before roadside transfer")
	interact_at(rig.get_witness_position(),"west_pickup_card")
	await tap_control("west_sign_pickup")
	check(game.job.pickup_signature==game.west_orders.SIGNATURE and game.job.checked_tape.deputy=="Pelz","the visible officer signs the same vehicle’s original tape and order")
	resume_shift()
	check(game.job.sheriff_order==ticket.sheriff_order and game.job.has("pickup_signature"),"a signed scene resumes without taking a second signature")
	interact_at(rig.car.position,"flare",rig.car.global_basis.x*2.1)
	interact_at(rig._panel(),"cable",-rig.truck.global_basis.x)
	interact_at(rig._eyelet(1),"attach",rig.car.global_basis.z*.75)
	point_at(rig._panel(),-rig.truck.global_basis.x)
	for tick in 3200:
		if rig.phase!="rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,rig.tension<.94,false,DT)
		game.seconds_worked+=DT
	interact_at(rig._panel(),"lift",-rig.truck.global_basis.x)
	check(game.mode=="haul" and rig.dropoff.sign=="WEST HOLD 2","normal cable and side panel load the sheriff car")
	rig.in_cab=true
	park_tow(game.BAY,-PI/2)
	check(not rig.at_dropoff(),"the original evidence floor cannot receive a West Hold order")
	park_tow(game.YardDrop.STORAGE.center,-PI/2)
	check(not rig.at_dropoff(),"ordinary storage cannot clear a sheriff order")
	park_tow(Vector3(-70,0,-64),-PI/2)
	for tick in 720:
		if rig.at_dropoff(): break
		rig.set_controls(Vector2.DOWN,Vector2.ZERO,false,false,DT)
	stop()
	check(rig.at_dropoff() and Bay.fits(rig.car),"the loaded car backs through the actual west gate and all four corners fit")
	rig.odo+=1.3
	var parked: Vector3 = rig.car.global_position
	interact_at(rig._panel(),"drop",-rig.truck.global_basis.x)
	check(game.mode=="invoice" and game.county.west_bay.vehicle.get_meta("vin")==ticket.vin and game.stored.is_empty(),"the exact sheriff car is retained in its own bay")
	check(Vector2(parked.x,parked.z).distance_to(Vector2(game.county.west_bay.vehicle.position.x,game.county.west_bay.vehicle.position.z))<.03,"the car stays where the operator set it down")
	point_at(game.FAX)
	game._action("fax")
	check(game.slips.is_empty() and game._filing_blocker().contains("Lock"),"unsecured vehicle cannot be paid")
	interact_at(Bay.LATCH,"west_chain",Vector3.RIGHT)
	check(not game.west_orders.locked,"the chain cannot close around the parked wrecker")
	rig.set_spawn(Vector3(-72,0,-60),-PI/2)
	interact_at(Bay.LATCH,"west_chain",Vector3.RIGHT)
	await physics_frame
	await physics_frame
	check(game.west_orders.locked and ray_locked(),"the keyed chain blocks the physical driveway")
	resume_shift()
	check(game.west_orders.locked and game.county.west_bay.vehicle.get_meta("vin")==ticket.vin,"the signed, parked and locked vehicle resumes")
	point_at(game.FAX)
	game._action("interact")
	check(game.completed==1 and game.slips[0].custody_fee==20 and game.slips[0].loaded>0 and game.fax_text.contains(ticket.sheriff_order),"the signed order earns the county tow rate, custody fee and loaded mileage")
	check(game.fax_text.contains(game.west_orders.SIGNATURE) and game.account.pending==game.slips[0].pay,"the fax contains the signed carbon and the money reaches accounts")
	game.desk.dismiss()
	interact_at(Bay.LATCH,"west_chain",Vector3.RIGHT)
	check(game.west_orders.locked,"signed release is required before opening a filed hold")
	# Keep working the original rotation while the separate sheriff car is secured.
	await do_ordinary_service()
	check(game.completed==2 and game.fax_text.contains("SHERIFF RELEASE") and game.county.west_bay.clerk.visible,"the next filed receipt returns clearance for the correct original car")
	game.desk.dismiss()
	interact_at(Bay.COUNTERSIGN+Vector3.UP,"west_release_card")
	check(game.desk.page=="west_custody" and game.west_orders.locked,"handoff document can be inspected before unlocking")
	game._action("west_sign_release")
	check(not game.west_orders.current.is_empty(),"a closed chain prevents the release")
	game.desk.dismiss()
	interact_at(Bay.LATCH,"west_chain",Vector3.RIGHT)
	interact_at(Bay.COUNTERSIGN+Vector3.UP,"west_release_card")
	await tap_control("west_sign_release")
	check(game.west_orders.current.is_empty() and game.west_orders.archive.size()==1 and game.held and game.bay_locked,"only the separately authorized sheriff car is released")
	var amount:float=game.account.earned
	game._action("west_sign_release")
	check(game.west_orders.archive.size()==1 and game.account.earned==amount,"release signatures cannot duplicate a tow or a payment")
	resume_shift()
	check(game.west_orders.archive[0].released_by=="Brandt" and rig.departures.any(func(d): return d.identity.get("west_release",false)),"the release and departing deputy persist")
	interact_at(Bay.BOOK,"west_order_book")
	await tap_control("west_archive")
	check(game.state.west_card.vin==ticket.vin and game.state.west_card.status=="RELEASED" and game.state.west_card.has("arrival_odo"),"the retained paper names the individual car, deputy, pickup, lock and final recipient")
	game.desk.dismiss()
	for tick in 1500: rig._trail(DT)
	var sheriff_cars: Array = rig.departures.filter(func(d): return d.identity.get("west_release",false))
	check(sheriff_cars.is_empty() or sheriff_cars[0].car.position.x > -61.,"deputy boards and takes the car through the west gate")
	check(game.west_orders.offer(game).is_empty(),"fresh orders leave room for ordinary receipts")
	await do_ordinary_service()
	check(game.completed==3 and game.account.pending==0 and is_equal_approx(game.account.cash,cash+game.account.earned),"the third actual fax settles all three invoices, including the first secured hold")
	game.desk.dismiss()
	var next:Dictionary=game.west_orders.offer(game)
	check(next.vin!=ticket.vin and next.sheriff_order!=ticket.sheriff_order and next.location!=ticket.location,"the next eligible order has fresh identity and scene")
	game.free()
	if not failures: print("CHECKS PASSED — paid west-bay installation, original evidence hold, optional order, roadside signature, actual reverse-in, secure chain, fax payment, authorized release, deputy departure and saved custody book")
	quit(int(failures>0))

func do_ordinary_service() -> void:
	rig.in_cab=true
	game._refresh()
	game._action("radio")
	await tap_control("respond")
	var ticket: Dictionary = game.job
	check(ticket.kind in ["ditch","hazard"] and not ticket.has("sheriff_order"),"ordinary radio and recovery remain independent of the west bay")
	var front := Vector3.FORWARD.rotated(Vector3.UP,float(ticket.angle))
	rig.set_spawn(rig.job_site+front*13,ticket.angle)
	point_at(rig.car.position,rig.car.global_basis.x*2.2)
	if game._site_action()=="driver": game._action("interact")
	game._action("interact")
	interact_at(rig._panel(),"cable",-rig.truck.global_basis.x)
	interact_at(rig._eyelet(-1),"attach",-rig.car.global_basis.z*.7)
	point_at(rig._panel(),-rig.truck.global_basis.x)
	for tick in 3200:
		if rig.phase!="rigged": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,rig.tension<.94,false,DT)
		game.seconds_worked+=DT
	if rig.phase=="at_lift":
		interact_at(rig._panel(),"lift",-rig.truck.global_basis.x)
		rig.in_cab=true
		park_tow(game.YardDrop.STORAGE.center+Vector3(4,0,0),PI/2)
		interact_at(rig._panel(),"drop",-rig.truck.global_basis.x)
	check(game.mode=="invoice" or not game.pending_slips.is_empty(),"subsequent ordinary service produces a real payable slip")
	rig.set_spawn(game.SPAWN,-PI/2)
	point_at(game.FAX)
	game._action("interact")
