extends "res://tests/shift_test.gd"

func tune_now(id: String, clock: float) -> void:
	game.broadcast.elapsed = clock
	await tap_control("broadcast_"+id)
	game.broadcast.advance(.1,game)
	game._refresh()

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	game.sub_time = 0
	var radio = game.broadcast
	check(radio.station == "off" and radio.program.stream == null,"a new shift opens with the entertainment set off")
	await tap_control("radio")
	await tap_control("open_scanner")
	await tap_control("open_broadcast")
	await tune_now("am",6.)
	check(game.state.broadcast_station == "am" and "Milk trucks" in game.state.subtitle and game.speaker != "ESKER FARM SERVICE","AM farm report has a voiced clip and a separate readable caption")
	var am: AudioStream = radio.program.stream
	check(am.get_length() >= radio.programs.am.duration-.1,"the complete farm report and original polka are packed")
	radio.elapsed = radio.programs.am.cues[3].start
	radio.advance(.1,game)
	game._refresh()
	check(game.state.broadcast_label == "The Forty Acre Polka" and game.state.subtitle.is_empty(),"the tune follows the dance-hall introduction")
	await tune_now("fm",9.)
	var fm: AudioStream = radio.program.stream
	check(am != fm and fm.get_length() >= radio.programs.fm.duration-.1 and game.state.broadcast_label == "Sunday at River Lanes","the FM preset plays its own country waltz and calendar")
	rig.set_spawn(Vector3(890,0,35),0)
	radio.advance(1.,game)
	var near_signal: float = radio.signal_strength
	rig.set_spawn(Vector3(-610,0,0),0)
	radio.advance(1.,game)
	check(near_signal > .98 and radio.signal_strength < near_signal*.40,"FM fades on the road away from the Tamarack tower")
	game.audio.set_sighting(1,1)
	radio.advance(1.,game)
	check(radio.signal_strength < .01 and radio.program.volume_db < -65 and radio.hiss.volume_db > -32,"the interference drowns the program under static")
	game.audio.set_sighting(0,0)
	game._speak("DISPATCH","Brandt, call the office.")
	radio.advance(.2,game)
	game._refresh()
	check(radio.program.volume_db < -65 and radio.hiss.volume_db < -70 and game.state.subtitle == "Brandt, call the office.","county radio overrides both program and caption")
	game.sub_time = 0
	radio.advance(1.,game)
	check(radio.program.volume_db > -35,"the broadcast comes back after the county call")
	var head: float = radio.elapsed
	game._save()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	game._restore(snapshot)
	check(radio.station == "fm" and is_equal_approx(radio.elapsed,head),"station and program position survive a cold restore")
	game.desk.dismiss()
	rig.in_cab = false
	radio.advance(1.,game)
	check(not radio.can_hear and radio.caption().is_empty(),"the dashboard receiver stays in the cab")
	snapshot.erase("broadcast")
	game._restore(snapshot)
	check(radio.station == "off" and radio.program.stream == null,"legacy shifts start with a silent entertainment receiver")
	if not failures:
		print("CHECKS PASSED — original AM and FM programs, air time, distance, interference, dispatch priority and save continuity")
	quit(int(failures > 0))
