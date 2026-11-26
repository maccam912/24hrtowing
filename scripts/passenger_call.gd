extends RefCounted

const Speech := preload("res://scripts/county_speech.gd")
const Memorial := preload("res://scripts/memorial_hospital.gd")
const FuelStore := preload("res://scripts/fuel_store.gd")
const Highway := preload("res://scripts/tamarack_highway.gd")
const RIDERS := [
	{"id":"switchboard","person":"Relief switchboard operator","model":0,"drop":"memorial","reason":"Her starter quit on the way to the night desk.","pickup":"Thanks. They can cover my switchboard till I get there. Night entrance, please.","arrival":"That's the right door. I can see Ruth still at the desk."},
	{"id":"creamery","person":"Creamery sampler","model":1,"drop":"esker","reason":"His ride turned back. Mai has the number for the next milk truck.","pickup":"I've got the milk truck's route written down. A lift to Mai's pay phone would do it.","arrival":"There's the phone. If I catch his next stop he'll take me the rest of the way."},
	{"id":"visitor","person":"Hospital visitor","model":1,"drop":"memorial","reason":"The car quit on the way to visit his brother.","pickup":"They moved my brother to a room on the first floor. I'd like to sit with him a while.","arrival":"His window's the third one over. Thanks for stopping."},
	{"id":"bakery","person":"Bakery opener","model":0,"drop":"esker","reason":"The van threw a belt. The other baker is on the way with the spare key.","pickup":"Mai said I could wait inside. The other baker's got the spare key.","arrival":"The coffee pot's still on. I'll wait for her inside."},
	{"id":"plow_relief","person":"Relief plow driver","model":1,"drop":"highway_shop","reason":"His pickup quit before the shift change at the east shop.","pickup":"Lou has been on the blades since supper. Can you get me to the crew door at the county garage?","arrival":"Bay two is still lit. I can take the grader from here."},
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
	var place := Speech.landmark(site.landmark)
	if person.id == "summer_driver":
		ticket.dispatch = "There’s a driver in a T-shirt by %s on %s, %s shoulder. Bring them in to Esker Fuel & Food." % [place,site.road,ticket.shoulder]
	else:
		var drop := "the night entrance at Tamarack Memorial" if person.drop == "memorial" else destination(ticket)
		ticket.dispatch = "%s needs a lift from %s on %s, %s shoulder. %s Drop them at %s." % [Speech.occupation(person.person),place,site.road,ticket.shoulder,person.reason,drop]

static func destination(ticket: Dictionary) -> String:
	match rider(ticket).drop:
		"memorial": return "Tamarack Memorial"
		"highway_shop": return "County Highway Garage"
		_: return "Esker Fuel & Food"

static func target(ticket: Dictionary) -> Vector3:
	match rider(ticket).drop:
		"memorial": return Memorial.CURB
		"highway_shop": return Highway.CURB
		_: return Vector3(-71,0,14)

static func at_drop(ticket: Dictionary, truck: Vector3) -> bool:
	var lot := Rect2(-85,9,28,13)
	match rider(ticket).drop:
		"memorial": lot = Memorial.DROP
		"highway_shop": lot = Highway.DROP
	return lot.has_point(Vector2(truck.x,truck.z))

static func inside_door(ticket: Dictionary) -> Vector3:
	match rider(ticket).drop:
		"memorial": return Memorial.DOOR + Vector3.BACK*.65
		"highway_shop": return Highway.DOOR + Vector3.BACK*.73
		_: return FuelStore.FORECOURT + Vector3(-5.15,0,5.76)

static func approach(ticket: Dictionary) -> String:
	match rider(ticket).drop:
		"memorial": return "Highway 64 east past County FF. Turn at the blue H before the county offices. Stop along the NIGHT ENTRANCE curb."
		"highway_shop": return "From County FF go three miles east on 64. Cross Cedar Creek. Turn right at the County Service Center and pull up to the crew door."
		_: return "Pull off Highway 64 into the Fuel & Food forecourt. Park clear of the pump islands."
