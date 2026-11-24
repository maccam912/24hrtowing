extends RefCounted
const K=preload("res://scripts/rig_mesh.gd")
const BLACK=Color("#272b2c")
const GLASS=Color("#38464b")
const STEEL=Color("#929895")
const SNOW=Color("#ced4d4")
const HOLD_BODY=Color("#deded2")
const TAPE=Color("#f4e409")
const UNIT_PLATE := "WI CO 038"
const UNIT_VIN := "1BTPK18S4VK044506"

static func car(parent:Node3D, kind:String, variant:int, identity := {}) -> Node3D:
	var is_hold:=kind=="hold"
	var wagon:=not is_hold and variant==2
	var p=K.joint(parent,Vector3.ZERO,"CountyPickup" if is_hold else "RoadCar")
	var plate: String = UNIT_PLATE if is_hold else identity.get("plate","")
	var vin: String = UNIT_VIN if is_hold else identity.get("vin","")
	p.set_meta("plate",plate)
	p.set_meta("vin",vin)
	var g=K.new(p)
	var body:Color=HOLD_BODY if is_hold else [Color("#607e98"),Color("#7d6159"),Color("#7b838e"),Color("#79635a")][posmod(variant,4)]
	var width:=.99 if is_hold else .89
	var length:=2.5 if is_hold else 2.12
	var base:=.64 if is_hold else .46
	var tint:=body.darkened(.27)
	g.box(Vector3(0,base,0),Vector3(width*1.83,.35,length*1.95),tint)
	g.box(Vector3(0,base+.24,-.04),Vector3(width*2,.34,length*1.94),body)
	g.box(Vector3(0,base+.44,-1.40),Vector3(width*1.89,.10,1.08),body,Vector3(-.065,0,0))
	g.box(Vector3(-.09,base+.509,-1.34),Vector3(width*1.40,.018,.69),SNOW,Vector3(-.065,0,.017))
	var cab_end:=.49 if is_hold else (1.86 if wagon else 1.04)
	var top_end:=.40 if is_hold else (1.65 if wagon else .68)
	var head_y:=base+1.16
	# Glazed greenhouse tapers from the belt line to the roof; two sloped panes.
	g.box(Vector3(0,head_y,(top_end-.56)*.5),Vector3(width*1.63,.115,top_end+.56),body)
	g.box(Vector3(-.032,head_y+.064,(top_end-.56)*.5),Vector3(width*1.54,.022,top_end+.48),SNOW)
	var windshield_tilt:=atan2(.40,.62)
	g.box(Vector3(0,base+.82,-.75),Vector3(width*1.76,.74,.035),GLASS,Vector3(windshield_tilt,0,0))
	var rear_tilt:=-atan2(cab_end-top_end,.60)
	g.box(Vector3(0,base+.81,(cab_end+top_end)*.5),Vector3(width*1.72,.72,.036),GLASS,Vector3(rear_tilt,0,0))
	g.box(Vector3(0,base+.47,-.98),Vector3(width*1.87,.08,.06),BLACK)
	for s in [-1.0,1.0]:
		var x:float=s*width
		for z in [-length*.61,length*.61]:
			var radius:=.43 if is_hold else .355
			g.tube(Vector3(x-s*.135,radius,z),Vector3(x+s*.095,radius,z),radius,BLACK,16)
			g.tube(Vector3(x+s*.099,radius,z),Vector3(x+s*.108,radius,z),radius*.61,STEEL,12)
			g.tube(Vector3(x+s*.111,radius,z),Vector3(x+s*.12,radius,z),radius*.25,Color("#535955"),8)
		g.beam(Vector3(x*.956,base+.48,-.98),Vector3(x*.81,head_y,-.56),.064,.076,body)
		g.beam(Vector3(x*.95,base+.48,cab_end),Vector3(x*.81,head_y,top_end),.078,.087,body)
		g.box(Vector3(x*.869,base+.80,(top_end-.56)*.50),Vector3(.063,.58,top_end+.56),GLASS,Vector3(0,0,s*.14))
		g.box(Vector3(x*.912,base+.79,.06),Vector3(.069,.62,.067),body,Vector3(0,0,s*.15))
		g.box(Vector3(x,base+.28,.0),Vector3(.03,.032,length*1.73),tint)
		for z in [-.04,.73]:
			if z>cab_end: continue
			g.box(Vector3(x+s*.018,base+.37,z),Vector3(.041,.032,.145),STEEL)
		g.box(Vector3(x*1.08,base+.64,-.82),Vector3(.22,.112,.16),body)
		g.box(Vector3(x*.77,base+.24,-length*.984),Vector3(.31,.136,.063),Color("#bfc6b8"))
		g.box(Vector3(x*.82,base+.25,length*.976),Vector3(.23,.17,.062),Color("#a64342"))
	if is_hold:
		g.box(Vector3(0,base+.441,1.32),Vector3(1.61,.08,1.54),Color("#6f7676"))
		for s in [-1.0,1.0]:
			g.box(Vector3(s*.91,base+.57,1.45),Vector3(.14,.31,1.76),body)
			g.box(Vector3(s*.90,base+.736,1.45),Vector3(.136,.022,1.66),SNOW)
			K.label(p,"TAMARACK COUNTY\nSURVEY UNIT 38",Vector3(s*(width+.031),base+.24,-.46),.104,Color("#283a32"),Vector3(0,s*PI/2,0))
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
	g.finish()
	if kind in ["hazard","hold"]:
		var strip=K.new(p)
		strip.box(Vector3(-width*1.104,base+.625,-.81),Vector3(.036,.06,.242),TAPE)
		strip.box(Vector3(-width*1.09,base+.485,-.71),Vector3(.025,.25,.09),TAPE,Vector3(.18,0,.08))
		strip.finish()
		K.label(p,"SHERIFF",Vector3(-width*1.13,base+.622,-.82),.034,BLACK,Vector3(0,-PI/2,0))
	for s in [-1,1]:
		var z:float=s*length*1.016
		var t=K.joint(p,Vector3(0,base-.087,z))
		var e=K.new(t)
		e.ring(Vector3.ZERO,.046,.069,Color("#ac8d63"),Vector3(PI/2,0,0))
		e.finish()
	return p

static func car_lamps(car_body:Node3D,kind:String,mode:String,line_end:int) -> Node3D:
	var lamps:Node3D=K.joint(car_body,Vector3.ZERO,"VehicleLamps")
	var kit=K.new(lamps)
	var length:=2.5 if kind=="hold" else 2.12
	var width:=.99 if kind=="hold" else .89
	var height:=.64 if kind=="hold" else .46
	if mode=="tow":
		# Magnetic feet hold the portable light bar on the roof. Its amber
		# clearance markers are visible to the operator in the side mirrors.
		var bar_y:=height+1.35
		kit.box(Vector3(0,bar_y,0),Vector3(1.82,.17,.16),Color("#d7a44e"))
		for side:float in [-1.0,1.0]:
			kit.box(Vector3(side*.52,bar_y-.09,0),Vector3(.15,.09,.22),BLACK)
			kit.box(Vector3(side*.72,bar_y,-line_end*.09),Vector3(.25,.13,.04),Color("#ff4039"),Vector3.ZERO,"lamp")
			kit.box(Vector3(side*.855,bar_y,0),Vector3(.12,.13,.19),Color("#ffbe47"),Vector3.ZERO,"lamp")
	else:
		for end_sign:float in [-1.0,1.0]:
			var tint:=Color("#ffaa35") if mode=="hazard" else (Color("#ffeac2") if end_sign<0 else Color("#f03937"))
			for side:float in [-1.0,1.0]:
				kit.box(Vector3(side*width*.82,height+.25,end_sign*length*.997),Vector3(.19,.112,.035),tint,Vector3.ZERO,"lamp")
		if mode=="running":
			var beam:=SpotLight3D.new()
			lamps.add_child(beam)
			beam.position=Vector3(0,height+.25,-length-.08)
			beam.rotation.x=-.08
			beam.light_color=Color("#fff0ce")
			beam.light_energy=1.8
			beam.spot_range=38
			beam.spot_angle=29
	kit.finish()
	return lamps

static func person(parent: Node3D, deputy: bool, variant: int = 0) -> Node3D:
	var scene := preload("res://assets/characters/stranded_driver.glb")
	if deputy:
		scene = preload("res://assets/characters/deputy.glb")
	elif variant == 1:
		scene = preload("res://assets/characters/farm_driver.glb")
	var witness := scene.instantiate() as Node3D
	witness.name = "Deputy" if deputy else "Driver"
	parent.add_child(witness)
	var animation: AnimationPlayer = witness.get_node("AnimationPlayer")
	animation.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	animation.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
	animation.play("idle")
	return witness

static func walk_person(witness: Node3D) -> void:
	var animation: AnimationPlayer = witness.get_node("AnimationPlayer")
	if animation.current_animation != "walk":
		animation.play("walk", 0.18)

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
