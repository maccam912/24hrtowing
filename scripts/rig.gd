extends Node3D

signal recovered(kind:String)
signal dropped
signal sound_event(id:String)

const Truck = preload("res://scripts/rig_truck.gd")
const Scene = preload("res://scripts/rig_scene.gd")
const Kit = preload("res://scripts/rig_mesh.gd")
const GAME_MILE := 400.0
const CABLE_REACH := 37.0
const WALK_EYES := 1.68
const MAX_SPEED := 25.6
const MAX_LOADED := 18.2
const MAX_STEER_ANGLE := deg_to_rad(36.0)
const START_ODO := 82146.2
const CHASE_ELEVATION := 0.25
var world: Node3D
var truck:Node3D
var body:Node3D
var eyes:=Camera3D.new()
var torch:=SpotLight3D.new()
var car:Node3D
var car_lamps:Node3D
var flash_time:=0.0
var witness:Node3D
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
var odo:=START_ODO
var fuel:=.84
var warmth:=1.0
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
var line_end:=-1
var free_line:=0.0
var reverse_timer:=0.0
var slip_cooldown:=0.0
var departure_time:=0.0
var departure_lane_start:=Vector3.ZERO
var departure_lane_end:=Vector3.ZERO
var walked:=0.0
var storage_point:=Vector3.ZERO
var ground_period:=0.0
var ground_targets:=Vector3.ZERO
var assist:=true
var tire_chains:=false
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
	_update_eyes()

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
		var tip_offset:Vector3=truck.global_basis.z*(-signf(speed)*3.95)
		var at:=car.to_local(truck.global_position+step+tip_offset.rotated(Vector3.UP,turn))
		var old:=car.to_local(truck.global_position+tip_offset)
		if absf(at.x)<1.93 and absf(at.z)<2.08 and Vector2(at.x,at.z).length_squared()<Vector2(old.x,old.z).length_squared():
			return true
	return false

func set_controls(move:Vector2,look:Vector2,operate:bool,brake:bool,dt:float) -> void:
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
		_walk(move,dt)
		_face_operator(dt)
		_suspension(dt)
	_winch(operate,dt)
	_trail(dt)
	_update_eyes()
	_cable_curve()
	_update_highlight()
	warmth=clampf(warmth+(dt*.014 if in_cab else -dt*.0017),0,1)
	if in_cab and fuel>0:
		fuel=maxf(fuel-dt*.000017,0)
	body.glass_material.set_shader_parameter("cold",1.0-warmth)
	body.animate(dt,speed,steering,acceleration,loaded,tension,fuel,odo,_heading_degrees(),in_cab and driving_view == "cab",near_casualty(55.0))
	if not in_cab and warmth<=0.0 and info_timer<=0:
		_note("Hands numb. The cab heater is running.",7.0)

func _drive(move:Vector2, handbrake:bool, dt:float) -> void:
	var forward:Vector3=-truck.global_basis.z
	var throttle:float=-move.y
	var road_dist:=_road(truck.position)
	var offroad:=smoothstep(5.1,11.0,road_dist)
	# A packed yard and parking lots provide the same support as a road.
	if Rect2(-65,-90,68,61).has_point(Vector2(truck.position.x,truck.position.z)):
		offroad=0
	var prev:=speed
	var max_forward:float=lerpf(MAX_LOADED if loaded else MAX_SPEED,7.2 if loaded else 9.1,offroad)
	var pumping:=fuel>0 and not phase in ["cable","rigged","at_lift","dollies"]
	var tire_grip:float=1.29 if tire_chains else 1.0
	if handbrake:
		speed=move_toward(speed,0,dt*(6.45 if loaded else 9.35)*tire_grip)
	elif absf(throttle)>.04 and pumping:
		var reversing:=speed*throttle<-.20
		var target:float=throttle*(max_forward if throttle>0 else 5.15)
		var accel:float=(2.58 if loaded else 4.34)*(1-.77*clampf(absf(speed)/max_forward,0,.96))
		if reversing: accel=(4.8 if loaded else 7.6)*tire_grip
		if throttle<0 and not reversing: accel=2.44
		speed=move_toward(speed,target,accel*dt)
	else:
		speed=move_toward(speed,0,(.56+offroad*.78+speed*speed*.0018)*dt)
	if not pumping and fuel<=0 and info_timer<=0: _note("Fuel gone. Call Arlene for a can.",6.0)
	# Digital controls use full steering lock in the yard and finer angles at road speed.
	var cornering_grip := (3.65 if loaded else 5.1) * tire_grip
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
	motion = midway*speed + right*lateral_speed
	var step := motion*dt + (next_forward-forward)*Truck.REAR_AXLE_Z
	if _truck_obstacle(step,turn):
		wear=minf(1,wear+clampf(absf(speed)-4,0,12)*.0015)
		if absf(speed)>3: sound_event.emit("air_brake")
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
	if absf(speed)<.20 and absf(prev)>=.20 and handbrake: sound_event.emit("air_brake")
	reverse_timer-=dt
	if speed<-.65 and reverse_timer<=0:
		reverse_timer=1.02
		sound_event.emit("reverse")
	_suspension(dt)
	_lay_tracks()

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
		if absf(c.x)<1.03 and absf(c.z)<2.30:
			var old:=car.to_local(foot)
			if absf(old.x)>1: c.x=signf(old.x)*1.04
			else: c.z=2.31 if old.z>0 else -2.31
			dest=car.to_global(c)
	var eye:=foot+Vector3.UP*.80
	if _obstructed(eye,dest-foot+dir*.17):
		var x_move:=Vector3(dest.x-foot.x,0,0)
		var z_move:=Vector3(0,0,dest.z-foot.z)
		if _obstructed(eye,x_move+x_move.normalized()*.17): dest.x=foot.x
		if _obstructed(eye,z_move+z_move.normalized()*.17): dest.z=foot.z
	dest.y=_ground(dest)
	foot=dest
	walked+=Vector2(foot.x-start.x,foot.z-start.z).length()
	if walked>.86:
		walked=0.0
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

func _heading_degrees() -> float:
	return fposmod(-rad_to_deg(heading),360)

func start_job(job_kind:String,target:Vector3,yaw:float) -> void:
	end_job()
	kind=job_kind
	phase="scene"
	job_site=target
	job_yaw=yaw
	var variant: int = (2 if target.x>0 else 3) if kind=="hazard" else (0 if target.x<100 else 1)
	car=Scene.car(self,kind,variant)
	car.position=Vector3(target.x,_ground(target),target.z)
	car.rotation.y=yaw
	_set_car_lamps("hazard")
	if kind in ["ditch","hold"]:
		witness=Scene.person(self,kind=="hold",variant)
		var point:Vector3=car.to_global(Vector3(-2.4,0,1.65))
		witness.position=Vector3(point.x,_ground(point),point.z)
		witness.rotation.y=yaw-1.14
	_update_highlight()

func end_job() -> void:
	for n in [car,witness,flame,chocks,dollies]:
		if is_instance_valid(n): n.queue_free()
	car=null
	car_lamps=null
	flash_time=0
	witness=null
	flame=null
	chocks=null
	dollies=null
	phase="idle"
	kind=""
	loaded=false
	working=false
	tension=0
	free_line=0
	departure_time=0
	if body:
		body.stinger.position.z=-1.31
		body.work_light.hide()
	if cable_mesh: cable_mesh.clear_surfaces()
	if highlight: highlight.visible=false

func store_vehicle(job_kind:String,point:Vector3,yaw:float) -> Node3D:
	var variant:=3 if job_kind in ["bridge","river"] else 2
	var model_kind:="hold" if job_kind=="hold" else "hazard"
	var stored:=Scene.car(self,model_kind,variant)
	stored.position=Vector3(point.x,_ground(point),point.z)
	stored.rotation.y=yaw
	return stored

func _face_operator(dt: float) -> void:
	if not witness or not witness.visible or phase == "departing":
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
	return car.to_global(Vector3(0,.56 if kind=="hold" else .39,end*(2.51 if kind=="hold" else 2.13)))

func _nearest_eyelet() -> int:
	return 1 if _flat_distance(foot,_eyelet(1))<_flat_distance(foot,_eyelet(-1)) else -1

func _reaches() -> bool:
	return car and _flat_distance(_drum(),car.position)<=CABLE_REACH

func _in_range(at:Vector3,dist:float, require_facing:=true) -> bool:
	var offset:=at-eyes.global_position
	if _flat_distance(foot,at)>dist or absf(offset.y)>3:
		return false
	# Forgiving hands' reach for mobile. At the edge, turn toward what you want.
	return not require_facing or offset.length()<1.5 or (-eyes.global_basis.z).dot(offset.normalized())>-.13

func action_id() -> String:
	if in_cab:
		return "exit" if absf(speed)<.65 else ""
	var panel_range:=_in_range(_panel(),2.65)
	if phase=="scene" and near_casualty(8.5) and (_in_range(car.position+Vector3.UP,8.5) or not _at_door()):
		return "flare"
	if phase=="flared" and panel_range:
		return "cable" if _reaches() else "too_far"
	if phase=="cable":
		if _in_range(_eyelet(_nearest_eyelet()),2.45): return "attach"
		if panel_range: return "restow"
	if phase=="rigged":
		if panel_range: return "winch"
		if _in_range(_eyelet(line_end),1.8): return "unhook"
	if phase=="at_lift":
		if kind=="hold" and _in_range(car.position+Vector3.UP*.35,3.3): return "dollies"
		if kind!="hold" and panel_range: return "lift"
	if phase=="dollies" and panel_range: return "lift"
	if phase=="loaded" and panel_range:
		return "drop" if _flat_distance(car.position,storage_point)<12.0 or _flat_distance(truck.position,storage_point)<12.0 else "haul"
	if _at_door(): return "enter"
	if phase=="flared" and near_casualty(2.7) and kind!="ditch": return "read_tape"
	return ""

func _at_door() -> bool:
	var handle:Vector3=body.to_global(Truck.DOOR+Vector3.UP*1.57)
	return _in_range(handle,2.12) and truck.to_local(foot).x<-.58

func context_text() -> String:
	if info_timer>0: return info
	var action:=action_id()
	if action=="winch":
		if slip_cooldown>0: return "Cable slipped · let the drum settle"
		return "Hold WINCH · release to ease tension" if OS.has_feature("mobile") else "Hold Space to winch · release to ease tension"
	var prompts:={"enter":"Climb into cab","flare":"Set a road flare","cable":"Chock wheels & take winch cable","too_far":"Move wrecker within cable reach","attach":"Hook cable to tow eye","restow":"Stow cable","unhook":"Remove hook","dollies":"Fit wheel dollies","lift":"Raise wheel-lift & secure straps","drop":"Lower lift & unstrap vehicle","haul":"Take vehicle to the marked yard bay","read_tape":"Read sheriff’s tape"}
	return prompts.get(action,"")

func _hint() -> String:
	match phase:
		"scene": return "Park on the shoulder within 35 m. Step out at a standstill and set a flare beside the disabled vehicle."
		"flared": return "At the wrecker’s left rear side panel, chock the drive wheels and take the line."
		"cable": return "Carry the hook to either bumper of the disabled vehicle. Use the tow eye facing your wrecker."
		"rigged": return "Hold the winch at the wrecker’s left rear panel. The needle shows load. Ease off if it climbs into red."
		"at_lift": return "Fit wheel dollies at the county pickup before lifting." if kind=="hold" else "Use the side panel to lift and strap the axle."
		"dollies": return "At the side panel, raise the lift and secure the straps."
		"loaded": return "Return to the yard and use the side panel by the hold bay." if kind=="hold" else "Return to the yard and use the side panel by the storage pad."
		"departing","done": return "The recovery is complete. Return to the office with the tow slip."
	return ""

func interact() -> void:
	var a:=action_id()
	match a:
		"exit":
			# Keep the heading the operator was looking at when crossing the threshold.
			motion=Vector3.ZERO
			speed=0
			foot=body.to_global(Truck.DOOR+Vector3(-.27,0,0))
			foot.y=_ground(foot)
			if driving_view == "chase":
				camera_yaw = wrapf(chase_heading+chase_orbit,-PI,PI)
				camera_pitch = -.067
			else:
				camera_yaw=wrapf(camera_yaw+heading,-PI,PI)
			in_cab=false
			sound_event.emit("door")
		"enter":
			# In a chocked wrecker the line is stowed before moving.
			if phase in ["cable","rigged","at_lift","dollies"]:
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
			phase="flared"
			sound_event.emit("flare")
		"cable":
			phase="cable"
			_set_chocks()
			sound_event.emit("ratchet")
		"attach":
			line_end=_nearest_eyelet()
			phase="rigged"
			free_line=_flat_distance(_drum(),_eyelet(line_end))+.45
			sound_event.emit("ratchet")
		"restow","unhook":
			phase="flared"
			tension=0
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
			recovered.emit(kind)
		"drop":
			phase="done"
			loaded=false
			car.rotation.x=0
			car.position.y=_ground(car.position)
			sound_event.emit("lift")
			dropped.emit()
		"too_far": _note("Thirty-seven metres of line. Bring the wrecker closer.",3)
		"read_tape": _note("SHERIFF  •  11/23  •  J.K. 417  •  CHECKED",4)
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
	working=phase=="rigged" and not in_cab and operate and _in_range(_panel(),2.7,false) and slip_cooldown<=0
	if not working:
		tension=move_toward(tension,0.0,dt*.72)
		return
	if not prev_work: sound_event.emit("winch_start")
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
	free_line=maxf(.30,free_line-shortening)
	var taut:=maxf(0,gap-free_line)
	tension=move_toward(tension,resistance*clampf(taut/.34,0,1),dt*(.23+taut*.38))
	fuel=maxf(0,fuel-dt*.00013)
	if tension>=.99:
		slip_cooldown=1.14
		free_line=gap+.38
		tension=.60
		wear=minf(1,wear+.012)
		sound_event.emit("cable_slip")
		return
	if taut<=.014: return
	var traction:float=clampf((tension-.16)*1.65,0,1)
	var amount:float=minf(taut,minf(gap,shortening*(.37+traction*.72)))
	car.position+=toward.normalized()*amount
	car.position.y=lerpf(car.position.y,_ground(car.position),1-exp(-7.0*dt))
	var desired:=atan2(toward.x,toward.z)+(PI if line_end<0 else 0.0)
	car.rotation.y=lerp_angle(car.rotation.y,desired,clampf(amount*.16,0,.20))
	if gap<=1.15 or (kind=="ditch" and _road(car.position)<4.55 and car.position.distance_to(job_site)>3.0):
		tension=0
		working=false
		if kind=="ditch":
			phase="departing"
			_note("Ditch pull complete · the driver is taking the car home.",8.0)
			if chocks: chocks.queue_free()
			chocks=null
			sound_event.emit("ratchet")
			recovered.emit(kind)
		else:
			phase="at_lift"
			sound_event.emit("ratchet")

func _set_car_lamps(mode:String) -> void:
	if car_lamps:
		car_lamps.hide()
		car_lamps.queue_free()
	car_lamps=Scene.car_lamps(car,kind,mode,line_end)

func _track_underlift() -> void:
	var half_wheelbase:float=(2.5 if kind=="hold" else 2.12)*.61
	var wheel_height:=.43 if kind=="hold" else .355
	var lifted_axle:=Vector3(0,wheel_height,line_end*half_wheelbase)
	var rolling_axle:=Vector3(0,wheel_height,-lifted_axle.z)
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

func _departure_lane() -> void:
	var forward:=Vector3.FORWARD.rotated(Vector3.UP,job_yaw)
	departure_lane_start=job_site-forward*500
	departure_lane_end=job_site+forward*500
	if not world.has_method("map_roads"):
		return
	var nearest:=INF
	for road:Dictionary in world.map_roads():
		var points:PackedVector2Array=road.points
		for i in range(1,points.size()):
			var a:Vector3=world.resolve_point(Vector3(points[i-1].x,0,points[i-1].y))
			var b:Vector3=world.resolve_point(Vector3(points[i].x,0,points[i].y))
			var distance:=job_site.distance_squared_to(Geometry3D.get_closest_point_to_segment(job_site,a,b))
			if distance>=nearest: continue
			nearest=distance
			if (b-a).dot(forward)<0:
				var swap:=a
				a=b
				b=swap
			var lane_offset:Vector3=(b-a).normalized().cross(Vector3.UP)*2.15
			departure_lane_start=a+lane_offset
			departure_lane_end=b+lane_offset

func _depart(dt:float) -> void:
	if witness and witness.visible:
		var door:=car.to_global(Vector3(-1.10,0,-.25))
		var stride:=door-witness.position
		stride.y=0
		if stride.length()>.16:
			Scene.walk_person(witness)
			witness.rotation.y=lerp_angle(witness.rotation.y,atan2(-stride.x,-stride.z),1.0-exp(-7.0*dt))
			witness.position+=stride.limit_length(dt*1.65)
			witness.position.y=_ground(witness.position)
			return
		witness.hide()
		_set_car_lamps("running")
		_departure_lane()
		sound_event.emit("door")
	departure_time+=dt
	if departure_time<1.0:
		return
	var lane:=departure_lane_end-departure_lane_start
	var lane_forward:=lane.normalized()
	var lane_right:=lane_forward.cross(Vector3.UP)
	var along:=clampf((car.position-departure_lane_start).dot(lane_forward)+8.0,0.0,lane.length())
	var aim:=departure_lane_start+lane_forward*along
	# Stay on the near side of the parked wrecker until the car can merge
	# without cutting across its bed. Account for parking across the road.
	var to_truck:=truck.position-car.position
	var truck_ahead:=to_truck.dot(lane_forward)
	if truck_ahead> -8.0 and truck_ahead<13.0:
		var clearance:=1.35*absf(truck.global_basis.x.dot(lane_right))+5.1*absf(truck.global_basis.z.dot(lane_right))+1.35
		var side:float=-1.0 if to_truck.dot(lane_right)>0.0 else 1.0
		var space:float=(aim-truck.position).dot(lane_right)*side
		aim+=lane_right*side*maxf(0.0,clearance-space)
	var direction:=aim-car.position
	direction.y=0
	if direction.length()>1.0:
		var yaw_target:=atan2(-direction.x,-direction.z)
		var distance:=minf((departure_time-1.0)*1.55,10.5)*dt
		var yaw:=rotate_toward(car.rotation.y,yaw_target,distance*.32)
		var step:=Vector3.FORWARD.rotated(Vector3.UP,yaw)*distance
		# Yield if the parked wrecker is across the lane.
		var nose:=truck.to_local(car.position+step.normalized()*2.2+step)
		if absf(nose.x)>1.75 or nose.z< -4.5 or nose.z>5.1:
			car.rotation.y=yaw
			car.position+=step
			car.position.y=_ground(car.position)
	# Beyond the county's 146 m fog horizon. A player following the car can
	# keep it in sight all the way to the end of the road.
	if _flat_distance(car.position,get_player_position())>165.0 and _flat_distance(car.position,job_site)>120.0:
		car.hide()
		phase="done"

func _trail(dt:float) -> void:
	if not car: return
	body.work_light.visible=loaded or near_casualty(CABLE_REACH)
	var extending:=kind!="ditch" and phase in ["rigged","at_lift","dollies","loaded"]
	body.stinger.position.z=move_toward(body.stinger.position.z,0.0 if extending else -1.31,dt*1.5)
	if phase=="departing":
		_depart(dt)
	elif loaded:
		_track_underlift()
	if phase not in ["loaded","done"] and (phase!="departing" or witness.visible):
		flash_time=fmod(flash_time+dt,1.0)
		car_lamps.visible=flash_time<.5

func _cable_curve() -> void:
	cable_mesh.clear_surfaces()
	if not phase in ["cable","rigged","at_lift","dollies"]: return
	var a:=_drum()
	var b:=_eyelet(line_end) if phase!="cable" else eyes.global_transform*Vector3(.25,-.32,-.46)
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
	highlight.visible=not in_cab and assist and phase=="cable" and near_casualty(9)
	if highlight.visible:
		var e:=_nearest_eyelet()
		highlight.global_position=_eyelet(e)
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

func service_fuel() -> void:
	fuel=1.0

func get_status() -> Dictionary:
	return {"in_cab":in_cab,"speed_mph":absf(speed)*2.237,"speed_mps":speed,"heading":_heading_degrees(),"odo":odo,"loaded":loaded,"phase":phase,"tension":tension,"fuel":fuel,"warmth":warmth,"wear":wear,"working":working,"hint":_hint(),"context":context_text()}

func _v(p:Vector3)->Array:
	return [p.x,p.y,p.z]

func _unpack(a:Variant,fallback:Vector3)->Vector3:
	if a is Array and a.size()==3: return Vector3(float(a[0]),float(a[1]),float(a[2]))
	return fallback

func save_state() -> Dictionary:
	var d:={"truck":_v(truck.position),"heading":heading,"yaw":camera_yaw,"pitch":camera_pitch,"cab":in_cab,"foot":_v(foot),"odo":odo,"fuel":fuel,"warmth":warmth,"wear":wear,"phase":phase,"kind":kind,"loaded":loaded,"site":_v(job_site),"site_yaw":job_yaw,"line_end":line_end,"free_line":free_line,"departed":departure_time,"chains":tire_chains}
	d["driving_view"] = driving_view
	if loaded:
		d["lift_height"]=body.lift.position.y
	if phase=="departing" and witness:
		d["driver_boarded"]=not witness.visible
		d["witness"]=_v(witness.position)
		d["witness_yaw"]=witness.rotation.y
	if car:
		d["car"]=_v(car.position)
		d["car_rot"]=_v(car.rotation)
	if flame: d["flare"]=_v(flame.position)
	return d

func restore_state(d:Dictionary) -> void:
	if d.is_empty(): return
	set_spawn(_unpack(d.get("truck"),truck.position),float(d.get("heading",heading)))
	var active:String=d.get("kind","")
	if active in ["ditch","hazard","hold"]:
		start_job(active,_unpack(d.get("site"),Vector3.ZERO),float(d.get("site_yaw",0)))
	else: end_job()
	in_cab=d.get("cab",true)
	driving_view = "cab" if d.get("driving_view") == "cab" else "chase"
	_reset_chase()
	foot=_unpack(d.get("foot"),truck.position)
	camera_yaw=d.get("yaw",0.0)
	camera_pitch=d.get("pitch",-.067)
	odo=d.get("odo",START_ODO)
	fuel=d.get("fuel",.84)
	warmth=d.get("warmth",1.0)
	wear=d.get("wear",0.0)
	tire_chains=d.get("chains",false)
	phase=d.get("phase","idle")
	loaded=d.get("loaded",false)
	departure_time=d.get("departed",0)
	line_end=d.get("line_end",-1)
	free_line=d.get("free_line",0)
	if car:
		car.position=_unpack(d.get("car"),car.position)
		car.rotation=_unpack(d.get("car_rot"),car.rotation)
		if phase=="departing" and witness:
			witness.visible=not d.get("driver_boarded",departure_time>7.0)
			witness.position=_unpack(d.get("witness"),witness.position)
			witness.rotation.y=d.get("witness_yaw",witness.rotation.y)
			if not d.has("driver_boarded"):
				departure_time=maxf(0.0,departure_time-6.5) if not witness.visible else 0.0
			if not witness.visible:
				_departure_lane()
				_set_car_lamps("running")
		elif phase=="done" and kind=="ditch":
			car.hide()
			witness.hide()
		if d.has("flare"): flame=Scene.flare(self,_unpack(d.flare,car.position))
		if phase in ["cable","rigged","at_lift","dollies"]: _set_chocks()
		if kind=="hold" and phase in ["dollies","loaded","done"]: _fit_dollies()
		if loaded:
			body.stinger.position.z=0.0
			body.lift.position.y=d.get("lift_height",.39)
			_set_car_lamps("tow")
			_track_underlift()
	speed=0
	motion=Vector3.ZERO
	if in_cab:
		_frame_nearby_car()
	_update_eyes()
