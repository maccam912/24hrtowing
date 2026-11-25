extends Node3D
## Visuals own no collision bodies. Only a dispatched recovery becomes an active vehicle.
const Batch := preload("res://scripts/county_mesh.gd")
const Car := preload("res://scripts/rig_scene.gd")
const Kit := preload("res://scripts/rig_mesh.gd")
const SKY_LIGHT := preload("res://assets/county/sky_lights.gdshader")

var world: Node3D
var lights: Node3D
var lamps_material := ShaderMaterial.new()
var props: Node3D
var actor: Node3D
var line_hum: AudioStreamPlayer3D
var wire_origin := Vector3.ZERO
var starting := Vector3.ZERO
var direction := Vector3.FORWARD
var crossroad := Vector3.RIGHT
var sky_origin := Vector3.ZERO
var roadside := Vector3.ZERO
var street_lamps: Array = []
var remnants := {}
var passing_light := OmniLight3D.new()

func setup(county: Node3D) -> void:
	world = county
	county.add_child(self)
	name = "SightingSky"
	lights = Node3D.new()
	add_child(lights)
	lamps_material.shader = SKY_LIGHT
	for offset: Vector3 in [Vector3(-5,0,1),Vector3.ZERO,Vector3(5.8,.65,0)]:
		var lamp := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(12,12)
		quad.material = lamps_material
		lamp.mesh = quad
		lamp.position = offset
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lights.add_child(lamp)
	lights.hide()
	passing_light.light_color = Color("#c9ffdf")
	passing_light.omni_range = 68.
	passing_light.omni_attenuation = .65
	add_child(passing_light)
	passing_light.hide()

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x,world.ground_height(at.x,at.z),at.z)

func _vehicle(parent: Node3D, tint := 0, taped := false, identity := {}, running := true) -> Node3D:
	var car := Car.car(parent,"hazard" if taped else "unattended",tint,identity)
	if running:
		Car.car_lamps(car,"running",-1)
	return car

func _animal(parent: Node3D, cow: bool) -> Node3D:
	var body := Node3D.new()
	parent.add_child(body)
	var kit := Kit.new(body)
	var hide := Color("#a09377") if not cow else Color("#403d38")
	var patch := Color("#c3c0ab")
	kit.box(Vector3(0,1.05,0),Vector3(.64 if cow else .38,.66,1.44),hide)
	if cow:
		kit.box(Vector3(-.02,1.14,-.32),Vector3(.66,.53,.55),patch)
	kit.beam(Vector3(0,1.15,-.52),Vector3(0,1.82,-.80),.28,.31,hide)
	kit.box(Vector3(0,1.80,-.92),Vector3(.38,.36,.57),hide,Vector3(-.32,0,0))
	for side: float in [-1,1]:
		kit.box(Vector3(side*.24,1.98,-.78),Vector3(.27,.085,.14),hide,Vector3(0,0,side*.36))
		for z: float in [-.48,.52]:
			kit.beam(Vector3(side*.19,.96,z),Vector3(side*.22,.02,z+.09),.095,.10,hide)
		if not cow:
			kit.beam(Vector3(side*.11,1.95,-.83),Vector3(side*.32,2.33,-.62),.044,.046,hide)
			kit.beam(Vector3(side*.23,2.16,-.70),Vector3(side*.19,2.33,-.81),.034,.030,hide)
	kit.finish()
	return body

func _ground_patch(parent: Node3D, at: Vector3, radius: float, grassy: bool) -> void:
	# Follow the topography around the entire perimeter so no edge floats.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color("#50763d") if grassy else Color("#383b38")
	wet.roughness = .48 if grassy else .22
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(wet)
	var center := ground(at)+Vector3.UP*.09
	for i in 40:
		var a := TAU*i/40.0
		var b := TAU*(i+1)/40.0
		for v: Vector3 in [center,ground(at+Vector3(cos(a)*radius,0,sin(a)*radius))+.092*Vector3.UP,ground(at+Vector3(cos(b)*radius,0,sin(b)*radius))+.092*Vector3.UP]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(v)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = surface.commit()
	parent.add_child(floor_mesh)
	for i in 4:
		var vapor := MeshInstance3D.new()
		var sheet := QuadMesh.new()
		sheet.size = Vector2(radius*.86,1.7)
		var steam := ShaderMaterial.new()
		steam.shader = preload("res://assets/county/ground_vapor.gdshader")
		steam.set_shader_parameter("seed",i*.27)
		sheet.material = steam
		vapor.mesh = sheet
		parent.add_child(vapor)
		var offset := Vector3(cos(i*2.4),0,sin(i*2.4))*radius*.55
		vapor.position = ground(at+offset)+Vector3.UP*.74
		vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if grassy:
		var flowers := Kit.new(parent)
		for i in 24:
			var offset := Vector3(sin(i*2.4),0,cos(i*2.4))*sqrt(float(i)/24.0)*radius
			flowers.box(ground(at+offset)+Vector3.UP*.16,Vector3(.10,.04,.10),Color("#e8cc4b"))
		flowers.finish()

func _marks(parent: Node3D, at: Vector3, forward: Vector3, hoof := false) -> void:
	var kit := Kit.new(parent)
	var side := forward.cross(Vector3.UP)
	for i in 29:
		var p := ground(at+forward*(i*.73)+side*.12*(1 if i%2 else -1))
		kit.box(p+.045*Vector3.UP,Vector3(.16,.035,.21 if hoof else .32),Color("#9ca7ad"),Vector3(0,atan2(-forward.x,-forward.z),0))
	kit.finish()

func add_remnant(key: String, entry: Dictionary) -> void:
	if remnants.has(key): return
	var parent := Node3D.new()
	parent.name = "Trace_"+key
	add_child(parent)
	remnants[key] = parent
	var at := Vector3(entry.x,0,entry.z)
	var id: String = entry.id
	var facing := Vector3.FORWARD.rotated(Vector3.UP,float(entry.get("yaw",0)))
	match id:
		"field_car","nose_car","tree_car","roof_car","ice_car","gate_car","shoulder_car","walker_car","roadside_tape":
			var vehicle: Dictionary = entry.get("vehicle",{})
			var car := _vehicle(parent,int(vehicle.get("variant",0)),not vehicle.get("untaped",true),vehicle,id != "roadside_tape")
			car.position = ground(at)+Vector3.UP*float(entry.get("height",0))
			car.rotation.y = entry.get("yaw",0.)
			if id == "field_car":
				car.rotate_object_local(Vector3.BACK,PI)
				car.position.y += 1.68
			elif id == "nose_car":
				car.rotate_object_local(Vector3.RIGHT,-PI*.5)
				car.position.y += 2.16
		"cow_ring":
			for i in 11:
				var radial := Vector3(cos(i*TAU/11),0,sin(i*TAU/11))
				var cow := _animal(parent,true)
				cow.position = ground(at+radial*11.)
				cow.rotation.y = atan2(radial.x,radial.z)
		"pressed_lines","dry_road","snow_roof":
			var grooves := Kit.new(parent)
			var side := facing.cross(Vector3.UP)
			for i in (5 if id=="pressed_lines" else 1):
				var pos := ground(at+side*(i-2)*1.45) if id=="pressed_lines" else ground(at)
				grooves.box(pos+Vector3.UP*.06,Vector3(.32 if id=="pressed_lines" else 8.0,.045,28 if id=="pressed_lines" else 105),Color("#535e65" if id=="pressed_lines" else "#3f4649"),Vector3(0,entry.get("yaw",0),0))
			grooves.finish()
		"hoofprints","bootprints":
			_marks(parent,at,facing,id=="hoofprints")
		"woods_tracks":
			_tree_gap(parent,at,facing)
			var tread := Kit.new(parent)
			var across := facing.cross(Vector3.UP)
			for i in 18:
				for wheel: float in [-.78,.78]:
					var p := ground(at+facing*(i*1.2)+across*wheel)+Vector3.UP*.065
					tread.box(p,Vector3(.21,.045,1.24),Color("#89949b"),Vector3(0,entry.yaw,0))
			tread.finish()
			_ground_patch(parent,at+facing*21.,4.0,false)
		"empty_ditch":
			_ground_patch(parent,at,3.,false)
			var tape := Kit.new(parent)
			tape.box(ground(at)+Vector3.UP*.12,Vector3(1.16,.02,.16),Color("#f5d22e"))
			tape.finish()
		_:
			_ground_patch(parent,at,6.4,id=="green_circle")

func _tree_gap(parent: Node3D, at: Vector3, along: Vector3) -> void:
	var grove := Batch.new(parent,world.materials)
	var side := along.cross(Vector3.UP)
	for i in 3:
		for edge: float in [-1.,1.]:
			var p := ground(at+along*(6.+i*4.5)+side*edge*(.77+float(i)*.25))
			grove.spruce(p,5.3+absf(sin(float(i*3)+edge))*3.4,float(i)*2.+edge)
	grove.finish()

func remove_remnant(key: String) -> void:
	if remnants.has(key):
		var model: Node3D = remnants[key]
		model.hide()
		model.queue_free()
		remnants.erase(key)

func clear_live() -> void:
	lights.hide()
	passing_light.hide()
	for lamp: Node3D in street_lamps:
		if is_instance_valid(lamp): lamp.show()
	street_lamps.clear()
	actor = null
	line_hum = null
	if is_instance_valid(props):
		props.hide()
		props.queue_free()
	props = null

func begin(id: String, at: Vector3, forward: Vector3, side_point: Vector3, level: int, identity := {}) -> void:
	clear_live()
	props = Node3D.new()
	props.name = "Pass_"+id
	add_child(props)
	starting = at
	direction = forward
	crossroad = forward.cross(Vector3.UP)
	roadside = side_point
	var distance := 225. if level <= 1 else (140. if level == 2 else 92.)
	sky_origin = ground(starting+forward*distance+crossroad*distance*.44)+Vector3.UP*(distance*.16)
	if id == "swamp_lights":
		sky_origin = ground(starting+forward*215.+crossroad*57.)+Vector3.UP*40.
	if id in ["set_down","the_lift","far_landing","snow_column","snow_up","angie_lights"]:
		sky_origin = roadside+Vector3.UP*(24. if id=="set_down" else 19.)
	if id == "yard_visit": sky_origin = Vector3(-44,24,-77)
	if id == "streetlights_out":
		street_lamps = world.get_tree().get_nodes_in_group("esker_street_lamps")
		street_lamps.sort_custom(func(a,b):return a.position.x < b.position.x)
	match id:
		"the_lift","woods_car","empty_oncoming","set_down","plow_stopped":
			actor = Car.county_plow(props,identity) if id=="plow_stopped" else _vehicle(props,int(identity.get("variant",0)),id=="the_lift",identity)
			actor.position = roadside+Vector3.UP*20.0 if id=="set_down" else roadside
			actor.rotation.y = identity.get("yaw",atan2(-forward.x,-forward.z))
			if id=="empty_oncoming": actor.rotate_y(PI)
			if id=="woods_car": _tree_gap(props,roadside+crossroad*7.,crossroad)
		"walker":
			actor = Car.person(props,false)
			Car.walk_person(actor)
			actor.rotation.y = atan2(-crossroad.x,-crossroad.z)
		"deer_line":
			for i in 5:
				var deer := _animal(props,false)
				deer.position = ground(roadside+crossroad*(i*1.65))
				deer.rotation.y = atan2(-crossroad.x,-crossroad.z)
		"power_lines":
			# All named pole rows use the field side of the positive road axis.
			var axis := Vector3(absf(direction.x),0,absf(direction.z))
			var closest := Vector2(at.x,at.z)
			for r: Array in world.ROADS:
				var projected := Geometry2D.get_closest_point_to_segment(closest,Vector2(r[1],r[2]),Vector2(r[3],r[4]))
				if projected.distance_to(closest)<6.8:
					closest = projected
					break
			wire_origin = Vector3(closest.x,0,closest.y)+axis.cross(Vector3.UP)*12.9+direction*4.
			for i in 28:
				var tuft := Node3D.new()
				props.add_child(tuft)
				var kit := Kit.new(tuft)
				for j in 5:
					kit.box(Vector3(sin(j*12.7)*.26,-absf(sin(j*7.3))*.17,cos(j*7.2)*.39),Vector3(.10,.11,.12),Color("#ccd5d9"))
				kit.finish()
			line_hum = AudioStreamPlayer3D.new()
			var motor: AudioStreamMP3 = preload("res://assets/audio/sodium.mp3").duplicate()
			motor.loop = true
			line_hum.stream = motor
			line_hum.pitch_scale = .73
			line_hum.max_distance = 66.
			line_hum.unit_size = 12.
			line_hum.volume_db = -10.
			props.add_child(line_hum)
			if DisplayServer.get_name()!="headless": line_hum.play()
		"snow_up","snow_column":
			var motes := Kit.new(props)
			for i in 72:
				var r := sin(i*17.7)*1.9
				var q := Vector3(cos(i*2.4)*r,float(i)/4.0,sin(i*2.4)*r)
				motes.box(roadside+q,Vector3(.08,.45,.08),Color("#cae4df"),Vector3.ZERO,"lamp")
			motes.finish()

func animate(id: String, t: float, strength: float, truck_at: Vector3, heading: Vector3) -> Vector3:
	var location := sky_origin
	match id:
		"pacing_lights","compass_turns","electrics_fade","radio_pulse":
			location = truck_at + (sky_origin-starting)
		"mirror_follow":
			location = truck_at-heading*67.+heading.cross(Vector3.UP)*12.+Vector3.UP*10.
		"overhead","hanging_snow","storm_hole":
			location = truck_at + direction*lerpf(63.,-66.,t) + Vector3.UP*15.
		"far_landing":
			location.y -= sin(PI*t)*17.
		"yard_visit":
			location.z -= smoothstep(.52,1.,t)*80.
		"the_lift":
			actor.position = roadside+Vector3.UP*(smoothstep(.23,.67,t)*23.)+crossroad*smoothstep(.57,1.,t)*42.
			location = actor.position+Vector3.UP*12.
		"set_down":
			actor.position = roadside+Vector3.UP*(1.-smoothstep(.10,.71,t))*20.
			location = actor.position+Vector3.UP*(14.+smoothstep(.77,1.,t)*32.)
		"empty_oncoming":
			actor.position = ground(roadside-direction*t*130.)
		"woods_car","walker":
			var travel := t*13. if id=="walker" else smoothstep(.09,.90,t)*44.
			actor.position = ground(roadside+crossroad*travel)+(Vector3.UP*.42 if id=="woods_car" else Vector3.ZERO)
			if id=="woods_car": actor.position.y = roadside.y+.56
		"deer_line":
			for i in props.get_child_count():
				props.get_child(i).position = ground(roadside+crossroad*(i*1.65+smoothstep(.63,1.,t)*9.))
		"streetlights_out":
			for i in street_lamps.size():
				var wave := t*2.25-float(i)/maxi(1,street_lamps.size())*.6
				if is_instance_valid(street_lamps[i]): street_lamps[i].visible = wave < .15 or wave > 1.27
		"power_lines":
			for i in 28:
				var age := (t-.10)*1.8-i/27.0
				var tuft := props.get_child(i) as Node3D
				tuft.visible = age>=0.0 and age<.18
				tuft.position = ground(wire_origin+direction*(i*1.8))+Vector3.UP*(6.8-pow(maxf(0.,age),2)*200.)
			line_hum.position = wire_origin+direction*(t*50.)+Vector3.UP*6.
		"snow_column","snow_up":
			props.position.y = fmod(t*9.,2.0)
	lights.position = location
	var sightline := location-truck_at
	if Vector2(sightline.x,sightline.z).length_squared()>.1:
		lights.rotation.y = atan2(sightline.x,sightline.z)
	var show_lights := id not in ["the_calm","warm_air","green_flash","moving_moon","missing_time","snow_roof","dry_road","thaw_glaze"]
	lights.visible = show_lights and strength>.02
	var lamp_scale := .72 if id in ["overhead","set_down"] else 1.0
	lights.scale = Vector3.ONE*lamp_scale
	lamps_material.set_shader_parameter("tint",Color(.76,1.0,.86,strength))
	passing_light.visible = id in ["overhead","storm_hole","set_down","the_lift","angie_lights"] and strength>.02
	passing_light.position = location
	passing_light.light_energy = strength*4.8
	return location if lights.visible else Vector3.INF
