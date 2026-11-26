extends Node
## Two local broadcasts on the truck's receive-only AM/FM set.
const TOWER := Vector2(905,44)
const STATIONS := {
	"am":{"dial":"760 AM","name":"Esker Farm Service"},
	"fm":{"dial":"99.7 FM","name":"Tamarack Country"},
}
var station := "off"
var elapsed := 0.0
var signal_strength := 0.0
var can_hear := false
var interrupted := false
var programs := {}
var program := AudioStreamPlayer.new()
var hiss := AudioStreamPlayer.new()
var cue := {}
var audible := DisplayServer.get_name() != "headless"

func _ready() -> void:
	programs = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/radio_programs.json"))
	add_child(program)
	add_child(hiss)
	hiss.volume_db = -80

func tune(id: String) -> bool:
	if station == id or (id != "off" and not STATIONS.has(id)):
		return false
	station = id
	program.stop()
	program.stream = null
	hiss.stop()
	can_hear = false
	cue = {}
	return true

func _select_stream() -> void:
	# Load just the selected program. Mono MP3s stay compressed on the phone.
	program.stream = load("res://assets/audio/broadcast_"+station+".mp3")
	if not hiss.stream:
		var sample := AudioStreamWAV.new()
		sample.format = AudioStreamWAV.FORMAT_16_BITS
		sample.mix_rate = 11025
		var pcm := PackedByteArray()
		pcm.resize(sample.mix_rate*2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 997
		var last := 0.0
		for i in sample.mix_rate:
			var noise := rng.randf_range(-1,1)
			pcm.encode_s16(i*2,roundi((noise-last)*11200))
			last = noise
		sample.data = pcm
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_end = sample.mix_rate
		hiss.stream = sample

func advance(dt: float, game) -> void:
	var running: bool = game.active and not game.desk.is_title() and game.desk.page not in ["pause","options","help","guidance","yard_recovery"]
	if running: elapsed += dt
	can_hear = running and game.rig.in_cab and STATIONS.has(station)
	interrupted = game.sub_time > 0 or game.audio.voice_busy()
	if not can_hear:
		if program.playing: program.stop()
		if hiss.playing: hiss.stop()
		return
	var at: Vector3 = game.rig.get_truck_position()
	var miles := Vector2(at.x,at.z).distance_to(TOWER)
	signal_strength = 1.0 - (.70 * smoothstep(330.,1950.,miles) if station == "am" else .86 * smoothstep(260.,1610.,miles))
	signal_strength *= 1.0 - smoothstep(.12,.78,game.audio.pulse)
	var show: Dictionary = programs[station]
	var playhead := fposmod(elapsed,float(show.duration))
	for item: Dictionary in show.cues:
		if float(item.start) > playhead: break
		cue = item
	if not program.stream: _select_stream()
	if audible and not program.playing:
		program.volume_db = -80.
		program.play(playhead)
		if not hiss.playing: hiss.play()
	# Rapid channel priority keeps even the first syllable of Arlene's call clear.
	var program_db := -80. if interrupted else -10. + linear_to_db(maxf(.0003,signal_strength))
	var hiss_gain := 0.0 if interrupted else .005+.105*(1.-signal_strength)
	var fade := dt * (650. if interrupted else 115.)
	program.volume_db = move_toward(program.volume_db,maxf(-80.,program_db),fade)
	hiss.volume_db = move_toward(hiss.volume_db,maxf(-80.,linear_to_db(hiss_gain)),fade)

func caption() -> String:
	if not can_hear or interrupted or signal_strength < .20: return ""
	return cue.get("words","")

func save_state() -> Dictionary:
	return {"station":station,"elapsed":elapsed}

func restore(saved: Dictionary) -> void:
	var id := str(saved.get("station","off"))
	tune(id if STATIONS.has(id) else "off")
	elapsed = maxf(0.,float(saved.get("elapsed",0.)))
	program.stop()
	hiss.stop()
	cue = {}
	can_hear = false
