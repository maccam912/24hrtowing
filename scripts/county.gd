extends Node3D
## A compressed Wisconsin township. All published locations are printed plat coordinates.
const Batch = preload("res://scripts/county_mesh.gd")
const Sites = preload("res://scripts/county_sites.gd")
const Dryhouse := preload("res://scripts/ginseng_dryhouse.gd")
const RiverLanes := preload("res://scripts/river_lanes.gd")
const Dairy := preload("res://scripts/dairy_transfer.gd")
const Fittings := preload("res://scripts/yard_fittings.gd")
const Memorial = preload("res://scripts/memorial_hospital.gd")
const FuelStore = preload("res://scripts/fuel_store.gd")
const CaseSites = preload("res://scripts/county_case_sites.gd")
const Bay = preload("res://scripts/county_bay.gd")
const Scene = preload("res://scripts/rig_scene.gd")
const SURVEY_PICKUP := Vector3(314,0,-409)
const SURVEY_YAW := .38
const HOFFMANN_LANE_END := Vector2(457,336)
const Town := preload("res://scripts/esker_main_street.gd")
const FireBay := preload("res://scripts/esker_fire_bay.gd")
const East := preload("res://scripts/tamarack_highway.gd")
const TERRAIN_X := Vector2i(-795, 2250)
const TERRAIN_Z := Vector2i(-610, 1000)
const YARD := Rect2(-65,-90,68,61)
const Flowage := preload("res://scripts/flowage_pull.gd")
const ROADS := [
	["River Rd",Flowage.ROAD_X,-158,Flowage.ROAD_X,0],
	["Highway 64", -635, 0, East.CLOSURE_X, 0], ["County K", 0, -420, 0, 800],
	["Kolpack Rd", 400, 0, 400, 800], ["County FF", 800, 0, 800, 800],
	["Hendricks Rd", 0, 400, 800, 400], ["Zielinski Rd", 0, 800, 800, 800],
	["Swamp Rd", -180, -400, 455, -400], ["US 59", -608, -280, -608, 350],
]
const PLACES := [
	["Brandt Towing", -32,-64], ["Fuel & Food",-71,18], ["St. Hedwig’s",22,80],
	["Brzezinski Dairy",90,425], ["Lindquist",431,246], ["Section 3",314,-400],
	["Tamarack Memorial",852,19], ["River bridge",-435,0], ["Flowage landing",-434,-141], ["Esker Co-op",40,-22], ["Tamarack",895,0], ["Esker Fire Hall",Town.HALL.x,Town.HALL.y], ["Esker Tap",-30,20], ["Esker Cheese Factory",-164,-20], ["Zion Lutheran",-24,73], ["County Highway Garage",East.CURB.x,East.CURB.z], ["Cedar Creek",1325,0],
]
var alder_open := false
var case_landmarks := {"angie_house":true,"mailboxes":true}
var case_models := {}
var rebuild_queued := false
var county_model: Node3D
var hold: Node3D
var tripod: Node3D
var survey_pickup: Node3D
var survey_point := SURVEY_PICKUP
var survey_yaw := SURVEY_YAW
var rod_case: Node3D
var rod_case_read := false
var rod_turn: Tween
var storm_environment: Environment
var calm := 0.0
var hanging := 0.0
var tower_view := false
var tower_meshes: Array[GeometryInstance3D] = []
var sky_material: ShaderMaterial
var skylight: DirectionalLight3D
var wind_time := 0.0
var storm_time := 0.0
var storm_gust := 0.0
var storm_travel := 0.0
var thawed_roads := {}
var roof_strength := 0.0
var storm: MeshInstance3D
var surface_x: Array
var surface_z: Array
var surface_rows: Array
var snow_shader: ShaderMaterial
var powder_clouds: MultiMeshInstance3D
var powder_shader: ShaderMaterial
var spindrift: MultiMeshInstance3D
var spindrift_shader: ShaderMaterial
var wind_materials: Array[ShaderMaterial] = []
var materials := {}
var yard_dispenser := false
var yard_brewer := false
const PoolRepair := preload("res://scripts/pool_repair.gd")
const WestBay := preload("res://scripts/west_hold_bay.gd")
var west_bay: WestBay
var west_bay_fitted := false
var west_lot_open := false
var fittings_model: Node3D
var fire_bay: FireBay
var fuel_door: Node3D
var bay: Node3D
var drop_guide := Node3D.new()
var freight_guide := Node3D.new()
var milk_guide := Node3D.new()
var favor_guide: Node3D
var bay_locked := false
var survey_pickup_parked := true
var tripod_taken := false
var rng := RandomNumberGenerator.new()
var county_font: Font
var lamp_locations := {"sodium": []}
var ballasts := {}
var lamp_update := 0

func _ready() -> void:
	if ResourceLoader.exists("res://assets/ui/fonts/overpass.ttf"):
		county_font = load("res://assets/ui/fonts/overpass.ttf")
	_make_materials()
	_weather()
	_fixture_audio()
	_build()
	drop_guide.name = "ActiveDropLights"
	add_child(drop_guide)
	var guide = Sites.new(self,Batch.new(drop_guide,materials))
	guide.drop_guide()
	guide.draw.finish()
	drop_guide.hide()
	freight_guide.name = "FreightBayLamps"
	add_child(freight_guide)
	freight_guide.position = RiverLanes.CENTER
	var receiving := RiverLanes.new(self,Batch.new(freight_guide,materials))
	receiving.build_guide()
	receiving.draw.finish()
	freight_guide.hide()
	milk_guide.name = "MilkHouseLamps"
	add_child(milk_guide)
	milk_guide.position = Dairy.CENTER
	var transfer := Dairy.new(self,Batch.new(milk_guide,materials))
	transfer.build_guide()
	transfer.draw.finish()
	milk_guide.hide()

func map_roads() -> Array:
	var result := []
	for r: Array in ROADS:
		result.append({"name":r[0],"points":PackedVector2Array([Vector2(r[1],r[2]),Vector2(r[3],r[4])])})
	result.append({"name":"Alder Cut Rd","points":PackedVector2Array([Vector2(CaseSites.ALDER_X,-400),Vector2(CaseSites.ALDER_X,-470)])})
	result.append({"name":"Hoffmann lane","points":PackedVector2Array([Vector2(400,336),HOFFMANN_LANE_END])})
	return result

func set_favor_guide(at: Vector3, yaw: float) -> void:
	if not at.is_finite():
		if favor_guide:
			favor_guide.hide()
		return
	if not favor_guide:
		favor_guide = Scene.warning_triangle(self,Vector3.ZERO,0)
		favor_guide.name = "FavorStopGuide"
		var guide = Sites.new(self,Batch.new(favor_guide,materials))
		guide.favor_lamps()
		guide.draw.finish()
	favor_guide.position = Vector3(at.x,ground_height(at.x,at.z),at.z)
	favor_guide.rotation.y = yaw
	favor_guide.show()

func map_places() -> Array:
	var result := []
	for p: Array in PLACES:
		result.append({"name":p[0],"point":Vector2(p[1],p[2])})
	result.append({"name":"N5420 Alder Cut","point":Vector2(462,-470)})
	result.append({"name":"N5104 Hoffmann","point":Vector2(446,331)})
	result.append({"name":"Esker water tower","point":Vector2(44,-68)})
	result.append({"name":"River Lanes receiving","point":RiverLanes.BAY.get_center()})
	return result

func resolve_point(p: Vector3) -> Vector3:
	return p

func _queue_build() -> void:
	if county_model and not rebuild_queued:
		rebuild_queued = true
		_build.call_deferred()

func yard_contains(point: Vector2) -> bool:
	return YARD.has_point(point) or (west_lot_open and Fittings.WEST_LOT.has_point(point))

func fit_yard(dispenser: bool, brewer: bool, west_lot := false, second_bay := false) -> void:
	if dispenser == yard_dispenser and brewer == yard_brewer and west_lot == west_lot_open and second_bay == west_bay_fitted:
		return
	yard_dispenser = dispenser
	yard_brewer = brewer
	west_lot_open = west_lot
	west_bay_fitted = second_bay and west_lot
	_build_yard_fittings()

func _build_yard_fittings() -> void:
	if is_instance_valid(fittings_model):
		fittings_model.get_parent().remove_child(fittings_model)
		fittings_model.queue_free()
		fittings_model = null
	fittings_model = Node3D.new()
	fittings_model.name = "ShopFittings"
	county_model.add_child(fittings_model)
	var geometry := Batch.new(fittings_model,materials)
	var fittings := Fittings.new(self,geometry)
	fittings.assemble(yard_dispenser,yard_brewer)
	fittings.west_fence(west_lot_open)
	geometry.finish()
	if west_bay_fitted and not is_instance_valid(west_bay):
		west_bay = WestBay.new()
		add_child(west_bay)
		west_bay.build(self)
	elif not west_bay_fitted and is_instance_valid(west_bay):
		remove_child(west_bay)
		west_bay.queue_free()
		west_bay = null

func coffee_counter_point() -> Vector3:
	return FuelStore.FORECOURT + FuelStore.COUNTER

func inside_fuel_store(point: Vector3) -> bool:
	return FuelStore.inside(point)

func is_heated_shelter(point: Vector3) -> bool:
	return Bay.sheltered(point) or FuelStore.inside(point)

func bay_latch_point() -> Vector3:
	return Bay.LATCH

func set_bay_locked(value: bool) -> void:
	bay_locked = value
	if is_instance_valid(bay):
		bay.set_locked(value)

func hold_tripod_point() -> Vector3:
	return Vector3(318.5, ground_height(318.5,-413), -413)

func survey_door_point() -> Vector3:
	var point := resolve_point(survey_point)
	point.y = ground_height(point.x,point.z)
	return point + Vector3(-1.03,.94,-.46).rotated(Vector3.UP,survey_yaw)

func set_survey_anchor(point: Vector3, yaw: float) -> void:
	survey_point = point
	survey_yaw = yaw
	if is_instance_valid(survey_pickup):
		survey_pickup.position = resolve_point(point)
		survey_pickup.position.y = ground_height(survey_pickup.position.x,survey_pickup.position.z)
		survey_pickup.rotation.y = yaw

func rod_case_point() -> Vector3:
	return Vector3(331,ground_height(331,-483)+.30,-483)

func set_rod_case_read(value: bool) -> void:
	if value == rod_case_read:
		return
	rod_case_read = value
	if not is_instance_valid(rod_case):
		return
	if rod_turn and rod_turn.is_valid():
		rod_turn.kill()
	rod_turn = rod_case.create_tween()
	rod_turn.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rod_turn.tween_property(rod_case,"rotation:x",PI if value else 0.0,.45)

func story_point(id: String) -> Vector3:
	if not CaseSites.POINTS.has(id):
		return Vector3.INF
	var point: Vector3 = CaseSites.POINTS[id]
	point.y += ground_height(point.x,point.z)
	return point

func set_case_landmarks(ids: Array) -> void:
	var requested := {"angie_house":true,"mailboxes":true}
	for id: String in ids:
		if CaseSites.POINTS.has(id):
			requested[id] = true
	if requested == case_landmarks:
		return
	case_landmarks = requested
	var open_spur := requested.has("last_cap") or requested.has("tou")
	if alder_open != open_spur:
		alder_open = open_spur
		_queue_build()
	elif county_model and not rebuild_queued:
		_sync_case_models()

func _sync_case_models() -> void:
	for id: String in case_models.keys():
		if not case_landmarks.has(id):
			var retired: Node3D = case_models[id]
			county_model.remove_child(retired)
			retired.queue_free()
			case_models.erase(id)
	for id: String in case_landmarks:
		if case_models.has(id):
			continue
		var landmark := Node3D.new()
		landmark.name = id
		county_model.add_child(landmark)
		CaseSites.new(self,Batch.new(landmark,materials)).build_landmark(id)
		case_models[id] = landmark

func set_tripod_collected(value: bool) -> void:
	tripod_taken = value
	if tripod:
		tripod.visible = not value

func set_survey_pickup_parked(value: bool) -> void:
	survey_pickup_parked = value
	if is_instance_valid(survey_pickup):
		survey_pickup.visible = value
		survey_pickup.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

func road_contact(at: Vector3) -> Vector2:
	var result := Vector2(1.,0.)
	if thawed_roads.is_empty(): return result
	for patch: Node3D in thawed_roads.values():
		if not patch.is_visible_in_tree(): continue
		var sample: Vector2 = patch.contact(at)
		if absf(sample.x-1.) > absf(result.x-1.): result.x = sample.x
		result.y = maxf(result.y,sample.y)
	return result

func shelter_road_snow(amount: float) -> void:
	if amount==0. and roof_strength==0.: return
	roof_strength = amount
	var strip: Node3D = thawed_roads.get("snow_roof")
	var span := Vector2(strip.half_length,amount) if strip else Vector2.ZERO
	for material: ShaderMaterial in [snow_shader,powder_shader,spindrift_shader]:
		if strip: material.set_shader_parameter("roof_strip",strip.geometry())
		material.set_shader_parameter("roof_span",span)

func set_sighting_weather(id: String, strength: float, progress: float) -> void:
	calm = strength
	hanging = strength if id in ["overhead","hanging_snow","storm_hole","set_down"] else 0.0
	var hole := strength if id == "storm_hole" else 0.0
	var glow := strength if id == "moving_moon" else 0.0
	var flash := strength * pow(maxf(0.0,sin(progress*10.0)),10.0) if id == "green_flash" else 0.0
	sky_material.set_shader_parameter("opening",hole)
	sky_material.set_shader_parameter("glow",glow+flash)
	sky_material.set_shader_parameter("passage",progress)
	skylight.rotation_degrees.y = -34.0+glow*(progress*130.0-65.0)
	skylight.light_energy = 0.30+glow*0.60+flash*0.8
	if id != "snow_roof": shelter_road_snow(0.)
	powder_clouds.transparency = 0. if id=="snow_roof" else strength
	spindrift.transparency = powder_clouds.transparency

func advance_storm(dt: float) -> void:
	storm_time += dt * (1.0-hanging)
	wind_time += dt * (1.0-calm)
	# Broad gust fronts pass at uneven intervals. Integrate the wind so flakes
	# keep moving downwind as a front recedes, even on a long night shift.
	var front := sin(storm_time * .42 + 1.2 * sin(storm_time * .13) - .7)
	storm_gust = smoothstep(-.30, .90, front) * (1.0-calm)
	storm_travel += dt * lerpf(13.5, 27.0, storm_gust) * (1.0-calm)
	# The Adreno 830 GLES compiler crashes when the wind shaders read these
	# values through Godot's global uniform buffer on the first yard frame.
	for material in wind_materials:
		material.set_shader_parameter(&"storm_time", storm_time if material == snow_shader else wind_time)
		material.set_shader_parameter(&"storm_gust", storm_gust)
	snow_shader.set_shader_parameter(&"storm_travel", storm_travel)
	snow_shader.set_shader_parameter(&"calm", calm)
	snow_shader.set_shader_parameter(&"hanging", hanging)
	powder_shader.set_shader_parameter(&"storm_travel", storm_travel)
	spindrift_shader.set_shader_parameter(&"storm_travel", storm_travel)
	storm_environment.fog_depth_begin = 420.0 if tower_view else lerpf(16.0,6.0,storm_gust)+75.0*calm
	storm_environment.fog_depth_end = 760.0 if tower_view else lerpf(98.0,60.0,storm_gust)+100.0*calm

func follow_camera(pos: Vector3, in_cab := false, in_store := false) -> void:
	if is_instance_valid(fuel_door):
		fuel_door.sense(pos,get_physics_process_delta_time())
	var elevated := pos.y >= 14.0 and Vector2(pos.x,pos.z).distance_to(Vector2(44,-68)) < 24.0
	if elevated != tower_view:
		tower_view = elevated
		for mesh: GeometryInstance3D in tower_meshes:
			mesh.visibility_range_end = 850.0 if elevated else 230.0
	if snow_shader:
		snow_shader.set_shader_parameter("eye",pos)
		powder_shader.set_shader_parameter("eye",pos)
		powder_clouds.position = pos
		spindrift_shader.set_shader_parameter("eye",pos)
		spindrift.position = pos
		storm.position = pos # keep the renderer's coarse bounds around the player
	lamp_update += 1
	if lamp_update % 12 == 1:
		for light_type: String in ballasts:
			var speaker: AudioStreamPlayer3D = ballasts[light_type]
			speaker.volume_db = lerpf(-12.5 - (17.0 if in_store else (12.0 if in_cab else 0.0)),-80.0,calm)
			var nearest := Vector3.INF
			var farthest := 27.0*27.0
			for source: Vector3 in lamp_locations[light_type]:
				var sq := pos.distance_squared_to(source)
				if sq < farthest:
					farthest=sq
					nearest=source
			if nearest.is_finite() and calm < .985:
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

func road_distance(x: float, z: float, include_alder := true) -> float:
	var distance := INF
	if include_alder:
		var dx := x-CaseSites.ALDER_X
		var dz := z-clampf(z,CaseSites.ALDER_END if alder_open else -470.0,-400)
		distance = dx*dx+dz*dz
	var lane_dx := x-clampf(x,400,HOFFMANN_LANE_END.x)
	var lane_dz := z-HOFFMANN_LANE_END.y
	distance = minf(distance,lane_dx*lane_dx+lane_dz*lane_dz)
	for r: Array in ROADS:
		var x0 := float(r[1])
		var x1 := float(r[3])
		var z0 := float(r[2])
		var z1 := float(r[4])
		var dx := x-clampf(x,minf(x0,x1),maxf(x0,x1))
		var dz := z-clampf(z,minf(z0,z1),maxf(z0,z1))
		distance = minf(distance, dx*dx + dz*dz)
	return sqrt(distance)

func _distance_from_lot(x: float, z: float) -> float:
	if x > 1050:
		return Vector2(x,z).distance_to(Vector2(x,z).clamp(East.LOT.position,East.LOT.end))
	var nearest := INF
	var edge := CaseSites.HOUSE_YARD
	nearest = maxf(0,maxf(maxf(edge.position.x-x,x-edge.end.x),maxf(edge.position.y-z,z-edge.end.y)))
	if Rect2(422,317,34,18).has_point(Vector2(x,z)):
		return 0.0
	for lot: Rect2 in [YARD,Town.APRON,Town.CHEESE_YARD,Town.ZION_YARD,Fittings.WEST_LOT,Flowage.LANDING,Memorial.LOT,RiverLanes.LOT,Rect2(-98,-2,46,31),Rect2(6,64,27,39),Rect2(426,230,43,36),Rect2(67,400,71,48),Rect2(-100,-28,140,55),Rect2(4,-38,78,43),Rect2(304,-412,19,13)]:
		var dx := maxf(0,maxf(lot.position.x-x, x-lot.end.x))
		var dz := maxf(0,maxf(lot.position.y-z, z-lot.end.y))
		nearest = minf(nearest, maxf(dx,dz))
	return nearest

func ground_height(x: float, z: float) -> float:
	if x > -501 and x < -449:
		var channel := smoothstep(0,8,minf(x+501,-449-x))
		if absf(z) > 6.6:
			var floor_height := -2.01 if z <= -108 else -4.4
			return floor_height*channel*smoothstep(6.6,13,absf(z))
	var d := road_distance(x,z)
	if d < 4.9:
		return 0.0
	var lot := _distance_from_lot(x,z)
	if lot < 0.01:
		return 0.0
	var bank := smoothstep(4.9,6.5,d)*(1.-smoothstep(6.5,8.0,d)) * .29
	var ditch := smoothstep(6.5,9,d)*(1.-smoothstep(10,16,d))
	var field := (0.37+0.7*sin(x*.019)+0.42*cos(z*.024))*smoothstep(10,30,d)
	return (bank-.86*ditch+field)*smoothstep(0,5,lot)

## Height of the triangle drawn under a small footprint on a sloping snowbank.
func surface_point(at: Vector3) -> Vector3:
	if surface_rows.is_empty(): return Vector3(at.x,ground_height(at.x,at.z),at.z)
	var col := clampi(surface_x.bsearch(at.x)-1,0,surface_x.size()-2)
	var row := clampi(surface_z.bsearch(at.z)-1,0,surface_z.size()-2)
	var u := clampf(inverse_lerp(surface_x[col],surface_x[col+1],at.x),0.,1.)
	var v := clampf(inverse_lerp(surface_z[row],surface_z[row+1],at.z),0.,1.)
	var a: float = surface_rows[row][col]
	var c: float = surface_rows[row+1][col+1]
	if u >= v:
		at.y = a*(1.-u)+surface_rows[row][col+1]*(u-v)+c*v
	else:
		at.y = a*(1.-v)+surface_rows[row+1][col]*(v-u)+c*u
	return at

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
		["flowage_ice","97acb8","windpack"],["snow","d7dfe6","windpack"],["pavement","b2bcc5","salt_asphalt"],
		["siding","d0b9b3","barn_siding"],["silver","abb7c0","galvanized"],
		["cream","c2bfab"],["dark","34383a"],["wood","665449"],["brick","794a40"],
		["oxide","773e35"],["green","245d4c"],["post","87999c"],["black","1e262b"],
		["slush","8a97a4"],["stripe","a99875"],["glass","3e4d54"],["river","425263"],
		["lamp","ffac64","",0.82],["window","e6a46a","",0.43],["fluoro","dbe0db","",0.65],
		["white","dfded1","",0.05],["red","be343c","",.80],
		["safety_yellow","f6b83e","",.40],["amber_lens","ffb62a","",1.7],
		["brass","b89d61"],["blue_sign","285979","",.17],["decaf","fb7430"],
		["sign","ffffff","brandt_enamel"],
	]:
		materials[item[0]] = _paint(item[1],item[2] if item.size()>2 else "",item[3] if item.size()>3 else 0.0)
	var shop_glass := StandardMaterial3D.new()
	shop_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shop_glass.albedo_color = Color(.58,.75,.73,.19)
	shop_glass.roughness = .32
	materials["shop_glass"] = shop_glass
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
	var spruce := ShaderMaterial.new()
	spruce.shader = preload("res://assets/county/spruce.gdshader")
	spruce.set_shader_parameter("needles",preload("res://assets/county/black_spruce.png"))
	materials["spruce"] = spruce
	var conductor := ShaderMaterial.new()
	conductor.shader = preload("res://assets/county/power_line.gdshader")
	materials["conductor"] = conductor
	var wire := ShaderMaterial.new()
	wire.shader = preload("res://assets/county/wire.gdshader")
	materials["wire"] = wire
	var halo := ShaderMaterial.new()
	halo.shader = preload("res://assets/county/light_halo.gdshader")
	halo.set_shader_parameter("tint",Color("#ffb579"))
	materials["sodium"] = halo
	var bootprint := ShaderMaterial.new()
	bootprint.shader = preload("res://assets/county/bootprint.gdshader")
	materials["bootprint"] = bootprint

func _weather() -> void:
	var env := Environment.new()
	storm_environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://assets/county/sky.gdshader")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a0a5b0")
	env.ambient_light_energy = .50
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#555965")
	env.fog_light_energy = .90
	env.fog_depth_curve = .90
	env.fog_sky_affect = .23
	env.fog_aerial_perspective = .08
	var weather := WorldEnvironment.new()
	weather.environment = env
	add_child(weather)
	skylight = DirectionalLight3D.new()
	skylight.rotation_degrees = Vector3(-48,-34,10)
	skylight.light_color = Color("#adb1bc")
	skylight.light_energy = .30
	add_child(skylight)
	snow_shader = ShaderMaterial.new()
	snow_shader.shader = preload("res://assets/county/snow.gdshader")
	powder_shader = ShaderMaterial.new()
	powder_shader.shader = preload("res://assets/county/blowing_powder.gdshader")
	rng.seed = 32006
	storm = preload("res://scripts/storm_grains.gd").build(snow_shader, rng, 4100)
	add_child(storm)
	powder_clouds = _airborne_snow(powder_shader, 280)
	_build_spindrift()
	var store_floor := Rect2(FuelStore.ROOM.position + Vector2(FuelStore.FORECOURT.x,FuelStore.FORECOURT.z), FuelStore.ROOM.size)
	var sheltered := Vector4(store_floor.position.x,store_floor.position.y,store_floor.end.x,store_floor.end.y)
	for flakes: ShaderMaterial in [snow_shader,powder_shader,spindrift_shader]:
		flakes.set_shader_parameter("fuel_store_bounds",sheltered)
	wind_materials.assign([snow_shader, powder_shader, spindrift_shader, materials.spruce, materials.conductor])
	advance_storm(0.)

func _build_spindrift() -> void:
	var wisp := QuadMesh.new()
	# Subdivision lets the crest curl and follow a bank down into the ditch.
	wisp.subdivide_width = 8
	wisp.subdivide_depth = 3
	spindrift_shader = ShaderMaterial.new()
	spindrift_shader.shader = preload("res://assets/county/spindrift.gdshader")
	wisp.material = spindrift_shader
	var eddies := MultiMesh.new()
	eddies.transform_format = MultiMesh.TRANSFORM_3D
	eddies.use_custom_data = true
	eddies.mesh = wisp
	eddies.instance_count = 76
	for i in eddies.instance_count:
		eddies.set_instance_transform(i, Transform3D.IDENTITY)
		eddies.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	spindrift = MultiMeshInstance3D.new()
	spindrift.name = "GroundSpindrift"
	spindrift.multimesh = eddies
	spindrift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spindrift.custom_aabb = AABB(Vector3(-44, -22, -44), Vector3(88, 30, 88))
	add_child(spindrift)

func _bake_spindrift_ground(xs: Array, zs: Array, heights: Array) -> void:
	var surface := Image.create_empty(xs.size(), zs.size(), false, Image.FORMAT_RH)
	for row in zs.size():
		for col in xs.size():
			surface.set_pixel(col, row, Color(heights[row][col], 0., 0.))
	# The terrain packs extra vertices into ditches. Translate world metres
	# into fractional row/column indices so wisps sample that same surface.
	var axes := [xs, zs]
	var width := ceili(maxf(xs.back() - xs[0], zs.back() - zs[0])) + 1
	var lookup := Image.create_empty(width, 2, false, Image.FORMAT_RH)
	for dim in 2:
		var axis: Array = axes[dim]
		var cell := 0
		for metre in width:
			var at: float = minf(axis[0] + metre, axis.back())
			while cell < axis.size() - 2 and at > axis[cell + 1]:
				cell += 1
			var t := inverse_lerp(axis[cell], axis[cell + 1], at)
			lookup.set_pixel(metre, dim, Color((cell + t + .5) / axis.size(), 0., 0.))
	spindrift_shader.set_shader_parameter("ground_surface", ImageTexture.create_from_image(surface))
	spindrift_shader.set_shader_parameter("ground_axes", ImageTexture.create_from_image(lookup))
	spindrift_shader.set_shader_parameter("ground_origin", Vector2(xs[0], zs[0]))

func _airborne_snow(material: ShaderMaterial, count: int) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	var spread := MultiMesh.new()
	spread.transform_format = MultiMesh.TRANSFORM_3D
	spread.use_custom_data = true
	spread.mesh = quad
	spread.instance_count = count
	for i in count:
		spread.set_instance_transform(i, Transform3D.IDENTITY)
		spread.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var cloud := MultiMeshInstance3D.new()
	cloud.multimesh = spread
	cloud.custom_aabb = AABB(Vector3(-33,-12,-33), Vector3(66,24,66))
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	return cloud

func _build() -> void:
	rebuild_queued = false
	var tanker_state := {"lift":fire_bay.lift,"travel":fire_bay.travel} if is_instance_valid(fire_bay) else {}
	case_models.clear()
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
	Town.new(self,draw).build()
	fire_bay = FireBay.new()
	fire_bay.name = "VolunteerTankerBay"
	county_model.add_child(fire_bay)
	fire_bay.build(self)
	fire_bay.restore(tanker_state)
	_build_yard_fittings()
	RiverLanes.new(self,draw).build()
	Dairy.new(self,draw).build()
	FuelStore.new(self,draw).build()
	Memorial.new(self,draw).build()
	East.new(self,draw).build()
	PoolRepair.new(self,draw).build()
	preload("res://scripts/field_redirect.gd").grow(self,draw)
	Dryhouse.new(self,draw).build()
	Flowage.mark_ice(draw,self)
	preload("res://scripts/tree_recovery.gd").grow_grove(draw,self)
	preload("res://scripts/rollover.gd").hayfield(draw,self)
	CaseSites.new(self,draw).alder_cut()
	draw.finish()
	tower_meshes.clear()
	for mesh: Node in county_model.get_children():
		if mesh is GeometryInstance3D and mesh.visibility_range_end == 230.0:
			tower_meshes.append(mesh)
			if tower_view: mesh.visibility_range_end = 850.0
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
	rod_case = Node3D.new()
	rod_case.name = "SurveyRodCase"
	hold.add_child(rod_case)
	rod_case.position = rod_case_point()-Vector3.UP*.15
	var gear = Sites.new(self,Batch.new(rod_case,materials))
	gear.survey_rod_case()
	gear.draw.finish()
	rod_case.rotation.x = PI if rod_case_read else 0.0
	survey_pickup = _parked_car(hold,"hold",0,survey_point,survey_yaw,{"open_door":true,"untaped":true})
	var instrument = Sites.new(self,Batch.new(tripod,materials))
	instrument.survey_tripod()
	instrument.draw.finish()
	set_survey_pickup_parked(survey_pickup_parked)
	set_tripod_collected(tripod_taken)
	_sync_case_models()

func _parked_car(parent: Node3D, kind: String, variant: int, point: Vector3, yaw: float, identity: Dictionary) -> Node3D:
	var vehicle := Scene.car(parent,kind,variant,identity)
	vehicle.position = resolve_point(point)
	vehicle.position.y = ground_height(vehicle.position.x,vehicle.position.z)
	vehicle.rotation.y = yaw
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.93,1.25,4.8) if kind == "hold" else Vector3(1.75,1.10,4.15)
	collision.shape = shape
	collision.position.y = shape.size.y*.5
	body.add_child(collision)
	vehicle.add_child(body)
	return vehicle

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
	var xs := _axis(TERRAIN_X.x,TERRAIN_X.y,[-608,Flowage.ROAD_X,0,400,800,CaseSites.ALDER_X],[-501,-493,-458,-449,-98,-65,-52,-2,67,138,304,323,452,457,462,822,829,877,884,Town.APRON.position.x,Town.APRON.end.x,Town.CHEESE_YARD.position.x,Town.CHEESE_YARD.end.x,1100,1150,East.LOT.position.x,East.LOT.end.x])
	var zs := _axis(TERRAIN_Z.x,TERRAIN_Z.y,[-400,0,400,800],[CaseSites.ALDER_END-5,CaseSites.ALDER_END,-482,-470,-461,-412,-153,-135,-108,-90,-84,-61,-35,-29,-2,4,14,18,24,27,31,47,61,146,164,236,246,331,336,341,425,448])
	var ground := {}
	var h_rows := []
	for z: float in zs:
		var heights := PackedFloat32Array()
		for x: float in xs:
			heights.append(ground_height(x,z) if x <= 1150 or absf(z) <= 265 else 0.0)
		h_rows.append(heights)
	surface_x = xs
	surface_z = zs
	surface_rows = h_rows
	_bake_spindrift_ground(xs, zs, h_rows)
	for row in range(zs.size()-1):
		var z0 := float(zs[row])
		var z1 := float(zs[row+1])
		for col in range(xs.size()-1):
			var x0 := float(xs[col])
			var x1 := float(xs[col+1])
			if x0 >= 1150 and (z0 > 240 or z1 < -240):
				continue
			var a := Vector3(x0,h_rows[row][col],z0)
			var b := Vector3(x1,h_rows[row][col+1],z0)
			var c := Vector3(x1,h_rows[row+1][col+1],z1)
			var d := Vector3(x0,h_rows[row+1][col],z1)
			var center := (a+c)*.5
			var road := road_distance(center.x,center.z) <= 5.0
			var yard_floor := Flowage.LANDING.has_point(Vector2(center.x,center.z)) or YARD.has_point(Vector2(center.x,center.z)) or RiverLanes.LOT.has_point(Vector2(center.x,center.z))
			var forecourt := Rect2(-98,-2,46,30).has_point(Vector2(center.x,center.z)) or Memorial.LOT.has_point(Vector2(center.x,center.z)) or East.LOT.has_point(Vector2(center.x,center.z)) or Town.APRON.has_point(Vector2(center.x,center.z)) or Town.CHEESE_YARD.has_point(Vector2(center.x,center.z))
			var material := "road" if road else ("pavement" if yard_floor or forecourt else "snow")
			var uv := PackedVector2Array()
			var highway := absf(center.z)<5.1 or absf(center.z-400)<5.1 or absf(center.z-800)<5.1 or absf(center.z+400)<5.1
			var xline := 0.0
			var zline := 0.0
			if road:
				for axis: float in [-608.,400.,800.]:
					if absf(center.x-axis)<absf(center.x-xline): xline=axis
				for axis: float in [-400.,400.,800.]:
					if absf(center.z-axis)<absf(center.z-zline): zline=axis
				if center.x>405 and center.x<HOFFMANN_LANE_END.x+5 and absf(center.z-HOFFMANN_LANE_END.y)<5.1:
					highway = true
					zline = HOFFMANN_LANE_END.y
				if center.z < -405 and absf(center.x-CaseSites.ALDER_X) <= 5:
					xline = CaseSites.ALDER_X
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
