extends RefCounted
## Every grain follows the same field around the camera. The four vertices share
## a seed so the renderer can draw the entire field as one ordinary mesh.

const CORNERS := [Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, -0.5), Vector2(-0.5, -0.5)]
const TRIANGLES := [0, 1, 2, 0, 2, 3]

static func build(material: ShaderMaterial, rng: RandomNumberGenerator, count: int) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var seeds := PackedFloat32Array()
	var indices := PackedInt32Array()
	vertices.resize(count * 4)
	uvs.resize(count * 4)
	seeds.resize(count * 16)
	indices.resize(count * 6)
	for grain in count:
		var seed_value := Vector4(rng.randf(), rng.randf(), rng.randf(), rng.randf())
		for corner in 4:
			var point: Vector2 = CORNERS[corner]
			var vertex := grain * 4 + corner
			vertices[vertex] = Vector3(point.x, point.y, 0.0)
			uvs[vertex] = Vector2(point.x + 0.5, 0.5 - point.y)
			for component in 4:
				seeds[vertex * 4 + component] = seed_value[component]
		for index in 6:
			indices[grain * 6 + index] = grain * 4 + TRIANGLES[index]

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = seeds
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, material)
	var field := MeshInstance3D.new()
	field.name = "AirborneSnow"
	field.mesh = mesh
	field.custom_aabb = AABB(Vector3(-33, -12, -33), Vector3(66, 24, 66))
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return field
