extends RefCounted
## The tandem chains, windshield linkage and exhaust have separate moving sources.
const County := preload("res://scripts/county.gd")
const LINK_TRAVEL := TAU*.59/12. # Twelve crosslinks per revolution of a drive tire.
const FAST_CHAIN_SPEED := LINK_TRAVEL*18.
var chains: AudioStreamPlayer3D
var horn: AudioStreamPlayer3D
var blade: AudioStreamPlayer3D
var exhaust: AudioStreamPlayer3D
var previous_odo := -1.
var link_travel := 0.
var surface := 0.
var surface_timer := 0.
var wiper_turn := -1

func mount(field) -> void:
	chains = field.voice()
	horn = field.voice()
	blade = field.voice()
	exhaust = field.voice()

func pavement(rig, contact: Vector3) -> float:
	var distance: float = rig._road(contact)
	# The two unsealed access lanes are included in the county's route graph.
	if absf(contact.x-County.CaseSites.ALDER_X)<5.5 and contact.z < -404.: return 0.
	if absf(contact.z-County.HOFFMANN_LANE_END.y)<5.5 and contact.x > 405. and contact.x < County.HOFFMANN_LANE_END.x+3.: return 0.
	if distance>5. and rig.world.has_method("_distance_from_lot"):
		distance = minf(distance,float(rig.world._distance_from_lot(contact.x,contact.z))+4.25)
	return 1.-smoothstep(4.65,6.20,distance)

func mix(field, rig, active: bool, inside_store: bool, dt: float) -> void:
	mix_horn(field,rig,active,inside_store,dt)
	var axle: Vector3 = rig.body.to_global(Vector3(0,.50,rig.Truck.REAR_AXLE_Z))
	var travel := 0.
	if previous_odo >= 0.:
		travel = minf(absf(float(rig.odo)-previous_odo)*rig.GAME_MILE,dt*21.)
	previous_odo = rig.odo
	var speed := absf(float(rig.speed))
	var fitted: bool = active and rig.tire_chains and speed>.10
	if fitted:
		surface_timer -= dt
		if surface_timer<=0.:
			surface = pavement(rig,axle)
			surface_timer = .075
	else:
		surface = 0.
		surface_timer = 0.
		link_travel = 0.
	if fitted and surface>.015 and speed<2.25:
		link_travel += travel
		if link_travel >= LINK_TRAVEL:
			link_travel = fmod(link_travel,LINK_TRAVEL)
			chains.stop()
			chains.stream = field.sample("chain_link")
			chains.pitch_scale = .89+randf()*.18
			chains.global_position = axle
			chains.volume_db = field.gain("chain_link",axle,inside_store)+linear_to_db(surface)
			if field.audible: chains.play()
		elif chains.stream != field.sample("chain_link"):
			chains.stop()
	else:
		var rolling: bool = fitted and surface>.015 and speed>=2.25
		chains.pitch_scale = clampf(speed/FAST_CHAIN_SPEED,.40,3.35)
		field.loop_at(chains,"chains_pavement",axle,rolling,dt,inside_store,linear_to_db(maxf(.001,surface)))
		link_travel = 0.
	var wipe_at: Vector3 = rig.body.to_global(Vector3(-.29,2.42,-1.68))
	blade.global_position = wipe_at
	var turn := floori(float(rig.body.elapsed)/3.6)
	var window := fmod(float(rig.body.elapsed),3.6)
	if active and window<.96:
		blade.volume_db = field.gain("wiper_sweep",wipe_at,inside_store)
		if turn != wiper_turn:
			wiper_turn = turn
			blade.stream = field.sample("wiper_sweep")
			if field.audible and blade.volume_db> -65.: blade.play(window)
	else:
		if not active: wiper_turn = -1
		if blade.playing and (not active or window>1.02): blade.stop()
	var pipe: Vector3 = rig.body.to_global(Vector3(.97,3.25,.06))
	var load:float = rig.compression_brake
	exhaust.pitch_scale = clampf(float(rig.engine_rpm)/1320.,.61,1.75)
	field.loop_at(exhaust,"exhaust_brake",pipe,active and rig.in_cab and load>.015,dt,inside_store,linear_to_db(maxf(.001,load)))

func mix_horn(field, rig, active: bool, inside_store: bool, dt: float) -> void:
	var sounding: bool = active and rig.in_cab and (rig.horn_held or rig.horn_tap>0.)
	if not sounding and horn.volume_db<=-79.9: return
	var target_db := -80.
	if sounding:
		horn.global_position = rig.body.to_global(Vector3(-.76,3.39,-.90))
		target_db = field.gain("truck_horn",horn.global_position,inside_store)
		if not horn.stream: horn.stream = field.sample("truck_horn")
		if field.audible and not horn.playing:
			horn.volume_db = target_db-16.
			horn.play()
	horn.volume_db = move_toward(horn.volume_db,target_db,dt*(620. if sounding else 460.))
	if horn.playing and not sounding and horn.volume_db<=-65.: horn.stop()
