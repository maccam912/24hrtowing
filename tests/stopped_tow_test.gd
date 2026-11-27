extends "res://tests/wheel_lift_test.gd"

func run() -> void:
	root.add_child(road)
	rig = Rig.new()
	road.add_child(rig)
	rig.setup(road)
	await physics_frame
	for eye: int in [-1,1]:
		road.crossfall = 0.
		attach_vehicle("hazard",2,eye)
		var base: Dictionary = rig.save_state()
		for bearing: float in [0.,PI]:
			for fps: int in [30,60]:
				for bank: float in [-.035,0.,.035]:
					road.crossfall = bank
					var at := Vector3(400,0,225)
					at.y = road.ground_height(at.x,at.z)
					var saved := base.duplicate(true)
					saved.heading = bearing
					saved.truck = rig.pack_point(at)
					saved.erase("ride")
					saved.car_rot = rig.pack_point(Vector3(0,bearing+(PI if eye>0 else 0.),0.))
					saved.car = rig.pack_point(at+Vector3.BACK.rotated(Vector3.UP,bearing)*7.13)
					rig.restore_state(saved)
					var dt := 1./fps
					for tick in 5*fps:
						rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,dt)
					for tick in 2*fps:
						rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,dt)
					var stopped := bend()
					var name := "%d fps, %d degrees, eye %d, crossfall %.3f" % [fps,roundi(rad_to_deg(bearing)),eye,bank]
					require(absf(rig.speed)<.001 and absf(stopped)<deg_to_rad(.2),"straight braking keeps the free axle in line: "+name)
					for tick in 12*fps:
						rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,dt)
					require(absf(angle_difference(stopped,bend()))<deg_to_rad(.05),"waiting at a stop cannot steer a strapped axle: "+name)
					for tick in 3*fps:
						rig.set_controls(Vector2(.8,-1),Vector2.ZERO,false,false,dt)
					for tick in 2*fps:
						rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,true,dt)
					var corner := bend()
					require(absf(corner)>deg_to_rad(8.),"a forward corner articulates the load: "+name)
					var parked:Dictionary = JSON.parse_string(JSON.stringify(rig.save_state()))
					rig.restore_state(parked)
					rig.in_cab = false
					for tick in 8*fps:
						rig.set_controls(Vector2.ZERO,Vector2.ZERO,false,false,dt)
					require(absf(angle_difference(corner,bend()))<deg_to_rad(.05),"a bent tow stays as parked through reload and cab exit: "+name)
					check_baskets()
					rig.in_cab = true
					for tick in 8*fps:
						rig.set_controls(Vector2(0,-1),Vector2.ZERO,false,false,dt)
					require(absf(bend())<deg_to_rad(.3),"straight travel draws the tow back into line: "+name)
	road.queue_free()
	await process_frame
	if not failed: print("CHECKS PASSED — stopped and moving tows at both frame rates, headings, hooked axles and road cambers")
	quit(int(failed))
