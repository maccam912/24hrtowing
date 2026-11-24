extends SceneTree
# Routes the first call by the ordinary steering and throttle controls. For later
# calls, stage the operator at each worksite to exercise the full five-ticket shift.
var game
var rig
var failures := 0
var total_moved := 0.0
const DT := 1.0/60.0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		printerr("CHECK FAILED: ",text)

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	rig = game.rig
	check(game.world_view.get_camera_3d() == game.title_camera, "title opens on the exterior wrecker")
	check(game.picture.texture == game.world_view.get_texture(), "menu displays the gameplay viewport")
	var opening_pose: Transform3D = game.title_camera.transform
	var parked: Transform3D = rig.truck.global_transform
	var initial_fuel: float = rig.fuel
	for frame in 30:
		game._physics_process(DT)
	check(game.world_view.render_target_update_mode == SubViewport.UPDATE_ALWAYS and not opening_pose.is_equal_approx(game.title_camera.transform), "the yard and camera stay live behind the menu")
	check(rig.truck.global_transform.is_equal_approx(parked) and rig.fuel == initial_fuel and game.shift_seconds == 0.0, "the title leaves the parked truck and shift clock alone")
	# This seed opens at the steeples and sends a separate hazard past the turnout.
	game.dispatch_seed = 84
	game._action("play")
	check(game.world_view.get_camera_3d() == rig.get_camera(), "starting puts the operator in the cab")
	check(game.mode == "available" and game.job.is_empty(), "the first contract waits for the operator")
	var radio_key := RegEx.create_from_string("\\bR\\b")
	check(radio_key.search(str(game.state.get("hint_action", ""))) != null, "the opening tutorial names the desktop radio key")
	press_key(KEY_T)
	check(game.mode == "available" and game.job.is_empty(), "asking for directions cannot accept a contract")
	game.desk._touch_mode = true
	game._refresh()
	for i in 5:
		if i == 0:
			var instruction := str(game.state.get("hint_action", "")).to_lower()
			check("radio" in instruction and "take contract" in instruction, "the touch tutorial explains both taps")
			await tap_control("radio")
			check(game.mode == "available" and game.desk.page == "radio", "opening the transceiver leaves the offer pending")
			await tap_control("respond")
		elif i == 2:
			visit_survey_turnout()
			# Stage the remaining routine slips to keep the five-ticket rigging exercise focused.
			game.campaign.ordinary_since = 5
			resume_shift()
			check(game.survey.notes.has("unit") and game.survey.notes.has("rod") and not game.survey.unit_reported,"observations survive a cold resume without opening a case")
			press_key(KEY_R)
			await tap_control("respond")
			press_key(KEY_R)
			await tap_control("report_unit")
			check(game.survey.hold_order == "offered" and game.mode == "fieldwork" and game.county.survey_pickup.visible, "a voluntary report opens one order and preserves the paying job")
		elif i >= 3:
			press_key(KEY_R)
			await tap_control("respond" if i == 3 else "take_case")
			if i == 3:
				check(game.survey.hold_order == "deferred" and game.job.kind == "hazard","keep me on rotation answers an ordinary dispatch immediately")
			else:
				check(game.survey.hold_order == "accepted" and game.job.kind == "hold" and not game.county.survey_pickup.visible, "Kowalski meets the operator at the original unit")
		else:
			press_key(KEY_R)
		check(game.mode == "fieldwork","accepted radio call")
		check(not game.county.drop_guide.visible, "the yard lights stay off until a vehicle is on the lift")
		var job: Dictionary = game.job
		var site: Vector3 = rig.car.position
		if i == 0:
			drive_to(Vector3(-7,0,-64))
			drive_to(Vector3(0,0,-54))
			drive_to(Vector3(0,0,site.z-16))
			drive_to(Vector3(site.x*.36,0,site.z-12))
			stop()
			check(game._prompt().is_empty(),"stopping at the scene leaves the cab view clear")
			check(rig.odo-game.dispatch_odo > 0.45,"actual drive to a generated County K pull counted empty miles")
		else:
			rig.set_spawn(Vector3(site.x+2,0,site.z-13),0)
		game._action("interact")
		check(not rig.in_cab,"driver left cab at scene")
		if i==1:
			var parked_car:Node3D=rig.car
			var before:=parked_car.global_transform
			stand_at_cab_door(1.0)
			game._refresh()
			check(game.state.can_enter_cab, "the passenger door offers ENTER CAB")
			await tap_control("interact")
			check(rig.in_cab and rig.car==parked_car and parked_car.global_transform.is_equal_approx(before),"re-entering at a roadside car preserves it")
			check(rig.eyes.is_position_in_frustum(parked_car.position+Vector3.UP),"re-entering frames the parked casualty in chase view")
			game._action("interact")
		if job.kind == "hold":
			var officer: Vector3 = rig.get_witness_position()
			stand(officer + Vector3(0,0,1),officer)
			game._action("interact")
			check(game.signed_card and game.desk.page=="custody","signed Kowalski's card")
			game.desk.dismiss()
			var survey: Vector3 = game.county.hold_tripod_point()
			stand(survey+Vector3(0,0,1),survey)
			game._action("interact")
			check(game.packed_tripod,"stowed survey gear")
		stand(site+Vector3(2.5,0,0),site)
		if game._site_action() == "driver":
			game._action("interact")
		game._action("interact")
		check(rig.phase=="flared" and is_instance_valid(rig.flame),"flare at scene "+str(i))
		var panel: Vector3 = rig._panel()
		var outside: Vector3 = rig.truck.global_basis.x*-1.1
		stand(panel+outside,panel)
		game._action("interact")
		check(rig.phase == "cable","chock and take line")
		if i==1:
			stand_at_cab_door(-1.0)
			game._action("interact")
			check(not rig.in_cab and rig.car.is_visible_in_tree() and rig.phase=="cable","carrying the hook keeps the truck chocked and the casualty at the scene")
		var hook_end:=1 if i==3 else -1
		var eye: Vector3 = rig._eyelet(hook_end)
		stand(eye+rig.car.global_basis.z*hook_end*.9,eye)
		game._action("interact")
		check(rig.phase=="rigged","attached cable")
		if i == 1:
			stand_at_cab_door(1.0)
			game._action("interact")
			check(not rig.in_cab and rig.car.is_visible_in_tree() and rig.phase=="rigged","the attached cable and car stay put at the cab door")
			game._save()
			var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
			game._restore(snapshot)
			check(rig.phase=="rigged" and not rig.in_cab,"resume with attached cable and unchanged view")
			check(is_instance_valid(rig.flame), "resuming active rigging restores its road flare")
			var operator_view: Transform3D = rig.get_camera().global_transform
			game.desk.toggle_pause()
			check(game.world_view.get_camera_3d() == rig.get_camera(), "pause keeps the operator view")
			game.desk._activate("title")
			game.desk._activate("options")
			check(game.world_view.get_camera_3d() == game.title_camera, "title settings keep the exterior view")
			game.desk.dismiss()
			game.desk._activate("play")
			check(game.world_view.get_camera_3d() == rig.get_camera() and rig.get_camera().global_transform.is_equal_approx(operator_view),"continuing restores the on-foot camera")
		stand(panel+outside,panel)
		var scene_flare: Node3D = rig.flame
		for tick in 3600:
			if rig.phase != "rigged":
				break
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,rig.tension < .94,false,DT)
			game.seconds_worked += DT
		if job.kind == "ditch":
			check(game.mode=="return","ditch driver released")
		else:
			check(rig.phase=="at_lift","winched to underlift")
			if job.kind=="hold":
				var dolly_at: Vector3 = rig.car.position
				stand(dolly_at + rig.car.global_basis.x*1.55,dolly_at)
				game._action("interact")
				check(rig.phase=="dollies","hold pickup dollies")
			stand(panel+outside,panel)
			game._action("interact")
			check(rig.loaded and game.mode=="haul","lift and sign for tow")
			verify_guide(job.kind)
		check(scene_flare.is_queued_for_deletion() and rig.flame == null and not rig.save_state().has("flare"), "finishing roadside work clears the flare before leaving")
		if i < 2:
			var legacy: Dictionary = rig.save_state()
			legacy["flare"] = rig._v(scene_flare.position)
			rig.restore_state(legacy)
			check(rig.flame == null, "resuming a recovered job ignores a flare from an older save")
		var casualty:Node3D=rig.car
		var handle: Vector3 = rig.truck.to_global(rig.Truck.DOOR)
		stand(handle + outside,handle)
		game._action("interact")
		check(rig.in_cab,"re-enter driving seat")
		check(rig.car==casualty and casualty.is_visible_in_tree(),"same recovery vehicle after entering the cab")
		if rig.loaded:
			for t in (440 if i == 1 else 240):
				rig.set_controls(Vector2(.35,-1),Vector2.ZERO,false,false,DT)
			verify_tow()
			if i == 1 or job.kind == "hold":
				resume_shift()
				verify_guide(job.kind)
				verify_tow()
			stop()
			if job.kind == "hold":
				approach_evidence_bay()
			else:
				park_tow(game.YardDrop.STORAGE.center + Vector3(4,0,0),PI/2)
			game._refresh()
			check("panel" in hint_text(), "parking in the marked bay reveals where to operate the lift")
			game._action("interact")
			panel = rig._panel()
			if job.kind == "hold":
				walk_to(panel-rig.truck.global_basis.x)
				face(panel)
			else:
				stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
			check(not rig.loaded and not game.county.drop_guide.visible, "unhooking at the panel clears the landing guide")
		else:
			if i==0:
				verify_departure()
			# Park outside the truck's yard arrival radius on the second ditch call.
			rig.set_spawn(Vector3(-18,0,-38) if i == 2 else game.SPAWN,-PI/2)
			game._survey()
			game._action("interact")
		check(game.mode == ("return" if i == 2 else "invoice"), "ready to turn in the slip")
		if i < 2:
			resume_shift()
			check("fax" in hint_text(), "turn-in instructions remain available until the office receives the slip")
			check(not game.county.drop_guide.visible, "an unloaded return has no yard marker")
		if job.kind=="hold":
			await secure_evidence_bay()
			walk_to(game.FAX+Vector3(1.5,0,-1.2))
			face(game.FAX)
		else:
			stand(game.FAX+Vector3(0,0,-1.2),game.FAX)
		game._refresh()
		check(game.state.can_fax, "arriving at the actual fax on foot allows filing")
		if i == 1:
			await tap_control("slip")
			await tap_control("send_fax")
		else:
			game._action("interact")
		check(game.completed==i+1 and game.desk.page=="fax","invoice filed")
		game.desk.dismiss()
		if i < 2:
			var invoice_balance: float = game.pending
			game._action("fax")
			resume_shift()
			check(game.mode == "available" and game.completed == i+1 and game.slips.size() == i+1 and is_equal_approx(game.pending, invoice_balance), "a filed slip cannot be charged twice")
			var receipt := str(game.state.get("hint_title","")).to_lower()
			check(str(job.number) in receipt and "filed" in receipt, "the HUD confirms the numbered slip after stowing the fax and resuming")
			check("cab" in str(game.state.get("hint_action","")).to_lower(), "the next-contract directions lead the operator back to the cab")
		if i == 3:
			check("filed" in hint_text(), "the fourth invoice is payable like every other slip")
		if i == 2:
			game._survey()
			var printed := Vector3(409,0,246)
			check(game.county.kolpack_open and game.county.resolve_point(printed).is_equal_approx(printed),"unprinted farm opens while the original Kolpack haul is still measurable")
			var balance: float = game.paid
			game._action("buy_chains")
			game._action("buy_chains")
			check(rig.tire_chains and absf(game.paid-(balance-95.0))<0.01,"yard parts fitted and charged once")
		if i < 4:
			handle = rig.truck.to_global(rig.Truck.DOOR)
			stand(handle-rig.truck.global_basis.x,handle)
			game._action("interact")
		if failures:
			break
	check(game.held and not game.book_read,"hold stored without forcing field book")
	if game.held:
		var latch: Vector3 = game.county.bay_latch_point()
		stand(latch+Vector3(0,0,.8),latch)
		game._action("interact")
		check(not game.bay_locked,"locked bay can be opened with operator key")
		stand(game.BAY+Vector3(0,0,-1.3),game.BAY)
		game._action("interact")
		check(game.book_read and game.desk.page == "field","optional field book inspection")
		await tap_control("mark_sketch")
		check(game.desk.page == "map" and game.survey.notes.has("sketch"),"copying Tou’s sketch marks the plat")
		game.desk.dismiss()
		game._save()
		var against_wall: Dictionary = game.saved_data.duplicate(true)
		against_wall.bay_locked = true
		against_wall.rig.truck = [-58.1,0,-45]
		against_wall.rig.heading = 0.0
		against_wall.rig.cab = true
		game._restore(against_wall)
		await physics_frame
		await physics_frame
		game._action("interact")
		check(not game.bay_locked and not rig.in_cab and rig.truck.to_local(rig.foot).x > 1.4, "a rig saved against the bay wall opens the chains and lets the operator exit on the yard side")
		walk_to(Vector3(-55,0,-54))
	check(game.faxes.size()==5,"all five jobs keep their receipts")
	var query_found := false
	for receipt: String in game.faxes:
		if "calibrated" in receipt:
			query_found = str(game.survey.queried_slip) in receipt and "loaded mi" in receipt
	check(query_found, "Doreen references an actual loaded slip and leaves the amount payable")
	if failures == 0:
		await investigate_kolpack()
	if failures == 0:
		print("CHECKS PASSED — generated recoveries, optional Unit 38 case, deferral, custody, Kolpack look-see and paid work afterward")
	quit(1 if failures else 0)

func visit_survey_turnout() -> void:
	rig.set_spawn(Vector3(314,0,-398),0)
	game._action("interact")
	var door: Vector3 = game.county.survey_door_point()
	stand(door+Vector3(0,0,1),door)
	game._action("interact")
	check(game.survey.notes.has("unit") and not game.survey.can_report_unit(),"door lettering alone does not locate the surveyor’s gear")
	var rod: Vector3 = game.county.rod_case_point()
	stand(rod+Vector3(0,0,1),rod)
	game._action("interact")
	stand_at_cab_door(-1)
	game._action("interact")

func investigate_kolpack() -> void:
	stand_at_cab_door(-1)
	game._action("interact")
	check(game._radio_contact().is_empty(), "copying the sketch keeps the next rotation available while records are checked")
	game.campaign.ordinary_since = 6
	press_key(KEY_R)
	await tap_control("ask_farm")
	press_key(KEY_R)
	await tap_control("take_case")
	check(game.job.get("kind") == "looksee" and rig.car == null,"the requested look-see has no recovery on the hook")
	rig.set_spawn(game.county.resolve_point(Vector3(416,0,336)),0)
	game._action("interact")
	for item: String in ["house","vin","cap"]:
		var point: Vector3 = game.county.story_point(item)
		stand(point+Vector3(0,0,1),point)
		game._action("interact")
		check(game.survey.notes.has(item), "copied " + item + " on site")
	resume_shift()
	stand_at_cab_door(-1)
	game._action("interact")
	press_key(KEY_R)
	await tap_control("report_farm")
	check(game.mode == "return" and game.survey.farm_reported,"operator calls in the VIN from the cab")
	rig.set_spawn(game.SPAWN,-PI/2)
	game._action("interact")
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	var filed: Dictionary = game.slips.back()
	check(filed.kind == "looksee" and filed.pay == 38 and filed.loaded == 0 and filed.vin == game.county.KOLPACK_SEDAN.vin, "the address report pays only the call-out and files the observed VIN")
	game.desk.dismiss()
	stand_at_cab_door(-1)
	game._action("interact")
	press_key(KEY_R)
	check(game.mode == "fieldwork" and game.job.kind in ["ditch","hazard"],"dispatch returns to ordinary rotation")

func hint_text() -> String:
	return ("%s %s" % [game.state.get("hint_title",""), game.state.get("hint_action","")]).to_lower()

func verify_guide(kind: String) -> void:
	var evidence := kind == "hold"
	var sign_text := "EVIDENCE HOLD" if evidence else "STORAGE"
	var destination: Vector3 = game.BAY if evidence else game.YardDrop.STORAGE.center
	check(game.county.drop_guide.is_visible_in_tree() and game.county.drop_guide.global_position.is_equal_approx(destination), "lights mark the assigned bay on every tow")
	check(sign_text.to_lower() in hint_text() and sign_text in str(game.state.progress), "HUD and slip name the assigned sign")
	if rig.in_cab:
		press_key(KEY_T)
		check(sign_text in game.subtitle, "repeat radio directions name the same yard sign")

func park_tow(at: Vector3, yaw: float) -> void:
	rig.set_spawn(at,yaw)
	rig.car.position = rig.truck.to_global(Vector3(0,0,8))
	rig._track_underlift()

func approach_evidence_bay() -> void:
	park_tow(game.YardDrop.STORAGE.center, PI/2)
	game._action("interact")
	var panel: Vector3 = rig._panel()
	stand(panel-rig.truck.global_basis.x,panel)
	game._action("interact")
	check(game.mode == "haul" and rig.loaded and "EVIDENCE HOLD" in game._prompt(), "the storage panel redirects the still-loaded survey pickup")
	stand_at_cab_door(-1)
	game._action("interact")
	park_tow(Vector3(-25,0,-46), -PI/2)
	for tick in 600:
		if rig.truck.position.x <= -39.5:
			break
		rig.set_controls(Vector2(0,1),Vector2.ZERO,false,false,DT)
	stop()
	check(rig.at_dropoff() and game.YardDrop.contains(game.BAY,rig.car.position), "reversing through the open entrance puts the pickup between the evidence lights")

func secure_evidence_bay() -> void:
	var latch: Vector3 = game.county.bay_latch_point()
	var yard_side := latch + Vector3(1.1,0,-1.1)
	walk_to(yard_side)
	face(latch)
	game._action("interact")
	check(not game.bay_locked and "wrecker" in hint_text(), "a wrecker tail across the chain prevents locking")
	# An earlier build could save the lock closed around this truck.
	game._save()
	var trapped: Dictionary = game.saved_data.duplicate(true)
	trapped.bay_locked = true
	game._restore(trapped)
	check(game.held and not game.bay_locked and not game.county.bay.locked, "continue opens the chain around a stranded rig and retains custody")
	var door: Vector3 = rig.truck.to_global(rig.Truck.DOOR)
	walk_to(door-rig.truck.global_basis.x*.65)
	face(door+Vector3.UP)
	game._action("interact")
	check(rig.in_cab, "operator can return to the truck after unhooking")
	for tick in 250:
		if rig.truck.position.x > -28:
			break
		rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,DT)
	stop()
	game._action("interact")
	walk_to(latch+Vector3(2.2,0,1.3))
	walk_to(latch+Vector3(-1.1,0,1.3))
	face(latch)
	game._action("interact")
	check(not game.bay_locked and "outside" in game.subtitle, "the operator cannot close the chains from inside")
	game._save()
	trapped = game.saved_data.duplicate(true)
	trapped.bay_locked = true
	game._restore(trapped)
	check(not game.bay_locked, "continue also frees an operator trapped on foot")
	walk_to(latch+Vector3(-1.1,0,-1.1))
	walk_to(yard_side)
	face(latch)
	game._action("interact")
	check(game.bay_locked and game.county.bay.locked, "the yard-side latch secures the pickup after the wrecker is clear")
	resume_shift()
	await physics_frame
	await physics_frame
	check(game.bay_locked and not game.county.bay.stops[0].disabled and not game.county.bay.stops[1].disabled, "a safely locked bay stays closed after continuing")
	walk_to(latch+Vector3(3,0,-1.1))
	walk_to(latch+Vector3(3,0,4.5))

func walk_to(point: Vector3) -> void:
	for tick in 500:
		var offset := Vector3(point.x-rig.foot.x,0,point.z-rig.foot.z)
		if offset.length() < .16:
			return
		var local := offset.rotated(Vector3.UP,-rig.camera_yaw).normalized()
		rig.set_controls(Vector2(local.x,local.z),Vector2.ZERO,false,false,DT)
	check(false,"blocked walking from %s toward %s" % [rig.foot,point])

func face(point: Vector3) -> void:
	var direction: Vector3 = point-rig.foot
	rig.camera_yaw = atan2(-direction.x,-direction.z)
	rig.camera_pitch = -.20
	rig._update_eyes()

func resume_shift() -> void:
	game._save()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	var touch_mode: bool = game.desk.is_touch_mode()
	game.free()
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.desk._touch_mode = touch_mode
	game.saved_data = snapshot
	game._action("play")
	rig = game.rig

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)

func tap_control(id: String) -> void:
	await process_frame
	await process_frame
	for entry in game.desk.surface.hit_boxes:
		if entry.id == id:
			var event := InputEventScreenTouch.new()
			event.position = entry.rect.get_center() * game.desk.surface.unit
			for pressed: bool in [true, false]:
				event.pressed = pressed
				root.push_input(event, true)
			return
	check(false, "missing touch control " + id)

func drive_to(point: Vector3) -> void:
	for tick in 2800:
		var offset: Vector3 = point-rig.truck.position
		if Vector2(offset.x,offset.z).length() < 3.6:
			return
		var desired := atan2(-offset.x,-offset.z)
		var error := wrapf(desired-float(rig.heading),-PI,PI)
		var speed_target := 6.0 if absf(error)>0.18 or offset.length()<14 else 14.0
		rig.set_controls(Vector2(clampf(-error*2.65,-1,1),-1.0 if rig.speed<speed_target else 0.0),
			Vector2.ZERO,false,rig.speed>speed_target+0.4,DT)
	check(false,"unable to reach %s from %s" % [point,rig.truck.position])

func stop() -> void:
	for t in 140:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,DT)

func stand(position: Vector3, face: Vector3) -> void:
	rig.foot = Vector3(position.x,game.county.ground_height(position.x,position.z),position.z)
	var direction: Vector3 = face-rig.foot
	rig.camera_yaw = atan2(-direction.x,-direction.z)
	rig.camera_pitch = -.20
	rig._update_eyes()

func stand_at_cab_door(side: float) -> void:
	var door: Vector3 = rig.Truck.DOOR
	door.x = side * absf(door.x)
	var handle: Vector3 = rig.body.to_global(door + Vector3.UP*1.4)
	stand(handle + rig.truck.global_basis.x*side, handle)

func verify_tow() -> void:
	var wheelbase:float=(2.5 if rig.kind=="hold" else 2.12)*.61
	var radius:=.43 if rig.kind=="hold" else .355
	var supported:Vector3=rig.car.to_global(Vector3(0,radius,rig.line_end*wheelbase))
	var rolling:Vector3=rig.car.to_global(Vector3(0,radius,-rig.line_end*wheelbase))
	check(supported.distance_to(rig._hitch()+Vector3.UP*.15)<.035,"strapped axle stays in the underlift")
	check(absf(rolling.y-rig._ground(rolling)-radius)<.20,"the free tires stay on the ground")
	check(rig.truck.to_local(rolling).z>5.5 and rig.car.is_visible_in_tree(),"the free axle trails behind the wrecker")
	check(rig.eyes.is_position_in_frustum(rig.car.position+Vector3.UP),"the chase camera includes the attached vehicle")

func verify_departure() -> void:
	var original:Vector3=rig.car.position
	var driver:Vector3=rig.witness.position
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.witness.position.distance_to(driver)>0.0 and rig.car.position.is_equal_approx(original),"the driver walks back before the ditch car moves")
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(rig.save_state()))
	driver=rig.witness.position
	rig.restore_state(snapshot)
	check(rig.witness.position.is_equal_approx(driver),"continue preserves the driver's walk back to the car")
	for i in 1800:
		# Watch the merge, then follow beyond the old despawn timer.
		if i==720:
			check(rig.car.position.distance_to(original)>12.0,"ditch driver merges past the parked wrecker")
		if i>=720:
			rig.truck.position=rig.car.position+Vector3(8,0,8)
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(not rig.witness.visible and rig.car.position.distance_to(original)>80.0,"the boarded driver takes the car away down the road")
	check(rig.car.is_visible_in_tree(),"a nearby customer never vanishes on a timer")
	rig.restore_state(JSON.parse_string(JSON.stringify(rig.save_state())))
	check(not rig.witness.visible and rig.car.is_visible_in_tree(),"continue preserves a visible departing car after the driver boards")
	rig.set_spawn(original)
	rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,DT)
	check(rig.phase=="done" and not rig.car.visible,"the departing car clears the scene beyond the storm horizon")
