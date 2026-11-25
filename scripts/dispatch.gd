extends RefCounted

const Legacy := preload("res://scripts/legacy_dispatch.gd")
const YardDrop := preload("res://scripts/yard_drop.gd")
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
const VEHICLES := ["Blue compact sedan", "Brown sedan", "Gray station wagon", "Tan four-door sedan", "County utility pickup"]
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
	"field_car": ["roll", "upside down in a field", "Rig two lines and roll it onto its wheels.", "Vehicle inverted, no approach", 85.0],
	"nose_car": ["nose", "standing on its front bumper", "Check it with a second line before lowering it.", "Vehicle inverted, no approach", 85.0],
	"roof_car": ["roof", "on the co-op roof", "Set up on the street side and lower it with the boom.", "Vehicle on structure", 95.0],
	"tree_car": ["tree", "up in the tamaracks", "Set the boom and reeve the snatch block.", "Vehicle on structure", 95.0],
	"ice_car": ["ice", "on the flowage ice", "Park on the bank. Pay out the whole drum for a slow pull.", "Vehicle on ice", 70.0],
	"shoulder_car": ["gate", "on the shoulder with the headlights on", "The sheriff authorizes recovery where found.", "", 0.0],
	"walker_car": ["gate", "running beside the road", "The driver went into the field. Bring the car in.", "", 0.0],
	"gate_car": ["gate", "running outside your gate", "Nobody's in it. Bring it into storage.", "", 0.0],
}

static func impossible(completed: int, event_id: String, point: Vector3, route: String, road: String, landmark: String, approach: String) -> Dictionary:
	if not RECOVERIES.has(event_id):
		return {}
	var spec: Array = RECOVERIES[event_id]
	var heavy := event_id in ["field_car", "nose_car", "tree_car"]
	return {"id":event_id, "number":1001+completed, "kind":"hazard", "route":route, "site":route,
		"point":point, "angle":PI if event_id == "ice_car" else 0.0, "variant":0, "vehicle":"Blue compact sedan",
		"plate":"TMR %03d" % (100 + posmod(completed*37,900)), "vin":"1BTRS39C5WJ%06d" % posmod(completed*2317,1000000),
		"road":road, "location":road+" · "+landmark, "recovery":spec[0], "heavy_recovery":heavy,
		"rate_name":spec[3], "rate_fee":spec[4], "running":true, "reply":"clear", "run":route,
		"dispatch":"Brandt, there's a blue sedan %s at %s. %s Sheriff wants it in storage." % [spec[1],landmark,spec[2]],
		"directions":approach + " " + str(spec[2]), "schedule":_scheduled_miles(Vector2(point.x,point.z))}

static func ordinary(completed: int, dispatch_seed: int, slips: Array, snatch_block := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var used := {}
	var driver_calls := {}
	var site_hazards := {}
	var ditches := 0
	var hazards := 0
	var passenger_calls := 0
	var met_angie := false
	for slip: Dictionary in slips:
		met_angie = met_angie or slip.get("vin", "") == Legacy.JOBS.angie.vin
		if slip.has("case_id") or slip.kind not in ["ditch", "hazard","passenger"]:
			continue
		var site_id := _site_on_slip(slip)
		used[site_id] = int(used.get(site_id, 0)) + 1
		if slip.kind in ["ditch","passenger"]:
			ditches += 1
			if slip.kind=="passenger": passenger_calls+=1
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
	var route := ""
	var best := INF
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		if rotation_count < int(site.get("after_jobs",0)) or (rotation_count == 0 and not site.get("local", false)):
			continue
		if kind == "ditch" and site.get("hazard_only", false):
			continue
		var score := float(used.get(id, 0)) + rng.randf_range(0, 1.25)
		if score < best:
			best = score
			route = id
	var site: Dictionary = SITES[route]
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
	if kind == "ditch":
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
		if job.id=="rotation" and rotation_count>=19 and ditches>=10+posmod(dispatch_seed,3)+passenger_calls*12:
			job.reply = "summer_driver"
		elif rotation_count >= 7 and posmod(rotation_count + dispatch_seed, 4) == 0:
			if job.id == "angie":
				job.reply = "angie_sunburn"
			elif job.id == "farm":
				job.reply = "gary_heifers"
			else:
				var replies := ["displaced_driver","gentle_driver","lost_hours"]
				job.reply = replies[rng.randi_range(0,replies.size()-1)]
		job.dispatch = "%s on %s by %s, %s ditch. %s needs a pull. %s" % [
			job.vehicle, site.road, site.landmark, shoulder, job.person, reason]
	else:
		var reports: Array = site.hazard_reasons
		var reason: String = reports[posmod(dispatch_seed + int(site_hazards.get(route, 0)), reports.size())]
		if heavy:
			job.heavy_recovery = true
			job.plate = "TCU %03d" % ((job.number % 800) + 100)
			reason = "Service body’s loaded with tools. Bring the snatch block. " + reason
		job.dispatch = "%s on %s by %s, %s shoulder. Checked and taped. Bring it to storage. %s" % [
			job.vehicle, site.road, site.landmark, shoulder, reason]
	if job.reply=="summer_driver":
		job.kind="passenger"
		job.id="summer_driver"
		job.driver_variant=2
		job.running=true
		job.untaped=true
		job.person="Driver in a T-shirt"
		job.dispatch="There's a driver out by %s in a T-shirt. %s shoulder on %s. Bring them in to Esker Fuel & Food." % [site.landmark,shoulder,site.road]
	job.directions = "%s Look on the %s side for the %s." % [site.approach, shoulder, job.vehicle.to_lower()]
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
		"directions":"Take Kolpack south past the Lindquist silo. Turn into the Hoffmann drive at the blue N5104 sign."}

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
	var look_only: bool = job.kind in ["looksee","passenger"]
	var mile := snappedf(maxf(0, drop - pickup), .1) if towed else 0.0
	var hookup := 0 if look_only else 16
	var winch := 0 if look_only else maxi(1, ceili(seconds / 60.0)) * 6
	var storage := 12 if towed else 0
	var heavy_fee := HEAVY_FEE if job.get("heavy_recovery", false) else 0
	var rate_fee := float(job.get("rate_fee",0.0)) if revised_rates else 0.0
	var pay := 38.0 + hookup + winch + mile * 3.25 + storage + heavy_fee + rate_fee
	var slip := {"number":job.number, "kind":job.kind, "site":job.site, "run":job.get("run",job.site),
		"location":job.location, "vehicle":job.vehicle, "plate":job.plate, "vin":job.vin,
		"start_odo":start, "pickup_odo":pickup, "drop_odo":drop, "loaded":mile,
		"schedule":job.get("schedule",0.0), "call_out":38, "hookup":hookup, "winch":winch,
		"storage":storage, "heavy_fee":heavy_fee, "pay":snappedf(pay,.01), "time":clock}
	if rate_fee > 0:
		slip.rate_name = job.get("rate_name","Vehicle on ice")
		slip.rate_fee = rate_fee
	if job.has("recovery"):
		slip.recovery = job.recovery
	if job.kind in ["ditch","passenger"]:
		slip.reply = job.get("reply","")
	return slip
