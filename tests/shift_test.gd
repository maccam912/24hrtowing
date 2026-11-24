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
	game._action("play")
	for i in 5:
		game._action("radio")
		check(game.mode == "fieldwork","accepted radio call")
		var job: Dictionary = game.job
		var site: Vector3 = rig.car.position
		if i == 0:
			drive_to(Vector3(-7,0,-64))
			drive_to(Vector3(0,0,-54))
			drive_to(Vector3(0,0,130))
			drive_to(Vector3(-2,0,150))
			stop()
			check(rig.odo-game.dispatch_odo > 0.48,"actual drive from yard to Angie counted empty miles")
		else:
			rig.set_spawn(Vector3(site.x+2,0,site.z-13),0)
		game._action("interact")
		check(not rig.in_cab,"driver left cab at scene")
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
		check(rig.phase=="flared","flare at scene "+str(i))
		var panel: Vector3 = rig._panel()
		var outside: Vector3 = rig.truck.global_basis.x*-1.1
		stand(panel+outside,panel)
		game._action("interact")
		check(rig.phase == "cable","chock and take line")
		var eye: Vector3 = rig._eyelet(-1)
		stand(eye-rig.car.global_basis.z*.9,eye)
		game._action("interact")
		check(rig.phase=="rigged","attached cable")
		if i == 1:
			game._save()
			var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
			game._restore(snapshot)
			check(rig.phase=="rigged" and not rig.in_cab,"resume with attached cable and unchanged view")
		stand(panel+outside,panel)
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
		var handle: Vector3 = rig.truck.to_global(rig.Truck.DOOR)
		stand(handle + outside,handle)
		game._action("interact")
		check(rig.in_cab,"re-enter driving seat")
		if rig.loaded:
			for t in 240:
				rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,DT)
			stop()
			rig.set_spawn(rig.storage_point + Vector3(4,0,0),PI/2)
			rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,DT)
			game._action("interact")
			panel = rig._panel()
			stand(panel-rig.truck.global_basis.x,panel)
			game._action("interact")
		else:
			rig.set_spawn(game.SPAWN,-PI/2)
			game._survey()
			game._action("interact")
		check(game.mode=="invoice","returned for invoice")
		if job.kind=="hold":
			var latch: Vector3 = game.county.bay_latch_point()
			stand(latch+Vector3(0,0,.7),latch)
			game._action("interact")
			check(game.bay_locked,"locked evidence chain")
		stand(game.FAX+Vector3(0,0,-1.2),game.FAX)
		game._action("interact")
		check(game.completed==i+1 and game.desk.page=="fax","invoice filed")
		game.desk.dismiss()
		if i == 2:
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
