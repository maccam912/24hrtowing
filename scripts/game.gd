extends Node

const County := preload("res://scripts/county.gd")
const Rig := preload("res://scripts/rig.gd")
const Desk := preload("res://scripts/desk.gd")
const Audio := preload("res://scripts/radio_audio.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
const Ledger := preload("res://scripts/ledger.gd")

const SPAWN := Vector3(-27,0,-64)
const STORAGE := Vector3(-44,0,-77)
const BAY := Vector3(-48,0,-47)
const FAX := Vector3(-40,0,-39)
const PUMP := Vector3(-71,0,18)
const PARKING := [Vector3(-56,0,-80),Vector3(-49,0,-80),Vector3(-35,0,-80),Vector3(-27,0,-80),Vector3(-19,0,-80)]

var county
var rig
var desk
var audio
var world_view := SubViewport.new()
var picture := TextureRect.new()
var world := Node3D.new()
var active := false
var mode := "available"
var job := {}
var completed := 0
var slips := []
var calls := []
var roads_driven := []
var stored := []
var faxes := []
var filed_card := ""
var physical_cars := []
var held := false
var bay_locked := false
var book_read := false
var signed_card := false
var packed_tripod := false
var talked := false
var talked_twice := false
var shift_seconds := 0.0
var dispatch_odo := 0.0
var pickup_odo := 0.0
var drop_odo := 0.0
var pickup_time := ""
var drop_time := ""
var paid := 0.0
var pending := 0.0
var seconds_worked := 0.0
var fax_text := "TAMARACK COUNTY HIGHWAY DEPARTMENT\nTOW BAN IN EFFECT UNTIL FURTHER NOTICE.\nSheriff-requested removals only. Record both odometer readings."
var subtitle := ""
var speaker := ""
var sub_time := 0.0
var mouse_motion := Vector2.ZERO
var save_timer := 0.0
var ui_timer := 0.0
var direction_timer := 0.0
var plow_heard := false
var saved_data := {}
var state := {}
var test_session := false
var shutting_down := false

func _ready() -> void:
	test_session = "--test-mode" in OS.get_cmdline_user_args()
	world_view.name = "Storm"
	world_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	world_view.own_world_3d = true
	world_view.audio_listener_enable_3d = true
	add_child(world_view)
	world_view.add_child(world)
	county = County.new()
	world.add_child(county)
	rig = Rig.new()
	world.add_child(rig)
	rig.setup(county)
	rig.set_spawn(SPAWN,-PI/2)
	rig.storage_point = STORAGE
	rig.recovered.connect(_recovered)
	rig.dropped.connect(_dropped)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = world_view.get_texture()
	var film := ShaderMaterial.new()
	film.shader = preload("res://assets/weather/film.gdshader")
	picture.material = film
	add_child(picture)
	get_viewport().size_changed.connect(_resize)
	_resize()
	audio = Audio.new()
	add_child(audio)
	rig.sound_event.connect(audio.effect)
	saved_data = {} if test_session else Ledger.read()
	desk = Desk.new()
	add_child(desk)
	desk.action.connect(_action)
	Engine.max_fps = int(saved_data.get("fps",30))
	desk.fps = Engine.max_fps
	_refresh()
	print("24 HR Towing | dispatch ready")

func _resize() -> void:
	var bounds := get_viewport().get_visible_rect().size
	world_view.size = Vector2i(roundi(640.0 * maxf(1.0, bounds.aspect()/(4.0/3.0))),448)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and desk:
		desk.toggle_pause()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		_save()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			shutting_down = true
			get_tree().quit()

func _physics_process(dt: float) -> void:
	if not rig or not desk or shutting_down:
		return
	var playing: bool = active and not desk.is_blocking()
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if playing else SubViewport.UPDATE_DISABLED
	if playing:
		var move: Vector2 = desk.get_move()
		move.x += _axis(KEY_A,KEY_D) + _axis(KEY_LEFT,KEY_RIGHT)
		move.y += _axis(KEY_W,KEY_S) + _axis(KEY_UP,KEY_DOWN)
		var look: Vector2 = mouse_motion*0.0023 + desk.take_look()*0.0039
		var working: bool = desk.work_held() or Input.is_physical_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_SPACE)
		var brake: bool = desk.brake_held() or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SPACE)
		rig.set_controls(move.clamp(Vector2(-1,-1),Vector2.ONE),look,working,brake,dt)
		shift_seconds += dt
		if rig.get_status().get("working",false):
			seconds_worked += dt
		save_timer += dt
		if save_timer > 7:
			_save()
		direction_timer += dt
		if direction_timer > 0.9:
			direction_timer = 0.0
			_survey()
	mouse_motion = Vector2.ZERO
	county.follow_camera(world_view.get_camera_3d().global_position)
	if active and desk.page != "pause":
		sub_time = maxf(0.0,sub_time-dt)
	ui_timer += dt
	if ui_timer >= 0.10:
		ui_timer = 0.0
		_refresh()
	audio.mix_truck(rig.get_status(),active,dt)
	if not desk.is_touch_mode() and DisplayServer.get_name() != "headless":
		var capture := Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != capture:
			Input.mouse_mode = capture

func _axis(negative: Key, positive: Key) -> int:
	return int(Input.is_physical_key_pressed(positive)) - int(Input.is_physical_key_pressed(negative))

func _input(event: InputEvent) -> void:
	if not desk:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_motion += event.relative
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		desk.toggle_pause()
		return
	if not active:
		return
	if event.keycode == KEY_M and desk.page in ["","map"]:
		desk.show_document("map", state)
	elif event.keycode in [KEY_J,KEY_TAB] and desk.page in ["","slip"]:
		desk.show_document("slip",state)
	elif not desk.is_blocking():
		match event.physical_keycode:
			KEY_E: _action("interact")
			KEY_C: _action("camera")
			KEY_R: _action("radio")
			KEY_T: _action("talk_in")
			KEY_H: desk.show_document("help",state)

func _action(id: String) -> void:
	match id:
		"play":
			if not active:
				active = true
				if not saved_data.is_empty():
					_restore(saved_data)
				else:
					_say("hail")
			desk.start_play()
		"radio":
			if rig.get_status().in_cab:
				if mode == "available":
					_accept()
				else:
					_directions()
			else:
				_message("BRANDT","The county radio is in the cab.")
		"talk_in":
			if rig.get_status().in_cab:
				_directions()
			else:
				_message("BRANDT","Use the radio in the cab.")
		"interact": _interact()
		"camera":
			if active and not desk.is_blocking() and rig.in_cab:
				rig.toggle_driving_view()
				_save()
		"fax": _file_invoice()
		"read_field":
			if held and (book_read or _near(BAY,5.0)):
				_read_book()
		"settings_30","settings_60":
			Engine.max_fps = 30 if id == "settings_30" else 60
			_save()
		"buy_chains","service_winch": _order_part(id)
		"quit":
			_save()
			get_tree().quit()
	_refresh()

func _order_part(id: String) -> void:
	if rig.in_cab or not _near(FAX,4.4):
		return
	if id == "buy_chains" and not rig.tire_chains and paid >= 95.0:
		rig.tire_chains = true
		paid -= 95.0
	elif id == "service_winch" and rig.wear > 0.001 and paid >= 24.0:
		rig.wear = 0.0
		paid -= 24.0
	else:
		return
	audio.effect("fax")
	_save()

func _accept() -> void:
	job = Dispatch.ticket(completed,audio.voices)
	mode = "fieldwork"
	dispatch_odo = rig.get_status().odo
	pickup_odo = dispatch_odo
	drop_odo = dispatch_odo
	pickup_time = ""
	drop_time = ""
	talked = false
	talked_twice = false
	seconds_worked = 0.0
	if job.kind == "hold":
		signed_card = false
		packed_tripod = false
	rig.storage_point = BAY if job.kind == "hold" else STORAGE
	rig.start_job(job.kind,county.resolve_point(job.point),job.angle)
	county.set_hold_scene(job.kind == "hold")
	if job.kind == "hold":
		county.set_tripod_collected(false)
	_say(job.id + "_call")
	_save()

func _directions() -> void:
	if mode == "available":
		_accept()
	elif mode in ["haul","return","invoice"]:
		_say("yard_dir")
	else:
		_say(job.route + "_dir")

func _survey() -> void:
	var pos: Vector3 = rig.get_truck_position()
	if completed >= 3 and not county.lengthened and pos.distance_to(SPAWN) < 85:
		county.try_lengthen(pos)
	var street := ""
	var p := Vector2(pos.x,pos.z)
	for road in county.map_roads():
		var vertices: PackedVector2Array = road.points
		for i in range(1,vertices.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(p, vertices[i-1],vertices[i])
			if p.distance_to(nearest) < 7:
				street = str(road.name)
				break
		if street != "":
			break
	if not street.is_empty() and not street in roads_driven:
		roads_driven.append(street)
	if held and not plow_heard and sub_time == 0 and pos.distance_to(SPAWN) > 110 and rig.get_status().in_cab:
		plow_heard = true
		_say("plow")
	if float(rig.get_status().get("fuel",1.0)) <= 0.0002:
		rig.service_fuel()
		shift_seconds += 18*60
		_say("can")
	if mode == "return" and pos.distance_to(SPAWN) < 27:
		mode = "invoice"
		_save()

func _near(point: Vector3, radius: float) -> bool:
	var diff: Vector3 = rig.get_player_position()-point
	return Vector2(diff.x,diff.z).length() < radius

func _facing(point: Vector3, radius: float) -> bool:
	if not _near(point,radius):
		return false
	var cam := world_view.get_camera_3d()
	if not cam:
		return true
	var d := Vector2(point.x-cam.global_position.x,point.z-cam.global_position.z)
	var axis := -cam.global_basis.z
	return d.length() < 1.45 or d.normalized().dot(Vector2(axis.x,axis.z).normalized()) > 0.30

func _site_action() -> String:
	if rig.get_status().in_cab:
		return ""
	if mode == "fieldwork" and job.get("kind") == "hold":
		if not packed_tripod and _facing(county.hold_tripod_point(),3.9):
			return "tripod"
		if _facing(rig.get_witness_position(),4.3):
			return "sign" if not signed_card else "deputy"
	elif mode == "fieldwork" and job.get("kind") == "ditch" and not talked and _facing(rig.get_witness_position(),3.9):
		return "driver"
	if _facing(FAX,4.4):
		return "fax"
	if held and _facing(county.bay_latch_point(),2.7):
		return "unlock" if bay_locked else "lock"
	if held and not bay_locked and _facing(BAY,4.8):
		return "field"
	if _facing(PUMP,6):
		return "fuel"
	return ""

func _interact() -> void:
	match _site_action():
		"tripod":
			packed_tripod = true
			county.set_tripod_collected(true)
			audio.effect("ratchet")
			_message("BRANDT","Tripod stowed. The instrument was still mounted.")
		"sign":
			signed_card = true
			pickup_time = _clock()
			pickup_odo = rig.get_status().odo
			_say("deputy")
			_refresh()
			desk.show_document("custody",state)
		"deputy":
			talked_twice = true
			_say("light")
		"driver":
			talked = true
			_say(job.reply)
		"fax":
			if mode == "invoice":
				_file_invoice()
			else:
				desk.show_document("fax",state)
		"lock","unlock":
			bay_locked = not bay_locked
			county.set_bay_locked(bay_locked)
			audio.effect("ratchet")
			_message("BRANDT","Bay secured. Key back on the ring." if bay_locked else "Hold bay open.")
		"field": _read_book()
		"fuel":
			rig.service_fuel()
			_message("BRANDT","Diesel topped up. Mai put a fresh pot on.")
		_:
			if mode == "fieldwork" and job.kind == "hold" and rig.action_id() == "flare" and (not signed_card or not packed_tripod):
				_message("KOWALSKI","Sign my custody card and take the survey tripod before we move this truck.")
				return
			rig.interact()
	_save()

func _recovered(kind: String) -> void:
	if mode != "fieldwork":
		return
	if kind != "hold" or pickup_time.is_empty():
		pickup_odo = rig.get_status().odo
		pickup_time = _clock()
	mode = "return" if kind == "ditch" else "haul"
	if kind == "ditch":
		drop_odo = pickup_odo
		drop_time = pickup_time
		_say(job.reply)
	else:
		_say("clear")
	_refresh()
	_save()

func _dropped() -> void:
	if mode != "haul":
		return
	drop_odo = rig.get_status().odo
	drop_time = _clock()
	mode = "invoice"
	if job.kind == "hold":
		held = true
		filed_card = _custody_record()
		county.set_hold_scene(false)
	else:
		stored.append(job.route)
	rig.end_job()
	_display_storage()
	_message("BRANDT","Set down and secured. The office fax is by the yard door.")
	_save()

func _display_storage() -> void:
	for node in physical_cars:
		if is_instance_valid(node):
			node.queue_free()
	physical_cars.clear()
	if held:
		var car = rig.store_vehicle("hold",BAY,PI/2)
		if car is Node3D:
			physical_cars.append(car)
	for i in mini(stored.size(),PARKING.size()):
		var car = rig.store_vehicle(stored[i],PARKING[i],0)
		if car is Node3D:
			physical_cars.append(car)

func _read_book() -> void:
	book_read = true
	_refresh()
	desk.show_document("field",state)
	_save()

func _file_invoice() -> void:
	if mode != "invoice" or rig.get_status().in_cab or not _near(FAX,4.4):
		return
	if job.kind == "hold" and not bay_locked:
		_message("BRANDT","The hold bay needs locking before I file the custody card.")
		return
	var slip := Dispatch.issue_slip(job,dispatch_odo,pickup_odo,drop_odo,seconds_worked,_clock())
	slips.append(slip)
	pending += slip.pay
	completed += 1
	fax_text = "TO  BRANDT TOWING & RECOVERY\nRE  TOW SLIP %04d\n\nReceived for county review.\nCall-out  $38    Hookup  $16\nWinch  $%d    Storage  $%d\nLoaded  %.1f mi @ $3.25\nNet invoice  $%.2f\n\nD. Pfaff  /  Accounts Payable" % [slip.number,slip.winch,slip.storage,slip.loaded,slip.pay]
	if completed % 3 == 0:
		paid += pending
		fax_text += "\n\nBATCH PAYMENT ISSUED   $%.2f" % pending
		pending = 0
		stored.clear()
		_display_storage()
	if slip.number == 1004:
		fax_text = "RETURN TO OPERATOR   /   INV. 1004\n\nThe loaded mileage from the Hwy 64 bridge exceeds our schedule by 0.4 mi.\n\nPlease correct and resubmit.\n\nDoreen Pfaff\nTamarack Co. Accounts Payable"
		_say("clerk")
	else:
		_message("DISPATCH","Standing by, Brandt. Call when you're ready.")
	faxes.append(fax_text)
	audio.effect("fax")
	rig.end_job()
	job = {}
	mode = "available"
	_refresh()
	desk.show_document("fax",state)
	_save()

func _say(id: String) -> void:
	var line: Array = audio.voices[id]
	speaker = line[0]
	subtitle = line[1]
	sub_time = maxf(4.0, audio.say(id) + 0.55)
	if speaker in ["DISPATCH","COUNTY PLOW"]:
		calls.append(speaker + "   " + subtitle)
		if calls.size() > 3:
			calls.pop_front()

func _message(who: String, words: String) -> void:
	speaker = who
	subtitle = words
	sub_time = clampf(2+words.length()/17.0,4,9)

func _clock() -> String:
	var minutes := 3*60+14+floori(shift_seconds/60.0)
	return "%02d:%02d" % [floori(minutes/60.0)%24,minutes%60]

func _procedure() -> String:
	match mode:
		"available": return "County dispatch is standing by. Answer on the cab radio."
		"fieldwork":
			if job.kind == "hold" and (not signed_card or not packed_tripod):
				return "Meet Deputy Kowalski, sign the custody card and collect the tripod."
			return rig.get_status().get("hint","Drive to the scene. Ask dispatch for a landmark if needed.")
		"haul": return "Deliver to the locked hold bay." if job.kind == "hold" else "Haul to the open storage pad in the Brandt yard."
		"return": return "The driver is clear. Return to the yard to file your slip."
		"invoice":
			if job.get("kind") == "hold" and not bay_locked:
				return "Lock the chain at the hold bay entrance before filing the custody card."
			return "Walk to the office fax at the yard door. File the tow slip."
	return ""

func _prompt() -> String:
	var site := _site_action()
	var words := {"lock":"Lock the evidence bay","unlock":"Unlock the evidence bay","tripod":"Collect the survey tripod","sign":"Sign Kowalski’s custody card","deputy":"Ask about the light","driver":"Speak to the driver","field":"Open the pickup · field book","fuel":"Fill the diesel tank","fax":"File tow slip at fax" if mode=="invoice" else "Read the county fax"}
	if words.has(site):
		return words[site]
	if mode == "available" and rig.in_cab and absf(rig.speed)<0.65:
		return "[RADIO]  Answer dispatch" if desk.is_touch_mode() else "[R]  Answer dispatch"
	return rig.context_text()

func _custody_record() -> String:
	return "TC-96-031  /  Survey Unit 38\nPickup  %s   ODO %.1f\nReceived by J. Kowalski / Brandt\nInstrument and tripod  %s\nHold bay  %s" % [pickup_time,pickup_odo,"in custody" if packed_tripod else "at scene",("%s   ODO %.1f" % [drop_time,drop_odo]) if held else "awaiting transfer"]

func _refresh() -> void:
	var s: Dictionary = rig.get_status()
	var ticket := job.duplicate()
	if not job.is_empty() and (not pickup_time.is_empty() or mode in ["haul","return","invoice"]):
		ticket.pickup_odo = pickup_odo
		if mode == "invoice" or mode == "return":
			ticket.drop_odo = drop_odo
			ticket.loaded = 0.0 if job.kind == "ditch" else snappedf(maxf(0,drop_odo-pickup_odo),0.1)
	var bearing := posmod(roundi(float(s.heading)/45.0),8)
	var card := filed_card if held else (_custody_record() if signed_card else "")
	state = {"prompt":_prompt(),"subtitle":subtitle if sub_time>0 else "","speaker":speaker,
		"has_save":not saved_data.is_empty(),"in_cab":s.in_cab,"speed_mph":s.speed_mph,
		"driving_view":rig.driving_view,
		"can_enter_cab":rig.action_id() == "enter" and _site_action().is_empty(),
		"miles":s.odo,"trip":float(s.odo)-dispatch_odo if not job.is_empty() else 0.0,
		"fuel":s.fuel,"tension":s.tension,"heading":["N","NE","E","SE","S","SW","W","NW"][bearing],
		"job":ticket,"slips":slips,"calls":calls,"can_radio":s.in_cab,"night_time":_clock(),
		"faxes":faxes,"fax_text":fax_text,"field_available":book_read,"custody_text":card,"can_fax":mode=="invoice" and not s.in_cab and _near(FAX,4.4),
		"roads":county.map_roads(),"places":county.map_places(),"road_names":roads_driven,
		"can_order":not s.in_cab and _near(FAX,4.4),"chains":rig.tire_chains,"wear":s.wear,
		"progress":_procedure(),"paid":paid,"pending":pending,"phase":s.phase,"work_available":rig.action_id()=="winch",
		"warmth":s.warmth,"mode":mode,"rig_hint":s.get("hint","")}
	desk.update_view(state)

func _save() -> void:
	if not active or not rig:
		return
	save_timer = 0
	saved_data = {"completed":completed,"mode":mode,"rig":rig.save_state(),"slips":slips,
		"calls":calls,"roads":roads_driven,"stored":stored,"bay_locked":bay_locked,"held":held,"book_read":book_read,
		"signed":signed_card,"tripod":packed_tripod,"talked":talked,"asked":talked_twice,
		"seconds":shift_seconds,"start":dispatch_odo,"pickup":pickup_odo,"drop":drop_odo,
		"pickup_time":pickup_time,"drop_time":drop_time,"paid":paid,"pending":pending,"work":seconds_worked,
		"fax":fax_text,"faxes":faxes,"filed_card":filed_card,"longer":county.lengthened,"plow":plow_heard,"fps":Engine.max_fps}
	if not test_session and not Ledger.write(saved_data):
		push_warning("Could not save current tow ticket")

func _restore(s: Dictionary) -> void:
	completed = int(s.completed)
	mode = s.mode
	slips = s.slips
	calls = s.calls
	roads_driven = s.roads
	stored = s.stored
	held = s.held
	bay_locked = s.get("bay_locked",held)
	county.set_bay_locked(bay_locked)
	book_read = s.book_read
	signed_card = s.signed
	packed_tripod = s.tripod
	talked = s.talked
	talked_twice = s.asked
	shift_seconds = s.seconds
	dispatch_odo = s.start
	pickup_odo = s.pickup
	drop_odo = s.drop
	pickup_time = s.pickup_time
	drop_time = s.drop_time
	paid = s.paid
	pending = s.pending
	seconds_worked = s.work
	fax_text = s.fax
	faxes = s.get("faxes",[])
	filed_card = s.get("filed_card","")
	plow_heard = s.plow
	county.set_lengthened(s.longer)
	if mode != "available":
		job = Dispatch.ticket(completed,audio.voices)
		rig.storage_point = BAY if job.kind == "hold" else STORAGE
		county.set_hold_scene(job.kind=="hold" and mode=="fieldwork")
		county.set_tripod_collected(packed_tripod)
	rig.restore_state(s.rig)
	_display_storage()
