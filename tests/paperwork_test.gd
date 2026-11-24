extends SceneTree
const Dispatch := preload("res://scripts/dispatch.gd")
var failed := false

func check(ok: bool, note: String) -> void:
	if not ok:
		failed = true
		printerr(note)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://game.tscn").instantiate()
	root.add_child(game)
	var lines: Dictionary = game.audio.lines
	for id in lines:
		game._say(id)
		var stream := game.audio.chatter.stream as AudioStreamWAV
		check(stream != null and stream.get_length() > 0, "Missing chatter for " + id)
		check(game.speaker == lines[id][0] and game.subtitle == lines[id][1], "Subtitle for " + id)
		check(stream != null and game.sub_time > stream.get_length(), "Reading time for " + id)
		var radio: bool = game.speaker in ["DISPATCH", "COUNTY PLOW"]
		check(game.audio.chatter.bus == (&"County radio" if radio else &"Master"), "Audio routing for " + id)
	var previous := ""
	for i in 100:
		var ticket := Dispatch.ticket(i,lines)
		check(ticket.kind != previous,"Repeated consecutive recovery type")
		check(ticket.number == 1001+i,"Ticket sequence")
		previous = ticket.kind
		if i == 3:
			check(ticket.id == "bridge","Disputed invoice should be 1004 from the bridge")
		if i == 4:
			check(ticket.kind == "hold","First custody hold should be fifth")
	var hazard := Dispatch.ticket(3,lines)
	var loaded := Dispatch.issue_slip(hazard,19240,19241.2,19242.48,83,"04:30")
	check(absf(loaded.loaded-1.3)<0.001 and loaded.winch == 12,"Recovery time and odometer charges")
	var pull := Dispatch.issue_slip(Dispatch.ticket(0,lines),19240,19240.8,19242,23,"03:28")
	check(pull.loaded==0 and pull.storage==0,"A self-departing car must not be billed loaded miles or storage")
	if not failed:
		print("CHECKS PASSED — invoices, dialogue chatter, subtitles and repeat dispatch")
	quit(1 if failed else 0)
