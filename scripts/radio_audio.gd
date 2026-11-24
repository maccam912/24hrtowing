extends Node

const FOLDER := "res://assets/audio/"
var voices := {}
var engines := {}
var samples := {}
var speech := AudioStreamPlayer.new()
var effects: Array[AudioStreamPlayer] = []
var cursor := 0
var radio_tail := false
var audible := DisplayServer.get_name() != "headless"

func _ready() -> void:
	voices = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "lines.json"))
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
	add_child(speech)
	speech.finished.connect(_speech_finished)
	for i in 7:
		var player := AudioStreamPlayer.new()
		add_child(player)
		effects.append(player)
	for id: String in ["wind","diesel","heater","winch"]:
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

func say(id: String) -> float:
	if not voices.has(id):
		return 0.0
	var stream := _sample(id)
	radio_tail = voices[id][0] in ["DISPATCH","COUNTY PLOW"]
	speech.bus = &"County radio" if radio_tail else &"Master"
	speech.volume_db = -1.5 if radio_tail else -3.0
	speech.stream = stream
	if audible:
		speech.play()
	return stream.get_length()

func _speech_finished() -> void:
	if radio_tail:
		effect("radio")

func effect(id: String) -> void:
	if not audible:
		return
	var aliases := {"flare":"footstep","cable_slip":"ratchet","hook":"ratchet","chock":"ratchet","winch_start":"lift"}
	var sample_id: String = aliases.get(id, id)
	if not ResourceLoader.exists(FOLDER + sample_id + ".mp3"):
		return
	var p := effects[cursor]
	cursor = (cursor + 1) % effects.size()
	p.stream = _sample(sample_id)
	p.volume_db = -15.0 if id in ["footstep","reverse"] else -7.5
	p.pitch_scale = randf_range(0.95,1.05)
	p.play()

func mix_truck(s: Dictionary, player_active: bool, delta: float) -> void:
	var cab: bool = s.get("in_cab",true)
	_volume("wind", (-27.0 if cab else -12.0) if player_active else -19.0, delta)
	_volume("diesel", (-18.0 if cab else -23.0) if player_active else -58.0, delta)
	_volume("heater", -29.0 if cab and player_active else -65.0, delta)
	_volume("winch", -13.0 if s.get("working",false) and player_active else -65.0, delta)
	engines.diesel.pitch_scale = lerpf(0.87,1.65,minf(absf(s.get("speed_mph",0.0))/37.0,1.0))
	engines.winch.pitch_scale = 0.80 + 0.56 * float(s.get("tension",0.0))

func _volume(id: String, target: float, delta: float) -> void:
	var p: AudioStreamPlayer = engines[id]
	p.volume_db = move_toward(p.volume_db, target, delta*48.0)
