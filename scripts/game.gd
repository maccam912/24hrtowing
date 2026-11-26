extends Node

const County := preload("res://scripts/county.gd")
const Rig := preload("res://scripts/rig.gd")
const Desk := preload("res://scripts/desk.gd")
const Audio := preload("res://scripts/radio_audio.gd")
const Rides := preload("res://scripts/passenger_call.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
const Ledger := preload("res://scripts/ledger.gd")
const ShopAccount := preload("res://scripts/shop_account.gd")
const FuelPlow := preload("res://scripts/fuel_plow.gd")
const Campaign := preload("res://scripts/county_case.gd")
const Casework := preload("res://scripts/casework.gd")
const SurveyCase := preload("res://scripts/survey_case.gd")
const YardDrop := preload("res://scripts/yard_drop.gd")
const CountyVisits := preload("res://scripts/county_visits.gd")
const Addresses := preload("res://scripts/fire_numbers.gd")
const RoadDirections := preload("res://scripts/road_directions.gd")

const OPTIONS_FILE := "user://operator-settings.cfg"
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
var ambience := preload("res://scripts/county_ambience.gd").new()
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
var fleet := preload("res://scripts/yard_fleet.gd").new()
const RollbackDeck := preload("res://scripts/rollback_deck.gd")
var waiting_hazard: Node3D
var case_offer := {}
var dispatch_seed := randi()
var survey := SurveyCase.new()
var campaign := Campaign.new()
@onready var casework := Casework.new(self,campaign)
var sightings := preload("res://scripts/sighting_director.gd").new()
var mai_lot_heard := false
var heavy_job_filed := false
var completed := 0
var slips := []
var pending_slips := []
var calls := []
var roads_driven := []
var plat_pencil := preload("res://scripts/plat_pencil.gd").new()
var stored := []
var faxes := []
var filed_card := ""
var physical_cars := []
var west_orders := preload("res://scripts/west_hold_orders.gd").new()
var west_archive_open := false
var west_page := 0
var west_source := ""
var hold_door_open := false
var held_pickup: Node3D
var held_tape: Dictionary = Rig.Scene.Tape.LEGACY
var open_tape := {}
var yard_card := {}
var impound_book := preload("res://scripts/impound_book.gd").new()
var received_freight: Node3D
var received_pool_car: Node3D
var pool_receipt := {}
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
var fuel_wait_left := 0.0
var fuel_plow: FuelPlow
var shop_receipt := ""
var nozzle_sale := 0.0
var nozzle_cents := 0.0
var nozzle_at_esker := false
var nozzle_reserve := false
var seconds_worked := 0.0
var fax_text := "TAMARACK COUNTY HIGHWAY DEPARTMENT\nTOW BAN IN EFFECT UNTIL FURTHER NOTICE.\nSheriff-requested removals only. Record both odometer readings."
var caption := preload("res://scripts/county_speech.gd").new()
var subtitle := ""
var speaker := ""
var sub_time := 0.0
var mouse_motion := Vector2.ZERO
var save_timer := 0.0
var ui_timer := 0.0
var direction_timer := 0.0
var road_directions := RoadDirections.new()
var plow_heard := false
var grower_visits := 0
var visits := CountyVisits.new()
var visit_offer := {}
var declined_visit := -1
var broadcast := preload("res://scripts/broadcast_radio.gd").new()
var scanner := preload("res://scripts/county_scanner.gd").new()
var saved_data := {}
var state := {}
var test_session := false
var shutting_down := false

func _ready() -> void:
	# Scripted SceneTree entry points (tests and screenshot captures) use their
	# in-memory shift even when launched directly from Godot without flags.
	test_session = get_tree().get_script() != null or "--test-mode" in OS.get_cmdline_user_args()
	world_view.name = "Storm"
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_view.own_world_3d = true
	world_view.audio_listener_enable_3d = true
	add_child(world_view)
	world_view.add_child(world)
	county = County.new()
	world.add_child(county)
	world.add_child(fleet)
	world.add_child(visits)
	visits.setup(county)
	world.add_child(ambience)
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
	audio.mount_diesel(rig.truck)
	audio.mount_recovery(rig)
	add_child(broadcast)
	rig.sound_event.connect(audio.rig_effect)
	saved_data = {} if test_session else Ledger.read()
	desk = Desk.new()
	add_child(desk)
	desk.action.connect(_action)
	var preferences := ConfigFile.new()
	if not test_session and FileAccess.file_exists(OPTIONS_FILE):
		preferences.load(OPTIONS_FILE)
	Engine.max_fps = int(preferences.get_value("cab","fps",saved_data.get("fps",30)))
	desk.fps = Engine.max_fps
	audio.set_spoken(preferences.get_value("cab","spoken",saved_data.get("spoken",false)))
	rig.assist = preferences.get_value("rig","suggested_anchors",true)
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
	var at_heater: bool = active and desk.page == "cab_heat"
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if playing or at_heater or desk.is_title() else SubViewport.UPDATE_DISABLED
	if playing:
		sightings.advance(dt,self)
		casework.advance_departure(dt)
		visits.advance(dt,self)
	if playing or at_heater or desk.is_title():
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
		var on_ladder := casework.tower_height >= 0.0
		if on_ladder:
			casework.climb(move.y,dt)
			if casework.glasses:
				look *= .19
		# A clearance clock belongs to this ticket. Travel, paperwork, a fuel
		# delivery and time spent away from the scene leave it where it was.
		if job.has("clearance_seconds") and not rig.in_cab and rig.fuel > 0.0 and rig.phase in ["flared","cable","rigged"] and rig.near_casualty(42.0) and not rig.cot_at_line():
			job.clearance_seconds += dt
		rig.set_controls(move.clamp(Vector2(-1,-1),Vector2.ONE),look,working and not on_ladder,brake,dt,on_ladder)
		picture.material.set_shader_parameter("operator_frost",0.0 if rig.in_cab else smoothstep(.08,.72,1.0-rig.warmth))
		casework.apply_glasses()
		sightings.observations.sample(dt,self,sightings)
		if rig.get_status().get("working",false):
			seconds_worked += dt
		direction_timer += dt
		if direction_timer > 0.9:
			_survey()
			_check_lead_reminder(direction_timer)
			direction_timer = 0.0
	if at_heater:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,dt)
	if playing or at_heater:
		save_timer += dt
		if save_timer > 7:
			_save()
	if active and desk.page == "bulk_pump":
		_run_nozzle(dt)
	elif active and desk.page == "reserve_transfer":
		_run_transfer(dt)
	if playing or at_heater or (active and desk.page == "radio" and fuel_wait_left > 0.0):
		_advance_shift_clock(dt)
	mouse_motion = Vector2.ZERO
	scanner.advance(dt,self)
	broadcast.advance(dt,self)
	var player_at: Vector3 = rig.get_player_position()
	var in_store: bool = not rig.in_cab and county.inside_fuel_store(player_at)
	var playing_shift: bool = active and not desk.is_title()
	if playing:
		county.fire_bay.advance(job.get("site") == "fire_hall" and mode == "haul",rig,dt)
	county.follow_camera(world_view.get_camera_3d().global_position,rig.in_cab and playing_shift,in_store)
	ambience.mix(player_at,rig.in_cab,in_store,audio.calm,playing_shift,dt)
	if active and not desk.is_title() and desk.page not in ["pause", "guidance"]:
		if sub_time > 0.0:
			sub_time = maxf(.05 if audio.voice_busy() else 0.0,sub_time-dt)
	ui_timer += dt
	# A pedal touch between HUD updates must see the latest physics step.
	if ui_timer >= 0.10 or rig.is_stopped() != state.truck_stopped:
		ui_timer = 0.0
		_refresh()
	audio.mix_truck(rig.get_status(),playing_shift,playing,dt,county.storm_gust,in_store,player_at.distance_to(rig.get_truck_position()))
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
			KEY_L: _action("spot")
			KEY_G: _action("read_fire_plate")
			KEY_V: _action("cab_heat")
			KEY_R: _action("radio")
			KEY_T: _action("talk_in")
			KEY_H: desk.show_document("help",state)

func _action(id: String) -> void:
	match id:
		"confirm_yard_recovery":
			if active and desk.page == "yard_recovery":
				_recover_to_yard()
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
			picture.material.set_shader_parameter("operator_frost",0.0)
			_save()
			title_camera.make_current()
			title_light.visible = true
			get_tree().physics_frame.connect(_frame_parked_truck,CONNECT_ONE_SHOT)
		"radio":
			if rig.get_status().in_cab:
				desk.show_document("radio",state)
			else:
				_message("BRANDT","The county radio is in the cab.")
		"rotation": _take_rotation()
		"toggle_lead":
			if _can_track_lead():
				if survey.tracked_lead.is_empty():
					survey.tracked_lead = campaign.chapter()
					if rig.in_cab and not _needs_fuel_can() and fuel_wait_left <= 0:
						if casework.lead_site().is_empty():
							_speak("DISPATCH",casework.lead_instruction())
						else:
							_directions()
					else:
						_message("BRANDT","Marked %s as my next stop. %s" % [casework.lead_label(),casework.lead_instruction()])
				else:
					survey.tracked_lead = ""
					_message("BRANDT","I'll leave that lead on file." if job.is_empty() else "Back to slip %04d." % int(job.number))
				_save()
		"report_unit","take_case","ask_farm","report_farm","report_detail","report_notes":
			_radio_case(id)
		"take_detail","talk_tou":
			if _radio_contact().get("id") == id:
				match id:
					"take_detail": _accept(campaign.ticket(1001 + completed + pending_slips.size()))
					"talk_tou": desk.show_document("passenger",state)
		"tou_0","tou_1","tou_2","tou_3","tou_4","tou_5","tou_6","tou_7":
			if _radio_contact().get("id") == "talk_tou":
				var choice := int(id.right(1))
				if choice not in campaign.asked:
					campaign.asked.append(choice)
				_speak("TOU",Campaign.QUESTIONS[choice][1])
				_save()
		"pencil_mark":
			if desk.page == "map" and desk.pencil_open and not desk.glance and plat_pencil.write(desk.pencil_tool,desk.pencil_point,
					plat_pencil.TOWN_PICK_RADIUS if desk.town_sheet else plat_pencil.PICK_RADIUS):
				_save()
		"mark_sketch":
			if book_read and desk.page == "field":
				survey.record("sketch",rig.odo)
				desk.show_document("map",state)
				_save()
		"talk_in":
			if rig.get_status().in_cab:
				_directions()
			else:
				_message("BRANDT","Use the radio in the cab.")
		"impound_prev","impound_next":
			if desk.page == "impound_register":
				impound_book.turn(1 if id == "impound_next" else -1)
		"impound_index":
			if desk.page == "register_card":
				desk.show_document("impound_register",state)
		"impound_0","impound_1","impound_2":
			var rows: Array = impound_book.visible_cards()
			var index := int(id.right(1))
			if desk.page == "impound_register" and index < rows.size():
				yard_card = rows[index]
				_refresh()
				desk.show_document("register_card",state)
		"west_accept","west_sign_pickup","west_sign_release","west_archive","west_archive_prev","west_archive_next","west_current":
			_handle_west_order(id)
		"take_visit":
			if mode == "available" and rig.in_cab:
				_prepare_offers()
				if not visit_offer.is_empty():
					_accept(visit_offer.duplicate())
		"pass_visit","report_visit":
			if _radio_contact().get("id") == id:
				_close_visit(id == "report_visit")
		"read_fire_plate": _read_fire_plate()
		"interact": _interact()
		"spot":
			if active and rig.in_cab and account.owns("lamps") and not desk.is_blocking():
				rig.spot_on = not rig.spot_on
				rig._note("Pillar spot · aim with your view." if rig.spot_on else "Pillar spot off.",3.0)
				_save()
		"camera":
			if active and not desk.is_blocking() and rig.in_cab:
				rig.toggle_driving_view()
				_save()
		"fax": _file_invoice()
		"read_field":
			if book_read or (held and not bay_locked and not rig.in_cab and _near(BAY,4.8)):
				_read_book()
		"return_deputy_call":
			if _deputy_callback() and desk.page == "custody" and rig.in_cab and rig.is_stopped():
				desk.show_document("deputy_call",state)
				_speak("KOWALSKI","Brandt, one more thing about Thirty-eight. Did you go through the pickup?")
		"told_open","told_closed":
			if _deputy_callback() and desk.page == "deputy_call" and rig.in_cab:
				survey.custody_reply = id
				desk.dismiss()
				_speak("KOWALSKI","All right. If there’s a thermos in there, leave it where he can reach it." if id == "told_open" else "All right. He always locked the passenger side first. Habit of his.")
				_save()
		"cab_heat":
			if active and rig.in_cab and rig.is_stopped():
				desk.show_document("cab_heat",state)
		"blower_off","blower_low","blower_high","window_latch":
			if desk.page == "cab_heat" and rig.in_cab and rig.is_stopped():
				if id == "window_latch":
					rig.climate.cracked = not rig.climate.cracked
				else:
					rig.climate.blower = ["blower_off","blower_low","blower_high"].find(id)
				_save()
		"settings_anchors":
			rig.assist = not rig.assist
			rig._update_highlight()
			_save_options()
		"settings_voice":
			audio.set_spoken(not audio.spoken)
			_save_options()
		"settings_30","settings_60":
			Engine.max_fps = 30 if id == "settings_30" else 60
			_save_options()
		"broadcast_am","broadcast_fm","broadcast_off":
			if rig.in_cab and desk.broadcast_open and broadcast.tune(id.trim_prefix("broadcast_")):
				broadcast.advance(0.,self)
				_save()
		"scanner_highway","scanner_garage","scanner_sheriff","scanner_off":
			if rig.in_cab and desk.scanner_open and scanner.tune(id.trim_prefix("scanner_"),account.owns("scanner")):
				audio.stop_scanner()
				if speaker.begins_with("SCANNER  /  "): sub_time = 0
				_save()
		"tank_main","tank_reserve":
			if desk.page == "bulk_pump" and account.owns("aux_tank") and not rig.rollback_active and not desk.nozzle_held():
				nozzle_reserve = id == "tank_reserve"
				nozzle_cents = 0.0
		"buy_rollback","buy_aux_tank","buy_reserve_fuel","buy_second_winch","buy_west_hold","buy_west_lot","buy_yard_pump","buy_coffee_maker","buy_mirrors","buy_lamps","buy_chains","buy_snatch_block","buy_scanner","service_winch","buy_fuel": _shop_purchase(id)
		"buy_coffee":
			if desk.page == "coffee" and _at_counter() and rig.coffee_left <= 0 and account.buy_coffee():
				rig.warmth = 1.0
				rig.coffee_left = Rig.HOT_COFFEE_SECONDS
				desk.dismiss()
				_speak("MAI","Seventy-five cents. Here, take the lid. It'll stay warm on the way out.")
				_save()
		"talk_mai":
			if desk.page == "coffee" and _at_counter():
				desk.dismiss()
				if sightings.seen.has("streetlights_out") and not mai_lot_heard:
					mai_lot_heard = true
					_say("mai_lot")
				else:
					var lines := ["Leave the truck out front. I'll hear the county radio from here.","Milk truck came through before the plow tonight. Took his coffee with him.","The pot with the orange handle is decaf. Nobody touches that one on nights."]
					_speak("MAI",lines[completed % lines.size()])
				_save()
		"roadside_fuel":
			if _needs_fuel_can():
				_clear_fuel_plow()
				fuel_wait_left = ShopAccount.CAN_ETA_MINUTES
				_speak("COUNTY PLOW","Copy, Brandt. Relief plow here. I have a can in the box. Give me %d minutes." % ShopAccount.CAN_ETA_MINUTES)
				_save()
		"quit":
			_save()
			get_tree().quit()
		_:
			if active and rig.in_cab and id.begins_with("sighting:"):
				var reply := sightings.report(id.trim_prefix("sighting:"),self)
				if not reply.is_empty():
					_speak("DISPATCH",reply)
					_save()
	_refresh()

func _save_options() -> void:
	if not test_session:
		var preferences := ConfigFile.new()
		preferences.set_value("rig","suggested_anchors",rig.assist)
		preferences.set_value("cab","spoken",audio.spoken)
		preferences.set_value("cab","fps",Engine.max_fps)
		if preferences.save(OPTIONS_FILE) != OK:
			push_warning("Could not save cab settings")
	_save()

func _needs_fuel_can() -> bool:
	return fuel_wait_left <= 0.0 and rig.in_cab and rig.is_stopped() and rig.fuel <= 0.0

func _advance_shift_clock(dt: float) -> void:
	shift_seconds += dt
	if fuel_wait_left <= 0.0:
		if is_instance_valid(fuel_plow) and fuel_plow.leave(dt,rig.get_truck_position()):
			_clear_fuel_plow()
		return
	if not is_instance_valid(fuel_plow):
		fuel_plow = FuelPlow.new()
		fuel_plow.setup(county,rig.get_truck_position())
	# Dispatch time runs at one shift minute per second until the plow arrives.
	var elapsed := minf(dt, fuel_wait_left)
	shift_seconds += elapsed * 59.0
	fuel_wait_left -= elapsed
	fuel_plow.approach(fuel_wait_left)
	if fuel_wait_left > 0.0:
		return
	var previous_due := account.fuel_due
	rig.fuel = minf(1.0, rig.fuel + account.roadside_can())
	rig.info_timer = 0.0
	var iou := snappedf(account.fuel_due - previous_due, 0.01)
	var receipt := "$%.2f paid." % (ShopAccount.CAN_PRICE - iou)
	if iou > 0.0:
		receipt += " $%.2f on the county IOU." % iou
	_speak("COUNTY PLOW","Can's in, Brandt. You've got a fifth of a tank. " + receipt)
	_save()

func _clear_fuel_plow() -> void:
	if is_instance_valid(fuel_plow):
		fuel_plow.hide()
		fuel_plow.queue_free()
		fuel_plow = null

func _fuel_eta() -> String:
	return "County plow en route · %d min to fuel delivery" % ceili(fuel_wait_left)

func _at_office() -> bool:
	return not rig.in_cab and _near(FAX,4.4)

func _at_pump() -> bool:
	return not rig.in_cab and (_near(PUMP_ISLANDS[0],4.5) or _near(PUMP_ISLANDS[1],4.5))

func _at_yard_nozzle() -> bool:
	return county.yard_dispenser and not rig.in_cab and _facing(County.Fittings.NOZZLE,2.9)

func _can_pump_at_tank() -> bool:
	return _at_yard_nozzle() and rig.is_stopped() and rig.get_truck_position().distance_to(County.Fittings.NOZZLE) < 13.0

func _can_dispense() -> bool:
	return _at_pump() and _can_refuel() if nozzle_at_esker else _can_pump_at_tank()

func _open_nozzle(at_esker: bool) -> void:
	nozzle_at_esker = at_esker
	nozzle_reserve = false
	nozzle_sale = 0.0
	nozzle_cents = 0.0
	_refresh()
	desk.show_document("bulk_pump",state)

func _buy_diesel(reserve: bool, budget := INF) -> Dictionary:
	var initial:float = rig.reserve_fuel if reserve else rig.fuel
	var capacity:float = Rig.Reserve.CAPACITY if reserve else 1.0
	var sale := account.buy_fuel(initial,budget,capacity)
	if sale.cost > 0.0:
		if reserve:
			rig.reserve_fuel = sale.fuel_after
			rig.aux_tank.set_reading(rig.reserve_fuel)
		else:
			rig.fuel = sale.fuel_after
			_cancel_can_after_refuel()
	return sale

func _cancel_can_after_refuel() -> void:
	if fuel_wait_left > 0.0 and rig.fuel > 0.0:
		fuel_wait_left = 0.0
		_speak("DISPATCH","Copy, Brandt. I'll cancel that fuel delivery.")

func _run_nozzle(dt: float) -> void:
	if not desk.nozzle_held() or not _can_dispense() or (nozzle_reserve and (not account.owns("aux_tank") or rig.rollback_active)):
		return
	# The rollers count whole cents; holding the handle meters $3.60 per second.
	nozzle_cents += dt*360.0
	var cents := floori(nozzle_cents)
	nozzle_cents -= cents
	if cents <= 0: return
	var sale := _buy_diesel(nozzle_reserve,cents/100.0)
	if sale.cost <= 0.0: return
	nozzle_sale = snappedf(nozzle_sale+sale.cost,.01)
	save_timer += dt
	if save_timer >= 1.0: _save()

func _run_transfer(dt: float) -> void:
	if not rig.aux_tank: return
	var amount := 0.0
	if desk.nozzle_held() and rig.reserve_valve_in_reach():
		amount = minf(Rig.Reserve.TRANSFER_RATE*dt,minf(1.0-rig.fuel,rig.reserve_fuel))
	if amount > 0.0:
		rig.fuel += amount
		rig.reserve_fuel -= amount
		_cancel_can_after_refuel()
		save_timer += dt
		if save_timer >= 1.0: _save()
	rig.aux_tank.set_reading(rig.reserve_fuel,amount>0.0)

func _at_counter() -> bool:
	return not rig.in_cab and county.inside_fuel_store(rig.foot) and _facing(county.coffee_counter_point(),2.5)

func _truck_in_yard() -> bool:
	var at: Vector3 = rig.get_truck_position()
	return rig.is_stopped() and county.yard_contains(Vector2(at.x,at.z))

func _can_refuel() -> bool:
	if _at_office():
		return _truck_in_yard()
	return _at_pump() and rig.is_stopped() and rig.get_truck_position().distance_to(PUMP) < 15.0

func _fleet_offered() -> bool:
	return account.owns("rollback") or completed >= 12

func _switch_reason() -> String:
	if mode != "available" or not job.is_empty() or rig.loaded or rig.is_chocked():
		return "Finish the open ticket before changing trucks."
	if fuel_wait_left > 0:
		return "Wait for the plow with the fuel can."
	if not _truck_in_yard(): return "Bring the other truck back to the yard first."
	return ""

func _fit_equipment() -> void:
	rig.tire_chains = account.owns("chains")
	rig.snatch_block = account.owns("snatch_block") and not rig.rollback_active
	rig.second_winch = account.owns("second_winch") and not rig.rollback_active
	rig.fit_reserve(account.owns("aux_tank") and not rig.rollback_active)
	rig.body.heated_mirrors = account.owns("mirrors")
	rig.body.fit_lamps(account.owns("lamps"))
	var extend_lot: bool = account.owns("west_lot")
	var moved_fence: bool = county.west_lot_open != extend_lot
	county.fit_yard(account.owns("yard_pump"),account.owns("coffee_maker"),extend_lot,account.owns("west_hold"))
	ambience.set_brewer(county.yard_brewer)
	_sync_west_bay()
	if moved_fence:
		_display_storage()
	if not account.owns("lamps"):
		rig.spot_on = false

func _sync_west_bay() -> void:
	if is_instance_valid(county.west_bay): county.west_bay.sync(self)

func _handle_west_order(id: String) -> void:
	if desk.page!="west_custody" or not is_instance_valid(county.west_bay) or rig.in_cab: return
	if west_orders.site_action(self)!=west_source: return
	match id:
		"west_accept":
			if west_source!="west_order_book" or west_archive_open: return
			var ticket := west_orders.offer(self)
			if ticket.is_empty(): return
			survey.defer_order()
			_stamp_ticket(ticket)
			desk.dismiss()
			_accept(ticket)
		"west_sign_pickup":
			if west_source!="west_pickup_card" or job.has("pickup_signature"): return
			job.pickup_signature = west_orders.SIGNATURE
			pickup_time = _clock()
			pickup_odo = rig.odo
			job.custody_start = pickup_time
			desk.dismiss()
			_speak("DEPUTY PELZ","Plate matches. My copy stays here. Keep the keys with your signed copy, Brandt.")
		"west_sign_release":
			if west_source!="west_release_card" or not west_orders.can_release(completed) or west_orders.locked: return
			county.west_bay.hand_off(rig,west_orders.current)
			west_orders.sign_release(_clock(),completed)
			_sync_west_bay()
			desk.dismiss()
			_speak("DEPUTY PELZ","I’ve got the keys. I’ll pull out when the lane’s clear. Your signed copy stays in the west book.")
		"west_archive","west_archive_prev","west_archive_next":
			if west_source!="west_order_book" or west_orders.archive.is_empty(): return
			west_archive_open=true
			match id:
				"west_archive": west_page=west_orders.archive.size()-1
				"west_archive_prev": west_page=posmod(west_page-1,west_orders.archive.size())
				"west_archive_next": west_page=posmod(west_page+1,west_orders.archive.size())
		"west_current": west_archive_open=false
	_refresh()
	_save()

func _scanner_available() -> bool:
	return signed_card or held or campaign.released or account.owns("scanner")

func _shop_purchase(id: String) -> void:
	if id in ["buy_fuel","buy_reserve_fuel"]:
		var reserve := id == "buy_reserve_fuel"
		if not _can_refuel() or (reserve and (not account.owns("aux_tank") or rig.rollback_active)): return
		var sale := _buy_diesel(reserve)
		if sale.cost <= 0: return
		var pct := roundi(100*float(sale.fuel_after)/(Rig.Reserve.CAPACITY if reserve else 1.0))
		shop_receipt = "Diesel   $%.2f   ·   %s %d%%" % [sale.cost,"Reserve" if reserve else "Tank",pct]
	elif not _at_office() or not _truck_in_yard():
		return
	elif id == "service_winch":
		if rig.wear <= 0.001 or not account.pay_repair():
			return
		rig.wear = 0.0
		shop_receipt = "Winch serviced. Cable and drum ready."
	else:
		var part := id.trim_prefix("buy_")
		if part == "rollback" and not _fleet_offered(): return
		if part in ["second_winch","aux_tank","snatch_block"] and rig.rollback_active: return
		if part == "scanner" and not _scanner_available(): return
		if part == "aux_tank" and campaign.stage < 1: return
		if part == "west_hold" and not account.owns("west_lot"): return
		if part == "second_winch" and (not heavy_job_filed or not account.owns("snatch_block")): return
		if not account.buy(part):
			return
		_fit_equipment()
		match part:
			"rollback":
				fleet.receive(rig)
				shop_receipt = "Keys in the carrier. Walk to its driver’s door by the office."
			"aux_tank": shop_receipt = "Reserve fitted behind the cab. Fill it here or at the pumps."
			"second_winch": shop_receipt = "Auxiliary winch fitted. Arlene can dispatch freight calls on US 59."
			"west_hold": shop_receipt = "West Hold 2 ready. Sheriff’s order book is under the metal hood beside its chain."
			"west_lot": shop_receipt = "West gate open. Twelve numbered storage spaces on the back lot."
			"yard_pump": shop_receipt = "Meter and hose fitted to the bulk tank by storage."
			"coffee_maker": shop_receipt = "Coffee’s on at the bench beside the office."
			"mirrors": shop_receipt = "Heater elements fitted to both mirrors."
			"lamps": shop_receipt = "Driving bar and pillar spot fitted. Aim the spot by looking."
			"chains": shop_receipt = "Drive-axle chains fitted."
			"snatch_block": shop_receipt = "Snatch block fitted. Heavy pulls cleared for dispatch."
			"scanner": shop_receipt = "Crystals fitted. Tune the cab scanner to Sheriff or Garage."
	audio.effect("fax")
	_save()

func _prepare_offers() -> void:
	visit_offer = {}
	if mode == "available":
		var issued := completed + pending_slips.size()
		visit_offer = CountyVisits.offer(dispatch_seed,slips+pending_slips,issued,declined_visit)
		if rotation_offer.is_empty() and campaign.stage >= 2:
			rotation_offer = sightings.recovery_offer(issued,county,account.owns("snatch_block"),campaign.stage == Campaign.ORDER.size(),account.owns("second_winch"))
		if rotation_offer.is_empty():
			rotation_offer = Dispatch.ordinary(issued,dispatch_seed,slips + pending_slips,account.owns("snatch_block"),account.owns("second_winch"))
			_stamp_ticket(rotation_offer)
		else:
			# A case may have used the next blank on the clipboard.
			rotation_offer.number = 1001 + issued
		if rig.rollback_active and not RollbackDeck.supports(rotation_offer):
			if fleet.alternate_offer.is_empty():
				fleet.alternate_offer = Dispatch.ordinary(issued,dispatch_seed,slips + pending_slips,false,false)
				_stamp_ticket(fleet.alternate_offer)
			fleet.alternate_offer.number = 1001 + issued
		else:
			fleet.alternate_offer = {}
		if case_offer.is_empty():
			match survey.pending_order():
				"hold":
					case_offer = Dispatch.hold_ticket(issued,audio.lines,true)
					case_offer.point = county.survey_point
					case_offer.angle = county.survey_yaw
					_stamp_ticket(case_offer)
				"looksee": case_offer = Dispatch.looksee(issued)
		if not case_offer.is_empty():
			case_offer.number = 1001 + issued
	_sync_waiting_hazard()

func _stamp_ticket(ticket: Dictionary) -> void:
	if ticket.get("kind") not in ["hazard","hold"] or ticket.get("untaped",false) or ticket.has("checked_tape") or ticket.has("recovery"):
		return
	var road := str(ticket.get("road",ticket.get("location",""))).get_slice(" · ",0)
	ticket.checked_tape = Rig.Scene.Tape.write(road,str(ticket.get("vin","")).hash(),shift_seconds,ticket.kind == "hold")
	if ticket.has("sheriff_order"):
		ticket.checked_tape.deputy = "Pelz"
		ticket.checked_tape.badge = "412"

func _offered_rotation() -> Dictionary:
	if rig.rollback_active and not fleet.alternate_offer.is_empty():
		return fleet.alternate_offer
	return rotation_offer

func _sync_waiting_hazard() -> void:
	var offer := _offered_rotation()
	var waiting: bool = offer.get("kind") == "hazard" and not offer.has("aftermath_key") and offer.get("recovery") not in ["semi","milk"]
	var point: Vector3 = county.resolve_point(offer.point) if waiting else Vector3.ZERO
	if is_instance_valid(waiting_hazard):
		if waiting and waiting_hazard.get_meta("offer_pose") == [offer.vin, point, offer.angle]:
			return
		waiting_hazard.hide()
		waiting_hazard.queue_free()
		waiting_hazard = null
	if waiting:
		waiting_hazard = rig.store_vehicle(offer.route,point,offer.angle,offer)
		waiting_hazard.set_meta("offer_pose",[offer.vin, point, offer.angle])

func _take_rotation() -> void:
	if not rig.in_cab or mode != "available":
		return
	_prepare_offers()
	if _can_track_lead() and survey.tracked_lead.is_empty():
		campaign.calls_past_lead += 1
	survey.defer_order()
	_accept(_offered_rotation())

func _favor_request() -> String:
	var chapter := campaign.chapter()
	if (chapter == "unit" and survey.notes.has("unit")) or (chapter == "farm" and survey.notes.has("house")):
		return casework.lead_instruction()
	return Campaign.FAVOR_REQUESTS[chapter]

func _dispatch_lead_briefing() -> String:
	if not _can_track_lead():
		return Campaign.LEADS.get(campaign.chapter(),"") if mode == "available" and _case_due() else ""
	var unpaid := not casework.lead_site().is_empty()
	var label := "Optional unpaid favor" if unpaid else "Optional county case"
	var words := _favor_request() if unpaid else casework.lead_instruction()
	if not survey.tracked_lead.is_empty():
		return "Tracking %s. %s" % [casework.lead_label(),casework.lead_instruction()]
	match campaign.reminder_level():
		2: return "%s / %s Track the lead for directions to your next step." % [label,casework.lead_instruction()]
		1: return "%s / %s %s" % [label,words,"Track this stop to follow up on the survey case." if unpaid else "Track this call to pick up the case."]
	return "%s / %s" % [label,words]

func _check_lead_reminder(elapsed: float) -> void:
	if not rig.in_cab or _needs_fuel_can() or fuel_wait_left > 0 or not survey.tracked_lead.is_empty() or not _can_track_lead():
		return
	if not rig.is_stopped():
		campaign.lead_drive_seconds += elapsed
	if sub_time > 0 or not sightings.active.is_empty() or (campaign.calls_past_lead == 0 and campaign.lead_drive_seconds < 120):
		return
	var level := campaign.reminder_level()
	if level <= campaign.last_reminder:
		return
	campaign.last_reminder = level
	var words := casework.lead_instruction()
	if not casework.lead_site().is_empty():
		match level:
			0: words = "Small favor if you’re out that way. " + _favor_request()
			1: words = "Still have that unpaid stop at %s. Track it on the radio and I’ll talk you in." % casework.lead_label()
			2: words = "If you want to follow up on the county case, here’s your next step. " + words
	else:
		words = "County case is still open. " + words
	_speak("DISPATCH",words)
	_save()

func _case_due() -> bool:
	return campaign.due() and not pending_slips.any(func(slip): return slip.get("case_id") == campaign.chapter())

func _can_track_lead() -> bool:
	if not _case_due():
		return false
	if campaign.chapter() == "unit":
		return not held and job.get("kind") != "hold"
	if campaign.chapter() == "farm":
		return job.get("id") != "n5104"
	return job.get("case_id","") != campaign.chapter()

func _finish_favor(chapter: String) -> void:
	if survey.tracked_lead == chapter and casework.lead_site().is_empty():
		survey.tracked_lead = ""

func _radio_contact() -> Dictionary:
	if not rig.in_cab:
		return {}
	if mode == "fieldwork" and job.get("kind") == "field_visit":
		if int(job.visit_step) >= 2:
			return {"id":"report_visit","label":CountyVisits.CHECKS[job.id].report}
		return {"id":"pass_visit","label":"Return visit to county"}
	if campaign.chapter() == "unit" and _case_due() and survey.can_report_unit():
		return {"id":"report_unit","label":"Report Unit 38 and rod case"}
	if not _case_lock().is_empty():
		return {}
	var report := casework.report_label(campaign.chapter())
	if _case_due() and mode == "available" and not report.is_empty():
		return {"id":"report_notes","label":report}
	if not survey.pending_order().is_empty() and mode == "available":
		if survey.pending_order() == "hold":
			return {"id":"take_case","label":"Meet Kowalski at Unit 38"}
		return {"id":"take_case","label":"Take the N5104 look-see"}
	if campaign.chapter() == "farm" and _case_due() and survey.can_request_farm() and report.is_empty():
		return {"id":"ask_farm","label":"Ask about N5104 Kolpack"}
	if mode == "fieldwork" and job.get("id") == "n5104" and survey.notes.has("house") and survey.notes.has("farm_ring"):
		return {"id":"report_farm","label":"Report the empty Hoffmann place"}
	return casework.contact()

func _case_lock() -> String:
	if mode != "available":
		return ""
	if rig.rollback_active:
		var detail := case_offer
		if detail.is_empty() and _case_due() and Campaign.DETAILS.has(campaign.chapter()):
			detail = campaign.ticket(1001 + completed + pending_slips.size())
		if not detail.is_empty() and not RollbackDeck.supports(detail):
			return "Collect the wrecker at Brandt’s yard for this call."
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
			survey.tracked_lead = ""
			survey.hold_order = "offered"
			_speak("DISPATCH","Copy. Prints stop in open snow. Nothing from Tou on the county channel. Kowalski opened TC-96-031. Call for her hold when you’re clear.")
		"ask_farm":
			survey.farm_order = "offered"
			_speak("DISPATCH","Hoffmann place. Milk hauler says every light is on. He knocked twice. I can give you the look-see when you’re free.")
		"take_case":
			_prepare_offers()
			if rig.rollback_active and not RollbackDeck.supports(case_offer):
				_accept(case_offer)
				return
			if survey.pending_order() == "hold":
				survey.hold_order = "accepted"
			else:
				survey.farm_order = "accepted"
			_accept(case_offer)
		"report_farm","report_detail","report_notes":
			if id == "report_notes":
				# Issue the usual field-service slip against the operator's observations.
				# The paid order and its fax are still recorded once, in order.
				var issued := completed + pending_slips.size()
				if campaign.chapter() == "farm":
					survey.farm_order = "accepted"
					case_offer = {}
					job = Dispatch.looksee(issued)
				else:
					job = campaign.ticket(1001 + issued)
				_start_fieldwork()
			_record_visit()
			if job.get("id") == "n5104":
				survey.farm_reported = true
				_speak("DISPATCH","Copy. Supper on the table and the car gone. I’ll let the milk hauler know. Fax it when you’re in.")
			else:
				_speak("DISPATCH",job.report)
			_clear_field_job()
	_prepare_offers()
	_save()

func _accept(ticket: Dictionary) -> void:
	if rig.rollback_active and not RollbackDeck.supports(ticket):
		_speak("DISPATCH","Bring the wrecker for that one. I’ll hold the order while you change trucks at the yard.")
		return
	job = ticket
	if job.has("aftermath_key"):
		sightings.claim_recovery(job)
	if not fleet.alternate_offer.is_empty() and job == fleet.alternate_offer:
		fleet.alternate_offer = {}
		_sync_waiting_hazard()
	elif (not job.has("case_id") and not job.has("sheriff_order") and job.kind in ["ditch","hazard","passenger"]) or (job.get("case_id") == "angie" and rotation_offer.get("vin") == job.vin):
		rotation_offer = {}
		_sync_waiting_hazard()
	if job == case_offer:
		case_offer = {}
	_start_fieldwork()
	var call_text: String = job.dispatch
	if not survey.tracked_lead.is_empty() and not casework.lead_site().is_empty():
		call_text += " I’ll hold that pickup for you. Your next stop is still %s." % casework.lead_label()
	elif Rig.uses_warning_triangle(job.kind,job):
		call_text += " Look for the red triangle."
	_speak("DISPATCH",call_text)
	speaker = "DISPATCH  ·  CONTRACT %d ACCEPTED" % job.number
	_save()

func _close_visit(reported: bool) -> void:
	var row: Dictionary = CountyVisits.CHECKS[job.id]
	if reported:
		_record_visit()
		_clear_field_job()
		_speak("DISPATCH",row.ack)
	else:
		declined_visit = int(job.visit_round)
		job = {}
		mode = "available"
		_speak("DISPATCH","Copy, I'll pass that check along. Your regular tow is still on the board.")
	visits.sync(job)
	_prepare_offers()
	_refresh()
	_save()

func _start_fieldwork() -> void:
	mode = "fieldwork"
	if not _can_track_lead():
		survey.tracked_lead = ""
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
	if job.kind not in ["looksee","field_visit"]:
		rig.start_job(job.kind,county.resolve_point(job.point),job.angle,job)
	else:
		rig.end_job()
	_sync_survey_scene()
	visits.sync(job)

func _restart_on_recovery() -> bool:
	return mode in ["fieldwork","haul"] or (job.get("case_id") == "ride" and not campaign.released)

func _recover_to_yard() -> void:
	casework.leave_tower()
	sightings.finish(self)
	rig.recover_to_yard(SPAWN,-PI/2)
	fuel_wait_left = 0.0
	_clear_fuel_plow()
	var message := "You and the wrecker are back at Brandt’s yard."
	if _restart_on_recovery():
		if job.get("case_id") == "ride":
			campaign.evidence.erase("passenger")
		_start_fieldwork()
		message += " Contract %04d restarts at the original call." % job.number
	var unpaid := account.pay_yard_recovery()
	message += " Yard tow $%.2f." % ShopAccount.YARD_RECOVERY_PRICE
	if unpaid > 0.0:
		message += " $%.2f on account." % unpaid
	desk.start_play()
	_message("COUNTY GARAGE",message)
	_save()

func _directions() -> void:
	if fuel_wait_left > 0.0:
		_speak("DISPATCH",_fuel_eta())
		return
	if _needs_fuel_can():
		_speak("DISPATCH",rig.reserve_hint() if rig.reserve_fuel > .0001 else "Duane can bring diesel. Request a fuel can on the cab radio.")
		return
	var words: String = _road_note().get("instruction","")
	if not words.is_empty():
		if mode == "haul" and survey.tracked_lead.is_empty() and not words.contains(rig.dropoff.sign):
			words += " You're delivering to %s." % rig.dropoff.sign
		_speak("DISPATCH",words)
	elif mode == "available":
		_speak("DISPATCH","Standing by when you're ready to take the contract.")
	elif job.get("kind") == "passenger" and rig.phase == "passenger":
		_speak("DISPATCH",Rides.approach(job))
	elif mode == "haul":
		if job.has("sheriff_order") or rig.axle_fault: _speak("DISPATCH",rig.dropoff.approach)
		else: _say(rig.dropoff.radio)
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
	if received_pool_car and pos.distance_to(received_pool_car.global_position)>190 and not _near(received_pool_car.global_position,190):
		_set_pool_receipt({})
	if received_freight and pos.distance_to(received_freight.global_position)>190 and not _near(received_freight.global_position,190):
		received_freight.queue_free()
		received_freight = null
	if campaign.released and not campaign.evidence.has("unit_departed") and pos.distance_to(BAY) > 140 and not _near(BAY,140):
		campaign.evidence["unit_departed"] = rig.odo
		_display_storage()
		_save()
	var street := _current_road_map().driven_road(Vector2(pos.x,pos.z))
	if not street.is_empty() and not street in roads_driven:
		roads_driven.append(street)
	if completed >= 2 and not plow_heard and pos.distance_to(SPAWN) > 110 and sightings.active.is_empty():
		plow_heard = scanner.plow_call(self)
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
	if mode == "fieldwork" and job.get("kind") == "passenger" and rig.phase == "passenger" and rig.is_stopped():
		if Rides.at_drop(job,rig.get_truck_position()) and (rig.in_cab or _facing(rig._passenger_step(),2.3)):
			return "let_out"
	if casework.tower_height >= 0.0:
		return casework.tower_action()
	if rig.reserve_valve_in_reach(): return "reserve_valve"
	if rig.in_cab or rig.at_dry_rig_door():
		return ""
	var west_site := west_orders.site_action(self)
	if not west_site.is_empty(): return west_site
	if is_instance_valid(fleet.model) and _facing(fleet.door(),2.45):
		return "fleet_door"
	if rig.ems_partner and rig.phase != "scene" and _facing(rig.ems_partner.position,3.3):
		return "cot_inside"
	if CountyVisits.step_in_reach(self):
		return "visit_stop"
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
		return "offer_ride"
	elif mode == "fieldwork" and (job.get("kind") == "ditch" or rig.semi or rig.tanker) and not talked and _facing(rig.get_witness_position(),3.9):
		return "driver"
	# The panel and doors can sit within reach of the fax, chain or field book.
	if rig.action_id() == "drop" or (held and _near(BAY,16.0) and rig.action_id() == "enter"):
		return ""
	if _facing(FAX,4.4):
		return "fax"
	if _facing(County.Fittings.REGISTER,2.6):
		return "impound_register"
	if _at_yard_nozzle():
		return "bulk_pump"
	if county.yard_brewer and _facing(County.Fittings.COFFEE,2.7):
		return "yard_coffee"
	if held and _facing(county.bay_latch_point(),2.7):
		return "unlock" if bay_locked else "lock"
	if held and not bay_locked and is_instance_valid(held_pickup):
		var hinge := held_pickup.get_node("DriverDoor") as Node3D
		if hold_door_open and _facing(hinge.to_global(Vector3(-.07,.46,1.16)),1.35):
			return "close_unit_door"
		if _facing(held_pickup.to_global(Vector3(-.62,.85,-.18)),4.0):
			return "field"
	if _facing(County.Dryhouse.grower_position(county),3.1):
		return "grower"
	if _at_counter():
		return "coffee"
	if _facing(PUMP_ISLANDS[0],4.5) or _facing(PUMP_ISLANDS[1],4.5):
		return "fuel"
	if rig.action_id() in ["","enter"] and rig.wipeable_mirror() >= 0:
		return "wipe_mirror"
	if rig.action_id().is_empty() and is_instance_valid(Rig.Scene.Tape.readable(rig)):
		return "checked_tape"
	if rig.action_id().is_empty() and _storage_row_in_reach() >= 0:
		return "storage_tag"
	if rig.action_id().is_empty() and not sightings.observations.inspectable(self,sightings).is_empty():
		return "inspect_sighting"
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
	if casework.tower_height >= 0.0 and site.is_empty():
		return
	if Casework.PROMPTS.has(site):
		casework.inspect(site)
		_save()
		return
	match site:
		"fleet_door":
			var reason := _switch_reason()
			if not reason.is_empty():
				_message("BRANDT",reason)
			else:
				fleet.switch_trucks(self)
				_prepare_offers()
				_message("BRANDT","Carrier keys." if rig.rollback_active else "Wrecker keys.")
		"visit_stop":
			var step := int(job.visit_step)
			if job.id == "dryhouse" and step == 0 and visits.flashes_seen < 2:
				_message("BRANDT","Something on that wall is blinking. I'll watch for a second flash.")
				return
			var row: Dictionary = CountyVisits.CHECKS[job.id]
			_speak(row.speaker if step == 1 else "BRANDT",row.observations[step])
			job.visit_step = step+1
			visits.sync(job)
			_save()
		"grower":
			_speak("ROMAN DUDA",County.Dryhouse.say(job,grower_visits))
			grower_visits += 1
		"inspect_sighting":
			var note := sightings.observations.inspectable(self,sightings)
			if not note.is_empty():
				sightings.observations.remember(note)
				_message("BRANDT",sightings.Reports.inspection(note.kind))
				_save()
		"unit","rod","house","farm_ring":
			survey.record(site,rig.odo)
			if site == "farm_ring":
				sightings.observations.remember({"key":site,"kind":site})
			if site in ["house","farm_ring"]:
				_finish_favor("farm")
			if site == "rod":
				county.set_rod_case_read(true)
			var entry := {
				"unit":"Survey Unit 38. Engine’s running. Driver’s door wide open. Boot prints head north from the tripod.",
				"rod":"Left boot, then nothing. Open snow all around. Tou’s rod case is dry enough to write on.",
				"house":"N5104. All the lights on, the door open. Two places set for supper. Nobody answers.",
				"farm_ring":"Bare, wet ground in a circle where the Hoffmanns parked. No tire tracks across the snow."}
			_message("BRANDT",entry[site])
		"west_order_book","west_pickup_card","west_release_card":
			west_source = site
			west_archive_open = false
			_refresh()
			desk.show_document("west_custody",state)
		"west_chain":
			if not west_orders.locked:
				var blocked := west_orders.obstruction(self)
				if not blocked.is_empty():
					_message("BRANDT",blocked)
					return
			elif not west_orders.can_release(completed):
				_message("BRANDT","Sheriff has the hold. Leave the chain locked until the release comes in.")
				return
			west_orders.locked = not west_orders.locked
			if west_orders.locked: west_orders.current.secured = _clock()
			audio.rig_effect("ratchet")
			_sync_west_bay()
			_message("BRANDT","West hold secured. I'll mark the copy." if west_orders.locked else "Chain open. The deputy can sign for the car.")
		"tripod":
			packed_tripod = true
			county.set_tripod_collected(true)
			audio.rig_effect("ratchet")
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
		"offer_ride":
			if rig.get_truck_position().distance_to(rig.get_witness_position()) > 23.0:
				_message("DRIVER","Can you bring the passenger door a little closer?")
				return
			if rig.offer_front_seat():
				pickup_time = _clock()
				pickup_odo = rig.odo
				_speak("DRIVER",Rides.rider(job).pickup)
		"let_out":
			if rig.let_rider_out(job):
				drop_odo = rig.odo
				drop_time = _clock()
				_speak("DRIVER",Rides.rider(job).arrival)
				_clear_field_job()
				rig.end_job()
				_sync_survey_scene()
				_prepare_offers()
		"cot_inside":
			if rig.send_cot_inside():
				_speak("EMT KIT","I’ve got the cot. I’ll take it in through the lit doors.")
		"driver":
			talked = true
			if job.has("driver_line"): _speak(job.person,job.driver_line)
			else: _say(job.reply)
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
			audio.rig_effect("ratchet")
			_message("BRANDT","Bay secured. Key back on the ring." if bay_locked else "Hold bay open.")
		"close_unit_door":
			hold_door_open = false
			Rig.Scene.close_driver_door(held_pickup)
			audio.effect("door")
		"field": _read_book()
		"wipe_mirror":
			var side: int = rig.wipeable_mirror()
			if side >= 0:
				rig.body.set_mirror_ice(side,0)
				rig._note("Glass wiped clean.",3.0)
		"checked_tape":
			var strip := Rig.Scene.Tape.readable(rig)
			if strip:
				open_tape = strip.get_meta("imprint").duplicate()
				open_tape.plate = strip.get_meta("plate","")
				var note := sightings.observations.inspectable(self,sightings)
				if note.get("kind") == "roadside_tape":
					sightings.observations.remember(note)
				_refresh()
				desk.show_document("checked_tape",state)
				_save()
		"impound_register":
			impound_book.open(stored,slips,PARKING.size(),County.Fittings.WEST_STALLS if county.west_lot_open else 0)
			desk.show_document("impound_register",state)
		"storage_tag":
			yard_card = _storage_tag(_storage_row_in_reach())
			_refresh()
			desk.show_document("storage_tag",state)
		"bulk_pump": _open_nozzle(false)
		"reserve_valve":
			_refresh()
			desk.show_document("reserve_transfer",state)
		"yard_coffee":
			if rig.coffee_left > 0:
				_message("BRANDT","Still have coffee in my cup.")
			else:
				rig.warmth = 1.0
				rig.coffee_left = Rig.HOT_COFFEE_SECONDS
				ambience.pour_coffee()
				_message("BRANDT","Fresh cup for the road.")
		"coffee":
			_refresh()
			desk.show_document("coffee",state)
		"fuel":
			if account.owns("aux_tank") and not rig.rollback_active: _open_nozzle(true)
			else: _open_shop()
		_:
			if mode == "fieldwork" and job.has("sheriff_order") and not job.has("pickup_signature") and rig.action_id()=="flare":
				_message("DEPUTY PELZ","Check the plate and sign my transfer order first.")
				return
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
	if (kind != "hold" and not job.has("sheriff_order")) or pickup_time.is_empty():
		pickup_odo = rig.get_status().odo
		pickup_time = _clock()
	if kind == "ditch":
		if rig.redirect: job.pull = "Tree strap and snatch block" if rig.redirect.route_used else "Straight pull through the gate"
		drop_odo = pickup_odo
		drop_time = pickup_time
		if job.get("vin") == Dispatch.Ambulance.VIN:
			_speak("EMT NOVAK","Four wheels on pavement. I’ll bring the unit back around for Kit. Thanks, Brandt.")
		elif talked:
			_say("clear")
		else:
			_say(job.reply)
		_clear_field_job()
		_prepare_offers()
	else:
		mode = "haul"
		if rig.axle_fault:
			job.handling = rig.axle_fault.method(rig)
			job.diagnosis = rig.axle_fault.finding() if rig.axle_fault.checked else "Shop inspection requested."
		_speak("DISPATCH",job.get("haul_line","Copy, Brandt. Bring this one to %s." % rig.dropoff.sign))
	_refresh()
	_save()

func _set_pool_receipt(record: Dictionary) -> void:
	if received_pool_car:
		received_pool_car.hide()
		received_pool_car.queue_free()
		received_pool_car = null
	pool_receipt = record
	if record.is_empty(): return
	received_pool_car = Rig.Scene.car(world,"hazard",int(record.variant),record)
	received_pool_car.position = Vector3(record.x,0,record.z)
	received_pool_car.position.y = rig._ground(received_pool_car.position)
	received_pool_car.rotation.y = record.yaw

func _dropped() -> void:
	if mode != "haul":
		return
	drop_odo = rig.get_status().odo
	drop_time = _clock()
	if rig.axle_fault:
		var receipt := {"x":rig.car.position.x,"z":rig.car.position.z,"yaw":rig.car.rotation.y}
		for key in ["number","variant","plate","vin","wheel_side","wheel_fault"]:
			receipt[key] = job[key]
		_set_pool_receipt(receipt)
		rig.end_job()
		_clear_field_job()
		_prepare_offers()
		_message("COUNTY HIGHWAY SHOP","Keys received at door three. Your repair copy is ready to fax.")
		_refresh()
		_save()
		return
	if rig.semi or rig.tanker:
		var milk: bool = rig.tanker != null
		if received_freight:
			received_freight.queue_free()
		received_freight = rig.car
		received_freight.reparent(world,true)
		received_freight.settle(rig._ground)
		rig.car_lamps.hide()
		rig.car_lamps.queue_free()
		rig.car = null
		rig.semi = null
		rig.tanker = null
		rig.end_job()
		_clear_field_job()
		_prepare_offers()
		if milk:
			_message("MILK HOUSE","Seal matches. We'll take the milk from here. You've got your transfer copy.")
		else:
			_message("RIVER LANES","We've got the tractor and the box. Keep your copy for the county.")
		_refresh()
		_save()
		return
	mode = "invoice"
	if job.has("sheriff_order"):
		west_orders.receive(job,drop_time,drop_odo,rig.car)
		_sync_west_bay()
	elif job.kind == "hold":
		held = true
		held_tape = Rig.Scene.Tape.imprint(job)
		filed_card = _custody_record()
		_sync_survey_scene()
	else:
		stored.append({"number":job.number,"route":job.route,"variant":job.get("variant",2),"plate":job.plate,"vin":job.vin,
			"heavy_recovery":job.get("heavy_recovery",false),"vehicle":job.get("vehicle",""),"location":job.get("location",""),"time":drop_time,
			"checked_tape":Rig.Scene.Tape.imprint(job),"untaped":job.get("untaped",false)})
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
	held_pickup = null
	for node in physical_cars:
		if is_instance_valid(node):
			node.hide()
			node.queue_free()
	physical_cars.clear()
	if held or (campaign.released and not campaign.evidence.has("unit_departed")):
		held_pickup = rig.store_vehicle("hold",BAY,-PI/2,{"checked_tape":held_tape,"open_door":true})
		if not hold_door_open:
			Rig.Scene.close_driver_door(held_pickup)
		physical_cars.append(held_pickup)
	var capacity := PARKING.size()+(County.Fittings.WEST_STALLS if county.west_lot_open else 0)
	for i in mini(stored.size(),capacity):
		var entry: Dictionary = stored[i] if stored[i] is Dictionary else {"route":stored[i]}
		var facing := 0.0 if entry.get("turned_north",false) or int(entry.get("number",i)) % 2 == 0 else PI
		var stall: Vector3 = PARKING[i] if i < PARKING.size() else County.Fittings.west_stall(i-PARKING.size())
		var ticket := entry.duplicate()
		ticket["yard_tag"] = str(entry.get("number","YARD"))
		var car = rig.store_vehicle(entry.route,stall,facing,ticket)
		if car is Node3D:
			car.set_meta("storage_row",i)
			physical_cars.append(car)

func _storage_row_in_reach() -> int:
	if rig.in_cab or not county.yard_contains(Vector2(rig.foot.x,rig.foot.z)):
		return -1
	for car: Node3D in physical_cars:
		if car.has_meta("storage_row") and _facing(car.global_position,3.1):
			return int(car.get_meta("storage_row"))
	return -1

func _storage_tag(index: int) -> Dictionary:
	if index < 0 or index >= stored.size():
		return {}
	var paper: Dictionary = impound_book.record(stored[index],index,PARKING.size(),County.Fittings.WEST_STALLS if county.west_lot_open else 0)
	# Early impounds stored the vehicle details on their carbon copy.
	if not paper.has("vehicle") or not paper.has("time"):
		var number := int(paper.get("number",-1))
		for slip in slips:
			if int(slip.get("number",0)) == number:
				paper.merge(slip)
				break
	return paper

func _read_fire_plate() -> void:
	if not active or desk.is_blocking() or casework.tower_height >= 0:
		return
	var id := Addresses.readable(rig,county)
	if not id.is_empty():
		desk.show_document("map",state)
		desk.open_fire_index(id)

func _deputy_callback() -> bool:
	return held and survey.hold_order == "filed" and survey.custody_reply.is_empty()

func _read_book() -> void:
	if held and not bay_locked and not rig.in_cab and _near(BAY,4.8) and is_instance_valid(held_pickup):
		if not hold_door_open:
			audio.effect("door")
		hold_door_open = true
		var hinge := held_pickup.get_node("DriverDoor") as Node3D
		hinge.rotation.y = -1.04
	book_read = true
	_refresh()
	desk.show_document("field",state)
	_save()

func _current_slip() -> Dictionary:
	var slip := Dispatch.issue_slip(job,dispatch_odo,pickup_odo,drop_odo,seconds_worked,drop_time if not drop_time.is_empty() else _clock(),campaign.released)
	if job.has("sheriff_order"):
		slip.sheriff_order = job.sheriff_order
		slip.destination = County.WestBay.DROP.sign
		slip.custody_fee = 20
		slip.pay += slip.custody_fee
		slip.receipt = "%s   /   WEST HOLD 2\n%s · %s\nReceived from %s by Brandt at %s.\nArrived %s  /  ODO %.1f. Chain secured %s." % [job.sheriff_order,job.vehicle,job.plate,job.pickup_signature,job.custody_start,drop_time,drop_odo,west_orders.current.secured]
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
	if job.has("sheriff_order") and not west_orders.locked: return "Lock West Hold 2 before filing the signed order."
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
	heavy_job_filed = heavy_job_filed or float(slip.get("heavy_fee",0.0)) > 0.0
	completed += 1
	if slip.has("sheriff_order") and west_orders.current.get("sheriff_order","")==slip.sheriff_order:
		west_orders.current.filed_at = completed
	_sync_west_bay()
	var prior_fuel_due := account.fuel_due
	var prior_recovery_due := account.recovery_due
	var payment := account.file_invoice(slip.pay,completed)
	if case_id == "unit":
		survey.hold_order = "filed"
	elif case_id == "farm":
		survey.farm_order = "filed"
	fax_text = "TO  BRANDT TOWING & RECOVERY\nRE  SERVICE SLIP %04d\n\nReceived for county review.\nCall-out  $%d    Hookup  $%d\nWinch  $%d    Storage  $%d\nLoaded  %.1f mi @ $3.25" % [slip.number,slip.call_out,slip.hookup,slip.winch,slip.storage,slip.loaded]
	if slip.kind == "field_visit":
		fax_text += "\nFinding   "+str(slip.finding)
	if slip.has("sheriff_order"):
		fax_text += "\nSecured hold  $%.2f   /   %s" % [slip.custody_fee,slip.sheriff_order]
	elif west_orders.can_release(completed) and completed==int(west_orders.current.filed_at)+1:
		slip.receipt = (str(slip.receipt)+"\f" if slip.has("receipt") else "")+"SHERIFF RELEASE / %s\nPlate %s. Meet Deputy Pelz at West Hold 2. Unlock the chain and countersign for the vehicle." % [west_orders.current.sheriff_order,west_orders.current.plate]
	if slip.heavy_fee > 0:
		fax_text += "\nHeavy recovery  $%d" % slip.heavy_fee
	if slip.get("recovery") == "semi":
		fax_text += "\nReceived at River Lanes truck stop"
	elif slip.has("wheel_fault"):
		fax_text += "\nCounty shop   /   REPAIR 03\n%s\n%s" % [slip.get("diagnosis","Shop inspection requested."),slip.handling]
	elif slip.get("recovery") == "milk":
		fax_text += "\nBrzezinski transfer   %d gal   /   Seal %s" % [int(slip.gallons),slip.seal]
	if slip.has("field_gate"):
		fax_text += "\nPasture gate   /   " + str(slip.pull)
	if slip.has("clearance_bonus"):
		var responder := "Ambulance" if slip.get("vin") == Dispatch.Ambulance.VIN else "Squad"
		fax_text += "\n%s clearance  %s    Bonus  $%.2f" % [responder,Dispatch.Squad.clock(slip.clearance_seconds),slip.clearance_bonus]
	if slip.get("rate_fee",0) > 0:
		fax_text += "\n%s  $%.2f" % [slip.rate_name,slip.rate_fee]
	fax_text += "\nNet invoice  $%.2f\n\nD. Pfaff  /  Accounts Payable" % slip.pay
	if payment > 0:
		fax_text += "\n\nBATCH PAYMENT ISSUED   $%.2f" % payment
		if prior_fuel_due > account.fuel_due:
			fax_text += "\nLess county fuel can   $%.2f" % (prior_fuel_due-account.fuel_due)
		if prior_recovery_due > account.recovery_due:
			fax_text += "\nLess yard recovery   $%.2f" % (prior_recovery_due-account.recovery_due)
		# A later tow may already be parked when an earlier invoice settles the batch.
		stored = stored.filter(func(car): return car is Dictionary and car.get("number",0) > slip.number)
		_display_storage()
	if slip.has("receipt"):
		fax_text += "\f" + str(slip.receipt)
	if not lead.is_empty():
		fax_text += "\f" + lead
		if campaign.chapter() == "unit":
			fax_text += "\n\nThis is an unpaid check. Your regular slip stays open. Radio the garage with what you find."
		elif not campaign.required_equipment().is_empty() and not account.owns(campaign.required_equipment()):
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
	if not who.begins_with("SCANNER  /  "):
		audio.stop_scanner()
		scanner.rx_left = 0
	speaker = who
	subtitle = words
	sub_time = caption.prepare(words)

func _clock() -> String:
	var minutes := 3*60+14+floori(shift_seconds/60.0)
	return "%02d:%02d" % [floori(minutes/60.0)%24,minutes%60]

func _procedure() -> String:
	if job.get("kind") == "field_visit":
		return CountyVisits.instruction(job)
	if job.has("case_id") and (mode == "fieldwork" or job.case_id == "ride"):
		var instruction := casework.procedure()
		if not instruction.is_empty():
			return instruction
	if job.get("vin") == Dispatch.Ambulance.VIN and rig.cot_at_line():
		if rig.phase == "scene": return "Flare the scene at Memorial’s east drive. Kit is beside the empty cot at the back."
		return "Ask Kit to wheel the cot in." if rig.ems_partner else "The crew is walking clear. You can set up your line."
	match mode:
		"available":
			if not pending_slips.is_empty():
				return "Take the next call on the cab radio. Fax the finished slips next time you’re at the yard."
			return "County dispatch is standing by. Answer on the cab radio."
		"fieldwork":
			if job.kind == "passenger":
				if rig.phase == "passenger":
					return Rides.approach(job) + " At a full stop, use the door to let the passenger out."
				if rig.phase == "boarding":
					return "Keep the truck stopped while the driver walks to the passenger door."
				return "Pull up with the passenger door clear. Step out and offer the %s a ride." % Rides.rider(job).person.to_lower()
			if job.kind == "looksee":
				if not survey.notes.has("house"):
					return "Find the porch fire number beyond the Lindquist farm on Kolpack."
				if not survey.notes.has("farm_ring"):
					return "Look in the empty drive beside the Hoffmann house."
				return "Use the cab radio to tell Arlene what you found."
			if job.has("sheriff_order") and not job.has("pickup_signature"): return "Find Deputy Pelz beside the car and sign the order before hooking up."
			if job.kind == "hold" and (not signed_card or not packed_tripod):
				return "Meet Deputy Kowalski, sign the custody card and collect the tripod."
			return rig.get_status().get("hint","Drive to the scene. Ask dispatch for a landmark if needed.")
		"haul":
			if rig.rollback_active: return rig.rollback_deck.instruction(rig)
			return rig.dropoff.approach if job.has("sheriff_order") or rig.axle_fault else audio.lines[rig.dropoff.radio][1]
		"return": return "Return to the yard to file your slip."
		"invoice":
			if job.get("kind") == "hold" and not bay_locked:
				return _chain_instruction()
			return "Walk to the office fax at the yard door. File the tow slip."
	return ""

func _contract_hint(site: String) -> Dictionary:
	var title := ""
	var instruction := ""
	if fuel_wait_left > 0.0:
		return {"hint_title":"Roadside fuel requested","hint_action":_fuel_eta()}
	if _needs_fuel_can() and rig.reserve_fuel > .0001:
		return {"hint_title":"Main tank empty","hint_action":rig.reserve_hint()}
	if _needs_fuel_can():
		return {"hint_title":"Out of diesel","hint_action":"Tap RADIO for a county fuel can." if desk.is_touch_mode() else "Press R to call for a county fuel can."}
	if rig.is_chocked() and rig.fuel <= 0.0:
		return {"hint_title":"Out of diesel","hint_action":rig.reserve_hint()}
	if not survey.tracked_lead.is_empty():
		return {"hint_title":"Next stop · " + casework.lead_label(),"hint_action":casework.lead_instruction()}
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
				instruction = "Press R, then choose Take contract."
		"fieldwork":
			if job.has("sheriff_order") and not job.has("pickup_signature"):
				title = "Sheriff order   /   "+str(job.sheriff_order)
				instruction = _procedure()
			elif job.has("case_id"):
				instruction = casework.procedure()
				if not instruction.is_empty():
					title = job.title
			elif job.kind == "passenger":
				title = "Passenger · " + Rides.destination(job)
				instruction = _procedure()
			elif job.kind == "field_visit":
				title = job.title
				instruction = CountyVisits.instruction(job)
			elif job.kind == "looksee":
				title = "Look-see · N5104 Kolpack"
				instruction = _procedure()
		"haul":
			title = "Deliver to %s" % rig.dropoff.sign
			instruction = rig.dropoff.approach
			if rig.rollback_active:
				instruction = rig.rollback_deck.instruction(rig)
				if rig.at_dropoff() or rig.rollback_deck.unloading: title = "At %s" % rig.dropoff.sign
			elif rig.at_dropoff():
				title = "At %s" % rig.dropoff.sign
				if rig.tanker and not rig.tanker.is_settled() and rig.is_stopped():
					instruction = "Let the tank settle before lowering the lift. The load indicator returns to center."
				elif rig.in_cab:
					instruction = "Stop and get out. Walk to the wrecker’s left rear panel."
				else:
					var control := "Tap USE" if desk.is_touch_mode() else "Press E"
					instruction = "%s at the left rear panel to unhook the vehicle." % control
		"return","invoice":
			title = "Slip %d awaiting fax" % int(job.number)
			if job.get("case_id") == "ride" and not campaign.released:
				title = "Tou’s release · Unit 38"
				instruction = casework.procedure()
			elif job.has("sheriff_order") and not west_orders.locked:
				instruction = "Pull the wrecker clear of West Hold 2. Turn the key on the entrance chain from outside."
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
	match site:
		"west_pickup_card": return "Read Deputy Pelz’s transfer order"
		"west_release_card": return "Meet Deputy Pelz for the release"
		"west_order_book": return "Read the west hold order book"
		"west_chain": return "Unlock the west hold chain" if west_orders.locked else "Lock the west hold chain"
	if site == "fleet_door":
		return "Take the carrier keys" if fleet.parked.rollback else "Take the wrecker keys"
	if site == "rod" and survey.notes.has("rod"):
		return "Read the survey rod tag"
	if site == "lock":
		var obstruction := _chain_obstruction()
		if not obstruction.is_empty():
			return obstruction
	if site == "cot_inside":
		return "Ask Kit to wheel the cot into Memorial"
	if site == "offer_ride":
		return "Offer a ride to " + Rides.destination(job)
	if site == "visit_stop":
		return CountyVisits.CHECKS[job.id].actions[int(job.visit_step)]
	if site == "reserve_valve": return "Open the reserve transfer pump"
	if site == "grower":
		return "Ask Roman Duda about County K"
	if site == "let_out":
		return "Let the passenger out at " + Rides.destination(job)
	var words := {"checked_tape":"Read the deputy’s mirror tape","impound_register":"Open the impound register","storage_tag":"Read the yard tag","yard_coffee":"Pour a cup of shop coffee","bulk_pump":"Lift the bulk-tank nozzle","wipe_mirror":"Wipe the mirror glass","coffee":"Stop at Mai’s counter","inspect_sighting":"Take a closer look","unit":"Read the lettering on the pickup","rod":"Turn over the survey rod case","house":"Look through the open door","farm_ring":"Inspect the bare ring in the drive","lock":"Lock the evidence bay","unlock":"Unlock the evidence bay","tripod":"Collect the survey tripod","sign":"Sign Kowalski’s custody card","deputy":"Ask Kowalski about the lights","driver":"Speak to the driver","field":"Read Tou’s field book" if hold_door_open else "Open the pickup · field book","close_unit_door":"Shut Unit 38’s door","fuel":"Check the diesel pump","fax":"Fax finished paperwork" if _can_file_here() else "Open yard office · diesel, parts & fax"}
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
	if fuel_wait_left > 0.0:
		return {}
	if not survey.tracked_lead.is_empty() and active and rig.in_cab and not _needs_fuel_can():
		var stop := casework.lead_site()
		var lead_note := {"title":"Next stop   /   " + casework.lead_label(),"instruction":casework.lead_instruction()}
		if not stop.is_empty():
			if stop == "last_cap":
				var at: Vector3 = rig.get_truck_position()
				var entrance := casework.lead_point(stop)
				if at.z <= entrance.z and absf(at.x-County.CaseSites.ALDER_X) < 43.0:
					lead_note.title = "Pencil note   /   Old logging road"
					lead_note.instruction = "Past N5420, follow the striped stakes north along the old logging road."
					if at.distance_to(county.story_point("last_cap")) < 23.0:
						lead_note.instruction = "Park at the striped stakes. Step out and check the corner cap for Tou’s pencil."
					return lead_note
			var route := _route_note(stop)
			if not route.is_empty():
				lead_note = route
			lead_note.instruction += " The red triangle and amber lamps mark %s." % casework.lead_label()
			return lead_note
		# An observed lead can be called in from wherever the operator parked.
		if mode == "available" or survey.can_report_unit():
			if not _case_lock().is_empty():
				var yard_route := _route_note()
				if not yard_route.is_empty():
					lead_note.instruction += " " + str(yard_route.instruction)
			return lead_note
	var note := _route_note()
	if job.get("kind") == "field_visit" and rig.in_cab and (int(job.visit_step) >= 2 or note.is_empty()):
		return {"title":job.title,"instruction":CountyVisits.instruction(job)}
	if not active or mode != "fieldwork" or rig.phase != "scene" or _needs_fuel_can():
		return note
	if job.get("kind") not in ["ditch","hazard","hold","passenger"]:
		return note
	var identity := "%s, plate %s." % [job.vehicle,job.plate]
	if Rig.uses_warning_triangle(job.kind,job):
		identity += " Look for the red triangle."
	elif job.kind == "passenger":
		identity += " %s is waiting by the car." % Rides.rider(job).person
	if note.is_empty():
		return {"title":"Pickup   /   %s" % job.location,"instruction":identity}
	note.instruction += " " + identity
	return note

func _route_note(favor_site := "") -> Dictionary:
	if not active or not rig.in_cab or _needs_fuel_can():
		return {}
	var at: Vector3 = rig.get_truck_position()
	var p := Vector2(at.x, at.z)
	var in_yard: bool = county.yard_contains(p) and p.x < -4
	var target := RoadDirections.DRIVEWAY
	var landmark := "Brandt’s yard"
	var title := "Route slip   /   Brandt yard"
	var unmapped := false
	var heading: float = fposmod(-rad_to_deg(rig.heading),360.0)
	if favor_site.is_empty() and mode == "haul" and (rig.semi or rig.tanker or rig.axle_fault):
		var apron := County.Dairy.APRON if rig.tanker else County.RiverLanes.LOT
		var receiver := "Brzezinski milk house" if rig.tanker else "River Lanes truck stop"
		if rig.axle_fault:
			apron = County.East.LOT
			receiver = "County highway garage · REPAIR 03"
		if apron.grow(3).has_point(p):
			return {"title":rig.dropoff.sign,"instruction":rig.dropoff.approach}
		var center:Vector3 = rig.dropoff.center
		var freight: Dictionary = _current_road_map().cue(p,heading,Vector2(center.x,center.z),receiver)
		freight.title = "Delivery   /   "+receiver
		return freight
	if county.alder_open and p.y < -478 and absf(p.x-441) < 43:
		if mode == "fieldwork" and job.get("case_id") in ["line","ride"]:
			return {}
		return {"title":"Pencil note   /   Alder Cut","instruction":"Follow the stakes south to Swamp Road. County K is west of the barricade."}
	if not favor_site.is_empty():
		var location: Vector3 = casework.lead_point(favor_site)
		target = Vector2(location.x,location.z)
		landmark = casework.lead_label()
		title = "Unpaid stop   /   " + landmark
	elif mode == "fieldwork" and not job.is_empty():
		var location: Vector3 = county.resolve_point(job.point) if job.kind in ["looksee","field_visit"] else rig.job_site
		target = Vector2(location.x, location.z)
		unmapped = job.get("unmapped", false)
		landmark = str(job.location).get_slice(" · ", 1)
		if landmark.is_empty():
			landmark = job.location
		title = "Route slip   /   %04d" % int(job.number)
		if job.kind == "passenger" and rig.phase == "passenger":
			var drop := Rides.target(job)
			target = Vector2(drop.x,drop.z)
			landmark = Rides.destination(job)
	if not favor_site.is_empty() or (mode == "fieldwork" and not job.is_empty()):
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
	var favor_site := casework.lead_site() if not survey.tracked_lead.is_empty() else ""
	var favor_point := casework.lead_point(favor_site)
	county.set_favor_guide(favor_point,0.0 if favor_site == "last_cap" else PI*.5)
	if rig.warning_triangle:
		rig.warning_triangle.visible = favor_site.is_empty()
	var guide_on: bool = mode == "haul" and rig.loaded and favor_site.is_empty()
	county.freight_guide.visible = guide_on and rig.semi != null
	county.milk_guide.visible = guide_on and rig.tanker != null
	county.drop_guide.visible = guide_on and rig.semi == null and rig.tanker == null
	if county.drop_guide.visible:
		county.drop_guide.position = rig.dropoff.center
	var site := _site_action()
	state = {"prompt":_prompt(site),"subtitle":caption.current(sub_time),"speaker":speaker,
		"feedback":_fuel_eta() if fuel_wait_left > 0.0 else (rig.info if rig.info_timer > 0 else ""),
		"can_inspect_sighting":site == "inspect_sighting","can_wipe":site == "wipe_mirror",
		"suggested_anchors":rig.assist,"heated_mirrors":account.owns("mirrors"),"aux_lamps":account.owns("lamps"),"spot_on":rig.spot_on,
		"spoken":audio.spoken,"has_save":not saved_data.is_empty(),"in_cab":s.in_cab,"speed_mph":s.speed_mph,
		"driving_view":rig.driving_view,"truck_stopped":rig.is_stopped(),
		"can_enter_cab":rig.action_id() == "enter" and (not rig.is_chocked() or rig.fuel <= 0.0) and site.is_empty(),
		"miles":s.odo,"trip":float(s.odo)-dispatch_odo if not job.is_empty() else 0.0,
		"fuel":s.fuel,"tension":s.tension,"heading":["N","NE","E","SE","S","SW","W","NW"][bearing],
		"job":ticket,"slips":slips,"pending_slips":pending_slips,"fax_count":_fax_count(),"calls":calls,"can_radio":s.in_cab,"night_time":_clock(),
		"offer":_offered_rotation(),"radio_contact":_radio_contact(),"sighting_reports":sightings.report_options(),"pending_case":not survey.pending_order().is_empty() or (_case_due() and Campaign.DETAILS.has(campaign.chapter())),
		"case_lead":_dispatch_lead_briefing(),
		"case_evidence":campaign.evidence,"tou_asked":campaign.asked,
		"pencil_notes":survey.notebook()+casework.notebook(),"observations":survey.notes,"can_mark_sketch":book_read and not survey.notes.has("sketch"),
		"faxes":faxes,"fax_text":fax_text,"field_available":book_read,"custody_text":card,"deputy_callback":_deputy_callback(),"can_fax":_can_file_here(),
		"plat_marks":plat_pencil.marks,"roads":county.map_roads(),"places":county.map_places(),"road_names":roads_driven,
		"west_hold":account.owns("west_hold"),"west_lot":county.west_lot_open,"storage_tag":yard_card,"checked_tape":open_tape,
		"yard_pump":county.yard_dispenser,"coffee_maker":county.yard_brewer,
		"heavy_job_filed":heavy_job_filed,"second_winch":account.owns("second_winch"),
		"nozzle_ready":_can_dispense(),"nozzle_sale":nozzle_sale,"nozzle_esker":nozzle_at_esker,"nozzle_reserve":nozzle_reserve,
		"reserve_offered":campaign.stage >= 1 or account.owns("aux_tank"),"aux_tank":account.owns("aux_tank") and not rig.rollback_active,
		"reserve_pct":rig.reserve_fuel/Rig.Reserve.CAPACITY,"reserve_quote":account.fuel_quote(rig.reserve_fuel,INF,Rig.Reserve.CAPACITY),
		"at_counter":site == "coffee","coffee_left":rig.coffee_left,"mai_lot":sightings.seen.has("streetlights_out") and not mai_lot_heard,
		"at_office":_at_office(),"at_pump":_at_pump(),"can_order":_at_office() and _truck_in_yard(),
		"can_refuel":_can_refuel(),"fuel_quote":account.fuel_quote(s.fuel),"fuel_help":_needs_fuel_can(),
		"fuel_eta":ceili(fuel_wait_left),
		"case_lock":_case_lock(),"shop_receipt":shop_receipt,
		"chains":rig.tire_chains,"snatch_block":rig.snatch_block,"wear":s.wear,
		"paid":account.cash,"pending":account.pending,"earned":account.earned,"fuel_due":account.fuel_due,
		"progress":_procedure(),"phase":s.phase,"work_available":s.fuel > 0.0 and rig.action_id()=="winch",
		"warmth":s.warmth,"mode":mode,"rig_hint":s.get("hint","")}
	state.merge(_contract_hint(site))
	state["fleet_offered"] = _fleet_offered()
	state["rollback_owned"] = account.owns("rollback")
	state["rollback_active"] = rig.rollback_active
	state["standby"] = fleet.parked
	state["wrecker_waiting"] = rig.rollback_active and not fleet.alternate_offer.is_empty()
	var parcel := Addresses.readable(rig,county) if active and not desk.is_blocking() and casework.tower_height < 0.0 else ""
	state["readable_fire_plate"] = Addresses.number(parcel) if not parcel.is_empty() else ""
	if desk.page=="west_custody" or site.begins_with("west_"):
		state.west_card = west_orders.sheet(self)
		state.west_source = west_source
	state["visit_offer"] = visit_offer if mode == "available" else {}
	state["visit_action"] = CountyVisits.CHECKS[job.id].buttons[int(job.visit_step)] if site == "visit_stop" else ("MOVE COT" if site == "cot_inside" else "")
	if site == "visit_stop" and not desk.is_touch_mode():
		state.feedback = "E   "+_prompt(site)
	state["passenger_drop"] = site == "let_out"
	state["tower_height"] = casework.tower_height
	if rig.flowage and not rig.in_cab and (s.phase=="cable" or (s.phase=="rigged" and rig._in_range(rig._panel(),2.8,false))):
		state["ice_line"] = rig.flowage.meter(rig)
	if rig.rollover and rig.rollover.controls:
		state["drum_instruction"] = rig.rollover.instruction(rig)
	if rig.roof and not rig.in_cab:
		state["roof_action"] = rig.action_id()
		state["roof_ladder"] = rig.roof.ladder >= 0.
		if rig.roof.controls:
			state["boom_instruction"] = rig.roof.instruction(rig)
			state["roof_slew"] = true
	if rig.tree_recovery and rig.tree_recovery.controls:
		state["boom_instruction"] = rig.tree_recovery.instruction(rig)
	state["tower_top"] = casework.tower_height == County.CaseSites.TANK_PLATFORM
	state["tower_action"] = site if site.begins_with("tower_") else ""
	state["tower_glasses"] = casework.glasses
	if casework.glasses:
		state["glass_bearing"] = fposmod(-rad_to_deg(rig.camera_yaw),360)
	if casework.tower_height >= 0.0:
		state.hint_title = "Esker water tower"
		state.hint_action = casework.tower_instruction()
		state.work_available = false
		state.can_enter_cab = false
	if desk.page == "impound_register" or site == "impound_register":
		state["impound_rows"] = impound_book.visible_cards()
		state["impound_leaf"] = impound_book.leaf
		state["impound_pages"] = impound_book.page_count()
	state["blower"] = rig.climate.blower
	state["window_open"] = rig.climate.cracked
	state["cab_air"] = rig.climate.air
	state["can_track_lead"] = _can_track_lead()
	state["tracked_lead"] = survey.tracked_lead
	state["lead_label"] = casework.lead_label()
	state["case_chapter"] = campaign.chapter()
	state["favor_point"] = favor_point
	state["favor_available"] = state.can_track_lead and not casework.lead_site().is_empty()
	if rig.tanker and (rig.loaded or rig.phase == "rigged"):
		state["milk_load"] = rig.tanker.surge
	if site == "inspect_sighting" and not desk.is_touch_mode() and state.feedback.is_empty():
		state.feedback = "E  ·  Take a closer look"
	state["recovery_restarts_job"] = _restart_on_recovery()
	state["broadcast_station"] = broadcast.station
	state["broadcast_signal"] = broadcast.signal_strength
	state["broadcast_label"] = broadcast.cue.get("label","")
	state["broadcast_words"] = broadcast.caption()
	if state.subtitle.is_empty() and not state.broadcast_words.is_empty():
		state.speaker = broadcast.STATIONS[broadcast.station].name.to_upper()
		state.subtitle = state.broadcast_words
	state["scanner_available"] = _scanner_available()
	state["scanner_fitted"] = account.owns("scanner")
	state["scanner_channel"] = scanner.channel
	state["scanner_history"] = scanner.history
	state["scanner_rx"] = scanner.rx_left > 0
	state["recovery_due"] = account.recovery_due
	state["heading_degrees"] = s.heading
	desk.update_view(state)

func _save() -> void:
	if not active or not rig:
		return
	save_timer = 0
	saved_data = {"completed":completed,"declined_visit":declined_visit,"mode":mode,"rig":rig.save_state(),"slips":slips,"pending_slips":pending_slips,
		"fire_bay":{"lift":county.fire_bay.lift,"travel":county.fire_bay.travel},
		"received_pool":pool_receipt,
		"received_freight":received_freight.delivery_record() if received_freight else {},
		"dispatch_seed":dispatch_seed,"ticket":Dispatch.pack(job),"offer":Dispatch.pack(rotation_offer),
		"parked_truck":fleet.parked.duplicate(true),"light_offer":Dispatch.pack(fleet.alternate_offer),
		"case_offer":Dispatch.pack(case_offer),"survey":survey.save_state(),"campaign":campaign.save_state(),
		"west_custody":west_orders.save_state(),
		"survey_anchor":Dispatch.pack({"point":county.survey_point,"angle":county.survey_yaw}),
		"sightings":sightings.save_state(),"scanner":scanner.save_state(),"broadcast":broadcast.save_state(),"mai_lot_heard":mai_lot_heard,
		"plat_marks":plat_pencil.marks.duplicate(true),"calls":calls,"roads":roads_driven,"stored":stored,"bay_locked":bay_locked,"held":held,"held_tape":held_tape,"hold_door_open":hold_door_open,"book_read":book_read,
		"signed":signed_card,"tripod":packed_tripod,"talked":talked,"asked":talked_twice,
		"seconds":shift_seconds,"start":dispatch_odo,"pickup":pickup_odo,"drop":drop_odo,
		"pickup_time":pickup_time,"drop_time":drop_time,"account":account.save_state(),"work":seconds_worked,"fuel_wait_left":fuel_wait_left,
		"fax":fax_text,"faxes":faxes,"filed_card":filed_card,"plow":plow_heard,"fps":Engine.max_fps,"spoken":audio.spoken}
	if casework.tower_height >= 0.0:
		saved_data.tower = {"height":casework.tower_height,"glasses":casework.glasses}
	if not test_session and not Ledger.write(saved_data):
		push_warning("Could not save current tow ticket")

func _restore(s: Dictionary) -> void:
	_set_pool_receipt(s.get("received_pool",{}))
	if received_freight:
		received_freight.queue_free()
		received_freight = null
	if not s.get("received_freight",{}).is_empty():
		received_freight = Rig.Tanker.new() if int(s.received_freight.get("variant",-1)) == Rig.Tanker.VARIANT else Rig.Semi.new()
		received_freight.restore_delivery(world,s.received_freight,rig._ground)
	casework.leave_tower()
	completed = int(s.completed)
	declined_visit = int(s.get("declined_visit",-1))
	mode = s.mode
	slips = s.slips
	heavy_job_filed = slips.any(func(slip: Dictionary) -> bool: return float(slip.get("heavy_fee",0.0)) > 0.0)
	pending_slips = s.get("pending_slips",[])
	calls = s.calls.duplicate()
	county.fire_bay.restore(s.get("fire_bay",{}))
	plat_pencil.restore(s.get("plat_marks",[]))
	roads_driven = s.roads
	stored = s.stored
	held = s.held
	held_tape = s.get("held_tape",Rig.Scene.Tape.LEGACY)
	hold_door_open = s.get("hold_door_open",false)
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
	west_orders.restore(s.get("west_custody",{}))
	fleet.parked = s.get("parked_truck",{}).duplicate(true)
	fleet.alternate_offer = Dispatch.unpack(s.get("light_offer",{}))
	fleet.clear_model()
	audio.stop_scanner()
	scanner.restore(s.get("scanner",{}),account.owns("scanner"))
	broadcast.restore(s.get("broadcast",{}))
	_clear_fuel_plow()
	fuel_wait_left = clampf(s.get("fuel_wait_left", 0.0), 0.0, ShopAccount.CAN_ETA_MINUTES)
	shop_receipt = ""
	seconds_worked = s.work
	fax_text = s.fax
	faxes = s.get("faxes",[])
	filed_card = s.get("filed_card","")
	plow_heard = s.plow
	mai_lot_heard = s.get("mai_lot_heard",false)
	sightings.restore(s.get("sightings",{}),county)
	sightings._snow_over(completed)
	var anchor := Dispatch.unpack(s.get("survey_anchor",{}))
	county.set_survey_anchor(anchor.get("point",County.SURVEY_PICKUP),anchor.get("angle",County.SURVEY_YAW))
	dispatch_seed = int(s.get("dispatch_seed",dispatch_seed))
	rotation_offer = Dispatch.unpack(s.get("offer",{}))
	case_offer = Dispatch.unpack(s.get("case_offer",{}))
	job = Dispatch.unpack(s.get("ticket",{}))
	if job.has("aftermath_key") and not job.has("observation_key"):
		job.observation_key = "order/%d/%s" % [int(job.number),job.aftermath_key]
	if mode != "available" and job.is_empty():
		job = Dispatch.legacy_ticket(completed,audio.lines)
	survey.restore(s.get("survey",{}),held,job.get("kind",""))
	if survey.notes.has("farm_ring") and not survey.farm_reported:
		sightings.observations.remember({"key":"farm_ring","kind":"farm_ring"})
	if not s.has("account") and survey.pending_order() == "hold" and case_offer.is_empty():
		case_offer = Dispatch.hold_ticket(completed,audio.lines)
		case_offer.point = county.survey_point
		case_offer.angle = county.survey_yaw
	campaign.restore(s.get("campaign",{}),survey,slips)
	if survey.tracked_lead != campaign.chapter() or not _can_track_lead():
		survey.tracked_lead = ""
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
	visits.sync(job,true)
	rig.restore_state(rig_state)
	_prepare_offers()
	if account.owns("rollback"):
		if fleet.parked.is_empty(): fleet.receive(rig)
		else: fleet.show_parked()
	if s.get("tower") is Dictionary and not rig.in_cab and county.case_landmarks.has("car_ring"):
		casework.mount_tower(s.tower.get("height",0.0),s.tower.get("glasses",false))
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
