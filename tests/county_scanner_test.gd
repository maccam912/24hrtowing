extends "res://tests/shift_test.gd"

func listen_now() -> void:
	game.sub_time = 0
	game.scanner.wait_seconds = 0
	game.scanner.advance(.1,game)
	game._refresh()

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	game.account.cash = 100
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("buy_scanner")
	check(game.account.cash == 100 and not game.account.owns("scanner"), "a new operator cannot buy the deputy's crystal bank")
	rig.in_cab = true
	game._refresh()
	await tap_control("radio")
	await tap_control("open_scanner")
	await process_frame
	check(game.desk.scanner_open and "scanner_sheriff" not in game.desk.surface.key_choices(),"the stock receiver offers the highway channel")
	var dispatch_history: Array = game.calls.duplicate()
	listen_now()
	check(game.scanner.history.size() == 1 and game.calls == dispatch_history and game.audio.chatter.bus == &"County radio","receiver works on the bench and has its own three-call log and filtered audio")
	await tap_control("scanner_off")
	listen_now()
	check(game.scanner.history.size() == 1 and not game.audio.scanner_voice and game.sub_time == 0,"turning off the scanner silences scanner speech")
	await tap_control("close_scanner")
	await tap_control("respond")
	check(game.mode == "fieldwork" and game.speaker.begins_with("DISPATCH"),"switching the receiver off leaves dispatch working")
	game._accept(game.Dispatch.hold_ticket(5,game.audio.lines))
	rig.in_cab = false
	var deputy: Vector3 = rig.get_witness_position()
	stand(deputy+Vector3.FORWARD,deputy)
	check(game._site_action() == "sign","the deputy is reachable at the pickup")
	game._action("interact")
	check(game.signed_card and game.state.scanner_available,"meeting Kowalski opens up her garage and sheriff channels")
	game.desk.dismiss()
	rig.set_spawn(game.SPAWN,-PI/2)
	rig.in_cab = false
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	await tap_control("parts_leaf")
	await tap_control("buy_scanner")
	game.desk._activate("buy_scanner")
	check(game.account.cash == 35 and game.state.scanner_fitted,"office fits the crystal bank and charges once")
	game.desk.dismiss()
	rig.in_cab = true
	game._refresh()
	await tap_control("radio")
	await tap_control("open_scanner")
	await tap_control("scanner_sheriff")
	game.sightings.seen.pacing_lights = game.sightings.drive
	listen_now()
	check(game.scanner.history[0].channel == "sheriff" and "lights, no action" in game.subtitle and game.sightings.report_options().is_empty(),"the deputy independently hears of the lights without filing evidence for Brandt")
	var first: Dictionary = game.scanner.history[0]
	game._directions()
	check(game.speaker == "DISPATCH" and not game.audio.scanner_voice,"asking for directions cuts into a scanner transmission")
	game.scanner.wait_seconds = 0
	game.scanner.advance(90,game)
	check(game.scanner.history[0] == first,"the receiver waits for Arlene to finish")
	listen_now()
	check(game.scanner.history[0] != first,"later patrol calls return to routine work")
	await tap_control("scanner_garage")
	listen_now()
	check(game.scanner.channel == "garage" and game.scanner.history.size() == 3 and game.scanner.history.has(first),"three incoming calls retained across channels")
	game.save()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	game._restore(snapshot)
	check(game.scanner.channel == "garage" and game.scanner.history.size() == 3 and game.scanner.reported.has("pacing_lights"),"new shifts restore crystals, tuning, history and previously heard sighting traffic")
	var before: Array = game.scanner.history.duplicate(true)
	game.sightings.active = "the_calm"
	listen_now()
	check(before == game.scanner.history,"the scanner stays quiet when the wind stops")
	game.sightings.active = ""
	rig.in_cab = false
	listen_now()
	check(before == game.scanner.history,"the bench receiver cannot be heard on foot")
	snapshot.erase("scanner")
	(snapshot.account.equipment as Dictionary).erase("scanner")
	game._restore(snapshot)
	check(game.scanner.channel == "highway" and game.scanner.history.is_empty() and game._scanner_available(),"an older signed shift can buy the upgrade")
	var words := "White squad on County FF by the west-side dairy barn, west shoulder. Deputy Ruiz needs a pull to get back on patrol. County adds $24 if you clear it within two minutes of your first flare. Regular rate either way."
	game.speak("DISPATCH",words)
	game._refresh()
	check(game.sub_time > 12. and game.state.subtitle.ends_with("shoulder.") and words in game.calls[-1],"the first caption gives the location while the radio keeps the complete call")
	check(" ".join(game.caption.pages) == words,"separate captions keep every word and punctuation mark in order")
	game.sub_time = .15
	game._refresh()
	check("Regular rate either way." in game.state.subtitle and game.state.subtitle.length() <= game.caption.PAGE_LENGTH,"the clearance terms get a separate reading time")
	check(game.audio.Speech.read_aloud("Hendricks Rd by St. Hedwig’s on County FF") == "Hendricks Road by Saint Hedwig’s on County F F","the spoken address expands the printed abbreviations")
	if not failures:
		print("CHECKS PASSED — stock scanner, county crystal bank, saved tuning, field traffic and dispatch priority")
	quit(int(failures > 0))
