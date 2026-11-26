extends RefCounted
## A strip belongs to the car. The road on a deputy's old strip can differ
## from the place Brandt finds it. Keep both on the original paper trail.
const OFFICERS := [["Kowalski","417"],["Pelz","412"],["Ruiz","426"]]
const LEGACY := {"date":"11/23","deputy":"Kowalski","badge":"417","road":""}
# The shift opens at 03:14 on January 14. A long-running shift can cross midnight.
const OPENING := 821589240   # Unix time, 1996-01-14 03:14 UTC

static func write(road: String, seed_value: int, seconds := 0.0, hold := false) -> Dictionary:
	var calendar := Time.get_date_dict_from_unix_time(OPENING+floori(seconds))
	var deputy: Array = OFFICERS[0 if hold else posmod(seed_value,OFFICERS.size())]
	return {"date":"%02d/%02d" % [calendar.month,calendar.day],"deputy":deputy[0],"badge":deputy[1],"road":road}

static func imprint(ticket: Dictionary) -> Dictionary:
	if ticket.get("untaped",false):
		return {}
	var mark: Dictionary = ticket.get("checked_tape",LEGACY)
	return mark

static func readable(rig) -> Node3D:
	if rig.in_cab:
		return null
	for strip: Node3D in rig.get_tree().get_nodes_in_group("checked_mirrors"):
		if strip.is_visible_in_tree() and rig._in_range(strip.global_position,1.85):
			return strip
	return null
