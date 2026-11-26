extends "res://tests/plat_pencil_test.gd"
const Town := preload("res://scripts/esker_main_street.gd")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	game.desk._touch_mode=true
	var advertised := {}
	for place: Dictionary in game.county.map_places(): advertised[place.name]=place.point
	check(advertised["Esker Fire Hall"]==Town.HALL and advertised.has("Esker Cheese Factory") and advertised.has("Zion Lutheran"),"town directory and real-world places agree")
	await tap_control("map")
	await tap_control("turn_town")
	await tap_control("plat_pencil")
	await tap_control("pencil_return")
	await touch_sheet(Town.HALL)
	check(game.plat_pencil.marks == [[105,26,"return"]],"touch map pencils the village-scale coordinate")
	await tap_control("pencil_vehicle")
	await touch_sheet(Vector2(Town.TANKER_X,17))
	var local_marks := [[105,26,"return"],[108,17,"vehicle"]]
	check(game.plat_pencil.marks == local_marks,"opposite ends of the town apron take distinct pencil marks")
	game.desk.dismiss()
	var call := {}
	var history := []
	for i in 45:
		var ticket: Dictionary = game.Dispatch.ordinary(i,412,history)
		history.append(game.Dispatch.issue_slip(ticket,100,100,100,0,"03:35"))
		if ticket.site=="fire_hall":
			call=ticket
			break
	check(not call.is_empty() and call.kind=="hazard" and call.shoulder=="south" and "fire hall" in call.directions,"Arlene describes the paid tow and its south-side bay")
	if call.is_empty(): game.free();quit(1);return
	game._stamp_ticket(call)
	game._accept(call)
	var bay: Node3D = game.county.fire_bay
	var bay_origin: Vector3 = bay.tanker.global_position
	var site: Vector3 = rig.car.position
	check(Town.APRON.has_point(Vector2(site.x,site.z)) and absf(site.x-Town.TANKER_X)<.2 and game.rig.car.get_node_or_null("SheriffTape"),"checked car blocks the tanker on the actual apron")
	# Pull the casualty lengthwise across the pavement, clear of the equipment bays.
	var outward := Vector3.RIGHT
	rig.set_spawn(site+outward*12,-PI*.5)
	rig.in_cab = false
	stand(site+Vector3.BACK*2.4,site)
	game._action("interact")
	var panel: Vector3 = rig._panel()
	stand(panel-rig.truck.global_basis.x,panel)
	game._action("interact")
	var end := 1 if outward.dot(rig.car.global_basis.z)>0 else -1
	var eye: Vector3 = rig._eyelet(end)
	stand(eye+rig.car.global_basis.z*end,eye)
	game._action("interact")
	stand(panel-rig.truck.global_basis.x,panel)
	game.desk._touches[0] = {"id":"work"}
	for i in 2400:
		if rig.phase!="rigged": break
		game._physics_process(DT)
	game.desk._touches.clear()
	check(rig.phase=="at_lift","stock main drum pulls the taped casualty onto the wheel-lift")
	game._action("interact")
	check(rig.loaded and game.mode=="haul","the fire hall uses the actual paid storage haul")
	rig.in_cab=true
	drive_to(Vector3(148,0,17))
	stop()
	for i in 240: game._physics_process(DT)
	check(bay.lift==1.0 and bay.travel>0 and bay.tanker.global_position.z<bay_origin.z,"the segmented door rolls overhead and Tanker 2 drives onto the vacated apron")
	var halfway: float = bay.travel
	rig.in_cab=false
	rig.foot=Vector3(Town.TANKER_X,0,17)
	for i in 30: game._physics_process(DT)
	check(bay.travel==halfway,"the tanker yields when the operator enters its path")
	resume_shift()
	bay=game.county.fire_bay
	check(is_equal_approx(bay.travel,halfway) and game.job.number==call.number and rig.loaded,"mid-roll tanker, loaded car and original paid ticket survive save")
	rig.foot=Vector3(90,0,15)
	for i in 720: game._physics_process(DT)
	check(is_equal_approx(bay.travel,bay.DRIVE_OUT),"after the operator steps clear the tanker finishes its roll")
	check(game.plat_pencil.marks==local_marks,"saved local notes project back onto the county plat")
	game.free()
	if not failures: print("CHECKS PASSED — Esker town detail, paid apron clearance, moving tanker, pedestrian yield and loaded save")
	quit(int(failures>0))
