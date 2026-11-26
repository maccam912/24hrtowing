extends CanvasLayer

const Addresses := preload("res://scripts/fire_numbers.gd")

signal action(id: String)

const Surface = preload("res://scripts/desk_surface.gd")

var state: Dictionary = {}
var road_note: Dictionary = {}
var page := "title"
var surface: Control
var started := false
var glance := false
var slip_index := -1
var fax_index := -1
var fax_sheet := -1
var fire_leaf := -1
var fire_parcel := ""
var atlas_notes := false
var town_sheet := false
var east_sheet := false
var pencil_open := false
var pencil_tool := "return"
var pencil_point := Vector2.ZERO
var parts_page := 0
var notes_page := 0
var sighting_page := -1
var scanner_open := false
var broadcast_open := false
var fps := 30
var _touch_mode := false
var _touches: Dictionary = {}
var _look := Vector2.ZERO
var _stick := Vector2.ZERO
var _return_page := ""

func _ready() -> void:
	layer = 10
	_touch_mode = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	surface = Surface.new()
	surface.desk = self
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func update_view(next_state: Dictionary) -> void:
	if state.get("in_cab",true) != next_state.get("in_cab",true):
		_clear_controls()
	state = next_state
	if glance and state.get("truck_stopped", true):
		glance = false
		_clear_controls()
	if surface:
		surface.queue_redraw()

func is_blocking() -> bool:
	return not page.is_empty() and not glance

func is_title() -> bool:
	return not started

func is_touch_mode() -> bool:
	return _touch_mode

func start_play() -> void:
	started = true
	_change_page("")

func show_document(id: String, next_state: Dictionary) -> void:
	state = next_state
	if id == "guide":
		id = "help"
	if page == id and id not in ["title", "pause"]:
		dismiss()
		return
	if id in ["options", "help", "guidance", "yard_recovery"]:
		_return_page = "pause" if started else "title"
	_change_page(id)
	if id == "slip" and state.get("job",{}).is_empty() and not state.get("pending_slips",[]).is_empty():
		slip_index = state.get("slips",[]).size() + state.pending_slips.size() - 1
	if id in ["map", "slip"] and state.get("in_cab", true) and not state.get("truck_stopped", true):
		glance = true

func dismiss() -> void:
	if page in ["options", "help", "guidance", "yard_recovery"]:
		_change_page(_return_page)
	elif page == "visit_call":
		_change_page("radio")
	elif started:
		_change_page("")
	else:
		_change_page("title")

func toggle_pause() -> void:
	if page.is_empty():
		_change_page("pause" if started else "title")
	elif page == "radio" and (sighting_page >= 0 or scanner_open):
		_change_page("radio")
	else:
		dismiss()

func _change_page(id: String) -> void:
	page = id
	pencil_open = false
	fire_leaf = -1
	fire_parcel = ""
	parts_page = 0
	glance = false
	slip_index = -1
	fax_index = -1
	fax_sheet = -1
	sighting_page = -1
	scanner_open = false
	broadcast_open = false
	_clear_controls()
	if surface:
		surface.hit_boxes.clear()
		surface.hover = ""
		surface.queue_redraw()

func open_fire_index(id: String) -> void:
	town_sheet = false
	east_sheet = false
	pencil_open = false
	fire_parcel = id
	fire_leaf = floori(float(maxi(Addresses.PARCELS.keys().find(id),0))/Addresses.PER_LEAF)
	surface.hover = ""
	surface.hit_boxes.clear()
	surface.queue_redraw()

func _pencil_bounds() -> Rect2:
	if town_sheet: return Rect2(Surface.Documents.Pencil.Town.NW,Surface.Documents.Pencil.Town.SE-Surface.Documents.Pencil.Town.NW)
	if east_sheet: return Rect2(Surface.Documents.Pencil.EAST_NW,Surface.Documents.Pencil.EAST_SE-Surface.Documents.Pencil.EAST_NW)
	return Rect2(Surface.Documents.ATLAS_A,Surface.Documents.ATLAS_B-Surface.Documents.ATLAS_A)

func _clear_controls() -> void:
	_touches.clear()
	_stick = Vector2.ZERO
	_look = Vector2.ZERO

func get_move() -> Vector2:
	var direction := _stick
	if _is_down("steer_l"):
		direction.x -= 1
	if _is_down("steer_r"):
		direction.x += 1
	if _is_down("reverse"):
		direction.y += 1
	elif _is_down("gas"):
		direction.y -= 1
	return direction.limit_length(1.0) if not bool(state.get("in_cab", true)) else direction.clamp(Vector2(-1,-1), Vector2.ONE)

func take_look() -> Vector2:
	var motion := _look
	_look = Vector2.ZERO
	return motion

func parts_labels() -> Array:
	var tabs := ["Fuel & parts","Cab & rig","Yard fittings"]
	if state.get("reserve_offered",false): tabs.append("Diesel reserve")
	if state.get("fleet_offered",false): tabs.append("Fleet keys")
	return tabs

func nozzle_held() -> bool:
	return page in ["bulk_pump","reserve_transfer"] and (_is_down("nozzle") or Input.is_physical_key_pressed(KEY_SPACE))

func work_held() -> bool:
	return _is_down("work")

func brake_held() -> bool:
	return _is_down("brake")

func _is_down(id: String) -> bool:
	for contact in _touches.values():
		if contact.id == id:
			return true
	return false

func _input(event: InputEvent) -> void:
	if not surface:
		return
	if event is InputEventScreenTouch:
		_touch_mode = true
		var point: Vector2 = surface.to_page(event.position)
		if event.pressed and not event.canceled:
			_press(event.index, point)
		else:
			_release(event.index, point, event.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_drag(event.index, surface.to_page(event.position), event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and is_blocking():
		var target: String = surface.hit_at(surface.to_page(event.position))
		if surface.hover != target:
			surface.hover = target
			surface.queue_redraw()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if is_blocking() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var point: Vector2 = surface.to_page(event.position)
			if event.pressed:
				_press(-1, point)
			else:
				_release(-1, point)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and is_blocking():
		if pencil_open and page == "map" and surface.hover == "pencil_sheet":
			var direction := Vector2.ZERO
			match event.keycode:
				KEY_LEFT: direction = Vector2.LEFT
				KEY_RIGHT: direction = Vector2.RIGHT
				KEY_UP: direction = Vector2.UP
				KEY_DOWN: direction = Vector2.DOWN
			if direction != Vector2.ZERO:
				var step := (20 if event.shift_pressed else 4) if town_sheet else (100 if event.shift_pressed else 22)
				pencil_point = (pencil_point+direction*step).clamp(_pencil_bounds().position,_pencil_bounds().end)
				surface.queue_redraw()
				get_viewport().set_input_as_handled()
				return
		var choices: Array = surface.key_choices()
		if choices.is_empty():
			return
		var focus := choices.find(surface.hover)
		match event.keycode:
			KEY_DOWN, KEY_RIGHT, KEY_TAB:
				var step := -1 if event.shift_pressed and event.keycode == KEY_TAB else 1
				focus = posmod(focus + step, choices.size()) if focus >= 0 else (0 if step > 0 else choices.size()-1)
			KEY_UP, KEY_LEFT:
				focus = posmod(focus - 1, choices.size()) if focus >= 0 else choices.size()-1
			KEY_ENTER, KEY_KP_ENTER:
				if focus >= 0 or page != "parts":
					_activate(str(choices[maxi(focus,0)]))
					get_viewport().set_input_as_handled()
					return
				# A newly opened catalog or a just-filled order needs a visible selection.
				focus = 0
			_:
				return
		surface.hover = str(choices[focus])
		surface.queue_redraw()
		get_viewport().set_input_as_handled()

func _press(index: int, point: Vector2) -> void:
	var id: String = surface.hit_at(point)
	if id == "brake":
		# Choose once per press, so holding the pedal through a stop keeps braking.
		if brake_held() or _is_down("reverse"):
			return
		if state.get("truck_stopped", true):
			id = "reverse"
	elif id == "interact" and state.get("in_cab", true) and not state.get("truck_stopped", true):
		return
	elif id.is_empty():
		if is_blocking():
			return
		id = "look"
	if id == "horn": action.emit("horn")
	_touches[index] = {"id": id, "origin": point}
	if id == "stick":
		_stick = surface.stick_input(point)
	surface.queue_redraw()

func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var contact: Dictionary = _touches[index]
	if contact.id == "look":
		_look += relative
	elif contact.id in ["steer_l","steer_r"]:
		var side: String = surface.hit_at(point)
		if side in ["steer_l","steer_r"] and side != contact.id:
			contact.id = side
			surface.queue_redraw()
	elif contact.id == "nozzle" and surface.hit_at(point) != "nozzle":
		_touches.erase(index)
	elif contact.id == "stick":
		_stick = surface.stick_input(point)
		surface.queue_redraw()

func _release(index: int, point: Vector2, canceled := false) -> void:
	if not _touches.has(index):
		return
	var id: String = _touches[index].id
	_touches.erase(index)
	if id == "stick":
		_stick = Vector2.ZERO
	elif not canceled and id == surface.hit_at(point) and id not in ["steer_l", "steer_r", "gas", "reverse", "brake", "horn", "work", "look"]:
		if id == "pencil_sheet":
			pencil_point = surface.docs.pencil_projection.affine_inverse() * point
			surface.hover = id
		_activate(id)
	surface.queue_redraw()

func _activate(id: String) -> void:
	match id:
		"play":
			start_play()
			action.emit("play")
		"close":
			dismiss()
		"pause":
			toggle_pause()
		"guidance":
			action.emit("guidance")
		"yard_recovery":
			if page == "pause":
				show_document(id,state)
		"return_deputy_call","told_open","told_closed","cab_heat","blower_off","blower_low","blower_high","window_latch","confirm_yard_recovery","settings_anchors":
			action.emit(id)
		"title":
			started = false
			_change_page("title")
			action.emit("title")
		"options", "help", "map", "slip", "radio", "fax", "custody", "field", "parts":
			show_document(id, state)
		"toggle_lead":
			_change_page("")
			action.emit(id)
		"respond", "directions", "send_fax":
			_change_page("")
			action.emit({"respond":"rotation", "directions":"talk_in", "send_fax":"fax"}[id])
		"report_unit", "take_case", "ask_farm", "report_farm", "take_detail", "report_detail", "report_notes", "talk_tou", "tou_0", "tou_1", "tou_2", "tou_3", "tou_4", "tou_5", "tou_6", "tou_7", "roadside_fuel":
			_change_page("")
			action.emit(id)
		"open_scanner","open_broadcast","close_scanner":
			scanner_open = id != "close_scanner"
			broadcast_open = id == "open_broadcast"
			surface.hover = ""
			surface.hit_boxes.clear()
			surface.queue_redraw()
		"broadcast_am","broadcast_fm","broadcast_off","scanner_highway","scanner_sheriff","scanner_garage","scanner_off","buy_scanner":
			action.emit(id)
		"report_sighting", "back_to_radio", "prev_sightings", "next_sightings":
			match id:
				"report_sighting": sighting_page = 0
				"back_to_radio": sighting_page = -1
				"prev_sightings": sighting_page -= 1
				"next_sightings": sighting_page += 1
			surface.hover = ""
			surface.hit_boxes.clear()
			surface.queue_redraw()
		"mark_sketch":
			atlas_notes = true
			notes_page = 0
			action.emit(id)
		"parts_leaf", "parts_prev":
			parts_page = posmod(parts_page + (1 if id == "parts_leaf" else -1),parts_labels().size())
			surface.hover = ""
			surface.hit_boxes.clear()
			surface.queue_redraw()
		"west_accept","west_sign_pickup","west_sign_release","west_archive","west_archive_prev","west_archive_next","west_current","impound_prev", "impound_next", "impound_index", "impound_0", "impound_1", "impound_2", "buy_coffee", "talk_mai":
			action.emit(id)
		"turn_town":
			town_sheet = not town_sheet
			surface.hover = ""
			surface.hit_boxes.clear()
			surface.queue_redraw()
		"turn_plat":
			town_sheet = false
			east_sheet = not east_sheet
			pencil_open = false
			fire_leaf = -1
			surface.hover = ""
			surface.hit_boxes.clear()
			surface.queue_redraw()
		"fire_index":
			if fire_leaf < 0:
				open_fire_index("")
			else:
				fire_leaf = -1
				surface.queue_redraw()
		"fire_next":
			fire_leaf = (fire_leaf+1)%ceili(float(Addresses.PARCELS.size()) / Addresses.PER_LEAF)
			surface.queue_redraw()
		"visit_call":
			if not (state.get("visit_offer",{}) as Dictionary).is_empty():
				show_document("visit_call",state)
		"take_visit","pass_visit","report_visit":
			_change_page("")
			action.emit(id)
		"read_fire_plate":
			action.emit(id)
		"plat_pencil":
			fire_leaf = -1
			pencil_open = not pencil_open
			pencil_point = pencil_point.clamp(_pencil_bounds().position,_pencil_bounds().end)
			surface.hover = "pencil_sheet" if pencil_open else ""
			surface.hit_boxes.clear()
			surface.queue_redraw()
		"pencil_vehicle", "pencil_lights", "pencil_return", "pencil_erase":
			pencil_tool = id.trim_prefix("pencil_")
			surface.hover = "pencil_sheet"
			surface.queue_redraw()
		"pencil_sheet":
			if pencil_open and page == "map" and not glance:
				action.emit("pencil_mark")
		"atlas_notes":
			if not atlas_notes:
				notes_page = 0
				atlas_notes = true
			elif (notes_page+1)*Surface.Documents.NOTES_PER_PAGE < state.get("pencil_notes",[]).size():
				notes_page += 1
			else:
				atlas_notes = false
			surface.queue_redraw()
		"prev_slip", "next_slip":
			var count: int = state.get("slips", []).size() + state.get("pending_slips", []).size()
			var order := -1 if id == "prev_slip" else 1
			slip_index = posmod(slip_index + 1 + order, count + 1) - 1
			surface.queue_redraw()
		"fax_sheet":
			fax_sheet += 1
			surface.queue_redraw()
		"prev_fax", "next_fax":
			var archive: Array = state.get("faxes", [])
			if not archive.is_empty():
				var current := archive.size()-1 if fax_index < 0 else fax_index
				fax_index = posmod(current + (-1 if id == "prev_fax" else 1), archive.size())
				fax_sheet = -1
				surface.queue_redraw()
		"settings_30", "settings_60":
			fps = 30 if id == "settings_30" else 60
			action.emit(id)
			surface.queue_redraw()
		"tank_main", "tank_reserve", "buy_rollback", "buy_aux_tank", "buy_reserve_fuel", "buy_second_winch", "buy_west_hold", "buy_west_lot", "buy_yard_pump", "buy_coffee_maker", "spot", "buy_mirrors", "buy_lamps", "interact", "camera", "quit", "settings_voice", "buy_fuel", "buy_chains", "buy_snatch_block", "service_winch":
			action.emit(id)
		_:
			if page == "radio" and sighting_page >= 0 and id.begins_with("sighting:"):
				_change_page("")
				action.emit(id)
