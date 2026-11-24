extends RefCounted

# Entries in the operator's pencil notes are the odometer at the first observation.
var notes := {}
var unit_reported := false
var hold_order := ""
var farm_order := ""
var farm_reported := false
var queried_slip := 0
var clipped_slips := []

func toggle_carbon(number: int) -> void:
	if number in clipped_slips:
		clipped_slips.erase(number)
	else:
		if clipped_slips.size() == 2:
			clipped_slips.pop_front()
		clipped_slips.append(number)

func record(item: String, odo: float) -> void:
	if not notes.has(item):
		notes[item] = odo

func can_report_unit() -> bool:
	return notes.has("unit") and notes.has("rod") and not unit_reported and hold_order == ""

func can_request_farm() -> bool:
	return hold_order == "filed" and farm_order == ""

func pending_order() -> String:
	if hold_order in ["offered", "deferred"]:
		return "hold"
	if farm_order in ["offered", "deferred"]:
		return "looksee"
	return ""

func defer_order() -> void:
	if hold_order == "offered":
		hold_order = "deferred"
	if farm_order == "offered":
		farm_order = "deferred"

func notebook() -> Array:
	var rows := []
	if notes.has("unit"):
		rows.append("Sec. 3 turnout · Survey Unit 38")
	if notes.has("rod"):
		rows.append("Rod case 38 · inside gate north of tripod")
	if notes.has("sketch"):
		rows.append("Kolpack · junction from T. Vang’s sketch")
	if notes.has("house"):
		rows.append("N5104 · porch light on, house empty")
	if notes.has("vin"):
		rows.append("At N5104 · VIN 1BTAL52C8TJ510428")
	if notes.has("cap"):
		rows.append("East of house · S4 NE / T28N R7E")
	return rows

func save_state() -> Dictionary:
	return {"notes":notes.duplicate(), "unit_reported":unit_reported, "hold_order":hold_order,
		"farm_order":farm_order, "farm_reported":farm_reported, "queried_slip":queried_slip,
		"clipped_slips":clipped_slips.duplicate()}

func restore(data: Dictionary, held: bool, active_kind: String) -> void:
	notes = data.get("notes", {}).duplicate()
	# Older operators already entrusted with the truck keep the deputy's authorization.
	hold_order = data.get("hold_order", "accepted" if active_kind == "hold" else ("filed" if held else ""))
	unit_reported = data.get("unit_reported", false)
	farm_order = data.get("farm_order", "")
	farm_reported = data.get("farm_reported", false)
	queried_slip = int(data.get("queried_slip", 0))
	clipped_slips = data.get("clipped_slips",[]).map(func(number): return int(number))
