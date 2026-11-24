extends SceneTree

const Desk := preload("res://scripts/desk.gd")
const CAB_CONTROLS := ["steer_l", "steer_r", "gas", "brake", "reverse", "interact", "radio", "map", "slip", "camera", "pause"]

var screen := SubViewport.new()
var desk := Desk.new()
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
	# At 360 dp landscape height, every displayed target should be at least 48 dp.
	var minimum := screen.size.y * (48.0 / 360.0)
	var previous: Array[Rect2] = []
	for entry in desk.surface.hit_boxes:
		var box: Rect2 = entry.rect
		var target := Rect2(box.position * desk.surface.unit, box.size * desk.surface.unit)
		check(bounds.encloses(target), entry.id + " extends off-screen")
		check(target.size.x + 0.01 >= minimum and target.size.y + 0.01 >= minimum, entry.id + " is too small")
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

func run() -> void:
	root.add_child(screen)
	screen.add_child(desk)
	for resolution in [Vector2i(800, 600), Vector2i(2400, 1080)]:
		screen.size = resolution
		desk.start_play()
		desk.update_view({"in_cab": true})
		# A screen contact activates the touch interface on headless and desktop builds.
		touch(0, Vector2(screen.size) / 2, true)
		touch(0, Vector2(screen.size) / 2, false)
		await process_frame
		await process_frame
		var centers := check_layout(CAB_CONTROLS)
		if failed:
			break
		touch(0, centers.steer_l, true)
		touch(1, centers.gas, true)
		check(desk.get_move() == Vector2(-1, -1), "Steering and gas should work together")
		drag(0, centers.steer_l, centers.steer_r)
		check(desk.get_move() == Vector2(1, -1), "Sliding across the wheel should steer right while holding gas")
		touch(1, centers.gas, false)
		touch(1, centers.brake, true)
		check(desk.brake_held() and desk.get_move() == Vector2.RIGHT, "Switching to brake lost steering or kept the gas down")
		touch(0, centers.steer_r, false)
		touch(1, centers.brake, false)
		check(desk.get_move() == Vector2.ZERO and not desk.brake_held(), "A pedal or arrow stayed pressed")
		touch(0, centers.steer_r, true)
		touch(1, centers.reverse, true)
		check(desk.get_move() == Vector2.ONE, "Reverse and right steering should work together")
		touch(1, centers.reverse, false)
		touch(0, centers.steer_r, false)
		desk.update_view({"in_cab": false, "work_available": true})
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
		print("CHECKS PASSED — landscape touch targets, multitouch driving and winching")
	quit(1 if failed else 0)
