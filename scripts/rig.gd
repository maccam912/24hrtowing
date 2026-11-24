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
const START_ODO := 82146.2
var world: Node3D
var truck:Node3D
var body:Node3D
var eyes:=Camera3D.new()
var torch:=SpotLight3D.new()
var car:Node3D
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
var in_cab:=true
var foot:=Vector3.ZERO
var speed:=0.0
var motion:=Vector3.ZERO
var steering:=0.0
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
		var fl:=_wheel_ground(-1,-2.85)
		var fr:=_wheel_ground(1,-2.85)
		var bl:=_wheel_ground(-1,2.25)
		var br:=_wheel_ground(1,2.25)
		var loaded_sag:=.058 if loaded else 0.0
		ground_targets=Vector3((fl+fr+bl+br)*.25-loaded_sag,atan2((fl+fr-bl-br)*.5,5.1)+loaded_sag*.50,atan2((fr+br-fl-bl)*.5,2.0))
	ground_spring+=((ground_targets.x-truck.position.y)*60.0-ground_spring*13.0)*dt
	truck.position.y+=ground_spring*dt
	var sprung_pitch:=ground_targets.y+clampf(acceleration*.003,-.036,.024)
	pitch=lerpf(pitch,sprung_pitch,1-exp(-6.8*dt))
	roll=lerpf(roll,ground_targets.z+steering*clampf(absf(speed)/22,0,1)*.036,1-exp(-6*dt))
	body.rotation=Vector3(pitch,0,roll)

func _obstructed(a:Vector3,displacement:Vector3) -> bool:
	if displacement.length_squared()<.000001:
		return false
	var hit:=_ray(a,a+displacement)
	return not hit.is_empty() and absf((hit.normal as Vector3).y)<.72

func _truck_obstacle(step:Vector3) -> bool:
	if step.length()<.005: return false
	var sign_z:float=-signf(step.dot(-truck.global_basis.z))
	for side in [-.91,.91]:
		var a:Vector3=truck.to_global(Vector3(side,.91,sign_z*4.06))
		if _obstructed(a,step+step.normalized()*.12):
			return true
	# Out in a work scene, the bumper stops against the casualty.
	if car and phase in ["scene","flared","cable","rigged"]:
		var tip:Vector3=truck.to_global(Vector3(0,0,sign_z*3.95))
		var at:=car.to_local(tip+step)
		var old:=car.to_local(tip)
		if absf(at.x)<1.93 and absf(at.z)<2.08 and Vector2(at.x,at.z).length_squared()<Vector2(old.x,old.z).length_squared():
			return true
	return false

func set_controls(move:Vector2,look:Vector2,operate:bool,brake:bool,dt:float) -> void:
	if not _ready_to_run: return
	dt=minf(dt,.0667)
	info_timer=maxf(0,info_timer-dt)
	camera_yaw=wrapf(camera_yaw-look.x,-PI,PI)
	camera_pitch=clampf(camera_pitch-look.y,-1.34,1.29)
	if in_cab:
		_drive(move,brake,dt)
	else:
		_walk(move,dt)
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
	body.animate(dt,speed,steering,acceleration,loaded,tension,fuel,odo,_heading_degrees(),in_cab,near_casualty(55.0))
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
	var steer_target:=move.x*lerpf(1.0,.56,clampf(absf(speed)/24,0,1))
	steering=move_toward(steering,steer_target,dt*(2.65 if absf(move.x)>.04 else 3.3))
	var yaw_rate:float=speed*tan(steering*(.56 if loaded else .64))/5.1
	heading-=yaw_rate*dt
	truck.rotation.y=heading
	forward=-truck.global_basis.z
	var grip:float=lerpf(3.3,1.36,clampf(absf(speed)/22,0,1))*tire_grip
	if loaded: grip*=1.17
	motion=motion.lerp(forward*speed,1.0-exp(-grip*dt))
	var step:=motion*dt
	if _truck_obstacle(step):
		wear=minf(1,wear+clampf(absf(speed)-4,0,12)*.0015)
		if absf(speed)>3: sound_event.emit("air_brake")
		motion=Vector3.ZERO
		speed=0
		step=Vector3.ZERO
	# The storm boundary softens to a stop; reverse remains available.
	var p:=truck.position+step
	if (absf(p.x)>1150 or p.x< -775 or p.z>970 or p.z< -580) and Vector2(p.x,p.z).length_squared()>Vector2(truck.position.x,truck.position.z).length_squared():
		step=Vector3.ZERO
		motion=Vector3.ZERO
		speed=0
	truck.position+=step
	odo+=step.length()/GAME_MILE
	fuel=maxf(0,fuel-step.length()*(.000065 if loaded else .000046))
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

func _update_eyes() -> void:
	if in_cab:
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
	if kind in ["ditch","hold"]:
		witness=Scene.person(self,kind=="hold")
		var point:Vector3=car.to_global(Vector3(-2.4,0,1.65))
		witness.position=Vector3(point.x,_ground(point),point.z)
		witness.rotation.y=yaw-1.14
	_update_highlight()

func end_job() -> void:
	for n in [car,witness,flame,chocks,dollies]:
		if is_instance_valid(n): n.queue_free()
	car=null
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
	if cable_mesh: cable_mesh.clear_surfaces()
	if highlight: highlight.visible=false

func store_vehicle(job_kind:String,point:Vector3,yaw:float) -> Node3D:
	var variant:=3 if job_kind in ["bridge","river"] else 2
	var model_kind:="hold" if job_kind=="hold" else "hazard"
	var stored:=Scene.car(self,model_kind,variant)
	stored.position=Vector3(point.x,_ground(point),point.z)
	stored.rotation.y=yaw
	return stored

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
	return body.to_global(Truck.HITCH)

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
	var prompts:={"exit":"Step out of cab","enter":"Climb into cab","flare":"Set a road flare","cable":"Chock wheels & take winch cable","too_far":"Move wrecker within cable reach","attach":"Hook cable to tow eye","restow":"Stow cable","unhook":"Remove hook","dollies":"Fit wheel dollies","lift":"Raise wheel-lift & secure straps","drop":"Lower lift & unstrap vehicle","haul":"Take vehicle to the marked yard bay","read_tape":"Read sheriff’s tape"}
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
			camera_yaw=wrapf(camera_yaw+heading,-PI,PI)
			in_cab=false
			sound_event.emit("door")
		"enter":
			# In a chocked wrecker the line is stowed before moving.
			if phase in ["cable","rigged","at_lift","dollies"]:
				_note("Finish or stow the rigging first.",2.5)
				return
			camera_yaw=wrapf(camera_yaw-heading,-PI,PI)
			in_cab=true
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
			if chocks: chocks.queue_free()
			chocks=null
			sound_event.emit("ratchet")
			recovered.emit(kind)
		else:
			phase="at_lift"
			sound_event.emit("ratchet")

func _trail(dt:float) -> void:
	if not car: return
	if phase=="departing":
		departure_time+=dt
		# Let the driver walk back before the recovered car rolls off.
		if witness and witness.visible:
			witness.position=witness.position.move_toward(car.to_global(Vector3(-1,0,0)),dt*1.8)
			witness.position.y=_ground(witness.position)
			if _flat_distance(witness.position,car.position)<1.5 or departure_time>7.0:
				witness.visible=false
		if departure_time>6.5:
			var yaw_target:=0.0 if cos(job_yaw)>0 else PI
			car.rotation.y=lerp_angle(car.rotation.y,yaw_target,1-exp(-dt*1.1))
			car.position+=-car.global_basis.z*minf((departure_time-6.5)*1.65,10.5)*dt
			car.position.y=_ground(car.position)
			if departure_time>22.5:
				car.visible=false
		return
	if not loaded: return
	var hitch:=_hitch()
	var toward:=hitch-car.position
	toward.y=0
	if toward.length_squared()<.001: toward=truck.global_basis.z*-1
	var target_yaw:=atan2(toward.x,toward.z)+(PI if line_end<0 else 0.0)
	car.rotation.y=lerp_angle(car.rotation.y,target_yaw,1.0-exp(-dt*(1.6+absf(speed)*.32)))
	var offset:Vector3=car.global_basis.z*line_end*(2.49 if kind=="hold" else 2.10)
	var pos:Vector3=hitch-offset
	car.position.x=pos.x
	car.position.z=pos.z
	car.position.y=_ground(car.position)+.19
	car.rotation.x=-line_end*.103

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
		if departure_time>22.5: car.visible=false
		if witness and departure_time>7.0: witness.visible=false
		if d.has("flare"): flame=Scene.flare(self,_unpack(d.flare,car.position))
		if phase in ["cable","rigged","at_lift","dollies"]: _set_chocks()
		if kind=="hold" and phase in ["dollies","loaded","done"]: _fit_dollies()
	speed=0
	motion=Vector3.ZERO
	_update_eyes()
