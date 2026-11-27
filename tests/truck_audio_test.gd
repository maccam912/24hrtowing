extends SceneTree

const DT := 1.0 / 60.0
var game
var failed := false
var cues: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("CHECK FAILED: ",message)

func ticks(count: int) -> void:
	for i in count:
		game._physics_process(DT)

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.desk._activate("play")
	game.rig.sound_event.connect(func(id: String): cues.append(id))
	game.rig.set_spawn(Vector3(-2,0,60),PI)
	var pull: AudioStreamPlayer = game.audio.engines.diesel_pull
	var idle: AudioStreamPlayer = game.audio.engines.diesel
	ticks(60)
	check(idle.volume_db > -20 and pull.volume_db < -60, "parked truck plays the idle layer")
	game.desk.stick = Vector2.UP
	ticks(30)
	check(game.rig.speed > 0 and pull.volume_db > -12, "the exhaust comes in on the gas at yard speed")
	var shifted := false
	for i in 360:
		var gear: int = game.rig.drive_gear
		var pitch_before := pull.pitch_scale
		ticks(1)
		if game.rig.drive_gear > gear:
			ticks(12)
			shifted = pull.pitch_scale < pitch_before - .09
			break
	check(shifted, "the audible engine revs fall on the first upshift")
	var on_gas := pull.volume_db
	game.desk.stick = Vector2.ZERO
	ticks(30)
	check(game.rig.speed > 2 and pull.volume_db < on_gas - 8, "lifting the pedal softens the exhaust while still rolling")
	game.desk.stick = Vector2.UP
	ticks(60)
	game.desk.toggle_pause()
	ticks(60)
	check(pull.volume_db < -60, "opening the pause log releases the driving sound")
	game.desk.dismiss()
	game.desk._touches[0] = {"id":"brake"}
	ticks(160)
	check(is_zero_approx(game.rig.speed) and cues.count("air_brake") == 1, "braking to a stop gives one air release")
	var hiss: AudioStreamPlayer = game.audio.effects[(game.audio.cursor-1) % game.audio.effects.size()]
	check(hiss.volume_db <= -23, "the air release has its own quiet mix level")
	game.desk._touches.clear()
	game.desk.stick = Vector2.DOWN
	ticks(180)
	check(game.rig.speed < -3 and cues.count("reverse") == 3, "three seconds of backing gives three beeps")
	for player in game.audio.effects:
		if player.stream == game.audio.samples.get("reverse"):
			check(is_equal_approx(player.pitch_scale,1.0), "each backup beep has the same pitch")
	check(pull.volume_db > -15, "the diesel pulls in reverse too")
	game.audio.set_sighting(1,1)
	for i in 120: game.audio.mix_truck(game.rig.get_status(),true,true,DT)
	check(game.audio.engines.wind.volume_db < -60 and game.audio.engines.pulse.volume_db > -20,"the calm removes the wind and leaves a slow pulse in the cab")
	check(pull.volume_db > -15,"the lights leave the working diesel audible")
	game.audio.set_sighting(0,0)
	for i in 120: game.audio.mix_truck(game.rig.get_status(),true,true,DT)
	check(game.audio.engines.wind.volume_db > -34 and game.audio.engines.pulse.volume_db < -60,"wind and radio recover after the encounter")
	if not failed:
		print("CHECKS PASSED — idle, acceleration, shift, coast, pause, air release and reverse alarm")
	quit(1 if failed else 0)
