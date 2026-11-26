extends Node3D

signal recovered(kind:String)
signal dropped
signal sound_event(id:String)

const TreeRecovery := preload("res://scripts/tree_recovery.gd")
const Truck = preload("res://scripts/rig_truck.gd")
const Scene = preload("res://scripts/rig_scene.gd")
const Semi := preload("res://scripts/semitrailer.gd")
const Reserve := preload("res://scripts/reserve_tank.gd")
const Tanker := preload("res://scripts/milk_tanker.gd")
const Dairy := preload("res://scripts/dairy_transfer.gd")
const RiverLanes := preload("res://scripts/river_lanes.gd")
const DepartingDriver := preload("res://scripts/departing_driver.gd")
const VehicleDrifts = preload("res://scripts/vehicle_drifts.gd")
const Kit = preload("res://scripts/rig_mesh.gd")
const YardDrop = preload("res://scripts/yard_drop.gd")
const GAME_MILE := 400.0
const CABLE_REACH := 37.0
const ICE_LINE := 52.0
const WINCH_FUEL_PER_SECOND := 0.00013
const DRY_RIG_HINT := "Out of diesel. Get in the cab and radio for a fuel can. The rigging can stay in place."
const BOOM_REACH := 15.0
const WALK_EYES := 1.68
const FOOTSTEP_DISTANCE := 2.1
const MPH_PER_MPS := 2.237
const MAX_SPEED := 40.0 / MPH_PER_MPS
const MAX_LOADED := 34.0 / MPH_PER_MPS
const IDLE_RPM := 680.0
# Road speeds in m/s at 2050 RPM, from first gear to overdrive.
const GEAR_TOP_SPEEDS: Array[float] = [4.4, 7.7, 12.0, 17.5, 23.0, 29.5]
const MAX_STEER_ANGLE := deg_to_rad(36.0)
const START_ODO := 82146.2
const CHASE_ELEVATION := 0.25
var world: Node3D
var truck:Node3D
var body:Node3D
var eyes:=Camera3D.new()
var torch:=SpotLight3D.new()
var car:Node3D
var semi: Semi
var tanker: Tanker
var aux_tank: Reserve
var reserve_fuel := 0.0
var car_lamps:Node3D
var warning_triangle: Node3D
var flash_time:=0.0
var tree_recovery: TreeRecovery
var special_work := 0.0
var second_line := false
var sighting_calm := 0.0
var sighting_light := Vector3.INF
var electrical_fade := 0.0
var witness:Node3D
var survey_passenger: Node3D
var flame:Node3D
var chocks:Node3D
var dollies:Node3D
var cable:=MeshInstance3D.new()
var cable_mesh:=ImmediateMesh.new()
var cable_mat:=StandardMaterial3D.new()
var tracker:MultiMeshInstance3D
var track_index:=0
var track_count:=0
var track_previous:=Vector3.INF
var camera_yaw:=0.0
var camera_pitch:=-.067
var driving_view := "chase"
var chase_heading := 0.0
var chase_orbit := 0.0
var chase_elevation := CHASE_ELEVATION
var chase_look_hold := 0.0
var chase_scene_weight := 0.0
var chase_scene_offset := Vector3.ZERO
var in_cab:=true
var foot:=Vector3.ZERO
var speed:=0.0
var motion:=Vector3.ZERO # Velocity at the rear tandem, in world space.
var steering:=0.0 # Equivalent front road-wheel angle in radians, positive right.
var heading:=0.0
var acceleration:=0.0
var drive_gear := 0
var engine_rpm := IDLE_RPM
var engine_load := 0.0
var odo:=START_ODO
var fuel:=.84
const HOT_COFFEE_SECONDS := 120.0
var warmth:=1.0
var climate := preload("res://scripts/cab_heater.gd").new()
var coffee_left := 0.0
var spot_on := false
var wear:=0.0
var ground_spring:=0.0
var pitch:=0.0
var roll:=0.0
var phase:="idle"
var kind:=""
var loaded:=false
var working:=false
var tension:=0.0
var job_site:=Vector3.ZERO
var job_yaw:=0.0
var vehicle_identity := {}
var line_end:=-1
var free_line:=0.0
var reverse_timer:=0.0
var slip_cooldown:=0.0
var departures: Array[DepartingDriver] = []
const RiderWalk := preload("res://scripts/passenger_walk.gd")
const Rides := preload("res://scripts/passenger_call.gd")
var boarding_walk: RiderWalk
var exiting_riders: Array[RiderWalk] = []
var walked:=0.0
var dropoff: Dictionary:
	get:
		if tanker: return Dairy.DROP
		return RiverLanes.DROP if semi else YardDrop.for_vehicle(kind)
var ground_period:=0.0
var ground_targets:=Vector3.ZERO
var assist:=true
var tire_chains:=false:
	set(value):
		tire_chains=value
		if body:
			body.set_chains(value)
var snatch_block := false
var auxiliary_drum: Node3D
var second_winch := false:
	set(value):
		second_winch = value
		if body and value and not auxiliary_drum:
			auxiliary_drum = Semi.fit_auxiliary_drum(body)
		if auxiliary_drum:
			auxiliary_drum.visible = value
var pulley: Node3D
var highlight:MeshInstance3D
var info:=""
var info_timer:=0.0
var _ready_to_run:=false

func setup(county:Node3D) -> void:
	if _ready_to_run:
		return
	world=county
	truck=Kit.joint(self,Vector3.ZERO,"Wrecker")
	body=Truck.new()
	truck.add_child(body)
	body.build()
	body.set_chains(tire_chains)
	if second_winch:
		auxiliary_drum = Semi.fit_auxiliary_drum(body)
	pulley = Scene.snatch_block(self)
	add_child(eyes)
	eyes.name="OperatorsEyes"
	eyes.make_current()
	eyes.near=.045
	eyes.far=570.0
	eyes.fov=76.0
	eyes.add_child(torch)
	torch.light_color=Color("#ece6ce")
	torch.light_energy=2.2
	torch.spot_range=29
	torch.spot_angle=24
	torch.spot_attenuation=.80
	torch.shadow_enabled=true
	torch.shadow_bias=.28
	torch.shadow_normal_bias=2.8
	torch.position=Vector3(.15,-.18,-.10)
	torch.visible=false
	cable_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	cable_mat.albedo_color=Color("#7f8683")
	cable_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	cable.mesh=cable_mesh
	add_child(cable)
	highlight=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=.079
	ring.outer_radius=.099
	ring.rings=16
	ring.ring_segments=4
	var mark:=StandardMaterial3D.new()
	mark.albedo_color=Color("#e2c8aa")
	mark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material=mark
	highlight.mesh=ring
	add_child(highlight)
	highlight.visible=false
	_build_tracks()
	_ready_to_run=true
	set_spawn(Vector3.ZERO)

func offer_front_seat() -> bool:
	if kind != "passenger" or phase != "scene" or not witness or not is_stopped():
		return false
	var walk := RiderWalk.new(witness,vehicle_identity.driver_variant)
	if not walk.plot(self,_passenger_step(),false,false):
		_note("Leave room beside the passenger door and offer the ride again.",5)
		return false
	boarding_walk = walk
	phase = "boarding"
	return true

func _passenger_step() -> Vector3:
	return truck.to_global(Vector3(1.78,0,Truck.DOOR.z))

func _seat_rider() -> void:
	witness.hide()
	phase = "passenger"
	set_survey_passenger(true,true)
	boarding_walk = null

func let_rider_out(ticket: Dictionary) -> bool:
	if kind != "passenger" or phase != "passenger" or not is_stopped():
		return false
	var memorial: bool = Rides.rider(ticket).drop == "memorial"
	var threshold := Rides.inside_door(ticket)
	var sidewalk := Vector3(threshold.x,0,threshold.z-(1.5 if memorial else 2.25))
	var walker := RiderWalk.new(witness,vehicle_identity.driver_variant)
	witness.position = _passenger_step()
	witness.position.y = _ground(witness.position)
	if _obstructed(truck.to_global(Vector3(0,.80,Truck.DOOR.z)),truck.global_basis.x*1.80) or not walker.plot(self,sidewalk,true,memorial):
		_note("Pull ahead a little. The passenger needs a clear step to the curb.",5)
		return false
	walker.entering_store = not memorial
	walker.route.append(threshold)
	witness.show()
	witness = null
	exiting_riders.append(walker)
	set_survey_passenger(false)
	sound_event.emit("door")
	return true

func _advance_riders(dt: float) -> void:
	if boarding_walk:
		if not is_stopped():
			boarding_walk = null
			phase = "scene"
			witness.get_node("AnimationPlayer").play("idle")
			_note("The driver stepped back. Park before offering the front seat.",5)
		elif boarding_walk.advance(self,dt):
			_seat_rider()
			sound_event.emit("door")
			_note("Passenger aboard.",3)
	for i in range(exiting_riders.size()-1,-1,-1):
		var walker := exiting_riders[i]
		if walker.advance(self,dt):
			walker.person.queue_free()
			exiting_riders.remove_at(i)

func set_survey_passenger(on_board: bool, rider:=false) -> void:
	body.seat_gear.visible = not on_board
	var model := int(vehicle_identity.get("driver_variant",2)) if rider else 3
	if on_board and is_instance_valid(survey_passenger) and survey_passenger.get_meta("model",-1) != model:
		survey_passenger.hide()
		survey_passenger.queue_free()
		survey_passenger=null
	if on_board and not is_instance_valid(survey_passenger):
		survey_passenger = Scene.person(body,false,model)
		survey_passenger.name = "RoadPassenger" if rider else "TouVang"
		survey_passenger.set_meta("model",model)
		survey_passenger.position = Vector3(.54, 1.05, -.43)
		survey_passenger.rotation.y = .16
		var animation := survey_passenger.get_node("AnimationPlayer") as AnimationPlayer
		animation.get_animation("seated").loop_mode = Animation.LOOP_LINEAR
		animation.play("seated")
		animation.advance(0.0)
	if is_instance_valid(survey_passenger):
		survey_passenger.visible = on_board

func set_spawn(at:Vector3, yaw:=0.0) -> void:
	truck.position=at
	truck.position.y=_ground(at)
	heading=yaw
	chase_heading=yaw
	truck.rotation.y=yaw
	body.rotation=Vector3.ZERO
	ground_spring=0
	ground_period=0
	ground_targets=Vector3(truck.position.y,0,0)
	foot=at
	walked=0.0
	_update_eyes()

func recover_to_yard(at: Vector3, yaw: float) -> void:
	in_cab = true
	_stop_motion()
	camera_yaw = 0.0
	camera_pitch = -.067
	info_timer = 0.0
	_reset_chase()
	set_spawn(at,yaw)
	eyes.make_current()

func fit_reserve(owned: bool) -> void:
	if owned and not aux_tank:
		aux_tank = Reserve.new()
		aux_tank.install(body)
	if aux_tank:
		aux_tank.visible = owned
		aux_tank.set_reading(reserve_fuel if owned else 0)
	if not owned:
		reserve_fuel = 0.0

func reserve_valve_in_reach() -> bool:
	if in_cab or not is_stopped() or not aux_tank or not aux_tank.visible:
		return false
	var local := body.to_local(foot)
	return local.x > 1.1 and _in_range(body.to_global(Reserve.PUMP),1.95)

func reserve_hint() -> String:
	if reserve_fuel > .0001 and aux_tank and aux_tank.visible:
		return "Transfer reserve diesel at the curb-side bed rail, just behind the cab."
	return DRY_RIG_HINT

func _stop_motion() -> void:
	speed = 0.0
	motion = Vector3.ZERO
	acceleration = 0.0
	steering = 0.0
	pitch = 0.0
	roll = 0.0
	drive_gear = 0
	engine_load = 0.0
	engine_rpm = IDLE_RPM if fuel > 0 else 0.0
	reverse_timer = 0.0

func _ground(p:Vector3) -> float:
	if world and world.has_method("ground_height"):
		return world.ground_height(p.x,p.z)
	return 0.0

func _road(p:Vector3) -> float:
	if world and world.has_method("road_distance"):
		return world.road_distance(p.x,p.z)
	return 0.0

func _ray(a:Vector3,b:Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(a,b,1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _wheel_ground(x:float,z:float) -> float:
	var p:Vector3=truck.to_global(Vector3(x,0,z))
	var base:=_ground(p)
	var hit:=_ray(Vector3(p.x,base+1.1,p.z),Vector3(p.x,base-1.8,p.z))
	if not hit.is_empty() and absf(hit.position.y-base)<.45:
		return hit.position.y
	return base

func _suspension(dt:float) -> void:
	ground_period-=dt
	if ground_period<=0:
		ground_period=.065
		var fl:=_wheel_ground(-Truck.HALF_TRACK,Truck.FRONT_AXLE_Z)
		var fr:=_wheel_ground(Truck.HALF_TRACK,Truck.FRONT_AXLE_Z)
		var bl:=_wheel_ground(-Truck.HALF_TRACK,Truck.REAR_AXLE_Z)
		var br:=_wheel_ground(Truck.HALF_TRACK,Truck.REAR_AXLE_Z)
		var loaded_sag:=.058 if loaded else 0.0
		ground_targets=Vector3((fl+fr+bl+br)*.25-loaded_sag,atan2((fl+fr-bl-br)*.5,Truck.WHEELBASE)+loaded_sag*.50,atan2((fr+br-fl-bl)*.5,2.0*Truck.HALF_TRACK))
	ground_spring+=((ground_targets.x-truck.position.y)*60.0-ground_spring*13.0)*dt
	truck.position.y+=ground_spring*dt
	var sprung_pitch:=ground_targets.y+clampf(acceleration*.003,-.036,.024)
	pitch=lerpf(pitch,sprung_pitch,1-exp(-6.8*dt))
	var lateral_accel := speed * speed * tan(steering) / Truck.WHEELBASE
	roll=lerpf(roll,ground_targets.z+clampf(lateral_accel*.008,-.06,.06),1-exp(-6*dt))
	body.rotation=Vector3(pitch,0,roll)

func _obstructed(a:Vector3,displacement:Vector3) -> bool:
	if displacement.length_squared()<.000001:
		return false
	var hit:=_ray(a,a+displacement)
	return not hit.is_empty() and absf((hit.normal as Vector3).y)<.72

func _truck_obstacle(step:Vector3, turn:float) -> bool:
	if step.is_zero_approx(): return false
	for z in [-4.06,4.22]:
		for x in [-1.12,1.12]:
			var corner:Vector3=truck.global_basis*Vector3(x,.91,z)
			var sweep:=step+corner.rotated(Vector3.UP,turn)-corner
			if _obstructed(truck.global_position+corner,sweep+sweep.normalized()*.08):
				return true
	# Out in a work scene, the bumper stops against the casualty.
	if car and phase in ["scene","flared","cable","rigged"]:
		if semi and semi.crosses_wrecker(truck,step,turn,speed): return true
		var tip_offset:Vector3=truck.global_basis.z*(-signf(speed)*3.95)
		var at:=car.to_local(truck.global_position+step+tip_offset.rotated(Vector3.UP,turn))
		var old:=car.to_local(truck.global_position+tip_offset)
		var size: Vector3 = car.get_meta("body_size")
		if absf(at.x)<size.x+1.04 and absf(at.z)<size.z-.04 and Vector2(at.x,at.z).length_squared()<Vector2(old.x,old.z).length_squared():
			return true
	if loaded and tanker:
		var pose := forecast_tow(step,turn,Tanker.FRONT_AXLE,Tanker.REAR_AXLE,Tanker.WHEEL_RADIUS)
		return load_obstructed(tanker,pose,Tanker.SIZE.x,1.0,[-Tanker.SIZE.z,0,Tanker.SIZE.z])
	return loaded and semi != null and semi.tow_obstructed(self,step,turn)

func forecast_tow(step: Vector3, turn: float, front_axle: float, rear_axle: float, wheel_height: float) -> Transform3D:
	var next_hitch := truck.position+step+(_hitch()-truck.position).rotated(Vector3.UP,turn)
	var axle_offset := car.to_global(Vector3(0,wheel_height,rear_axle))-next_hitch
	var next_heading := heading+turn
	var yaw := next_heading+clampf(angle_difference(next_heading,atan2(axle_offset.x,axle_offset.z)),-PI/3,PI/3)
	var pose := Basis(Vector3.UP,yaw)
	var at := next_hitch-pose*Vector3(0,0,front_axle)
	at.y = car.position.y
	return Transform3D(pose,at)

func load_obstructed(payload: Node3D, pose: Transform3D, half_width: float, probe_height: float, stations: Array) -> bool:
	for side:float in [-1.,1.]:
		for z:float in stations:
			var local := Vector3(side*half_width,probe_height,z)
			var from := payload.to_global(local)
			var sweep := pose*local-from
			sweep.y = 0
			if _obstructed(from,sweep): return true
	return false

func set_controls(move:Vector2,look:Vector2,operate:bool,brake:bool,dt:float,on_ladder := false) -> void:
	if not _ready_to_run: return
	dt=minf(dt,.0667)
	info_timer=maxf(0,info_timer-dt)
	if in_cab and driving_view == "chase":
		if not look.is_zero_approx() or absf(speed)>1.0 or chase_scene_weight<1.0:
			chase_scene_weight=move_toward(chase_scene_weight,0.0,dt*1.5)
		chase_orbit = wrapf(chase_orbit-look.x,-PI,PI)
		chase_elevation = clampf(chase_elevation+look.y,-0.08,0.95)
		if not look.is_zero_approx():
			chase_look_hold = 1.4
		else:
			chase_look_hold = maxf(0.0,chase_look_hold-dt)
			if chase_look_hold == 0.0 and absf(speed) > 1.5:
				chase_orbit = lerp_angle(chase_orbit,0.0,1.0-exp(-2.5*dt))
				chase_elevation = lerpf(chase_elevation,CHASE_ELEVATION,1.0-exp(-2.5*dt))
	else:
		camera_yaw=wrapf(camera_yaw-look.x,-PI,PI)
		camera_pitch=clampf(camera_pitch-look.y,-1.34,1.29)
	if in_cab:
		_drive(move,brake,dt)
		chase_heading = lerp_angle(chase_heading,heading,1.0-exp(-5.5*dt))
	else:
		_update_engine(0.0,dt)
		if not on_ladder and not (tree_recovery and tree_recovery.holds_operator(move)):
			_walk(move,dt)
		_face_operator(dt)
		_suspension(dt)
	body.weather_mirrors(dt,sighting_calm,speed,fuel > 0)
	if body.search_beam:
		if in_cab:
			var spot_yaw := camera_yaw if driving_view == "cab" else wrapf(chase_heading+chase_orbit-heading,-PI,PI)
			body.point_spot(spot_on,spot_yaw,camera_pitch if driving_view == "cab" else -.06)
		elif body.search_on:
			body.point_spot(false,0,0)
	if tree_recovery and tree_recovery.controls:
		tree_recovery.stroke(self,move,dt)
		tree_recovery.frame_load(self,look,dt)
	else:
		_winch(operate,dt)
	_trail(dt)
	_update_eyes()
	_cable_curve()
	_update_highlight()
	climate.advance(self,dt)
	if fuel>0:
		fuel=maxf(fuel-dt*.000017,0)
	body.glass_material.set_shader_parameter("cold",1.0-climate.air)
	body.move_driver_window(climate.cracked,dt)
	body.animate(dt,speed,steering,engine_rpm,loaded,tension,fuel,odo,_compass_degrees(),in_cab and driving_view == "cab",near_casualty(55.0))

func _drive(move:Vector2, handbrake:bool, dt:float) -> void:
	var forward:Vector3=-truck.global_basis.z
	var throttle:float=-move.y
	var road_dist:=_road(truck.position)
	var offroad:=smoothstep(5.1,11.0,road_dist)
	# A packed yard and parking lots provide the same support as a road.
	if Rect2(-65,-90,68,61).has_point(Vector2(truck.position.x,truck.position.z)) or RiverLanes.LOT.has_point(Vector2(truck.position.x,truck.position.z)):
		offroad=0
	var prev:=speed
	var packed_speed := MAX_LOADED if loaded else MAX_SPEED
	var snow_speed := 7.2 if loaded else 9.1
	if tire_chains:
		snow_speed *= 1.30
	var load_factor := 0.80 if loaded and vehicle_identity.get("heavy_recovery",false) else 1.0
	if tanker and loaded:
		load_factor *= .88
		if handbrake:
			load_factor *= 1.0-clampf(tanker.surge.y,0,1)*.36
		if Dairy.APRON.has_point(Vector2(truck.position.x,truck.position.z)):
			offroad = 0
	var max_forward := lerpf(packed_speed,snow_speed,offroad) * load_factor
	var tire_grip:float=1.29 if tire_chains else 1.0
	var coast_decel := .56 + offroad*.78 + speed*speed*.0018
	var demand := 0.0
	if is_chocked():
		speed = 0.0
		if fuel > 0.0 and absf(throttle) > .04 and info_timer <= 0:
			_note("Wheels chocked. Step out and finish or stow the rigging.",4)
	elif handbrake:
		speed=move_toward(speed,0,dt*(6.45 if loaded else 9.35)*tire_grip*load_factor)
		if absf(speed)<.20 and absf(prev)>=.20: sound_event.emit("air_brake")
	elif absf(throttle)>.04 and fuel > 0.0:
		var reversing:=speed*throttle<-.20
		var target:float=throttle*(max_forward if throttle>0 else 5.15)
		var accel := 2.44
		if reversing:
			accel = (4.8 if loaded else 7.6) * tire_grip
		elif throttle > 0:
			# The diesel pulls steadily out of the yard, then gains speed slowly above 30 mph.
			var road_pull := lerpf(1.0, .10, smoothstep(8.5, 13.4, speed))
			accel = (1.0 if loaded else 1.45) * road_pull
		if tire_chains and not reversing:
			accel *= lerpf(1.0,1.28,offroad)
		var rate := coast_decel if speed > target and throttle > 0 else accel * load_factor
		speed=move_toward(speed,target,rate*dt)
		if not reversing:
			# Ease back once the truck reaches its governed road speed.
			var pulling := smoothstep(0.0, 2.5, absf(target)-absf(speed))
			demand = absf(throttle) * lerpf(.52, .87, pulling)
			if loaded:
				demand = minf(1.0, demand * 1.2)
	else:
		speed=move_toward(speed,0,coast_decel*dt)
	if fuel<=0 and info_timer<=0: _note(reserve_hint() if reserve_fuel > .0001 else "Tank empty. Use the cab radio to call Arlene for a fuel can.",6.0)
	# Digital controls use full steering lock in the yard and finer angles at road speed.
	var cornering_grip := (3.65 if loaded else 5.1) * tire_grip
	if loaded and tanker:
		cornering_grip *= 1.0-clampf(absf(tanker.surge.x),0,1)*.32
	var lock_angle := minf(MAX_STEER_ANGLE, atan2(Truck.WHEELBASE*cornering_grip, speed*speed))
	var steer_rate := lock_angle * (2.0 if absf(move.x) > .04 else 2.8)
	steering = move_toward(steering, clampf(move.x,-1,1)*lock_angle, steer_rate*dt)

	# Integrate the rear tandem along its rolling direction. The cab swings around
	# that axle, and signed travel automatically reverses the arc when backing up.
	var distance := speed * dt
	var turn := -distance * tan(steering) / Truck.WHEELBASE
	var midway := forward.rotated(Vector3.UP, turn*.5)
	var right := midway.cross(Vector3.UP)
	var next_forward := forward.rotated(Vector3.UP,turn)
	# Above yard speed, momentum can push the drive tires sideways on snow.
	var slip_limit := maxf(0.0,absf(speed)-6.0) * .17
	var lateral_speed := clampf(motion.dot(right)*exp(-3.1*tire_grip*dt),-slip_limit,slip_limit)
	if loaded and tanker:
		lateral_speed += tanker.surge.x*minf(absf(speed)*.25,3.0)*dt
	motion = midway*speed + right*lateral_speed
	var step := motion*dt + (next_forward-forward)*Truck.REAR_AXLE_Z
	if _truck_obstacle(step,turn):
		wear=minf(1,wear+clampf(absf(speed)-4,0,12)*.0015)
		motion=Vector3.ZERO
		speed=0
		step=Vector3.ZERO
		turn=0.0
	# The storm boundary softens to a stop; reverse remains available.
	var p:=truck.position+step
	if (absf(p.x)>1150 or p.x< -775 or p.z>970 or p.z< -580) and Vector2(p.x,p.z).length_squared()>Vector2(truck.position.x,truck.position.z).length_squared():
		step=Vector3.ZERO
		turn=0.0
		motion=Vector3.ZERO
		speed=0
	truck.position+=step
	heading=wrapf(heading+turn,-PI,PI)
	truck.rotation.y=heading
	var driven := absf(speed)*dt
	odo+=driven/GAME_MILE
	fuel=maxf(0,fuel-driven*(.000065 if loaded else .000046))
	acceleration=clampf((speed-prev)/dt,-11,6)
	if loaded and tanker:
		tanker.step_liquid(dt,Vector2(-speed*speed*tan(steering)/Truck.WHEELBASE*.31,-acceleration*.23))
	_update_engine(demand,dt)
	reverse_timer=maxf(0.0,reverse_timer-dt)
	if speed<-.10 and is_zero_approx(reverse_timer):
		reverse_timer=1.0
		sound_event.emit("reverse")
	_suspension(dt)
	_lay_tracks()

func _update_engine(demand:float, dt:float) -> void:
	# Downshift below the upshift point so easing off won't hunt between gears.
	while drive_gear < GEAR_TOP_SPEEDS.size()-1 and speed > GEAR_TOP_SPEEDS[drive_gear]:
		drive_gear += 1
	while drive_gear > 0 and speed < GEAR_TOP_SPEEDS[drive_gear-1] * .78:
		drive_gear -= 1
	var gear_speed := 6.1 if speed < 0.0 else GEAR_TOP_SPEEDS[drive_gear]
	engine_load = demand
	var target_rpm := maxf(IDLE_RPM + 570.0*demand, 2050.0*absf(speed)/gear_speed)
	if fuel <= 0:
		target_rpm = 0.0
		engine_load = 0.0
	engine_rpm = lerpf(engine_rpm, target_rpm, 1.0-exp(-6.0*dt))

func _walk(move:Vector2, dt:float) -> void:
	var dir:=Vector3(move.x,0,move.y).rotated(Vector3.UP,camera_yaw)
	var start:=foot
	var dest:=foot+dir.limit_length(1)*dt*(3.55 if phase!="cable" else 3.0)
	var local:=truck.to_local(dest)
	if absf(local.x)<1.34 and local.z<4.22 and local.z> -4.11:
		var before:=truck.to_local(foot)
		if absf(before.x)>=1.32: local.x=signf(before.x)*1.35
		else: local.z=4.23 if before.z>0 else -4.12
		dest=truck.to_global(local)
	if car and car.visible:
		var c:=car.to_local(dest)
		var size: Vector3 = car.get_meta("body_size")
		if absf(c.x)<size.x+.14 and absf(c.z)<size.z+.18:
			var old:=car.to_local(foot)
			if absf(old.x)>size.x+.11: c.x=signf(old.x)*(size.x+.15)
			else: c.z=(size.z+.19) * (1.0 if old.z>0 else -1.0)
			dest=car.to_global(c)
		if semi: dest = semi.outside_trailer(dest,foot)
	var eye:=foot+Vector3.UP*.80
	if _obstructed(eye,dest-foot+dir*.17):
		var x_move:=Vector3(dest.x-foot.x,0,0)
		var z_move:=Vector3(0,0,dest.z-foot.z)
		if _obstructed(eye,x_move+x_move.normalized()*.17): dest.x=foot.x
		if _obstructed(eye,z_move+z_move.normalized()*.17): dest.z=foot.z
	dest.y=_ground(dest)
	foot=dest
	walked+=Vector2(foot.x-start.x,foot.z-start.z).length()
	if walked>=FOOTSTEP_DISTANCE:
		walked-=FOOTSTEP_DISTANCE
		sound_event.emit("footstep")

func toggle_driving_view() -> void:
	if not in_cab:
		return
	driving_view = "cab" if driving_view == "chase" else "chase"
	camera_yaw = 0.0
	camera_pitch = -.067
	_reset_chase()
	_frame_nearby_car()
	_update_eyes()

func _reset_chase() -> void:
	chase_heading = heading
	chase_orbit = 0.0
	chase_elevation = CHASE_ELEVATION
	chase_look_hold = 0.0
	chase_scene_weight = 0.0

func _frame_nearby_car() -> void:
	if driving_view!="chase" or absf(speed)>.65 or phase not in ["scene","flared","departing"] or not near_casualty(CABLE_REACH):
		return
	# Across the shoulder, both vehicles are visible and the wrecker cannot
	# hide a car that was just behind it when the operator returned to the cab.
	chase_scene_offset=car.global_position-truck.global_position
	var side:=Vector3(-chase_scene_offset.z,0,chase_scene_offset.x).normalized()
	if side.dot(truck.global_basis.x)>0.0: side=-side
	var view:Vector3=(side*.85+truck.global_basis.z*.35).normalized()
	chase_orbit=wrapf(atan2(view.x,view.z)-heading,-PI,PI)
	chase_scene_weight=1.0

func _update_chase() -> void:
	# Start the boom above the cab so it can shorten over the roof in tight yards.
	var pivot := truck.global_position + Vector3.UP*3.7
	var behind := Vector3.BACK.rotated(Vector3.UP,chase_heading+chase_orbit)
	var length := 17.0 if loaded else 11.2
	var focus:Vector3=truck.global_position+Vector3.UP*2.05-behind*(.35 if loaded else 2.6)
	if chase_scene_weight>0.0 and car:
		pivot+=chase_scene_offset*.48*chase_scene_weight
		focus=focus.lerp(truck.global_position+chase_scene_offset*.48+Vector3.UP*1.2,chase_scene_weight)
		length+=chase_scene_offset.length()*.65*chase_scene_weight
	elif loaded and car:
		# Aim over the coupling, keeping the free axle in the lower half of the view.
		focus=truck.global_position.lerp(car.global_position,.32)+Vector3.UP*1.45
	var offset := (behind*cos(chase_elevation) + Vector3.UP*sin(chase_elevation))*length
	var hit := _ray(pivot,pivot+offset)
	if not hit.is_empty():
		offset = offset.normalized()*maxf(0.0,pivot.distance_to(hit.position)-0.35)
	var at := pivot + offset
	at.y = maxf(at.y,_ground(at)+0.55)
	eyes.global_position = at
	eyes.look_at(focus,Vector3.UP)

func _update_eyes() -> void:
	eyes.fov = 62.0 if in_cab and driving_view == "chase" else 76.0
	if in_cab and driving_view == "chase":
		_update_chase()
	elif in_cab:
		var view:=body.global_transform*Transform3D(Basis.from_euler(Vector3(camera_pitch,camera_yaw,0),EULER_ORDER_YXZ),Truck.EYE)
		eyes.global_transform=view
	else:
		eyes.global_position=foot+Vector3.UP*WALK_EYES
		eyes.rotation=Vector3(camera_pitch,camera_yaw,0)
	torch.visible=not in_cab

func wipeable_mirror() -> int:
	if in_cab:
		return -1
	for i in body.mirror_centers.size():
		if body.mirror_ice[i] < .12:
			continue
		var target: Vector3 = body.mirror_centers[i].global_position
		var towards := target-eyes.global_position
		if towards.length() < 2.6 and towards.normalized().dot(-eyes.global_basis.z) > .96:
			return i
	return -1

func _heading_degrees() -> float:
	return fposmod(-rad_to_deg(heading),360)

func set_sighting(calm: float, light_at: Vector3, electrical: float) -> void:
	sighting_calm = clampf(calm,0,1)
	sighting_light = light_at
	# Preserve road visibility when braking hard or working up a grade.
	electrical_fade = clampf(electrical,0,1)
	if absf(acceleration) > 4.5 or absf(pitch) > .10:
		electrical_fade = 0.0
	body.set_electrics(electrical_fade)

func _compass_degrees() -> float:
	if sighting_light == Vector3.INF:
		return _heading_degrees()
	var toward := sighting_light - truck.global_position
	var bearing := atan2(toward.x,-toward.z)
	return fposmod(rad_to_deg(lerp_angle(deg_to_rad(_heading_degrees()),bearing,sighting_calm)),360.0)

static func uses_warning_triangle(job_kind: String, ticket: Dictionary) -> bool:
	return job_kind in ["ditch","hazard"] and not ticket.has("case_id") and ticket.get("recovery","") in ["","semi","milk"]

func start_job(job_kind:String,target:Vector3,yaw:float,ticket := {},initial_phase := "scene") -> void:
	end_job()
	kind=job_kind
	phase=initial_phase
	job_site=target
	job_yaw=yaw
	# Saves made before dispatch recorded a model used the site to choose one.
	var old_variant: int = (2 if target.x>0 else 3) if kind=="hazard" else (0 if target.x<100 else 1)
	var variant := int(ticket.get("variant",old_variant))
	vehicle_identity = {"variant":variant,"driver_variant":int(ticket.get("driver_variant",old_variant)),
		"plate":ticket.get("plate",""),"vin":ticket.get("vin",""),"heavy_recovery":ticket.get("heavy_recovery",false)}
	for key in ["case_id", "rider", "recovery", "fold", "paint", "gallons", "seal", "mail", "running", "open_door", "untaped"]:
		if ticket.has(key):
			vehicle_identity[key] = ticket[key]
	if ticket.has("checked_tape"):
		vehicle_identity.checked_tape = ticket.checked_tape
	if kind == "hold":
		vehicle_identity.open_door = true
	car=Scene.car(self,kind,variant,vehicle_identity)
	semi = car as Semi
	tanker = car as Tanker
	car.position=Vector3(target.x,_ground(target),target.z)
	car.rotation.y=yaw
	match _recovery():
		"milk":
			var left := car.to_global(Vector3.LEFT*Tanker.SIZE.x)
			var right := car.to_global(Vector3.RIGHT*Tanker.SIZE.x)
			car.rotation.z = clampf(atan2(_ground(right)-_ground(left),Tanker.SIZE.x*2),-.17,.17)
			VehicleDrifts.place(car,_ground)
		"semi":
			semi.park_at(car.position,yaw,vehicle_identity.get("fold",1.12),_ground)
		"roll":
			car.rotation.z = PI
			car.position.y += Scene.SEDAN_SIZE.y + 1.25
		"nose":
			car.rotation.x = -PI/2
			car.position.y += Scene.SEDAN_SIZE.z
		"roof", "tree":
			car.position.y += target.y if target.y > 0 else (4.75 if _recovery()=="roof" else 5.0)
		"":
			if kind == "hazard" and not vehicle_identity.get("running",false):
				VehicleDrifts.place(car, _ground)
			elif _county_plow():
				var nose := car.to_global(Vector3.FORWARD*3.4)
				var tail := car.to_global(Vector3.BACK*3.2)
				car.rotation.x = clampf(atan2(_ground(nose)-_ground(tail),6.6),-.17,.17)
				VehicleDrifts.place(car,_ground)
	if _recovery() == "tree": tree_recovery = TreeRecovery.new()
	_set_car_lamps("running" if _running_car() else "hazard")
	if phase == "scene" and uses_warning_triangle(kind,vehicle_identity):
		# Face traffic from either direction, on the road side of the car.
		# Dispatch parks cars at a slight yaw along the county's section roads.
		var road_yaw := snappedf(job_yaw, PI / 2.0)
		var across := Vector3.RIGHT.rotated(Vector3.UP,road_yaw)
		if _road(target + across) > _road(target - across):
			across = -across
		var ahead := 6.0 if _county_plow() or semi or tanker else 3.5
		var at := target + across * 1.8 + Vector3.FORWARD.rotated(Vector3.UP,road_yaw) * ahead
		at.y = _ground(at)
		warning_triangle = Scene.warning_triangle(self,at,road_yaw)
	if kind in ["ditch","hold","passenger"] or semi or tanker:
		witness=Scene.person(self,kind=="hold",vehicle_identity.driver_variant)
		var point:Vector3=car.to_global(Vector3(-2.4,0,1.65))
		witness.position=Vector3(point.x,_ground(point),point.z)
		witness.rotation.y=yaw-1.14
	_update_highlight()

func end_job() -> void:
	if tree_recovery: tree_recovery.clear_sling()
	tree_recovery = null
	boarding_walk = null
	# The customer keeps the same car and driver when the radio assigns a new scene.
	if kind=="passenger" and phase=="passenger":
		set_survey_passenger(false)
	if phase == "departing":
		car = null
		witness = null
	_clear_warning_triangle()
	for n in [car,witness,flame,chocks,dollies]:
		if is_instance_valid(n): n.queue_free()
	car=null
	semi=null
	tanker=null
	car_lamps=null
	flash_time=0
	witness=null
	flame=null
	chocks=null
	dollies=null
	phase="idle"
	kind=""
	vehicle_identity={}
	loaded=false
	working=false
	tension=0
	line_end=-1
	free_line=0
	special_work=0.0
	second_line=false
	if body:
		body.stow_boom()
		body.stinger.position.z=-1.31
		body.work_light.hide()
	if cable_mesh: cable_mesh.clear_surfaces()
	if highlight: highlight.visible=false

func _clear_warning_triangle() -> void:
	if warning_triangle:
		warning_triangle.hide()
		warning_triangle.queue_free()
		warning_triangle = null

func store_vehicle(job_kind:String,point:Vector3,yaw:float,ticket := {}) -> Node3D:
	var variant:=int(ticket.get("variant",3 if job_kind in ["bridge","river"] else 2))
	var model_kind:="hold" if job_kind=="hold" else "hazard"
	var stored:=Scene.car(self,model_kind,variant,ticket)
	stored.position=Vector3(point.x,_ground(point),point.z)
	stored.rotation.y=yaw
	if model_kind == "hazard":
		VehicleDrifts.place(stored, _ground)
	return stored

func _face_operator(dt: float) -> void:
	if not witness or not witness.visible or phase in ["boarding","departing"]:
		return
	var distance := _flat_distance(foot, witness.position)
	if distance < 0.4 or distance > 4.3:
		return
	var toward := foot - witness.position
	var yaw := atan2(-toward.x, -toward.z)
	witness.rotation.y = rotate_toward(witness.rotation.y, yaw, dt * 1.8)

func get_witness_position() -> Vector3:
	return witness.global_position if witness and witness.visible else Vector3.INF

func get_player_position() -> Vector3:
	return truck.global_position if in_cab else foot

func get_truck_position() -> Vector3:
	return truck.global_position

func get_camera() -> Camera3D:
	return eyes

func get_target_position() -> Vector3:
	return car.global_position if car else Vector3.INF

func near_casualty(radius:float) -> bool:
	return car and car.visible and _flat_distance(get_player_position(),car.global_position)<radius

func _flat_distance(a:Vector3,b:Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _panel() -> Vector3:
	return body.to_global(Truck.PANEL)

func _drum() -> Vector3:
	return body.to_global(Truck.DRUM)

func _hitch() -> Vector3:
	return body.stinger.to_global(Truck.HITCH)

func _eyelet(end:int) -> Vector3:
	var size: Vector3 = car.get_meta("body_size")
	return car.to_global(Vector3(0,size.y-.087,end*size.z*1.016))

func _nearest_eyelet() -> int:
	if tanker: return -1
	if _county_plow(): return 1
	return 1 if _flat_distance(foot,_eyelet(1))<_flat_distance(foot,_eyelet(-1)) else -1

func _county_plow() -> bool:
	return vehicle_identity.get("variant",-1) == Scene.Snowplow.VARIANT

func duane_on_scene() -> bool:
	if _county_plow() and phase != "done":
		return true
	for driver in departures:
		if driver.identity.get("variant",-1) == Scene.Snowplow.VARIANT:
			return true
	return false

func _reaches() -> bool:
	var reach := CABLE_REACH
	if _recovery() == "ice":
		reach = ICE_LINE
	elif _boom_job():
		reach = BOOM_REACH
	return car and _flat_distance(_drum(),car.position)<=reach

func _recovery() -> String:
	return vehicle_identity.get("recovery","")

func _boom_job() -> bool:
	return _recovery() in ["roof","tree"]

func _boom_landing() -> Vector3:
	var ground_start := Vector3(job_site.x,_ground(job_site),job_site.z)
	var toward := _drum()-ground_start
	toward.y = 0
	var travel := minf(8.25,toward.length()-2.5)
	var landing := ground_start+toward.normalized()*travel
	landing.y = _ground(landing)
	return landing

func _clear_to_lower() -> bool:
	var landing := _boom_landing()
	if _flat_distance(landing,job_site) < 5.9: return false
	# Check the actual car footprint under the raised boom before committing
	# to the lift. A car can't be lowered through the roof it is sitting on.
	for x: float in [-.96,.96]:
		for z: float in [-2.18,2.18]:
			var at := landing+Vector3(x,0,z).rotated(Vector3.UP,job_yaw)
			var hit := _ray(at+Vector3.UP*11,at+Vector3.UP*.55)
			if not hit.is_empty(): return false
	return true

func _roll_job() -> bool:
	return _recovery() in ["roll","nose"]

func _running_car() -> bool:
	return kind == "hold" or not _recovery().is_empty() or vehicle_identity.get("running",false)

func _side_eye(side: float) -> Vector3:
	# Two slings cradle the casualty from opposite sides. Both chains reach
	# the snow, including when the rear axle is high above the shoulder.
	var point := car.position + Vector3.RIGHT.rotated(Vector3.UP,car.rotation.y)*side
	point.y = _ground(point)+.62
	return point

func _in_range(at:Vector3,dist:float, require_facing:=true) -> bool:
	var offset:=at-eyes.global_position
	if _flat_distance(foot,at)>dist or absf(offset.y)>3:
		return false
	# Forgiving hands' reach for mobile. At the edge, turn toward what you want.
	return not require_facing or offset.length()<1.5 or (-eyes.global_basis.z).dot(offset.normalized())>-.13

func at_dropoff() -> bool:
	if semi: return loaded and semi.fits(RiverLanes.BAY)
	if tanker: return loaded and tanker.fits(Dairy.BAY)
	return loaded and is_instance_valid(car) and (YardDrop.contains(dropoff.center, car.position)
		or YardDrop.contains(dropoff.center, truck.position))

func wrecker_overlaps(area: Rect2) -> bool:
	# Include the forks behind the rear bumper, even after stowing the lift.
	var rear: float = Truck.HITCH.z + body.stinger.position.z + .32
	var outline := PackedVector2Array()
	for corner: Vector3 in [Vector3(-1.4,0,-4.2), Vector3(1.4,0,-4.2), Vector3(1.4,0,rear), Vector3(-1.4,0,rear)]:
		var p := truck.to_global(corner)
		outline.append(Vector2(p.x, p.z))
	var floor_outline := PackedVector2Array([area.position, Vector2(area.end.x, area.position.y),
		area.end, Vector2(area.position.x, area.end.y)])
	return not Geometry2D.intersect_polygons(outline, floor_outline).is_empty()

func is_stopped() -> bool:
	return speed == 0.0

func is_chocked() -> bool:
	return phase in ["cable","rigged","at_lift","dollies"]

func at_dry_rig_door() -> bool:
	return not in_cab and fuel <= 0.0 and is_chocked() and _at_door()

func action_id() -> String:
	if in_cab:
		return "exit" if is_stopped() else ""
	if at_dry_rig_door():
		return "enter"
	if kind=="passenger":
		return "enter" if _at_door() else ""
	var panel_range:=_in_range(_panel(),2.65)
	if tree_recovery:
		var nearby := tree_recovery.action(self,panel_range)
		if not nearby.is_empty(): return nearby
	if phase=="scene" and (_boom_job() or _recovery()=="ice") and panel_range:
		return "flare"
	if phase=="scene" and near_casualty(8.5) and (_in_range(car.position+Vector3.UP,8.5) or not _at_door()):
		return "flare"
	if phase=="flared" and tanker and not tanker.checked:
		if _in_range(tanker.to_global(Tanker.CABINET),2.5): return "milk_manifest"
		if panel_range: return "milk_seal"
	if phase=="flared" and panel_range:
		if not _reaches(): return "too_far"
		if semi and not second_winch: return "need_second_winch"
		if semi or tanker:
			var set_up := car.to_local(_drum())
			var nose:float = car.get_meta("body_size").z
			if set_up.z > -nose-.6 or absf(set_up.x)>12.: return "milk_position" if tanker else "freight_position"
		if _boom_job() and not _clear_to_lower(): return "boom_space"
		if _recovery()=="ice" and (_flat_distance(_drum(),job_site)<22.0 or _ground(truck.position)< -1.0): return "shore"
		return "need_block" if vehicle_identity.heavy_recovery and not snatch_block else "cable"
	if phase=="cable":
		if semi: return semi.cable_action(self,panel_range)
		if _boom_job() and panel_range: return "sling"
		if tree_recovery: return ""
		if _roll_job():
			if _in_range(_side_eye(1.0 if second_line else -1.0),2.35): return "check_line" if second_line else "roll_hook"
			return "restow" if panel_range else ""
		if _in_range(_eyelet(_nearest_eyelet()),2.45): return "attach"
		if _county_plow() and _in_range(_eyelet(-1),2.6): return "plow_blade"
		if panel_range: return "restow"
	if phase=="rigged":
		if panel_range: return "winch"
		if semi and semi.rigging=="both": return "enter" if _at_door() else ""
		if not _boom_job() and not _roll_job() and _in_range(_eyelet(line_end),1.8): return "unhook"
	if phase=="at_lift":
		if kind=="hold" and _in_range(car.position+Vector3.UP*.35,3.3): return "dollies"
		if kind!="hold" and panel_range: return "lift"
	if phase=="dollies" and panel_range: return "lift"
	if phase=="loaded" and panel_range:
		if tanker and at_dropoff() and not tanker.is_settled(): return "milk_settle"
		return "drop" if at_dropoff() else "haul"
	if _at_door(): return "enter"
	return ""

func _at_door() -> bool:
	var side := truck.to_local(foot).x
	if absf(side)<.58:
		return false
	var handle := Truck.DOOR+Vector3.UP*1.57
	handle.x=signf(side)*absf(handle.x)
	return _in_range(body.to_global(handle),2.12)

func context_text() -> String:
	var action:=action_id()
	if Semi.PROMPTS.has(action): return Semi.PROMPTS[action]
	if tanker:
		match action:
			"milk_manifest": return "Read the milk ticket and check the pump seal"
			"milk_seal": return "Check the seal on the tanker’s rear pump cabinet"
			"milk_position": return "Park ahead of the milk truck with its grille facing the lift"
			"milk_settle": return "Hold the lift steady while the milk settles"
			"attach": return "Shackle the block to the front eye"
	if tree_recovery:
		match action:
			"tree_block": return "Shackle the block to the hanging sling"
			"tree_boom": return "Take the boom levers at the side panel" if fuel > 0 else reserve_hint()
			"tree_leave": return "Let go of the boom controls"
	if action in ["winch","lift","sling"] and fuel <= 0.0:
		return reserve_hint()
	if action == "enter" and is_chocked() and fuel > 0.0:
		return "Finish or stow the rigging before entering the cab."
	if action == "haul":
		return "Take the vehicle to %s" % dropoff.sign
	if action == "winch" and special_work < 1.0:
		if semi: return "Hold WINCH to bring the trailer back in line"
		if _boom_job(): return "Hold WINCH to lift clear, swing out and lower"
		if _roll_job(): return "Hold WINCH to roll upright against the check line"
	var extra := {"boom_space":"Move toward the open road · leave room to swing the car clear", "shore":"Set the wrecker back on the bank · at least 22 m from the sedan",
		"sling":"Swing boom over the car and set the lifting sling", "roll_hook":"Shackle the lifting line to the near-side sling",
		"check_line":"Attach the second line to the opposite sling"}
	if extra.has(action): return extra[action]
	if action=="too_far" and _boom_job(): return "Bring rear of wrecker within 15 m of the car"
	if action=="cable" and _boom_job(): return "Chock wheels and unfold recovery boom"
	if vehicle_identity.get("heavy_recovery",false):
		if action == "plow_blade": return "Go around the blade to the rear recovery eye"
		if action == "attach" and _county_plow(): return "Shackle the block to the rear recovery eye"
		if action == "need_block": return "Fit the snatch block from the yard parts counter"
		if action == "cable": return "Chock wheels & take snatch block"
		if action == "attach": return "Shackle snatch block to tow eye"
	if action=="winch":
		return "Hold WINCH · release to ease tension" if OS.has_feature("mobile") else "Hold Space to winch · release to ease tension"
	var prompts:={"enter":"Climb into cab","flare":"Set a road flare","cable":"Chock wheels & take winch cable","too_far":"Move wrecker within cable reach","attach":"Hook cable to tow eye","restow":"Stow cable","unhook":"Remove hook","dollies":"Fit wheel dollies","lift":"Raise wheel-lift & secure straps","drop":"Lower lift & unstrap vehicle"}
	return prompts.get(action,"")

func _hint() -> String:
	if not in_cab and is_chocked() and fuel <= 0.0:
		return reserve_hint()
	if semi:
		var freight_note := semi.instructions(phase)
		if not freight_note.is_empty(): return freight_note
	if tanker:
		match phase:
			"scene": return "Park ahead of the milk truck with the wrecker’s rear toward its grille. Set a flare beside the farm lane."
			"flared": return "Check the orange seal on the rear pump cabinet and copy the gallons." if not tanker.checked else "Take the snatch block at the wrecker’s side panel."
			"cable": return "Take the block to the eye just below the tanker’s grille."
			"rigged": return "Start the pull at the left rear panel. Give the tank a moment to settle if the load needle jumps."
	if kind=="passenger":
		if phase == "boarding": return "Keep the wrecker stopped while the passenger walks to its right-hand door."
		return "Take the passenger to %s." % Rides.destination(vehicle_identity) if phase == "passenger" else "Pull up beside the driver, step down and ask if they need a lift."
	if tree_recovery and phase == "cable":
		return "Return to the side panel and take the boom levers." if tree_recovery.block_set else "Reeve the block into the orange sling hanging beside the sedan."
	if tree_recovery and phase == "rigged" and special_work < 1.:
		return tree_recovery.instruction(self) + ". Use the wrecker’s side-panel levers."
	if phase == "scene" and _boom_job():
		return "Back toward the car. Leave 9–15 m between the rear controls and the casualty so the boom can swing clear."
	if phase == "scene" and _recovery()=="ice":
		return "Stay on the bank, 22–52 m from the car. Set a flare at the rear controls and run the cable onto the ice."
	if _county_plow():
		if phase == "scene":
			return "Park on firm road behind the plow and set a flare. Duane needs a short pull back onto the crown."
		if phase == "cable":
			return "Carry the snatch block around to the rear of the salt box. Shackle it to the recovery eye below the tailgate."
	if phase == "cable":
		if _boom_job(): return "Set the lifting sling from the rear boom controls."
		if _roll_job(): return "Attach the second line on the opposite side." if second_line else "Carry the block to the sling on the car’s left side."
	match phase:
		"scene": return "Park on the shoulder within 35 m. Step out at a standstill and set a flare beside the disabled vehicle."
		"flared": return "At the wrecker’s left rear side panel, chock the drive wheels and take the line."
		"cable": return "Carry the hook to either bumper of the disabled vehicle. Use the tow eye facing your wrecker."
		"rigged": return "Hold the winch at the wrecker’s left rear panel. The needle shows load. Ease off if it climbs into red."
		"at_lift": return "Fit wheel dollies at the county pickup before lifting." if kind=="hold" else "Use the side panel to lift and strap the axle."
		"dollies": return "At the side panel, raise the lift and secure the straps."
		"loaded": return "Unload at %s using the wrecker’s left rear panel." % dropoff.sign
		"departing","done": return "The recovery is complete."
	return ""

func interact() -> void:
	var a:=action_id()
	if a == "milk_manifest":
		tanker.checked = true
		_note("%d gallons   ·   Seal %s intact. Take the snatch block at the side panel." % [tanker.gallons,tanker.seal],6.)
		sound_event.emit("ratchet")
		return
	if a in ["milk_position","milk_seal","milk_settle"]:
		_note(context_text(),4.)
		return
	if a=="freight_position":
		_note(context_text(),4)
		return
	if semi and a.begins_with("freight_"):
		semi.handle_work(self,a)
		_update_highlight()
		return
	if a in ["lift","sling","winch","tree_boom"] and fuel <= 0.0:
		_note(reserve_hint(),6.0)
		return
	match a:
		"exit":
			# A bay wall or a closed chain can be flush against the driver's door.
			var aisle := truck.to_global(Vector3(0,.80,Truck.DOOR.z))
			var step_out := -truck.global_basis.x * (absf(Truck.DOOR.x) + .27)
			var clearance := step_out + step_out.normalized()*.20
			if _obstructed(aisle,clearance):
				if _obstructed(aisle,-clearance):
					_note("Both doors are blocked. Move the wrecker into the open.",3)
					return
				step_out = -step_out
			motion=Vector3.ZERO
			speed=0
			foot=aisle+step_out
			foot.y=_ground(foot)
			walked=0.0
			if driving_view == "chase":
				camera_yaw = wrapf(chase_heading+chase_orbit,-PI,PI)
				camera_pitch = -.067
			else:
				camera_yaw=wrapf(camera_yaw+heading,-PI,PI)
			in_cab=false
			sound_event.emit("door")
		"enter":
			if is_chocked() and fuel > 0.0:
				_note("Finish or stow the rigging first.",2.5)
				return
			# Looking down at the exterior door handle should not leave the
			# seated operator facing their lap or the back wall of the cab.
			camera_yaw=0.0
			camera_pitch=-.067
			in_cab=true
			_reset_chase()
			_frame_nearby_car()
			sound_event.emit("door")
		"flare":
			var loc:=foot+(car.position-foot).normalized()*.55
			loc.y=_ground(loc)
			flame=Scene.flare(self,loc)
			_clear_warning_triangle()
			phase="flared"
			sound_event.emit("flare")
		"cable":
			phase="cable"
			_set_chocks()
			sound_event.emit("ratchet")
			if tree_recovery: tree_recovery.deploy(self)
		"tree_block":
			tree_recovery.block_set = true
			sound_event.emit("ratchet")
			_note("Block set. Take the boom levers at the truck.",4)
		"tree_boom": tree_recovery.engage(self)
		"tree_leave": tree_recovery.controls = false
		"roll_hook":
			second_line=true
			sound_event.emit("ratchet")
		"sling","check_line":
			line_end=_nearest_eyelet()
			phase="rigged"
			free_line=_flat_distance(_drum(),_eyelet(line_end))+.45
			sound_event.emit("lift" if a=="sling" else "ratchet")
		"attach":
			if kind=="hold":
				Scene.close_driver_door(car)
			line_end=_nearest_eyelet()
			phase="rigged"
			free_line=_flat_distance(_drum(),_eyelet(line_end))+.45
			sound_event.emit("ratchet")
		"restow","unhook":
			if tree_recovery:
				tree_recovery.clear_sling()
				tree_recovery.block_set = false
			if semi: semi.rigging = "tractor"
			second_line=false
			phase="flared"
			tension=0
			body.stow_boom()
			if chocks: chocks.queue_free()
			chocks=null
			sound_event.emit("ratchet")
		"dollies":
			phase="dollies"
			_fit_dollies()
			sound_event.emit("ratchet")
		"lift":
			phase="loaded"
			loaded=true
			body.stinger.position.z=0.0
			_track_underlift()
			_set_car_lamps("tow")
			if chocks: chocks.queue_free()
			chocks=null
			sound_event.emit("lift")
			_finish_recovery()
		"drop":
			phase="done"
			loaded=false
			car.rotation.x=0
			car.position.y=_ground(car.position)
			sound_event.emit("lift")
			dropped.emit()
		"need_block": _note("This recovery needs a double line. Order the snatch block at the yard.",4)
		"need_second_winch": _note(context_text(),4)
		"plow_blade": _note(context_text(),3)
		"boom_space": _note("The car needs open ground under all four wheels. Move back toward the road.",4)
		"shore": _note("Ice won't hold the wrecker. Set up on the bank.",4)
		"too_far": _note(context_text(),3)
	_update_eyes()

func _set_chocks() -> void:
	chocks=Kit.joint(truck,Vector3.ZERO,"Chocks")
	var k=Kit.new(chocks)
	for s in [-1,1]:
		k.box(Vector3(s*1.02,.115,3.40),Vector3(.36,.20,.30),Color("#915c39"),Vector3(-.27,0,0))
	k.finish()

func _fit_dollies() -> void:
	dollies=Kit.joint(car,Vector3.ZERO,"WheelDollies")
	var k=Kit.new(dollies)
	var z:float=-line_end*1.54
	for s in [-1.0,1.0]:
		k.box(Vector3(s*.99,.18,z),Vector3(.54,.12,.83),Color("#825242"))
		for dz in [-.31,.31]:
			k.tube(Vector3(s*.80,.12,z+dz),Vector3(s*1.27,.12,z+dz),.108,Color("#303236"),8)
	k.finish()

func _winch(operate:bool,dt:float) -> void:
	var prev_work:=working
	slip_cooldown=maxf(0,slip_cooldown-dt)
	working=phase=="rigged" and not in_cab and operate and fuel>0.0 and _in_range(_panel(),2.7,false) and slip_cooldown<=0
	if working and ((vehicle_identity.heavy_recovery and not snatch_block) or (semi and not second_winch)):
		working = false
	if tree_recovery and special_work < 1.: working = false
	if not working:
		tension=move_toward(tension,0.0,dt*.72)
		if tanker:
			if not loaded:
				tanker.update_during_pull(dt,0,tanker.global_basis.inverse()*(_drum()-tanker.global_position).normalized())
			elif not in_cab:
				tanker.step_liquid(dt,Vector2.ZERO)
		return
	if not prev_work: sound_event.emit("winch_start")
	# A partial last stroke uses only the diesel still in the tank.
	if fuel <= dt * WINCH_FUEL_PER_SECOND:
		dt = fuel / WINCH_FUEL_PER_SECOND
		fuel = 0.0
		working = false
		_note(reserve_hint(),6.0)
	else:
		fuel -= dt * WINCH_FUEL_PER_SECOND
	if semi and semi.rigging == "both":
		semi.straighten(self,dt)
		return
	if special_work < 1.0 and (_roll_job() or _boom_job()):
		_work_casualty(dt)
		return
	var attach:=_eyelet(line_end)
	var fairlead:=_drum()
	var toward:=fairlead-attach
	toward.y=0
	var gap:=toward.length()
	var axial:float=absf(toward.normalized().dot(car.global_basis.z))
	var sideways:float=1.0-absf(toward.normalized().dot(truck.global_basis.z))
	var resistance:=.48+(.13 if kind=="hold" else 0.0)+(1-axial)*.32+sideways*.17
	if _road(car.position)>6.8: resistance+=.12
	if warmth<.24: resistance+=.04
	var shortening:=dt*(1.52 if kind=="hold" else 1.84)*(1.0-wear*.22)
	if _recovery()=="ice":
		shortening*=.72
		resistance*=.78
	if vehicle_identity.heavy_recovery:
		# The utility load needs more than one part of line. The block shares
		# that load across two strands and halves travel per turn of the drum.
		resistance=(resistance+.68)*.5
		shortening*=.5
	if tanker:
		resistance += clampf(tanker.surge.length()*.28,0,.31)
	free_line=maxf(.30,free_line-shortening)
	var taut:=maxf(0,gap-free_line)
	tension=move_toward(tension,resistance*clampf(taut/.34,0,1),dt*(.23+taut*.38))
	if tension>=.99:
		slip_cooldown=1.14
		_note("Cable slipped · let the drum settle",slip_cooldown)
		free_line=gap+.38
		tension=.60
		wear=minf(1,wear+.012)
		sound_event.emit("cable_slip")
		return
	if taut<=.014: return
	var traction:float=clampf((tension-.16)*1.65,0,1)
	var amount:float=minf(taut,minf(gap,shortening*(.37+traction*.72)))
	if tanker:
		tanker.update_during_pull(dt,amount/maxf(.001,dt),tanker.global_basis.inverse()*toward.normalized())
		car.rotation.z = move_toward(car.rotation.z,0,amount*.028)
	car.position+=toward.normalized()*amount
	car.position.y=lerpf(car.position.y,_ground(car.position),1-exp(-7.0*dt))
	if _county_plow():
		car.rotation.x = move_toward(car.rotation.x,0.0,amount*.045)
	var desired:=atan2(toward.x,toward.z)+(PI if line_end<0 else 0.0)
	car.rotation.y=lerp_angle(car.rotation.y,desired,clampf(amount*.16,0,.20))
	if semi: semi.follow(_ground)
	if gap<=1.15 or (kind=="ditch" and _road(car.position)<4.55 and car.position.distance_to(job_site)>3.0):
		tension=0
		working=false
		if kind=="ditch":
			phase="departing"
			_begin_departure()
			if _county_plow():
				_note("Plow free · Duane's taking the route back.",6.0)
			else:
				_note("Ditch pull complete · driver leaving. Clear for the next call.",8.0)
			if chocks: chocks.queue_free()
			chocks=null
			sound_event.emit("ratchet")
			_finish_recovery()
		else:
			phase="at_lift"
			sound_event.emit("ratchet")

func _work_casualty(dt: float) -> void:
	var duration := 9.0 if _boom_job() else 7.0
	special_work = move_toward(special_work,1.0,dt/duration)
	tension = move_toward(tension,.57+.15*sin(PI*special_work),dt*.32)
	if _roll_job():
		var angle := PI*(1.0-smoothstep(0.0,1.0,special_work))
		if _recovery()=="roll":
			car.rotation.z = angle
			car.position.y = _ground(car.position) + maxf(0.0,-cos(angle))*1.71 + sin(angle)*.96
		else:
			car.rotation.x = -angle*.5
			car.position.y = _ground(car.position) + sin(angle*.5)*Scene.SEDAN_SIZE.z
	else:
		var height := job_site.y if job_site.y>0 else (4.75 if _recovery()=="roof" else 5.0)
		var start := Vector3(job_site.x,_ground(job_site)+height,job_site.z)
		var landing := _boom_landing()
		car.position = start.lerp(Vector3(landing.x,start.y,landing.z),smoothstep(.19,.68,special_work))
		car.position.y = lerpf(start.y+.65*smoothstep(0,.17,special_work),landing.y,smoothstep(.68,1,special_work))
		body.aim_boom(car.global_position+Vector3.UP*2.15)
	if special_work >= 1.0:
		free_line = _flat_distance(_drum(),_eyelet(line_end))+.30
		body.stow_boom()
		_note("On its wheels. Keep winching to the underlift.",4)

func _finish_recovery() -> void:
	if flame:
		flame.queue_free()
		flame=null
	recovered.emit(kind)

func _set_car_lamps(mode:String) -> void:
	if car_lamps:
		car_lamps.hide()
		car_lamps.queue_free()
	car_lamps=semi.freight_lamps() if semi and mode=="tow" else Scene.car_lamps(car,mode,line_end)

func _track_underlift() -> void:
	var size: Vector3 = car.get_meta("body_size")
	var half_wheelbase:=size.z*.61
	var wheel_height:=.43 if size == Scene.PICKUP_SIZE else .355
	var lifted_axle:=Vector3(0,wheel_height,line_end*half_wheelbase)
	var rolling_axle:=Vector3(0,wheel_height,-lifted_axle.z)
	if semi or tanker:
		wheel_height = Tanker.WHEEL_RADIUS if tanker else Semi.WHEEL_RADIUS
		lifted_axle = Vector3(0,wheel_height,Tanker.FRONT_AXLE if tanker else Semi.FRONT_AXLE)
		rolling_axle = Vector3(0,wheel_height,Tanker.REAR_AXLE if tanker else Semi.REAR_AXLE)
		half_wheelbase = (rolling_axle.z-lifted_axle.z)*.5
	var hitch:=_hitch()+Vector3.UP*.15
	# The rolling axle keeps its last ground contact as the crossbar moves. This
	# gives the tow its own turning arc, in both forward and reverse.
	var tail:=car.to_global(rolling_axle)-hitch
	var bend:=wrapf(atan2(tail.x,tail.z)-heading,-PI,PI)
	var trailing_yaw:=heading+clampf(bend,-PI/3,PI/3)
	var rear_contact:=hitch+Vector3.BACK.rotated(Vector3.UP,trailing_yaw)*2.0*half_wheelbase
	var rise:=hitch.y-_ground(rear_contact)-wheel_height
	car.rotation=Vector3(-line_end*asin(clampf(rise/(2.0*half_wheelbase),-.60,.60)),trailing_yaw+(PI if line_end>0 else 0.0),0)
	car.global_position=hitch-car.global_basis*lifted_axle
	if semi: semi.follow(_ground)

func _begin_departure() -> DepartingDriver:
	var driver := DepartingDriver.new(self,car,witness,car_lamps,job_site,job_yaw,vehicle_identity)
	driver.flash_time = flash_time
	departures.append(driver)
	return driver

func _in_wrecker(point:Vector3) -> bool:
	var local:=truck.to_local(point)
	return absf(local.x)<1.75 and local.z> -4.5 and local.z<5.1

func _trail(dt:float) -> void:
	_advance_riders(dt)
	for i in range(departures.size()-1,-1,-1):
		var driver := departures[i]
		if driver.advance(dt):
			if driver.car == car:
				car.hide()
				phase = "done"
			else:
				driver.car.queue_free()
				driver.witness.queue_free()
			departures.remove_at(i)
	if not car: return
	body.work_light.visible=loaded or near_casualty(CABLE_REACH)
	var extending:=kind!="ditch" and phase in ["rigged","at_lift","dollies","loaded"]
	body.stinger.position.z=move_toward(body.stinger.position.z,0.0 if extending else -1.31,dt*1.5)
	if loaded:
		_track_underlift()
	if phase not in ["loaded","done","departing"]:
		flash_time=fmod(flash_time+dt,1.0)
		car_lamps.visible=_running_car() or flash_time<.5

func _cable_curve() -> void:
	cable_mesh.clear_surfaces()
	pulley.visible=snatch_block
	if snatch_block:
		pulley.global_transform=body.global_transform*Transform3D(Basis.IDENTITY,Vector3(-.89,1.85,3.40))
	if not phase in ["cable","rigged","at_lift","dollies"]: return
	if semi:
		semi.draw_lines(self)
		return
	var a:=_drum()
	if _boom_job() and special_work<1 and phase in ["cable","rigged"]:
		body.aim_boom(car.global_position+Vector3.UP*2.15)
		if tree_recovery and phase=="cable":
			pulley.global_position = tree_recovery.eye if tree_recovery.block_set else eyes.global_transform*Vector3(.25,-.32,-.46)
			_cable_strand(a,pulley.global_position)
		if phase=="rigged":
			var sling_top: Vector3=body.boom_tip.global_position
			if _recovery()=="tree":
				sling_top=car.to_global(Vector3(0,1.87,0))
				pulley.global_position=sling_top
				pulley.rotation.y=body.boom.global_rotation.y
				for side: float in [-1.0,1.0]:
					var offset: Vector3 = pulley.global_basis.x*(side*.07)
					_cable_strand(body.boom_tip.global_position+offset,sling_top+offset)
			for side: float in [-1.0,1.0]:
				_cable_strand(sling_top,car.to_global(Vector3(side*.81,.82,0)))
		return
	if _roll_job() and special_work<1.0 and (second_line or phase=="rigged"):
		pulley.global_position=_side_eye(-1.0)
		_cable_strand(a,pulley.global_position)
		if phase=="rigged": _cable_strand(body.to_global(Vector3(.67,1.34,4.09)),_side_eye(1.0))
		return
	var b:=_eyelet(line_end)
	if phase=="cable":
		b = foot + Vector3.UP*.15 if in_cab else eyes.global_transform*Vector3(.25,-.32,-.46)
	if snatch_block and vehicle_identity.heavy_recovery:
		pulley.global_position=b+Vector3.UP*.12
		pulley.rotation.y=atan2(b.x-a.x,b.z-a.z)
		b=pulley.global_position
		_cable_strand(body.to_global(Vector3(.67,1.34,4.09)),b+pulley.global_basis.x*.07)
		b-=pulley.global_basis.x*.07
	_cable_strand(a,b)

func _cable_strand(a: Vector3, b: Vector3) -> void:
	var sag:float=clampf(a.distance_to(b)*.05,.07,1.25)*(1.0-tension*.83)
	var side:Vector3=(b-a).cross(eyes.global_position-a).normalized()*.014
	if side.length_squared()<.000001: side=Vector3.RIGHT*.014
	cable_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP,cable_mat)
	for i in 13:
		var t:=i/12.0
		var p:=a.lerp(b,t)
		p.y=maxf(_ground(p)+.045,p.y-sin(t*PI)*sag)
		cable_mesh.surface_add_vertex(p-side)
		cable_mesh.surface_add_vertex(p+side)
	cable_mesh.surface_end()

func _update_highlight() -> void:
	if tree_recovery and phase == "cable":
		highlight.visible = assist and not tree_recovery.block_set and foot.distance_to(tree_recovery.eye) < 9.
		if highlight.visible: highlight.global_position = tree_recovery.eye
		return
	if semi and phase == "cable":
		var at := semi.marking(self)
		highlight.visible = not in_cab and assist and at.is_finite() and foot.distance_to(at)<9.
		if highlight.visible: highlight.global_position = at
		return
	highlight.visible=not in_cab and assist and phase=="cable" and near_casualty(9)
	if highlight.visible:
		var e:=_nearest_eyelet()
		highlight.global_position=_side_eye(1.0 if second_line else -1.0) if _roll_job() else _eyelet(e)
		highlight.rotation=Vector3(PI/2,car.rotation.y,0)

func _build_tracks() -> void:
	tracker=MultiMeshInstance3D.new()
	var m:=MultiMesh.new()
	m.transform_format=MultiMesh.TRANSFORM_3D
	m.instance_count=1400
	var tile:=PlaneMesh.new()
	tile.size=Vector2(.27,1.08)
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("#778591")
	mat.roughness=1
	tile.material=mat
	m.mesh=tile
	m.visible_instance_count=0
	tracker.multimesh=m
	tracker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracker.custom_aabb=AABB(Vector3(-810,-20,-630),Vector3(2000,70,1730))
	add_child(tracker)

func _lay_tracks() -> void:
	if absf(speed)<.35 or (track_previous!=Vector3.INF and _flat_distance(track_previous,truck.position)<.92): return
	track_previous=truck.position
	for s in [-1.0,1.0]:
		var p:Vector3=truck.to_global(Vector3(s*1.02,0,2.9))
		p.y=_ground(p)+.033
		var orientation:=Basis.from_euler(Vector3(pitch,heading,roll),EULER_ORDER_YXZ)
		tracker.multimesh.set_instance_transform(track_index,Transform3D(orientation,p))
		track_index=posmod(track_index+1,tracker.multimesh.instance_count)
		track_count=mini(track_count+1,tracker.multimesh.instance_count)
	tracker.multimesh.visible_instance_count=track_count

func _note(message:String,seconds:float) -> void:
	info=message
	info_timer=seconds

func get_status() -> Dictionary:
	return {"in_cab":in_cab,"speed_mph":absf(speed)*MPH_PER_MPS,"speed_mps":speed,"engine_rpm":engine_rpm,"engine_load":engine_load,"heading":_compass_degrees(),"odo":odo,"loaded":loaded,"phase":phase,"tension":tension,"fuel":fuel,"warmth":warmth,"blower":climate.blower,"window_open":climate.cracked,"wear":wear,"working":working,"hint":_hint(),"context":context_text()}

func _v(p:Vector3)->Array:
	return [p.x,p.y,p.z]

func _unpack(a:Variant,fallback:Vector3)->Vector3:
	if a is Array and a.size()==3: return Vector3(float(a[0]),float(a[1]),float(a[2]))
	return fallback

func save_state() -> Dictionary:
	var d:={"truck":_v(truck.position),"heading":heading,"yaw":camera_yaw,"pitch":camera_pitch,"cab":in_cab,"foot":_v(foot),"odo":odo,"fuel":fuel,"warmth":warmth,"coffee_left":coffee_left,"cab_heat":climate.save_state(),"spot_on":spot_on,"mirror_ice":body.mirror_ice.duplicate(),"wear":wear,"phase":phase,"kind":kind,"loaded":loaded,"site":_v(job_site),"site_yaw":job_yaw,"line_end":line_end,"free_line":free_line,"chains":tire_chains}
	d["driving_view"] = driving_view
	d.special_work = special_work
	if tree_recovery: d.tree_boom = {"block":tree_recovery.block_set,"controls":tree_recovery.controls,"watch_load":tree_recovery.watch_load}
	if aux_tank and aux_tank.visible: d.reserve_fuel = reserve_fuel
	if semi: d.freight = semi.snapshot()
	if tanker: d.milk = tanker.snapshot()
	d.second_line = second_line
	if not vehicle_identity.is_empty():
		d["identity"] = vehicle_identity.duplicate()
	if loaded:
		d["lift_height"]=body.lift.position.y
	if boarding_walk:
		d.boarding = boarding_walk.save_state(self)
	if kind == "passenger" and phase == "scene" and witness:
		d.waiting_rider = _v(witness.position)
	d.exiting_riders = []
	for walker in exiting_riders:
		d.exiting_riders.append(walker.save_state(self))
	d.departures = []
	for driver in departures:
		if driver.car == car:
			d.merge(driver.save_state(),true)
		else:
			d.departures.append(driver.save_state())
	if car:
		d["car"]=_v(car.position)
		d["car_rot"]=_v(car.rotation)
	if flame: d["flare"]=_v(flame.position)
	return d

func restore_state(d:Dictionary) -> void:
	if d.is_empty(): return
	set_spawn(_unpack(d.get("truck"),truck.position),float(d.get("heading",heading)))
	for driver in departures:
		driver.car.queue_free()
		driver.witness.queue_free()
	departures.clear()
	for walker in exiting_riders:
		walker.person.queue_free()
	exiting_riders.clear()
	for data: Dictionary in d.get("exiting_riders",[]):
		var model := int(data.get("variant",2))
		var walker := RiderWalk.new(Scene.person(self,false,model),model)
		walker.restore(self,data)
		exiting_riders.append(walker)
	for data: Dictionary in d.get("departures",[]):
		var ticket: Dictionary = data.identity
		var vehicle := Scene.car(self,"ditch",ticket.variant,ticket)
		var driver := Scene.person(self,false,ticket.driver_variant)
		var lamps := Scene.car_lamps(vehicle,"hazard",-1)
		var departure := DepartingDriver.new(self,vehicle,driver,lamps,_unpack(data.site,Vector3.ZERO),data.site_yaw,ticket)
		departure.restore_state(data)
		departures.append(departure)
	var active:String=d.get("kind","")
	if active in ["ditch","hazard","hold","passenger"]:
		start_job(active,_unpack(d.get("site"),Vector3.ZERO),float(d.get("site_yaw",0)),d.get("identity",{}),d.get("phase","idle"))
	else: end_job()
	in_cab=d.get("cab",true)
	driving_view = "cab" if d.get("driving_view") == "cab" else "chase"
	_reset_chase()
	foot=_unpack(d.get("foot"),truck.position)
	camera_yaw=d.get("yaw",0.0)
	camera_pitch=d.get("pitch",-.067)
	odo=d.get("odo",START_ODO)
	fuel=d.get("fuel",.84)
	reserve_fuel = clampf(d.get("reserve_fuel",0.0),0.0,Reserve.CAPACITY)
	warmth=d.get("warmth",1.0)
	climate.restore(d.get("cab_heat",{}))
	body.move_driver_window(climate.cracked,3.)
	coffee_left = clampf(d.get("coffee_left",0.0),0,HOT_COFFEE_SECONDS)
	spot_on = d.get("spot_on",false)
	var ice: Array = d.get("mirror_ice",[])
	for i in body.mirror_glass.size():
		body.set_mirror_ice(i,float(ice[i]) if i < ice.size() else 0.0)
	wear=d.get("wear",0.0)
	tire_chains=d.get("chains",false)
	phase=d.get("phase","idle")
	loaded=d.get("loaded",false)
	line_end=d.get("line_end",-1)
	free_line=d.get("free_line",0)
	second_line=d.get("second_line",false)
	special_work=d.get("special_work",0.0)
	if car:
		if kind == "passenger":
			match phase:
				"passenger": _seat_rider()
				"boarding":
					boarding_walk = RiderWalk.new(witness,vehicle_identity.driver_variant)
					boarding_walk.restore(self,d.boarding)
				"scene": witness.position = _unpack(d.get("waiting_rider"),witness.position)
		car.position=_unpack(d.get("car"),car.position)
		car.rotation=_unpack(d.get("car_rot"),car.rotation)
		if tree_recovery:
			var boom: Dictionary = d.get("tree_boom",{})
			tree_recovery.block_set = boom.get("block",phase == "rigged" or special_work > 0.)
			tree_recovery.controls = boom.get("controls",false) and phase == "rigged" and not in_cab and special_work < 1. and fuel > 0.
			tree_recovery.watch_load = boom.get("watch_load",true)
			if phase == "cable": tree_recovery.deploy(self)
		if semi: semi.restore(d.get("freight",{}),_ground)
		if tanker: tanker.restore(d.get("milk",{}))
		if kind=="hold" and phase not in ["scene","flared","cable"]:
			Scene.close_driver_door(car)
		if phase=="departing" and witness:
			_begin_departure().restore_state(d)
		elif phase=="done" and kind=="ditch":
			car.hide()
			witness.hide()
		if d.has("flare") and phase in ["flared","cable","rigged","at_lift","dollies"]:
			flame=Scene.flare(self,_unpack(d.flare,car.position))
		if phase in ["cable","rigged","at_lift","dollies"]: _set_chocks()
		if kind=="hold" and phase in ["dollies","loaded","done"]: _fit_dollies()
		if loaded:
			body.stinger.position.z=0.0
			body.lift.position.y=d.get("lift_height",.39)
			_set_car_lamps("tow")
			_track_underlift()
	_stop_motion()
	if in_cab:
		_frame_nearby_car()
	_update_eyes()
