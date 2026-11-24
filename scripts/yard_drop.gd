extends RefCounted

const STORAGE := {
	"center": Vector3(-44, 0, -77), "sign": "STORAGE", "radio": "storage_dir",
	"approach": "Right inside the gate. Pull between the amber lights.",
}
const EVIDENCE := {
	"center": Vector3(-50.8, 0, -45), "sign": "EVIDENCE HOLD", "radio": "evidence_dir",
	"approach": "Left by the office. Back in between the amber lights.",
}
# Distances from the center to the four amber corner posts.
const HALF_SIZE := Vector2(8.3, 3.65)

static func for_vehicle(kind: String) -> Dictionary:
	return EVIDENCE if kind == "hold" else STORAGE

static func contains(center: Vector3, point: Vector3) -> bool:
	return absf(point.x - center.x) <= HALF_SIZE.x and absf(point.z - center.z) <= HALF_SIZE.y
