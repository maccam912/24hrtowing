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
var yard_card := {}
var impound_book := preload("res://scripts/impound_book.gd").new()
var received_freight: Rig.Semi
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
var broadcast := preload("res://scripts/broadcast_radio.gd").new()
var scanner := preload("res://scripts/county_scanner.gd").new()
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
	add_child(broadcast)
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
		var on_ladder := casework.tower_height >= 0.0
		if on_ladder:
			casework.climb(move.y,dt)
			if casework.glasses:
				look *= .19
		# A clearance clock belongs to this ticket. Travel, paperwork, a fuel
		# delivery and time spent away from the scene leave it where it was.
		if job.has("clearance_seconds") and not rig.in_cab and rig.fuel > 0.0 and rig.phase in ["flared","cable","rigged"] and rig.near_casualty(42.0):
			job.clearance_seconds += dt
		rig.set_controls(move.clamp(Vector2(-1,-1),Vector2.ONE),look,working and not on_ladder,brake,dt,on_ladder)
		casework.apply_glasses()
		sightings.observations.sample(dt,self,sightings)
		if rig.get_status().get("working",false):
			seconds_worked += dt
		save_timer += dt
		if save_timer > 7:
			_save()
		direction_timer += dt
		if direction_timer > 0.9:
			_survey()
			_check_lead_reminder(direction_timer)
			direction_timer = 0.0
	if active and desk.page == "bulk_pump":
		_run_nozzle(dt)
	if playing or (active and desk.page == "radio" and fuel_wait_left > 0.0):
		_advance_shift_clock(dt)
	mouse_motion = Vector2.ZERO
	scanner.advance(dt,self)
	broadcast.advance(dt,self)
	var player_at: Vector3 = rig.get_player_position()
	var in_store: bool = not rig.in_cab and county.inside_fuel_store(player_at)
	var playing_shift: bool = active and not desk.is_title()
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
			if desk.page == "map" and desk.pencil_open and not desk.glance and plat_pencil.write(desk.pencil_tool,desk.pencil_point):
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
		"broadcast_am","broadcast_fm","broadcast_off":
			if rig.in_cab and desk.broadcast_open and broadcast.tune(id.trim_prefix("broadcast_")):
				broadcast.advance(0.,self)
				_save()
		"scanner_highway","scanner_garage","scanner_sheriff","scanner_off":
			if rig.in_cab and desk.scanner_open and scanner.tune(id.trim_prefix("scanner_"),account.owns("scanner")):
				audio.stop_scanner()
				if speaker.begins_with("SCANNER  /  "): sub_time = 0
				_save()
		"buy_second_winch","buy_west_lot","buy_yard_pump","buy_coffee_maker","buy_mirrors","buy_lamps","buy_chains","buy_snatch_block","buy_scanner","service_winch","buy_fuel": _shop_purchase(id)
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

func _run_nozzle(dt: float) -> void:
	if not desk.nozzle_held() or not _can_pump_at_tank():
		return
	# The rollers count whole cents; holding the handle meters $3.60 per second.
	nozzle_cents += dt*360.0
	var cents := floori(nozzle_cents)
	nozzle_cents -= cents
	if cents <= 0:
		return
	var sale := account.buy_fuel(rig.fuel,cents/100.0)
	if sale.cost <= 0.0:
		return
	rig.fuel = sale.fuel_after
	nozzle_sale = snappedf(nozzle_sale+sale.cost,.01)
	if fuel_wait_left > 0.0:
		fuel_wait_left = 0.0
		_speak("DISPATCH","Copy, Brandt. I'll cancel that fuel delivery.")
	save_timer += dt
	if save_timer >= 1.0:
		_save()

func _at_counter() -> bool:
	return not rig.in_cab and county.inside_fuel_store(rig.foot) and _facing(county.coffee_counter_point(),2.5)

func _truck_in_yard() -> bool:
	var at: Vector3 = rig.get_truck_position()
	return rig.is_stopped() and county.yard_contains(Vector2(at.x,at.z))

func _can_refuel() -> bool:
	if _at_office():
		return _truck_in_yard()
	return _at_pump() and rig.is_stopped() and rig.get_truck_position().distance_to(PUMP) < 15.0

func _fit_equipment() -> void:
	rig.tire_chains = account.owns("chains")
	rig.snatch_block = account.owns("snatch_block")
	rig.second_winch = account.owns("second_winch")
	rig.body.heated_mirrors = account.owns("mirrors")
	rig.body.fit_lamps(account.owns("lamps"))
	var extend_lot: bool = account.owns("west_lot")
	var moved_fence: bool = county.west_lot_open != extend_lot
	county.fit_yard(account.owns("yard_pump"),account.owns("coffee_maker"),extend_lot)
	if moved_fence:
		_display_storage()
	if not account.owns("lamps"):
		rig.spot_on = false

func _scanner_available() -> bool:
	return signed_card or held or campaign.released or account.owns("scanner")

func _shop_purchase(id: String) -> void:
	if id == "buy_fuel":
		if not _can_refuel():
			return
		var sale := account.buy_fuel(rig.fuel)
		if sale.cost <= 0:
			return
		rig.fuel = sale.fuel_after
		if fuel_wait_left > 0.0:
			fuel_wait_left = 0.0
			_speak("DISPATCH","Copy, you found diesel. I'll call off the plow.")
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
		if part == "scanner" and not _scanner_available(): return
		if part == "second_winch" and (not heavy_job_filed or not account.owns("snatch_block")): return
		if not account.buy(part):
			return
		_fit_equipment()
		match part:
			"second_winch": shop_receipt = "Auxiliary winch fitted. Arlene can dispatch freight calls on US 59."
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
	if mode == "available":
		var issued := completed + pending_slips.size()
		if rotation_offer.is_empty() and campaign.stage >= 2:
			rotation_offer = sightings.recovery_offer(issued,county,account.owns("snatch_block"),campaign.stage == Campaign.ORDER.size())
		if rotation_offer.is_empty():
			rotation_offer = Dispatch.ordinary(issued,dispatch_seed,slips + pending_slips,account.owns("snatch_block"),account.owns("second_winch"))
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
	var waiting: bool = rotation_offer.get("kind") == "hazard" and not rotation_offer.has("aftermath_key") and rotation_offer.get("recovery") != "semi"
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
	if _can_track_lead() and survey.tracked_lead.is_empty():
		campaign.calls_past_lead += 1
	survey.defer_order()
	_accept(rotation_offer)

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
	job = ticket
	if job.has("aftermath_key"):
		sightings.claim_recovery(job)
	if (not job.has("case_id") and job.kind in ["ditch","hazard","passenger"]) or (job.get("case_id") == "angie" and rotation_offer.get("vin") == job.vin):
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
	if job.kind != "looksee":
		rig.start_job(job.kind,county.resolve_point(job.point),job.angle,job)
	else:
		rig.end_job()
	_sync_survey_scene()

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
		_speak("DISPATCH","Duane can bring diesel. Request a fuel can on the cab radio.")
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
	if received_freight and pos.distance_to(County.RiverLanes.CENTER)>190 and not _near(County.RiverLanes.CENTER,190):
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
	if rig.in_cab or rig.at_dry_rig_door():
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
		return "offer_ride"
	elif mode == "fieldwork" and (job.get("kind") == "ditch" or rig.semi) and not talked and _facing(rig.get_witness_position(),3.9):
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
	if held and not bay_locked and _facing(BAY,4.8):
		return "field"
	if _at_counter():
		return "coffee"
	if _facing(PUMP_ISLANDS[0],4.5) or _facing(PUMP_ISLANDS[1],4.5):
		return "fuel"
	if rig.action_id() in ["","enter"] and rig.wipeable_mirror() >= 0:
		return "wipe_mirror"
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
		"wipe_mirror":
			var side: int = rig.wipeable_mirror()
			if side >= 0:
				rig.body.set_mirror_ice(side,0)
				rig._note("Glass wiped clean.",3.0)
		"impound_register":
			impound_book.open(stored,slips,PARKING.size(),County.Fittings.WEST_STALLS if county.west_lot_open else 0)
			desk.show_document("impound_register",state)
		"storage_tag":
			yard_card = _storage_tag(_storage_row_in_reach())
			_refresh()
			desk.show_document("storage_tag",state)
		"bulk_pump":
			nozzle_sale = 0
			nozzle_cents = 0
			_refresh()
			desk.show_document("bulk_pump",state)
		"yard_coffee":
			if rig.coffee_left > 0:
				_message("BRANDT","Still have coffee in my cup.")
			else:
				rig.warmth = 1.0
				rig.coffee_left = Rig.HOT_COFFEE_SECONDS
				_message("BRANDT","Fresh cup for the road.")
		"coffee":
			_refresh()
			desk.show_document("coffee",state)
		"fuel":
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
	if rig.semi:
		if received_freight:
			received_freight.queue_free()
		received_freight = rig.semi
		received_freight.reparent(world,true)
		received_freight.settle(rig._ground)
		rig.car_lamps.hide()
		rig.car_lamps.queue_free()
		rig.car = null
		rig.semi = null
		rig.end_job()
		_clear_field_job()
		_prepare_offers()
		_message("RIVER LANES","We've got the tractor and the box. Keep your copy for the county.")
		_refresh()
		_save()
		return
	mode = "invoice"
	if job.kind == "hold":
		held = true
		filed_card = _custody_record()
		_sync_survey_scene()
	else:
		stored.append({"number":job.number,"route":job.route,"variant":job.get("variant",2),"plate":job.plate,"vin":job.vin,
			"heavy_recovery":job.get("heavy_recovery",false),"vehicle":job.get("vehicle",""),"location":job.get("location",""),"time":drop_time})
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
			node.hide()
			node.queue_free()
	physical_cars.clear()
	if held or (campaign.released and not campaign.evidence.has("unit_departed")):
		var car = rig.store_vehicle("hold",BAY,-PI/2)
		if car is Node3D:
			physical_cars.append(car)
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
	heavy_job_filed = heavy_job_filed or float(slip.get("heavy_fee",0.0)) > 0.0
	completed += 1
	var prior_fuel_due := account.fuel_due
	var prior_recovery_due := account.recovery_due
	var payment := account.file_invoice(slip.pay,completed)
	if case_id == "unit":
		survey.hold_order = "filed"
	elif case_id == "farm":
		survey.farm_order = "filed"
	fax_text = "TO  BRANDT TOWING & RECOVERY\nRE  SERVICE SLIP %04d\n\nReceived for county review.\nCall-out  $%d    Hookup  $%d\nWinch  $%d    Storage  $%d\nLoaded  %.1f mi @ $3.25" % [slip.number,slip.call_out,slip.hookup,slip.winch,slip.storage,slip.loaded]
	if slip.heavy_fee > 0:
		fax_text += "\nHeavy recovery  $%d" % slip.heavy_fee
	if slip.get("recovery") == "semi":
		fax_text += "\nReceived at River Lanes truck stop"
	if slip.has("clearance_bonus"):
		fax_text += "\nSquad clearance  %s    Bonus  $%.2f" % [Dispatch.Squad.clock(slip.clearance_seconds),slip.clearance_bonus]
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
	if fuel_wait_left > 0.0:
		return {"hint_title":"Roadside fuel requested","hint_action":_fuel_eta()}
	if _needs_fuel_can():
		return {"hint_title":"Out of diesel","hint_action":"Tap RADIO for a county fuel can." if desk.is_touch_mode() else "Press R to call for a county fuel can."}
	if rig.is_chocked() and rig.fuel <= 0.0:
		return {"hint_title":"Out of diesel","hint_action":Rig.DRY_RIG_HINT}
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
			if job.has("case_id"):
				instruction = casework.procedure()
				if not instruction.is_empty():
					title = job.title
			elif job.kind == "passenger":
				title = "Passenger · " + Rides.destination(job)
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
	if site == "offer_ride":
		return "Offer a ride to " + Rides.destination(job)
	if site == "let_out":
		return "Let the passenger out at " + Rides.destination(job)
	var words := {"impound_register":"Open the impound register","storage_tag":"Read the yard tag","yard_coffee":"Pour a cup of shop coffee","bulk_pump":"Lift the bulk-tank nozzle","wipe_mirror":"Wipe the mirror glass","coffee":"Stop at Mai’s counter","inspect_sighting":"Take a closer look","unit":"Read the lettering on the pickup","rod":"Turn over the survey rod case","house":"Look through the open door","farm_ring":"Inspect the bare ring in the drive","lock":"Lock the evidence bay","unlock":"Unlock the evidence bay","tripod":"Collect the survey tripod","sign":"Sign Kowalski’s custody card","deputy":"Ask Kowalski about the lights","driver":"Speak to the driver","field":"Open the pickup · field book","fuel":"Check the diesel pump","fax":"Fax finished paperwork" if _can_file_here() else "Open yard office · diesel, parts & fax"}
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
	if favor_site.is_empty() and mode == "haul" and rig.semi:
		if County.RiverLanes.LOT.grow(3).has_point(p):
			return {"title":rig.dropoff.sign,"instruction":rig.dropoff.approach}
		var freight: Dictionary = _current_road_map().cue(p,heading,County.RiverLanes.BAY.get_center(),"River Lanes truck stop")
		freight.title = "Delivery   /   River Lanes receiving"
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
		var location: Vector3 = county.resolve_point(job.point) if job.kind == "looksee" else rig.job_site
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
	county.drop_guide.visible = guide_on and rig.semi == null
	if county.drop_guide.visible:
		county.drop_guide.position = rig.dropoff.center
	var site := _site_action()
	state = {"prompt":_prompt(site),"subtitle":caption.current(sub_time),"speaker":speaker,
		"feedback":_fuel_eta() if fuel_wait_left > 0.0 else (rig.info if rig.info_timer > 0 else ""),
		"can_inspect_sighting":site == "inspect_sighting","can_wipe":site == "wipe_mirror",
		"heated_mirrors":account.owns("mirrors"),"aux_lamps":account.owns("lamps"),"spot_on":rig.spot_on,
		"spoken":audio.spoken,"has_save":not saved_data.is_empty(),"in_cab":s.in_cab,"speed_mph":s.speed_mph,
		"driving_view":rig.driving_view,"truck_stopped":rig.is_stopped(),
		"can_enter_cab":rig.action_id() == "enter" and (not rig.is_chocked() or rig.fuel <= 0.0) and site.is_empty(),
		"miles":s.odo,"trip":float(s.odo)-dispatch_odo if not job.is_empty() else 0.0,
		"fuel":s.fuel,"tension":s.tension,"heading":["N","NE","E","SE","S","SW","W","NW"][bearing],
		"job":ticket,"slips":slips,"pending_slips":pending_slips,"fax_count":_fax_count(),"calls":calls,"can_radio":s.in_cab,"night_time":_clock(),
		"offer":rotation_offer,"radio_contact":_radio_contact(),"sighting_reports":sightings.report_options(),"pending_case":not survey.pending_order().is_empty() or (_case_due() and Campaign.DETAILS.has(campaign.chapter())),
		"case_lead":_dispatch_lead_briefing(),
		"case_evidence":campaign.evidence,"tou_asked":campaign.asked,
		"pencil_notes":survey.notebook()+casework.notebook(),"observations":survey.notes,"can_mark_sketch":book_read and not survey.notes.has("sketch"),
		"faxes":faxes,"fax_text":fax_text,"field_available":book_read,"custody_text":card,"can_fax":_can_file_here(),
		"plat_marks":plat_pencil.marks,"roads":county.map_roads(),"places":county.map_places(),"road_names":roads_driven,
		"west_lot":county.west_lot_open,"storage_tag":yard_card,
		"yard_pump":county.yard_dispenser,"coffee_maker":county.yard_brewer,
		"heavy_job_filed":heavy_job_filed,"second_winch":account.owns("second_winch"),
		"nozzle_ready":_can_pump_at_tank(),"nozzle_sale":nozzle_sale,
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
	state["passenger_drop"] = site == "let_out"
	state["tower_height"] = casework.tower_height
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
	state["can_track_lead"] = _can_track_lead()
	state["tracked_lead"] = survey.tracked_lead
	state["lead_label"] = casework.lead_label()
	state["case_chapter"] = campaign.chapter()
	state["favor_point"] = favor_point
	state["favor_available"] = state.can_track_lead and not casework.lead_site().is_empty()
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
	saved_data = {"completed":completed,"mode":mode,"rig":rig.save_state(),"slips":slips,"pending_slips":pending_slips,
		"received_freight":received_freight.delivery_record() if received_freight else {},
		"dispatch_seed":dispatch_seed,"ticket":Dispatch.pack(job),"offer":Dispatch.pack(rotation_offer),
		"case_offer":Dispatch.pack(case_offer),"survey":survey.save_state(),"campaign":campaign.save_state(),
		"survey_anchor":Dispatch.pack({"point":county.survey_point,"angle":county.survey_yaw}),
		"sightings":sightings.save_state(),"scanner":scanner.save_state(),"broadcast":broadcast.save_state(),"mai_lot_heard":mai_lot_heard,
		"plat_marks":plat_pencil.marks.duplicate(true),"calls":calls,"roads":roads_driven,"stored":stored,"bay_locked":bay_locked,"held":held,"book_read":book_read,
		"signed":signed_card,"tripod":packed_tripod,"talked":talked,"asked":talked_twice,
		"seconds":shift_seconds,"start":dispatch_odo,"pickup":pickup_odo,"drop":drop_odo,
		"pickup_time":pickup_time,"drop_time":drop_time,"account":account.save_state(),"work":seconds_worked,"fuel_wait_left":fuel_wait_left,
		"fax":fax_text,"faxes":faxes,"filed_card":filed_card,"plow":plow_heard,"fps":Engine.max_fps,"spoken":audio.spoken}
	if casework.tower_height >= 0.0:
		saved_data.tower = {"height":casework.tower_height,"glasses":casework.glasses}
	if not test_session and not Ledger.write(saved_data):
		push_warning("Could not save current tow ticket")

func _restore(s: Dictionary) -> void:
	if received_freight:
		received_freight.queue_free()
		received_freight = null
	if not s.get("received_freight",{}).is_empty():
		received_freight = Rig.Semi.new()
		received_freight.restore_delivery(world,s.received_freight,rig._ground)
	casework.leave_tower()
	completed = int(s.completed)
	mode = s.mode
	slips = s.slips
	heavy_job_filed = slips.any(func(slip: Dictionary) -> bool: return float(slip.get("heavy_fee",0.0)) > 0.0)
	pending_slips = s.get("pending_slips",[])
	calls = s.calls.duplicate()
	plat_pencil.restore(s.get("plat_marks",[]))
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
	_prepare_offers()
	rig.restore_state(rig_state)
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
