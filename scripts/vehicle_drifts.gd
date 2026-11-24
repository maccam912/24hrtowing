extends RefCounted
## Wind packs a steep lip against each tire, then leaves a long taper downwind.
const WIND := Vector3(0.968, 0.0, 0.252)
const ACROSS := Vector3(-WIND.z, 0.0, WIND.x)
const LENGTH_STEPS := 12
const WIDTH_STEPS := 8
static var powder: StandardMaterial3D

static func place(car: Node3D, ground_height: Callable) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first_vertex := 0
	for side: float in [-1.0, 1.0]:
		for axle: float in [-1.0, 1.0]:
			var wheel := car.global_basis * Vector3(side * 0.89, 0.0, axle * 1.29)
			var exposure := clampf(0.5 + wheel.dot(WIND) * 0.32, 0.0, 1.0)
			_append_drift(surface, first_vertex, car.global_position, wheel, exposure, ground_height)
			first_vertex += (LENGTH_STEPS + 1) * (WIDTH_STEPS + 1)
	surface.generate_normals()
	var bank := MeshInstance3D.new()
	bank.name = "SettledSnow"
	bank.mesh = surface.commit()
	if not powder:
		powder = StandardMaterial3D.new()
		powder.albedo_texture = preload("res://assets/county/windpack.png")
		powder.albedo_color = Color("#d7dfe6")
		powder.vertex_color_use_as_albedo = true
		powder.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		powder.roughness = 1.0
	bank.material_override = powder
	# The vehicle owns cleanup, but the deposits stay at the original wheel
	# locations through winching, lift, haul and restoration of a saved tow.
	bank.top_level = true
	car.add_child(bank)
	bank.global_position = car.global_position

static func _append_drift(surface: SurfaceTool, first: int, center: Vector3, wheel: Vector3, exposure: float, ground_height: Callable) -> void:
	var length := lerpf(2.35, 3.55, exposure)
	var height := lerpf(0.41, 0.55, exposure)
	var phase := fposmod(center.x * 0.24 + center.z * 0.19 + wheel.x * 3.1, TAU)
	for row in LENGTH_STEPS + 1:
		var t := float(row) / LENGTH_STEPS
		var lip := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.25, 1.0, t))
		var spine := wheel + WIND * (t * length - 0.58)
		spine += ACROSS * (0.10 + t * 0.18) * sin(t * 5.9 + phase)
		var width := (0.15 + 0.87 * sin(PI * pow(t, 0.76))) * lerpf(0.86, 1.18, exposure)
		var ridge := 0.19 * sin(t * 5.2 + phase)
		for col in WIDTH_STEPS + 1:
			var across := float(col) * 2.0 / WIDTH_STEPS - 1.0
			var point := center + spine + ACROSS * (across * width)
			point.y = ground_height.call(point)
			# Bury the skirt in the shoulder so the toe feathers into the terrain.
			var flank := absf(across - ridge) / (1.0 - signf(across - ridge) * ridge)
			var depth := height * lip * (1.0 - smoothstep(0.0, 1.0, flank))
			point.y += depth - 0.075
			surface.set_color(Color(1.0, 1.0, 1.0, smoothstep(0.04, 0.24, depth)))
			surface.set_uv(Vector2(point.x * 0.18, point.z * 0.16))
			surface.add_vertex(point - center)
			if row > 0 and col > 0:
				var corner := first + (row - 1) * (WIDTH_STEPS + 1) + col - 1
				for offset: int in [0, WIDTH_STEPS + 1, WIDTH_STEPS + 2, 0, WIDTH_STEPS + 2, 1]:
					surface.add_index(corner + offset)
