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
		else:
			press_key(KEY_R)
		check(game.mode == "fieldwork","accepted radio call")
		check(not game.county.storage_guide.visible, "the storage guide stays off until a vehicle is on the lift")
		var job: Dictionary = game.job
		var site: Vector3 = rig.car.position
		if i == 0:
			drive_to(Vector3(-7,0,-64))
			drive_to(Vector3(0,0,-54))
			drive_to(Vector3(0,0,130))
			drive_to(Vector3(-2,0,150))
			stop()
			check(game._prompt().is_empty(),"stopping at the scene leaves the cab view clear")
			check(rig.odo-game.dispatch_odo > 0.48,"actual drive from yard to Angie counted empty miles")
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
			check(game.county.storage_guide.visible == (i == 1), "only the first storage delivery lights the pad")
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
			for t in 240:
				rig.set_controls(Vector2(.35,-1),Vector2.ZERO,false,false,DT)
			verify_tow()
			if i==1:
				resume_shift()
				check(game.mode == "haul" and game.county.storage_guide.visible, "resuming a loaded first tow restores its landing guide")
				verify_tow()
			stop()
			rig.set_spawn(rig.storage_point + Vector3(4,0,0),PI/2)
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,DT)
			if i == 1:
				game._refresh()
				check("panel" in hint_text(), "parking in the marked bay reveals where to operate the lift")
			game._action("interact")
			panel = rig._panel()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
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
			check(not game.county.storage_guide.visible, "the storage guide is off once the lift is lowered")
		if job.kind=="hold":
			var latch: Vector3 = game.county.bay_latch_point()
			stand(latch+Vector3(0,0,.7),latch)
			game._action("interact")
			check(game.bay_locked,"locked evidence chain")
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
			check("disput" in hint_text(), "the county's disputed invoice is identified on the HUD")
		if i == 2:
			game._survey()
			var printed := Vector3(409,0,246)
			check(is_equal_approx(game.county.resolve_point(printed).z-printed.z,40.0),"offscreen section adds one odometer tenth")
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
	check(game.faxes.size()==5 and "0.4" in str(game.faxes[3]) if game.faxes.size()>3 else false,"dispute archived")
	if failures == 0:
		print("CHECKS PASSED — drove County K, five complete recoveries, resume, custody and optional field book")
	quit(1 if failures else 0)

func hint_text() -> String:
	return ("%s %s" % [game.state.get("hint_title",""), game.state.get("hint_action","")]).to_lower()

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
