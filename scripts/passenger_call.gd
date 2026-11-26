extends RefCounted

const Memorial := preload("res://scripts/memorial_hospital.gd")
const FuelStore := preload("res://scripts/fuel_store.gd")
const RIDERS := [
	{"id":"switchboard","person":"Switchboard relief","model":0,"drop":"memorial","reason":"Her starter quit on the way to the night desk.","pickup":"Thanks. They can cover my switchboard till I get there. Night entrance, please.","arrival":"That's the right door. I can see Ruth still at the desk."},
	{"id":"creamery","person":"Creamery sampler","model":1,"drop":"esker","reason":"His ride turned back. Mai has the number for the next milk truck.","pickup":"I've got the milk truck's route written down. A lift to Mai's pay phone would do it.","arrival":"There's the phone. If I catch his next stop he'll take me the rest of the way."},
	{"id":"visitor","person":"Hospital visitor","model":1,"drop":"memorial","reason":"The passenger was headed to see someone at Memorial when the car quit.","pickup":"They moved my brother to a room on the first floor. I'd like to sit with him a while.","arrival":"His window's the third one over. Thanks for stopping."},
	{"id":"bakery","person":"Bakery opener","model":0,"drop":"esker","reason":"The bakery van lost a belt. A coworker will pick them up at Fuel & Food.","pickup":"Mai said I could wait inside. The other baker's got the spare key.","arrival":"The coffee pot's still on. I'll wait for her inside."},
]
const SUMMER := {"id":"summer_driver","person":"Driver in a T-shirt","model":2,"drop":"esker","pickup":"It was warm where I was. Can you take me to Esker Fuel & Food?","arrival":"I know this place. I can call my sister from inside. Thanks for the ride."}

static func rider(ticket: Dictionary) -> Dictionary:
	for person: Dictionary in RIDERS:
		if ticket.get("rider") == person.id:
			return person
	# Passenger tickets issued before Memorial served the original summer driver.
	return SUMMER

static func assign(ticket: Dictionary, site: Dictionary, person: Dictionary) -> void:
	ticket.kind = "passenger"
	ticket.id = person.id
	ticket.rider = person.id
	ticket.driver_variant = person.model
	ticket.person = person.person
	ticket.reply = person.id
	ticket.running = person.id == "summer_driver"
	ticket.untaped = true
	if person.id == "summer_driver":
		ticket.dispatch = "There's a driver out by %s in a T-shirt. %s shoulder on %s. Bring them in to Esker Fuel & Food." % [site.landmark,ticket.shoulder,site.road]
	else:
		ticket.dispatch = "%s needs a lift from %s on %s, %s shoulder. %s Take your passenger to %s." % [person.person,site.landmark,site.road,ticket.shoulder,person.reason,destination(ticket)]

static func destination(ticket: Dictionary) -> String:
	return "Tamarack Memorial" if rider(ticket).drop == "memorial" else "Esker Fuel & Food"

static func target(ticket: Dictionary) -> Vector3:
	return Memorial.CURB if rider(ticket).drop == "memorial" else Vector3(-71,0,14)

static func at_drop(ticket: Dictionary, truck: Vector3) -> bool:
	var lot := Memorial.DROP if rider(ticket).drop == "memorial" else Rect2(-85,9,28,13)
	return lot.has_point(Vector2(truck.x,truck.z))

static func inside_door(ticket: Dictionary) -> Vector3:
	return Memorial.DOOR + Vector3.BACK*.65 if rider(ticket).drop == "memorial" else FuelStore.FORECOURT + Vector3(-5.15,0,5.76)

static func approach(ticket: Dictionary) -> String:
	if rider(ticket).drop == "memorial":
		return "Highway 64 east past County FF. Turn at the blue H before the county offices. Stop along the NIGHT ENTRANCE curb."
	return "Pull off Highway 64 into the Fuel & Food forecourt. Park clear of the pump islands."
