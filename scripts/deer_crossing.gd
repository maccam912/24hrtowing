extends Node3D
## A line of whitetails watches the sky. Their footfalls return along the
## same path as the hoofprints the operator can find on the next pass.
const Kit := preload("res://scripts/rig_mesh.gd")
const OFFSETS := [-5.8,-2.9,0.0,2.9,5.8]
const SIZES := [0.90,0.78,1.04,0.86,0.98]
const COATS := [Color("#806751"),Color("#88715a"),Color("#79634e"),Color("#927861"),Color("#806a53")]
const CREAM := Color("#ddd5b9")
const DARK := Color("#353128")
const CROSSING_RUN := 20.0
const BANK_OFFSET := 8.5
const LEG_PHASES: Array[float] = [0.,2.5,PI,PI+2.5]
var deer: Array[Node3D] = []
var heads: Array[Node3D] = []
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var origin := Vector3.ZERO
var along := Vector3.RIGHT
var ground: Callable
var pelt := SphereMesh.new()

static func has_room(game, center: Vector3, forward: Vector3, street: String) -> bool:
	var roads = game._current_road_map()
	var across := forward.cross(Vector3.UP)
	var space: PhysicsDirectSpaceState3D = game.rig.get_world_3d().direct_space_state
	for offset: float in [-16.,0.,16.]:
		var lane := center+forward*offset
		if roads.driven_road(Vector2(lane.x,lane.z)) != street or game.county.road_distance(lane.x,lane.z)>3.0:
			return false
	# The herd needs open banks, outside the river or another traveled lane.
	for offset: float in [-7.5,7.5,14.0,20.0,25.8]:
		var step := center+across*offset
		var floor_y: float = game.county.ground_height(step.x,step.z)
		if floor_y < -2.3 or game.county.road_distance(step.x,step.z)<6.0: return false
		var low := Vector3(step.x,floor_y+.28,step.z)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(low+Vector3.UP*3.,low,1)).is_empty(): return false
	return true

func build(parent: Node3D, center: Vector3, travel: Vector3, floor_at: Callable) -> void:
	parent.add_child(self)
	name = "DeerCrossing"
	origin = center
	along = travel
	ground = floor_at
	pelt.radius = .5
	pelt.height = 1.
	pelt.radial_segments = 8
	pelt.rings = 3
	for index in OFFSETS.size():
		_add_deer(index)
	pose(0.)

func _add_deer(index: int) -> void:
	var stag := index==2
	var coat: Color = COATS[index]
	var body := Kit.joint(self,Vector3.ZERO,"Whitetail")
	body.scale = Vector3.ONE*SIZES[index]
	body.rotation.y = atan2(-along.x,-along.z)
	var k := Kit.new(body)
	k.mesh_at(pelt,Vector3(0,.94,.04),Basis.from_scale(Vector3(.46,.55,1.36)),coat)
	k.mesh_at(pelt,Vector3(0,.91,.41),Basis.from_scale(Vector3(.43,.56,.55)),coat)
	k.mesh_at(pelt,Vector3(0,.86,-.33),Basis.from_scale(Vector3(.37,.50,.59)),coat)
	k.mesh_at(pelt,Vector3(0,.73,.03),Basis.from_scale(Vector3(.31,.17,.86)),Color("#b3a084"))
	k.beam(Vector3(0,1.03,.55),Vector3(0,.78,.73),.13,.13,CREAM)
	k.box(Vector3(0,.96,.64),Vector3(.15,.15,.16),coat,Vector3(.48,0,0))
	k.finish()
	var head := Kit.joint(body,Vector3(0,1.05,-.40),"Head")
	var h := Kit.new(head)
	h.beam(Vector3.ZERO,Vector3(0,.41,-.29),.21,.22,coat)
	h.beam(Vector3(0,.13,-.09),Vector3(0,.36,-.33),.14,.10,CREAM)
	h.mesh_at(pelt,Vector3(0,.45,-.36),Basis.from_scale(Vector3(.24,.23,.32)),coat)
	h.beam(Vector3(0,.44,-.42),Vector3(0,.38,-.65),.14,.14,coat)
	h.box(Vector3(0,.39,-.66),Vector3(.123,.088,.055),DARK)
	for side: float in [-1.,1.]:
		h.box(Vector3(side*.108,.477,-.40),Vector3(.018,.036,.045),DARK)
		h.beam(Vector3(side*.076,.49,-.29),Vector3(side*.245,.67,-.25),.09,.056,coat)
		h.beam(Vector3(side*.12,.54,-.315),Vector3(side*.219,.64,-.272),.048,.033,CREAM)
		if stag:
			h.beam(Vector3(side*.074,.52,-.36),Vector3(side*.24,.85,-.23),.041,.045,Color("#a39074"))
			h.beam(Vector3(side*.17,.70,-.28),Vector3(side*.25,.80,-.43),.030,.034,Color("#b8aa8d"))
			h.beam(Vector3(side*.24,.84,-.23),Vector3(side*.28,.93,-.33),.027,.028,Color("#b8aa8d"))
	h.finish()
	for flank: float in [-1.,1.]:
		for end: float in [-1.,1.]:
			var hip := Kit.joint(body,Vector3(flank*.14,.78,end*.41))
			var thigh := Kit.new(hip)
			thigh.beam(Vector3.ZERO,Vector3(0,-.35,.02*end),.095,.105,coat)
			thigh.finish()
			var knee := Kit.joint(hip,Vector3(0,-.35,.02*end))
			var shin := Kit.new(knee)
			shin.beam(Vector3.ZERO,Vector3(0,-.34,-.04),.062,.065,coat)
			shin.box(Vector3(0,-.386,-.059),Vector3(.082,.090,.125),DARK)
			shin.finish()
			legs.append(hip)
			knees.append(knee)
	deer.append(body)
	heads.append(head)

func pose(t: float) -> void:
	var leaving := clampf((t-.55)/.43,0.,1.)
	# The calm lifts for the whole line together. At the beginning and end
	# of their walk stride length tapers so hooves come to rest on the snow.
	var distance := CROSSING_RUN*leaving*leaving*(3.-2.*leaving)
	var gait := smoothstep(0.,.09,leaving)*(1.-smoothstep(.93,1.,leaving))
	for i in deer.size():
		var stride: float = distance/SIZES[i]*4.5+float(i)*1.87
		var at: Vector3 = ground.call(origin+along*(OFFSETS[i]+distance))
		deer[i].position = at+Vector3.UP*.037*absf(sin(stride))*gait
		heads[i].rotation.x = lerpf(.65,.04,smoothstep(.50,.64,t))+.035*sin(stride)*gait
		heads[i].rotation.y = .085*sin(i*1.98+t*4.)*(1.-gait)
		for n in 4:
			var footstep := sin(stride + LEG_PHASES[n])
			legs[i*4+n].rotation.x = footstep*.64*gait
			knees[i*4+n].rotation.x = maxf(0.,-footstep)*.48*gait

func head_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for head in heads:
		points.append(head.to_global(Vector3(0,.47,-.39)))
	return points

static func hoofprints(parent: Node3D, first: Vector3, travel: Vector3, floor_at: Callable) -> PackedVector3Array:
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pressed := ShaderMaterial.new()
	pressed.shader = preload("res://assets/county/hoofprint.gdshader")
	marks.set_material(pressed)
	var side := travel.cross(Vector3.UP)
	var points := PackedVector3Array()
	var length: float = CROSSING_RUN+OFFSETS.back()-OFFSETS.front()
	var count := roundi(length/.73)
	var corners := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for i in range(count+1):
		var enter := first+travel*(float(i)*length/count)
		var step := enter + side*(.14 if i%2 else -.14)
		for n: int in [0,1,2,0,2,3]:
			var uv: Vector2 = corners[n]
			var ground_at: Vector3 = floor_at.call(step+side*(uv.x-.5)*.21+travel*(uv.y-.5)*.28)
			marks.set_normal(Vector3.UP)
			marks.set_uv(uv)
			marks.add_vertex(ground_at+Vector3.UP*.014)
		if i in [0,count/2,count]: points.append(floor_at.call(step)+Vector3.UP*.04)
	var tread := MeshInstance3D.new()
	tread.mesh=marks.commit()
	tread.visibility_range_end = 65.
	tread.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tread)
	return points
