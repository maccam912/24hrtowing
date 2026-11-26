extends Node3D
## The pumps, spillway, furnace and cooler stay at their physical sources, even in chase view.

const Bay := preload("res://scripts/county_bay.gd")
const SITES := {
	"dairy":{"point":Vector3(93,2,430), "near":10., "reach":135., "db":-8., "sound":preload("res://assets/audio/dairy_pump.wav")},
	"dam":{"point":Vector3(-472,.8,-95), "near":20., "reach":165., "db":-5., "sound":preload("res://assets/audio/dam_spillway.wav")},
	"yard":{"point":Bay.FURNACE, "near":4., "reach":36., "db":-11., "sound":preload("res://assets/audio/bay_furnace.wav")},
	"cooler":{"point":Vector3(-73.83,1.29,29.30), "near":2., "reach":12., "db":-13., "sound":preload("res://assets/audio/store_cooler.wav")},
}
var sources := {}
var audible := DisplayServer.get_name() != "headless"

func _ready() -> void:
	for id: String in SITES:
		var speaker := AudioStreamPlayer3D.new()
		speaker.name = id
		speaker.position = SITES[id].point
		speaker.stream = SITES[id].sound
		# The listener is the operator. The camera only supplies stereo orientation.
		speaker.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		speaker.panning_strength = .72
		speaker.volume_db = -80.
		add_child(speaker)
		sources[id] = speaker

func mix(at: Vector3, in_cab: bool, in_store: bool, calm: float, active: bool, dt: float) -> void:
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		var speaker: AudioStreamPlayer3D = sources[id]
		var gain := 0.0
		var distance := at.distance_to(site.point)
		if active and distance < float(site.reach):
			gain = db_to_linear(site.db) * (1. - smoothstep(site.near,site.reach,distance))
			if id == "cooler":
				if not in_store: gain *= .12
			elif in_cab or in_store:
				gain *= .20 if in_cab else .08
			gain *= 1. - calm
		var target := maxf(-80.,linear_to_db(gain))
		speaker.volume_db = move_toward(speaker.volume_db,target,dt*76.)
		if audible and gain > .0005 and not speaker.playing:
			speaker.play()
		elif gain <= .0005 and speaker.volume_db <= -65. and speaker.playing:
			speaker.stop()

func _exit_tree() -> void:
	for speaker: AudioStreamPlayer3D in sources.values():
		speaker.stop()
		speaker.stream = null
