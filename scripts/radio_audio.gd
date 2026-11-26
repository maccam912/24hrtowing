extends Node

const Speech := preload("res://scripts/county_speech.gd")
const Chatter := preload("res://scripts/dialogue_chatter.gd")
const FOLDER := "res://assets/audio/"
const EFFECT_LEVELS_DB := {"footstep": -24.0, "air_brake": -25.0, "reverse": -21.0}
var lines := {}
var chatter_streams := {}
var engines := {}
var samples := {}
var chatter := AudioStreamPlayer.new()
const Recovery := preload("res://scripts/recovery_audio.gd")
var recovery: Recovery
var parked_diesel: AudioStreamPlayer3D
var wind_filter: AudioEffectLowPassFilter
var effects: Array[AudioStreamPlayer] = []
var cursor := 0
var radio_tail := false
var scanner_voice := false
var spoken := false
var native_voices := PackedStringArray()
var utterance := 0
var calm := 0.0
var pulse := 0.0
var audible := DisplayServer.get_name() != "headless"

func _ready() -> void:
	lines = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "lines.json"))
	var radio_bus := AudioServer.get_bus_index("County radio")
	if radio_bus < 0:
		AudioServer.add_bus()
		radio_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(radio_bus, "County radio")
		var lo := AudioEffectHighPassFilter.new()
		lo.cutoff_hz = 360.0
		var hi := AudioEffectLowPassFilter.new()
		hi.cutoff_hz = 3000.0
		AudioServer.add_bus_effect(radio_bus, lo)
		AudioServer.add_bus_effect(radio_bus, hi)
	var wind_bus := AudioServer.get_bus_index("Outside wind")
	if wind_bus < 0:
		AudioServer.add_bus()
		wind_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(wind_bus,"Outside wind")
		wind_filter = AudioEffectLowPassFilter.new()
		wind_filter.cutoff_hz = 7800.
		AudioServer.add_bus_effect(wind_bus,wind_filter)
	else:
		wind_filter = AudioServer.get_bus_effect(wind_bus,0)
	add_child(chatter)
	chatter.finished.connect(_chatter_finished)
	for i in 7:
		var player := AudioStreamPlayer.new()
		add_child(player)
		effects.append(player)
	var receiver := AudioStreamPlayer.new()
	receiver.stream = Chatter.radio_pulse()
	receiver.bus = &"County radio"
	receiver.volume_db = -80
	add_child(receiver)
	engines.pulse = receiver
	if audible: receiver.play()
	for id: String in ["wind","diesel","diesel_pull","heater"]:
		var loop_player := AudioStreamPlayer.new()
		var stream = _sample(id).duplicate()
		stream.loop = true
		loop_player.stream = stream
		if id == "wind": loop_player.bus = &"Outside wind"
		loop_player.volume_db = -55.0
		add_child(loop_player)
		if audible:
			loop_player.play()
		engines[id] = loop_player

func mount_recovery(rig) -> void:
	recovery = Recovery.new()
	recovery.mount(rig)

func mount_diesel(truck: Node3D) -> void:
	parked_diesel = AudioStreamPlayer3D.new()
	parked_diesel.position = Vector3(0,1.12,-2.45)
	parked_diesel.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	parked_diesel.panning_strength = .85
	parked_diesel.volume_db = -80.
	parked_diesel.pitch_scale = 680./740.
	truck.add_child(parked_diesel)

func set_sighting(wind_calm: float, radio_interference: float) -> void:
	calm = clampf(wind_calm,0,1)
	pulse = clampf(radio_interference,0,1)

func set_spoken(enabled: bool) -> void:
	spoken = enabled
	if not audible: return
	if spoken:
		native_voices = DisplayServer.tts_get_voices_for_language("en")
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED,_spoken_finished)
	else:
		if utterance > 0: DisplayServer.tts_stop()

func voice_busy() -> bool:
	return chatter.playing or (audible and spoken and utterance > 0 and DisplayServer.tts_is_speaking())

func stop_scanner() -> void:
	if not scanner_voice:
		return
	scanner_voice = false
	radio_tail = false
	chatter.stop()
	if audible and spoken and utterance > 0:
		utterance += 1
		DisplayServer.tts_stop()

func _try_spoken(who: String, words: String) -> bool:
	if not spoken or native_voices.is_empty():
		return false
	chatter.stop()
	radio_tail = scanner_voice or who in ["DISPATCH","COUNTY PLOW"]
	utterance += 1
	var pitch: float = clampf(float(Chatter.SPEAKER_HZ.get(who,320))/320,.78,1.16)
	var voice := native_voices[posmod(who.hash(),native_voices.size())]
	DisplayServer.tts_speak(Speech.read_aloud(words),voice,84,pitch,.95,utterance,true)
	return true

func _spoken_finished(id: int) -> void:
	if id == utterance and spoken:
		_chatter_finished()

func _exit_tree() -> void:
	if audible and utterance > 0: DisplayServer.tts_stop()
	if is_instance_valid(parked_diesel):
		parked_diesel.stop()
		parked_diesel.stream = null

func _sample(id: String) -> AudioStream:
	if not samples.has(id):
		samples[id] = load(FOLDER + id + ".mp3")
	return samples[id]

func say(id: String) -> void:
	scanner_voice = false
	var line: Array = lines[id]
	if _try_spoken(line[0],line[1]): return
	if not chatter_streams.has(id):
		chatter_streams[id] = Chatter.render(line[0], line[1])
	_play_chatter(line[0], chatter_streams[id])

func speak(who: String, words: String, from_scanner := false) -> void:
	scanner_voice = from_scanner
	if _try_spoken(who,words): return
	# Generated tickets vary indefinitely. Keep only the utterance on the radio.
	_play_chatter(who, Chatter.render(who, words))

func _play_chatter(who: String, stream: AudioStream) -> void:
	radio_tail = scanner_voice or who in ["DISPATCH","COUNTY PLOW"]
	chatter.bus = &"County radio" if radio_tail else &"Master"
	chatter.volume_db = -15.0 if scanner_voice else (-10.0 if radio_tail else -13.0)
	chatter.stream = stream
	if audible:
		chatter.play()

func _chatter_finished() -> void:
	scanner_voice = false
	if radio_tail:
		radio_tail = false
		effect("radio")

func rig_effect(id: String) -> void:
	if not recovery or not recovery.effect(id): effect(id)

func effect(id: String) -> void:
	var sample_id := id
	if not ResourceLoader.exists(FOLDER + sample_id + ".mp3"):
		return
	var p := effects[cursor]
	cursor = (cursor + 1) % effects.size()
	p.stream = _sample(sample_id)
	p.volume_db = EFFECT_LEVELS_DB.get(id, -7.5)
	p.pitch_scale = 1.0 if id == "reverse" else randf_range(0.95,1.05)
	if audible:
		p.play()

func mix_truck(s: Dictionary, player_active: bool, controls_live: bool, delta: float, gust: float = 0.0,
		in_store := false, truck_distance := 0.0) -> void:
	var cab: bool = s.get("in_cab",true)
	var wind_db := -21.0
	var cutoff := 7800.0
	if player_active:
		wind_db = -15.0
		if cab or in_store:
			wind_db = -37.0 if in_store else -28.0
			cutoff = 610.0 if in_store else 1150.0
	if cab and player_active and s.get("window_open",false):
		wind_db = -22.0
		cutoff = 4200.0
	wind_filter.cutoff_hz = lerpf(wind_filter.cutoff_hz,cutoff,1.0 - exp(-delta * 6.0))
	_volume("wind", lerpf(wind_db + gust * (4.0 if cab and player_active else 6.0),-76.0,calm), delta)
	var signal_level := pulse if cab and controls_live else 0.0
	if radio_tail and voice_busy(): signal_level = 0.0
	_volume("pulse",linear_to_db(maxf(.0001,signal_level*.42)),delta)
	var blower := int(s.get("blower",1))
	var heater_db := -65.0
	if cab and player_active and blower > 0 and float(s.fuel) > 0:
		heater_db = lerpf(-23.0,-29.0,float(s.get("warmth",1.0))) + (5.0 if blower == 2 else 0.0)
	engines.heater.pitch_scale = 1.16 if blower == 2 else .95
	_volume("heater",heater_db,delta)
	if is_instance_valid(recovery): recovery.mix(player_active and controls_live,in_store,delta,calm)

	var driving := controls_live and cab
	var rpm: float = s.engine_rpm if driving else 680.0
	var load_fraction: float = s.engine_load if driving else 0.0
	var road_speed := absf(s.speed_mps) if driving else 0.0
	var blend := maxf(load_fraction, smoothstep(0.15, 3.2, road_speed))
	var running := player_active and float(s.fuel) > 0.0
	var idle_gain := db_to_linear(-18.0) * (1.0 - blend) if cab else 0.0
	if is_instance_valid(parked_diesel):
		var outdoors := 0.0
		if running and not cab:
			outdoors = db_to_linear(-23.) * (1.0 - smoothstep(52.0,110.0,truck_distance)) / (1.0 + truck_distance / 14.0)
			if in_store: outdoors *= .26
		parked_diesel.volume_db = move_toward(parked_diesel.volume_db,maxf(-80.,linear_to_db(outdoors)),delta*96.)
		if outdoors > .0005 and audible and not parked_diesel.playing:
			if parked_diesel.stream == null: parked_diesel.stream = engines.diesel.stream
			parked_diesel.play(engines.diesel.get_playback_position())
		elif outdoors <= .0005 and parked_diesel.volume_db <= -65. and parked_diesel.playing:
			parked_diesel.stop()
	var pull_gain := db_to_linear(lerpf(-18.0, -5.0, load_fraction)) * blend
	# Smooth linear amplitudes so the exhaust responds even on the first gas tap.
	var response := 1.0 - exp(-8.0 * delta)
	var idle: AudioStreamPlayer = engines.diesel
	var pull: AudioStreamPlayer = engines.diesel_pull
	idle.volume_linear = lerpf(idle.volume_linear, idle_gain if running else 0.0, response)
	pull.volume_linear = lerpf(pull.volume_linear, pull_gain if running else 0.0, response)
	idle.pitch_scale = clampf(rpm / 740.0, 0.9, 1.35)
	pull.pitch_scale = clampf(rpm / 1550.0, 0.5, 1.5)

func _volume(id: String, target: float, delta: float) -> void:
	var p: AudioStreamPlayer = engines[id]
	p.volume_db = move_toward(p.volume_db, target, delta*48.0)
