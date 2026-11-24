extends RefCounted
const K=preload("res://scripts/rig_mesh.gd")
const BLACK=Color("#272b2c")
const GLASS=Color("#38464b")
const STEEL=Color("#929895")
const SNOW=Color("#ced4d4")
const HOLD_BODY=Color("#deded2")
const TAPE=Color("#f4e409")

static func car(parent:Node3D, kind:String, variant:int) -> Node3D:
	var is_hold:=kind=="hold"
	var wagon:=kind=="hazard" and variant==2
	var p=K.joint(parent,Vector3.ZERO,"CountyPickup" if is_hold else "RoadCar")
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
			K.label(p,"TAMARACK COUNTY\nLAND SURVEY",Vector3(s*(width+.024),base+.21,-.40),.082,Color("#29433b"),Vector3(0,s*PI/2,0))
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
		g.box(Vector3(0,base+.115,z*1.016),Vector3(.32,.15,.03),Color("#d5d8ba"))
	g.finish()
	if kind!="ditch":
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

static func person(parent:Node3D,deputy:bool) -> Node3D:
	var p=K.joint(parent,Vector3.ZERO,"Deputy" if deputy else "Driver")
	var g=K.new(p)
	var coat:=Color("#424844") if deputy else Color("#7f6559")
	var trouser:=Color("#464a4c") if deputy else Color("#3b4653")
	var skin:=Color("#b9927b")
	for side in [-1.0,1.0]:
		var x:float=side*.11
		g.box(Vector3(x,.085,-.048),Vector3(.165,.17,.32),BLACK)
		g.tube(Vector3(x,.16,0),Vector3(x,.74,0),.088,trouser,8,"paint",.11)
	g.tube(Vector3(0,.76,0),Vector3(0,1.36,0),.212,coat,10,"paint",.26)
	g.tube(Vector3(0,1.34,0),Vector3(0,1.43,0),.20,coat,10,"paint",.12)
	g.tube(Vector3(0,1.41,0),Vector3(0,1.49,0),.079,skin,8,"paint")
	g.tube(Vector3(0,1.455,-.006),Vector3(0,1.55,-.012),.086,skin,9,"paint",.122)
	g.tube(Vector3(0,1.55,-.012),Vector3(0,1.686,0),.122,skin,9,"paint",.116)
	g.tube(Vector3(0,1.635,0),Vector3(0,1.722,0),.13,Color("#393b39"),10,"paint",.114)
	g.tube(Vector3(0,1.722,0),Vector3(0,1.755,0),.114,Color("#393b39"),10,"paint",.050)
	g.box(Vector3(0,1.557,-.126),Vector3(.043,.052,.03),skin.darkened(.08))
	for s in [-1.0,1.0]:
		g.box(Vector3(s*.047,1.598,-.115),Vector3(.025,.009,.012),Color("#483d34"))
		g.tube(Vector3(s*.204,1.32,0),Vector3(s*.285,1.032,-.012),.081,coat,8,"paint",.074)
		g.tube(Vector3(s*.285,1.039,-.012),Vector3(s*.174,.936,-.142),.074,coat,8,"paint",.069)
		g.tube(Vector3(s*.175,.937,-.143),Vector3(s*.145,.913,-.156),.066,BLACK,8,"paint",.044)
		if deputy:
			g.box(Vector3(s*.114,1.21,-.193),Vector3(.038,.29,.027),Color("#a8a58b"),Vector3(0,0,s*.13))
	g.finish()
	return p

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
