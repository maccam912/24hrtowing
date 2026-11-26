extends RefCounted
## Batches the hard-surface parts of one vehicle into a handful of draw calls.
var parent: Node3D
var groups := {}
var cache := {}
var shade := "paint"
var default_material: StandardMaterial3D
static var materials := {}

func _init(owner: Node3D) -> void:
	parent = owner

static func material(style: String) -> StandardMaterial3D:
	if materials.has(style):
		return materials[style]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	if style == "metal":
		mat.metallic = 0.28
		mat.roughness = 0.52
	if style == "lamp":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif style == "vinyl":
		if ResourceLoader.exists("res://assets/rig/cab_vinyl.jpg"):
			mat.albedo_texture = load("res://assets/rig/cab_vinyl.jpg")
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE * 5.0
		mat.roughness = 0.93
	materials[style] = mat
	return mat

func mesh_at(source: PrimitiveMesh, position: Vector3, basis: Basis, color: Color, style := "paint") -> void:
	if not groups.has(style):
		groups[style] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray(), PackedInt32Array()]
	var g: Array = groups[style]
	var a := source.get_mesh_arrays()
	var n_basis := basis.inverse().transposed()
	var offset: int = g[0].size()
	for i in a[Mesh.ARRAY_VERTEX].size():
		g[0].append(position + basis * (a[Mesh.ARRAY_VERTEX][i] as Vector3))
		g[1].append((n_basis * (a[Mesh.ARRAY_NORMAL][i] as Vector3)).normalized())
		g[2].append(a[Mesh.ARRAY_TEX_UV][i])
		g[3].append(color)
	for i: int in a[Mesh.ARRAY_INDEX]:
		g[4].append(offset + i)

func box(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, style := "paint") -> void:
	if not cache.has("box"):
		var primitive := BoxMesh.new()
		primitive.size = Vector3.ONE
		cache.box = primitive
	mesh_at(cache.box, pos, Basis.from_euler(rot) * Basis.from_scale(size), col, style)

func tube(a: Vector3, b: Vector3, radius: float, color: Color, sides := 8, style := "metal", end_radius := -1.0) -> void:
	var displacement := b-a
	if displacement.length_squared() < 0.000001:
		return
	var ratio := end_radius / radius if end_radius >= 0 else 1.0
	var key := "%d/%.3f" % [sides, ratio]
	if not cache.has(key):
		var c := CylinderMesh.new()
		c.top_radius = ratio
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = sides
		c.rings = 0
		cache[key] = c
	var b_rot := Basis(Quaternion(Vector3.UP, displacement.normalized()))
	mesh_at(cache[key], (a+b)*0.5, b_rot * Basis.from_scale(Vector3(radius,displacement.length(),radius)),color,style)

func beam(a: Vector3, b: Vector3, width: float, depth: float, color: Color, style := "paint") -> void:
	var d := b-a
	var r := Quaternion(Vector3.UP,d.normalized()).get_euler()
	box((a+b)*0.5,Vector3(width,d.length(),depth),color,r,style)

func ring(pos: Vector3, inside: float, outside: float, col: Color, rot := Vector3.ZERO, style := "paint") -> void:
	var tor := TorusMesh.new()
	tor.inner_radius = inside
	tor.outer_radius = outside
	tor.rings = 32
	tor.ring_segments = 6
	mesh_at(tor,pos,Basis.from_euler(rot),col,style)

func truck_wheel(side: float, z: float, radius: float, x: float, floor_y: float) -> void:
	var rubber := Color("#292d2e")
	var steel := Color("#989b93")
	var at := Vector3(side*x,radius+floor_y,z)
	tube(at-Vector3.RIGHT*.17,at+Vector3.RIGHT*.17,radius,rubber,16)
	var face := at+Vector3.RIGHT*side*.18
	tube(face,face+Vector3.RIGHT*side*.025,radius*.60,steel,12)
	tube(face+Vector3.RIGHT*side*.03,face+Vector3.RIGHT*side*.073,radius*.23,rubber,10)
	for lug in 6:
		var p := face+Vector3(side*.029,cos(lug*TAU/6),sin(lug*TAU/6))*Vector3(1,radius*.38,radius*.38)
		tube(p,p+Vector3.RIGHT*side*.022,.032,rubber,6)

func finish() -> MeshInstance3D:
	var baked := ArrayMesh.new()
	for style: String in groups:
		var g: Array = groups[style]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX]=g[0]
		a[Mesh.ARRAY_NORMAL]=g[1]
		a[Mesh.ARRAY_TEX_UV]=g[2]
		a[Mesh.ARRAY_COLOR]=g[3]
		a[Mesh.ARRAY_INDEX]=g[4]
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		baked.surface_set_material(baked.get_surface_count()-1,material(style))
	var instance := MeshInstance3D.new()
	instance.mesh=baked
	parent.add_child(instance)
	groups.clear()
	return instance

static func joint(p: Node3D, pos: Vector3, label := "") -> Node3D:
	var n := Node3D.new()
	if not label.is_empty():
		n.name = label
	p.add_child(n)
	n.position = pos
	return n

static var fonts := {}
static func label(p:Node3D, words:String, pos:Vector3, height:float, color:Color, rot := Vector3.ZERO, font_name := "overpass") -> Label3D:
	var l := Label3D.new()
	l.text = words
	var path := "res://assets/ui/fonts/%s.ttf" % font_name
	if not fonts.has(path) and ResourceLoader.exists(path):
		fonts[path] = load(path)
	if fonts.has(path):
		l.font = fonts[path]
	l.font_size=42
	l.pixel_size=height/42.0
	l.outline_size=0
	l.modulate=color
	l.position=pos
	l.rotation=rot
	l.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.double_sided=false
	p.add_child(l)
	return l
