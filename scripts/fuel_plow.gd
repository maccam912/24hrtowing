extends Node3D

const Vehicle := preload("res://scripts/rig_scene.gd")
const Shop := preload("res://scripts/shop_account.gd")
var county: Node3D
var stop: Vector2
var start: Vector2
var exit: Vector2
var departed := 0.0

func setup(world: Node3D, truck: Vector3) -> void:
	county = world
	county.add_child(self)
	Vehicle.fuel_service_plow(self)
	var truck_at := Vector2(truck.x,truck.z)
	var best := INF
	# Use the other lane, even if the wrecker is parked on the centerline.
	# When the wrecker is off-road Duane parks by the nearest road.
	for road: Dictionary in county.map_roads():
		var points: PackedVector2Array = road.points
		for i in range(1,points.size()):
			var a := points[i-1]
			var b := points[i]
			if road.name == "Alder Cut Rd" and county.alder_open:
				b.y = county.CaseSites.ALDER_END
			var nearest := Geometry2D.get_closest_point_to_segment(truck_at,a,b)
			var distance := nearest.distance_squared_to(truck_at)
			if distance >= best:
				continue
			best = distance
			var axis := a.direction_to(b)
			var lane := Vector2(-axis.y,axis.x) * 3.25
			var entrance := a
			var departure := b
			if (truck_at-nearest).dot(lane) > 0:
				lane = -lane
				entrance = b
				departure = a
			if nearest.distance_to(entrance) < 18.0:
				var road_end := entrance
				entrance = departure
				departure = road_end
			var along := entrance.direction_to(departure)
			start = nearest.move_toward(entrance,112.0) + lane
			# Leave room for a truck stopped broadside across both lanes.
			stop = nearest.move_toward(entrance,11.0) + lane
			exit = nearest.move_toward(departure,125.0) + lane
			rotation.y = atan2(-along.x,-along.y)
	_place(start)

func _place(at: Vector2) -> void:
	position = Vector3(at.x,county.ground_height(at.x,at.y),at.y)

func approach(minutes_left: float) -> void:
	# The last three minutes of the call are for filling the wrecker.
	_place(start.lerp(stop,1.0-smoothstep(3.0,Shop.CAN_ETA_MINUTES,minutes_left)))

func leave(dt: float, truck: Vector3) -> bool:
	departed += dt
	if departed > 2:
		var at := Vector2(position.x,position.z)
		var ahead := at.move_toward(exit,minf(12,2*(departed-2))*dt)
		var wrecker := Vector2(truck.x,truck.z)
		if ahead.distance_to(wrecker) > 10 or ahead.distance_to(wrecker) >= at.distance_to(wrecker):
			_place(ahead)
	return position.distance_to(truck) > 108 and departed > 12
