extends SceneTree

const Game := preload("res://scripts/game.gd")
const CAB_CONTROLS := ["steer_l", "steer_r", "gas", "brake", "interact", "radio", "map", "slip", "camera", "pause"]
const PAPER_TABS := ["radio", "slip", "map", "fax", "parts", "custody", "field"]
const PAPER_STATE := {
	"in_cab": true, "field_available": true, "custody_text": "Evidence hold",
	"slips": [{}], "faxes": ["First fax", "Second fax"], "can_fax": true,
	"can_order": true, "paid": 1000, "wear": 0.5,
	"fuel": 0.5, "can_refuel": true, "fuel_quote": {"cost":24.0,"fuel_after":1.0},
}

var screen := SubViewport.new()
var game := Game.new()
var desk
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("Touch controls at ", screen.size, " on '", desk.page, "': ", message)

func check_layout(required: Array) -> Dictionary:
	var centers := {}
	var bounds := Rect2(Vector2.ZERO, screen.size)
	# Express physical target sizes at a reference landscape height of 360 dp.
	var minimum := screen.size.y * ((52.0 if desk.page.is_empty() else 48.0) / 360.0)
	var previous: Array[Rect2] = []
	for entry in desk.surface.hit_boxes:
		var box: Rect2 = entry.rect
		var target := Rect2(box.position * desk.surface.unit, box.size * desk.surface.unit)
		check(bounds.encloses(target), entry.id + " extends off-screen")
		check(target.size.x + 0.01 >= minimum and target.size.y + 0.01 >= minimum, entry.id + " is too small")
		if entry.id in ["steer_l", "steer_r"]:
			check(box.size.x > 116 and box.size.y > 145, "The steering area should be larger in both directions")
		for other in previous:
			check(not target.intersects(other), entry.id + " overlaps another target")
		previous.append(target)
		centers[entry.id] = target.get_center()
	for id in required:
		check(centers.has(id), "Missing " + id)
	return centers

func touch(finger: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = pressed
	screen.push_input(event, true)

func drag(finger: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = to
	event.relative = to - from
	screen.push_input(event, true)

func ticks(count: int) -> void:
	for i in count:
		game._physics_process(1.0 / 60.0)

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	screen.push_input(event,true)

func check_shop() -> void:
	var actions := ["buy_fuel","buy_chains","service_winch","buy_snatch_block"]
	check_layout(actions)
	var orders := []
	var record := func(id: String): orders.append(id)
	desk.action.connect(record)
	press_key(KEY_TAB)
	check(desk.surface.hover == "buy_fuel","Tab selects the first available order")
	press_key(KEY_RIGHT)
	check(desk.surface.hover == "buy_chains","Arrow selects the next order")
	press_key(KEY_ENTER)
	check(orders == ["buy_chains"],"Enter submits the displayed equipment order")
	# The real truck is still in the cab, so the refreshed catalog is read-only.
	await process_frame
	press_key(KEY_ENTER)
	check(orders == ["buy_chains"] and desk.page == "parts","A vanished order cannot redirect Enter into a second action")
	desk.action.disconnect(record)
	for id in actions:
		check(id not in desk.surface.key_choices(),"Field copy accepts order "+id)
	desk.update_view(PAPER_STATE)
	await process_frame

func tap_key(id: String) -> void:
	var centers := check_layout([id])
	if not centers.has(id):
		return
	touch(0,centers[id],true)
	touch(0,centers[id],false)
	await process_frame

func check_sighting_pages() -> void:
	await tap_key("report_sighting")
	for id: String in desk.surface.key_choices():
		check(not id.begins_with("sighting:") and id != "next_sightings","An empty list should reveal no sightings")
	await tap_key("back_to_radio")
	var reports := []
	for i in 4:
		reports.append({"key":str(i),"label":"Observed vehicle %d" % i})
	desk.update_view(PAPER_STATE.merged({"sighting_reports":reports}))
	await process_frame
	await tap_key("report_sighting")
	check_layout(["sighting:0","sighting:1","sighting:2"])
	await tap_key("next_sightings")
	check_layout(["sighting:3","prev_sightings"])
	check("sighting:0" not in desk.surface.key_choices(),"The previous page's targets should be gone")
	await tap_key("prev_sightings")
	check_layout(["sighting:0","sighting:1","sighting:2"])
	await tap_key("back_to_radio")
	check_layout(["report_sighting"])
	desk.update_view(PAPER_STATE)
	await process_frame

func check_driving(centers: Dictionary) -> void:
	check(not centers.has("reverse"), "The shared pedal should be the only reverse control")
	touch(0, centers.steer_l, true)
	touch(1, centers.gas, true)
	check(desk.get_move() == Vector2(-1, -1), "Steering and gas should work together")
	drag(0, centers.steer_l, centers.steer_r)
	check(desk.get_move() == Vector2(1, -1), "Sliding across the wheel should steer right while holding gas")
	# Start rolling between pressing and releasing the exit latch, before the next HUD redraw.
	touch(2, centers.interact, true)
	ticks(1)
	check(game.rig.speed > 0 and game.rig.speed < 0.2, "The truck should just be creeping forward")
	touch(2, centers.interact, false)
	check(game.rig.in_cab, "Releasing Exit after the wheels start moving should keep the driver in the cab")
	touch(1, centers.gas, false)
	touch(1, centers.brake, true)
	check(desk.brake_held() and desk.get_move() == Vector2.RIGHT, "A press while creeping should brake and preserve steering")
	await process_frame
	check(not check_layout([]).has("interact"), "Exit should be hidden even below one displayed MPH")
	touch(1, centers.brake, false)
	touch(1, centers.gas, true)
	ticks(60)
	touch(1, centers.gas, false)
	var forward_speed: float = game.rig.speed
	touch(1, centers.brake, true)
	ticks(1)
	check(game.rig.speed > 0 and game.rig.speed < forward_speed, "The brake should slow a moving truck progressively")
	ticks(90)
	check(game.rig.speed == 0 and desk.brake_held(), "Holding the original brake press should keep the truck parked")
	touch(2, centers.brake, true)
	check(desk.brake_held() and desk.get_move() == Vector2.RIGHT, "Another finger should not re-arm a pedal that is still held")
	touch(2, centers.brake, false)
	touch(1, centers.brake, false)
	touch(1, centers.brake, true)
	touch(2, centers.gas, true)
	check(not desk.brake_held() and desk.get_move() == Vector2.ONE, "Pressing the same pedal again at rest should reverse while steering")
	touch(2, centers.gas, false)
	ticks(45)
	check(game.rig.speed < -0.5, "Holding the new press should continue backing up")
	await process_frame
	check(not check_layout([]).has("interact"), "Exit should be hidden while backing up")
	touch(1, centers.brake, false)
	touch(0, centers.steer_r, false)
	check(desk.get_move() == Vector2.ZERO and not desk.brake_held(), "A pedal or arrow stayed pressed")
	touch(0, centers.map, true)
	touch(0, centers.map, false)
	check(desk.glance, "The plat should stay in lap view while the truck rolls")
	await process_frame
	touch(1, centers.brake, true)
	check(desk.brake_held(), "A fresh press while already backing up should brake")
	ticks(90)
	check(game.rig.speed == 0 and not desk.glance, "Braking in lap view should fully stop the truck before opening the full plat")
	touch(1, centers.brake, false)
	desk.dismiss()
	await process_frame
	var parked := check_layout(["interact"])
	if parked.has("interact"):
		touch(0, parked.interact, true)
		touch(0, parked.interact, false)
		check(not game.rig.in_cab, "Tapping Exit when parked should leave the cab")
		game._action("interact")

func run() -> void:
	root.add_child(screen)
	screen.size = Vector2i(800, 600)
	screen.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	desk = game.desk
	for resolution in [Vector2i(800, 600), Vector2i(2400, 1080)]:
		screen.size = resolution
		game.rig.set_spawn(Vector3(0, 0, 265), PI)
		game._refresh()
		# A screen contact activates the touch interface on headless and desktop builds.
		touch(0, Vector2(screen.size) / 2, true)
		touch(0, Vector2(screen.size) / 2, false)
		await process_frame
		await process_frame
		var centers := check_layout(CAB_CONTROLS)
		if failed:
			break
		await check_driving(centers)
		if failed:
			break
		desk.update_view(PAPER_STATE)
		for tab in PAPER_TABS:
			touch(0, centers[tab], true)
			touch(0, centers[tab], false)
			await process_frame
			check(desk.page == tab, "Tap did not open " + tab)
			var tabs := PAPER_TABS.duplicate()
			if tab == "map":
				# On the open plat, its tab turns the facing survey sheet.
				tabs[tabs.find("map")] = "turn_plat"
				await tap_key("turn_plat")
				check(desk.east_sheet, "The east sheet can be turned by touch")
				await tap_key("turn_plat")
				check(not desk.east_sheet, "The operator can turn back to Esker")
			centers = check_layout(tabs + ["close"])
			if tab == "radio":
				await check_sighting_pages()
			elif tab == "parts":
				await check_shop()
			if failed:
				break
		desk.dismiss()
		var foot_state := PAPER_STATE.merged({"in_cab": false, "work_available": true}, true)
		desk.update_view(foot_state)
		await process_frame
		centers = check_layout(["stick", "interact", "work", "pause"])
		check(not centers.has("camera"), "Driving camera switch should be stowed on foot")
		if failed:
			break
		touch(0, centers.work, true)
		check(desk.work_held(), "Winch should run while held")
		touch(0, centers.work, false)
		check(not desk.work_held(), "Releasing winch should stop it")
	if not failed:
		print("CHECKS PASSED — landscape touch targets, brake and reverse, stopped-only exit, multitouch steering, winch and paperwork tabs")
	quit(1 if failed else 0)
