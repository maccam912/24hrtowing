extends CanvasLayer

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
var atlas_notes := false
var notes_page := 0
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
	if id in ["options", "help", "guidance"]:
		_return_page = "pause" if started else "title"
	_change_page(id)
	if id in ["map", "slip"] and state.get("in_cab", true) and not state.get("truck_stopped", true):
		glance = true

func dismiss() -> void:
	if page in ["options", "help", "guidance"]:
		_change_page(_return_page)
	elif started:
		_change_page("")
	else:
		_change_page("title")

func toggle_pause() -> void:
	if page.is_empty():
		_change_page("pause" if started else "title")
	else:
		dismiss()

func _change_page(id: String) -> void:
	page = id
	glance = false
	slip_index = -1
	fax_index = -1
	fax_sheet = -1
	_clear_controls()
	if surface:
		surface.hit_boxes.clear()
		surface.hover = ""
		surface.queue_redraw()

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
	elif not canceled and id == surface.hit_at(point) and id not in ["steer_l", "steer_r", "gas", "reverse", "brake", "work", "look"]:
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
		"title":
			started = false
			_change_page("title")
			action.emit("title")
		"options", "help", "map", "slip", "radio", "fax", "custody", "field", "parts":
			show_document(id, state)
		"respond", "directions", "send_fax":
			_change_page("")
			action.emit({"respond":"rotation", "directions":"talk_in", "send_fax":"fax"}[id])
		"report_unit", "take_case", "ask_farm", "report_farm", "take_detail", "report_detail", "talk_tou", "tou_0", "tou_1", "tou_2", "tou_3", "roadside_fuel":
			_change_page("")
			action.emit(id)
		"mark_sketch":
			atlas_notes = true
			notes_page = 0
			action.emit(id)
		"clip_slip":
			action.emit(id)
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
			var count: int = state.get("slips", []).size()
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
		"interact", "camera", "quit", "buy_fuel", "buy_chains", "buy_snatch_block", "service_winch":
			action.emit(id)
