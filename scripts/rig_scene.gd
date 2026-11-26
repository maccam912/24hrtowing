extends RefCounted
const K=preload("res://scripts/rig_mesh.gd")
const Snowplow := preload("res://scripts/county_snowplow.gd")
const Ambulance := preload("res://scripts/memorial_ambulance.gd")
const Squad := preload("res://scripts/county_squad.gd")
const Semi := preload("res://scripts/semitrailer.gd")
const RoadWheels := preload("res://scripts/road_wheels.gd")
const Tanker := preload("res://scripts/milk_tanker.gd")
const Tape := preload("res://scripts/sheriff_tape.gd")
const BLACK=Color("#272b2c")
const GLASS=Color("#38464b")
const STEEL=Color("#929895")
const SNOW=Color("#ced4d4")
const HOLD_BODY=Color("#deded2")
const TAPE=Color("#f4e409")
const UNIT_PLATE := "WI CO 038"
const UNIT_VIN := "1BTPK18S4VK044506"
const UTILITY_VARIANT := 4
# Half-width, belt base and half-length, shared by the body, axles and lamps.
const SEDAN_SIZE := Vector3(.89,.46,2.12)
const PICKUP_SIZE := Vector3(.99,.64,2.5)

static func snatch_block(parent: Node3D) -> Node3D:
	var block := K.joint(parent, Vector3.ZERO, "SnatchBlock")
	var kit = K.new(block)
	# Two red cheek plates straddle the sheave. A shackle sits below its pin.
	kit.tube(Vector3(-.046,0,0),Vector3(.046,0,0),.113,STEEL,14)
	for s: float in [-1.0,1.0]:
		kit.tube(Vector3(s*.05,0,0),Vector3(s*.069,0,0),.124,Color("#99543d"),12)
		kit.tube(Vector3(s*.07,0,0),Vector3(s*.081,0,0),.038,STEEL)
	kit.ring(Vector3(0,-.14,0),.036,.055,STEEL,Vector3(PI/2,0,0))
	kit.finish()
	block.hide()
	return block

static func car(parent:Node3D, kind:String, variant:int, identity := {}, live_wheels := false) -> Node3D:
	if variant == Ambulance.VARIANT:
		return Ambulance.vehicle(parent)
	if variant == Tanker.VARIANT:
		var tanker := Tanker.new()
		tanker.build(parent,identity)
		return tanker
	if variant == Semi.VARIANT:
		var tractor := Semi.new()
		tractor.build(parent,identity)
		return tractor
	if variant == Snowplow.VARIANT and kind == "ditch":
		return Snowplow.build(parent)
	var is_hold:=kind=="hold"
	var open_door: bool = is_hold and identity.get("open_door",false)
	var mail: bool = identity.get("mail",false)
	var utility := variant == UTILITY_VARIANT and not is_hold
	var pickup := is_hold or utility
	var wagon:=not pickup and variant==2
	var p=K.joint(parent,Vector3.ZERO,"UtilityPickup" if utility else ("CountyPickup" if is_hold else "RoadCar"))
	var plate: String = UNIT_PLATE if is_hold else identity.get("plate","")
	var vin: String = UNIT_VIN if is_hold else identity.get("vin","")
	p.set_meta("plate",plate)
	p.set_meta("vin",vin)
	var g=K.new(p)
	var body:Color=HOLD_BODY if is_hold else [Color("#607e98"),Color("#7d6159"),Color("#7b838e"),Color("#79635a")][posmod(variant,4)]
	if utility:
		body = Color("#bd753b")
	if variant == Squad.VARIANT:
		body = Squad.PAINT
	var size := PICKUP_SIZE if pickup else SEDAN_SIZE
	p.set_meta("body_size",size)
	var width:=size.x
	var length:=size.z
	var base:=size.y
	var tint:=body.darkened(.27)
	g.box(Vector3(0,base,0),Vector3(width*1.83,.35,length*1.95),tint)
	if open_door:
		# The cutout runs from the A-pillar to the seat back.
		g.box(Vector3(0,base+.24,-1.65),Vector3(width*2,.34,1.37),body)
		g.box(Vector3(0,base+.24,1.40),Vector3(width*2,.34,1.98),body)
		g.box(Vector3(.10,base+.18,-.28),Vector3(width*1.74,.26,1.42),BLACK)
		g.box(Vector3(0,base+.50,-.05),Vector3(1.47,.20,.56),Color("#68645a"))
		g.box(Vector3(0,base+.71,.24),Vector3(1.47,.56,.14),Color("#68645a"))
		g.box(Vector3(.47,base+.612,-.01),Vector3(.28,.032,.40),Color("#394b3e"),Vector3(0,-.14,0))
		g.box(Vector3(.47,base+.628,-.01),Vector3(.26,.014,.38),Color("#e4dfc7"),Vector3(0,-.14,0))
		_survey_door(p,width,base)
	else:
		g.box(Vector3(0,base+.24,-.04),Vector3(width*2,.34,length*1.94),body)
	g.box(Vector3(0,base+.44,-1.40),Vector3(width*1.89,.10,1.08),body,Vector3(-.065,0,0))
	g.box(Vector3(-.09,base+.509,-1.34),Vector3(width*1.40,.018,.69),SNOW,Vector3(-.065,0,.017))
	var cab_end:=.49 if pickup else (1.86 if wagon else 1.04)
	var top_end:=.40 if pickup else (1.65 if wagon else .68)
	var head_y:=base+1.16
	if variant == Squad.VARIANT:
		Squad.fit(p,g,width,base,head_y,plate)
	# Glazed greenhouse tapers from the belt line to the roof; two sloped panes.
	g.box(Vector3(0,head_y,(top_end-.56)*.5),Vector3(width*1.63,.115,top_end+.56),body)
	g.box(Vector3(-.032,head_y+.064,(top_end-.56)*.5),Vector3(width*1.54,.022,top_end+.48),SNOW)
	var windshield_tilt:=atan2(.40,.62)
	g.box(Vector3(0,base+.82,-.75),Vector3(width*1.76,.74,.035),GLASS,Vector3(windshield_tilt,0,0))
	var rear_tilt:=-atan2(cab_end-top_end,.60)
	g.box(Vector3(0,base+.81,(cab_end+top_end)*.5),Vector3(width*1.72,.72,.036),GLASS,Vector3(rear_tilt,0,0))
	g.box(Vector3(0,base+.47,-.98),Vector3(width*1.87,.08,.06),BLACK)
	var tire_radius := .43 if pickup else .355
	live_wheels = live_wheels or identity.has("wheel_fault")
	if live_wheels:
		var hubs := RoadWheels.new()
		hubs.assemble(p,size,tire_radius)
		if identity.has("wheel_fault"):
			preload("res://scripts/damaged_axle.gd").mark_car(hubs,identity)
			for side: float in [-1.,1.]:
				K.label(p,"TAMARACK COUNTY\nMOTOR POOL",Vector3(side*(width+.031),base+.24,-.46),.083,Color("#d1c7aa"),Vector3(0,side*PI/2,0))
	for s in [-1.0,1.0]:
		var x:float=s*width
		if not live_wheels:
			for z in [-length*.61,length*.61]:
				RoadWheels.wheel(g,Vector3(x,tire_radius,z),s,tire_radius)
		g.beam(Vector3(x*.956,base+.48,-.98),Vector3(x*.81,head_y,-.56),.064,.076,body)
		g.beam(Vector3(x*.95,base+.48,cab_end),Vector3(x*.81,head_y,top_end),.078,.087,body)
		if s>0 or not (open_door or mail):
			g.box(Vector3(x*.869,base+.80,(top_end-.56)*.50),Vector3(.063,.58,top_end+.56),GLASS,Vector3(0,0,s*.14))
		if s>0 or not open_door:
			g.box(Vector3(x*.912,base+.79,.06),Vector3(.069,.62,.067),body,Vector3(0,0,s*.15))
			g.box(Vector3(x,base+.28,.0),Vector3(.03,.032,length*1.73),tint)
			for z in [-.04,.73]:
				if z>cab_end: continue
				g.box(Vector3(x+s*.018,base+.37,z),Vector3(.041,.032,.145),STEEL)
			g.box(Vector3(x*1.08,base+.64,-.82),Vector3(.22,.112,.16),body)
		g.box(Vector3(x*.77,base+.24,-length*.984),Vector3(.31,.136,.063),Color("#bfc6b8"))
		g.box(Vector3(x*.82,base+.25,length*.976),Vector3(.23,.17,.062),Color("#a64342"))
	if pickup:
		g.box(Vector3(0,base+.441,1.32),Vector3(1.61,.08,1.54),Color("#6f7676"))
		for s in [-1.0,1.0]:
			g.box(Vector3(s*.91,base+.57,1.45),Vector3(.14,.31,1.76),body)
			g.box(Vector3(s*.90,base+.736,1.45),Vector3(.136,.022,1.66),SNOW)
			var lettering := "TAMARACK COUNTY\nHIGHWAY DEPT." if utility else "TAMARACK COUNTY\nSURVEY UNIT 38"
			if not open_door or s>0:
				K.label(p,lettering,Vector3(s*(width+.031),base+.24,-.46),.104,Color("#283a32"),Vector3(0,s*PI/2,0))
			if utility:
				# Full-height service lockers and the ladder over the bed.
				g.box(Vector3(s*.78,base+.75,1.46),Vector3(.46,.63,1.84),body)
				g.box(Vector3(s*.78,base+1.075,1.46),Vector3(.47,.035,1.84),SNOW)
				for z in [.86,1.45,2.04]:
					g.box(Vector3(s*1.02,base+.74,z),Vector3(.025,.48,.54),body.darkened(.13))
					g.box(Vector3(s*1.04,base+.87,z),Vector3(.035,.045,.11),STEEL)
				for z in [.66,2.23]:
					g.box(Vector3(s*.76,base+1.25,z),Vector3(.06,.42,.06),STEEL)
				g.box(Vector3(s*.76,base+1.47,1.32),Vector3(.06,.08,2.1),STEEL)
		if utility:
			for z in [.49,.88,1.27,1.66,2.05]:
				g.box(Vector3(0,base+1.47,z),Vector3(1.49,.044,.06),STEEL)
		g.box(Vector3(0,base+.54,2.32),Vector3(1.81,.34,.11),body)
		g.box(Vector3(0,head_y+.13,-.13),Vector3(1.01,.07,.23),BLACK)
		g.box(Vector3(0,head_y+.21,-.13),Vector3(.95,.105,.21),Color("#bb8654"))
	else:
		if wagon:
			for s in [-1.0,1.0]:
				var x:float=s*width
				g.box(Vector3(x*.909,base+.81,.91),Vector3(.066,.63,.061),body,Vector3(0,0,s*.15))
				g.tube(Vector3(x*.715,head_y+.101,-.29),Vector3(x*.715,head_y+.101,1.50),.019,BLACK,8)
				for roof_z in [-.23,1.42]:
					g.box(Vector3(x*.715,head_y+.075,roof_z),Vector3(.055,.065,.071),BLACK)
			g.box(Vector3(0,base+.45,1.86),Vector3(width*1.9,.13,.31),body)
		else:
			g.box(Vector3(0,base+.435,1.46),Vector3(width*1.86,.115,.84),body,Vector3(.045,0,0))
			g.box(Vector3(.04,base+.505,1.48),Vector3(width*1.62,.026,.71),SNOW,Vector3(.045,0,0))
	g.box(Vector3(0,base+.21,-length*.99),Vector3(.63,.16,.058),BLACK)
	for z in [-length,length]:
		g.box(Vector3(0,base-.015,z),Vector3(width*1.96,.145,.093),STEEL)
		g.box(Vector3(0,base+.115,z*1.016),Vector3(.36,.16,.03),Color("#d5d8ba"))
		if not plate.is_empty():
			K.label(p,plate,Vector3(0,base+.115,z*1.016+signf(z)*.018),.059,BLACK,Vector3(0,0 if z>0 else PI,0),"plex_mono")
	if not vin.is_empty():
		var vin_strip := Vector3(-.38,base+.59,-.928)
		g.box(vin_strip,Vector3(.37,.054,.012),BLACK,Vector3(windshield_tilt,0,0))
		K.label(p,vin,vin_strip+Vector3(0,.003,-.008),.03,SNOW,Vector3(-windshield_tilt,PI,0),"plex_mono")
	if identity.has("yard_tag"):
		var card := Vector3(.42,base+.77,-.825)
		g.box(card,Vector3(.28,.21,.011),Color("#efcc88"),Vector3(windshield_tilt,0,0))
		K.label(p,"BRANDT\n"+str(identity.yard_tag),card+Vector3(0,.007,-.013),.047,BLACK,Vector3(-windshield_tilt,PI,0),"plex_mono")
	if mail:
		g.box(Vector3(-.38,base+.48,-.10),Vector3(.71,.12,.64),BLACK)
		for i in 4:
			var at := Vector3(-.40+i*.035,base+.56+i*.022,-.14+i*.029)
			g.box(at,Vector3(.45,.018,.24),Color("#ebe4c7"),Vector3(0,i*.07,0))
			g.box(at+Vector3(.13,.011,-.075),Vector3(.054,.004,.04),Color("#8a4c40"))
	g.finish()
	if open_door and identity.get("untaped",false):
		car_lamps(p,"running",-1)
	if kind in ["hazard","hold"] and not identity.get("untaped",false):
		sheriff_tape(p,width,base,Tape.imprint(identity))
	for s in [-1,1]:
		var z:float=s*length*1.016
		var t=K.joint(p,Vector3(0,base-.087,z))
		var e=K.new(t)
		e.ring(Vector3.ZERO,.046,.069,Color("#ac8d63"),Vector3(PI/2,0,0))
		e.finish()
	return p

static func fuel_service_plow(parent: Node3D) -> Node3D:
	var plow := car(parent,"unattended",UTILITY_VARIANT)
	car_lamps(plow,"running",-1)
	var blade := K.new(plow)
	blade.box(Vector3(0,.49,-2.89),Vector3(3.12,.84,.24),Color("#997249"),Vector3(.17,.24,.05))
	blade.finish()
	var driver := person(plow,false,1)
	driver.position = Vector3(-.45,.45,-.13)
	driver.get_node("AnimationPlayer").play("seated")
	return plow

static func county_plow(parent: Node3D) -> Node3D:
	var plow := Snowplow.build(parent)
	car_lamps(plow,"running",-1)
	board_plow_driver(plow)
	return plow

static func board_plow_driver(plow: Node3D) -> void:
	var duane := person(plow,false,Snowplow.DRIVER)
	duane.position = Vector3(-.51,1.06,-.86)
	duane.get_node("AnimationPlayer").play("seated")

static func _survey_door(vehicle: Node3D, width: float, base: float) -> void:
	var hinge:=K.joint(vehicle,Vector3(-width,base,-.91),"DriverDoor")
	hinge.rotation.y=-1.04
	var door:=K.new(hinge)
	door.box(Vector3(0,.24,.61),Vector3(.10,.48,1.24),HOLD_BODY)
	door.box(Vector3(.062,.24,.61),Vector3(.035,.37,1.08),Color("#584e44"))
	door.box(Vector3(.034,.75,.65),Vector3(.05,.51,.88),GLASS)
	door.beam(Vector3(.01,.46,.02),Vector3(.05,1.12,.35),.05,.05,HOLD_BODY)
	door.beam(Vector3(.05,1.12,.35),Vector3(.05,1.12,1.18),.05,.05,HOLD_BODY)
	door.beam(Vector3(.05,1.12,1.18),Vector3(.02,.46,1.21),.05,.05,HOLD_BODY)
	door.box(Vector3(-.078,.37,1.05),Vector3(.042,.032,.14),STEEL)
	door.box(Vector3(-.16,.63,.12),Vector3(.22,.11,.16),HOLD_BODY)
	K.label(hinge,"TAMARACK COUNTY\nSURVEY UNIT 38",Vector3(-.06,.24,.57),.103,Color("#283a32"),Vector3(0,-PI/2,0))
	door.finish()

static func close_driver_door(vehicle: Node3D) -> void:
	var door := vehicle.get_node_or_null("DriverDoor") as Node3D
	if door:
		door.rotation.y=0

static func sheriff_tape(vehicle: Node3D, width: float, base: float, mark: Dictionary) -> Node3D:
	var tape: Node3D = K.joint(vehicle,Vector3(-width*1.11,base+.62,-.81),"SheriffTape")
	tape.set_meta("imprint",mark)
	tape.set_meta("plate",vehicle.get_meta("plate",""))
	tape.add_to_group("checked_mirrors")
	var strip = K.new(tape)
	strip.box(Vector3.ZERO,Vector3(.042,.071,.255),TAPE)
	strip.box(Vector3(-.028,-.153,.082),Vector3(.027,.31,.13),TAPE,Vector3(.18,0,.08))
	strip.box(Vector3(.022,-.074,.155),Vector3(.025,.11,.22),TAPE,Vector3(-.26,0,-.06))
	strip.finish()
	K.label(tape,"SHERIFF",Vector3(-.029,.003,-.01),.037,BLACK,Vector3(0,-PI/2,0))
	K.label(tape,"%s\n%d" % [mark.date,int(mark.badge)],Vector3(-.053,-.14,.089),.033,BLACK,Vector3(0,-PI/2,.1),"plex_mono")
	return tape

static func car_lamps(car_body:Node3D,mode:String,line_end:int) -> Node3D:
	var lamps:Node3D=K.joint(car_body,Vector3.ZERO,"VehicleLamps")
	var kit=K.new(lamps)
	var size: Vector3 = car_body.get_meta("body_size")
	var length:=size.z
	var width:=size.x
	var height:=size.y
	if mode=="tow":
		# Magnetic feet hold the portable light bar on the roof. Its amber
		# clearance markers are visible to the operator in the side mirrors.
		var bar_y:=height+1.35
		if car_body is Tanker:
			lamps.position = Vector3(0,-.58,Tanker.SIZE.z-.11)
		kit.box(Vector3(0,bar_y,0),Vector3(1.82,.17,.16),Color("#d7a44e"))
		for side:float in [-1.0,1.0]:
			kit.box(Vector3(side*.52,bar_y-.09,0),Vector3(.15,.09,.22),BLACK)
			kit.box(Vector3(side*.72,bar_y,-line_end*.09),Vector3(.25,.13,.04),Color("#ff4039"),Vector3.ZERO,"lamp")
			kit.box(Vector3(side*.855,bar_y,0),Vector3(.12,.13,.19),Color("#ffbe47"),Vector3.ZERO,"lamp")
	else:
		var plow: bool = car_body.get_meta("vin", "") == Snowplow.VIN
		if mode == "ems_scene":
			Ambulance.warning_heads(lamps)
		if car_body.get_meta("patrol",false):
			Squad.add_patrol_lights(kit,height)
		if plow:
			for side:float in [-1,1]:
				kit.box(Vector3(side*.79,2.95,-.98),Vector3(.33,.20,.27),Color("#ffad36"),Vector3.ZERO,"lamp")
		for end_sign:float in [-1.0,1.0]:
			var tint:=Color("#ffaa35") if mode=="hazard" else (Color("#ffeac2") if end_sign<0 else Color("#f03937"))
			for side:float in [-1.0,1.0]:
				if plow and end_sign<0:
					kit.box(Vector3(side*1.02,1.32,-3.28),Vector3(.27,.17,.033),tint,Vector3.ZERO,"lamp")
				else:
					kit.box(Vector3(side*width*.82,height+.25,end_sign*length*.997),Vector3(.19,.112,.035),tint,Vector3.ZERO,"lamp")
		if mode in ["running","ems_scene"]:
			var beam:=SpotLight3D.new()
			lamps.add_child(beam)
			beam.position=Vector3(0,height+.25,-length-.08)
			beam.rotation.x=-.08
			beam.light_color=Color("#fff0ce")
			beam.light_energy=1.8
			beam.spot_range=38
			beam.spot_angle=29
	kit.finish()
	if mode in ["running","ems_scene"]:
		_exhaust(lamps, Vector3(-width*.57,.34,length+.06))
	return lamps

static var vapor_material: StandardMaterial3D
static var surveyor_skin: ShaderMaterial
static var highway_jacket: ShaderMaterial

static func _exhaust(lamps: Node3D, outlet: Vector3) -> void:
	if vapor_material==null:
		vapor_material=StandardMaterial3D.new()
		vapor_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		vapor_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		vapor_material.vertex_color_use_as_albedo=true
		vapor_material.albedo_color=Color(.83,.86,.83,.16)
	var vapor:=CPUParticles3D.new()
	vapor.name="TailpipeVapor"
	vapor.amount=9
	vapor.lifetime=1.6
	vapor.direction=Vector3(.18,.12,1)
	vapor.spread=18
	vapor.initial_velocity_min=.65
	vapor.initial_velocity_max=1.1
	vapor.gravity=Vector3(.37,.82,.12)
	vapor.scale_amount_min=.5
	vapor.scale_amount_max=1.0
	var fade:=Gradient.new()
	fade.colors=PackedColorArray([Color(1,1,1,.72),Color(1,1,1,0)])
	vapor.color_ramp=fade
	var puff:=SphereMesh.new()
	puff.radius=.18
	puff.height=.25
	puff.radial_segments=6
	puff.rings=2
	puff.material=vapor_material
	vapor.mesh=puff
	vapor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamps.add_child(vapor)
	vapor.position=outlet

static func person(parent: Node3D, deputy: bool, variant: int = 0) -> Node3D:
	var scene := preload("res://assets/characters/stranded_driver.glb")
	if deputy or variant == Squad.DRIVER:
		scene = preload("res://assets/characters/deputy.glb")
	elif variant == 2:
		scene = preload("res://assets/characters/summer_driver.glb")
	elif variant in [1,3,Snowplow.DRIVER,Ambulance.ATTENDANT]:
		scene = preload("res://assets/characters/farm_driver.glb")
	var witness := scene.instantiate() as Node3D
	witness.name = "Deputy" if deputy else "Driver"
	parent.add_child(witness)
	if variant in [Ambulance.DRIVER,Ambulance.ATTENDANT]:
		Ambulance.fit_uniform(witness,variant == Ambulance.ATTENDANT)
	if variant == Snowplow.DRIVER and not deputy:
		var jacket := witness.find_child("Jacket",true,false) as MeshInstance3D
		if jacket:
			if not highway_jacket:
				highway_jacket = ShaderMaterial.new()
				highway_jacket.shader = preload("res://assets/characters/highway_jacket.gdshader")
				highway_jacket.set_shader_parameter("palette",preload("res://assets/characters/winter_palette.png"))
			jacket.material_override = highway_jacket
	if variant==3 and not deputy:
		var head:=witness.find_child("Head",true,false) as MeshInstance3D
		if head:
			if not surveyor_skin:
				surveyor_skin=ShaderMaterial.new()
				surveyor_skin.shader=preload("res://assets/characters/surveyor_face.gdshader")
				surveyor_skin.set_shader_parameter("palette",preload("res://assets/characters/winter_palette.png"))
			head.material_override=surveyor_skin
	var animation: AnimationPlayer = witness.get_node("AnimationPlayer")
	animation.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	animation.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
	animation.play("idle")
	return witness

static func walk_person(witness: Node3D) -> void:
	var animation: AnimationPlayer = witness.get_node("AnimationPlayer")
	if animation.current_animation != "walk":
		animation.play("walk", 0.18)

static var reflector_material: StandardMaterial3D

static func warning_triangle(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var stand := K.joint(parent,at,"WarningTriangle")
	stand.rotation.y = yaw
	var frame := K.new(stand)
	# A weighted folding foot and a short riser hold the reflector above the snow.
	frame.box(Vector3(0,.055,0),Vector3(.24,.11,.78),BLACK)
	frame.box(Vector3(0,.15,0),Vector3(.14,.20,.10),STEEL)
	var corners := PackedVector3Array([Vector3(-.51,.27,0),Vector3(0,1.13,0),Vector3(.51,.27,0)])
	var strips := K.new(stand)
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		frame.beam(a,b,.18,.045,Color("#dd4936"))
		strips.beam(a,b,.095,.052,Color.WHITE)
	frame.finish()
	if not reflector_material:
		reflector_material = StandardMaterial3D.new()
		reflector_material.albedo_color = Color("#ff7842")
		reflector_material.roughness = .45
		reflector_material.emission_enabled = true
		reflector_material.emission = Color("#ed5637")
		reflector_material.emission_energy_multiplier = .32
	strips.finish().material_override = reflector_material
	return stand

static func flare(parent:Node3D, at:Vector3) -> Node3D:
	var p=K.joint(parent,at,"RoadFlare")
	var g=K.new(p)
	g.tube(Vector3(0,.024,0),Vector3(.18,.094,.08),.025,Color("#943f36"))
	g.tube(Vector3(.18,.094,.08),Vector3(.187,.166,.079),.046,Color("#ff8864"),7,"lamp",.012)
	g.finish()
	var light:=OmniLight3D.new()
	light.light_color=Color("#ff644b")
	light.light_energy=.72
	light.omni_range=5.0
	light.position=Vector3(.18,.19,.08)
	p.add_child(light)
	return p
