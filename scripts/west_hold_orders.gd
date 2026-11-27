extends RefCounted

const WestBay := preload("res://scripts/west_hold_bay.gd")
const SIGNATURE := "K. Pelz / Badge 412"
const LOCATIONS := [
	{"site":"frames","road":"County K","place":"ginseng frames","point":Vector3(-7,0,-225),"angle":.12,
	 "directions":"Turn north on K. The deputy is on the west shoulder just beyond the ginseng frames.",
	 "vehicle":"Gray station wagon","variant":2,"reason":"Driver went in with the ambulance. Sheriff needs the car kept under seal until the family arrives."},
	{"site":"dairy","road":"Hendricks Rd","place":"Brzezinski Dairy","point":Vector3(138,0,407),"angle":1.65,
	 "directions":"Take K south to Hendricks, then turn east. Find the deputy just beyond the dairy driveway.",
	 "vehicle":"Brown four-door sedan","variant":1,"reason":"Stolen sedan recovered with both plates on it. Sheriff is matching the registration before it goes back."},
	{"site":"coop","road":"Highway 64","place":"Esker Co-op","point":Vector3(94,0,-7),"angle":-1.42,
	 "directions":"Take K south and turn east on Main. The deputy is on the north shoulder just past the co-op bins.",
	 "vehicle":"Blue compact sedan","variant":0,"reason":"Sheriff recovered the missing sedan by the co-op. The registered owner is still on the way."},
]
var current := {}
var archive: Array = []
var locked := false
var next_after := 0
# The custody form the operator has open, and whether the order book is turned
# back to released orders. These last only while the page is open.
var source := ""
var archive_open := false
var page := 0

func offer(game) -> Dictionary:
	if game.mode!="available" or not current.is_empty() or game.completed<next_after: return {}
	var number: int = 1001+game.completed+game.pending_slips.size()
	var row: Dictionary = LOCATIONS[posmod(game.dispatch_seed+archive.size(),LOCATIONS.size())]
	var id := "SH-96-%04d" % number
	var plate := "WSH %03d" % posmod(number*7+33,1000)
	return {"id":id,"kind":"hazard","site":row.site,"route":row.site,"sheriff_order":id,"number":number,"point":row.point,
		"angle":row.angle,"variant":row.variant,"driver_variant":1,"vehicle":row.vehicle,"plate":plate,
		"vin":"1G1WL52M2T9%06d" % posmod(12043+number,1000000),"road":row.road,"location":row.road+" · "+row.place,
		"reason":row.reason,"dispatch":"Sheriff's order %s. %s, plate %s. Meet Deputy Pelz on %s." % [id,row.vehicle,plate,row.road],
		"directions":row.directions,"haul_line":"Bring it all the way through the west gate to WEST HOLD 2. Lock the chain and send the signed copy."}

func receive(ticket: Dictionary, clock: String, odo: float, car: Node3D) -> void:
	current = {}
	for key: String in ["number","sheriff_order","plate","vin","vehicle","variant","location","reason","checked_tape","pickup_signature","custody_start"]:
		if ticket.has(key): current[key]=ticket[key]
	current["yard_tag"] = ticket.sheriff_order
	current["arrived"] = clock
	current["arrival_odo"] = odo
	current["parked"] = [car.global_position.x,car.global_position.y,car.global_position.z]
	current["yaw"] = car.global_rotation.y
	locked = false

func can_release(completed: int) -> bool:
	return current.has("filed_at") and completed > int(current.filed_at)

func sign_release(clock: String, completed: int) -> void:
	current.released = clock
	current.release_signature = SIGNATURE
	current.released_by = "Brandt"
	archive.append(current)
	current = {}
	locked = false
	next_after = completed+1

func save_state() -> Dictionary:
	return {"current":current.duplicate(true),"archive":archive.duplicate(true),"locked":locked,"next_after":next_after}

func restore(data:Dictionary) -> void:
	current = data.get("current",{}).duplicate(true)
	archive = data.get("archive",[]).duplicate(true)
	locked = not current.is_empty() and bool(data.get("locked",false))
	next_after = int(data.get("next_after",0))

func open_page(site: String) -> void:
	source = site
	archive_open = false

## Acts on a button of the open custody page. Returns false when the press
## does not apply to the form in front of the operator.
func press(game, id: String) -> bool:
	if game.desk.page!="west_custody" or not is_instance_valid(game.county.west_bay) or game.rig.in_cab: return false
	if site_action(game)!=source: return false
	match id:
		"west_accept":
			if source!="west_order_book" or archive_open: return false
			var ticket := offer(game)
			if ticket.is_empty(): return false
			game.survey.defer_order()
			game.stamp_ticket(ticket)
			game.desk.dismiss()
			game.accept(ticket)
		"west_sign_pickup":
			if source!="west_pickup_card" or game.job.has("pickup_signature"): return false
			game.job.pickup_signature = SIGNATURE
			game.pickup_time = game.clock()
			game.pickup_odo = game.rig.odo
			game.job.custody_start = game.pickup_time
			game.desk.dismiss()
			game.speak("DEPUTY PELZ","Plate matches. My copy stays here. Keep the keys with your signed copy, Brandt.")
		"west_sign_release":
			if source!="west_release_card" or not can_release(game.completed) or locked: return false
			game.county.west_bay.hand_off(game.rig,current)
			sign_release(game.clock(),game.completed)
			game.sync_west_bay()
			game.desk.dismiss()
			game.speak("DEPUTY PELZ","I’ve got the keys. I’ll pull out when the lane’s clear. Your signed copy stays in the west book.")
		"west_archive","west_archive_prev","west_archive_next":
			if source!="west_order_book" or archive.is_empty(): return false
			archive_open = true
			match id:
				"west_archive": page = archive.size()-1
				"west_archive_prev": page = posmod(page-1,archive.size())
				"west_archive_next": page = posmod(page+1,archive.size())
		"west_current": archive_open = false
	return true

## Locks or unlocks the bay chain from outside the bay.
func pull_chain(game) -> void:
	if not locked:
		var blocked := obstruction(game)
		if not blocked.is_empty():
			game.show_message("BRANDT",blocked)
			return
	elif not can_release(game.completed):
		game.show_message("BRANDT","Sheriff has the hold. Leave the chain locked until the release comes in.")
		return
	locked = not locked
	if locked: current.secured = game.clock()
	game.audio.rig_effect("ratchet")
	game.sync_west_bay()
	game.show_message("BRANDT","West hold secured. I'll mark the copy." if locked else "Chain open. The deputy can sign for the car.")

func obstruction(game) -> String:
	if game.rig.wrecker_overlaps(WestBay.FLOOR.grow(.35)):
		return "Pull the wrecker and forks clear of the west bay first."
	if WestBay.FLOOR.grow(.16).has_point(Vector2(game.rig.foot.x,game.rig.foot.z)):
		return "Stand outside the west bay to draw the chain."
	return ""

func site_action(game) -> String:
	if not is_instance_valid(game.county.west_bay): return ""
	if game.mode == "fieldwork" and game.job.has("sheriff_order") and game.rig.phase=="scene" and game.is_facing(game.rig.get_witness_position(),3.1):
		return "west_pickup_card"
	if game.rig.action_id() in ["drop","enter"]: return ""
	if not current.is_empty() and game.is_facing(WestBay.LATCH,2.25):
		return "west_chain"
	if can_release(game.completed) and game.is_facing(WestBay.COUNTERSIGN+Vector3.UP,2.4):
		return "west_release_card"
	if game.is_facing(WestBay.BOOK,2.22):
		return "west_order_book"
	return ""

func sheet(game) -> Dictionary:
	var data: Dictionary
	if archive_open and not archive.is_empty():
		data = archive[clampi(page,0,archive.size()-1)].duplicate()
		data.status = "RELEASED"
	elif game.job.has("sheriff_order") and current.is_empty():
		data = game.job.duplicate()
		data.status = "PICKUP SIGNED" if data.has("pickup_signature") else "AWAITING SIGNATURE"
	elif not current.is_empty():
		data = current.duplicate()
		data.status = "RELEASE AUTHORIZED" if can_release(game.completed) else ("FILED" if current.has("filed_at") else "IN YARD")
	else:
		data = offer(game)
		data.status = "ORDER AVAILABLE" if data.has("sheriff_order") else "NO NEW ORDERS"
	data.locked = locked
	data.archive_count = archive.size()
	data.archive_open = archive_open and data.status=="RELEASED"
	data.page = page
	return data

## The custody form on the desk and which form the operator opened.
func view(game) -> Dictionary:
	return {"west_card":sheet(game),"west_source":source}
