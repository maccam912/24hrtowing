extends Node

const County := preload("res://scripts/county.gd")
const Rig := preload("res://scripts/rig.gd")
const Desk := preload("res://scripts/desk.gd")
const Audio := preload("res://scripts/radio_audio.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
const Ledger := preload("res://scripts/ledger.gd")
const ShopAccount := preload("res://scripts/shop_account.gd")
const Campaign := preload("res://scripts/county_case.gd")
const Casework := preload("res://scripts/casework.gd")
const SurveyCase := preload("res://scripts/survey_case.gd")
const YardDrop := preload("res://scripts/yard_drop.gd")
const RoadDirections := preload("res://scripts/road_directions.gd")

const WORLD_RASTER_HEIGHT := 288
const SPAWN := Vector3(-27,0,-64)
const TITLE_CAMERA_OFFSET := Vector3(-10.5,2.65,-7.0)
const BAY: Vector3 = YardDrop.EVIDENCE.center
const FAX := Vector3(-40,0,-39)
const PUMP := Vector3(-71,0,18)
const PUMP_ISLANDS := [PUMP + Vector3(-3.7,0,-2), PUMP + Vector3(3.7,0,-2)]
const PARKING := [Vector3(-56,0,-80),Vector3(-49,0,-80),Vector3(-35,0,-80),Vector3(-27,0,-80),Vector3(-19,0,-80)]

var county
var rig
var desk
var audio
var world_view := SubViewport.new()
var title_camera := Camera3D.new()
var title_light := SpotLight3D.new()
var title_offset := TITLE_CAMERA_OFFSET
var title_time := 0.0
var picture := TextureRect.new()
var world := Node3D.new()
var active := false
var mode := "available"
var job := {}
var rotation_offer := {}
var waiting_hazard: Node3D
var case_offer := {}
var dispatch_seed := randi()
var survey := SurveyCase.new()
var campaign := Campaign.new()
@onready var casework := Casework.new(self,campaign)
var sightings := preload("res://scripts/sighting_director.gd").new()
var mai_lot_heard := false
var completed := 0
var slips := []
var pending_slips := []
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
var account := ShopAccount.new()
var shop_receipt := ""
var seconds_worked := 0.0
var fax_text := "TAMARACK COUNTY HIGHWAY DEPARTMENT\nTOW BAN IN EFFECT UNTIL FURTHER NOTICE.\nSheriff-requested removals only. Record both odometer readings."
var subtitle := ""
var speaker := ""
var sub_time := 0.0
var mouse_motion := Vector2.ZERO
var save_timer := 0.0
var ui_timer := 0.0
var direction_timer := 0.0
var road_directions := RoadDirections.new()
var plow_heard := false
var saved_data := {}
var state := {}
var test_session := false
var shutting_down := false

func _ready() -> void:
	test_session = "--test-mode" in OS.get_cmdline_user_args()
	world_view.name = "Storm"
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	_stage_title()
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
	audio.set_spoken(saved_data.get("spoken",false))
	_refresh()
	print("24 HR Towing | dispatch ready")

func _stage_title() -> void:
	rig.truck.add_child(title_camera)
	title_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_frame_truck(TITLE_CAMERA_OFFSET)
	rig.truck.add_child(title_light)
	title_light.global_position = rig.truck.to_global(Vector3(-5.1,7.2,-4.6))
	title_light.look_at(rig.truck.to_global(Vector3(0,1.2,0)),Vector3.UP)
	title_light.light_color = Color("#ffd6a3")
	title_light.light_energy = 3.0
	title_light.spot_range = 23.0
	title_light.spot_angle = 54.0
	title_light.shadow_enabled = true
	title_camera.make_current()

func _frame_truck(offset: Vector3, field_of_view := 73.0) -> void:
	title_camera.fov = field_of_view
	title_camera.position = offset
	title_camera.look_at(rig.truck.to_global(Vector3(0,1.62,0)),Vector3.UP)
	title_camera.translate_object_local(Vector3(-4.35,0,0))

func _frame_parked_truck() -> void:
	if not title_camera.current:
		return
	title_time = 0.0
	var focus: Vector3 = rig.truck.to_global(Vector3(0,1.62,0))
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	for angle: float in [0.0, PI * 0.5, -PI * 0.5, PI]:
		title_offset = TITLE_CAMERA_OFFSET.rotated(Vector3.UP,angle)
		_frame_truck(title_offset,73.0 if angle == 0.0 else 78.0)
		var sightline := PhysicsRayQueryParameters3D.create(focus,title_camera.global_position,1)
		if space.intersect_ray(sightline).is_empty():
			return
	title_offset = Vector3(-5.0,11.0,-4.0)
	_frame_truck(title_offset)

func _animate_title(dt: float) -> void:
	title_time += dt
	var angle := 0.29 * sin(title_time * 0.19)
	var previous := title_camera.transform
	_frame_truck(title_offset.rotated(Vector3.UP,angle),title_camera.fov)
	# A resumed truck can be parked next to a wall or inside the hold bay.
	if active:
		var focus: Vector3 = rig.truck.to_global(Vector3(0,1.62,0))
		var ray := PhysicsRayQueryParameters3D.create(focus,title_camera.global_position,1)
		if not title_camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			title_camera.transform = previous
	rig.body.animate_weather(dt,true)

func _resize() -> void:
	var bounds := get_viewport().get_visible_rect().size
	if bounds.y > 0:
		world_view.size = Vector2i(maxi(2, roundi(WORLD_RASTER_HEIGHT * bounds.aspect())), WORLD_RASTER_HEIGHT)

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
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if playing or desk.is_title() else SubViewport.UPDATE_DISABLED
	if playing:
		sightings.advance(dt,self)
		casework.advance_departure(dt)
	if playing or desk.is_title():
		county.advance_storm(dt)
	if desk.is_title():
		_animate_title(dt)
	if playing:
		var move: Vector2 = desk.get_move()
		move.x += _axis(KEY_A,KEY_D) + _axis(KEY_LEFT,KEY_RIGHT)
		move.y += _axis(KEY_W,KEY_S) + _axis(KEY_UP,KEY_DOWN)
		var look: Vector2 = mouse_motion*0.0023 + desk.take_look()*0.0039
		var working: bool = desk.work_held() or Input.is_physical_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_SPACE)
		var brake: bool = desk.brake_held() or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SPACE)
		if is_instance_valid(casework.tower_view):
			move = Vector2.ZERO
			look = Vector2.ZERO
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
	if active and not desk.is_title() and desk.page not in ["pause", "guidance"]:
		sub_time = maxf(0.0,sub_time-dt)
	ui_timer += dt
	# A pedal touch between HUD updates must see the latest physics step.
	if ui_timer >= 0.10 or rig.is_stopped() != state.truck_stopped:
		ui_timer = 0.0
		_refresh()
	audio.mix_truck(rig.get_status(),active and not desk.is_title(),playing,dt,county.storm_gust)
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
		"guidance":
			desk.road_note = _road_note()
			desk.show_document("guidance",state)
		"play":
			rig.get_camera().make_current()
			title_light.visible = false
			if not active:
				active = true
				if not saved_data.is_empty():
					_restore(saved_data)
				else:
					sightings.restore({},county)
					_prepare_offers()
					_say("hail")
					_save()
			desk.start_play()
		"title":
			casework.leave_tower()
			_save()
			title_camera.make_current()
			title_light.visible = true
			get_tree().physics_frame.connect(_frame_parked_truck,CONNECT_ONE_SHOT)
		"radio":
			if rig.get_status().in_cab:
				if _needs_fuel_can() or sightings.can_report() or not _radio_contact().is_empty() or (mode == "available" and _case_due()):
					desk.show_document("radio",state)
				elif mode == "available":
					_take_rotation()
				else:
					_directions()
			else:
				_message("BRANDT","The county radio is in the cab.")
		"rotation": _take_rotation()
		"report_unit","take_case","ask_farm","report_farm":
			_radio_case(id)
		"take_detail","report_detail","talk_tou":
			if _radio_contact().get("id") == id:
				match id:
					"take_detail": _accept(campaign.ticket(1001 + completed + pending_slips.size()))
					"report_detail":
						_record_visit()
						_speak("DISPATCH",job.report)
						_clear_field_job()
						_prepare_offers()
						_save()
					"talk_tou": desk.show_document("passenger",state)
		"tou_0","tou_1","tou_2","tou_3","tou_4","tou_5","tou_6","tou_7":
			if _radio_contact().get("id") == "talk_tou":
				var choice := int(id.right(1))
				if choice not in campaign.asked:
					campaign.asked.append(choice)
				_speak("TOU",Campaign.QUESTIONS[choice][1])
				_save()
		"mark_sketch":
			if book_read and desk.page == "field":
				survey.record("sketch",rig.odo)
				desk.show_document("map",state)
				_save()
		"report_sighting":
			if rig.in_cab and sightings.can_report():
				_speak("DISPATCH",sightings.report(campaign.stage))
				_save()
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
		"settings_voice":
			audio.set_spoken(not audio.spoken)
			if not saved_data.is_empty():
				saved_data.spoken = audio.spoken
			_save()
		"settings_30","settings_60":
			Engine.max_fps = 30 if id == "settings_30" else 60
			_save()
		"buy_chains","buy_snatch_block","service_winch","buy_fuel": _shop_purchase(id)
		"roadside_fuel":
			if _needs_fuel_can():
				rig.fuel = minf(1.0,rig.fuel + account.roadside_can())
				shift_seconds += 18 * 60
				_speak("COUNTY PLOW","Put the can in for you, Brandt. That’ll get you back to the yard.")
				_save()
		"quit":
			_save()
			get_tree().quit()
	_refresh()

func _needs_fuel_can() -> bool:
	return rig.in_cab and rig.is_stopped() and rig.fuel <= 0.0002

func _at_office() -> bool:
	return not rig.in_cab and _near(FAX,4.4)

func _at_pump() -> bool:
	return not rig.in_cab and (_near(PUMP_ISLANDS[0],4.5) or _near(PUMP_ISLANDS[1],4.5))

func _truck_in_yard() -> bool:
	var at: Vector3 = rig.get_truck_position()
	return rig.is_stopped() and County.YARD.has_point(Vector2(at.x,at.z))

func _can_refuel() -> bool:
	if _at_office():
		return _truck_in_yard()
	return _at_pump() and rig.is_stopped() and rig.get_truck_position().distance_to(PUMP) < 15.0

func _fit_equipment() -> void:
	rig.tire_chains = account.owns("chains")
	rig.snatch_block = account.owns("snatch_block")

func _shop_purchase(id: String) -> void:
	if id == "buy_fuel":
		if not _can_refuel():
			return
		var sale := account.buy_fuel(rig.fuel)
		if sale.cost <= 0:
			return
		rig.fuel = sale.fuel_after
		shop_receipt = "Diesel   $%.2f   ·   Tank %d%%" % [sale.cost,roundi(rig.fuel*100)]
	elif not _at_office() or not _truck_in_yard():
		return
	elif id == "service_winch":
		if rig.wear <= 0.001 or not account.pay_repair():
			return
		rig.wear = 0.0
		shop_receipt = "Winch serviced. Cable and drum ready."
	else:
		var part := id.trim_prefix("buy_")
		if not account.buy(part):
			return
		_fit_equipment()
		shop_receipt = "Drive-axle chains fitted." if part == "chains" else "Snatch block fitted. Heavy pulls cleared for dispatch."
	audio.effect("fax")
	_save()

func _prepare_offers() -> void:
	if mode == "available":
		var issued := completed + pending_slips.size()
		if rotation_offer.is_empty() and campaign.stage >= 2:
			rotation_offer = sightings.recovery_offer(issued,county,account.owns("snatch_block"),campaign.stage == Campaign.ORDER.size())
		if rotation_offer.is_empty():
			rotation_offer = Dispatch.ordinary(issued,dispatch_seed,slips + pending_slips,account.owns("snatch_block"))
		else:
			# A case may have used the next blank on the clipboard.
			rotation_offer.number = 1001 + issued
		if case_offer.is_empty():
			match survey.pending_order():
				"hold":
					case_offer = Dispatch.hold_ticket(issued,audio.lines,true)
					case_offer.point = county.survey_point
					case_offer.angle = county.survey_yaw
				"looksee": case_offer = Dispatch.looksee(issued)
		if not case_offer.is_empty():
			case_offer.number = 1001 + issued
	_sync_waiting_hazard()

func _sync_waiting_hazard() -> void:
	var waiting: bool = rotation_offer.get("kind") == "hazard" and not rotation_offer.has("aftermath_key")
	var point: Vector3 = county.resolve_point(rotation_offer.point) if waiting else Vector3.ZERO
	if is_instance_valid(waiting_hazard):
		if waiting and waiting_hazard.get_meta("offer_pose") == [rotation_offer.vin, point, rotation_offer.angle]:
			return
		waiting_hazard.hide()
		waiting_hazard.queue_free()
		waiting_hazard = null
	if waiting:
		waiting_hazard = rig.store_vehicle(rotation_offer.route,point,rotation_offer.angle,rotation_offer)
		waiting_hazard.set_meta("offer_pose",[rotation_offer.vin, point, rotation_offer.angle])

func _take_rotation() -> void:
	if not rig.in_cab or mode != "available":
		return
	_prepare_offers()
	survey.defer_order()
	_accept(rotation_offer)

func _case_due() -> bool:
	return campaign.due() and not pending_slips.any(func(slip): return slip.get("case_id") == campaign.chapter())

func _radio_contact() -> Dictionary:
	if not rig.in_cab:
		return {}
	if campaign.chapter() == "unit" and _case_due() and survey.can_report_unit():
		return {"id":"report_unit","label":"Report Unit 38 and rod case"}
	if not _case_lock().is_empty():
		return {}
	if not survey.pending_order().is_empty() and mode == "available":
		if survey.pending_order() == "hold":
			return {"id":"take_case","label":"Meet Kowalski at Unit 38"}
		return {"id":"take_case","label":"Take the N5104 look-see"}
	if campaign.chapter() == "farm" and _case_due() and survey.can_request_farm():
		return {"id":"ask_farm","label":"Ask about N5104 Kolpack"}
	if mode == "fieldwork" and job.get("id") == "n5104" and survey.notes.has("house") and survey.notes.has("farm_ring"):
		return {"id":"report_farm","label":"Report the empty Hoffmann place"}
	return casework.contact()

func _case_lock() -> String:
	if mode != "available":
		return ""
	if campaign.chapter() == "unit":
		if survey.pending_order() != "hold":
			return ""
		# Keep a custody order already issued on an older rig's original terms.
		if case_offer.get("kind") == "hold" and not case_offer.get("heavy_recovery",false):
			return ""
	elif not _case_due():
		return ""
	var part := campaign.required_equipment()
	return campaign.equipment_note() if not part.is_empty() and not account.owns(part) else ""

func _radio_case(id: String) -> void:
	if _radio_contact().get("id") != id:
		return
	match id:
		"report_unit":
			survey.unit_reported = true
			survey.hold_order = "offered"
			_speak("DISPATCH","Copy. Prints stop in open snow. Nothing from Tou on the county channel. Kowalski opened TC-96-031. Call for her hold when you’re clear.")
		"ask_farm":
			survey.farm_order = "offered"
			_speak("DISPATCH","Hoffmann place. Milk hauler says every light is on. He knocked twice. I can give you the look-see when you’re free.")
		"take_case":
			_prepare_offers()
			if survey.pending_order() == "hold":
				survey.hold_order = "accepted"
			else:
				survey.farm_order = "accepted"
			_accept(case_offer)
		"report_farm":
			survey.farm_reported = true
			_record_visit()
			_speak("DISPATCH","Copy. Supper on the table and the car gone. I’ll let the milk hauler know. Fax it when you’re in.")
			_clear_field_job()
	_prepare_offers()
	_save()

func _accept(ticket: Dictionary) -> void:
	job = ticket
	if job.has("aftermath_key"):
		sightings.claim_recovery(job)
	if (not job.has("case_id") and job.kind in ["ditch","hazard","passenger"]) or (job.get("case_id") == "angie" and rotation_offer.get("vin") == job.vin):
		rotation_offer = {}
		_sync_waiting_hazard()
	if job == case_offer:
		case_offer = {}
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
	if job.kind != "looksee":
		rig.start_job(job.kind,county.resolve_point(job.point),job.angle,job)
	_sync_survey_scene()
	var call_text: String = job.dispatch
	if Rig.uses_warning_triangle(job.kind,job):
		call_text += " Look for the red triangle."
	_speak("DISPATCH",call_text)
	speaker = "DISPATCH  ·  CONTRACT %d ACCEPTED" % job.number
	_save()

func _directions() -> void:
	var words: String = _road_note().get("instruction","")
	if not words.is_empty():
		if mode == "haul" and not words.contains(rig.dropoff.sign):
			words += " You're delivering to %s." % rig.dropoff.sign
		_speak("DISPATCH",words)
	elif mode == "available":
		_speak("DISPATCH","Standing by when you're ready to take the contract.")
	elif job.get("kind") == "passenger" and rig.phase == "passenger":
		_speak("DISPATCH","Pull in by the pumps. Mai’s on the register.")
	elif mode == "haul":
		_say(rig.dropoff.radio)
	elif mode in ["return","invoice"]:
		_say("yard_dir")
	else:
		_speak("DISPATCH",job.directions)

func _sync_survey_scene() -> void:
	county.set_case_landmarks(campaign.landmarks())
	var summer: bool = job.get("kind") == "passenger" and rig.phase == "passenger"
	rig.set_survey_passenger(summer or (campaign.evidence.has("passenger") and not campaign.released),summer)
	county.set_survey_pickup_parked(not held and not campaign.released and job.get("kind") != "hold")
	county.set_tripod_collected(held or packed_tripod or campaign.released)
	county.set_rod_case_read(survey.notes.has("rod"))

func _survey() -> void:
	var pos: Vector3 = rig.get_truck_position()
	if campaign.released and not campaign.evidence.has("unit_departed") and pos.distance_to(BAY) > 140 and not _near(BAY,140):
		campaign.evidence["unit_departed"] = rig.odo
		_display_storage()
		_save()
	var street := _current_road_map().driven_road(Vector2(pos.x,pos.z))
	if not street.is_empty() and not street in roads_driven:
		roads_driven.append(street)
	if completed >= 2 and not plow_heard and sub_time == 0 and pos.distance_to(SPAWN) > 110 and rig.in_cab:
		plow_heard = true
		_say("plow")
	if job.get("kind") == "passenger" and rig.phase == "passenger" and rig.in_cab and rig.is_stopped() and pos.distance_to(PUMP) < 16.0:
		drop_odo = rig.odo
		drop_time = _clock()
		_speak("DRIVER","I know this place. I can call my sister from inside. Thanks for the ride.")
		_clear_field_job()
		rig.end_job()
		_sync_survey_scene()
		_prepare_offers()
		_save()
	if mode == "return" and (pos.distance_to(SPAWN) < 27 or _near(FAX,4.4)):
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
	var detail_site := casework.site()
	if not detail_site.is_empty():
		return detail_site
	if not held and not campaign.released and job.get("kind") != "hold" and _facing(county.survey_door_point(),3.3):
		return "unit"
	if _facing(county.rod_case_point(),3.0):
		return "rod"
	for item: String in ["house","farm_ring"]:
		if _facing(county.story_point(item),3.2):
			return item
	if mode == "fieldwork" and job.get("kind") == "hold":
		if not packed_tripod and _facing(county.hold_tripod_point(),3.9):
			return "tripod"
		if _facing(rig.get_witness_position(),4.3):
			return "sign" if not signed_card else "deputy"
	elif mode == "fieldwork" and job.get("kind") == "passenger" and rig.phase == "scene" and _facing(rig.get_witness_position(),3.9):
		return "summer_ride"
	elif mode == "fieldwork" and job.get("kind") == "ditch" and not talked and _facing(rig.get_witness_position(),3.9):
		return "driver"
	# The panel and doors can sit within reach of the fax, chain or field book.
	if rig.action_id() == "drop" or (held and _near(BAY,16.0) and rig.action_id() == "enter"):
		return ""
	if _facing(FAX,4.4):
		return "fax"
	if held and _facing(county.bay_latch_point(),2.7):
		return "unlock" if bay_locked else "lock"
	if held and not bay_locked and _facing(BAY,4.8):
		return "field"
	if _facing(PUMP_ISLANDS[0],4.5) or _facing(PUMP_ISLANDS[1],4.5):
		return "fuel"
	return ""

func _chain_obstruction() -> String:
	var floor_area := County.Bay.FLOOR
	if rig.wrecker_overlaps(floor_area):
		return "Drive the wrecker clear of the chains before locking up."
	if not rig.in_cab and floor_area.has_point(Vector2(rig.foot.x, rig.foot.z)):
		return "Step outside the bay and lock the corner chain from the yard."
	return ""

func _chain_instruction() -> String:
	var obstruction := _chain_obstruction()
	return obstruction if not obstruction.is_empty() else "Lock the chain at the bay’s outside corner, then go to the office fax."

func _interact() -> void:
	var site := _site_action()
	if Casework.PROMPTS.has(site):
		casework.inspect(site)
		_save()
		return
	match site:
		"unit","rod","house","farm_ring":
			survey.record(site,rig.odo)
			if site == "rod":
				county.set_rod_case_read(true)
			var entry := {
				"unit":"Survey Unit 38. Engine’s running. Driver’s door wide open. Boot prints head north from the tripod.",
				"rod":"Left boot, then nothing. Open snow all around. Tou’s rod case is dry enough to write on.",
				"house":"N5104. All the lights on, the door open. Two places set for supper. Nobody answers.",
				"farm_ring":"Bare, wet ground in a circle where the Hoffmanns parked. No tire tracks across the snow."}
			_message("BRANDT",entry[site])
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
			_say("light" if talked_twice else "kowalski_swamp")
			talked_twice = true
		"summer_ride":
			if rig.get_truck_position().distance_to(rig.get_witness_position()) > 23.0:
				_message("DRIVER","Can you bring the truck over here? I left my coat somewhere.")
				return
			rig.board_summer_driver()
			pickup_time = _clock()
			pickup_odo = rig.odo
			_say("summer_driver")
		"driver":
			talked = true
			_say(job.reply)
		"fax":
			if _can_file_here() or mode in ["return","invoice"]:
				_file_invoice()
			else:
				_open_shop()
		"lock","unlock":
			if not bay_locked:
				var obstruction := _chain_obstruction()
				if not obstruction.is_empty():
					_message("BRANDT",obstruction)
					return
			bay_locked = not bay_locked
			county.set_bay_locked(bay_locked)
			audio.effect("ratchet")
			_message("BRANDT","Bay secured. Key back on the ring." if bay_locked else "Hold bay open.")
		"field": _read_book()
		"fuel":
			if sightings.seen.has("streetlights_out") and not mai_lot_heard:
				mai_lot_heard = true
				_say("mai_lot")
			_open_shop()
		_:
			if mode == "fieldwork" and job.get("case_id") == "angie" and not campaign.evidence.has("angie_consent") and rig.action_id() == "flare":
				_message("BRANDT","The owner’s on the porch. I need her signature before I hook this car.")
				return
			if mode == "fieldwork" and job.kind == "hold" and rig.action_id() == "flare" and (not signed_card or not packed_tripod):
				_message("KOWALSKI","Sign my custody card and take the survey tripod before we move this truck.")
				return
			rig.interact()
	_save()

func _open_shop() -> void:
	shop_receipt = ""
	_refresh()
	desk.show_document("parts",state)

func _recovered(kind: String) -> void:
	if mode != "fieldwork":
		return
	if kind != "hold" or pickup_time.is_empty():
		pickup_odo = rig.get_status().odo
		pickup_time = _clock()
	if kind == "ditch":
		drop_odo = pickup_odo
		drop_time = pickup_time
		if talked:
			_say("clear")
		else:
			_say(job.reply)
		_clear_field_job()
		_prepare_offers()
	else:
		mode = "haul"
		_speak("DISPATCH",job.get("haul_line","Copy, Brandt. Bring this one to %s." % rig.dropoff.sign))
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
		_sync_survey_scene()
	else:
		stored.append({"number":job.number,"route":job.route,"variant":job.get("variant",2),"plate":job.plate,"vin":job.vin,
			"heavy_recovery":job.get("heavy_recovery",false)})
	rig.end_job()
	_display_storage()
	_save()

func _turn_storage_north() -> void:
	for i in stored.size():
		if not stored[i] is Dictionary:
			stored[i] = {"route":stored[i]}
		stored[i].turned_north = true
	_display_storage()

func _display_storage() -> void:
	for node in physical_cars:
		if is_instance_valid(node):
			node.queue_free()
	physical_cars.clear()
	if held or (campaign.released and not campaign.evidence.has("unit_departed")):
		var car = rig.store_vehicle("hold",BAY,-PI/2)
		if car is Node3D:
			physical_cars.append(car)
	for i in mini(stored.size(),PARKING.size()):
		var entry: Dictionary = stored[i] if stored[i] is Dictionary else {"route":stored[i]}
		var facing := 0.0 if entry.get("turned_north",false) or int(entry.get("number",i)) % 2 == 0 else PI
		var car = rig.store_vehicle(entry.route,PARKING[i],facing,entry)
		if car is Node3D:
			physical_cars.append(car)

func _read_book() -> void:
	book_read = true
	_refresh()
	desk.show_document("field",state)
	_save()

func _current_slip() -> Dictionary:
	var slip := Dispatch.issue_slip(job,dispatch_odo,pickup_odo,drop_odo,seconds_worked,drop_time if not drop_time.is_empty() else _clock(),campaign.released)
	var case_id: String = job.get("case_id","")
	if job.kind == "hold":
		case_id = "unit"
	elif job.get("id") == "n5104":
		case_id = "farm"
	if not case_id.is_empty():
		slip.case_id = case_id
	if job.has("receipt"):
		slip.receipt = job.receipt
	return slip

func _record_visit() -> void:
	pickup_odo = rig.odo
	drop_odo = pickup_odo
	pickup_time = _clock()
	drop_time = pickup_time

func _clear_field_job() -> void:
	pending_slips.append(_current_slip())
	job = {}
	mode = "available"

func _filing_blocker() -> String:
	if job.get("kind") == "hold" and not bay_locked:
		return "The hold bay needs locking before I file the custody card."
	if job.get("case_id") == "ride" and not campaign.released:
		return "Tou’s custody release still needs a signature at the hold bay."
	return ""

func _fax_count() -> int:
	return pending_slips.size() + int(mode in ["return","invoice"] and _filing_blocker().is_empty())

func _can_file_here() -> bool:
	return _at_office() and _fax_count() > 0

func _file_invoice() -> void:
	if not _at_office():
		return
	var blocker := ""
	if mode in ["return","invoice"]:
		blocker = _filing_blocker()
		if blocker.is_empty():
			pending_slips.append(_current_slip())
			rig.end_job()
			job = {}
			mode = "available"
	if pending_slips.is_empty():
		if not blocker.is_empty():
			_message("BRANDT",blocker)
		return
	for slip: Dictionary in pending_slips:
		_file_slip(slip)
	pending_slips.clear()
	audio.effect("fax")
	if not blocker.is_empty():
		_message("BRANDT",blocker)
	elif mode == "available":
		if slips.back().get("case_id") == "angie":
			_speak("DISPATCH","Brandt, you on? I’ve got another one for you when you’re ready.")
		else:
			_message("DISPATCH","Standing by, Brandt. Call when you're ready.")
	_sync_survey_scene()
	_survey()
	_prepare_offers()
	_refresh()
	desk.show_document("fax",state)
	_save()

func _file_slip(slip: Dictionary) -> void:
	var case_id: String = slip.get("case_id","")
	var lead := campaign.on_file(slip.kind,case_id)
	slips.append(slip)
	completed += 1
	var prior_fuel_due := account.fuel_due
	var payment := account.file_invoice(slip.pay,completed)
	if case_id == "unit":
		survey.hold_order = "filed"
	elif case_id == "farm":
		survey.farm_order = "filed"
	fax_text = "TO  BRANDT TOWING & RECOVERY\nRE  SERVICE SLIP %04d\n\nReceived for county review.\nCall-out  $%d    Hookup  $%d\nWinch  $%d    Storage  $%d\nLoaded  %.1f mi @ $3.25" % [slip.number,slip.call_out,slip.hookup,slip.winch,slip.storage,slip.loaded]
	if slip.heavy_fee > 0:
		fax_text += "\nHeavy recovery  $%d" % slip.heavy_fee
	if slip.get("rate_fee",0) > 0:
		fax_text += "\n%s  $%.2f" % [slip.rate_name,slip.rate_fee]
	fax_text += "\nNet invoice  $%.2f\n\nD. Pfaff  /  Accounts Payable" % slip.pay
	if payment > 0:
		fax_text += "\n\nBATCH PAYMENT ISSUED   $%.2f" % payment
		if prior_fuel_due > account.fuel_due:
			fax_text += "\nLess county fuel can   $%.2f" % (prior_fuel_due-account.fuel_due)
		# A later tow may already be parked when an earlier invoice settles the batch.
		stored = stored.filter(func(car): return car is Dictionary and car.get("number",0) > slip.number)
		_display_storage()
	if slip.has("receipt"):
		fax_text += "\f" + str(slip.receipt)
	if not lead.is_empty():
		fax_text += "\f" + lead
		if not campaign.required_equipment().is_empty() and not account.owns(campaign.required_equipment()):
			fax_text += "\n\n" + campaign.equipment_note()
	faxes.append(fax_text)

func _say(id: String) -> void:
	var line: Array = audio.lines[id]
	_speak(line[0],line[1])

func _speak(who: String, words: String) -> void:
	_message(who, words)
	audio.speak(who,words)
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
	if job.has("case_id") and (mode == "fieldwork" or job.case_id == "ride"):
		var instruction := casework.procedure()
		if not instruction.is_empty():
			return instruction
	match mode:
		"available":
			if not pending_slips.is_empty():
				return "Take the next call on the cab radio. Fax the finished slips next time you’re at the yard."
			return "County dispatch is standing by. Answer on the cab radio."
		"fieldwork":
			if job.kind == "passenger":
				return "Stop beside the pumps at Esker Fuel & Food to let the driver out." if rig.phase == "passenger" else "Pull up by the car and speak to the driver in the summer shirt."
			if job.kind == "looksee":
				if not survey.notes.has("house"):
					return "Find the porch fire number beyond the Lindquist farm on Kolpack."
				if not survey.notes.has("farm_ring"):
					return "Look in the empty drive beside the Hoffmann house."
				return "Use the cab radio to tell Arlene what you found."
			if job.kind == "hold" and (not signed_card or not packed_tripod):
				return "Meet Deputy Kowalski, sign the custody card and collect the tripod."
			return rig.get_status().get("hint","Drive to the scene. Ask dispatch for a landmark if needed.")
		"haul": return audio.lines[rig.dropoff.radio][1]
		"return": return "Return to the yard to file your slip."
		"invoice":
			if job.get("kind") == "hold" and not bay_locked:
				return _chain_instruction()
			return "Walk to the office fax at the yard door. File the tow slip."
	return ""

func _contract_hint(site: String) -> Dictionary:
	var title := ""
	var instruction := ""
	if _needs_fuel_can():
		return {"hint_title":"Out of diesel","hint_action":"Tap RADIO for a county fuel can." if desk.is_touch_mode() else "Press R to call for a county fuel can."}
	match mode:
		"available":
			title = "First contract available"
			if not pending_slips.is_empty():
				title = "Clear for dispatch · %d %s awaiting fax" % [pending_slips.size(),"slip" if pending_slips.size() == 1 else "slips"]
			elif not slips.is_empty():
				var number := int(slips.back().number)
				title = "Slip %d filed" % number
			if site == "fax" and not pending_slips.is_empty():
				instruction = "Tap USE to fax the finished paperwork." if desk.is_touch_mode() else "Press E to fax the finished paperwork."
			elif not _case_lock().is_empty():
				instruction = _case_lock()
			elif _case_due() and not rig.in_cab:
				instruction = "Case message on file. Check the cab radio when you’re ready."
			elif not rig.in_cab:
				instruction = "Get in the cab for the next contract on the radio."
			elif not _radio_contact().is_empty() or _case_due():
				instruction = "Open RADIO for the next call or a case contact." if desk.is_touch_mode() else "Press R for the next call or a case contact."
			elif desk.is_touch_mode():
				instruction = "Tap RADIO, then Take contract."
			else:
				instruction = "Press R to take a contract on the cab radio."
		"fieldwork":
			if job.has("case_id"):
				instruction = casework.procedure()
				if not instruction.is_empty():
					title = job.title
			elif job.kind == "passenger":
				title = "Passenger · Esker Fuel & Food"
				instruction = _procedure()
			elif job.kind == "looksee":
				title = "Look-see · N5104 Kolpack"
				instruction = _procedure()
		"haul":
			title = "Deliver to %s" % rig.dropoff.sign
			instruction = rig.dropoff.approach
			if rig.at_dropoff():
				title = "At %s" % rig.dropoff.sign
				if rig.in_cab:
					instruction = "Stop and get out. Walk to the wrecker’s left rear panel."
				else:
					var control := "Tap USE" if desk.is_touch_mode() else "Press E"
					instruction = "%s at the left rear panel to unhook the vehicle." % control
		"return","invoice":
			title = "Slip %d awaiting fax" % int(job.number)
			if job.get("case_id") == "ride" and not campaign.released:
				title = "Tou’s release · Unit 38"
				instruction = casework.procedure()
			elif job.kind == "hold" and not bay_locked:
				instruction = _chain_instruction()
			elif site == "fax":
				instruction = "Tap USE to file the slip." if desk.is_touch_mode() else "Press E to file the slip."
			elif mode == "return":
				instruction = "Return to Brandt’s yard. File the slip at the office fax."
			elif rig.in_cab:
				instruction = "Park by the OFFICE / FAX sign and get out."
			else:
				instruction = "Walk to the fax under the OFFICE / FAX sign."
	return {"hint_title":title, "hint_action":instruction}

func _prompt(site: String = _site_action()) -> String:
	if _needs_fuel_can():
		return ""
	if Casework.PROMPTS.has(site):
		return Casework.PROMPTS[site]
	if site == "rod" and survey.notes.has("rod"):
		return "Read the survey rod tag"
	if site == "lock":
		var obstruction := _chain_obstruction()
		if not obstruction.is_empty():
			return obstruction
	var words := {"summer_ride":"Offer the driver a ride to Esker","unit":"Read the lettering on the pickup","rod":"Turn over the survey rod case","house":"Look through the open door","farm_ring":"Inspect the bare ring in the drive","lock":"Lock the evidence bay","unlock":"Unlock the evidence bay","tripod":"Collect the survey tripod","sign":"Sign Kowalski’s custody card","deputy":"Ask Kowalski about the lights","driver":"Speak to the driver","field":"Open the pickup · field book","fuel":"Check the diesel pump","fax":"Fax finished paperwork" if _can_file_here() else "Open yard office · diesel, parts & fax"}
	if words.has(site):
		return words[site]
	return rig.context_text()

func _custody_record() -> String:
	return "TC-96-031  /  Survey Unit 38\nPickup  %s   ODO %.1f\nReceived by J. Kowalski / Brandt\nInstrument and tripod  %s\nHold bay  %s" % [pickup_time,pickup_odo,"in custody" if packed_tripod else "at scene",("%s   ODO %.1f" % [drop_time,drop_odo]) if held else "awaiting transfer"]

func _current_road_map() -> RoadDirections:
	if road_directions.sections.is_empty():
		road_directions.build(county.map_roads())
	return road_directions

func _road_note() -> Dictionary:
	var note := _route_note()
	if not active or mode != "fieldwork" or rig.phase != "scene" or _needs_fuel_can():
		return note
	if job.get("kind") not in ["ditch","hazard","hold","passenger"]:
		return note
	var identity := "%s, plate %s." % [job.vehicle,job.plate]
	if Rig.uses_warning_triangle(job.kind,job):
		identity += " Look for the red triangle."
	elif job.kind == "passenger":
		identity += " The driver's in a T-shirt."
	if note.is_empty():
		return {"title":"Pickup   /   %s" % job.location,"instruction":identity}
	note.instruction += " " + identity
	return note

func _route_note() -> Dictionary:
	if not active or not rig.in_cab or _needs_fuel_can():
		return {}
	var at: Vector3 = rig.get_truck_position()
	var p := Vector2(at.x, at.z)
	var in_yard := County.YARD.has_point(p) and p.x < -4
	var target := RoadDirections.DRIVEWAY
	var landmark := "Brandt’s yard"
	var title := "Route slip   /   Brandt yard"
	var unmapped := false
	var heading: float = fposmod(-rad_to_deg(rig.heading),360.0)
	if county.alder_open and p.y < -478 and absf(p.x-441) < 43:
		if mode == "fieldwork" and job.get("case_id") in ["line","ride"]:
			return {}
		return {"title":"Pencil note   /   Alder Cut","instruction":"Follow the stakes south to Swamp Road. County K is west of the barricade."}
	if mode == "fieldwork" and not job.is_empty():
		var location: Vector3 = county.resolve_point(job.point) if job.kind == "looksee" else rig.job_site
		target = Vector2(location.x, location.z)
		unmapped = job.get("unmapped", false)
		landmark = str(job.location).get_slice(" · ", 1)
		if landmark.is_empty():
			landmark = job.location
		title = "Route slip   /   %04d" % int(job.number)
		if job.kind == "passenger" and rig.phase == "passenger":
			target = Vector2(PUMP.x,PUMP.z)
			landmark = "Esker Fuel & Food"
		if p.distance_to(target) < 23.0:
			return {}
		if in_yard:
			p = RoadDirections.DRIVEWAY
			heading = 90.0
	elif in_yard or (mode == "available" and p.distance_to(target) < 90):
		return {}
	elif mode == "available" and not pending_slips.is_empty():
		title = "Office fax   /   Optional return"
	elif mode == "haul":
		title = "Return   /   %s" % rig.dropoff.sign
	elif mode in ["return", "invoice"]:
		title = "Return   /   Office fax"
	var note := _current_road_map().cue(p, heading, target, landmark, unmapped)
	note.title = title
	return note

func _refresh() -> void:
	var s: Dictionary = rig.get_status()
	var ticket := job.duplicate()
	if not job.is_empty() and (not pickup_time.is_empty() or mode in ["haul","return","invoice"]):
		ticket.pickup_odo = pickup_odo
		if mode == "invoice" or mode == "return":
			ticket.drop_odo = drop_odo
			ticket.loaded = 0.0 if job.kind == "ditch" else snappedf(maxf(0,drop_odo-pickup_odo),0.1)
	var bearing := posmod(roundi(float(s.heading)/45.0),8)
	var card := filed_card if held or campaign.released else (_custody_record() if signed_card else "")
	county.drop_guide.visible = mode == "haul" and rig.loaded
	if county.drop_guide.visible:
		county.drop_guide.position = rig.dropoff.center
	var site := _site_action()
	state = {"prompt":_prompt(site),"subtitle":subtitle if sub_time>0 else "","speaker":speaker,
		"feedback":rig.info if rig.info_timer > 0 else "",
		"spoken":audio.spoken,"has_save":not saved_data.is_empty(),"in_cab":s.in_cab,"speed_mph":s.speed_mph,
		"driving_view":rig.driving_view,"truck_stopped":rig.is_stopped(),
		"can_enter_cab":rig.action_id() == "enter" and site.is_empty(),
		"miles":s.odo,"trip":float(s.odo)-dispatch_odo if not job.is_empty() else 0.0,
		"fuel":s.fuel,"tension":s.tension,"heading":["N","NE","E","SE","S","SW","W","NW"][bearing],
		"job":ticket,"slips":slips,"pending_slips":pending_slips,"fax_count":_fax_count(),"calls":calls,"can_radio":s.in_cab,"night_time":_clock(),
		"offer":rotation_offer,"radio_contact":_radio_contact(),"can_report_sighting":sightings.can_report(),"pending_case":not survey.pending_order().is_empty() or (_case_due() and Campaign.DETAILS.has(campaign.chapter())),
		"case_lead":Campaign.LEADS.get(campaign.chapter(),"") if _case_due() else "",
		"case_evidence":campaign.evidence,"tou_asked":campaign.asked,
		"pencil_notes":survey.notebook()+casework.notebook(),"observations":survey.notes,"can_mark_sketch":book_read and not survey.notes.has("sketch"),
		"faxes":faxes,"fax_text":fax_text,"field_available":book_read,"custody_text":card,"can_fax":_can_file_here(),
		"roads":county.map_roads(),"places":county.map_places(),"road_names":roads_driven,
		"at_office":_at_office(),"at_pump":_at_pump(),"can_order":_at_office() and _truck_in_yard(),
		"can_refuel":_can_refuel(),"fuel_quote":account.fuel_quote(s.fuel),"fuel_help":_needs_fuel_can(),
		"case_lock":_case_lock(),"shop_receipt":shop_receipt,
		"chains":rig.tire_chains,"snatch_block":rig.snatch_block,"wear":s.wear,
		"paid":account.cash,"pending":account.pending,"earned":account.earned,"fuel_due":account.fuel_due,
		"progress":_procedure(),"phase":s.phase,"work_available":rig.action_id()=="winch",
		"warmth":s.warmth,"mode":mode,"rig_hint":s.get("hint","")}
	state.merge(_contract_hint(site))
	state["heading_degrees"] = s.heading
	desk.update_view(state)

func _save() -> void:
	if not active or not rig:
		return
	save_timer = 0
	saved_data = {"completed":completed,"mode":mode,"rig":rig.save_state(),"slips":slips,"pending_slips":pending_slips,
		"dispatch_seed":dispatch_seed,"ticket":Dispatch.pack(job),"offer":Dispatch.pack(rotation_offer),
		"case_offer":Dispatch.pack(case_offer),"survey":survey.save_state(),"campaign":campaign.save_state(),
		"survey_anchor":Dispatch.pack({"point":county.survey_point,"angle":county.survey_yaw}),
		"sightings":sightings.save_state(),"mai_lot_heard":mai_lot_heard,
		"calls":calls,"roads":roads_driven,"stored":stored,"bay_locked":bay_locked,"held":held,"book_read":book_read,
		"signed":signed_card,"tripod":packed_tripod,"talked":talked,"asked":talked_twice,
		"seconds":shift_seconds,"start":dispatch_odo,"pickup":pickup_odo,"drop":drop_odo,
		"pickup_time":pickup_time,"drop_time":drop_time,"account":account.save_state(),"work":seconds_worked,
		"fax":fax_text,"faxes":faxes,"filed_card":filed_card,"plow":plow_heard,"fps":Engine.max_fps,"spoken":audio.spoken}
	if not test_session and not Ledger.write(saved_data):
		push_warning("Could not save current tow ticket")

func _restore(s: Dictionary) -> void:
	casework.leave_tower()
	completed = int(s.completed)
	mode = s.mode
	slips = s.slips
	pending_slips = s.get("pending_slips",[])
	calls = s.calls.duplicate()
	roads_driven = s.roads
	stored = s.stored
	held = s.held
	bay_locked = s.get("bay_locked",held)
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
	account.restore(s)
	shop_receipt = ""
	seconds_worked = s.work
	fax_text = s.fax
	faxes = s.get("faxes",[])
	filed_card = s.get("filed_card","")
	plow_heard = s.plow
	mai_lot_heard = s.get("mai_lot_heard",false)
	sightings.restore(s.get("sightings",{}),county)
	var anchor := Dispatch.unpack(s.get("survey_anchor",{}))
	county.set_survey_anchor(anchor.get("point",County.SURVEY_PICKUP),anchor.get("angle",County.SURVEY_YAW))
	dispatch_seed = int(s.get("dispatch_seed",dispatch_seed))
	rotation_offer = Dispatch.unpack(s.get("offer",{}))
	case_offer = Dispatch.unpack(s.get("case_offer",{}))
	job = Dispatch.unpack(s.get("ticket",{}))
	if mode != "available" and job.is_empty():
		job = Dispatch.legacy_ticket(completed,audio.lines)
	survey.restore(s.get("survey",{}),held,job.get("kind",""))
	if not s.has("account") and survey.pending_order() == "hold" and case_offer.is_empty():
		case_offer = Dispatch.hold_ticket(completed,audio.lines)
		case_offer.point = county.survey_point
		case_offer.angle = county.survey_yaw
	campaign.restore(s.get("campaign",{}),survey,slips)
	var rig_state: Dictionary = s.rig.duplicate(true)
	if not s.has("sightings"):
		if s.get("longer",false):
			_restore_plat_positions(rig_state)
			for departure: Dictionary in rig_state.get("departures",[]):
				_restore_plat_positions(departure)
		_migrate_case_ticket(rig_state)
	if not job.is_empty() and not rig_state.has("identity"):
		rig_state.identity = job
	elif job.has("case_id") and job.kind == rig_state.get("kind"):
		# Older rig snapshots only kept the case ID on the dispatch ticket.
		rig_state.identity.case_id = job.case_id
	# Older shifts kept finished roadside work as the active ticket until the yard fax.
	if mode in ["return","invoice"] and job.get("kind") in ["ditch","looksee"] and job.get("case_id") != "ride":
		_clear_field_job()
	_sync_survey_scene()
	_prepare_offers()
	rig.restore_state(rig_state)
	if job.get("kind") == "passenger" and rig.phase == "passenger":
		rig.board_summer_driver()
	_fit_equipment()
	# Older saves could close the chain around the operator or a parked rig.
	if bay_locked and not _chain_obstruction().is_empty():
		bay_locked = false
	county.set_bay_locked(bay_locked)
	_display_storage()

# The dispatch ticket always used plat coordinates. Old rig snapshots used world metres.
func _restore_plat_positions(snapshot: Dictionary) -> void:
	for key in ["truck","foot","site","car","witness","flare"]:
		var point = snapshot.get(key)
		if point is Array and point.size() == 3:
			var z := float(point[2])
			point[2] = z - 40.0 * clampf((z - 164.0) / 112.0,0,1)

func _migrate_case_ticket(rig_state: Dictionary) -> void:
	if case_offer.get("id") == "n5104":
		case_offer = Dispatch.looksee(int(case_offer.number)-1001)
	if job.get("id") == "n5104":
		job = Dispatch.looksee(int(job.number)-1001)
	var id: String = job.get("case_id","")
	if not Campaign.DETAILS.has(id) or id != campaign.chapter():
		return
	var original_kind: String = job.kind
	job = campaign.ticket(int(job.number))
	if mode == "fieldwork" and original_kind == "looksee" and job.kind == "hazard":
		# The former bridge and mailbox inspections now dispatch actual recoveries.
		rig_state.merge({"kind":job.kind,"phase":"scene","site":[job.point.x,job.point.y,job.point.z],
			"site_yaw":job.angle,"identity":job.duplicate(),"loaded":false,"line_end":-1},true)
		for key in ["car","car_rot","flare"]:
			rig_state.erase(key)
