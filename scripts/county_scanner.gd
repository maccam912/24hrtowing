extends RefCounted
## Receive-only radio in Brandt's cab. Listening never opens a ticket or logs evidence.

const CHANNELS := {"highway":"01  HIGHWAY", "garage":"06  GARAGE", "sheriff":"08  SHERIFF", "off":"OFF"}
const TRAFFIC := {
	"highway":[
		["HIGHWAY BASE", "West bridge is salted. Leave the center stripe bare so folks can find their lane."],
		["COUNTY PLOW", "Lost the rubber off my right wiper. Left one's still earning its keep."],
		["HIGHWAY BASE", "Whoever left their brown mittens on the spreader, I've got them drying on the register."],
		["COUNTY PLOW", "Got the church corner opened up. Bell's still going on the quarter hour."],
		["HIGHWAY BASE", "Dairy truck made it through. Leave him room on the next pass."],
		["COUNTY PLOW", "Cutting the ridge back at the boxes. Mail lady's got short arms."],
	],
	"garage":[
		["COUNTY GARAGE", "Little spreader's inside. Park the next one nose out, please."],
		["COUNTY PLOW", "Put a coffee can under that new fitting. I want to see what it leaks before you tighten it."],
		["COUNTY GARAGE", "Sand pile froze up on the north face. Loader's working the other side."],
		["COUNTY PLOW", "Who's got my half-inch? Paint's gone on the handle. That's how you know it's mine."],
		["COUNTY GARAGE", "Coffee pot's down to the last cup. Bring a filter back with you."],
	],
	"sheriff":[
		["CAR FOUR", "Yellow tape on the mirror. Owner's home with his brother."],
		["KOWALSKI", "Put the extra rolls in my locker. You can't write a badge number on wet tape."],
		["CAR FOUR", "Fuel and Food's got the front door shoveled. I'll leave the spare key there."],
		["KOWALSKI", "I can read the fire plate from this side. Correct that last digit to a four."],
		["CAR FOUR", "Checked the bridge both ways. That's my own set of tracks coming back."],
	],
}
const REPORTS := {
	"pacing_lights":["CAR FOUR", "Three lights reported moving level across a field. Put it down as lights, no action."],
	"streetlights_out":["KOWALSKI", "Lamps went out one after the other down Main. Esker Fuel kept power the whole time."],
	"deer_line":["CAR FOUR", "That row of deer never crossed the road. I sat there with the high beams on."],
	"the_lift":["KOWALSKI", "Tape hasn't come loose. It's the whole car that's gone. Leave the time on my report."],
}
var channel := "highway"
var history: Array = []
var cursor := {}
var reported := {}
var wait_seconds := 35.0
var rx_left := 0.0
var scripted_plow := false

func tune(next: String, fitted: bool) -> bool:
	if next == channel or not CHANNELS.has(next) or (next in ["sheriff","garage"] and not fitted):
		return false
	channel = next
	rx_left = 0.0
	scripted_plow = false
	wait_seconds = minf(wait_seconds, 8.0)
	return true

func _reception(game) -> bool:
	return game.active and game.rig.in_cab and channel != "off" and game.rig.fuel > 0 and not game.fuel_can.en_route() \
		and (not game.desk.is_blocking() or (game.desk.page == "radio" and game.desk.scanner_open)) \
		and not (is_instance_valid(game.rig.survey_passenger) and game.rig.survey_passenger.visible) \
		and game.rig.phase not in ["flared","cable","rigged","at_lift","dollies"]

func _clear_reception(game) -> void:
	if rx_left > 0 and game.speaker.begins_with("SCANNER  /  "):
		game.sub_time = 0
	game.audio.stop_scanner()
	rx_left = 0.0
	scripted_plow = false

func advance(dt: float, game) -> void:
	# The plow driver can key his mic while the player sees the stopped plow.
	if not _reception(game) or (not game.sightings.active.is_empty() and not (scripted_plow and game.sightings.active == "plow_stopped")):
		_clear_reception(game)
		return
	rx_left = maxf(0,rx_left-dt)
	var monitoring: bool = game.desk.scanner_open and not game.desk.broadcast_open
	if game.sub_time > 0 or game.audio.cue_busy() or (not monitoring and (game.completed < 1 or absf(game.rig.speed) < 1.0)):
		return
	wait_seconds = maxf(0,wait_seconds-dt)
	if wait_seconds > 0:
		return
	var turn := int(cursor.get(channel,0))
	var line: Array = []
	if channel == "sheriff":
		for event: String in REPORTS:
			if not reported.has(event) and game.sightings.seen.has(event) and game.sightings.drive-int(game.sightings.seen[event]) <= 3:
				reported[event] = true
				line = REPORTS[event]
				break
	if line.is_empty():
		var pool: Array = TRAFFIC[channel]
		var index := posmod(int(game.dispatch_seed) + turn,pool.size())
		line = pool[index]
		# Duane is working the roadside recovery with Brandt.
		if line[0] == "COUNTY PLOW" and game.rig.duane_on_scene():
			index = (index + 1) % pool.size()
			line = pool[index]
			turn += 1
	cursor[channel] = turn + 1
	_receive(game,line)

func plow_call(game) -> bool:
	if channel not in ["highway","garage"] or not _reception(game) or game.rig.duane_on_scene() or game.sub_time > 0 or game.audio.cue_busy():
		return false
	scripted_plow = game.sightings.active == "plow_stopped"
	if scripted_plow:
		_receive(game,game.audio.lines.plow)
	else:
		_receive(game,game.audio.lines.plow_shop)
	return true

func _receive(game, line: Array) -> void:
	var who: String = line[0]
	var words: String = line[1]
	history.push_front({"clock":game.clock(),"channel":channel,"who":who,"words":words})
	history.resize(mini(history.size(),3))
	game.show_message("SCANNER  /  " + who,words)
	game.audio.speak(who,words,true)
	rx_left = game.sub_time
	wait_seconds = 72.0 + posmod(int(game.dispatch_seed) + int(cursor.get(channel,0)) * 19,35)

func save_state() -> Dictionary:
	return {"channel":channel,"history":history.duplicate(true),"cursor":cursor.duplicate(),
		"reported":reported.duplicate(),"wait":wait_seconds}

func restore(save: Dictionary, fitted: bool) -> void:
	var selected := str(save.get("channel","highway"))
	channel = selected if CHANNELS.has(selected) and (fitted or selected in ["highway","off"]) else "highway"
	history = save.get("history",[]).slice(0,3).duplicate(true)
	cursor = save.get("cursor",{}).duplicate()
	reported = save.get("reported",{}).duplicate()
	wait_seconds = clampf(save.get("wait",35.0),0,108)
	rx_left = 0.0
	scripted_plow = false

## What the scanner page draws: the tuned channel, its log and the receive lamp.
func view() -> Dictionary:
	return {"scanner_channel":channel,"scanner_history":history,"scanner_rx":rx_left > 0}
