extends "res://tests/shift_test.gd"

func frames(count: int, move := Vector2.ZERO, brake := false) -> void:
	for i in count:
		rig.set_controls(move,Vector2.ZERO,false,brake,DT)
		game.audio.recovery.mix(true,false,DT)

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game._action("play")
	rig=game.rig
	var road = game.audio.recovery.driving
	rig.set_spawn(Vector3(0,0,268),0)
	rig.tire_chains = false
	frames(190,Vector2.UP)
	check(road.chains.volume_db<-66.,"ordinary tires have no chain chatter at road speed")
	rig._stop_motion()
	rig.tire_chains = true
	frames(40,Vector2.UP)
	check(road.chains.stream != null and road.chains.stream.resource_path.ends_with("chain_link.wav"),"at walking pace the fitted tandem strikes one crosslink at a time")
	frames(230,Vector2.UP)
	check(road.surface>.98 and road.chains.volume_db>-38. and road.chains.stream.resource_path.ends_with("chains_pavement.wav"),"fitted chains roll audibly down the plowed county route")
	var fast:float = road.chains.pitch_scale
	frames(80,Vector2.ZERO)
	check(road.chains.pitch_scale<fast and rig.compression_brake==0.,"chain cadence follows wheel travel while the level road stays clear of exhaust braking")
	rig._stop_motion()
	frames(100)
	check(road.chains.volume_db<-66. and road.exhaust.volume_db<-66.,"both tandem and exhaust quiet at a standstill")
	check(road.pavement(rig,Vector3(84,0,290))<.02 and road.pavement(rig,Vector3(0,0,290))>.98,"deep snow damps the chain while the paved crown carries the strike")
	check(road.pavement(rig,Vector3(game.County.CaseSites.ALDER_X,0,-442.))==0.,"chains stay soft on the unsigned two-track")
	rig.set_spawn(Vector3(79,0,293),0)
	frames(130,Vector2.UP)
	check(road.surface<.02 and road.chains.volume_db<-66.,"real wheel travel across field snow does not sound like pavement")
	rig._stop_motion()
	rig.tire_chains = false
	rig.set_spawn(Vector3(-24,0,281),-PI/2)
	for tick in 700:
		if rig.truck.position.x > 1.9: break
		frames(1,Vector2.UP)
		check(rig.compression_brake==0.,"the foot on the accelerator holds the exhaust brake off")
	check(rig.truck.position.x>1.9 and rig.speed>4.,"a real crossing builds speed before the crowned road descends into the east borrow ditch")
	var greatest := 0.
	var loudest := -80.
	for i in 120:
		frames(1)
		greatest = maxf(greatest,rig.compression_brake)
		loudest = maxf(loudest,road.exhaust.volume_db)
	check(greatest>.45 and loudest>-57.,"coasting down the physical bank works the exhaust brake, using all six tire contacts (%.2f / %.1f)" % [greatest,loudest])
	frames(45,Vector2.UP)
	check(rig.compression_brake==0. and road.exhaust.volume_db<-65.,"putting power back on silences the overrun")
	rig._stop_motion()
	var before:int = road.wiper_turn
	for i in 220:
		var wipe_time := fmod(float(rig.body.elapsed),3.6)
		if wipe_time>=1.05 and wipe_time<1.11: break
		frames(1)
	var parked_wipe:int = road.wiper_turn
	frames(78)
	check(road.wiper_turn==parked_wipe and is_zero_approx(rig.body.wipers[0].rotation.z),"time between real blade sweeps is quiet")
	for i in 300:
		frames(1)
		if road.wiper_turn>parked_wipe: break
	frames(15)
	check(road.wiper_turn>before and absf(rig.body.wipers[0].rotation.z)>.09 and road.blade.stream.resource_path.ends_with("wiper_sweep.wav"),"a real blade stroke triggers once at the windshield")
	game.free()
	if not failures: print("CHECKS PASSED — chain crosslinks on pavement, snow and crawl, actual downhill diesel overrun, and each windshield stroke")
	quit(int(failures>0))
