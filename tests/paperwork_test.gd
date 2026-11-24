extends SceneTree
const Dispatch := preload("res://scripts/dispatch.gd")
var failed := false

func check(ok: bool, note: String) -> void:
	if not ok:
		failed = true
		printerr(note)

func _initialize() -> void:
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/lines.json"))
	for id in lines:
		check(ResourceLoader.exists("res://assets/audio/"+id+".mp3"),"Missing voiced line: "+str(id))
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
		print("CHECKS PASSED — invoices, radio recordings and repeat dispatch")
	quit(1 if failed else 0)
