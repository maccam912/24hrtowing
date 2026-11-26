extends "res://tests/tree_recovery_test.gd"

func last_impact():
	var field = game.audio.recovery
	return field.impacts[posmod(field.cursor-1,field.impacts.size())]

func run() -> void:
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game._action("play")
	rig = game.rig
	var field = game.audio.recovery
	var ui_cursor: int = game.audio.cursor
	rig.set_spawn(Vector3(0,0,160))
	rig.start_job("hazard",Vector3(3,0,176),.08,{"vin":"AUDIO-1"})
	rig.in_cab=false
	stand(rig.car.position+Vector3.LEFT*2.,rig.car.position)
	rig.interact()
	check(rig.phase=="flared" and last_impact().get_meta("source_id")=="flare_strike" and last_impact().global_position.distance_to(rig.flame.global_position)<.2,"a struck flare ignites at its own spot on the snow")
	for i in 75: field.mix(true,false,DT)
	var open_burn:float = field.burning.volume_db
	check(field.burning.global_position.distance_to(rig.flame.global_position)<.2 and open_burn>-28.,"burning hiss remains at the flare while the operator walks away")
	for i in 75: field.mix(true,false,DT,1.)
	check(field.burning.volume_db <= -65., "the sighting calm stills the roadside fizz")
	rig.in_cab=true
	rig.set_spawn(rig.flame.global_position-Vector3.LEFT*.4)
	for i in 90: field.mix(true,false,DT)
	var shut:float = field.burning.volume_db
	check(shut<open_burn-15. and field.filter.cutoff_hz<1300.,"closed cab attenuates exterior equipment and removes high hiss")
	rig.climate.cracked = true
	for i in 90: field.mix(true,false,DT)
	check(field.burning.volume_db>shut+10. and field.filter.cutoff_hz>4900.,"cracking the driver window restores brightness and part of the exterior level")
	rig.in_cab=false
	rig.set_spawn(Vector3(0,0,160))
	var panel:Vector3 = rig._panel()
	stand(panel-rig.body.global_basis.x*.65,panel)
	rig.interact()
	check(rig.phase=="cable" and last_impact().get_meta("source_id")=="drum_clutch","taking the cable releases the drum clutch at the truck")
	for i in 27:
		rig.foot.x -= .042
		field.mix(true,false,DT)
	check(field.mode=="rope_payout" and field.motor.stream.resource_path.ends_with("rope_payout.wav"),"outgoing cable freewheels on the actual reel")
	for i in 62: field.mix(true,false,DT)
	check(field.mode.is_empty() and field.motor.volume_db<-65.,"the drum goes quiet when Brandt stops walking with the hook")
	var eye: Vector3 = rig._eyelet(-1)
	stand(eye+Vector3.RIGHT,eye)
	rig.interact()
	check(rig.phase=="rigged" and last_impact().get_meta("source_id")=="shackle_pin" and last_impact().global_position.distance_to(rig._eyelet(-1))<.03,"the tow eye and pin ring where they meet")
	stand(panel-rig.body.global_basis.x*.68,panel)
	for i in 120:
		rig.set_controls(Vector2.ZERO,Vector2.ZERO,true,false,DT)
		field.mix(true,false,DT)
	check(field.mode=="drum_under_load" and field.motor.global_position.distance_to(rig._drum())<.02 and field.motor.pitch_scale>.96,"the loaded drum sounds at the rear fairlead and climbs in pitch")
	rig.sound_event.emit("cable_slip")
	var slip:AudioStream = last_impact().stream
	rig.sound_event.emit("ratchet")
	check(slip.resource_path.ends_with("rope_slip.wav") and last_impact().stream.resource_path.ends_with("strap_ratchet.wav"),"wire slip and ratchet teeth play separate recordings")
	check(game.audio.cursor==ui_cursor,"the physical effects keep the cabin papers and radio pool free")
	game.audio.effect("fax")
	check(game.audio.cursor!=ui_cursor,"the fax stays on its interior output")
	rig.end_job()
	rig.use_rollback(true)
	rig.start_job("hazard",Vector3(0,0,179),0.,{})
	rig.phase="flared"
	panel=rig._panel()
	stand(panel-rig.body.global_basis.x*.68,panel)
	rig.interact()
	field.mix(true,false,DT)
	check(field.mode=="hydraulic_pump" and field.motor.global_position.distance_to(panel)<.02,"sliding the carrier bed works the hydraulic pump at the valve chest")
	rig.end_job()
	rig.use_rollback(false)
	rig.start_job("hazard",Vector3(0,4.75,177),0.,{"recovery":"roof"})
	rig.phase="rigged"
	rig.working=true
	field.mix(true,false,DT)
	check(field.mode=="hydraulic_pump" and field.motor.pitch_scale>1.,"hoisting on the boom uses the higher-pressure hydraulic note")
	for i in 80: field.mix(false,false,DT)
	check(field.motor.volume_db<=-65. and field.burning.volume_db<=-65.,"stowing the controls releases the equipment mix")
	game.free()
	if not failures: print("CHECKS PASSED — flare at source, cable payout, loaded reel, winch slip, hydraulics, cab muffling and separate paper audio")
	quit(int(failures>0))
