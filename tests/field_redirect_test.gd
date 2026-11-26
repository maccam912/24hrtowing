extends "res://tests/shift_test.gd"

const Gate := preload("res://scripts/field_redirect.gd")

func point(at: Vector3, offset: Vector3) -> void:
	rig.in_cab=false
	stand(at+offset,at)
	game._refresh()

func interact_at(id: String, at: Vector3, offset: Vector3) -> void:
	point(at,offset)
	var actual: String = game._site_action()
	if actual.is_empty(): actual=rig.action_id()
	check(actual==id, "expected "+id+" at "+str(at)+" but offered "+actual)
	game._action("interact")

func panel(id: String) -> void:
	interact_at(id,rig._panel(),-rig.truck.global_basis.x*.95)

func work(count: int) -> void:
	for i in count: rig.set_controls(Vector2.ZERO,Vector2.ZERO,rig.tension<.93,false,DT)

func run_gate(index: int, selected: int) -> void:
	game=load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	rig=game.rig
	game.account.equipment.snatch_block=true
	game._fit_equipment()
	game.dispatch_seed=index
	var jobs: Array = []
	for i in 100:
		var offer: Dictionary = game.Dispatch.ordinary(i,index,jobs,true)
		if offer.has("field_gate"): break
		jobs.append(game.Dispatch.issue_slip(offer,0,0,0,40,"03:45"))
	game.slips=jobs
	game.completed=jobs.size()
	game.rotation_offer={}
	game._prepare_offers()
	var offer: Dictionary = game.rotation_offer
	check(offer.get("field_gate",-1)==index and not game.RollbackDeck.supports(offer),"the equipped wrecker gets a recurring gate recovery through ordinary dispatch")
	if not offer.has("field_gate"):
		game.free()
		return
	game._action("radio")
	game.desk._activate("respond")
	var gate=rig.redirect
	var spec: Dictionary = gate.site
	var open_direction: float = spec.opening
	var tree: Vector3 = gate.anchor(rig,maxi(selected,0))
	var truck_at := Gate.point(spec,1.4,4.5 if selected>=0 else 17.8)
	var yaw := 0. if open_direction>0 else PI
	rig.set_spawn(truck_at,yaw)
	interact_at("driver",rig.get_witness_position(),Vector3.RIGHT)
	check(game.subtitle.contains("wire"),"the driver identifies the gate when asked")
	interact_at("flare",rig.car.position,rig.car.global_basis.x*2.3)
	panel("cable")
	var eye: Vector3 = rig._eyelet(-1)
	if selected>=0:
		interact_at("field_fence",eye,rig.car.global_basis.z*-.7)
		check(rig.phase=="cable" and not rig.working,"straight cable cannot be pulled through the actual end fence")
		var post := Gate.point(spec,Gate.FENCE_X,0.)
		post.y=rig._ground(post)+.9
		interact_at("field_post",post,Vector3.LEFT)
		check(gate.selected<0,"the loose post cannot take the block")
		point(tree,Vector3.RIGHT)
		rig.assist=false
		rig._update_highlight()
		check(not rig.highlight.visible and rig.action_id()=="field_wrap","the real tree still takes the strap with assistance disabled")
		rig.assist=true
		rig._update_highlight()
		check(rig.highlight.visible and rig.highlight.global_position.distance_to(tree)<.04,"assistance identifies a physically reachable hardwood")
		interact_at("field_wrap",tree,Vector3.RIGHT)
		check(gate.selected==selected and is_instance_valid(gate.sling),"webbing is fastened around the chosen trunk")
		resume_shift()
		gate=rig.redirect
		check(gate.selected==selected and is_instance_valid(gate.sling),"the routed block resumes before hook-up")
	interact_at("attach",eye,rig.car.global_basis.z*-.7)
	point(rig._panel(),-rig.truck.global_basis.x)
	if selected>=0:
		rig._cable_curve()
		check(rig.cable_mesh.get_surface_count()==2 and rig.pulley.global_position.distance_to(tree)<.02,"both visible legs meet at the selected block")
		var last: Vector3=rig.car.position
		var closest := INF
		for i in 2600:
			if gate.easing: break
			work(1)
			check(not gate.cuts_wire(last,rig.car.position,.65),"the moving body clears the field wire")
			last=rig.car.position
			closest=minf(closest,rig._flat_distance(tree,last))
		check(gate.easing and game.mode=="fieldwork" and closest>2.6,"the first pull stops safely short of the trunk with the contract open")
		var stopped_at:Vector3=rig.car.position
		work(125)
		check(stopped_at.distance_to(rig.car.position)<.004 and rig.tension<.01,"the line stays slack until the operator reroutes it")
		resume_shift()
		gate=rig.redirect
		interact_at("field_transfer",tree,Vector3.RIGHT)
		check(not gate.easing and gate.selected<0 and gate.route_used and not is_instance_valid(gate.sling),"operator removes the slack hardware while the hook stays on the car")
		point(rig._panel(),-rig.truck.global_basis.x)
	work(3300)
	check(game.mode=="available" and rig.phase in ["departing","done"] and rig._road(rig.car.position)<4.8,"the owner’s car is pulled all the way onto the road and released")
	if game.pending_slips.is_empty():
		game.free()
		return
	var slip: Dictionary=game.pending_slips[0]
	check(slip.field_gate==index and (("block" in slip.pull) if selected>=0 else ("Straight" in slip.pull)),"the receipt records the line the operator actually used")
	point(game.FAX,Vector3.FORWARD)
	game._action("interact")
	check(game.slips.back().number==offer.number and game.fax_text.contains(slip.pull) and game.account.earned>=slip.pay,"the operator's own rigging method and payment reach the county fax")
	game.free()

func run() -> void:
	await run_gate(0,0)
	await run_gate(1,1)
	await run_gate(0,-1)
	if failures==0: print("CHECKS PASSED — ordinary gate dispatch, optional tree assistance, two routed anchors, clear straight alternative, fence geometry, slack changeover, saved block and paid departure.")
	quit(int(failures>0))
