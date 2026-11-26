extends Node3D
## Exterior acoustics of the drum, PTO and tackle in the game's 3D world.
const BUS := &"Recovery equipment"
const FOLDER := "res://assets/audio/"
const EVENT := {
	"flare":"flare_strike","cable_slip":"rope_slip","ratchet":"strap_ratchet",
	"hook":"shackle_pin","chock":"drum_clutch","winch_start":"drum_clutch","lift":"hydraulic_valve",
}
const LEVEL := {
	"flare_strike":-7.,"rope_slip":-6.,"strap_ratchet":-13.,"shackle_pin":-12.,"drum_clutch":-14.,
	"hydraulic_valve":-12.,"drum_under_load":-13.,"hydraulic_pump":-15.,"rope_payout":-13.,"flare_burn":-20.,
}
var audible := DisplayServer.get_name() != "headless"
var filter: AudioEffectLowPassFilter
var motor: AudioStreamPlayer3D
var burning: AudioStreamPlayer3D
var impacts: Array[AudioStreamPlayer3D] = []
var cursor := 0
var leader := 0.
var payout_hold := 0.
var previous_job := 0
var mode := ""
var storm_hush := 0.
var streams := {}
var rig

func mount(operator) -> void:
	rig = operator
	rig.add_child(self)
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,BUS)
		filter = AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 19000.
		AudioServer.add_bus_effect(bus,filter)
	else: filter = AudioServer.get_bus_effect(bus,0)
	motor = voice()
	burning = voice()
	burning.stream = sample("flare_burn")
	for i in 4: impacts.append(voice())

func voice() -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	source.panning_strength = .95
	source.attenuation_filter_cutoff_hz = 20500.
	source.volume_db = -80.
	source.bus = BUS
	add_child(source)
	return source

func sample(id: String) -> AudioStreamWAV:
	if not streams.has(id):
		streams[id] = load(FOLDER+id+".wav")
	return streams[id]

func operator_position() -> Vector3:
	return rig.body.to_global(rig.Truck.EYE) if rig.in_cab else rig.foot+Vector3.UP*1.5

func gain(id: String, source: Vector3, inside_store: bool) -> float:
	var distance := source.distance_to(operator_position())
	var enclosure := 0.
	if rig.in_cab: enclosure = -8. if rig.climate.cracked else -20.
	elif inside_store: enclosure = -23.
	# The physical driver's seat remains the listening point in chase view.
	var strength := (1.-smoothstep(48.,94.,distance))/(1.+distance/7.5)
	return maxf(-80.,float(LEVEL[id])+linear_to_db(maxf(.00001,strength))+enclosure-storm_hush*68.)

func effect(id: String, inside_store := false) -> bool:
	if not EVENT.has(id): return false
	var sound: String = EVENT[id]
	var point: Vector3 = operator_position()-Vector3.UP*.53
	match id:
		"flare":
			if is_instance_valid(rig.flame): point = rig.flame.global_position+Vector3.UP*.12
		"cable_slip","chock","winch_start","lift":
			point = rig._drum() if id in ["cable_slip","winch_start"] else rig._panel()
			if id=="winch_start" and rig._boom_job() and rig.special_work<1.: sound = "hydraulic_valve"
		"hook":
			if rig.car and rig.phase == "rigged": point = rig._eyelet(rig.line_end)
	var impact := impacts[cursor]
	cursor = (cursor+1) % impacts.size()
	impact.stop()
	impact.stream = sample(sound)
	impact.global_position = point
	impact.set_meta("source_id",sound)
	impact.volume_db = gain(sound,point,inside_store)
	impact.pitch_scale = randf_range(.96,1.04)
	if audible: impact.play()
	return true

func motion(dt: float) -> String:
	var free_hook: bool = rig.phase == "cable" and not rig.in_cab and not rig._boom_job()
	if free_hook:
		var job: int = rig.car.get_instance_id() if rig.car else 0
		var extension: float = rig._drum().distance_to(rig.foot+Vector3.UP*1.22)
		if job != previous_job:
			previous_job = job
			leader = extension
		if extension > leader+.013:
			leader = extension
			payout_hold = .13
		else: payout_hold = maxf(0.,payout_hold-dt)
	else:
		previous_job = 0
		payout_hold = 0.
	if rig.rollback_active and rig.rollback_deck.motion not in ["","pay"] and rig.fuel>0.: return "hydraulic_pump"
	if rig.working:
		if rig.rollback_active and rig.rollback_deck.motion=="pay": return "rope_payout"
		if rig._boom_job() and rig.special_work<1.: return "hydraulic_pump"
		return "drum_under_load"
	return "rope_payout" if payout_hold>0. else ""

func loop_at(player: AudioStreamPlayer3D, id: String, point: Vector3, requested: bool, dt: float, inside_store: bool) -> void:
	var db := -80.
	if requested:
		player.global_position = point
		db = gain(id,point,inside_store)
		if player.stream != sample(id):
			player.stop()
			player.stream = sample(id)
			player.volume_db = -55.
		if audible and not player.playing and db > -65.: player.play()
	player.volume_db = move_toward(player.volume_db,db,dt*112.)
	if player.playing and db < -65. and player.volume_db <= -65.: player.stop()

func mix(active: bool, inside_store: bool, dt: float, calm := 0.) -> void:
	storm_hush = clampf(calm,0.,1.)
	var cutoff := 19000.
	if rig.in_cab: cutoff = 5100. if rig.climate.cracked else 1180.
	elif inside_store: cutoff = 940.
	filter.cutoff_hz = lerpf(filter.cutoff_hz,cutoff,1.-exp(-dt*9.))
	for impact in impacts:
		if impact.playing:
			impact.volume_db = gain(impact.get_meta("source_id"),impact.global_position,inside_store) if active else -80.
	mode = motion(dt) if active else ""
	var point: Vector3 = rig._drum()
	if mode == "hydraulic_pump":
		point = rig._panel()
		motor.pitch_scale = .86 if rig.rollback_active else 1.08
	elif mode == "rope_payout": motor.pitch_scale = .83 if rig.rollback_active and rig.rollback_deck.unloading else 1.0
	else: motor.pitch_scale = .79+.61*float(rig.tension)
	loop_at(motor,mode,point,not mode.is_empty(),dt,inside_store)
	var lit: bool = active and is_instance_valid(rig.flame)
	var at: Vector3 = rig.flame.global_position+Vector3.UP*.16 if lit else Vector3.ZERO
	loop_at(burning,"flare_burn",at,lit,dt,inside_store)

func _exit_tree() -> void:
	for source: AudioStreamPlayer3D in impacts + [motor,burning]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
