extends RefCounted

const NORTHWEST := Vector2(-635,-575)
const SOUTHEAST := Vector2(934,836)
const LABELS := {"vehicle":"Vehicle", "lights":"Lights", "return":"Come back"}
# One hand-drawn symbol occupies roughly this much of the printed sheet.
const PICK_RADIUS := 43.0

var marks: Array = []

func write(tool: String, point: Vector2) -> bool:
	if not point.is_finite() or point != point.clamp(NORTHWEST,SOUTHEAST):
		return false
	if tool != "erase" and not LABELS.has(tool):
		return false
	var closest := -1
	var distance := PICK_RADIUS
	for i in marks.size():
		var row: Array = marks[i]
		var separation := point.distance_to(Vector2(row[0],row[1]))
		if separation < distance:
			closest = i
			distance = separation
	if tool == "erase":
		if closest < 0:
			return false
		marks.remove_at(closest)
	else:
		var entry := [roundi(point.x),roundi(point.y),tool]
		if closest >= 0:
			if marks[closest] == entry:
				return false
			marks[closest] = entry
		else:
			marks.append(entry)
	return true

func restore(entries: Array) -> void:
	marks = []
	for entry in entries:
		if entry is Array and entry.size() == 3 and str(entry[2]) in LABELS:
			if (entry[0] is float or entry[0] is int) and (entry[1] is float or entry[1] is int):
				write(str(entry[2]),Vector2(entry[0],entry[1]))

static func projection(box: Rect2, pad: float) -> Transform2D:
	var frame := box.grow(-pad)
	var extent := SOUTHEAST-NORTHWEST
	var ratio := minf(frame.size.x/extent.x,frame.size.y/extent.y)
	return Transform2D(0,Vector2.ONE*ratio,0,frame.get_center()-(NORTHWEST+extent*.5)*ratio)
