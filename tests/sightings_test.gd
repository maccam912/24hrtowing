extends SceneTree

var game
var failures := 0

func check(condition: bool, note: String) -> void:
	if not condition:
		failures += 1
		printerr("Sighting check failed: ",note)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._action("play")
	var director = game.sightings
	var rig = game.rig
	game.dispatch_seed = 23
	# Twenty filed and paid ordinary jobs, ignoring the case. Start each real
	# ticket, drive on its road, then finish at the yard using the normal fax.
	for i in 20:
		game._take_rotation()
		var job: Dictionary = game.job
		var p: Vector3 = job.point
		if job.route in ["frames","angie","farm","ff_barn"]: p.x = roundf(p.x/400.)*400.
		else: p.z = roundf(p.z/400.)*400.
		rig.set_spawn(p)
		rig.speed = 6.
		rig.in_cab = false
		director.advance(4.,game)
		check(director.active.is_empty(),"never begins on foot")
		rig.in_cab = true
		rig.tension = .52
		director.advance(4.,game)
		check(director.active.is_empty(),"never begins on a live cable")
		rig.tension = 0
		director.advance(20.,game)
		if i<2: check(director.seen.is_empty(),"first two tickets stay quiet")
		if i==2: check(director.active=="swamp_lights","first sight on ticket three")
		if not director.active.is_empty():
			director.advance(88.,game)
			director.advance(17.,game)
			check(director.active.is_empty(),"no second major event on the outbound")
		game._recovered(job.kind)
		if job.kind=="hazard":
			game.mode="haul"
			rig.loaded=true
			director.advance(20.,game)
			director.advance(88.,game)
			game._dropped()
		rig.set_spawn(game.SPAWN)
		rig.in_cab=false
		rig.foot=game.FAX
		game._action("fax")
		game.desk.dismiss()
		rig.in_cab=true
		check(game.completed==i+1,"ordinary fax %d" % (i+1))
	check(game.campaign.stage==0 and not game.survey.unit_reported and not game.held,"a whole shift can ignore the surveyor")
	check(game.account.earned>0 and director.seen.size()>=5 and director.seen.has("pacing_lights"),"paid ordinary calls encounter lights at multiple tiers")
	check(director.tier(40,0)==4 and director.tier(12,2)==3,"slips or story bring lights closer")
	game._take_rotation()
	rig.set_spawn(Vector3(0,0,-245),0)
	# Build every moving/aftermath set piece, including temporary events unlikely
	# to appear for this drive's seed, and advance each through its ending.
	var ids: Array = director.PACING+director.CLOSE+director.HIGH
	for id: String in ids:
		director._start(id,game,rig.truck.position,"County K",false)
		director._advance_live(director.duration*.48,game,rig.truck.position)
		director._advance_live(director.duration*.60,game,rig.truck.position)
	check(director.aftermath.has("field_car") and director.aftermath.has("woods_tracks"),"live scenes leave physical evidence")
	# A clock skip needs a clear, straight segment that shortens this run.
	game.job = {"number":1040,"kind":"ditch","point":Vector3(0,0,720)}
	game.mode = "fieldwork"
	rig.set_spawn(Vector3(0,0,535),PI)
	rig.in_cab=true
	rig.loaded=false
	rig.phase="scene"
	rig.speed=5.
	var before_seconds: float = game.shift_seconds
	var before_fuel: float = rig.fuel
	var before: Vector3 = rig.truck.position
	game.county.advance_storm(0.)
	director._start("missing_time",game,before,"County K",false)
	director._advance_live(1.65,game,before)
	check(rig.truck.position.distance_to(game.job.point)<before.distance_to(game.job.point) and rig.truck.position.z<600.,"clock skip only advances toward the call")
	check(is_equal_approx(game.shift_seconds,before_seconds+2400.) and is_equal_approx(rig.fuel,before_fuel),"forty missing minutes preserve tank level")
	director._advance_live(2.,game,rig.truck.position)
	rig.loaded=true
	check(not director._jump_point(game).is_finite(),"loaded wrecker is ineligible for missing time")
	rig.loaded=false
	var data: Dictionary = JSON.parse_string(JSON.stringify(director.save_state()))
	director.restore(data,game.county)
	director._snow_over(game.completed+10)
	check(director.aftermath.has("field_car") and not director.aftermath.has("bare_ring"),"upturned car survives ten jobs and a reload while rings snow over")
	# A fresh set of once-only flags. Use the regular tick for the scripted rides.
	director.restore({},game.county)
	game.campaign.stage=4
	game.job.case_id="mail"
	rig.loaded=true
	game.mode="haul"
	director.advance(.1,game)
	check(director.active=="mirror_follow","carrier's loaded return lights")
	director.advance(director.duration+1.,game)
	director.advance(2.,game)
	check(director.active.is_empty(),"carrier lights only once")
	rig.loaded=false
	game.mode="fieldwork"
	game.campaign.stage=6
	game.job.case_id="ride"
	rig.set_spawn(Vector3(441,0,-530))
	director.advance(.1,game)
	check(director.active=="storm_hole","clear patch over Tou")
	game.campaign.evidence.passenger=true
	rig.speed=4.
	director.advance(.1,game)
	check(director.active=="overhead","lights cross the occupied cab on the way out")
	director.advance(director.duration+1.,game)
	game.job.erase("case_id")
	game.campaign.stage=8
	game.job.point = Vector3(8.4,0,-350)
	rig.set_spawn(Vector3(0,0,-180))
	rig.speed=4.
	director.advance(.1,game)
	check(director.active=="set_down","first subsequent ordinary outbound gets the finale")
	director.advance(director.duration*.4,game)
	var plate: String = director.scene.actor.get_meta("plate")
	var vin: String = director.scene.actor.get_meta("vin")
	var saved := JSON.parse_string(JSON.stringify(director.save_state())) as Dictionary
	director.restore(saved,game.county)
	director.advance(director.duration+1.,game)
	check(director.aftermath.has("shoulder_car"),"finale persists through a mid-descent save")
	var recovery: Dictionary=director.recovery_offer(109,game.county)
	check(recovery.get("aftermath_key")=="shoulder_car","the next authorization is the car seen arriving")
	check(recovery.plate==plate and recovery.vin==vin and recovery.variant==0 and recovery.untaped,"one identifiable blue sedan from sky to tow order")
	director.claim_recovery(recovery)
	check(not director.aftermath.has("shoulder_car"),"no static duplicate of a claimed sedan")
	for mph: float in [20.,30.,40.]:
		director.restore({},game.county)
		var start := Vector3(0,0,430)
		rig.set_spawn(start,PI)
		rig.speed = mph/rig.MPH_PER_MPS
		game.job.point = Vector3(8.4,0,750)
		director.advance(.1,game)
		check(director.active=="set_down","eligible straight road at %d mph" % int(mph))
		if director.active!="set_down": continue
		check(director.scene.actor.position.y-director.shoulder.y>=19.9,"sedan is airborne on its first visible frame")
		var touched := false
		var radio := false
		for frame in 420:
			rig.truck.position.z += rig.speed/60.
			director.advance(1./60.,game)
			if director.active!="set_down": break
			if not touched and director.scene.actor.position.y-director.shoulder.y<.02:
				touched = true
				check(director.shoulder.z-rig.truck.position.z>18.,"touchdown ahead at %d mph" % int(mph))
			if not radio and director.heard:
				radio = true
				check(director.shoulder.z-rig.truck.position.z>16. and touched,"radio follows touchdown in view at %d mph" % int(mph))
		check(touched and radio,"touchdown and call reached at %d mph" % int(mph))
	game.free()
	if failures==0: print("CHECKS PASSED — twenty ordinary shifts, sighting tiers and guards, lasting aftermath, Tou's ride and the shoulder set-down")
	quit(int(failures>0))
