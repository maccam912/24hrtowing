extends RefCounted
## An interrupted pair of tire tracks and the moving car share a single course.
const TRACK_START := 7.0
const TRACK_RUN := 21.0
const GROVE_OFFSETS := [Vector2(1.0,.71),Vector2(6.2,.77),Vector2(12.8,.68)]
var course := Curve3D.new()
var entry := Vector3.ZERO
var roadside := Vector3.ZERO
var forward := Vector3.FORWARD
var across := Vector3.RIGHT
var level := 0.0

static func has_room(game, bank: Vector3, along: Vector3) -> bool:
	var side := along.cross(Vector3.UP)
	var lane := bank-side*6.65-along*44.
	if game.county.road_distance(lane.x,lane.z)>4.6: return false
	var space: PhysicsDirectSpaceState3D = game.rig.get_world_3d().direct_space_state
	for offset: float in [TRACK_START,TRACK_START+TRACK_RUN*.5,TRACK_START+TRACK_RUN]:
		var at := bank+side*offset
		if game.county.road_distance(at.x,at.z)<6.: return false
		var floor_y: float = game.county.ground_height(at.x,at.z)
		if floor_y < -2.: return false
		var ground_at := Vector3(at.x,floor_y,at.z)
		var ray := PhysicsRayQueryParameters3D.create(ground_at+Vector3.UP*8.,ground_at+Vector3.UP*.65,1)
		if not space.intersect_ray(ray).is_empty(): return false
	return true

func set_course(at: Vector3, along: Vector3, terrain: Callable) -> void:
	roadside = at
	forward = along
	across = along.cross(Vector3.UP)
	entry = at - across*6.65 - along*44.
	level = terrain.call(entry).y
	var end := at+across*(TRACK_START+TRACK_RUN)
	course.clear_points()
	course.bake_interval = .30
	# The tires leave their lane on a curve. By the time they cross the bank,
	# their direction already lines up with the narrow passage through the trunks.
	course.add_point(entry,Vector3.ZERO,along*18.)
	course.add_point(at,-across*7.,across*8.)
	course.add_point(end,-across*7.,Vector3.ZERO)

func move_car(car: Node3D, elapsed: float) -> void:
	var distance := course.get_baked_length()*clampf((elapsed-.05)/.80,0.,1.)
	var place := course.sample_baked(distance,true)
	var next := course.sample_baked(minf(distance+.25,course.get_baked_length()),true)
	var heading := place.direction_to(next) if place.distance_squared_to(next)>.00001 else across
	place.y = level+.22*smoothstep(12.,39.,distance)
	car.position = place
	car.rotation = Vector3(0.,atan2(-heading.x,-heading.z),0.)
	car.visible = elapsed<.86

static func lamps(car: Node3D) -> void:
	var size: Vector3 = car.get_meta("body_size")
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://assets/county/tail_glow.gdshader")
	var lens := QuadMesh.new()
	lens.size = Vector2(1.00,.64)
	lens.material = glow
	for side: float in [-1.,1.]:
		var red := MeshInstance3D.new()
		red.name = "LeftTailGlow" if side<0 else "RightTailGlow"
		red.mesh = lens
		red.position = Vector3(side*size.x*.82,size.y+.25,size.z+.024)
		red.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.add_child(red)
