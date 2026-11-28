extends Node3D
## The pumps, spillway, furnace and cooler stay at their physical sources, even in chase view.

const Fittings := preload("res://scripts/yard_fittings.gd")
const Bay := preload("res://scripts/county_bay.gd")
const SITES := {
	"dairy":{"point":Vector3(93,2,430), "near":10., "reach":135., "db":-8., "sound":preload("res://assets/audio/dairy_pump.wav")},
	"dam":{"point":Vector3(-472,.8,-95), "near":20., "reach":165., "db":-5., "sound":preload("res://assets/audio/dam_spillway.wav")},
	"yard":{"point":Bay.FURNACE, "near":4., "reach":36., "db":-11., "sound":preload("res://assets/audio/bay_furnace.wav")},
	"cooler":{"point":Vector3(-73.83,1.29,29.30), "near":2., "reach":12., "db":-13., "sound":preload("res://assets/audio/store_cooler.wav")},
	"office":{"point":Fittings.OFFICE_TUBES, "near":1.2, "reach":8.3, "db":-18., "sound":preload("res://assets/audio/office_tubes.wav")},
	"brewer":{"point":Fittings.COFFEE, "near":1.5, "reach":8., "db":-10., "sound":preload("res://assets/audio/coffee_brew.wav")},
	"pour":{"point":Fittings.COFFEE+Vector3(.46,0,-.09), "near":1.5, "reach":7., "db":-7., "sound":preload("res://assets/audio/coffee_pour.wav")},
}
var brewer_fitted := false
var activity := {"brewer":-1., "pour":-1.}
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

func set_brewer(fitted: bool) -> void:
	if brewer_fitted == fitted: return
	brewer_fitted = fitted
	activity.brewer = 0. if fitted else -1.
	activity.pour = -1.

func pour_coffee() -> void:
	if brewer_fitted: activity.pour = 0.

func mix(at: Vector3, in_cab: bool, in_store: bool, calm: float, active: bool, dt: float, paperwork_open := false) -> void:
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		var speaker: AudioStreamPlayer3D = sources[id]
		var playing := active
		var offset := 0.
		if activity.has(id):
			offset = float(activity[id])
			playing = active and offset >= 0.
			if playing:
				activity[id] = offset+dt
				if float(activity[id]) >= speaker.stream.get_length():
					activity[id] = -1.
					if id=="pour" and activity.brewer<0.: activity.brewer = 0.
		var gain := 0.0
		var distance := at.distance_to(site.point)
		if playing and distance < float(site.reach):
			gain = db_to_linear(site.db) * (1. - smoothstep(site.near,site.reach,distance))
			if id == "cooler":
				if not in_store: gain *= .12
			elif in_cab or in_store:
				gain *= .20 if in_cab else .08
			if paperwork_open and id in ["office","yard"]:
				gain *= .38
			gain *= 1. - calm
		var target := maxf(-80.,linear_to_db(gain))
		if activity.has(id):
			# A carafe pick-up and the first drop have short attacks.
			var level := lerpf(speaker.volume_linear,gain,1.-exp(-28.*dt))
			speaker.volume_db = maxf(-80.,linear_to_db(level))
		else:
			speaker.volume_db = move_toward(speaker.volume_db,target,dt*76.)
		if audible and gain > .0005 and not speaker.playing:
			speaker.play(offset)
		elif gain <= .0005 and speaker.volume_db <= -65. and speaker.playing:
			speaker.stop()

func _exit_tree() -> void:
	for speaker: AudioStreamPlayer3D in sources.values():
		speaker.stop()
		speaker.stream = null
