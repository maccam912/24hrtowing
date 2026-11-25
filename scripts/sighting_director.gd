extends RefCounted
## A ticket gets one ambient encounter. Reservations, the active scene and its
## physical aftermath survive a trip to the title screen or a process restart.
const Scene := preload("res://scripts/sighting_scene.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
const FAR := ["swamp_lights","the_calm","green_flash"]
const PACING := ["pacing_lights","field_car","far_landing","cow_ring","deer_line","green_flash","electrics_fade","dry_road","moving_moon","plow_stopped","warm_air","compass_turns","power_lines","empty_ditch","thaw_glaze","radio_pulse","bare_ring"]
const CLOSE := ["the_lift","woods_car","mirror_follow","empty_oncoming","streetlights_out","walker","yard_visit","snow_up","nose_car","roof_car","ice_car","tree_car","green_circle","pressed_lines","snow_column","missing_time"]
const HIGH := ["overhead","snow_roof","storm_hole","hanging_snow","gate_car"]
const CASUALTIES := ["field_car","nose_car","roof_car","ice_car","tree_car","gate_car","shoulder_car","walker_car"]
const FIXED := {
	"cow_ring":Vector3(414,0,232), "roof_car":Vector3(37,4.75,-13.6),
	"ice_car":Vector3(-477,0,-153), "tree_car":Vector3(207,5,-409),
	"gate_car":Vector3(-8,0,-56), "yard_visit":Vector3(-44,0,-77),
}
var scene: Scene
var drive := -1
var used := false
var seen := {} # last ticket on which each repeatable event appeared
var once := {} # scripted moments, independent of ambient variations
var reportable := ""
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
var live_identity := {}
var heard := false
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
		"reportable":reportable,"aftermath":aftermath.duplicate(true),"yard_turned":yard_turned,
		"active":active,"duration":duration,"elapsed":elapsed,"level":level,"origin":_pack(origin),
		"forward":_pack(forward),"shoulder":_pack(shoulder),"road":road,"jumped":jumped,"delay":delay,"identity":live_identity.duplicate(),"heard":heard}

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
	reportable = data.get("reportable","")
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
	delay = data.get("delay",0.)
	last_filed = -1
	landing_retry = 0.0
	live_identity = data.get("identity",{}).duplicate()
	heard = data.get("heard",false)
	reset_mix = true
	county.set_sighting_weather("",0,0)
	if not once.has("ditch_landmarks"):
		# These taped cars can be passed night after night before the first lift.
		once.ditch_landmarks = true
		for spec: Array in [["tape_swamp",Vector3(247,0,-391),"Swamp Rd",PI*.5],["tape_dairy",Vector3(391,0,173),"Kolpack Rd",PI],["tape_church",Vector3(-8.4,0,193),"County K",0.0]]:
			_record("roadside_tape",spec[1],spec[3],0,0,spec[2],_identity(spec[0],spec[1],true),spec[0])
	for key: String in aftermath:
		scene.add_remnant(key,aftermath[key])
	if not active.is_empty():
		scene.begin(active,origin,forward,shoulder,level,live_identity)
		scene.animate(active,clampf(elapsed/maxf(duration,.01),0.,1.),0.,origin,forward)

func can_report() -> bool:
	return not reportable.is_empty()

func report(stage: int) -> String:
	reportable = ""
	return "Copy, Brandt. I see where you are. They like to stay with your truck." if stage >= 4 else "Lights logged. No action. You’re clear to finish your call, Brandt."

func _identity(kind: String, at: Vector3, tape: bool) -> Dictionary:
	var digits := ("%s/%d/%d/%d" % [kind,roundi(at.x),roundi(at.z),drive]).hash()
	return {"variant":0,"plate":"TMR %03d" % (100+posmod(digits,900)),"vin":"1BTRS39C5WJ%06d" % posmod(digits,1000000),"untaped":not tape}

func _record(id: String, at: Vector3, heading: float, filed: int, height := 0., street := "", vehicle := {}, key := "") -> void:
	if key.is_empty(): key = id
	if aftermath.has(key): return
	if id in CASUALTIES and vehicle.is_empty(): vehicle = _identity(id,at,false)
	aftermath[key] = {"id":id,"x":at.x,"z":at.z,"height":height,"yaw":heading,
		"expires":-1 if id in CASUALTIES or id=="roadside_tape" else filed+4,"road":street,"vehicle":vehicle}
	scene.add_remnant(key,aftermath[key])

func _snow_over(filed: int) -> void:
	if last_filed == filed: return
	last_filed = filed
	for key: String in aftermath.keys():
		var expires := int(aftermath[key].expires)
		if expires >= 0 and filed >= expires:
			scene.remove_remnant(key)
			aftermath.erase(key)

func recovery_offer(issued: int, county: Node3D, has_block := true, after_story := true) -> Dictionary:
	if not is_instance_valid(scene): return {}
	# Back ordinary dispatch between extraordinary tows. The last set-down is
	# the next available order regardless of its position in that rotation.
	if not aftermath.has("shoulder_car") and issued%11 not in [0,5]: return {}
	var choices := ["shoulder_car"]+aftermath.keys()
	for key: String in choices:
		if not aftermath.has(key): continue
		var spot: Dictionary = aftermath[key]
		var id: String = spot.id
		if not id in CASUALTIES: continue
		if not has_block and id in ["tree_car","field_car","nose_car"]: continue
		var point := Vector3(spot.x,spot.height,spot.z)
		var street: String = spot.road
		if street.is_empty(): street = "County K"
		var landmark: String = {"roof_car":"Esker Co-op roof","tree_car":"tamaracks at the Swamp Road bend",
			"ice_car":"flowage above the dam","gate_car":"Brandt yard gate","field_car":"upturned sedan in the field",
			"nose_car":"sedan standing on its nose","walker_car":"abandoned shoulder car",
			"shoulder_car":"running sedan at the edge of the road"}[id]
		var order: Dictionary = Dispatch.impossible(issued,id,point,key,street,landmark,"Stay on %s. Watch for the %s." % [street,landmark])
		order.merge(spot.get("vehicle",{}),true)
		order.aftermath_key = key
		order.angle = spot.yaw
		return order
	# Keep the special procedures in rotation even if the player missed the
	# original roadside encounter. The vehicle exists before dispatch calls.
	if after_story and once.has("story_set_down") and has_block:
		var options := ["roof_car","ice_car","tree_car","field_car","nose_car","gate_car"]
		var key: String = options[posmod((issued/11)*2+int(issued%11==5),options.size())]
		var point: Vector3 = FIXED.get(key,Vector3(383,0,275))
		var street: String = {"roof_car":"Highway 64","ice_car":"Highway 64","tree_car":"Swamp Rd","gate_car":"County K"}.get(key,"Kolpack Rd")
		_record(key,point,0,issued,point.y,street)
		return recovery_offer(issued,county,has_block,after_story)
	return {}

func claim_recovery(ticket: Dictionary) -> void:
	var key: String = ticket.get("aftermath_key","")
	if not aftermath.has(key): return
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
			var candidate := scene.ground(shoulder_center+side*(8.2*side_sign))
			if game.county.road_distance(candidate.x,candidate.z)<6.2 or (candidate.x>-504 and candidate.x< -446 and absf(candidate.z)<15.): continue
			if game.rig.near_casualty(12.) or candidate.distance_to(job_at)<10.: continue
			var clear := true
			for end: float in [-1.9,0.,1.9]:
				var foot := scene.ground(candidate+heading*end)
				var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*23.,foot+Vector3.UP*.31,1)
				if not space.intersect_ray(ray).is_empty():
					clear = false
					break
			if clear: return candidate
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
	var ahead := 105.0 if id in ["the_lift","woods_car"] else 59.0
	var at := origin+forward*ahead
	var roads = game._current_road_map()
	var near: Dictionary = roads._nearest(Vector2(at.x,at.z))
	if not near.is_empty():
		at.x = near.point.x
		at.z = near.point.y
	shoulder = scene.ground(at+side*8.5)
	if id in ["field_car","nose_car","pressed_lines","green_circle","bare_ring","far_landing","snow_column","snow_up"]: shoulder=scene.ground(at+side*24.)
	if id=="empty_oncoming": shoulder=scene.ground(at-side*2.)
	if id in ["dry_road","snow_roof"]: shoulder=scene.ground(at)
	if FIXED.has(id): shoulder = scene.ground(FIXED[id])
	if id=="set_down" and landing.is_finite(): shoulder = landing
	if id=="angie_lights": shoulder = Vector3(444,0,-534)
	jumped = false
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
	else: reportable = id
	scene.begin(id,origin,forward,shoulder,level,live_identity)
	if id in CASUALTIES or id in ["cow_ring","bare_ring","green_circle","pressed_lines","empty_ditch","dry_road","snow_roof"]:
		var fixed_at: Vector3 = FIXED.get(id,Vector3.ZERO)
		var street_name: String = {"roof_car":"Highway 64","ice_car":"Highway 64","tree_car":"Swamp Rd","gate_car":"County K"}.get(id,street)
		var yaw := PI if id=="ice_car" else atan2(-forward.x,-forward.z)
		_record(id,shoulder,yaw,game.completed,fixed_at.y,street_name)

func _finish(game) -> void:
	var yaw := atan2(-forward.x,-forward.z)
	var side := forward.cross(Vector3.UP)
	match active:
		"set_down":
			_record("shoulder_car",shoulder,yaw,game.completed,0,road,live_identity)
		"walker":
			_record("bootprints",shoulder,yaw-PI*.5,game.completed)
			_record("walker_car",shoulder-forward*11.,yaw,game.completed,0,road)
		"the_lift","empty_ditch":
			_record("empty_ditch",shoulder,yaw,game.completed)
			_record("field_car",shoulder+side*28.,yaw,game.completed,0,road,live_identity,"lifted_%d" % drive)
		"far_landing","snow_up","snow_column":
			_record("bare_ring",shoulder,yaw,game.completed)
		"woods_car":
			_record("woods_tracks",shoulder+side*7.,yaw-PI*.5,game.completed)
		"deer_line":
			_record("hoofprints",shoulder,yaw-PI*.5,game.completed)
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
	if active == "snow_roof":
		var along := absf((at-shoulder).dot(forward))
		intensity *= (1.-smoothstep(52.,68.,along))
	var light := scene.animate(active,t,intensity,at,Vector3.FORWARD.rotated(Vector3.UP,game.rig.heading))
	var safe_electrics: bool = absf(game.rig.acceleration)<3.5 and absf(game.rig.pitch)<.075
	var electrical := intensity if safe_electrics and active in ["electrics_fade","overhead","set_down","mirror_follow"] else 0.0
	game.rig.set_sighting(intensity,light,electrical)
	game.rig.body.glass_material.set_shader_parameter("thaw",intensity if active in ["warm_air","thaw_glaze","dry_road"] else 0.)
	game.audio.set_sighting(intensity,intensity*(.48 if level==1 else .92))
	game.county.set_sighting_weather(active,intensity,t)
	if active=="set_down" and not heard and t>=.76:
		heard = true
		game._speak("DISPATCH","Brandt, you on? I’ve got one on the shoulder right in front of you.")
	if active=="cow_ring" and not heard and game.sub_time<=0.0 and at.distance_to(shoulder)<65.:
		heard = true
		game._say("bev_heifers")
	if active=="walker" and not heard and scene.actor.position.distance_to(game.rig.get_player_position()) < 14. and absf(game.rig.speed)<1.:
		heard = true
		game._speak("DRIVER","I’m fine. I just want to see.")
	if active=="plow_stopped" and not heard and t>.68:
		heard = true
		game._say("plow")
	if active=="missing_time":
		var shade := 1.-smoothstep(0.,.32,t)*(1.-smoothstep(.62,1.,t))
		game.picture.self_modulate = Color(shade,shade,shade)
		if t >= .45 and not jumped:
			jumped = true
			var jump := _jump_point(game)
			if jump.is_finite():
				game.rig.set_spawn(jump,game.rig.heading)
				game.shift_seconds += 40.*60.
				game._speak("DISPATCH","There you are. I’ve been calling for forty minutes, Brandt.")
	if t >= 1.0: _finish(game)

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
		if active=="storm_hole" and game.job.get("case_id")=="ride" and game.campaign.evidence.has("passenger"):
			_finish(game)
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
