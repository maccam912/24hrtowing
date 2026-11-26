extends RefCounted
## County architecture is built in site-local coordinates, then baked in culling cells.
const SignMount = preload("res://scripts/sign_mount.gd")
const YardDrop = preload("res://scripts/yard_drop.gd")
var world
var draw
var origin := Vector3.ZERO
var rng := RandomNumberGenerator.new()

func _init(county, geometry) -> void:
	world = county
	draw = geometry
	rng.seed = 83193

func site(x: float,z: float, ground := 0.0) -> void:
	origin = world.resolve_point(Vector3(x,ground,z))

func p(x: float,y: float,z: float) -> Vector3:
	return origin+Vector3(x,y,z)

func b(x: float,y: float,z: float,w: float,h: float,d: float,mat: String,solid := false) -> void:
	draw.box(p(x,y,z),Vector3(w,h,d),mat,solid)

func cyl(x: float,y: float,z: float,w: float,h: float,mat: String,solid := false) -> void:
	draw.add("cylinder",p(x,y,z),Vector3(w,h,w),mat)
	if solid:
		draw.solid_box(p(x,y,z),Vector3(w*.83,h,w*.83))

func beam(a: Vector3,bb: Vector3,w: float,d: float,mat: String) -> void:
	draw.beam(origin+a,origin+bb,w,d,mat)

func label(at: Vector3, words: String, height: float, yaw: float, ink: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var type := Label3D.new()
	type.text = words
	if world.county_font:
		type.font = world.county_font
	type.font_size = 64
	type.pixel_size = height/74.
	type.modulate = ink
	type.outline_size = 0
	type.shaded = false
	type.double_sided = false
	type.horizontal_alignment = align
	type.position = origin+at
	type.rotation.y = yaw
	type.visibility_range_end = minf(155.,45.+height*65.)
	type.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.parent.add_child(type)
	return type

func placard(at: Vector3, words: String, width: float, height: float, yaw: float, panel := "green", both := false) -> void:
	var front := Basis(Vector3.UP,yaw)*Vector3.BACK
	draw.box(origin+at,Vector3(width,height,.095),panel,false,Vector3(0,yaw,0))
	var font_height := minf(height*.82,width/maxi(1,words.length())*1.75)
	label(at+front*.053,words,font_height,yaw,Color("#ece9d5"))
	if both:
		label(at-front*.054,words,font_height,yaw+PI,Color("#ece9d5"))

func lamp(x: float,z: float, height := 6.0, actual := true, street_fixture := false) -> void:
	world.lamp_locations.sodium.append(p(x+.88,height-.07,z))
	cyl(x,height*.5,z,.18,height,"wood")
	beam(Vector3(x,height-.2,z),Vector3(x+.85,height+.08,z),.09,.09,"post")
	b(x+.88,height+.06,z,.9,.18,.46,"dark")
	var bulb_draw = draw
	var luminous: Node3D
	if street_fixture:
		luminous = Node3D.new()
		luminous.name = "MainStreetLight"
		draw.parent.add_child(luminous)
		luminous.position = p(x+.88,height-.07,z)
		luminous.add_to_group("esker_street_lamps")
		bulb_draw = world.Batch.new(luminous,world.materials)
	var center := Vector3.ZERO if street_fixture else p(x+.88,height-.07,z)
	bulb_draw.box(center,Vector3(.64,.13,.36),"lamp")
	for yaw: float in [0.,PI*.5]:
		bulb_draw.add("quad",center,Vector3(6.0,6.0,1),"sodium",Vector3(0,yaw,0))
	if street_fixture: bulb_draw.finish()
	if actual:
		var light := OmniLight3D.new()
		light.position=p(x+.88,height-.35,z)
		light.light_color=Color("#ffa65c")
		light.light_energy=3.6
		light.omni_range=height*2.6
		light.omni_attenuation=.88
		light.distance_fade_enabled=true
		light.distance_fade_begin=43
		light.distance_fade_length=18
		if street_fixture:
			light.position = Vector3.DOWN*.28
			luminous.add_child(light)
		else:
			draw.parent.add_child(light)

func street_sign(x: float,z: float, first: String, second: String) -> void:
	site(x,z,world.ground_height(x,world.resolve_point(Vector3(0,0,z)).z))
	cyl(0,1.8,0,.12,3.6,"post")
	var mount := SignMount.new()
	mount.county = world
	mount.position = origin + Vector3.UP * 3.10
	draw.parent.add_child(mount)
	# Bake each pair of blades and both faces of its lettering onto the mount.
	var plates = get_script().new(world, world.Batch.new(mount, world.materials))
	plates.placard(Vector3.UP * .25,first,3.1,.44,0.0,"green",true)
	plates.placard(Vector3.DOWN * .26,second,3.1,.44,PI*.5,"green",true)
	plates.draw.finish()

func address(x: float,z:float, text: String, yaw: float) -> void:
	site(x,z,world.ground_height(x,world.resolve_point(Vector3(0,0,z)).z))
	b(0,.69,0,.11,1.38,.13,"wood")
	placard(Vector3(0,1.3,0),text,1.24,.43,yaw,"green",true)

func roof(x: float,y: float,z: float,w: float,h: float,d: float,mat := "snow") -> void:
	for s: float in [-1.,1.]:
		var angle := -s*atan2(h,w*.5)
		draw.box(p(x+s*w*.25,y+h*.5,z),Vector3(Vector2(w*.5,h).length()+.25,.22,d+.48),mat,false,Vector3(0,0,angle))
	# Gable end triangles are filled with siding behind the eaves.
	for s: float in [-1.,1.]:
		var face := z+s*d*.5
		draw.quad(p(x-w*.5,y,face),p(x,y+h,face),p(x+w*.5,y,face),p(x,y+.01,face),"silver")

func window(at: Vector3,w: float,h: float,yaw := 0.,lit := true) -> void:
	var basis := Basis(Vector3.UP,yaw)
	var front := basis*Vector3.BACK
	draw.box(origin+at,Vector3(w+.14,h+.15,.08),"cream",false,Vector3(0,yaw,0))
	draw.box(origin+at+front*.05,Vector3(w,h,.065),"window" if lit else "glass",false,Vector3(0,yaw,0))
	draw.box(origin+at+front*.095,Vector3(.055,h,.04),"dark",false,Vector3(0,yaw,0))
	draw.box(origin+at+front*.095,Vector3(w,.055,.04),"dark",false,Vector3(0,yaw,0))

func house(x: float,z: float) -> void:
	site(x,z)
	b(0,2.1,0,8.5,4.2,10,"cream",true)
	roof(0,4.2,0,9.3,2.7,10.7)
	b(-2.6,6.0,-2.0,.8,3.0,.78,"brick")
	b(1.0,1.2,5.1,1.14,2.4,.14,"green")
	b(.8,.2,5.8,3.8,.4,1.55,"wood")
	for xx: float in [-2.4,2.9]:
		window(Vector3(xx,2.0,5.05),1.5,1.45,0,xx<0)
	for zz: float in [-2.8,1.8]:
		window(Vector3(-4.28,2.05,zz),1.5,1.43,-PI*.5,true)
	lamp(-7,5,5.2)

func barn(x: float,z: float, large: bool) -> void:
	site(x,z)
	var w := 15. if large else 10.
	var d := 36. if large else 18.
	b(0,3.35,0,w,6.7,d,"siding",true)
	# Two pitches per side give the old dairy barn its gambrel silhouette.
	var break_x := w*.33
	var bottom := 6.65
	var break_h := 9.5
	var ridge := 10.85
	for s: float in [-1.,1.]:
		for shape: Array in [[w*.5,bottom,break_x,break_h],[break_x,break_h,0.,ridge]]:
			var a := Vector3(float(shape[0])*s,shape[1],0)
			var bb := Vector3(float(shape[2])*s,shape[3],0)
			draw.box(origin+(a+bb)*.5,Vector3((bb-a).length()+.27,.24,d+.62),"snow",false,Vector3(0,0,atan2(bb.y-a.y,bb.x-a.x)))
	for side: float in [-1.,1.]:
		var zz := side*d*.5
		draw.quad(p(-w*.5,bottom,zz),p(-break_x,break_h,zz),p(break_x,break_h,zz),p(w*.5,bottom,zz),"siding")
		draw.quad(p(-break_x,break_h,zz),p(0,ridge,zz),p(break_x,break_h,zz),p(0,break_h,zz),"siding")
		b(0,2.4,zz+side*.07,4.4,4.8,.16,"cream")
		b(0,2.3,zz+side*.17,4.15,4.6,.15,"oxide")
		for flip: float in [-1.,1.]:
			beam(Vector3(-2,2.3+flip*2.15,zz+side*.28),Vector3(2,2.3-flip*2.15,zz+side*.28),.12,.12,"cream")
	for i in range(-2,3):
		window(Vector3(-w*.5-.04,3.4,d*.15*i),1.7,1.,-PI*.5,large)
	var silo_x := w*.5+4.
	cyl(silo_x,6.8,d*.2,5.4,13.6,"silver",true)
	draw.add("cone",p(silo_x,14.45,d*.2),Vector3(5.7,1.9,5.7),"snow")
	for i in 7:
		cyl(silo_x,i*1.84+.6,d*.2,5.48,.10,"dark")
	b(silo_x-2.7,7,d*.2,.22,14,.25,"silver")
	lamp(-w*.5-1,-d*.5-2,6.6)

func fence(a: Vector3, end: Vector3, height: float, mesh_fence := true, solid := false) -> void:
	var length := a.distance_to(end)
	var bays := ceili(length/(4.3 if mesh_fence else 7.9))
	for i in bays+1:
		var pt := a.lerp(end,float(i)/bays)
		draw.box(origin+pt+Vector3.UP*(height*.52), Vector3(.11,height*1.04,.11), "post" if mesh_fence else "wood")
	beam(a+Vector3.UP*height,end+Vector3.UP*height,.06,.06,"post")
	if mesh_fence:
		var up := Vector3.UP*height
		draw.quad(origin+a,origin+a+up,origin+end+up,origin+end,"wire",PackedVector2Array([Vector2.ZERO,Vector2(0,height),Vector2(length,height),Vector2(length,0)]))
	else:
		beam(a+Vector3.UP*.5,end+Vector3.UP*.5,.035,.035,"post")
	if solid:
		var middle := origin+(a+end)*.5+Vector3.UP*height*.44
		draw.solid_box(middle,Vector3(length,height*.90,.16),Vector3(0,-atan2(end.z-a.z,end.x-a.x),0))

func yard() -> void:
	site(0,0)
	for edge: Array in [
		[Vector3(-61,0,-86),Vector3(-4,0,-86)], [Vector3(-61,0,-86),Vector3(-61,0,-72)],
		[Vector3(-61,0,-57),Vector3(-61,0,-34)],
		[Vector3(-61,0,-34),Vector3(-4,0,-34)], [Vector3(-4,0,-86),Vector3(-4,0,-74)],
		[Vector3(-4,0,-54),Vector3(-4,0,-34)]
	]:
		fence(edge[0],edge[1],2.3,true,true)
	for xx: float in [-58.,-21.]:
		lamp(xx,-84,6.)
	lamp(-7.5,-52.5,5.7)
	# Plow windrows stack against the fence, leaving the gate and storage stalls clear.
	for i in 18:
		var xx := -59.+i*3.12
		var span := rng.randf_range(4.1,7.)
		draw.add("mound",p(xx,.06,-85.4+rng.randf_range(-.2,.3)),Vector3(span,rng.randf_range(.8,1.8),2.9),"snow",Vector3(0,rng.randf_range(-.1,.1),0))
	for i in [0,1,5]:
		draw.add("mound",p(-60.2,.04,-78.+i*5.4),Vector3(2.2,rng.randf_range(.7,1.48),7.8),"snow")
	for zz: float in [-77.,-82.,-50.4,-42.5]:
		draw.add("mound",p(-5.2,.07,zz),Vector3(2.1,1.38,6.5),"snow")
	# Heated shop and evidence bay. The north and east sides of the bay are open.
	b(-51.0,4.9,-44.8,18,.42,13,"silver")
	b(-51.0,5.19,-44.8,18.4,.22,13.4,"snow")
	b(-59.6,2.4,-45.1,.45,4.8,12.8,"silver",true)
	b(-51.0,2.4,-38.6,17.7,4.8,.44,"silver",true)
	for xx: float in [-59.4,-42.4]:
		for zz: float in [-50.8,-38.8]:
			b(xx,2.47,zz,.23,4.94,.23,"oxide",true)
	b(-50.8,4.7,-50.9,17.55,.52,.24,"oxide")
	b(-50.6,4.44,-46.8,7.0,.13,.32,"fluoro")
	placard(Vector3(-50.7,4.64,-51.5),YardDrop.EVIDENCE.sign,13.5,1.65,PI,"black")
	placard(Vector3(-41.75,4.64,-44.8),YardDrop.EVIDENCE.sign,12.4,1.65,PI*.5,"black")
	placard(Vector3(-57.2,1.45,-84.9),"STORAGE",4.2,.67,0,"dark")
	# Office window and weatherproof fax desk face the yard. The fax interaction
	# stands in open ground at (-40,-39), with no wall between player and machine.
	b(-38,1.82,-35.45,8,3.64,4.4,"silver",true)
	b(-38,3.77,-35.45,8.5,.26,4.85,"snow")
	window(Vector3(-38.8,2.08,-37.72),2.5,1.30,PI)
	b(-40.5,.81,-38.16,1.42,.18,.72,"wood")
	for xx: float in [-41.05,-40.0]:
		b(xx,.40,-38.1,.12,.80,.12,"dark")
	b(-40.5,1.02,-38.14,.83,.27,.53,"cream")
	b(-40.5,1.19,-37.97,.59,.28,.12,"white")
	b(-40.5,1.17,-38.17,.54,.024,.045,"black")
	b(-40.46,1.08,-38.45,.37,.018,.24,"white")
	b(-40.78,1.19,-38.14,.105,.065,.36,"dark")
	for zz:float in [-38.30,-38.01]:
		b(-40.78,1.19,zz,.15,.10,.13,"black")
	b(-40.39,1.18,-38.08,.20,.033,.080,"green")
	for row in 3:
		for col in 3:
			b(-40.55+col*.070,1.17,-38.22-row*.04,.046,.021,.025,"dark")
	b(-35.8,1.25,-37.74,1.2,2.5,.1,"green")
	b(-35.4,.96,-37.82,.17,.053,.07,"post")
	placard(Vector3(-38.1,3.03,-37.79),"OFFICE   /   FAX",4.2,.52,PI,"black")
	# The yard's bulk tank feeds a metered hose beside the service counter.
	b(-38.6,.73,-38.1,.71,1.46,.49,"oxide")
	b(-38.6,1.33,-38.37,.57,.35,.07,"cream")
	beam(Vector3(-38.17,1.14,-38.25),Vector3(-37.89,.34,-38.28),.075,.075,"black")
	beam(Vector3(-37.89,.34,-38.28),Vector3(-37.69,.50,-38.29),.075,.075,"black")
	beam(Vector3(-37.69,.50,-38.29),Vector3(-37.93,.98,-38.26),.075,.075,"black")
	placard(Vector3(-38.1,2.53,-37.88),"PARTS  •  DIESEL",4.2,.46,PI,"green")
	# Shop equipment sits just inside the fence outside the drop and parking lanes.
	for i in 5:
		var cx := -11.3-i*.77
		b(cx,.28,-36.4,.42,.55,.42,"wood")
		draw.add("cylinder",p(cx,.83,-36.4),Vector3(1.12,.43,1.12),"black",Vector3(0,0,PI*.5))
		draw.add("cylinder",p(cx,.83,-36.4),Vector3(.66,.46,.66),"post",Vector3(0,0,PI*.5))
		draw.add("cylinder",p(cx,.83,-36.4),Vector3(.27,.48,.27),"dark",Vector3(0,0,PI*.5))
	b(-10.5,.49,-81.5,.36,.85,.60,"wood")
	b(-8.8,.49,-81.5,.36,.85,.60,"wood")
	draw.add("cylinder",p(-9.7,1.04,-81.5),Vector3(1.28,2.64,1.28),"cream",Vector3(0,0,PI*.5))
	for xx:float in [-11.02,-8.38]:
		draw.add("mound",p(xx,1.04,-81.5),Vector3(.52,1.27,1.27),"cream")
	b(-9.0,1.73,-81.5,.38,.18,.33,"oxide")
	# Weathered porcelain yard sign, backs visible from either approach.
	for zz: float in [-52.,-47.0]:
		b(-4.9,2.12,zz,.18,4.24,.18,"wood")
	var sign_at := p(-4.9,3.8,-49.5)
	draw.box(sign_at,Vector3(6.5,2.17,.17),"oxide",false,Vector3(0,PI*.5,0))
	for direction: float in [-1.,1.]:
		draw.add("quad",sign_at+Vector3.RIGHT*.093*direction,Vector3(6.5,2.17,1),"sign",Vector3(0,PI*.5*direction,0))
	# Yard air compressor and a stack of salt-stained tires near the office.
	cyl(-31.1,.82,-37,.97,1.64,"oxide",true)
	for j in 3:
		cyl(-30,.22+j*.31,-36.6,.89,.29,"black")

func storage_pad() -> void:
	site(YardDrop.STORAGE.center.x, YardDrop.STORAGE.center.z)
	var sign_at := Vector3(0, 3.55, -5.4)
	var yaw := 1.08 # Face the open gate on County K.
	var basis := Basis(Vector3.UP, yaw)
	var rotation := Vector3(0, yaw, 0)
	for side: float in [-1.0, 1.0]:
		var leg := sign_at + basis.x * side * 2.7
		b(leg.x, 1.65, leg.z, .14, 3.3, .14, "post")
	draw.box(origin + sign_at, Vector3(8.6, 2.0, .17), "black", false, rotation)
	var lettering := label(sign_at + basis.z * .096, YardDrop.STORAGE.sign, 1.80, yaw, Color("#ece9d5"))
	var bold := FontVariation.new()
	bold.base_font = world.county_font
	bold.variation_opentype = {"weight": 740}
	lettering.font = bold

func drop_guide() -> void:
	# Light the assigned bay and leave both ends open for the wrecker.
	for z: float in [-YardDrop.HALF_SIZE.y, YardDrop.HALF_SIZE.y]:
		for x: float in [-7.2, -3.6, 0.0, 3.6, 7.2]:
			b(x, .035, z, 2.85, .04, .30, "safety_yellow")
		for x: float in [-YardDrop.HALF_SIZE.x, YardDrop.HALF_SIZE.x]:
			b(x, .075, z, .74, .15, .74, "black")
			cyl(x, .81, z, .29, 1.52, "safety_yellow")
			for h: float in [.54, 1.06]:
				cyl(x, h, z, .31, .24, "black")
			cyl(x, 1.61, z, .48, .15, "dark")
			cyl(x, 1.85, z, .43, .38, "amber_lens")
			for yaw: float in [0.0, PI * .5]:
				draw.add("quad", p(x, 1.86, z), Vector3(3.5, 3.5, 1), "sodium", Vector3(0, yaw, 0))
	# Two broad pavement chevrons lead inward from the gate.
	for x: float in [13.3, 9.5]:
		for z: float in [-1.0, 1.0]:
			beam(Vector3(x + 1.0, .065, z * 1.5), Vector3(x - .6, .065, 0), .045, .38, "safety_yellow")

func favor_lamps() -> void:
	# Portable amber lamps flank the folding reflector at the marked shoulder.
	for x: float in [-.95,.95]:
		b(x,.13,0,.37,.26,.34,"dark")
		cyl(x,.46,0,.12,.44,"safety_yellow")
		cyl(x,.77,0,.28,.21,"amber_lens")
		for yaw: float in [0.0,PI*.5]:
			draw.add("quad",p(x,.78,0),Vector3(2.1,2.1,1),"sodium",Vector3(0,yaw,0))

func esker() -> void:
	# Paired bell towers of St. Hedwig's read before its sign.
	site(22,80)
	b(0,3.8,4.,12.6,7.6,18,"cream",true)
	roof(0,7.6,4,13.2,4.8,18.4)
	for xx: float in [-5.0,5.0]:
		b(xx,5.40,-5,3.45,10.8,3.45,"brick",true)
		b(xx,10.52,-5,3.79,.34,3.79,"cream")
		b(xx,11.9,-5,2.85,2.8,2.85,"cream")
		b(xx,11.94,-6.46,1.66,1.86,.1,"dark")
		draw.add("cone",p(xx,16.8,-5),Vector3(4.1,7.4,4.1),"dark")
		b(xx,20.8,-5,.09,1.4,.09,"post")
		b(xx,21.1,-5,.82,.095,.09,"post")
	b(0,1.6,-5.1,2.55,3.2,.18,"oxide")
	for zz: float in [-2,2,6,10]:
		window(Vector3(-6.36,4.36,zz),1.1,2.85,-PI*.5,true)
	lamp(-6,-10,4.4)
	placard(Vector3(-8,1.7,-8),"ST. HEDWIG",3.55,.61,-PI*.5,"dark",true)
	site(37,-23)
	b(0,3.2,0,15,6.4,13,"siding",true)
	roof(0,6.4,0,15.2,3,13.2)
	# Low delivery canopy on the Main Street side of the gable. Its flat,
	# snow-topped roof can actually support the car seen here after a landing.
	b(0,4.50,9.40,11.0,.34,6.2,"silver",true)
	b(0,4.71,9.40,11.12,.08,6.26,"snow")
	for xx: float in [-4.96,4.96]:
		b(xx,2.18,12.04,.20,4.36,.21,"oxide",true)
		beam(Vector3(xx,3.2,12.04),Vector3(xx,4.33,10.70),.12,.14,"post")
	preload("res://scripts/coop_roof.gd").furnish(self)
	placard(Vector3(-7.56,4.5,0),"ESKER CO-OP",9.2,1.28,-PI*.5,"oxide")
	for xx:float in [11.5,17.4]:
		cyl(xx,6.4,-1,5.5,12.8,"silver",true)
		draw.add("cone",p(xx,13.9,-1),Vector3(5.8,2.3,5.8),"silver")
	lamp(-8,6,5.1)
	# Esker water tower on crossed legs.
	site(44,-68)
	for x:float in [-3.1,3.1]:
		for z:float in [-3.1,3.1]:
			beam(Vector3(x,0,z),Vector3(x*.69,37,z*.69),.27,.28,"post")
		beam(Vector3(x,2,-3.1),Vector3(x*.83,10,2.65),.12,.12,"post")
		beam(Vector3(x,2,3.1),Vector3(x*.83,10,-2.65),.12,.12,"post")
	cyl(0,38.1,0,8.7,5.0,"silver")
	draw.add("cone",p(0,41.15,0),Vector3(9.5,1.9,9.5),"snow")
	label(Vector3(-4.4,38.3,0),"ESKER",1.07,-PI*.5,Color("#eadac7"))
	# The ladder stands outside the legs so a person can reach it from the yard.
	for side: float in [-.39,.39]:
		beam(Vector3(4.7,0,2.1+side),Vector3(4.7,36.6,2.1+side),.10,.10,"post")
	for rung in 91:
		beam(Vector3(4.7,.32+rung*.39,1.68),Vector3(4.7,.32+rung*.39,2.52),.065,.08,"silver")
	for level: float in [12.,23.,34.]:
		for side: float in [-1.,1.]:
			beam(Vector3(2.55*side,level,-2.55),Vector3(-2.55*side,level+8,-2.55),.14,.14,"post")
			beam(Vector3(2.55,level,-2.55*side),Vector3(2.55,level+8,2.55*side),.14,.14,"post")
	# The east service landing clears the tank and has a ladder opening.
	b(4.45,35.4,2.10,2.45,.16,2.52,"silver")
	for z: float in [.89,3.31]:
		for x: float in [3.34,5.56]:
			b(x,36.04,z,.063,1.12,.063,"post")
		for y: float in [35.96,36.58]:
			beam(Vector3(3.31,y,z),Vector3(5.60,y,z),.058,.060,"post")
	for z: float in [1.34,2.85]:
		b(5.56,36.04,z,.063,1.12,.063,"post")
		var end := .89 if z < 2.0 else 3.31
		beam(Vector3(5.56,36.58,z),Vector3(5.56,36.58,end),.058,.060,"post")
	# Glasses and a pencilled bearing sit together on a shelf by the tank.
	b(4.40,36.66,1.60,.62,.07,.49,"wood")
	for z: float in [1.53,1.65]:
		draw.add("cylinder",p(4.40,36.75,z),Vector3(.109,.22,.109),"black",Vector3(0,0,PI*.5))
	b(4.42,36.75,1.59,.075,.06,.13,"dark")
	placard(Vector3(4.44,36.96,1.59),"LINDQUIST   SE",.79,.20,PI*.5,"green")
	b(4.47,2.02,.92,.08,1.06,.08,"post")
	placard(Vector3(4.53,2.18,.92),"TANK LADDER",1.3,.38,PI*.5,"green")
	site(-30,14)
	b(0,2.35,7,11.5,4.7,9,"oxide",true)
	b(0,4.85,7,12,.30,9.5,"snow")
	placard(Vector3(0,3.8,2.42),"ESKER TAP",7.8,.91,PI,"black")
	for xx:float in [-3.4,3.4]:
		window(Vector3(xx,2.0,2.44),2.1,1.3,PI,false)
	b(0,1.35,2.42,1.5,2.70,.16,"dark")
	for xx:float in [-134.,-98.,62.,105.]:
		house(xx, 32 if xx<0 else -50)
	site(0,0)
	for x:float in [-118,-38,25,94]:
		lamp(x,7.4 if x<0 else -7.4,6.3,true,true)

func river_and_seat() -> void:
	site(0,0)
	b(-475,-2.12,0,43,.18,1510,"river")
	for side: float in [-1.,1.]:
		b(-475,1.15,side*6.15,61,.26,.28,"post")
		b(-475,.67,side*6.15,61,.12,.20,"post")
		for xx in range(-504,-442,5):
			b(xx,.66,side*6.15,.19,1.34,.24,"post",true)
		b(-475,.29,side*6.15,61,.58,.4,"slush",true)
	site(-539,-13)
	for zz:float in [-5.5,5.5]:
		b(0,2.85,zz, .28,5.7,.28,"wood")
	placard(Vector3(0,4.8,0),"TAMARACK RIVER",12.3,1.68,PI*.5,"green",true)
	site(-580,27)
	b(0,2.7,0,17,5.4,10,"silver",true)
	roof(0,5.4,0,17.4,2.3,10.3)
	placard(Vector3(0,3.7,-5.1),"RIVER LANES  /  TRUCK STOP",14.9,1.1,PI,"black")
	lamp(-6,-7,7.1)
	site(-472,-99)
	b(0,0,0,51,4.6,6.4,"slush",true)
	for i in range(-18,20,6):
		b(i,.2,0,1.05,6,7.8,"silver")
	b(-17,4.8,0,8,4.2,5.8,"brick")
	roof(-17,6.9,0,8.3,1.7,6.1)
	# The winch works off the east landing above the dam.
	site(-445,-134)
	placard(Vector3(1.7,1.68,0),"FLOWAGE LANDING",3.25,.51,PI*.5,"green",true)
	b(1.7,.77,0,.14,1.54,.14,"wood")
	for zz: float in [-5.3,6.2]:
		b(-1.1,.70,zz,.13,1.40,.13,"oxide")
		b(-1.1,1.25,zz,.145,.21,.145,"white")
	site(-443,-6)
	placard(Vector3(0,2.18,0),"RIVER RD",2.85,.43,0,"green",true)
	placard(Vector3(0,1.6,0),"DAM LANDING ↑",3.1,.53,0,"green",true)
	b(0,.70,0,.15,1.4,.15,"wood")
	site(889,-25)
	b(0,4.7,0,30,9.4,13,"brick",true)
	for x:float in [-11.,-7.,-3.,1.,5.,9.]:
		window(Vector3(x,3.4,6.6),1.65,1.9)
		window(Vector3(x,7.05,6.6),1.65,1.9)
	b(0,9.7,0,30.5,.55,13.6,"snow")
	placard(Vector3(0,5.5,6.7),"TAMARACK COUNTY",15,1.15,0,"black")
	lamp(-12,9,6.3)
	site(905,44)
	for i in 3:
		var a := Vector3(cos(i*TAU/3.)*3.5,0,sin(i*TAU/3.)*3.5)
		beam(a,Vector3.UP*61,.23,.23,"oxide")
		beam(a*3.8,Vector3.UP*39,.045,.045,"post")
	for y in range(5,57,4):
		var width := 5.8*(1.-float(y)/61.)
		for i in 3:
			var ray := Vector3(cos(i*TAU/3.),0,sin(i*TAU/3.))
			var other := Vector3(cos((i+1)*TAU/3.),0,sin((i+1)*TAU/3.))
			beam(ray*width*.5+Vector3.UP*y,other*width*.47+Vector3.UP*(y+3.3),.09,.09,"post")
	cyl(0,61,0,1.2,.9,"red")

func spruce_at(x: float, z: float, solid: bool) -> void:
	# Leave the surveyor's foot trail, the driveway and the new road passable.
	if z >= -489 and z <= -408 and absf(x-lerpf(318.5,331.0,clampf((-413.0-z)/70.0,0,1))) < 2.6:
		return
	if Rect2(405,286,120,104).has_point(Vector2(x,z)):
		# Leave the milk lane and the farmhouse doorway clear.
		if Rect2(420,314,37,25).has_point(Vector2(x,z)) or world.road_distance(x,world.resolve_point(Vector3(0,0,z)).z)<9.5:
			return
	var real_z: float = world.resolve_point(Vector3(0,0,z)).z
	site(x,z,world.ground_height(x,real_z))
	var height := rng.randf_range(5.3,15.3)
	var yaw := rng.randf_range(-PI,PI)
	if z < -395 and z > (world.CaseSites.ALDER_END-8 if world.alder_open else -484.0):
		if absf(x-world.CaseSites.ALDER_X) < 10 or world.CaseSites.HOUSE_YARD.grow(2).has_point(Vector2(x,z)):
			return
	draw.spruce(origin, height, yaw)
	if solid:
		draw.solid_box(p(0,1.5,0),Vector3(.34,3,.34))

func grove_at(x: float,z: float,number: int,radius: float) -> void:
	for i in number:
		var xx := x+rng.randf_range(-radius,radius)
		var zz := z+rng.randf_range(-radius,radius)
		var real_z: float = world.resolve_point(Vector3(0,0,zz)).z
		# Draw from the original forest first so opening the new spur only clears its corridor.
		var road_distance: float = world.road_distance(xx,real_z,false)
		if road_distance < 15 or Rect2(-142,-98,200,199).has_point(Vector2(xx,zz)):
			continue
		spruce_at(xx,zz,road_distance < 55 and i%2 == 0)

func shelterbelts() -> void:
	# Loose rows along the backs of the yard and fields give the gusts a
	# silhouette near the driver, with gaps at the gates, turnouts and job sites.
	for run: Array in [
		[-79,-98,-70,-35],[-59,-102,-10,-102],[19,-124,19,-64],
		[-22,116,-30,174],[23,135,30,202],[-29,216,-20,286],
		[50,378,114,371],[128,420,179,422],[422,167,431,218],
		[378,246,373,304],[418,506,427,552],[23,526,21,609],
		[-408,-24,-348,-17],[-407,25,-366,34],[-273,-22,-194,-17],
		[-588,154,-588,222],[124,18,188,24],[514,-22,588,-19],
		[-20,-350,-25,-293],[75,-382,139,-375],[270,-431,338,-436],
		[308,-378,365,-383],[768,706,777,767],[154,779,227,777]
	]:
		var start := Vector2(run[0],run[1])
		var end := Vector2(run[2],run[3])
		var steps := ceili(start.distance_to(end)/5.5)
		for i in steps:
			var at := start.lerp(end, float(i)/steps)
			at += Vector2(rng.randf_range(-3.7,3.7),rng.randf_range(-3.7,3.7))
			spruce_at(at.x,at.y,true)

func rural_grid() -> void:
	house(431,246)
	barn(465,262,false)
	house(132,431)
	barn(93,435,true)
	barn(74,462,false)
	site(98,420)
	placard(Vector3(0,2.5,0),"BRZEZINSKI DAIRY",7,.94,PI,"oxide",true)
	for xx:float in [-2.9,2.9]:
		b(xx,1.37,0,.15,2.74,.15,"wood")
	house(771,339)
	barn(753,344,true)
	barn(382,650,false)
	house(366,620)
	house(43,734)
	site(0,0)
	# A narrow field access with a culvert crosses the ditch at each dairy.
	for lane:Array in [[406,246,430,246],[94,405,94,425]]:
		var a:Vector3 = world.resolve_point(Vector3(lane[0],.01,lane[1]))
		var bb:Vector3 = world.resolve_point(Vector3(lane[2],.01,lane[3]))
		draw.box((a+bb)*.5,Vector3(absf(bb.x-a.x)+3,.13,absf(bb.z-a.z)+3),"slush",true)
	for row:Array in [[13,185,152],[13,490,230],[414,267,92],[789,438,155],[-13,-378,189],[413,490,117]]:
		site(row[0],row[1])
		if row[0]==414 and row[1]==267:
			fence(Vector3.ZERO,Vector3(0,0,63),1.17,false)
			fence(Vector3(0,0,75),Vector3(0,0,row[2]),1.17,false)
		else:
			fence(Vector3.ZERO,Vector3(0,0,row[2]),1.17,false)
	for index in 6:
		var xx := 36+index*6
		site(xx,-251)
		for i in 15:
			b(0,1.55,i*5,.13,3.1,.13,"wood")
		beam(Vector3(0,2.91,0),Vector3(0,2.91,70),.045,.045,"post")
	for index in 8:
		site(43,-248+index*9)
		beam(Vector3(-7,2.97,0),Vector3(24,2.97,0),.052,.052,"post")
	for spec:Array in [[-62,152,21,33],[82,180,27,44],[-100,334,55,70],[270,122,42,56],[243,360,24,31],[473,85,27,43],[452,345,31,39],[865,450,32,71],[241,480,55,53],[310,720,34,62],[-54,-268,34,44],[63,-337,44,37],[45,-456,95,55],[225,-454,84,48],[408,-475,65,50],[-210,-416,36,44],[-350,42,40,34],[-215,-71,49,41],[180,57,34,29],[610,-42,38,41],[676,751,43,53]]:
		grove_at(spec[0],spec[1],spec[2],spec[3])
	shelterbelts()

func power_span(a: Vector3, b_end: Vector3, across: Vector3) -> void:
	var sections := ceili(a.distance_to(b_end)/6.0)
	var sag := minf(a.distance_to(b_end)*.022,1.65)
	var orientation := absf(across.x)
	var previous := a
	for segment in range(1,sections+1):
		var t := float(segment)/sections
		var next := a.lerp(b_end,t) - Vector3.UP * (4.0*t*(1.0-t)*sag)
		var uv_a := Vector2(float(segment-1)/sections,orientation)
		var uv_b := Vector2(t,orientation)
		var uv := PackedVector2Array([uv_a,uv_a,uv_b,uv_b])
		for width: Vector3 in [Vector3.UP*.032,across*.032]:
			draw.quad(previous-width,previous+width,next+width,next-width,"conductor",uv)
		previous = next

func road_furniture() -> void:
	for r:Array in world.ROADS:
		var start: Vector3 = world.resolve_point(Vector3(r[1],0,r[2]))
		var end: Vector3 = world.resolve_point(Vector3(r[3],0,r[4]))
		var dir := start.direction_to(end)
		var side := dir.cross(Vector3.UP)
		var length := start.distance_to(end)
		var highway: bool = r[0] == "Highway 64" or r[0] == "US 59"
		var has_poles: bool = highway or r[0] in ["County K","Kolpack Rd","Hendricks Rd","Swamp Rd"]
		var previous := Vector3.ZERO
		for i in range(0,int(length+1),48):
			var point := start+dir*i
			# Utility poles are sited on the field side of the roadside ditch.
			var here := point+side*12.9
			var skip: bool = world.East.LOT.has_point(Vector2(here.x,here.z)) or (here.x > -507 and here.x < -442) or (Rect2(-102,-96,208,140).has_point(Vector2(here.x,here.z))) or here.distance_to(Vector3(318,0,-412)) < 20
			if skip:
				previous = Vector3.ZERO
				continue
			# Keep the wire continuous across a junction while clearing both shoulders.
			if has_poles and world.road_distance(here.x,here.z) >= 12.0:
				here.y = world.ground_height(here.x,here.z)
				origin=here
				cyl(0,3.55,0,.22,7.65,"wood")
				draw.beam(here-side*1.34+Vector3.UP*7.1,here+side*1.34+Vector3.UP*7.1,.11,.11,"wood")
				for arm:float in [-1.,1.]:
					var ins := here+side*arm+Vector3.UP*7.27
					draw.box(ins,Vector3(.12,.27,.12),"glass")
					if previous != Vector3.ZERO:
						var start_line := previous + side*arm+Vector3.UP*7.4
						var end_line := ins+Vector3.UP*.13
						power_span(start_line,end_line,side)
				previous = here
			# Low reflective snow stakes parallel the road without covering the lane.
			if i%96==0:
				for s:float in [-1.,1.]:
					var foot := point+side*6.5*s
					if world.East.LOT.has_point(Vector2(foot.x,foot.z)) or world.road_distance(foot.x,foot.z) < 6.5:
						continue
					foot.y = world.ground_height(foot.x,foot.z)
					draw.box(foot+Vector3.UP*.49,Vector3(.07,.98,.08),"wood")
					draw.box(foot+Vector3.UP*.91,Vector3(.084,.14,.095),"white")
		for i in range(6,int(length-4),12 if highway else 18):
			var pt := start+dir*i
			if (absf(pt.x) < 9 or absf(pt.x-400)<9 or absf(pt.x-800)<9) and (absf(pt.z)<9 or absf(pt.z+400)<9 or absf(pt.z-400)<9 or absf(pt.z-800)<9):
				continue
			var stripe_size := Vector3(3.5,.02,.105) if absf(dir.x)>.5 else Vector3(.105,.02,3.5)
			draw.box(pt+Vector3.UP*.022,stripe_size,"stripe")
	for sign:Array in [[-6.7,-7.3,"HWY 64","COUNTY K"],[6.8,-393.2,"SWAMP RD","COUNTY K"],[393.,7.2,"HWY 64","KOLPACK RD"],[7.2,393.,"HENDRICKS RD","COUNTY K"],[393.,393.,"HENDRICKS RD","KOLPACK RD"],[793.,7.3,"HWY 64","COUNTY FF"],[7.,793.,"ZIELINSKI RD","COUNTY K"],[393.,793.,"ZIELINSKI RD","KOLPACK RD"],[793.,393.,"HENDRICKS RD","COUNTY FF"]]:
		street_sign(sign[0],sign[1],sign[2],sign[3])
	address(304,-406.8,"SEC. 3",PI*.5)
	site(11,-49)
	placard(Vector3(0,1.8,0),"ESKER  •  POP 402",4.6,.76,0.0,"green",true)
	for x:float in [-1.68,1.68]:
		b(x,.91,0,.14,1.82,.14,"wood")
	# County closures at the outer survey roads. The yard gate always stays open.
	for end_point:Array in [[-635,0,PI*.5],[world.East.CLOSURE_X,0,PI*.5],[455,-400,PI*.5],[-180,-400,PI*.5],[0,-420,0.],[-608,-280,0.],[-608,350,0.]]:
		site(end_point[0],end_point[1])
		placard(Vector3(0,1.4,0),"ROAD CLOSED",5.6,.7,end_point[2],"oxide",true)
		for s:float in [-1.,1.]:
			var offset := Basis(Vector3.UP,end_point[2])*Vector3(2.15*s,0,0)
			b(offset.x,.74,offset.z,.19,1.49,.19,"wood")
	site(0,0)

func bare_ring(center: Vector3, radius: float) -> void:
	# Follow the terrain around the rim, including the ditch beside the turnout.
	# The dark wet earth and its narrow meltwater edge have no tracks leading in.
	var segments := 36
	var mid := Vector3(center.x,world.ground_height(center.x,center.z)+.065,center.z)
	for n in segments:
		var a := float(n)*TAU/segments
		var b_end := float(n+1)*TAU/segments
		var corners: Array[Vector3] = []
		for dims: Vector2 in [Vector2(a,radius),Vector2(b_end,radius),Vector2(b_end,radius*.88),Vector2(a,radius*.88)]:
			var radial := dims.y * (1.0+.017*sin(dims.x*5))
			var x := center.x+cos(dims.x)*radial
			var z := center.z+sin(dims.x)*radial
			corners.append(Vector3(x,world.ground_height(x,z)+.073,z))
		draw.quad(corners[0],corners[1],corners[2],corners[3],"glass")
		draw.quad(corners[3],corners[2],mid,mid,"dark")

func footprints(start: Vector3, finish: Vector3, steps: int) -> void:
	var forward := start.direction_to(finish)
	forward.y = 0
	forward = forward.normalized()
	var sideways := forward.cross(Vector3.UP)
	for i in range(1,steps+1):
		var t := float(i)/steps
		var at := start.lerp(finish,t) + sideways*(sin(t*TAU)*.37+(.13 if i%2==0 else -.13))
		at.y = world.ground_height(at.x,at.z)+.055
		var yaw := .10 if i%2 else -.10
		var side := sideways.rotated(Vector3.UP,yaw)*.109
		var step := forward.rotated(Vector3.UP,yaw)*.193
		draw.quad(at-side-step,at-side+step,at+side+step,at+side-step,"bootprint")

func hold_site() -> void:
	var corner: Vector3 = world.hold_tripod_point()
	var rod: Vector3 = world.rod_case_point()
	bare_ring(corner,2.65)
	origin = corner
	cyl(0,.123,0,.19,.06,"brass")
	footprints(corner+Vector3.FORWARD*2.7,rod+Vector3.BACK*.85,113)

func survey_rod_case() -> void:
	# A riveted field case. Turning it over in the snow exposes the underside tag.
	b(0,0,0,1.87,.30,.38,"green",true)
	b(0,.16,0,1.90,.035,.40,"silver")
	for xx: float in [-.85,.85]:
		b(xx,0,0,.064,.318,.392,"post")
		b(xx,.173,0,.068,.025,.403,"post")
	for xx: float in [-.59,.59]:
		b(xx,.075,.203,.10,.12,.032,"brass")
		b(xx,.08,.224,.055,.058,.016,"black")
	for xx: float in [-.17,.17]:
		b(xx,-.014,.228,.034,.043,.090,"wood")
	b(0,-.014,.284,.371,.046,.037,"black")
	b(0,-.155,0,1.36,.018,.32,"cream")
	var stencil := label(Vector3(0,-.167,-.061),"TAMARACK COUNTY SURVEY",.077,0,Color("#273b2d"))
	stencil.rotation.x=PI*.5
	var number := label(Vector3(0,-.167,.066),"UNIT 38",.105,0,Color("#273b2d"))
	number.rotation.x=PI*.5

func kolpack_farm() -> void:
	# The Hoffmanns’ milk lane is printed on the county plat.
	site(445,326)
	b(0,.11,0,8.55,.22,10.35,"wood")
	b(0,1.96,-5,8.45,3.92,.24,"siding",true)
	for x:float in [-4.17,4.17]:
		b(x,1.96,0,.24,3.92,10.2,"siding",true)
	b(-2.03,1.96,5,4.28,3.92,.24,"siding",true)
	b(3.09,1.96,5,2.17,3.92,.24,"siding",true)
	b(1.04,3.08,5,1.93,1.68,.24,"siding",true)
	roof(0,3.92,0,9.0,2.3,10.7)
	b(-2.65,5.0,-.9,.8,2.75,.77,"brick")
	b(.15,1.11,4.18,.12,2.22,1.66,"green",true)
	b(1,.08,5.72,3.2,.14,1.32,"wood")
	for xx: float in [-.53,2.53]:
		b(xx,1.30,6.31,.14,2.48,.14,"wood",true)
		b(xx,.29,6.31,.24,.31,.24,"cream")
	draw.box(p(1,2.65,5.90),Vector3(3.64,.15,2.08),"snow",false,Vector3(.13,0,0))
	b(1,2.46,6.78,3.67,.16,.10,"wood")
	window(Vector3(-2.03,2.00,5.14),1.62,1.24)
	window(Vector3(4.31,2.0,1.6),1.51,1.30,PI*.5)
	placard(Vector3(2.77,1.82,5.16),"N 5104",1.06,.32,0,"green")
	# Through the open door the kitchen table is still set for supper.
	b(1.14,.84,2.94,2.2,.12,1.0,"wood")
	for xx: float in [.22,2.06]:
		for zz: float in [2.57,3.31]:
			b(xx,.40,zz,.10,.80,.10,"wood")
	for xx: float in [.56,1.72]:
		cyl(xx,.922,3.10,.42,.045,"cream")
		cyl(xx,.956,3.10,.26,.042,"brick")
		cyl(xx+.25,.985,2.76,.15,.17,"white")
		b(xx-.28,.92,3.10,.025,.013,.23,"silver")
		b(xx,.48,2.15,.56,.11,.50,"wood")
		b(xx,.83,1.94,.55,.74,.09,"wood")
	cyl(1.15,1.00,2.78,.34,.20,"silver")
	b(1.15,1.123,2.78,.12,.05,.045,"dark")
	window(Vector3(-4.31,1.98,-2.35),1.39,1.32,-PI*.5)
	window(Vector3(-4.31,1.98,1.34),1.39,1.32,-PI*.5)
	var inside:=OmniLight3D.new()
	inside.position=p(1.0,2.8,2.0)
	inside.light_color=Color("#ffcd94")
	inside.light_energy=2.4
	inside.omni_range=6.7
	inside.distance_fade_enabled=true
	inside.distance_fade_begin=25
	inside.distance_fade_length=12
	draw.parent.add_child(inside)
	var ring: Vector3 = world.story_point("farm_ring")
	bare_ring(ring,3.18)

func survey_tripod() -> void:
	origin = world.hold_tripod_point()
	for leg in 3:
		var angle := leg*TAU/3.
		var foot := Vector3(cos(angle)*.74,0,sin(angle)*.74)
		beam(foot,Vector3(foot.x*.14,1.65,foot.z*.14),.088,.085,"wood")
		beam(foot*.6+Vector3.UP*.65,Vector3(foot.x*.1,1.65,foot.z*.1),.1,.1,"post")
	cyl(0,1.64,0,.43,.13,"post")
	b(0,1.89,0,.38,.44,.33,"green")
	b(0,2.08,0,.49,.12,.43,"snow")
	b(0,1.92,-.22,.22,.18,.28,"black")

func build() -> void:
	yard()
	storage_pad()
	esker()
	river_and_seat()
	rural_grid()
	road_furniture()
	kolpack_farm()
