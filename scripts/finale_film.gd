extends CanvasLayer

signal finished

const DURATION := 11.5
const REVERSE_ANGLE := 4.35
const OVERPASS := preload("res://assets/ui/fonts/overpass.ttf")
const MONO := preload("res://assets/ui/fonts/plex_mono.ttf")

var active := false
var elapsed := 0.0
var camera: Camera3D
var previous_camera: Camera3D
var from_cab := Vector3.ZERO
var from_road := Vector3.ZERO
var sedan := Vector3.ZERO
var screen := Control.new()
var top_bar := ColorRect.new()
var bottom_bar := ColorRect.new()
var shade := TextureRect.new()
var radio := Label.new()
var creator := Label.new()
var assistance := Label.new()
var skip_button := Button.new()

func _ready() -> void:
	layer = 20
	hide()
	set_process_input(false)
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	for bar: ColorRect in [top_bar, bottom_bar]:
		screen.add_child(bar)
		bar.color = Color("#0c1011")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0

	# A transparent falloff below the image keeps the type legible over a lit snowbank.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.03,0.05,0.06,0.0),Color(0.03,0.05,0.06,0.82)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5,0.0)
	texture.fill_to = Vector2(0.5,1.0)
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 0.56
	screen.move_child(shade,0)

	_style_label(radio, OVERPASS, 22, Color("#f5f1e7"))
	radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio.anchor_left = 0.08
	radio.anchor_right = 0.92

	_style_label(creator, OVERPASS, 36, Color("#faf3df"))
	creator.text = "A game by maccam912"
	_style_label(assistance, MONO, 18, Color("#e6dac0"))
	assistance.text = "With help from Astra 6.2"
	for line: Label in [creator, assistance]:
		line.anchor_left = 0.07
		line.anchor_right = 0.95

	screen.add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -108.0
	skip_button.offset_right = -12.0
	skip_button.offset_top = 0.0
	skip_button.offset_bottom = 48.0
	skip_button.flat = true
	skip_button.text = "Skip"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_override("font", MONO)
	skip_button.add_theme_font_size_override("font_size", 17)
	skip_button.add_theme_color_override("font_color", Color("#dbd9ca"))
	skip_button.add_theme_color_override("font_outline_color", Color("#111817"))
	skip_button.add_theme_constant_override("outline_size", 3)
	skip_button.pressed.connect(skip)

func _style_label(label: Label, face: Font, size_px: int, ink: Color) -> void:
	screen.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_shadow_color", Color("#14191be0"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 3)

func start(game, landing: Vector3) -> void:
	if active:
		return
	sedan = landing
	from_cab = game.rig.body.to_global(game.rig.Truck.EYE)
	# Place the reverse angle on the road side of the sedan, clear of the ditch
	# and the trees beyond it. Its running lamps face back into the frame.
	var trace: Dictionary = game.sightings.aftermath.get("shoulder_car", {})
	var facing := Vector3.FORWARD.rotated(Vector3.UP, float(trace.get("yaw", game.rig.heading)))
	var nearest: Dictionary = game.current_road_map().nearest_section(Vector2(sedan.x, sedan.z))
	var pavement := Vector3(nearest.point.x, sedan.y, nearest.point.y)
	var toward_road := sedan.direction_to(pavement)
	from_road = game.county.surface_point(sedan + facing * 10.0 + toward_road * 2.0) + Vector3.UP * 1.95
	previous_camera = game.world_view.get_camera_3d()
	camera = Camera3D.new()
	camera.name = "FinaleCamera"
	game.world.add_child(camera)
	camera.near = 0.08
	radio.text = game.sightings.SET_DOWN_LINE
	elapsed = 0.0
	active = true
	set_process_input(true)
	_frame()
	camera.make_current()
	show()

func advance(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if elapsed >= DURATION:
		skip()
	else:
		_frame()

func _frame() -> void:
	var focus := sedan + Vector3.UP * 0.88
	if elapsed < REVERSE_ANGLE:
		camera.global_position = from_cab
		camera.look_at(focus)
		camera.fov = lerpf(61.0, 56.0, smoothstep(0.0, REVERSE_ANGLE, elapsed))
	else:
		# A gentle push holds the sedan and the lights of the wrecker in one shot.
		var push := smoothstep(REVERSE_ANGLE, DURATION, elapsed)
		camera.global_position = from_road.lerp(focus, 0.09 * push)
		camera.look_at(focus)
		camera.rotate_object_local(Vector3.UP, deg_to_rad(5.0))
		camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(-2.0))
		camera.fov = 41.0
	var matte := smoothstep(0.0, 0.58, elapsed) * (1.0 - smoothstep(DURATION - 0.8, DURATION, elapsed))
	var bar_height := clampf(screen.size.y * 0.077, 34.0, 64.0)
	top_bar.offset_bottom = bar_height * matte
	bottom_bar.offset_top = -bar_height * matte
	shade.modulate.a = matte
	radio.offset_top = -bar_height - 94.0
	radio.offset_bottom = -bar_height - 12.0
	radio.modulate.a = 1.0 - smoothstep(REVERSE_ANGLE - 0.55, REVERSE_ANGLE, elapsed)
	creator.offset_top = -bar_height - 104.0
	creator.offset_bottom = -bar_height - 52.0
	assistance.offset_top = -bar_height - 52.0
	assistance.offset_bottom = -bar_height - 22.0
	var fade_out := 1.0 - smoothstep(DURATION - 1.6, DURATION - 0.35, elapsed)
	creator.modulate.a = smoothstep(REVERSE_ANGLE + 0.15, REVERSE_ANGLE + 1.05, elapsed) * fade_out
	assistance.modulate.a = smoothstep(REVERSE_ANGLE + 0.55, REVERSE_ANGLE + 1.55, elapsed) * fade_out

func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			skip()

func skip() -> void:
	if active:
		stop()
		finished.emit()

func stop() -> void:
	if not active:
		return
	active = false
	hide()
	set_process_input(false)
	if is_instance_valid(previous_camera) and camera.current:
		previous_camera.make_current()
	camera.queue_free()
	camera = null
	previous_camera = null
