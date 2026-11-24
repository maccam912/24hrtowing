extends Node3D
## A compressed Wisconsin township. All published locations are printed plat coordinates.
const Batch = preload("res://scripts/county_mesh.gd")
const Sites = preload("res://scripts/county_sites.gd")
const Bay = preload("res://scripts/county_bay.gd")
const TERRAIN_X := Vector2i(-795, 1100)
const TERRAIN_Z := Vector2i(-610, 1000)
const YARD := Rect2(-65,-90,68,61)
const ROADS := [
	["Highway 64", -635, 0, 930, 0], ["County K", 0, -420, 0, 800],
	["Kolpack Rd", 400, 0, 400, 800], ["County FF", 800, 0, 800, 800],
	["Hendricks Rd", 0, 400, 800, 400], ["Zielinski Rd", 0, 800, 800, 800],
	["Swamp Rd", -180, -400, 455, -400], ["US 59", -608, -280, -608, 350],
]
const PLACES := [
	["Brandt Towing", -32,-64], ["Fuel & Food",-71,18], ["St. Hedwig’s",22,80],
	["Brzezinski Dairy",90,425], ["Lindquist",431,246], ["Section 3",314,-400],
	["River bridge",-435,0], ["Esker Co-op",40,-22], ["Tamarack",895,0],
]
var lengthened := false
var county_model: Node3D
var hold: Node3D
var tripod: Node3D
var storm: MultiMeshInstance3D
var snow_shader: ShaderMaterial
var spindrift: MultiMeshInstance3D
var spindrift_shader: ShaderMaterial
var materials := {}
var bay: Node3D
var bay_locked := false
var hold_shown := false
var tripod_taken := false
var rng := RandomNumberGenerator.new()
var county_font: Font
var lamp_locations := {"sodium": [], "mercury": []}
var ballasts := {}
var lamp_update := 0

func _ready() -> void:
	if ResourceLoader.exists("res://assets/ui/fonts/overpass.ttf"):
		county_font = load("res://assets/ui/fonts/overpass.ttf")
	_make_materials()
	_weather()
	_fixture_audio()
	_build()

func map_roads() -> Array:
	var result := []
	for r: Array in ROADS:
		result.append({"name":r[0],"points":PackedVector2Array([Vector2(r[1],r[2]),Vector2(r[3],r[4])])})
	return result

func map_places() -> Array:
	var result := []
	for p: Array in PLACES:
		result.append({"name":p[0],"point":Vector2(p[1],p[2])})
	return result

func _mapped_z(z: float) -> float:
	return z + (40.0 * clampf((z-164.0)/72.0, 0, 1) if lengthened else 0.0)

func resolve_point(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, _mapped_z(p.z))

func _printed_z(z: float) -> float:
	if not lengthened:
		return z
	return z - 40.0*clampf((z-164.0)/112.0,0,1)

func try_lengthen(player_position: Vector3) -> bool:
	if lengthened:
		return true
	# Both the original farm and the new section must be beyond the storm horizon.
	# Leave the entire southern half untouched while it is occupied.
	if player_position.z >= 28.0:
		return false
	set_lengthened(true)
	return true

func set_lengthened(value: bool) -> void:
	if lengthened != value:
		lengthened = value
		if county_model:
			call_deferred("_build")

func bay_latch_point() -> Vector3:
	return Bay.LATCH

func set_bay_locked(value: bool) -> void:
	bay_locked = value
	if is_instance_valid(bay):
		bay.set_locked(value)

func hold_tripod_point() -> Vector3:
	return Vector3(318.5, ground_height(318.5,-413), -413)

func set_tripod_collected(value: bool) -> void:
	tripod_taken = value
	if tripod:
		tripod.visible = not value

func set_hold_scene(value: bool) -> void:
	hold_shown = value
	if hold:
		hold.visible = value

func follow_camera(pos: Vector3) -> void:
	if snow_shader:
		snow_shader.set_shader_parameter("eye",pos)
		spindrift_shader.set_shader_parameter("eye",pos)
		spindrift.position = pos
		storm.position = pos # keep the renderer's coarse bounds around the player
	lamp_update += 1
	if lamp_update % 12 == 1:
		for light_type: String in ballasts:
			var speaker: AudioStreamPlayer3D = ballasts[light_type]
			var nearest := Vector3.INF
			var farthest := 27.0*27.0
			if light_type=="sodium" or hold_shown:
				for source: Vector3 in lamp_locations[light_type]:
					var sq := pos.distance_squared_to(source)
					if sq < farthest:
						farthest=sq
						nearest=source
			if nearest.is_finite():
				speaker.position=nearest
				if not speaker.playing: speaker.play()
			elif speaker.playing:
				speaker.stop()

func _fixture_audio() -> void:
	# Only the nearest fixture of each type can be heard above the storm.
	for role: String in lamp_locations:
		var sound_path := "res://assets/audio/"+role+".mp3"
		if not ResourceLoader.exists(sound_path):
			continue
		var loop: AudioStreamMP3 = load(sound_path).duplicate()
		loop.loop = true
		var audio := AudioStreamPlayer3D.new()
		audio.stream = loop
		audio.max_distance = 28.
		audio.unit_size = 5.5
		audio.volume_db = -12.5
		audio.panning_strength = .8
		add_child(audio)
		ballasts[role] = audio

func road_distance(x: float, z: float) -> float:
	var distance := INF
	for r: Array in ROADS:
		var x0 := float(r[1])
		var x1 := float(r[3])
		var z0 := _mapped_z(r[2])
		var z1 := _mapped_z(r[4])
		var dx := x-clampf(x,minf(x0,x1),maxf(x0,x1))
		var dz := z-clampf(z,minf(z0,z1),maxf(z0,z1))
		distance = minf(distance, dx*dx + dz*dz)
	return sqrt(distance)

func _distance_from_lot(x: float, z: float) -> float:
	var nearest := INF
	for lot: Rect2 in [YARD,Rect2(-98,-2,46,31),Rect2(6,64,27,39),Rect2(426,230,43,36),Rect2(67,400,71,48),Rect2(-100,-28,140,55),Rect2(4,-38,78,43)]:
		var dx := maxf(0,maxf(lot.position.x-x, x-lot.end.x))
		var dz := maxf(0,maxf(lot.position.y-z, z-lot.end.y))
		nearest = minf(nearest, maxf(dx,dz))
	return nearest

func ground_height(x: float, z: float) -> float:
	var natural_z := _printed_z(z)
	if x > -501 and x < -449:
		var channel := smoothstep(0,8,minf(x+501,-449-x))
		if absf(z) > 6.6:
			return -4.4*channel*smoothstep(6.6,13,absf(z))
	var d := road_distance(x,z)
	if d < 4.9:
		return 0.0
	var lot := _distance_from_lot(x,natural_z)
	if lot < 0.01:
		return 0.0
	var bank := smoothstep(4.9,6.5,d)*(1.-smoothstep(6.5,8.0,d)) * .29
	var ditch := smoothstep(6.5,9,d)*(1.-smoothstep(10,16,d))
	var field := (0.37+0.7*sin(x*.019)+0.42*cos(natural_z*.024))*smoothstep(10,30,d)
	return (bank-.86*ditch+field)*smoothstep(0,5,lot)

func _paint(tint: String, texture_path := "", emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint)
	mat.roughness = .92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not texture_path.is_empty():
		mat.albedo_texture = load("res://assets/county/"+texture_path+".png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if emission > 0.:
		mat.emission_enabled = true
		mat.emission = Color(tint)
		mat.emission_energy_multiplier = emission
	return mat

func _make_materials() -> void:
	for item: Array in [
		["snow","d7dfe6","windpack"],["pavement","b2bcc5","salt_asphalt"],
		["siding","d0b9b3","barn_siding"],["silver","abb7c0","galvanized"],
		["cream","c2bfab"],["dark","34383a"],["wood","665449"],["brick","794a40"],
		["oxide","773e35"],["green","245d4c"],["post","87999c"],["black","1e262b"],
		["slush","8a97a4"],["stripe","a99875"],["glass","3e4d54"],["river","425263"],
		["lamp","ffac64","",0.82],["window","e6a46a","",0.43],["fluoro","dbe0db","",0.65],
		["white","dfded1","",0.05],["mercury","b7d9cf","",.85],["red","be343c","",.80],
		["sign","ffffff","brandt_enamel"],["spruce","e1e4e7","black_spruce"],
	]:
		materials[item[0]] = _paint(item[1],item[2] if item.size()>2 else "",item[3] if item.size()>3 else 0.0)
	var road_material := ShaderMaterial.new()
	road_material.shader = preload("res://assets/county/road.gdshader")
	road_material.set_shader_parameter("asphalt",load("res://assets/county/salt_asphalt.png"))
	road_material.set_shader_parameter("windpack",load("res://assets/county/windpack.png"))
	materials["road"] = road_material
	var yard_material: ShaderMaterial = road_material.duplicate()
	yard_material.shader = preload("res://assets/county/yard.gdshader")
	yard_material.set_shader_parameter("asphalt",load("res://assets/county/salt_asphalt.png"))
	yard_material.set_shader_parameter("windpack",load("res://assets/county/windpack.png"))
	materials["pavement"] = yard_material
	for surface: String in ["silver","siding"]:
		var wall: StandardMaterial3D=materials[surface]
		wall.uv1_triplanar=true
		wall.uv1_world_triplanar=true
		wall.uv1_scale=Vector3(.26,.16,.26)
	var spruce: StandardMaterial3D = materials.spruce
	spruce.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	spruce.alpha_scissor_threshold = 0.43
	var wire := ShaderMaterial.new()
	wire.shader = preload("res://assets/county/wire.gdshader")
	materials["wire"] = wire
	for role: String in ["sodium","cold_halo"]:
		var halo := ShaderMaterial.new()
		halo.shader = preload("res://assets/county/light_halo.gdshader")
		halo.set_shader_parameter("tint",Color("#ffb579") if role=="sodium" else Color("#b7d9cf"))
		materials[role] = halo

func _weather() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://assets/county/sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#94a5ba")
	env.ambient_light_energy = .64
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#354051")
	env.fog_light_energy = .76
	env.fog_depth_begin = 30.
	env.fog_depth_end = 146.
	env.fog_depth_curve = 1.13
	env.fog_sky_affect = .34
	env.fog_aerial_perspective = .08
	var weather := WorldEnvironment.new()
	weather.environment = env
	add_child(weather)
	var skylight := DirectionalLight3D.new()
	skylight.rotation_degrees = Vector3(-48,-34,10)
	skylight.light_color = Color("#a6b6cc")
	skylight.light_energy = .36
	add_child(skylight)
	var flake := QuadMesh.new()
	flake.size = Vector2(.046,.19)
	snow_shader = ShaderMaterial.new()
	snow_shader.shader = preload("res://assets/county/snow.gdshader")
	flake.material = snow_shader
	var spread := MultiMesh.new()
	spread.transform_format = MultiMesh.TRANSFORM_3D
	spread.use_custom_data = true
	spread.mesh = flake
	spread.instance_count = 1380
	rng.seed = 32006
	for i in spread.instance_count:
		spread.set_instance_transform(i,Transform3D.IDENTITY)
		spread.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
	storm = MultiMeshInstance3D.new()
	storm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	storm.multimesh = spread
	storm.custom_aabb = AABB(Vector3(-24,-12,-24),Vector3(48,24,48))
	add_child(storm)
	var wisp := QuadMesh.new()
	wisp.size = Vector2(7.0,.70)
	spindrift_shader = ShaderMaterial.new()
	spindrift_shader.shader = preload("res://assets/county/spindrift.gdshader")
	wisp.material = spindrift_shader
	var eddies := MultiMesh.new()
	eddies.transform_format = MultiMesh.TRANSFORM_3D
	eddies.use_custom_data = true
	eddies.mesh = wisp
	eddies.instance_count = 34
	for i in eddies.instance_count:
		eddies.set_instance_transform(i,Transform3D.IDENTITY)
		eddies.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
	spindrift=MultiMeshInstance3D.new()
	spindrift.multimesh = eddies
	spindrift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spindrift.custom_aabb=AABB(Vector3(-30,-10,-30),Vector3(60,16,60))
	add_child(spindrift)

func _build() -> void:
	if is_instance_valid(county_model):
		remove_child(county_model)
		county_model.queue_free()
	for role: String in lamp_locations:
		lamp_locations[role].clear()
	county_model = Node3D.new()
	county_model.name = "TamarackCounty"
	add_child(county_model)
	rng.seed = 75039
	var draw = Batch.new(county_model,materials)
	_build_ground(draw)
	var places = Sites.new(self,draw)
	places.build()
	draw.finish()
	bay = Bay.new()
	county_model.add_child(bay)
	bay.setup(materials,bay_locked)
	hold = Node3D.new()
	hold.name = "SwampRoadSectionThree"
	county_model.add_child(hold)
	tripod = Node3D.new()
	hold.add_child(tripod)
	var investigation = Sites.new(self,Batch.new(hold,materials))
	investigation.hold_site()
	investigation.draw.finish()
	var instrument = Sites.new(self,Batch.new(tripod,materials))
	instrument.survey_tripod()
	instrument.draw.finish()
	set_hold_scene(hold_shown)
	set_tripod_collected(tripod_taken)

func _axis(low: int, high: int, centers: Array, extra: Array) -> Array:
	var values := {}
	for i in range(low, high+1, 28):
		values[float(i)] = true
	for c: float in centers:
		for e: float in [-20.,-15.,-10.,-8.,-6.6,-5.0,0.,5.,6.6,8.,10.,15.,20.]:
			values[c+e] = true
	for i: float in extra+[low,high]:
		values[i] = true
	var result := values.keys()
	result.sort()
	return result

func _build_ground(draw) -> void:
	var xs := _axis(TERRAIN_X.x,TERRAIN_X.y,[-608,0,400,800],[-501,-493,-458,-449,-98,-65,-52,-2,67,138])
	var zs := _axis(TERRAIN_Z.x,TERRAIN_Z.y,[-400,0,400,800],[-90,-84,-61,-35,-29,-2,18,31,146,164,236,246,425,448])
	var ground := {}
	var h_rows := []
	for z: float in zs:
		var heights := PackedFloat32Array()
		for x: float in xs:
			heights.append(ground_height(x,_mapped_z(z)))
		h_rows.append(heights)
	for row in range(zs.size()-1):
		var z0 := _mapped_z(zs[row])
		var z1 := _mapped_z(zs[row+1])
		for col in range(xs.size()-1):
			var x0 := float(xs[col])
			var x1 := float(xs[col+1])
			var a := Vector3(x0,h_rows[row][col],z0)
			var b := Vector3(x1,h_rows[row][col+1],z0)
			var c := Vector3(x1,h_rows[row+1][col+1],z1)
			var d := Vector3(x0,h_rows[row+1][col],z1)
			var center := (a+c)*.5
			var natural_z := _printed_z(center.z)
			var road := road_distance(center.x,center.z) <= 5.0
			var yard_floor := YARD.has_point(Vector2(center.x,natural_z))
			var forecourt := Rect2(-98,-2,46,30).has_point(Vector2(center.x,natural_z))
			var material := "road" if road else ("pavement" if yard_floor or forecourt else "snow")
			var uv := PackedVector2Array()
			var highway := absf(center.z)<5.1 or absf(natural_z-400)<5.1 or absf(natural_z-800)<5.1 or absf(natural_z+400)<5.1
			var xline := 0.0
			var zline := 0.0
			if road:
				for axis: float in [-608.,400.,800.]:
					if absf(center.x-axis)<absf(center.x-xline): xline=axis
				for axis: float in [-400.,_mapped_z(400),_mapped_z(800)]:
					if absf(center.z-axis)<absf(center.z-zline): zline=axis
			for p: Vector3 in [a,b,c,d]:
				if road:
					uv.append(Vector2(p.z-zline,p.x) if highway else Vector2(p.x-xline,p.z))
				else:
					uv.append(Vector2(p.x*.18,p.z*.16))
			draw.quad(a,b,c,d,material,uv)
			var cell := Vector2i(floori(center.x/224.),floori(center.z/224.))
			if not ground.has(cell):
				ground[cell] = PackedVector3Array()
			var faces: PackedVector3Array = ground[cell]
			faces.append_array(PackedVector3Array([a,b,c,a,c,d]))
			ground[cell] = faces
	for cell: Vector2i in ground:
		var terrain := StaticBody3D.new()
		terrain.name = "Ground_%d_%d" % [cell.x,cell.y]
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(ground[cell])
		collision.shape = shape
		terrain.add_child(collision)
		county_model.add_child(terrain)
