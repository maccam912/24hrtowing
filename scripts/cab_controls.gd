extends RefCounted

const WHEEL := preload("res://assets/ui/controls/wheel.webp")
const ACCELERATOR := preload("res://assets/ui/controls/accelerator.webp")
const BRAKE := preload("res://assets/ui/controls/brake.webp")
const LATCH := preload("res://assets/ui/controls/latch.webp")
const GLOVE := preload("res://assets/ui/controls/glove.webp")
const PENDANT := preload("res://assets/ui/controls/work.webp")
const RADIO := preload("res://assets/ui/controls/radio.webp")
const PLAT := preload("res://assets/ui/controls/plat.webp")
const SLIP := preload("res://assets/ui/controls/slip.webp")

const INK := Color("#141b1c")
const METAL := Color("#c0b79d")
const LETTERING := Color("#f4edd4")
const AMBER := Color("#f4bb65")
const SHADOW := Color(0.015, 0.022, 0.023, 0.78)
const LABEL_HEIGHT := 23.0
const LABEL_SIZE := 18

static func wheel(surface, bounds: Rect2, left_down: bool, right_down: bool) -> void:
	var direction := int(right_down) - int(left_down)
	var center := bounds.get_center()
	var diameter := minf(bounds.size.y - 2.0, bounds.size.x - 62.0)
	var unit: float = surface.unit
	surface.draw_set_transform(center * unit, deg_to_rad(36.0 * direction), Vector2.ONE * unit)
	var rim := Rect2(-Vector2.ONE * diameter / 2, Vector2.ONE * diameter)
	_draw_hardware(surface, WHEEL, rim, false)
	surface.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * unit)
	for side: int in [-1, 1]:
		var pressed := direction == side
		var point := center + Vector2(side * (diameter / 2 + 13), 0)
		var chevron := PackedVector2Array([
			point + Vector2(-4 * side, -8), point + Vector2(4 * side, 0),
			point + Vector2(-4 * side, 8)])
		surface.draw_polyline(chevron, INK, 6.5, true)
		surface.draw_polyline(chevron, AMBER if pressed else LETTERING, 3.2, true)

static func paint(surface, id: String, bounds: Rect2, caption: String, down: bool) -> void:
	if id == "pause":
		_switch(surface, bounds.get_center(), 27.0, false, down)
		return

	var art := bounds.grow_individual(-4, -3, -4, -LABEL_HEIGHT - 4)
	var texture: Texture2D
	match id:
		"gas": texture = ACCELERATOR
		"brake": texture = BRAKE
		"radio": texture = RADIO
		"map": texture = PLAT
		"slip": texture = SLIP
		"interact": texture = LATCH if caption.ends_with("CAB") else GLOVE
		"work": texture = PENDANT
		"spot": _switch(surface,art.get_center(),25.0,caption == "SPOT ON",down)
		"camera": _switch(surface, art.get_center(), 27.0, true, down)
	if texture:
		var source_size := texture.get_size()
		var scale_ratio := minf(art.size.x / source_size.x, art.size.y / source_size.y)
		var size := source_size * scale_ratio
		var image := Rect2(art.get_center() - size / 2, size)
		if down and id in ["gas", "brake"]:
			# Show the pad tipping away around the bottom hinge.
			var travel := image.size.y * 0.22
			image.position.y += travel
			image.size.y -= travel
		elif down:
			image = image.grow(-2)
			image.position.y += 3.0
		_draw_hardware(surface, texture, image, down)
	_caption(surface, bounds, caption, down)

static func _draw_hardware(surface, texture: Texture2D, rect: Rect2, down: bool) -> void:
	var shade := rect
	shade.position += Vector2(1, 2 if down else 4)
	surface.draw_texture_rect(texture, shade, false, SHADOW)
	surface.draw_texture_rect(texture, rect, false, Color("#ffe1a9") if down else Color.WHITE)

static func _caption(surface, bounds: Rect2, caption: String, down: bool) -> void:
	var width: float = surface.scaled.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + 18
	var tag := Rect2(bounds.get_center().x - width / 2, bounds.end.y - LABEL_HEIGHT, width, LABEL_HEIGHT)
	var top_left := tag.position
	var bottom_right := tag.end
	var cut := 3.5
	var corners := PackedVector2Array([
		top_left + Vector2(cut, 0), Vector2(bottom_right.x, top_left.y),
		bottom_right - Vector2(0, cut), bottom_right - Vector2(cut, 0),
		Vector2(top_left.x, bottom_right.y), top_left + Vector2(0, cut)])
	surface.draw_colored_polygon(corners, AMBER if down else INK)
	surface.draw_line(corners[0], corners[1], METAL.darkened(0.4), 1.0, true)
	surface.fitted(tag, caption, surface.scaled, LABEL_SIZE, INK if down else LETTERING)

static func _switch(surface, center: Vector2, radius: float, camera: bool, down: bool) -> void:
	# A spun metal bezel holds the rubber-capped dash switch.
	surface.draw_circle(center + Vector2(0, 3), radius + 2, SHADOW, true, -1, true)
	surface.draw_circle(center, radius + 1, INK, true, -1, true)
	surface.draw_circle(center, radius, METAL.darkened(0.20), true, -1, true)
	surface.draw_arc(center, radius - 1, -PI, -0.35, 28, Color("#e0d7be"), 1.5, true)
	surface.draw_circle(center, radius - 3, Color("#121818"), true, -1, true)
	var face_center := center + Vector2(0, 1 if down else -1)
	surface.draw_circle(face_center, radius - 5, Color("#5f5141") if down else Color("#3e4441"), true, -1, true)
	surface.draw_arc(face_center, radius - 6, -PI, -0.45, 24, Color("#77796b"), 1.5, true)
	var colour := AMBER if down else LETTERING
	if camera:
		var body := Rect2(face_center - Vector2(11, 6), Vector2(22, 14))
		surface.draw_rect(body, colour)
		surface.draw_rect(Rect2(body.position + Vector2(4, -3), Vector2(8, 3)), colour)
		surface.draw_circle(face_center + Vector2(1, 1), 5.0, INK, true, -1, true)
		surface.draw_circle(face_center + Vector2(1, 1), 2.8, colour, true, -1, true)
	else:
		for x in [-6, 2]:
			surface.draw_rect(Rect2(face_center + Vector2(x, -7), Vector2(4, 14)), colour)
