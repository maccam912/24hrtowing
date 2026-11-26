extends "res://tests/rig_test.gd"

const Deck := preload("res://scripts/rollback_deck.gd")
var recovered_calls := 0
var deliveries := 0
var landed := Vector3.INF
var travel_locks := false

func tick(count: int, winch := false) -> void:
	for i in count: rig.set_controls(Vector2.ZERO,Vector2.ZERO,winch,false,STEP)

func panel() -> void:
	var at: Vector3 = rig._panel()
	stand_at(at-rig.body.global_basis.x*.68)
	aim_at(at)

func at_side(side: int) -> void:
	var bed: Node3D = rig.rollback_deck.bed
	var at := bed.to_global(Vector3(side*1.92,0,Deck.CAR_CENTER))
	stand_at(at)
	aim_at(bed.to_global(Vector3(side*.89,.30,Deck.CAR_CENTER)))

func receive_car() -> void:
	deliveries += 1
	landed = rig.car.position
	travel_locks = rig.rollback_deck.extension == 0. and not rig.is_chocked()
	# The county clerk moves the received car into storage synchronously.
	rig.end_job()

func resume() -> void:
	var saved: Dictionary = rig.save_state()
	rig.restore_state(saved)

func run() -> void:
	var test_road := TestRoad.new()
	root.add_child(test_road)
	rig = Rig.new()
	test_road.add_child(rig)
	rig.setup(test_road)
	await physics_frame
	for kind: String in ["hazard","ditch","passenger","looksee","field_visit"]:
		require(Deck.supports({"kind":kind}),"carrier serves "+kind)
	for recovery: String in ["roll","nose","ice","roof","tree","semi","milk"]:
		require(not Deck.supports({"kind":"hazard","recovery":recovery}),"wrecker keeps "+recovery)
	require(not Deck.supports({"kind":"hold"}) and not Deck.supports({"kind":"ditch","heavy_recovery":true}),"county pickup and double lines remain with the wrecker")
	require(Deck.supports({"kind":"ditch","variant":6}) and not Deck.supports({"kind":"ditch","variant":5}),"a squad sedan fits and the snowplow is heavy")
	rig.snatch_block = true
	rig.second_winch = true
	rig.use_rollback(true)
	var deck: Deck = rig.rollback_deck
	require(deck.visible and not rig.body.boom.visible and not rig.body.service_body.visible and not rig.auxiliary_drum.visible,"selected truck shows the carrier, its headboard and no wrecker boom")
	rig.recovered.connect(func(_kind): recovered_calls += 1)
	rig.dropped.connect(receive_car)
	rig.start_job("hazard",Vector3(2.3,0,19),.23,{"plate":"KFH 305","vin":"CARRIER-SLIP"})
	stand_at(rig.car.position+Vector3.LEFT*2.)
	operate("flare",rig.car.position+Vector3.UP)
	rig.set_spawn(Vector3(0,0,13))
	panel()
	require(rig.action_id()=="deck_align" and not rig.is_chocked(),"short setup can be corrected before touching the controls")
	rig.set_spawn(Vector3.ZERO)
	panel()
	operate("deck_out",rig._panel())
	tick(32)
	resume()
	require(deck.extension>.2 and deck.extension<.6 and rig.is_chocked(),"deployment resumes halfway with tires chocked")
	tick(100)
	var toe := deck.bed.to_global(Vector3(0,0,Deck.HALF_LENGTH))
	require(rig.phase=="cable" and absf(toe.y)<.09 and toe.z>9.,"sliding bed lowers its tail to the actual pavement")
	var eye: Vector3 = rig._eyelet(-1)
	stand_at(eye+Vector3.LEFT*1.2)
	operate("attach",eye)
	panel()
	require(rig.action_id()=="winch" and "runners" in rig.context_text(), "carrier uses the normal holdable desktop and touch winch action")
	for i in 340:
		tick(1,true)
		if rig.car.position.y>.31: break
	require(rig.car.position.y>.31 and rig.car.position.distance_to(deck.bed.global_position)>1.7,"front tires climb before the rear tires are aboard")
	var paused: Vector3 = rig.car.position
	tick(40)
	resume()
	require(rig.car.position.distance_to(paused)<.015,"a partial winch can be released and resumed on the runners")
	panel()
	tick(650,true)
	require(rig.phase=="at_lift" and not rig.loaded, "the car stops at the headboard before the straps are set")
	at_side(1)
	operate("deck_strap",rig.car.position)
	resume()
	require(deck.sides==2 and deck.restraints[1].visible and not deck.restraints[0].visible,"far-side restraints remain visibly fastened on save")
	at_side(-1)
	operate("deck_strap",rig.car.position)
	panel()
	operate("deck_home",rig._panel())
	tick(140)
	require(rig.loaded and deck.extension==0. and recovered_calls==1 and not rig.is_chocked(),"all four wheels are strapped and the bed locks for travel exactly once")
	rig.in_cab=true
	for i in 135: rig.set_controls(Vector2(.58,-1),Vector2.ZERO,false,false,STEP)
	var seat := deck.bed.to_local(rig.car.position)
	require(absf(seat.z-Deck.CAR_CENTER)<.005 and absf(seat.y-.025)<.005 and absf(rig.heading)>.01,"car rides rigidly on the turning deck")
	resume()
	require(rig.rollback_active and rig.loaded and rig.car.get_meta("vin")=="CARRIER-SLIP","loaded carrier and passenger vehicle identity survive restart")
	rig._stop_motion()
	var bay: Vector3 = rig.dropoff.center
	rig.set_spawn(bay-Vector3.RIGHT*11.82,PI/2)
	tick(2)
	panel()
	require(rig.at_dropoff(),"four footprint corners fit between the amber bay lamps from the tail")
	operate("deck_unload",rig._panel())
	tick(128)
	at_side(-1)
	operate("deck_unstrap",rig.car.position)
	at_side(1)
	operate("deck_unstrap",rig.car.position)
	panel()
	operate("deck_pay",rig._panel())
	tick(69,true)
	var halfway:Vector3 = rig.car.position
	tick(31)
	resume()
	require(deck.motion=="pay" and rig.car.position.distance_to(halfway)<.015 and deliveries==0,"unloading pauses and resumes before the receipt")
	panel()
	tick(290,true)
	require(deliveries==1 and rig.phase=="idle" and landed.distance_to(bay)<.55 and travel_locks,"car lands in the amber storage bay and the empty bed locks home")
	# A ditch customer wants a straight pull, then drives home. Leave the
	# carrier bed locked and use its rear roller for the return line.
	rig.set_spawn(Vector3.ZERO)
	rig.start_job("ditch",Vector3(2.8,0,16),.2,{"variant":6})
	stand_at(rig.car.position+Vector3.RIGHT*1.85)
	operate("flare",rig.car.position)
	panel()
	operate("cable",rig._panel())
	var rear_eye: Vector3 = rig._eyelet(1)
	stand_at(rear_eye+Vector3.BACK*.85)
	operate("attach",rear_eye)
	panel()
	tick(1200,true)
	require(rig.phase in ["departing","done"] and recovered_calls==2 and deck.extension==0.,"a squad takes its own wheels home after a carrier ditch pull")
	rig.restore_state({"kind":"","phase":"idle"})
	require(not rig.rollback_active and not deck.visible and rig.body.service_body.visible and rig.auxiliary_drum.visible,"a save from before the carrier uses the original fitted wrecker")
	if not failed: print("CHECKS PASSED — rollback deck travel, wheel straps, loaded handling, stamped storage drop, and interrupted saves.")
	quit(1 if failed else 0)
