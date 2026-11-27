extends "res://tests/shift_test.gd"

var touch_index := 21

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	game.desk._touch_mode = true
	rig = game.rig
	game.account.cash = 220.
	game._action("interact")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._refresh()
	await tap_control("interact")
	game._action("buy_aux_tank")
	check(game.desk.parts_labels().size()==3 and not game.account.owns("aux_tank") and not rig.aux_tank,"a stock truck has no transfer hardware or reserve controls before Act 2")
	game.desk.dismiss()
	game.campaign.stage = 1
	game.save()
	var ledger:Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	ledger.rig.erase("reserve_fuel")
	ledger.account.equipment.erase("aux_tank")
	game._restore(ledger)
	check(rig.reserve_fuel==0 and not rig.aux_tank,"a shift from before the tank upgrade resumes with its original fuel")
	game._refresh()
	await tap_control("interact")
	await tap_control("parts_prev")
	check(game.desk.parts_page==3,"the Act 2 yard catalog offers the auxiliary tank")
	await tap_control("buy_aux_tank")
	check(game.account.cash==65. and game.account.owns("aux_tank") and rig.aux_tank.visible and rig.reserve_fuel==0.,"the quoted $155 fits an empty tank beside the bed")
	var old_main:float = rig.fuel
	await tap_control("buy_reserve_fuel")
	check(game.account.cash==41. and is_equal_approx(rig.reserve_fuel,rig.Reserve.CAPACITY) and rig.fuel==old_main,"office fills the reserve for $24 and keeps the main reading")
	game._action("buy_reserve_fuel")
	check(game.account.cash==41.,"a full auxiliary tank cannot be billed again")
	game.desk.dismiss()
	# A driver can restart a dry PTO beside a chocked, open ticket.
	rig.in_cab = true
	game._action("rotation")
	var number:int = game.job.number
	rig.set_spawn(rig.job_site+Vector3(0,0,18))
	rig.in_cab = false
	rig.phase = "rigged"
	rig.free_line = rig.flat_distance(rig.drum_point(),rig.eyelet_point(-1))
	rig.set_chocks()
	rig.fuel = 0.0
	game._refresh()
	check("curb-side" in game.state.hint_action and "curb-side" in rig.reserve_hint(),"the out-of-fuel guidance identifies the installed pump")
	await open_valve()
	var level_before:float = rig.fuel+rig.reserve_fuel
	await hold_nozzle(48)
	check(is_equal_approx(rig.fuel,.040) and is_equal_approx(rig.reserve_fuel,.460) and is_equal_approx(rig.fuel+rig.reserve_fuel,level_before) and game.account.cash==41.,"holding the transfer switch moves existing diesel without another charge")
	var balance:float = rig.reserve_fuel
	game._physics_process(DT)
	check(rig.reserve_fuel==balance,"the transfer switch stops on release")
	resume_shift()
	check(rig.aux_tank.visible and is_equal_approx(rig.reserve_fuel,.460) and is_equal_approx(rig.fuel,.040) and game.job.number==number and rig.phase=="rigged","restart restores both fills, hardware, rigging and the open contract")
	var panel:Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x,panel)
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.working and rig.fuel<.04,"the transferred diesel powers the PTO again")
	var eye:Vector3 = rig.eyelet_point(rig.line_end)
	stand(eye+rig.car.global_basis.z*rig.line_end*.9,eye)
	game._action("interact")
	check(not rig.is_chocked(),"the powered rig can be disconnected before driving back to town")
	# Move the serviced rig to Esker and pump cash-limited diesel into only the selected tank.
	rig.fuel = .45
	rig.reserve_fuel = .05
	rig.in_cab = false
	rig.set_spawn(game.PUMP+Vector3(0,0,-8))
	var island:Vector3 = game.PUMP_ISLANDS[1]
	stand(island+Vector3.FORWARD*1.8,island)
	game.account.cash = 6.
	game._refresh()
	await tap_control("interact")
	check(game.desk.page == "bulk_pump" and game.state.nozzle_esker and game.state.nozzle_ready,"Esker opens its metered dispenser for the equipped truck")
	await tap_control("tank_reserve")
	await hold_nozzle(60)
	check(is_equal_approx(rig.reserve_fuel,.125) and is_equal_approx(rig.fuel,.45) and is_equal_approx(game.nozzle_sale,3.6) and is_equal_approx(game.account.cash,2.4),"a one-second reserve fill meters the same price per unit as main diesel")
	await tap_control("tank_main")
	await hold_nozzle(60)
	check(is_equal_approx(rig.fuel,.50) and is_equal_approx(rig.reserve_fuel,.125) and is_equal_approx(game.nozzle_sale,6.) and game.account.cash==0.,"cash-limited main fill stops the same meter without consuming the reserve")
	game.desk.dismiss()
	game.account.equipment.yard_pump = true
	game.fit_equipment()
	var hose:Vector3 = game.county.Fittings.NOZZLE
	stand(hose+Vector3.BACK*1.7,hose)
	game._refresh()
	await tap_control("interact")
	check(game.desk.page=="bulk_pump" and not game.state.nozzle_ready,"the installed yard nozzle cannot reach the reserve from another location")
	game.desk.dismiss()
	rig.set_spawn(hose+Vector3(4,0,5))
	stand(hose+Vector3.BACK*1.7,hose)
	game.account.cash = 12.00
	game._refresh()
	await tap_control("interact")
	await tap_control("tank_reserve")
	await hold_nozzle(40)
	check(is_equal_approx(rig.reserve_fuel,.175) and is_equal_approx(rig.fuel,.5) and is_equal_approx(game.account.cash,9.6) and is_equal_approx(game.nozzle_sale,2.4),"the Brandt bulk pump also meters reserve fuel independently")
	game.desk.dismiss()
	rig.fuel = .99
	await open_valve()
	await hold_nozzle(60)
	check(is_equal_approx(rig.fuel,1.) and is_equal_approx(rig.reserve_fuel,.165),"the transfer stops at a full main tank and preserves the unused reserve")
	resume_shift()
	check(is_equal_approx(rig.reserve_fuel,.165) and is_equal_approx(game.account.cash,9.6) and is_equal_approx(rig.fuel,1.),"the receipt and independently metered tanks survive another resume")
	game.free()
	if not failures: print("CHECKS PASSED — Act 2 fuel cell, office and two pump sales, field PTO restart, conserved volume and saved fills")
	quit(int(failures>0))

func open_valve() -> void:
	var pump:Vector3 = rig.body.to_global(rig.Reserve.PUMP)
	stand(pump+rig.truck.global_basis.x*1.06,pump)
	game._refresh()
	check(game._site_action()=="reserve_valve","the curb-side transfer switch is reachable by hand")
	await tap_control("interact")
	check(game.desk.page=="reserve_transfer","the physical pump opens its two gauges")

func hold_nozzle(ticks: int) -> void:
	await process_frame
	await process_frame
	var trigger := Rect2()
	for entry in game.desk.surface.hit_boxes:
		if entry.id=="nozzle": trigger = entry.rect
	check(trigger.has_area(),"a usable nozzle has a touch target")
	if not trigger.has_area(): return
	touch_index += 1
	var touch := InputEventScreenTouch.new()
	touch.index = touch_index
	touch.position = trigger.get_center()*game.desk.surface.unit
	touch.pressed = true
	root.push_input(touch,true)
	for tick in ticks: game._physics_process(DT)
	touch.pressed = false
	root.push_input(touch,true)
