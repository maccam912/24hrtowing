extends RefCounted

const Speech := preload("res://scripts/county_speech.gd")
const Legacy := preload("res://scripts/legacy_dispatch.gd")
const YardDrop := preload("res://scripts/yard_drop.gd")
const Snowplow := preload("res://scripts/county_snowplow.gd")
const Rides := preload("res://scripts/passenger_call.gd")
const Ambulance := preload("res://scripts/memorial_ambulance.gd")
const Squad := preload("res://scripts/county_squad.gd")
const Semi := preload("res://scripts/semitrailer.gd")
const Tanker := preload("res://scripts/milk_tanker.gd")
const Dairy := preload("res://scripts/dairy_transfer.gd")
const RiverLanes := preload("res://scripts/river_lanes.gd")
const CountyVisits := preload("res://scripts/county_visits.gd")
const Addresses := preload("res://scripts/fire_numbers.gd")
const GATE := Vector2(0, -64)
const METERS_PER_GAME_MILE := 400.0
# Points are centerline stations on the county plat.
const SITES := {
	"angie": {"road":"County K", "landmark":"St. Hedwig’s", "station":Vector2(0,135), "north_south":true,
		"hazard_reasons":["The parish plow needs room to turn.", "Owner rode back to town with the deputy."],
		"local":true, "approach":"Turn right out the gate onto K. Cross Main and watch for the twin steeples."},
	"coop": {"road":"Highway 64", "landmark":"Esker Co-op", "station":Vector2(62,0),
		"hazard_reasons":["The co-op loader is coming through.", "The feed truck needs the full turn."],
		"local":true, "approach":"Go south on K. Left at Main, just past the co-op bins."},
	"frames": {"road":"County K", "landmark":"ginseng frames", "station":Vector2(0,-204), "north_south":true,
		"hazard_reasons":["County has to cut that bank back.", "Owner left the keys with the deputy."],
		"local":true, "approach":"Turn left out the gate onto K. Look for the rows of bare ginseng frames."},
	"dairy": {"road":"Hendricks Rd", "landmark":"Brzezinski Dairy", "station":Vector2(109,400),
		"hazard_reasons":["Milk hauler needs the swing into the dairy.", "Herd manager's got the owner inside warming up."],
		"approach":"Take K south past the church. Turn left at Hendricks and look for the lit dairy barns."},
	"farm": {"road":"Kolpack Rd", "landmark":"Lindquist place", "station":Vector2(400,256), "north_south":true,
		"hazard_reasons":["Gary needs to get the tractor through.", "Bev took the driver in for coffee."],
		"approach":"South on K, left at Main. Turn right on Kolpack and go down to the Lindquist silo."},
	"bridge": {"road":"Highway 64", "landmark":"river bridge", "station":Vector2(-428,0), "hazard_only":true,
		"hazard_reasons":["Salt truck needs both approaches clear.", "Deputy gave the driver a lift across the river."],
		"approach":"South on K, right at Main. Stay west on sixty-four to the near end of the bridge."},
	"swamp": {"road":"Swamp Rd", "landmark":"east road closure", "station":Vector2(386,-400),
		"hazard_reasons":["Plow needs to back out from the closure.", "Last deputy through brought the driver in."],
		"approach":"North on K past the ginseng frames. Right on Swamp Road. Pass the Section 3 turnout and watch for the closure ahead."},
	"river_lanes": {"road":"Highway 64", "landmark":"River Lanes truck stop", "station":Vector2(-573,0),
		"after_jobs":8, "hazard_reasons":["The fuel delivery is waiting to turn in.", "Driver went inside River Lanes to call home."],
		"approach":"South on K, right at Main. Cross the river bridge and watch for River Lanes before US 59."},
	"ff_barn": {"road":"County FF", "landmark":"west-side dairy barn", "station":Vector2(800,343), "north_south":true,
		"after_jobs":8, "hazard_reasons":["The milk truck has to make this corner.", "Owner rode to the dairy in the milk truck."],
		"approach":"South on K, left at Main. Pass Kolpack and turn right on County FF. The barn is just before Hendricks."},
	"county_seat": {"road":"Highway 64", "landmark":"Tamarack county offices", "station":Vector2(880,0), "hazard_only":true,
		"after_jobs":8, "hazard_reasons":["Highway crew needs the shoulder for snow.", "The clerk is holding the keys at the counter."],
		"approach":"Go south on K, left at Main. Stay on sixty-four past County FF to the brick county building."},
}
const VEHICLES := ["Blue compact sedan", "Brown sedan", "Gray station wagon", "Tan four-door sedan", "County utility pickup", "Orange county snowplow", "White sheriff’s squad", "North Country tractor-trailer", "Brzezinski bulk milk truck", Ambulance.TITLE]
const HEAVY_VARIANT := 4
const HEAVY_FEE := 36
const DRIVERS := [
	{"person":"Delivery driver","reply":"rural","reason":"Lost the road edge looking for a fire number."},
	{"person":"College student","reply":"student_pull","reason":"Pulled over to let the plow by."},
	{"person":"Dairy hand","reply":"dairy_hand","reason":"Front tires broke through the crust."},
	{"person":"Second-shift operator","reply":"shift_worker","reason":"Hit a ridge of hardpack coming home."},
	{"person":"Home care aide","reply":"aide_pull","reason":"Slid off the crown on the way between visits."},
	{"person":"Bakery opener","reply":"baker_pull","reason":"Followed a set of tracks off the pavement."},
	{"person":"Elevator mechanic","reply":"mechanic_pull","reason":"Went wide letting a spreader through."},
	{"person":"Boiler tender","reply":"boiler_pull","reason":"Got the front wheels buried turning around."},
	{"person":"Relief milker","reply":"relief_pull","reason":"Stopped to clear a wiper and sank in."},
	{"person":"School custodian","reply":"custodian_pull","reason":"Missed the edge coming around a windrow."},
]

const RECOVERIES := {
	"level_field_car": ["level_field", "sitting upright in the hay", "Back in from Kolpack Road. The stock drum will reach from the firm edge of the field.", "", 0.0],
	"field_car": ["roll", "upside down in a field", "Rig two lines and roll it onto its wheels.", "Vehicle inverted, no approach", 85.0],
	"nose_car": ["nose", "standing on its front bumper", "Check it with a second line before lowering it.", "Vehicle inverted, no approach", 85.0],
	"roof_car": ["roof", "on the co-op roof", "Park in the striped pocket west of the canopy, hood toward County K. The co-op keeps a service ladder on the west end.", "Vehicle on structure", 95.0],
	"tree_car": ["tree", "up in the tamaracks", "Set the boom and reeve the snatch block.", "Vehicle on structure", 95.0],
	"ice_car": ["ice", "on the flowage ice", "Take River Rd north from the east end of the Highway 64 bridge. Back toward the ice at the landing and run out the long cable.", "Vehicle on ice", 70.0],
	"shoulder_car": ["gate", "on the shoulder with the headlights on", "The sheriff authorizes recovery where found.", "", 0.0],
	"walker_car": ["gate", "running beside the road", "The driver went into the field. Bring the car in.", "", 0.0],
	"gate_car": ["gate", "running outside your gate", "Nobody's in it. Bring it into storage.", "", 0.0],
}

static func impossible(completed: int, event_id: String, point: Vector3, route: String, road: String, landmark: String, approach: String) -> Dictionary:
	if not RECOVERIES.has(event_id):
		return {}
	var spec: Array = RECOVERIES[event_id]
	var heavy := event_id in ["field_car", "nose_car", "tree_car"]
	var ticket := {"id":event_id, "number":1001+completed, "kind":"hazard", "route":route, "site":route,
		"point":point, "angle":PI if event_id == "ice_car" else 0.0, "variant":0, "vehicle":"Blue compact sedan",
		"plate":"TMR %03d" % (100 + posmod(completed*37,900)), "vin":"1BTRS39C5WJ%06d" % posmod(completed*2317,1000000),
		"road":road, "location":road+" · "+landmark, "recovery":spec[0], "heavy_recovery":heavy,
		"rate_name":spec[3], "rate_fee":spec[4], "running":true, "reply":"clear", "run":route,
		"dispatch":"Brandt, there's a blue sedan %s at %s. %s Sheriff wants it in storage." % [spec[1],landmark,spec[2]],
		"directions":approach + " " + str(spec[2]), "schedule":_scheduled_miles(Vector2(point.x,point.z))}
	if event_id == "roof_car": ticket.canopy_spreader = true
	if event_id in ["field_car","nose_car"]:
		ticket.two_drum_roll = true
		var position := "upside down" if event_id == "field_car" else "standing on its front bumper"
		ticket.dispatch = "Brandt, the blue sedan is %s off %s. Nobody inside. Take the snatch block and both drums. Sheriff wants it in storage." % [position,road]
	elif event_id == "level_field_car":
		ticket.dispatch = "Blue sedan three fence posts into the hay strip west of Kolpack Road. Four wheels down, engine running. You can get it out on the main drum. Bring it to storage."
		ticket.directions = "Follow Kolpack Road south from Highway 64. The car is in the hay west of the road, north of the Lindquist place. Set up at the field edge."
	return ticket

static func ordinary(completed: int, dispatch_seed: int, slips: Array, snatch_block := false, second_winch := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var used := {}
	var driver_calls := {}
	var site_hazards := {}
	var ditches := 0
	var hazards := 0
	var ordinary_rides := 0
	var last_ride := -1
	var summer_filed := false
	var met_angie := false
	var last_plow := -1
	var last_squad := -1
	var squad_calls := 0
	var last_ems := -1
	var last_semi := -1
	var freight_calls := 0
	var last_milk := -1
	var milk_calls := 0
	for slip: Dictionary in slips:
		met_angie = met_angie or slip.get("vin", "") == Legacy.JOBS.angie.vin
		if slip.has("case_id") or slip.kind not in ["ditch", "hazard","passenger"]:
			continue
		var site_id := _site_on_slip(slip)
		if slip.get("recovery") == "semi":
			last_semi = ditches + hazards
			freight_calls += 1
		elif slip.get("recovery") == "milk":
			last_milk = ditches + hazards
			milk_calls += 1
		if slip.get("vin") == Snowplow.VIN:
			last_plow = ditches + hazards
		if slip.get("vin") == Ambulance.VIN:
			last_ems = ditches + hazards
		elif slip.has("clearance_seconds"):
			last_squad = ditches + hazards
			squad_calls += 1
		used[site_id] = int(used.get(site_id, 0)) + 1
		if slip.kind in ["ditch","passenger"]:
			ditches += 1
			if slip.kind == "passenger":
				last_ride = ditches + hazards
				if slip.get("rider","summer_driver") == "summer_driver":
					summer_filed = true
				else:
					ordinary_rides += 1
			var reply: String = slip.get("reply", "")
			driver_calls[reply] = int(driver_calls.get(reply, 0)) + 1
		else:
			hazards += 1
			site_hazards[site_id] = int(site_hazards.get(site_id, 0)) + 1

	var rotation_count := ditches + hazards
	rng.seed = ("%s/%s" % [dispatch_seed, rotation_count]).hash()
	var kind := "ditch"
	if rotation_count > 0 and (ditches > hazards or (ditches == hazards and rng.randf() < 0.5)):
		kind = "hazard"
	# Duane gets back on his route after the pull. Give him a stretch of
	# good road between calls, and keep a due passenger's place on rotation.
	var summer_due := not summer_filed and rotation_count >= 19 and ditches >= 10 + posmod(dispatch_seed,3)
	var passenger_due := summer_due or (rotation_count >= 9 and (last_ride < 0 or rotation_count-last_ride >= 12))
	var stuck_plow := snatch_block and kind == "ditch" and not passenger_due and rotation_count >= 8 and (last_plow == -1 or rotation_count-last_plow >= 14)
	var squad := kind == "ditch" and not passenger_due and not stuck_plow and rotation_count >= 12 and (last_squad == -1 or rotation_count-last_squad >= 17)
	if kind == "ditch" and not passenger_due and not stuck_plow and not squad and rotation_count >= 18 and (last_ems < 0 or rotation_count-last_ems >= 23):
		return Ambulance.ticket(completed,_scheduled_miles(Vector2(Ambulance.SITE.x,Ambulance.SITE.z)))
	if kind == "hazard" and second_winch and snatch_block and rotation_count >= 12 and (last_semi < 0 or rotation_count-last_semi >= 18):
		return _freight_ticket(completed,dispatch_seed,freight_calls)
	if kind == "hazard" and snatch_block and rotation_count >= 16 and (last_milk < 0 or rotation_count-last_milk >= 20) and (last_semi < 0 or rotation_count-last_semi >= 4):
		return _milk_ticket(completed,dispatch_seed,milk_calls)
	var route := ""
	var best := INF
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		if rotation_count < int(site.get("after_jobs",0)) or (rotation_count == 0 and not site.get("local", false)):
			continue
		if kind == "ditch" and not squad and site.get("hazard_only", false):
			continue
		if stuck_plow and id not in ["frames","farm","dairy","ff_barn"]:
			continue
		if squad and id not in ["bridge","river_lanes","county_seat"]:
			continue
		var score := float(used.get(id, 0)) + rng.randf_range(0, 1.25)
		if score < best:
			best = score
			route = id
	var site: Dictionary = SITES[route]
	var named_place := Speech.landmark(site.landmark)
	var station: Vector2 = site.station
	var north_south: bool = site.get("north_south", false)
	var side := 1 if rng.randi() % 2 == 0 else -1
	var shoulder := ("east" if side > 0 else "west") if north_south else ("south" if side > 0 else "north")
	var offset := 8.4 if kind == "ditch" else 5.6
	var point := Vector3(station.x, 0, station.y)
	point += (Vector3.RIGHT if north_south else Vector3.BACK) * side * offset
	var yaw := (0.0 if north_south else PI / 2) + (PI if rng.randi() % 2 == 0 else 0.0)
	if kind == "ditch":
		# Turn released drivers back into the county at the two outer closures.
		if route == "swamp":
			yaw = PI / 2
		elif route == "river_lanes":
			yaw = -PI / 2
	yaw += rng.randf_range(-0.18, 0.18) if rotation_count == 0 else rng.randf_range(-0.42, 0.42)
	var variant := rng.randi_range(0, HEAVY_VARIANT-1)
	var heavy: bool = snatch_block and kind == "hazard" and hazards % 3 == 1
	if heavy:
		variant = HEAVY_VARIANT
	var job := {"id":"rotation", "number":1001 + completed, "kind":kind, "route":route, "site":route,
		"road":site.road, "location":site.road + " · " + site.landmark, "point":point, "angle":yaw,
		"shoulder":shoulder, "variant":variant, "driver_variant":rng.randi_range(0, 1),
		"vehicle":VEHICLES[variant], "plate":"%s %03d" % [["WFS","ETK","JRG","AKP","PFS"][rng.randi_range(0,4)], rng.randi_range(100,999)],
		"vin":"1BTRS39C5WJ%06d" % posmod(dispatch_seed + completed * 7919, 1000000),
		"reply":"clear", "schedule":_scheduled_miles(station), "run":route + "/" + shoulder}
	if stuck_plow:
		# A blade caught in the windrow leaves the rear eye facing the road.
		var into_bank := (Vector3.RIGHT if north_south else Vector3.BACK) * side
		var forward := Vector3.FORWARD.rotated(Vector3.UP,yaw) + into_bank*.76
		job.angle = atan2(-forward.x,-forward.z)
		job.id = "stuck_plow"
		job.variant = Snowplow.VARIANT
		job.driver_variant = Snowplow.DRIVER
		job.heavy_recovery = true
		job.plate = Snowplow.PLATE
		job.vin = Snowplow.VIN
		job.person = "Duane"
		job.reply = "duane_ditch" if last_plow == -1 else "duane_windrow"
		job.vehicle = VEHICLES[Snowplow.VARIANT]
		job.dispatch = "%s on %s by %s, %s ditch. Duane caught the windrow. Take your snatch block and pull from the rear eye. He'll finish his route." % [
			job.vehicle,site.road,named_place,shoulder]
	elif squad:
		job.merge(Squad.UNITS[posmod(dispatch_seed+squad_calls,Squad.UNITS.size())],true)
		job.id = "squad_pull"
		job.variant = Squad.VARIANT
		job.driver_variant = Squad.DRIVER
		job.running = true
		job.vehicle = VEHICLES[Squad.VARIANT]
		job.clearance_seconds = 0.0
		job.dispatch = "%s on %s by %s, %s shoulder. %s needs a pull to get back on patrol. County adds $%d if you clear it within two minutes of your first flare. Regular rate either way." % [
			job.vehicle,site.road,named_place,shoulder,job.person,Squad.PREMIUM]
	elif kind == "ditch" and passenger_due:
		var rider: Dictionary = Rides.SUMMER if summer_due else Rides.RIDERS[posmod(ordinary_rides+dispatch_seed,Rides.RIDERS.size())]
		Rides.assign(job,site,rider)
	elif kind == "ditch":
		var reason: String
		if not met_angie and route in ["angie", "coop", "frames"] and rng.randf() < .33:
			_named_driver(job, "angie", "nurse_pull", 0)
			reason = "She's due on the floor at Memorial."
		elif route == "farm" and rng.randf() < .33:
			_named_driver(job, "farm", "gary", 1)
			reason = "Bev says he went out to check the heifers."
		else:
			var driver := _next_driver(driver_calls, rng)
			job.person = driver.person
			job.reply = driver.reply
			reason = driver.reason
		if rotation_count >= 7 and posmod(rotation_count + dispatch_seed, 4) == 0:
			if job.id == "angie":
				job.reply = "angie_sunburn"
			elif job.id == "farm":
				job.reply = "gary_heifers"
			else:
				var replies := ["displaced_driver","gentle_driver","lost_hours"]
				job.reply = replies[rng.randi_range(0,replies.size()-1)]
		var caller: String = job.person if job.id in ["angie","farm"] else Speech.occupation(job.person)
		job.dispatch = "%s on %s by %s, %s ditch. %s needs a pull. %s" % [
			job.vehicle, site.road, named_place, shoulder, caller, reason]
	else:
		var reports: Array = site.hazard_reasons
		var reason: String = reports[posmod(dispatch_seed + int(site_hazards.get(route, 0)), reports.size())]
		if heavy:
			job.heavy_recovery = true
			job.plate = "TCU %03d" % ((job.number % 800) + 100)
			reason = "Service body’s loaded with tools. Bring the snatch block. " + reason
		job.dispatch = "%s on %s by %s, %s shoulder. Checked and taped. Bring it to storage. %s" % [
			job.vehicle, site.road, named_place, shoulder, reason]
	job.directions = "%s Look on the %s side for the %s." % [site.approach, shoulder, job.vehicle.to_lower()]
	if Addresses.PARCELS.has(route):
		var number := Addresses.number(route)
		job.location = "%s · %s (%s)" % [site.road,site.landmark,number]
		job.address = number
		job.directions += " The nearest fire plate reads %s." % number
		if route == "frames":
			job.dispatch += " Duda’s drying shed is at %s." % number
	return job

static func _next_driver(calls: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var best := INF
	var selected := {}
	for driver: Dictionary in DRIVERS:
		var score := float(calls.get(driver.reply, 0)) + rng.randf() * .99
		if score < best:
			best = score
			selected = driver
	return selected

static func _named_driver(job: Dictionary, id: String, reply: String, variant: int) -> void:
	var identity: Dictionary = Legacy.JOBS[id]
	job.id = id
	job.person = identity.person
	job.plate = identity.plate
	job.vin = identity.vin
	job.variant = variant
	job.vehicle = VEHICLES[variant]
	job.driver_variant = variant
	job.reply = reply

static func _freight_ticket(completed: int, seed_value: int, previous: int) -> Dictionary:
	var north := posmod(seed_value+previous,2) == 0
	var point := RiverLanes.NORTH_SITE if north else RiverLanes.SOUTH_SITE
	var stop := "north turnout" if north else "south turnout"
	var side := "north" if north else "south"
	var site := "freight_"+side
	var paint := posmod(seed_value+previous,2)
	var miles := (absf(point.z-RiverLanes.CENTER.z)+absf(point.x-RiverLanes.CENTER.x))/METERS_PER_GAME_MILE
	return {"number":1001+completed,"kind":"hazard","id":"jackknife","recovery":"semi","heavy_recovery":true,
		"site":site,"route":site,"run":site+"/east","road":"US 59","location":"US 59 · "+stop,"point":point,
		"angle":PI if north else 0.0,"fold":-1.12 if north else 1.12,"variant":Semi.VARIANT,"paint":paint,
		"driver_variant":1,"vehicle":"North Country tractor-trailer","plate":"MN PTR %03d" % (125+posmod(seed_value+completed*37,860)),
		"vin":"1HTNCC9X5S%07d" % posmod(seed_value+completed*7919,10000000),"schedule":snappedf(miles,.1),
		"person":"Freight driver","reply":"freight_lights" if previous%2 == 0 else "freight_brake","destination":RiverLanes.DROP.sign,
		"dispatch":"North Country tractor-trailer folded up at the %s on US 59. Driver's clear. Straighten the trailer with both drums and tow the whole outfit to River Lanes." % stop,
		"directions":"Cross the river on sixty-four. Turn %s onto US 59 at River Lanes. Look for the east turnout and the white freight box." % ("right" if north else "left"),
		"haul_line":"Copy, Brandt. River Lanes has the pull-through ready. Get both halves between the amber posts and drop at the panel."}

static func _milk_ticket(completed: int, seed_value: int, previous: int) -> Dictionary:
	var east := posmod(seed_value+previous,2) != 0
	var site := "milk_ff" if east else "milk_lindquist"
	var road := "County FF" if east else "Kolpack Rd"
	var lane := "west dairy lane" if east else "Lindquist milk lane"
	var point := Vector3(792,0,343) if east else Vector3(407.5,0,246)
	var gallons := 1460+40*posmod(seed_value+previous*7,23)
	var seal := "B%04d" % (1000+posmod(seed_value*13+completed*59,9000))
	var miles := (absf(point.x-Dairy.CENTER.x)+absf(point.z-400)+13.)/METERS_PER_GAME_MILE
	var arrival := "Take sixty-four east to County FF. Turn south. The dairy lane is on your right before Hendricks." if east else "Take sixty-four east to Kolpack. Turn south. Look for the bulk truck at the Lindquist farm lane, before Hendricks."
	return {"number":1001+completed,"kind":"hazard","id":"milk_tanker","recovery":"milk","heavy_recovery":true,
		"site":site,"route":site,"run":site+("/west" if east else "/east"),"road":road,"location":road+" · "+lane,"point":point,
		"angle":PI+(.14 if east else -.16),"variant":Tanker.VARIANT,"driver_variant":2,"vehicle":"Brzezinski bulk milk truck",
		"plate":"WI MH 024","vin":"1HTMDADR6RH571024","gallons":gallons,"seal":seal,"schedule":snappedf(miles,.1),
		"person":"Milk hauler","reply":"milk_herd" if previous%2 == 0 else "milk_haul","destination":Dairy.DROP.sign,
		"dispatch":"Brzezinski milk truck lost its driveline leaving the %s on %s. Driver has %s gallons sealed up. Get it to the milk house for transfer." % [lane,road,gallons],
		"directions":arrival,"haul_line":"The relief hauler is at the Brzezinski milk house on Hendricks. Take the corners easy. He's got the transfer hose ready."}

static func _scheduled_miles(station: Vector2) -> float:
	# Original street distances down the county grid to the K gate and across the yard.
	var yard: Vector3 = YardDrop.STORAGE.center
	var distance := absf(station.x - GATE.x) + absf(station.y - GATE.y)
	distance += absf(yard.x - GATE.x) + absf(yard.z - GATE.y)
	return snappedf(distance / METERS_PER_GAME_MILE, .1)

static func legacy_ticket(completed: int, lines: Dictionary) -> Dictionary:
	var job := Legacy.ticket(completed, lines)
	job.site = job.route
	# The first yard picked both meshes from the vehicle's side of town.
	job.variant = (2 if job.point.x > 0 else 3) if job.kind == "hazard" else (0 if job.point.x < 100 else 1)
	job.driver_variant = job.variant
	job.schedule = _scheduled_miles(Vector2(job.point.x, job.point.z))
	return job

static func hold_ticket(completed: int, lines: Dictionary, heavy_recovery := false) -> Dictionary:
	var job := legacy_ticket(4, lines)
	job.number = completed + 1001
	if heavy_recovery:
		job.heavy_recovery = true
	return job

static func looksee(completed: int) -> Dictionary:
	return {"id":"n5104", "kind":"looksee", "number":1001 + completed, "site":"n5104", "route":"n5104",
		"road":"Kolpack Rd", "location":"Kolpack Rd · N5104", "point":Vector3(445,0,326), "angle":0.0,
		"vehicle":"Hoffmann welfare check", "plate":"—", "vin":"—",
		"dispatch":"Milk hauler says every light is on at N5104 Kolpack and nobody answers. Look in on the Hoffmanns and check the drive.",
		"directions":"Take Kolpack south past the Lindquist silo. Turn into the Hoffmann drive at the green N5104 sign."}

static func pack(job: Dictionary) -> Dictionary:
	var data := job.duplicate()
	if data.get("point") is Vector3:
		var point: Vector3 = data.point
		data.point = [point.x, point.y, point.z]
	return data

static func unpack(data: Dictionary) -> Dictionary:
	var job := data.duplicate()
	if job.get("point") is Array and job.point.size() == 3:
		job.point = Vector3(job.point[0], job.point[1], job.point[2])
	return job

static func _site_on_slip(slip: Dictionary) -> String:
	if slip.has("site"):
		return slip.site
	# Old paperwork records the printed place name only.
	for id: String in Legacy.JOBS:
		if Legacy.JOBS[id].location == slip.get("location", ""):
			return id
	return ""

static func issue_slip(job: Dictionary, start: float, pickup: float, drop: float, seconds: float, clock: String, revised_rates:=false) -> Dictionary:
	var towed: bool = job.kind in ["hold", "hazard"]
	var look_only: bool = job.kind in ["looksee","passenger","field_visit"]
	var mile := snappedf(maxf(0, drop - pickup), .1) if towed else 0.0
	var hookup := 0 if look_only else 16
	var winch := 0 if look_only else maxi(1, ceili(seconds / 60.0)) * 6
	var storage := 12 if towed else 0
	if job.get("recovery") in ["semi","milk"]:
		storage = 0
	var heavy_fee := HEAVY_FEE if job.get("heavy_recovery", false) else 0
	var rate_fee := float(job.get("rate_fee",0.0)) if revised_rates else 0.0
	var pay := 38.0 + hookup + winch + mile * 3.25 + storage + heavy_fee + rate_fee
	var slip := {"number":job.number, "kind":job.kind, "site":job.site, "run":job.get("run",job.site),
		"location":job.location, "vehicle":job.vehicle, "plate":job.plate, "vin":job.vin,
		"start_odo":start, "pickup_odo":pickup, "drop_odo":drop, "loaded":mile,
		"schedule":job.get("schedule",0.0), "call_out":38, "hookup":hookup, "winch":winch,
		"storage":storage, "heavy_fee":heavy_fee, "pay":snappedf(pay,.01), "time":clock}
	if job.has("checked_tape"):
		slip.checked_tape = job.checked_tape.duplicate()
	if job.kind == "field_visit":
		slip.finding = CountyVisits.CHECKS[job.id].result
		slip.visit_round = int(job.visit_round)
	if rate_fee > 0:
		slip.rate_name = job.get("rate_name","Vehicle on ice")
		slip.rate_fee = rate_fee
	if job.has("clearance_seconds"):
		var elapsed := snappedf(maxf(0.0,job.clearance_seconds),.001)
		slip.clearance_seconds = elapsed
		slip.clearance_bonus = Squad.PREMIUM if elapsed <= Squad.LIMIT_SECONDS else 0.0
		slip.pay = snappedf(slip.pay+slip.clearance_bonus,.01)
	if job.has("recovery"):
		slip.recovery = job.recovery
	if job.get("recovery") == "semi":
		slip.destination = RiverLanes.DROP.sign
	elif job.get("recovery") == "milk":
		slip.destination = Dairy.DROP.sign
		slip.gallons = int(job.gallons)
		slip.seal = job.seal
	if job.kind == "passenger":
		slip.rider = Rides.rider(job).id
		slip.destination = Rides.destination(job)
	if job.kind in ["ditch","passenger"]:
		slip.reply = job.get("reply","")
	return slip
