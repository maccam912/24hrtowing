extends Node3D
## The marks on the road, the warm cab and the grip at the tires all use
## the same surveyed length. Filed tickets give the wet pavement time to freeze.
const DRY := "dry_road"
const ROOF := "snow_roof"
const HALF_WIDTH := 4.6
var county
var kind := ""
var axis := Vector2.ZERO
var center := Vector2.ZERO
var half_length := 52.5
var freeze := 0.0
var vapor := Node3D.new()

static func locate(roads, ahead: Vector3, front: Vector3, id: String) -> Dictionary:
	var along := Vector2(front.x,front.z)
	var hit: Dictionary = roads._nearest(Vector2(ahead.x,ahead.z),along)
	if hit.is_empty() or hit.section.name == roads.GATE: return {}
	var a: Vector2 = hit.section.a
	var b: Vector2 = hit.section.b
	var run := a.direction_to(b)
	if absf(run.dot(along)) < .85: return {}
	var half := minf(100.0 if id==ROOF else 52.5,a.distance_to(b)*.5-2.)
	if half < 12.: return {}
	var station := clampf((Vector2(hit.point)-a).dot(run),half+1.,a.distance_to(b)-half-1.)
	var point := a+run*station
	# The bridge has an elevated steel deck over the dam.
	if absf(run.x)>.9 and absf(point.y)<5 and point.x-half < -417 and point.x+half > -453: return {}
	if run.dot(along)<0: run = -run
	return {"center":Vector3(point.x,0,point.y),"yaw":atan2(-run.x,-run.y),"half":half,"road":hit.section.name}

func configure(world, entry: Dictionary) -> void:
	county = world
	kind = entry.id
	center = Vector2(entry.x,entry.z)
	var bearing := Vector3.FORWARD.rotated(Vector3.UP,entry.yaw)
	axis = Vector2(bearing.x,bearing.z)
	half_length = entry.get("half_length",52.5)
	add_child(vapor)
	if kind == DRY:
		for i in 6:
			var across := -2.4 if i%2 else 1.8
			var point := center + axis * ((i-2.5)*half_length*.33) + Vector2(-axis.y,axis.x)*across
			var sheet := QuadMesh.new()
			sheet.size = Vector2(7.,2.0)
			var steam := ShaderMaterial.new()
			steam.shader = preload("res://assets/county/ground_vapor.gdshader")
			steam.set_shader_parameter("seed",i*.23)
			sheet.material = steam
			var wisp := MeshInstance3D.new()
			vapor.add_child(wisp)
			wisp.mesh = sheet
			wisp.position = Vector3(point.x,county.ground_height(point.x,point.y)+.85,point.y)
			wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wisp.visibility_range_end = 110.
	county.thawed_roads[kind] = self
	set_age(0)

func _exit_tree() -> void:
	if is_instance_valid(county) and county.thawed_roads.get(kind)==self:
		county.thawed_roads.erase(kind)
		county.materials.road.set_shader_parameter(kind+"_half",0.0)

func set_age(jobs: int) -> void:
	freeze = [0.,.43,.82,1.][clampi(jobs,0,3)]
	vapor.visible = freeze < .8
	for wisp: MeshInstance3D in vapor.get_children():
		wisp.transparency = freeze
	var shader: ShaderMaterial = county.materials.road
	shader.set_shader_parameter(kind+"_strip",geometry())
	shader.set_shader_parameter(kind+"_half",half_length)
	shader.set_shader_parameter(kind+"_freeze",freeze)

func geometry() -> Vector4:
	return Vector4(center.x,center.y,axis.x,axis.y)

func coverage(at: Vector3, width := HALF_WIDTH) -> float:
	var delta := Vector2(at.x,at.z)-center
	return (1.-smoothstep(width-.8,width,absf(delta.cross(axis)))) * (1.-smoothstep(half_length-3.,half_length,absf(delta.dot(axis))))

func contact(at: Vector3) -> Vector2:
	var mask := coverage(at)
	if mask<=0.: return Vector2(1.,0.)
	var along := absf((Vector2(at.x,at.z)-center).dot(axis))
	var rim := smoothstep(half_length-12.,half_length-3.,along)
	var grip := lerpf(1.25,.65,maxf(rim,freeze))
	# By the fourth ticket snow is accumulating on the glaze.
	grip = lerpf(grip,.88,smoothstep(.85,1.,freeze))
	var warmth := mask*(1.-freeze)*(1.-rim) if kind==DRY else 0.
	return Vector2(lerpf(1.,grip,mask),warmth)
