extends RefCounted
## A ticket gets one ambient encounter. Reservations, the active scene and its
## physical aftermath survive a trip to the title screen or a process restart.
const Scene := preload("res://scripts/sighting_scene.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
const Reports := preload("res://scripts/sighting_reports.gd")
const Observations := preload("res://scripts/sighting_observations.gd")
const SET_DOWN_LINE := "Brandt, you on? I’ve got one on the shoulder right in front of you."
const FAR := ["swamp_lights","the_calm","green_flash"]
const PACING := ["pacing_lights","field_car","far_landing","cow_ring","deer_line","green_flash","electrics_fade","dry_road","moving_moon","plow_stopped","warm_air","compass_turns","power_lines","empty_ditch","thaw_glaze","radio_pulse","bare_ring"]
const CLOSE := ["the_lift","woods_car","mirror_follow","empty_oncoming","streetlights_out","walker","yard_visit","snow_up","nose_car","roof_car","ice_car","tree_car","green_circle","pressed_lines","snow_column","missing_time"]
const HIGH := ["overhead","snow_roof","storm_hole","hanging_snow","gate_car"]
const CASUALTIES := ["field_car","level_field_car","nose_car","roof_car","ice_car","tree_car","gate_car","shoulder_car","walker_car"]
const FIXED := {
	"cow_ring":Vector3(414,0,232), "roof_car":Vector3(37,4.75,-13.6),
	"ice_car":Vector3(-477,0,-153), "tree_car":preload("res://scripts/tree_recovery.gd").SITE,
	"level_field_car":preload("res://scripts/rollover.gd").HAYFIELD, "gate_car":Vector3(-8,0,-56), "yard_visit":Vector3(-44,0,-77),
}
var scene: Scene
var drive := -1
var used := false
var seen := {} # last ticket on which each repeatable event appeared
var once := {} # scripted moments, independent of ambient variations
var observations := Observations.new()
var aftermath := {}
var yard_turned := false
var active := ""
var duration := 0.0
var elapsed := 0.0
var level := 0
var origin := Vector3.ZERO
var forward := Vector3.FORWARD
var shoulder := Vector3.ZERO
var road := ""
var jumped := false
var time_lost := false
var live_identity := {}
var heard := false
var credits_due := false
var reset_mix := false
var last_filed := -1
var delay := 0.0
var landing_retry := 0.0

static func tier(filed: int, stage: int) -> int:
	if filed < 2: return 0
	if filed >= 40 or stage >= 6: return 4
	if filed >= 20 or stage >= 2: return 3
	if filed >= 8: return 2
	return 1

static func _pack(p: Vector3) -> Array:
	return [p.x,p.y,p.z]

static func _unpack(data: Array) -> Vector3:
	return Vector3(data[0],data[1],data[2])

func save_state() -> Dictionary:
	return {"drive":drive,"used":used,"seen":seen.duplicate(),"once":once.duplicate(),
		"observations":observations.save_state(),"aftermath":aftermath.duplicate(true),"yard_turned":yard_turned,
		"active":active,"duration":duration,"elapsed":elapsed,"level":level,"origin":_pack(origin),"credits_due":credits_due,
		"forward":_pack(forward),"shoulder":_pack(shoulder),"road":road,"jumped":jumped,"time_lost":time_lost,"delay":delay,"identity":live_identity.duplicate(),"heard":heard}

func restore(data: Dictionary, county: Node3D) -> void:
	if is_instance_valid(scene):
		scene.clear_live()
		scene.get_parent().remove_child(scene)
		scene.queue_free()
	scene = Scene.new()
	scene.setup(county)
	drive = int(data.get("drive",-1))
	used = data.get("used",false)
	seen = data.get("seen",{}).duplicate()
	once = data.get("once",{}).duplicate()
	# Old reportable strings were set at spawn and do not establish a sighting.
	observations.restore(data.get("observations",{}))
	aftermath = data.get("aftermath",{}).duplicate(true)
	yard_turned = data.get("yard_turned",false)
	active = data.get("active","")
	duration = data.get("duration",0.)
	elapsed = data.get("elapsed",0.)
	level = int(data.get("level",0))
	origin = _unpack(data.get("origin",[0,0,0]))
	forward = _unpack(data.get("forward",[0,0,-1]))
	shoulder = _unpack(data.get("shoulder",[0,0,0]))
	road = data.get("road","")
	jumped = data.get("jumped",false)
	time_lost = data.get("time_lost",false)
	delay = data.get("delay",0.)
	last_filed = -1
	landing_retry = 0.0
	live_identity = data.get("identity",{}).duplicate()
	heard = data.get("heard",false)
	credits_due = data.get("credits_due",false)
	reset_mix = true
	county.set_sighting_weather("",0,0)
	if not once.has("ditch_landmarks"):
		# These taped cars can be passed night after night before the first lift.
		once.ditch_landmarks = true
		for spec: Array in [["tape_swamp",Vector3(247,0,-391),"Swamp Rd",PI*.5],["tape_dairy",Vector3(391,0,173),"Kolpack Rd",PI],["tape_church",Vector3(-8.4,0,193),"County K",0.0]]:
			var identity := _identity(spec[0],spec[1],true)
			identity.checked_tape = Scene.Car.Tape.write(spec[2],str(identity.vin).hash(),-6*3600.)
			_record("roadside_tape",spec[1],spec[3],0,0,spec[2],identity,spec[0])
	for key: String in aftermath:
		if not aftermath[key].has("observation_key"):
			aftermath[key].observation_key = "trace/%s/legacy" % key
		scene.add_remnant(key,aftermath[key])
	if not active.is_empty():
		scene.begin(active,origin,forward,shoulder,level,live_identity)
		scene.animate(active,clampf(elapsed/maxf(duration,.01),0.,1.),0.,origin,forward)

func report_options() -> Array[Dictionary]:
	return observations.options()

func report(key: String, game) -> String:
	var note := observations.file(key)
	if note.is_empty(): return ""
	var kind: String = note.kind
	var reply := Reports.reply(kind,game.campaign.stage)
	if kind not in CASUALTIES: return reply
	if game.job.get("observation_key","") == key:
		if game.mode == "invoice": return reply + " I've got it down as delivered. Fax the slip when you're in."
		return reply + " That's your car on slip %04d. Bring it to storage." % int(game.job.number)
	var spot: Dictionary = aftermath.get(note.trace,{})
	if spot.get("observation_key","") != key:
		return reply + " That one has already been picked up."
	spot.reported = true
	if game.rotation_offer.get("aftermath_key","") == note.trace:
		return reply + " The sheriff signed for that one. Take its tow slip when you're clear and bring it to storage."
	if game.campaign.stage < 2:
		return reply + " Leave it there. I'll hold the location for the sheriff."
	if kind in ["field_car","nose_car"] and not game.account.owns("second_winch"):
		return reply + " I'll keep the location. That job takes the auxiliary drum and a snatch block."
	if needs_block(kind) and not game.account.owns("snatch_block"):
		return reply + " Leave it there. You'll need the snatch block and a tow order."
	return reply + " I'll put it on the recovery list. Wait for the tow slip, then bring it to storage."

static func needs_block(kind: String) -> bool:
	return kind in ["tree_car","field_car","nose_car"]

func _identity(kind: String, at: Vector3, tape: bool) -> Dictionary:
	var digits := ("%s/%d/%d/%d" % [kind,roundi(at.x),roundi(at.z),drive]).hash()
	return {"variant":0,"plate":"TMR %03d" % (100+posmod(digits,900)),"vin":"1BTRS39C5WJ%06d" % posmod(digits,1000000),"untaped":not tape}

func _record(id: String, at: Vector3, heading: float, filed: int, height := 0., street := "", vehicle := {}, key := "", half_length := 0.) -> void:
	if key.is_empty(): key = id
	if aftermath.has(key): return
	if id in CASUALTIES and vehicle.is_empty(): vehicle = _identity(id,at,false)
	aftermath[key] = {"observation_key":"trace/%s/%d" % [key,drive],"id":id,"x":at.x,"z":at.z,"height":height,"yaw":heading,
		"expires":-1 if id in CASUALTIES or id=="roadside_tape" else filed+4,"road":street,"vehicle":vehicle}
	if half_length>0.: aftermath[key]["half_length"] = half_length
	scene.add_remnant(key,aftermath[key])

func _snow_over(filed: int) -> void:
	if last_filed == filed: return
	last_filed = filed
	for key: String in aftermath.keys():
		var expires := int(aftermath[key].expires)
		if expires >= 0 and filed >= expires:
			scene.remove_remnant(key)
			aftermath.erase(key)
		elif scene.world.thawed_roads.has(key):
			scene.world.thawed_roads[key].set_age(filed-(expires-4))

func recovery_offer(issued: int, county: Node3D, has_block := true, after_story := true, second_drum := true) -> Dictionary:
	if not is_instance_valid(scene): return {}
	# Back ordinary dispatch between extraordinary tows. The last set-down is
	# the next available order regardless of its position in that rotation.
	if not aftermath.has("shoulder_car") and issued%11 not in [0,5]: return {}
	var waiting_roll := ""
	var choices := ["shoulder_car"]
	for key: String in aftermath:
		if aftermath[key].get("reported",false): choices.append(key)
	choices.append_array(aftermath.keys())
	for key: String in choices:
		if not aftermath.has(key): continue
		var spot: Dictionary = aftermath[key]
		var id: String = spot.id
		if not id in CASUALTIES: continue
		if id in ["field_car","nose_car"] and not second_drum:
			waiting_roll = spot.observation_key
			continue
		if not has_block and needs_block(id): continue
		var point := Vector3(spot.x,spot.height,spot.z)
		var street: String = spot.road
		if street.is_empty(): street = "County K"
		var landmark: String = {"roof_car":"Esker Co-op roof","tree_car":"tamaracks at the Swamp Road bend",
			"level_field_car":"the hay strip west of Kolpack Road","ice_car":"flowage above the dam","gate_car":"Brandt yard gate","field_car":"upturned sedan in the field",
			"nose_car":"sedan standing on its nose","walker_car":"abandoned shoulder car",
			"shoulder_car":"running sedan at the edge of the road"}[id]
		var order: Dictionary = Dispatch.impossible(issued,id,point,key,street,landmark,"Stay on %s. Watch for the %s." % [street,landmark])
		order.merge(spot.get("vehicle",{}),true)
		order.aftermath_key = key
		order.angle = spot.yaw
		return order
	# A level car out in the hay can be brought in on the stock drum. Keep
	# the reported rollover on its own card with its original VIN and pose.
	if not waiting_roll.is_empty() and not once.has("field_tow/"+waiting_roll):
		once["field_tow/"+waiting_roll] = true
		_record("level_field_car",FIXED.level_field_car,PI*.5,issued,0.,"Kolpack Rd")
		return recovery_offer(issued,county,has_block,after_story,second_drum)
	# Keep the special procedures in rotation even if the player missed the
	# original roadside encounter. The vehicle exists before dispatch calls.
	if after_story and once.has("story_set_down") and has_block:
		var options := ["roof_car","ice_car","tree_car","level_field_car","gate_car"]
		if second_drum: options.append_array(["field_car","nose_car"])
		var key: String = options[posmod((issued/11)*2+int(issued%11==5),options.size())]
		var point: Vector3 = FIXED.get(key,Vector3(383,0,275))
		var street: String = {"roof_car":"Highway 64","ice_car":"Highway 64","tree_car":"Swamp Rd","gate_car":"County K"}.get(key,"Kolpack Rd")
		_record(key,point,0,issued,point.y,street)
		return recovery_offer(issued,county,has_block,after_story,second_drum)
	return {}

func claim_recovery(ticket: Dictionary) -> void:
	var key: String = ticket.get("aftermath_key","")
	if not aftermath.has(key): return
	ticket.observation_key = aftermath[key].observation_key
	scene.remove_remnant(key)
	aftermath.erase(key)

func _taped_ahead(at: Vector3, heading: Vector3) -> String:
	var best := 155.0
	var key := ""
	for candidate: String in aftermath:
		var spot: Dictionary = aftermath[candidate]
		if spot.id != "roadside_tape": continue
		var offset := Vector3(spot.x-at.x,0,spot.z-at.z)
		if offset.length() < best and offset.dot(heading)>30.:
			best = offset.length()
			key = candidate
	return key

func _choose(game, current_road: String, at: Vector3) -> String:
	var filed: int = game.completed
	if level == 1:
		if (filed-2)%3 == 0: return FAR[posmod((filed-2)/3,FAR.size())]
		return ""
	if level == 2 and (drive%4 == 0): return ""
	var options: Array = PACING.duplicate()
	if level >= 3: options = CLOSE+options
	if level >= 4 and drive%4 == 0: options = HIGH+options
	if level == 2 and not seen.has("pacing_lights"): return "pacing_lights"
	if not seen.has("field_car") and not _urban(at): return "field_car"
	var best := -INF
	var selected := ""
	for id: String in options:
		if aftermath.has(id) or drive-int(seen.get(id,-100)) < (16 if id=="missing_time" else 5): continue
		if FIXED.has(id) and at.distance_to(FIXED[id]) > (150. if id in ["yard_visit","cow_ring"] else 90.): continue
		if id=="power_lines" and (_urban(at) or current_road not in ["County K","Kolpack Rd","Swamp Rd","Hendricks Rd","Highway 64","US 59"]): continue
		if id=="streetlights_out" and (current_road!="Highway 64" or absf(at.x)>130.): continue
		if id=="gate_car" and game.campaign.stage<8: continue
		if id=="mirror_follow" and not game.rig.loaded: continue
		if id=="plow_stopped" and game.rig.duane_on_scene(): continue
		if id in ["the_lift","empty_ditch"] and _taped_ahead(at,Vector3.FORWARD.rotated(Vector3.UP,game.rig.heading)).is_empty(): continue
		if id=="missing_time" and _jump_point(game) == Vector3.INF: continue
		if id=="yard_visit" and (game.stored.is_empty() or game.mode!="haul"): continue
		if id in ["deer_line","plow_stopped","walker","woods_car","the_lift","field_car","nose_car","empty_ditch","pressed_lines","green_circle"] and _urban(at): continue
		if id=="electrics_fade" and (absf(game.rig.acceleration)>3.0 or absf(game.rig.pitch)>.075): continue
		var variety := float(("%s-%s-%s" % [game.dispatch_seed,drive,id]).hash()%997)/997.
		var score := variety + (1.0 if (id in CLOSE and level==3) or (id in HIGH and level==4) else 0.)
		if not seen.has(id): score += 1.65
		if id=="pacing_lights" and drive%7==0: score += 2.
		if score > best:
			selected = id
			best = score
	return selected

func _urban(at: Vector3) -> bool:
	return absf(at.x)<146. and absf(at.z)<125.

func _story(game, at: Vector3) -> String:
	var id: String = game.job.get("case_id","")
	var evidence: Dictionary = game.campaign.evidence
	match id:
		"mail":
			if game.rig.loaded and not once.has("carrier_follow"): return "mirror_follow"
		"line":
			if at.z < -476. and absf(at.x-441.)<25. and not once.has("alder_snow"): return "hanging_snow"
		"ride":
			if evidence.has("passenger") and not once.has("ride_overhead") and game.rig.in_cab and absf(game.rig.speed)>1.: return "overhead"
			if not evidence.has("passenger") and at.z < -493. and absf(at.x-441.)<27. and not once.has("tou_sky"): return "storm_hole"
		"angie":
			if at.distance_to(Vector3(449,0,-468))<48. and not once.has("angie_lights"): return "angie_lights"
		"":
			if game.campaign.stage >= 8 and not once.has("story_set_down") and game.mode=="fieldwork" and game.rig.in_cab and game.rig.speed>2.:
				return "set_down"
	return ""

func _landing_site(game, at: Vector3, heading: Vector3) -> Vector3:
	# Follow the driver's route only up to the next turn or assigned scene.
	var nav = game._current_road_map()
	var start := Vector2(at.x,at.z)
	var ahead := Vector2(heading.x,heading.z)
	var job_at: Vector3 = game.job.point
	var path: PackedVector2Array = nav._path(nav._nearest(start,ahead),nav._nearest(Vector2(job_at.x,job_at.z)))
	if path.size()<2 or path[0].direction_to(path[1]).dot(ahead)<.92: return Vector3.INF
	var run := 0.0
	for i in range(1,path.size()):
		if path[i-1].direction_to(path[i]).dot(ahead)<.98: break
		run += path[i].distance_to(path[i-1])
	var speed: float = game.rig.speed
	var station := minf(run-10.0,clampf(speed*4.6+30.,52.,115.))
	if station < maxf(33.,speed*2.6+10.): return Vector3.INF
	var side := heading.cross(Vector3.UP)
	var center := Vector3(path[0].x,0,path[0].y)+heading*station
	var street: String = nav.driven_road(start)
	var space: PhysicsDirectSpaceState3D = game.rig.get_world_3d().direct_space_state
	for offset: float in [0.,-7.,6.]:
		var shoulder_center := center+heading*offset
		if station+offset >= run-3. or nav.driven_road(Vector2(shoulder_center.x,shoulder_center.z)) != street: continue
		for side_sign: float in [1.,-1.]:
			# Land on the plowed shoulder, before the ground falls into the ditch.
			var candidate := scene.ground(shoulder_center+side*(6.3*side_sign))
			if game.county.road_distance(candidate.x,candidate.z)<6.2 or (candidate.x>-504 and candidate.x< -446 and absf(candidate.z)<15.): continue
			if game.rig.near_casualty(12.) or candidate.distance_to(job_at)<10.: continue
			var clear := true
			for end: float in [-1.9,0.,1.9]:
				var foot := scene.ground(candidate+heading*end)
				var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*23.,foot+Vector3.UP*.31,1)
				if not space.intersect_ray(ray).is_empty():
					clear = false
					break
			if clear:
				# Keep the sedan level, with both wheel tracks settled in the snow.
				var axle := side * Scene.Car.SEDAN_SIZE.x
				candidate.y = minf(game.county.surface_point(candidate-axle).y,game.county.surface_point(candidate+axle).y)
				return candidate
	return Vector3.INF

func _start(id: String, game, location: Vector3, street: String, story: bool, landing := Vector3.INF) -> void:
	active = id
	elapsed = 0.0
	origin = location
	forward = Vector3.FORWARD.rotated(Vector3.UP,game.rig.heading)
	# Take the direction along the actual road. Small steering corrections
	# must not place a shoulder event in the traveled lane.
	if absf(forward.x)>absf(forward.z): forward = Vector3(signf(forward.x),0,0)
	else: forward = Vector3(0,0,signf(forward.z))
	road = street
	var side := forward.cross(Vector3.UP)
	var ahead := 105.0 if id == "the_lift" else (83.0 if id == "woods_car" else 59.0)
	var at := origin+forward*ahead
	var roads = game._current_road_map()
	var near: Dictionary = roads._nearest(Vector2(at.x,at.z))
	if not near.is_empty():
		at.x = near.point.x
		at.z = near.point.y
	shoulder = scene.ground(at+side*8.5)
	if id == "deer_line" and not Scene.Deer.has_room(game,at,forward,street):
		active = ""
		used = true
		return
	if id=="woods_car" and not Scene.Woods.has_room(game,shoulder,forward):
		active = ""
		used = true
		return
	if id in ["field_car","nose_car","pressed_lines","green_circle","bare_ring","far_landing","snow_column","snow_up"]: shoulder=scene.ground(at+side*24.)
	if id=="empty_oncoming":
		if not Scene.Oncoming.clear_road(game,at,forward,street):
			active = ""
			used = true
			return
		shoulder=scene.ground(at-side*2.25)
	var thaw_span := 0.0
	if id in ["dry_road","snow_roof"]:
		var stretch := Scene.Thaw.locate(roads,at,forward,id)
		if stretch.is_empty() or aftermath.has(id):
			active = ""
			used = true
			return
		shoulder = scene.ground(stretch.center)
		forward = Vector3.FORWARD.rotated(Vector3.UP,stretch.yaw)
		road = stretch.road
		thaw_span = stretch.half
	if FIXED.has(id): shoulder = scene.ground(FIXED[id])
	if id=="set_down" and landing.is_finite(): shoulder = landing
	if id=="angie_lights": shoulder = Vector3(444,0,-534)
	jumped = false
	time_lost = false
	heard = false
	live_identity = _identity(id,shoulder,id=="the_lift")
	if id in ["the_lift","empty_ditch"]:
		var key := _taped_ahead(origin,forward)
		if not key.is_empty():
			var taped: Dictionary = aftermath[key]
			live_identity = taped.vehicle
			shoulder = scene.ground(Vector3(taped.x,0,taped.z))
			live_identity["yaw"] = taped.yaw
			scene.remove_remnant(key)
			aftermath.erase(key)
	duration = 10.0 + level*2.0
	if id=="deer_line": duration=23.0
	if id=="set_down": duration=clampf(((shoulder-origin).dot(forward)-16.)/maxf(8.,game.rig.speed),2.4,5.8)
	if id=="storm_hole": duration=58.
	if id=="missing_time": duration=3.2
	if id=="mirror_follow": duration=26.
	if id=="the_calm" or id=="green_flash": duration=6.
	used = true
	seen[id] = drive
	if story:
		var script_key: String = {"mirror_follow":"carrier_follow","hanging_snow":"alder_snow","storm_hole":"tou_sky",
			"overhead":"ride_overhead","angie_lights":"angie_lights","set_down":"story_set_down"}[id]
		once[script_key] = true
	scene.begin(id,origin,forward,shoulder,level,live_identity)
	if id in CASUALTIES or id in ["cow_ring","bare_ring","green_circle","pressed_lines","empty_ditch","dry_road","snow_roof"]:
		var fixed_at: Vector3 = FIXED.get(id,Vector3.ZERO)
		var street_name: String = {"roof_car":"Highway 64","ice_car":"Highway 64","tree_car":"Swamp Rd","gate_car":"County K"}.get(id,street)
		var yaw := PI if id=="ice_car" else atan2(-forward.x,-forward.z)
		_record(id,shoulder,yaw,game.completed,fixed_at.y,road if thaw_span>0. else street_name,{},"",thaw_span)

func finish(game, interrupted := false) -> void:
	if active.is_empty():
		return
	var yaw := atan2(-forward.x,-forward.z)
	var side := forward.cross(Vector3.UP)
	match active:
		"set_down":
			if interrupted:
				# A yard rescue can end a drive before the sedan touches down.
				once.erase("story_set_down")
			else:
				var settled_height := shoulder.y - scene.ground(shoulder).y
				_record("shoulder_car",shoulder,yaw,game.completed,settled_height,road,live_identity)
				credits_due = true
		"walker":
			_record("bootprints",shoulder,yaw-PI*.5,game.completed)
			_record("walker_car",shoulder-forward*11.,yaw,game.completed,0,road)
		"the_lift","empty_ditch":
			_record("empty_ditch",shoulder,yaw,game.completed)
			_record("field_car",shoulder+side*28.,yaw,game.completed,0,road,live_identity,"lifted_%d" % drive)
		"far_landing","snow_up","snow_column":
			_record("bare_ring",shoulder,yaw,game.completed)
		"woods_car":
			_record("woods_tracks",shoulder+side*Scene.Woods.TRACK_START,yaw-PI*.5,game.completed,0.,road)
		"deer_line":
			_record("hoofprints",shoulder+side*(Scene.Deer.OFFSETS[0]-Scene.Deer.BANK_OFFSET),yaw-PI*.5,game.completed,0.,road)
		"yard_visit":
			yard_turned = true
			game._turn_storage_north()
	scene.clear_live()
	active = ""
	game.rig.set_sighting(0.,Vector3.INF,0.)
	game.rig.body.glass_material.set_shader_parameter("thaw",0.)
	game.audio.set_sighting(0.,0.)
	game.county.set_sighting_weather("",0.,0.)
	game.picture.self_modulate = Color.WHITE

func _jump_point(game) -> Vector3:
	var rig = game.rig
	if game.mode != "fieldwork" or not rig.in_cab or rig.loaded or rig.speed < 3. or not game.job.has("point"): return Vector3.INF
	if id_is_case(game.job) or rig.phase not in ["scene","idle"]: return Vector3.INF
	var at: Vector3 = rig.get_truck_position()
	var dest: Vector3 = game.job.point
	var roads = game._current_road_map()
	var heading := Vector3.FORWARD.rotated(Vector3.UP,rig.heading)
	var end := at+heading*34.
	var street: String = roads.driven_road(Vector2(at.x,at.z))
	if street.is_empty() or at.distance_to(dest)<90. or end.distance_to(dest)>=at.distance_to(dest)-8.: return Vector3.INF
	if roads.driven_road(Vector2(end.x,end.z)) != street or game.county.road_distance(end.x,end.z)>3.2: return Vector3.INF
	if rig._truck_obstacle(heading*34.,0.): return Vector3.INF
	return end

func id_is_case(job: Dictionary) -> bool:
	return job.has("case_id") or job.kind in ["looksee","hold"]

func _advance_live(dt: float,game, at: Vector3) -> void:
	elapsed += dt
	if active == "woods_car":
		var distance := maxf(1.,(shoulder-origin).dot(forward)-24.)
		elapsed = maxf(elapsed,clampf((at-origin).dot(forward)/distance,0.,1.)*duration*.83)
	if active=="deer_line":
		var remaining := (shoulder-at).dot(forward)
		var approach := clampf(maxf(0.,game.rig.speed)*2.1+3.,8.,44.)
		var crossing := (1.-clampf((remaining-7.)/approach,0.,1.))*.98
		elapsed = maxf(elapsed,crossing*duration)
	if active == "set_down":
		# A driver can accelerate mid-descent. Finish the landing and radio cue
		# while the sedan remains in front of the bumper, even then.
		var span := maxf(1.,(shoulder-origin).dot(forward)-18.)
		elapsed = maxf(elapsed,clampf((at-origin).dot(forward)/span,0.,1.)*duration)
	var t := clampf(elapsed/maxf(.01,duration),0.,1.)
	var intensity := smoothstep(0.,.12,t)*(1.-smoothstep(.80,1.,t))
	if active=="mirror_follow" and game.job.get("case_id")=="mail" and once.has("carrier_follow") and not once.has("carrier_words") and elapsed >= 2.3:
		once["carrier_words"] = true
		game._speak("DISPATCH","They follow you, Brandt. They always have. While you’re out, they’re not over anybody’s house.")
	if active in ["snow_roof","dry_road"]:
		var strip: Node3D = game.county.thawed_roads.get(active)
		if active=="snow_roof": game.county.shelter_road_snow(intensity)
		intensity *= strip.coverage(game.rig.get_player_position(),10. if active=="snow_roof" else 4.6) if strip else 0.
	var light := scene.animate(active,t,intensity,at,Vector3.FORWARD.rotated(Vector3.UP,game.rig.heading))
	if active=="empty_oncoming" and scene.actor.visible and (scene.actor.position-at).dot(forward)<Scene.Oncoming.CUT_OFF:
		scene.actor.hide()
		live_identity.passed = true
	var safe_electrics: bool = absf(game.rig.acceleration)<3.5 and absf(game.rig.pitch)<.075
	var electrical := intensity if safe_electrics and active in ["electrics_fade","overhead","set_down","mirror_follow"] else 0.0
	var calm := intensity*(1.-smoothstep(.44,.55,t)) if active=="deer_line" else intensity
	game.rig.set_sighting(calm,light,electrical)
	game.rig.body.glass_material.set_shader_parameter("thaw",intensity if active in ["warm_air","thaw_glaze","dry_road"] else 0.)
	game.audio.set_sighting(calm,calm*(.48 if level==1 else .92))
	game.county.set_sighting_weather(active,calm,t)
	if active=="set_down" and not heard and t>=.76:
		heard = true
		game._speak("DISPATCH",SET_DOWN_LINE)
	if active=="cow_ring" and not heard and game.sub_time<=0.0 and at.distance_to(shoulder)<65.:
		heard = true
		game._say("bev_heifers")
	if active=="walker" and not heard and scene.actor.position.distance_to(game.rig.get_player_position()) < 14. and absf(game.rig.speed)<1.:
		heard = true
		game._speak("DRIVER","I’m fine. I just want to see.")
	if active=="plow_stopped" and not heard and t>.68:
		heard = true
		game.scanner.plow_call(game)
	if active=="missing_time":
		var shade := 1.-smoothstep(0.,.32,t)*(1.-smoothstep(.62,1.,t))
		game.picture.self_modulate = Color(shade,shade,shade)
		if t >= .45 and not jumped:
			jumped = true
			var jump := _jump_point(game)
			if jump.is_finite():
				game.rig.set_spawn(jump,game.rig.heading)
				game.shift_seconds += 40.*60.
				time_lost = true
				game._speak("DISPATCH","There you are. I’ve been calling for forty minutes, Brandt.")
	if t >= 1.0: finish(game)

func advance(dt: float,game) -> void:
	if not is_instance_valid(scene): return
	if reset_mix:
		reset_mix = false
		game.rig.set_sighting(0.,Vector3.INF,0.)
		game.audio.set_sighting(0.,0.)
		game.picture.self_modulate = Color.WHITE
		game.rig.body.glass_material.set_shader_parameter("thaw",0.)
	var rig = game.rig
	var at: Vector3 = rig.get_truck_position()
	var number := int(game.job.get("number",-1))
	if number != drive and number >= 0:
		drive = number
		used = false
		delay = 0.
	_snow_over(game.completed)
	level = tier(game.completed,game.campaign.stage)
	var delicate: bool = rig.tension>.01 or rig.working or rig.phase in ["cable","rigged","at_lift","dollies","boom_lower"]
	if not active.is_empty():
		# Tou can get in before the full minute of clear sky has elapsed.
		if active=="plow_stopped" and rig.duane_on_scene():
			finish(game)
		elif active=="storm_hole" and game.job.get("case_id")=="ride" and game.campaign.evidence.has("passenger"):
			finish(game)
		else:
			_advance_live(dt,game,at)
			return
	if level==0 or number<0 or delicate: return
	var story := _story(game,at)
	if not story.is_empty() and rig.in_cab:
		var street: String = game._current_road_map().driven_road(Vector2(at.x,at.z))
		var landing := Vector3.INF
		if story == "set_down":
			if street.is_empty() or game.county.YARD.grow(8).has_point(Vector2(at.x,at.z)): return
			landing_retry -= dt
			if landing_retry > 0.0: return
			landing_retry = .30
			var bearing := Vector3.FORWARD.rotated(Vector3.UP,rig.heading)
			var axis := Vector3(signf(bearing.x),0,0) if absf(bearing.x)>absf(bearing.z) else Vector3(0,0,signf(bearing.z))
			if bearing.dot(axis)<.92: return
			landing = _landing_site(game,at,axis)
			if not landing.is_finite(): return
		_start(story,game,at,street,true,landing)
		return
	if used or not rig.in_cab or game.mode not in ["fieldwork","haul"] or absf(rig.speed)<1.6: return
	if id_is_case(game.job): return
	delay += dt
	if delay < 2.4: return
	# Give each drive time to leave the town limits. Short local jobs qualify
	# sooner, so the first lights still read through the windshield on call three.
	var target: Vector3 = rig.dropoff.center if game.mode=="haul" else game.job.point
	var distance: float = at.distance_to(target)
	if distance > (160.0 if level<=1 else 118.0) and delay < 15.0: return
	# On some loaded jobs leave the outbound leg quiet for a mirror encounter.
	if game.job.kind=="hazard" and drive%4==2 and game.mode!="haul" and level>=2: return
	var street: String = game._current_road_map().driven_road(Vector2(at.x,at.z))
	if street.is_empty(): return
	var id := _choose(game,street,at)
	if id.is_empty():
		used = true
		return
	_start(id,game,at,street,false)
