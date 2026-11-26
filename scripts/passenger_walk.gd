extends RefCounted
## A short walk between a parked passenger door and another vehicle or building.
## Foot routes go around the wrecker, casualty and forecourt fixtures.
var person: Node3D
var variant := 0
var route := PackedVector3Array()
var step := 0
var entering_store := false

func _init(actor: Node3D, model: int) -> void:
	person = actor
	variant = model

static func _obstacle(pose: Transform3D, x: float, z: float) -> Dictionary:
	return {"pose":pose,"half":Vector2(x,z)}

static func _clear(a: Vector3, b: Vector3, obstacles: Array) -> bool:
	for obstacle: Dictionary in obstacles:
		var local: Transform3D = obstacle.pose.affine_inverse()
		var half: Vector2 = obstacle.half
		var box := AABB(Vector3(-half.x,-100,-half.y),Vector3(half.x*2,200,half.y*2))
		if box.intersects_segment(local*a,local*b) != null:
			return false
	return true

func plot(rig, goal: Vector3, leaving: bool, memorial: bool) -> bool:
	var obstacles := [_obstacle(rig.truck.global_transform,1.40,4.28)]
	if not leaving and is_instance_valid(rig.car):
		var bounds: Vector3 = rig.car.get_meta("body_size")
		obstacles.append(_obstacle(rig.car.global_transform,bounds.x+.18,bounds.z+.18))
	if leaving:
		if memorial:
			for x: float in [847.12,858.88]:
				for z: float in [23.78,26.82]:
					obstacles.append(_obstacle(Transform3D(Basis.IDENTITY,Vector3(x,0,z)),.30,.30))
		else:
			for x: float in [-74.7,-67.3]:
				obstacles.append(_obstacle(Transform3D(Basis.IDENTITY,Vector3(x,0,16)),1.22,.72))
	var points := PackedVector3Array([person.global_position,goal])
	for obstacle: Dictionary in obstacles:
		var half: Vector2 = obstacle.half+Vector2(.16,.16)
		for x: float in [-half.x,half.x]:
			for z: float in [-half.y,half.y]:
				points.append(obstacle.pose*Vector3(x,0,z))
	var graph := AStar3D.new()
	for i in points.size():
		var p := points[i]
		graph.add_point(i,Vector3(p.x,0,p.z))
	for i in points.size():
		for j in range(i+1,points.size()):
			if _clear(points[i],points[j],obstacles):
				graph.connect_points(i,j)
	route = graph.get_point_path(0,1)
	step = 1
	return route.size() >= 2

func advance(rig,dt: float) -> bool:
	if entering_store and is_instance_valid(rig.world.fuel_door) and person.position.distance_to(rig.world.fuel_door.global_position) < 3.85:
		rig.world.fuel_door.hold_for_rider()
	while step < route.size():
		var direction := route[step]-person.global_position
		direction.y = 0
		if direction.length_squared() < .025:
			step += 1
			continue
		rig.Scene.walk_person(person)
		person.rotation.y = rotate_toward(person.rotation.y,atan2(-direction.x,-direction.z),dt*4.6)
		person.global_position += direction.limit_length(dt*1.65)
		person.position.y = rig._ground(person.position)
		return false
	return true

func save_state(rig) -> Dictionary:
	var remaining := []
	for i in range(step,route.size()):
		remaining.append(rig._v(route[i]))
	return {"variant":variant,"remaining":remaining,"position":rig._v(person.position),"yaw":person.rotation.y,"store":entering_store}

func restore(rig,data: Dictionary) -> void:
	person.position = rig._unpack(data.get("position"),person.position)
	person.rotation.y = data.get("yaw",0.0)
	entering_store = data.get("store",false)
	step = 0
	for p in data.get("remaining",[]):
		route.append(rig._unpack(p,person.position))
