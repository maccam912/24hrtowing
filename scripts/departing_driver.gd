extends RefCounted

const Scene := preload("res://scripts/rig_scene.gd")

var rig: Node3D
var car: Node3D
var witness: Node3D
var lamps: Node3D
var job_site: Vector3
var job_yaw: float
var identity: Dictionary
var departure_time := 0.0
var backing_distance := 0.0
var west_bay_cleared := false
var flash_time := 0.0
var departure_lane_start := Vector3.ZERO
var departure_lane_end := Vector3.ZERO

func _init(owner_rig: Node3D, vehicle: Node3D, driver: Node3D, lights: Node3D, site: Vector3, yaw: float, ticket: Dictionary) -> void:
	rig = owner_rig
	car = vehicle
	witness = driver
	lamps = lights
	job_site = site
	job_yaw = yaw
	identity = ticket

func _running_lamps() -> void:
	lamps.hide()
	lamps.queue_free()
	lamps = Scene.car_lamps(car,"running",-1)
	if identity.get("variant",-1) == Scene.Snowplow.VARIANT:
		Scene.board_plow_driver(car)
		car.get_node("Blade").position.y = .38
	if car == rig.car:
		rig.car_lamps = lamps

func save_state() -> Dictionary:
	var state := {"site":rig._v(job_site),"site_yaw":job_yaw,"identity":identity.duplicate(),
		"car":rig._v(car.position),"car_rot":rig._v(car.rotation),"departed":departure_time,
		"backing_distance":backing_distance,"driver_boarded":not witness.visible,
		"witness":rig._v(witness.position),"witness_yaw":witness.rotation.y}
	if identity.get("west_release",false): state.west_bay_cleared = west_bay_cleared
	return state

func restore_state(data: Dictionary) -> void:
	car.position = rig._unpack(data.get("car"), job_site)
	car.rotation = rig._unpack(data.get("car_rot"), Vector3.UP * job_yaw)
	departure_time = data.get("departed",0)
	backing_distance = data.get("backing_distance",0)
	west_bay_cleared = data.get("west_bay_cleared",false)
	witness.visible = not data.get("driver_boarded",departure_time>7.0)
	witness.position = rig._unpack(data.get("witness"),witness.position)
	witness.rotation.y = data.get("witness_yaw",witness.rotation.y)
	if not data.has("driver_boarded"):
		departure_time = maxf(0.0,departure_time-6.5) if not witness.visible else 0.0
	if not witness.visible:
		_departure_lane()
		_running_lamps()

func _departure_lane() -> void:
	if identity.get("west_release",false):
		# The open throat of the west lot leads straight through the yard.
		# County K takes a right at the driveway once the car clears the gate.
		if car.position.x < -6:
			departure_lane_start = Vector3(-91,0,-64)
			departure_lane_end = Vector3(3,0,-64)
		else:
			departure_lane_start = Vector3(-2.15,0,-66)
			departure_lane_end = Vector3(-2.15,0,900)
		return
	var forward:=Vector3.FORWARD.rotated(Vector3.UP,job_yaw)
	departure_lane_start=job_site-forward*500
	departure_lane_end=job_site+forward*500
	if not rig.world.has_method("map_roads"):
		return
	var nearest:=INF
	for road:Dictionary in rig.world.map_roads():
		var points:PackedVector2Array=road.points
		for i in range(1,points.size()):
			var a:Vector3=rig.world.resolve_point(Vector3(points[i-1].x,0,points[i-1].y))
			var b:Vector3=rig.world.resolve_point(Vector3(points[i].x,0,points[i].y))
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

func advance(dt: float) -> bool:
	# Once the operator heads for another call, retire an out-of-sight customer
	# even if the car stopped at the end of a short road.
	if car != rig.car and rig._flat_distance(car.position,rig.get_player_position()) > 165.0:
		return true
	if witness.visible:
		var door:=car.to_global(car.get_meta("driver_door",Vector3(-1.10,0,-.25)))
		var stride:=door-witness.position
		stride.y=0
		if stride.length()>.16:
			Scene.walk_person(witness)
			witness.rotation.y=lerp_angle(witness.rotation.y,atan2(-stride.x,-stride.z),1.0-exp(-7.0*dt))
			witness.position+=stride.limit_length(dt*1.65)
			witness.position.y=rig._ground(witness.position)
			flash_time = fmod(flash_time + dt, 1.0)
			lamps.visible = flash_time < 0.5
			return false
		witness.hide()
		_running_lamps()
		_departure_lane()
		rig.sound_event.emit("door")
	departure_time+=dt
	if departure_time<1.0:
		return false
	var yard_release: bool = identity.get("west_release",false) and departure_lane_end.z == -64.
	if yard_release and car.position.x>=-6:
		_departure_lane()
		yard_release=false
	var lane:=departure_lane_end-departure_lane_start
	var lane_forward:=lane.normalized()
	var lane_right:=lane_forward.cross(Vector3.UP)
	var along:=clampf((car.position-departure_lane_start).dot(lane_forward)+8.0,0.0,lane.length())
	var aim:=departure_lane_start+lane_forward*along
	# Stay on the near side of the parked wrecker until the car can merge
	# without cutting across its bed. Account for parking across the road.
	var to_truck:Vector3=rig.truck.position-car.position
	var truck_ahead:=to_truck.dot(lane_forward)
	if yard_release and truck_ahead>0. and truck_ahead<12.:
		for side:float in [-1.,0.,1.]:
			if rig._in_wrecker(car.position+lane_forward*3.3+lane_right*side):
				return false
	if not yard_release and truck_ahead> -8.0 and truck_ahead<13.0:
		var required_width := 2.08 if identity.get("variant",-1) == Scene.Snowplow.VARIANT else 1.35
		var clearance:float=1.35*absf(rig.truck.global_basis.x.dot(lane_right))+5.1*absf(rig.truck.global_basis.z.dot(lane_right))+required_width
		var side:float=-1.0 if to_truck.dot(lane_right)>0.0 else 1.0
		var space:float=(aim-rig.truck.position).dot(lane_right)*side
		aim+=lane_right*side*maxf(0.0,clearance-space)
	var direction:=aim-car.position
	direction.y=0
	# A rear-lift tow can leave the car nose-in. Back through the same
	# opening before turning around in the middle of the storage lot.
	if yard_release and car.position.x >= -69.: west_bay_cleared = true
	var reverse_out := yard_release and not west_bay_cleared and Vector3.FORWARD.rotated(Vector3.UP,job_yaw).x < 0.
	if reverse_out: direction = -direction
	if direction.length()>1.0:
		var yaw_target:=atan2(-direction.x,-direction.z)
		var distance:=minf((departure_time-1.0)*1.55,10.5)*dt
		var yaw:=rotate_toward(car.rotation.y,yaw_target,distance*.32)
		var step:=Vector3.FORWARD.rotated(Vector3.UP,yaw)*distance
		if reverse_out: step = -step
		# A close pull can leave the bumper pointed at the wrecker. Back up to
		# make enough room to swing around its bed before trying forward again.
		var overhang := 4.40 if identity.get("variant",-1) == Scene.Snowplow.VARIANT else 2.2
		if backing_distance<=0 and rig._in_wrecker(car.position+step.normalized()*overhang+step):
			backing_distance=3.2
		if backing_distance>0:
			distance=minf(backing_distance,dt*2.6)
			yaw=rotate_toward(car.rotation.y,yaw_target,distance*.38)
			step=Vector3.BACK.rotated(Vector3.UP,yaw)*distance
			backing_distance=maxf(0.0,backing_distance-distance)
		if not rig._in_wrecker(car.position+step.normalized()*overhang+step):
			car.rotation.y=yaw
			car.position+=step
			car.position.y=rig._ground(car.position)
	# Beyond even a lull in the blizzard. A player following the car can
	# keep it in sight all the way to the end of the road.
	return (rig._flat_distance(car.position,rig.get_player_position()) > 165.0
		and (car != rig.car or rig._flat_distance(car.position,job_site) > 120.0))
