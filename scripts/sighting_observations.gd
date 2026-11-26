extends RefCounted
## The director knows what is in the county. This notebook only knows what the
## operator had a chance to recognize from the playing camera or examined on foot.
const Reports := preload("res://scripts/sighting_reports.gd")
const SKY_LIGHTS := ["swamp_lights","pacing_lights","mirror_follow","overhead","yard_visit","angie_lights","far_landing"]
const SAMPLE_INTERVAL := 0.10
const LOOK_TIME := 0.9

# The player's wrecker is visual geometry without a physics body. The opaque
# roof, hood and service body can hide a sightline even when the county ray is clear.
const TRUCK_PANELS := [
	AABB(Vector3(-1.05,3.16,-1.62),Vector3(2.1,.17,1.73)),
	AABB(Vector3(-.96,1.04,-3.87),Vector3(1.92,.76,2.12)),
	AABB(Vector3(-1.04,1.03,-1.73),Vector3(2.08,1.05,1.73)),
	AABB(Vector3(-1.12,.83,.18),Vector3(2.24,.94,3.95)),
]

var pending := {}
var filed := {}
var exposure := {}
var sample_time := 0.0
var radio_choices: Array[Dictionary] = []

func save_state() -> Dictionary:
	# JSON sorts dictionary keys. Keep the order in which Brandt saw things.
	return {"pending":pending.values().duplicate(true),"filed":filed.duplicate()}

func restore(data: Dictionary) -> void:
	pending.clear()
	for note: Dictionary in data.get("pending",[]):
		pending[note.key] = note.duplicate()
	filed = data.get("filed",{}).duplicate()
	exposure.clear()
	sample_time = 0.0
	_rebuild_choices()

func options() -> Array[Dictionary]:
	return radio_choices

func _rebuild_choices() -> void:
	radio_choices = []
	var keys := pending.keys()
	keys.reverse()
	for key: String in keys:
		var note: Dictionary = pending[key]
		var label := Reports.label(note.kind)
		if not str(note.get("road","")).is_empty(): label += " · " + str(note.road)
		radio_choices.append({"key":key,"label":label})

func remember(note: Dictionary) -> void:
	var key: String = note.key
	if not filed.has(key) and not pending.has(key):
		pending[key] = note
		_rebuild_choices()

func file(key: String) -> Dictionary:
	var note: Dictionary = pending.get(key,{})
	if not note.is_empty():
		pending.erase(key)
		filed[key] = true
		_rebuild_choices()
	return note

func _note(key: String, kind: String, road := "", trace := "") -> Dictionary:
	return {"key":key,"kind":kind,"road":road,"trace":trace}

func _physical_sources(game, director) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for trace: String in director.aftermath:
		var entry: Dictionary = director.aftermath[trace]
		var source := _note(entry.observation_key,entry.id,entry.road,trace)
		sources.append({"note":source,"points":director.scene.remnant_evidence(trace)})
	var ticket: Dictionary = game.job
	var rig = game.rig
	if ticket.has("observation_key") and game.mode == "fieldwork" and rig.phase in ["scene","flared","cable","rigged"] and rig.special_work <= 0.0 and is_instance_valid(rig.car):
		var note := _note(ticket.observation_key,ticket.id,ticket.road,ticket.aftermath_key)
		sources.append({"note":note,"points":PackedVector3Array([rig.car.to_global(Vector3.UP*.85)])})
	var county = game.county
	var sites := {"survey_ring":county.hold_tripod_point(),"farm_ring":county.story_point("farm_ring")}
	if county.case_models.has("tou"): sites["tou_ring"] = county.story_point("tou")
	for kind: String in sites:
		sources.append({"note":_note(kind,kind),"points":PackedVector3Array([sites[kind]+Vector3.UP*.12])})
	return sources

func _in_view(camera: Camera3D, at: Vector3, reach: float, game) -> bool:
	var eye := camera.global_position
	if eye.distance_squared_to(at) > reach*reach or not camera.is_position_in_frustum(at):
		return false
	var screen := camera.get_viewport().get_visible_rect()
	# A fly-by at the very edge of the windshield isn't a good enough look.
	var focus := Rect2(screen.position+screen.size*Vector2(.15,.14),screen.size*Vector2(.70,.72))
	var pixel := camera.unproject_position(at)
	if not focus.has_point(pixel):
		return false
	if camera == game.world_view.get_camera_3d() and game.desk.surface.covers_world_point((pixel-screen.position)/screen.size):
		return false
	var start: Vector3 = game.rig.body.to_local(eye)
	var end: Vector3 = game.rig.body.to_local(at)
	for panel: AABB in TRUCK_PANELS:
		if panel.intersects_segment(start,end) != null: return false
	var ray := PhysicsRayQueryParameters3D.create(eye,at,1)
	return camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _visible(game, points: PackedVector3Array, reach: float, minimum := 1) -> bool:
	var camera: Camera3D = game.world_view.get_camera_3d()
	for at: Vector3 in points:
		if _in_view(camera,at,reach,game):
			minimum -= 1
			if minimum <= 0: return true
	return false

func _mirror_visible(game, points: PackedVector3Array) -> bool:
	if not game.rig.in_cab or game.rig.driving_view != "cab": return false
	for mirror: SubViewport in game.rig.body.mirrors:
		var camera := mirror.get_camera_3d()
		var mount: Node3D = camera.get_meta("mount")
		if not _visible(game,PackedVector3Array([mount.global_position]),4.): continue
		for at: Vector3 in points:
			if _in_view(camera,at,300.,game): return true
	return false

func _range(kind: String, game) -> float:
	if kind == "empty_oncoming": return preload("res://scripts/oncoming_sedan.gd").RECOGNITION
	if kind in SKY_LIGHTS: return 340.
	if kind in ["hoofprints","bootprints","woods_tracks","empty_ditch"]: return 15.
	if kind in ["green_circle","bare_ring","farm_ring","survey_ring","tou_ring","pressed_lines","roadside_tape"]: return 32.
	return minf(72.,game.county.storm_environment.fog_depth_end*.75)

func inspectable(game, director) -> Dictionary:
	if game.rig.in_cab or not is_instance_valid(director.scene): return {}
	var nearest := 6.0
	var choice := {}
	var camera: Camera3D = game.world_view.get_camera_3d()
	for source in _physical_sources(game,director):
		for at: Vector3 in source.points:
			if _in_view(camera,at,nearest,game):
				choice = source.note
				nearest = camera.global_position.distance_to(at)
	return choice

func _live_visible(game, director) -> bool:
	var scene = director.scene
	var kind: String = director.active
	var rig = game.rig
	if scene.intensity < .35: return false
	var camera: Camera3D = game.world_view.get_camera_3d()
	if kind == "empty_oncoming" and scene.actor.to_local(camera.global_position).z>.40: return false
	if kind in ["moving_moon","green_flash","storm_hole"]:
		if not scene.has_sensory_evidence(kind,rig.in_cab,false): return false
		# The sky shader places the moving glow here. The storm opens overhead.
		var sky := Vector3(lerpf(-.95,.95,scene.progress),.48,-.25).normalized()
		if kind == "storm_hole":
			sky = -camera.global_basis.z
			if sky.y < .62: return false
		return _visible(game,PackedVector3Array([camera.global_position+sky*220.]),230.)
	if kind in ["warm_air","thaw_glaze"]:
		if not rig.in_cab: return kind == "warm_air" and rig.warmth < .98
		var windshield: Vector3 = rig.body.to_global(Vector3(0,2.69,-1.65))
		return rig.driving_view == "cab" and _visible(game,PackedVector3Array([windshield]),3.)
	if kind == "compass_turns" and absf(angle_difference(deg_to_rad(rig._heading_degrees()),deg_to_rad(rig._compass_degrees()))) < .15:
		return false
	if kind == "missing_time" and not director.time_lost: return false
	if scene.has_sensory_evidence(kind,rig.in_cab,rig.electrical_fade > .1): return true
	var points: PackedVector3Array = scene.live_evidence(kind)
	var minimum := 2 if kind in SKY_LIGHTS or kind == "deer_line" else 1
	return _visible(game,points,_range(kind,game),minimum) or (kind == "mirror_follow" and _mirror_visible(game,points))

func _watch(note: Dictionary, step: float, next: Dictionary, needed := LOOK_TIME) -> void:
	var key: String = note.key
	if pending.has(key) or filed.has(key): return
	var duration := float(exposure.get(key,0.0))+step
	if duration >= needed:
		remember(note)
	else:
		next[key] = duration

func sample(dt: float, game, director) -> void:
	sample_time += dt
	if sample_time < SAMPLE_INTERVAL or not is_instance_valid(director.scene): return
	var step := minf(sample_time,.16)
	sample_time = 0.0
	var next := {}
	for source in _physical_sources(game,director):
		var note: Dictionary = source.note
		if pending.has(note.key) or filed.has(note.key): continue
		if _visible(game,source.points,_range(note.kind,game),3 if note.kind == "cow_ring" else 1):
			_watch(note,step,next)
	var kind: String = director.active
	# The field car, grass, etc. are actual persistent meshes from the start.
	# Walking up to that same car tomorrow must refer to the same observation.
	if not kind.is_empty() and not director.aftermath.has(kind):
		var note := _note("pass/%d/%s" % [director.drive,kind],kind,director.road)
		if not pending.has(note.key) and not filed.has(note.key) and _live_visible(game,director):
			var needed := .15 if kind == "green_flash" else (.21 if kind == "empty_oncoming" else LOOK_TIME)
			_watch(note,step,next,needed)
	# The lamps often accompany something else. A look up can establish the
	# lights without disclosing the car or tracks still down in the field.
	if not kind.is_empty() and kind not in SKY_LIGHTS:
		var lights_note := _note("lights/%d/%s" % [director.drive,kind],"road_lights",director.road)
		if not pending.has(lights_note.key) and not filed.has(lights_note.key) and _visible(game,director.scene.lamp_points(),340.,2):
			_watch(lights_note,step,next)
	for driver in game.rig.departures:
		if driver.departure_time <= 1.0 or driver.witness.visible: continue
		var car: Node3D = driver.car
		if not car.is_visible_in_tree() or car.position.distance_squared_to(driver.job_site) < .25: continue
		var note := _note("traffic/"+str(driver.identity.get("vin","")), "departing_car")
		if _visible(game,PackedVector3Array([car.to_global(Vector3.UP)]),_range(note.kind,game)):
			_watch(note,step,next,.45)
	var pickup: Node3D = game.casework.released_pickup
	if is_instance_valid(pickup) and game.casework.departure_distance > 1.0:
		if _visible(game,PackedVector3Array([pickup.to_global(Vector3.UP)]),60.):
			_watch(_note("released_pickup","released_pickup"),step,next,.45)
	if director.yard_turned:
		var turned := 0
		for i in mini(game.stored.size(),game.PARKING.size()):
			if game.stored[i] is Dictionary and game.stored[i].get("turned_north",false):
				var at: Vector3 = game.PARKING[i]
				at.y = game.county.ground_height(at.x,at.z)+1.0
				if _visible(game,PackedVector3Array([at]),36.): turned += 1
		if turned >= 2: _watch(_note("yard_turned","yard_turned"),step,next)
	exposure = next
