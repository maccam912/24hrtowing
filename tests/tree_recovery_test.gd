extends "res://tests/shift_test.gd"

func stroke(direction: Vector2, frames: int) -> void:
	game.desk.stick = direction
	for tick in frames: game._physics_process(DT)
	game.desk.stick = Vector2.ZERO

func use_panel() -> void:
	var panel: Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.6,panel)
	game._refresh()
	await tap_control("interact")

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.desk._touch_mode = true
	game._action("play")
	rig = game.rig
	var site: Vector3 = game.sightings.FIXED.tree_car
	game.campaign.stage = 2
	game.campaign.released = false
	game.account.equipment.snatch_block = true
	rig.snatch_block = true
	game.sightings._record("tree_car",site,0,0,site.y,"Swamp Rd")
	game.rotation_offer = {}
	game._prepare_offers()
	game._action("radio")
	await tap_control("respond")
	check(game.job.get("id") == "tree_car" and not game.sightings.aftermath.has("tree_car"),"answering the radio claims the actual Swamp Road car for the wrecker")
	if not rig.tree_recovery:
		game.free()
		quit(1)
		return
	var ticket: Dictionary = game.job.duplicate(true)
	var vin: String = ticket.vin
	var initial: Vector3 = rig.car.position
	check(absf(initial.y-rig.ground_height(initial)-2.44)<.02,"the tires rest eight feet up in the tamaracks")
	rig.set_spawn(Vector3(site.x,0,site.z+13.),PI)
	rig.in_cab = false
	await use_panel()
	await use_panel()
	check(rig.phase == "cable" and is_instance_valid(rig.tree_recovery.sling),"the deployed boom drops a marked sling end to the ground")
	var eye: Vector3 = rig.tree_recovery.eye
	stand(eye+Vector3(0,0,.65),eye)
	game._refresh()
	await tap_control("interact")
	check(rig.tree_recovery.block_set and not rig.tree_recovery.controls,"Brandt attaches the block at the base of the trees")
	resume_shift()
	check(rig.phase=="cable" and rig.tree_recovery.block_set and is_instance_valid(rig.tree_recovery.sling),"a saved setup retains its block and sling")
	await use_panel()
	check(rig.tree_recovery.controls and game.state.has("boom_instruction"),"the side panel takes the walking stick for the boom")
	var operator: Vector3 = rig.foot
	stroke(Vector2.RIGHT,60)
	stroke(Vector2.DOWN,60)
	check(initial.distance_to(rig.car.position)<.035 and operator.distance_to(rig.foot)<.015,"the load stays in its forks, and the operator stays at the controls")
	stroke(Vector2.UP,120)
	var raised: Vector3 = rig.car.position
	check(raised.y>initial.y+.65,"the raise stroke lifts the underbody clear of the branches")
	stroke(Vector2.RIGHT,120)
	stroke(Vector2.DOWN,60)
	check(rig.car.position.y >= initial.y+.63,"lowering over the canopy holds the load above the limbs")
	var suspended: Vector3 = rig.car.position
	game.save()
	var old: Dictionary = JSON.parse_string(JSON.stringify(game.saved_data))
	old.rig.erase("tree_boom")
	game._restore(old)
	check(not rig.tree_recovery.controls and rig.tree_recovery.block_set and rig.car.position.distance_to(suspended)<.01,"an older rigged save keeps its suspended car and can take the new controls")
	await use_panel()
	stroke(Vector2.RIGHT,410)
	stroke(Vector2.ZERO,30)
	check(rig.tree_recovery.instruction(rig)=="Lower to the snow","the verge lies clear of the canopy")
	stroke(Vector2.DOWN,400)
	check(operator.distance_to(rig.foot) < .025,"holding LOWER at touchdown keeps the operator planted until the stick returns to neutral")
	check(rig.special_work == 1 and not rig.tree_recovery.controls and absf(rig.car.position.y-rig.ground_height(rig.car.position)) < .08,"lowering sets four tires on the open verge")
	var panel: Vector3 = rig.panel_point()
	stand(panel-rig.truck.global_basis.x*.65,panel)
	for tick in 900:
		if rig.phase=="at_lift": break
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
	check(rig.phase=="at_lift","the ordinary winch brings the lowered sedan to the wheel-lift")
	await use_panel()
	check(game.mode=="haul" and rig.loaded,"the strapped recovery leaves the scene as a payable tow")
	park_tow(game.YardDrop.STORAGE.center,PI/2)
	rig.in_cab=false
	await use_panel()
	stand(game.FAX+Vector3.FORWARD,game.FAX)
	game._action("interact")
	check(game.slips.size()==1 and game.slips[0].vin==vin and game.slips[0].heavy_fee==36 and game.account.earned == game.slips[0].pay,"filing at Brandt's pays the heavy recovery on the original VIN")
	var revised: Dictionary = game.Dispatch.issue_slip(ticket,100.,101.,102.,18.,"04:12",true)
	check(not game.slips[0].has("rate_fee") and revised.rate_name=="Vehicle on structure" and revised.rate_fee==95.,"Doreen's later schedule adds the structure charge only after her revision")
	game.free()
	if not failures:
		print("CHECKS PASSED — Swamp Road sling, independent hydraulic strokes, old-save resumption, wheel-lift, storage and payment")
	quit(int(failures>0))
