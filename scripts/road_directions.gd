extends RefCounted
## The roads on Arlene's desk map, including the driveway through Brandt's gate.
## Positions are in the current county. Unprinted roads never enter the graph.

const GATE := "Brandt yard"
const DRIVEWAY := Vector2(-28, -64)
const JUNCTION := Vector2(0, -64)
const START := 0
const FINISH := 1

var graph := AStar2D.new()
var sections: Array[Dictionary] = []

func build(roads: Array) -> void:
	graph.clear()
	sections.clear()
	var streets: Array[Dictionary] = []
	for road: Dictionary in roads:
		var points: PackedVector2Array = road.points
		for i in range(1, points.size()):
			streets.append({"name":road.name, "a":points[i-1], "b":points[i]})
	streets.append({"name":GATE, "a":DRIVEWAY, "b":JUNCTION})
	var ids := {}
	for street in streets:
		var points := [street.a, street.b]
		for other in streets:
			var crossing = Geometry2D.segment_intersects_segment(street.a, street.b, other.a, other.b)
			if crossing != null:
				var point: Vector2 = crossing.snapped(Vector2.ONE * 0.01)
				if not points.has(point):
					points.append(point)
		var origin: Vector2 = street.a
		points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return origin.distance_squared_to(a) < origin.distance_squared_to(b))
		for i in points.size():
			var p: Vector2 = points[i]
			if not ids.has(p):
				ids[p] = ids.size() + 2
				graph.add_point(ids[p], p)
			if i > 0:
				var a: Vector2 = points[i-1]
				graph.connect_points(ids[a], ids[p])
				sections.append({"name":street.name, "a":a, "b":p, "ids":[ids[a],ids[p]]})

func nearest_section(p: Vector2, forward := Vector2.ZERO) -> Dictionary:
	var best := INF
	var selected := {}
	for section in sections:
		var q := Geometry2D.get_closest_point_to_segment(p, section.a, section.b)
		var distance := p.distance_to(q)
		if section.name == GATE and distance > 6.0:
			continue
		var axis: Vector2 = (section.b - section.a).normalized()
		# Within the width of an intersection, prefer the road the truck faces.
		var score := distance + 3.0 * (1.0 - absf(forward.dot(axis)))
		if score < best:
			best = score
			selected = {"point":q, "section":section}
	return selected

func driven_road(p: Vector2) -> String:
	var nearest := nearest_section(p)
	if nearest.is_empty() or nearest.section.name == GATE or p.distance_to(nearest.point) >= 7.0:
		return ""
	return nearest.section.name

func route_points(start: Dictionary, end: Dictionary) -> PackedVector2Array:
	graph.add_point(START, start.point)
	graph.add_point(FINISH, end.point)
	for id: int in start.section.ids:
		graph.connect_points(START, id)
	for id: int in end.section.ids:
		graph.connect_points(FINISH, id)
	if start.section == end.section:
		graph.connect_points(START, FINISH)
	var path := graph.get_point_path(START, FINISH)
	graph.remove_point(START)
	graph.remove_point(FINISH)
	# When the origin is an intersection its temporary and permanent points coincide.
	var unique := PackedVector2Array()
	for point in path:
		if unique.is_empty() or unique[-1].distance_to(point) > 0.1:
			unique.append(point)
	return unique

static func _cardinal(direction: Vector2) -> String:
	return ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"][posmod(roundi(rad_to_deg(atan2(direction.x, -direction.y)) / 45.0), 8)]

static func _turn(incoming: Vector2, outgoing: Vector2) -> String:
	return "right" if incoming.cross(outgoing) > 0 else "left"

func _street(a: Vector2, b: Vector2) -> String:
	return nearest_section((a+b) * 0.5, a.direction_to(b)).section.name

static func _cue(words: String, maneuver := "") -> Dictionary:
	return {"instruction":words, "maneuver":maneuver}

func cue(position: Vector2, heading_degrees: float, destination: Vector2, landmark: String, unmapped := false) -> Dictionary:
	if sections.is_empty():
		return {}
	var forward := Vector2.UP.rotated(deg_to_rad(heading_degrees))
	var start := nearest_section(position, forward)
	var end := nearest_section(destination)
	var road: String = start.section.name
	if unmapped and road == end.section.name:
		if position.distance_to(start.point) > 14.0:
			return _cue("That's off my sheet. Watch the fire plates for %s." % landmark)
		return _cue("%s is missing from my plat. Watch the fire plates along %s." % [landmark, road])
	if position.distance_to(start.point) > 10.0:
		return _cue("%s lies %s of you. Get back to the road." % [road, _cardinal(position.direction_to(start.point))])
	var path := route_points(start, end)
	if path.size() < 2:
		return _cue("Watch both shoulders for %s." % landmark)
	var direction := path[0].direction_to(path[1])
	var street := _street(path[0], path[1])
	if forward.dot(direction) < -0.62:
		return _cue("When clear, turn around. Head %s on %s." % [_cardinal(direction), street], "around")
	if absf(forward.cross(direction)) > 0.72:
		var turn := _turn(forward, direction)
		if street == GATE:
			return _cue("Turn %s at the Brandt sign into the yard." % turn, turn)
		return _cue("Turn %s onto %s, heading %s." % [turn, street, _cardinal(direction)], turn)
	for i in range(1, path.size()-1):
		var outgoing := path[i].direction_to(path[i+1])
		if direction.dot(outgoing) > 0.95:
			continue
		var next := _street(path[i], path[i+1])
		var turn := _turn(direction, outgoing)
		if street == GATE:
			return _cue("At the yard gate, turn %s onto %s. Head %s." % [turn, next, _cardinal(outgoing)], turn)
		if path[0].distance_to(path[i]) > 75.0:
			return _cue("Stay %s on %s. Next %s at %s." % [_cardinal(direction), street, turn, "the Brandt sign" if next == GATE else next], "ahead")
		if next == GATE:
			return _cue("Turn %s at the Brandt sign into the yard." % turn, turn)
		var corner := " at the co-op" if path[i].distance_to(Vector2.ZERO) < 1 else ""
		return _cue("Turn %s%s onto %s, heading %s." % [turn, corner, next, _cardinal(outgoing)], turn)
	var offset: Vector2 = destination - end.point
	if position.distance_to(end.point) < 60.0 and offset.length() > 2:
		return _cue("Slow for %s. Check the %s shoulder." % [landmark, _turn(direction, offset.normalized())])
	return _cue("Head %s on %s. Watch for %s." % [_cardinal(direction), street, landmark], "ahead")
