extends RefCounted
## Groups static props by 96 m cells. Godot can cull a farm or a grove as a unit.
const CELL := 96.0
var parent: Node3D
var materials: Dictionary
var batches := {}
var primitives := {}
var collision_bins := {}

func _init(owner: Node3D, palette: Dictionary) -> void:
	parent = owner
	materials = palette

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

func _batch(p: Vector3, material: String, custom_faces := false) -> SurfaceTool:
	var key := _cell(p)
	if not batches.has(key):
		batches[key] = {}
	var group: Dictionary = batches[key]
	var surface_key := material + ("_faces" if custom_faces else "_primitives")
	if not group.has(surface_key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(materials[material])
		group[surface_key] = surface
	return group[surface_key]

func _primitive(kind: String) -> PrimitiveMesh:
	if primitives.has(kind):
		return primitives[kind]
	var mesh: PrimitiveMesh
	match kind:
		"box":
			mesh = BoxMesh.new()
		"mound":
			var drift := SphereMesh.new()
			drift.radial_segments = 12
			drift.rings = 4
			drift.height = 1.
			drift.radius = .5
			mesh = drift
		"quad":
			mesh = QuadMesh.new()
		_:
			var cyl := CylinderMesh.new()
			cyl.radial_segments = 8 if kind == "cylinder" else 6
			cyl.rings = 0
			cyl.height = 1.0
			cyl.top_radius = 0 if kind == "cone" else 0.5
			cyl.bottom_radius = 0.5
			mesh = cyl
	primitives[kind] = mesh
	return mesh

func add(kind: String, p: Vector3, size: Vector3, material: String, angle := Vector3.ZERO) -> void:
	var orientation := Basis.from_euler(angle) * Basis.from_scale(size)
	_batch(p, material).append_from(_primitive(kind), 0, Transform3D(orientation, p))

func box(p: Vector3, size: Vector3, material: String, solid := false, angle := Vector3.ZERO) -> void:
	add("box", p, size, material, angle)
	if solid:
		solid_box(p, size, angle)

func solid_box(p: Vector3, size: Vector3, angle := Vector3.ZERO) -> void:
	var key := _cell(p)
	if not collision_bins.has(key):
		var body := StaticBody3D.new()
		parent.add_child(body)
		collision_bins[key] = body
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = p
	col.rotation = angle
	collision_bins[key].add_child(col)

func beam(a: Vector3, b: Vector3, width: float, depth: float, material: String) -> void:
	var y_axis := a.direction_to(b)
	if y_axis.length_squared() < 0.9:
		return
	var helper := Vector3.FORWARD if absf(y_axis.z) < 0.95 else Vector3.RIGHT
	var x_axis := y_axis.cross(helper).normalized()
	var z_axis := x_axis.cross(y_axis)
	var armature := Basis(x_axis * width, y_axis * a.distance_to(b), z_axis * depth)
	var center := (a+b) * 0.5
	_batch(center, material).append_from(_primitive("box"), 0, Transform3D(armature, center))

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: String, uv: PackedVector2Array = PackedVector2Array()) -> void:
	var surface := _batch((a+c)*0.5,material,true)
	var vertices := [a,b,c,d]
	var normal := (c-a).cross(b-a).normalized()
	var tex := uv if uv.size() == 4 else PackedVector2Array([Vector2(0,1), Vector2(0,0), Vector2(1,0), Vector2(1,1)])
	for i in [0,1,2,0,2,3]:
		surface.set_normal(normal)
		surface.set_uv(tex[i])
		surface.add_vertex(vertices[i])

func finish() -> void:
	for key: Vector2i in batches:
		var mesh := ArrayMesh.new()
		for id: String in batches[key]:
			var batch: SurfaceTool = batches[key][id]
			batch.commit(mesh)
		var geometry := MeshInstance3D.new()
		geometry.name = "Section_%d_%d" % [key.x, key.y]
		geometry.mesh = mesh
		geometry.visibility_range_end = 230.0
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(geometry)
	batches.clear()
