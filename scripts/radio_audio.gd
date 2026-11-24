extends Node

const Chatter := preload("res://scripts/dialogue_chatter.gd")
const FOLDER := "res://assets/audio/"
const EFFECT_LEVELS_DB := {"footstep": -24.0, "air_brake": -25.0, "reverse": -21.0}
var lines := {}
var chatter_streams := {}
var engines := {}
var samples := {}
var chatter := AudioStreamPlayer.new()
var effects: Array[AudioStreamPlayer] = []
var cursor := 0
var radio_tail := false
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
	add_child(chatter)
	chatter.finished.connect(_chatter_finished)
	for i in 7:
		var player := AudioStreamPlayer.new()
		add_child(player)
		effects.append(player)
	for id: String in ["wind","diesel","diesel_pull","heater","winch"]:
		var loop_player := AudioStreamPlayer.new()
		var stream = _sample(id).duplicate()
		stream.loop = true
		loop_player.stream = stream
		loop_player.volume_db = -55.0
		add_child(loop_player)
		if audible:
			loop_player.play()
		engines[id] = loop_player

func _sample(id: String) -> AudioStream:
	if not samples.has(id):
		samples[id] = load(FOLDER + id + ".mp3")
	return samples[id]

func say(id: String) -> void:
	var line: Array = lines[id]
	if not chatter_streams.has(id):
		chatter_streams[id] = Chatter.render(line[0], line[1])
	_play_chatter(line[0], chatter_streams[id])

func speak(who: String, words: String) -> void:
	# Generated tickets vary indefinitely. Keep only the utterance on the radio.
	_play_chatter(who, Chatter.render(who, words))

func _play_chatter(who: String, stream: AudioStream) -> void:
	radio_tail = who in ["DISPATCH","COUNTY PLOW"]
	chatter.bus = &"County radio" if radio_tail else &"Master"
	chatter.volume_db = -10.0 if radio_tail else -13.0
	chatter.stream = stream
	if audible:
		chatter.play()

func _chatter_finished() -> void:
	if radio_tail:
		effect("radio")

func effect(id: String) -> void:
	var aliases := {"flare":"footstep","cable_slip":"ratchet","hook":"ratchet","chock":"ratchet","winch_start":"lift"}
	var sample_id: String = aliases.get(id, id)
	if not ResourceLoader.exists(FOLDER + sample_id + ".mp3"):
		return
	var p := effects[cursor]
	cursor = (cursor + 1) % effects.size()
	p.stream = _sample(sample_id)
	p.volume_db = EFFECT_LEVELS_DB.get(id, -7.5)
	p.pitch_scale = 1.0 if id == "reverse" else randf_range(0.95,1.05)
	if audible:
		p.play()

func mix_truck(s: Dictionary, player_active: bool, controls_live: bool, delta: float, gust: float = 0.0) -> void:
	var cab: bool = s.get("in_cab",true)
	var wind_db := (-28.0 if cab else -15.0) if player_active else -21.0
	_volume("wind", wind_db + gust * (4.0 if cab and player_active else 6.0), delta)
	_volume("heater", -29.0 if cab and player_active else -65.0, delta)
	_volume("winch", -13.0 if s.get("working",false) and player_active else -65.0, delta)
	engines.winch.pitch_scale = 0.80 + 0.56 * float(s.get("tension",0.0))

	var driving := controls_live and cab
	var rpm: float = s.engine_rpm if driving else 680.0
	var load_fraction: float = s.engine_load if driving else 0.0
	var road_speed := absf(s.speed_mps) if driving else 0.0
	var blend := maxf(load_fraction, smoothstep(0.15, 3.2, road_speed))
	var running := player_active and float(s.fuel) > 0.0
	var idle_gain := db_to_linear(-18.0 if cab else -23.0) * (1.0 - blend)
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
