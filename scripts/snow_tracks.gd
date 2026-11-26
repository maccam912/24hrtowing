extends MultiMeshInstance3D
## One ground axle's rolling trail. Record each axle station in centimeters so
## a loaded turn can be recognized again after the operator resumes a shift.
const CAPACITY := 700
const STAMP_LENGTH := 1.08
static var stamp: PlaneMesh
var history: Array = []
var next := 0
var last := Vector2.INF
var county: Node3D

func build(parent: Node3D, world: Node3D) -> void:
	county = world
	parent.add_child(self)
	if not stamp:
		stamp = PlaneMesh.new()
		stamp.size = Vector2(1.,STAMP_LENGTH)
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://assets/weather/tire_print.gdshader")
		stamp.material = surface
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = CAPACITY*2
	multimesh.mesh = stamp
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-810,-20,-630),Vector3(3050,70,1730))

func mark(axle: Vector3, yaw: float, gauge: float, width: float) -> void:
	var p := Vector2(axle.x,axle.z)
	if last.is_finite() and p.distance_squared_to(last)<.92*.92: return
	_set_pair([roundi(p.x*100.),roundi(p.y*100.),roundi(rad_to_deg(yaw)*10.),roundi(gauge*100.),roundi(width*100.)])

func height(p: Vector3) -> float:
	if county.has_method("surface_point"): return county.surface_point(p).y
	return county.ground_height(p.x,p.z) if county.has_method("ground_height") else 0.

func _set_pair(entry: Array) -> void:
	var at := Vector3(float(entry[0])*.01,0,float(entry[1])*.01)
	var direction := Vector3.BACK.rotated(Vector3.UP,deg_to_rad(float(entry[2])*.1))
	var across := Vector3.UP.cross(direction)
	for i in 2:
		var point := at+across*(float(entry[3])*.01)*(-1. if i==0 else 1.)
		# Fit the tile to the rendered snow, including the banks of a turnout.
		point.y = height(point)+.033
		var tangent := direction+Vector3.UP*(height(point+direction*.5)-height(point-direction*.5))
		var side := across+Vector3.UP*(height(point+across*.5)-height(point-across*.5))
		var normal := tangent.cross(side).normalized()
		var basis := Basis(normal.cross(tangent).normalized()*float(entry[4])*.01,normal,tangent.normalized())
		multimesh.set_instance_transform(next*2+i,Transform3D(basis,point))
	if history.size()<CAPACITY: history.append(entry)
	else: history[next]=entry
	next = (next+1)%CAPACITY
	last = Vector2(at.x,at.z)
	multimesh.visible_instance_count=history.size()*2

func snapshot() -> Array:
	return history.slice(next)+history.slice(0,next) if history.size()==CAPACITY else history.duplicate()

func restore(entries: Array) -> void:
	history.clear()
	next = 0
	last = Vector2.INF
	multimesh.visible_instance_count=0
	for i in range(maxi(0,entries.size()-CAPACITY),entries.size()):
		var entry = entries[i]
		if entry is not Array or entry.size()!=5: continue
		if not entry.all(func(value)->bool: return (value is float or value is int) and is_finite(float(value))): continue
		if float(entry[3])>0. and float(entry[3])<=250. and float(entry[4])>0. and float(entry[4])<=60.:
			_set_pair(entry)
