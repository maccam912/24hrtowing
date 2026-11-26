extends "res://tests/wheel_lift_test.gd"

func run() -> void:
	root.add_child(road)
	rig=Rig.new()
	road.add_child(rig)
	rig.setup(road)
	await physics_frame
	for eye: int in [-1,1]:
		attach_vehicle("hazard",2,eye)
		rig.truck_tracks.restore([])
		rig.tow_tracks.restore([])
		for tick in 210: rig.set_controls(Vector2(.75,-1),Vector2.ZERO,false,false,STEP)
		var marks: Array = rig.tow_tracks.snapshot()
		require(marks.size()>2 and rig.truck_tracks.history.size()>2,"the free axle and tandem both mark a loaded turn")
		var rear: Vector3 = rig.car.to_global(Vector3(0,rig.road_wheels.radius,-eye*rig.road_wheels.axle_z))
		var last: Array = marks.back()
		require(Vector2(rear.x,rear.z).distance_to(Vector2(last[0],last[1])*.01)<.95,"the freshest pair belongs to the axle rolling on snow")
		require(absf(angle_difference(deg_to_rad(last[2]*.1),rig.car.rotation.y))<.22,"a curved track follows the car's angle")
		for tick in 90: rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,STEP)
		var state: Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
		var tire_count: int = rig.tow_tracks.multimesh.visible_instance_count
		var transforms := []
		for i in tire_count: transforms.append(rig.tow_tracks.multimesh.get_instance_transform(i))
		rig.restore_state(state)
		for tick in 120: rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,STEP)
		require(rig.tow_tracks.multimesh.visible_instance_count==tire_count,"holding still and restoring the haul make no extra marks")
		for i in tire_count:
			require(transforms[i].is_equal_approx(rig.tow_tracks.multimesh.get_instance_transform(i)),"the same tire mark survives restart")
		state.erase("snow_tracks")
		rig.restore_state(state)
		require(rig.loaded and rig.tow_tracks.history.is_empty(),"older tickets still open at their saved tow angle")
	attach_vehicle("hold",0,-1)
	for tick in 170: rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,STEP)
	require(rig.tow_tracks.history.back()[4]==10,"a dolly leaves narrow caster tracks outside its locked tires")
	var before: int=rig.tow_tracks.history.size()
	rig.use_rollback(true)
	rig.speed=2.
	rig._lay_tracks()
	require(rig.tow_tracks.history.size()==before,"a car lifted onto the carrier bed leaves no tire tracks")
	# A long shift wraps in order, and loading a partial or invalid row is harmless.
	var tape=rig.tow_tracks
	tape.restore([[1],["bad",0,0,88,22],[0,0,0,88,0]])
	for i in tape.CAPACITY+11: tape.mark(Vector3(0,0,i),0.,.88,.22)
	var latest: Array=tape.snapshot()
	require(latest.size()==tape.CAPACITY and latest.front()[1]==1100 and latest.back()[1]==(tape.CAPACITY+10)*100,"the oldest overlapping tire marks wear out first")
	tape.restore(latest)
	require(tape.snapshot()==latest and tape.multimesh.visible_instance_count==tape.CAPACITY*2,"the bounded trail has the same chronology after reloading")
	road.queue_free()
	await process_frame
	if not failed: print("CHECKS PASSED — the rolling axle inscribes its turn, a stopped or carried car makes no marks, and tracks survive resuming the shift")
	quit(int(failed))
