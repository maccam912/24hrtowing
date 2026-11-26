extends "res://scripts/county_sites.gd"
## Esker's night counter opens onto the same forecourt as the two diesel pumps.
const Door = preload("res://scripts/fuel_store_door.gd")
const FORECOURT := Vector3(-71,0,18)
const ROOM := Rect2(-8.15,4.25,6.55,7.5)
const COUNTER := Vector3(-5,1.05,9.05)
const PRICE_SIGN := "COFFEE  75¢"

static func inside(point: Vector3) -> bool:
	var local := point - FORECOURT
	return local.y >= -.3 and local.y < 3.9 and ROOM.has_point(Vector2(local.x,local.z))

func build() -> void:
	origin = FORECOURT
	_store()
	_pumps()

func _store() -> void:
	# Solid retail wings leave a short, level walk to the counter between them.
	b(-10.575,2.10,8.0,4.85,4.2,7.50,"brick",true)
	b(1.70,2.10,8.0,6.60,4.2,7.50,"brick",true)
	b(-4.87,1.98,11.65,6.6,3.96,.20,"cream",true)
	b(-4.87,3.99,8.0,6.6,.18,7.5,"cream")
	b(-4,4.25,8.0,18.5,.24,8.0,"snow")
	b(-4.87,3.47,4.35,6.58,1.52,.21,"brick",true)
	b(-7.47,1.36,4.35,1.37,2.72,.20,"green",true)
	b(-2.56,1.36,4.35,1.92,2.72,.20,"green",true)
	for jamb: float in [-6.78,-3.52]:
		b(jamb,1.36,4.24,.12,2.72,.19,"cream",true)
	b(-5.15,2.71,4.24,3.38,.11,.19,"cream")
	_entry()
	b(-4.87,.019,8.0,6.56,.038,7.50,"cream")
	for i in 10:
		b(-8.12+i*.72,.041,8.0,.014,.004,7.5,"post")
	for i in 11:
		b(-4.87,.041,4.33+i*.72,6.55,.004,.014,"post")
	b(-5.15,.050,5.32,2.25,.028,1.72,"dark")
	for groove in 10:
		b(-6.15+groove*.22,.069,5.32,.019,.008,1.60,"post")
	for x: float in [-10.5,.03,3.23]:
		window(Vector3(x,2.12,4.18),2.60,1.65,PI,true)
	placard(Vector3(-4,3.77,4.09),"ESKER  FUEL & FOOD",14.3,1.01,PI,"oxide")
	placard(Vector3(-2.57,1.78,4.21),"OPEN",1.25,.47,PI,"oxide")
	placard(Vector3(-10.5,1.89,4.00),"HOT COFFEE",2.42,.47,PI,"black")
	for x: float in [-10.55,1.70]:
		var width := 4.85 if x < 0. else 6.60
		b(x,.98,4.19,width,.13,.14,"cream")
		b(x,.82,4.19,width,.065,.14,"green")
		b(x,.11,4.12,width,.18,.35,"slush")
	b(-4.87,1.29,11.53,6.55,.10,.05,"green")
	b(-4.87,1.20,11.53,6.55,.04,.05,"oxide")
	# A night clerk can see the forecourt directly from the register.
	b(-4.86,.52,9.44,6.55,1.04,.86,"wood",true)
	b(-4.86,1.055,9.44,6.55,.08,.99,"cream")
	b(-4.86,.85,8.99,6.55,.09,.045,"green")
	b(-4.86,.14,8.99,6.55,.18,.05,"dark")
	placard(Vector3(-5.00,.67,8.97),PRICE_SIGN,1.84,.35,PI,"green")
	_coffee_service()
	_register()
	_cooler()
	var mai := preload("res://assets/characters/night_clerk.glb").instantiate() as Node3D
	mai.name = "MaiXiong"
	draw.parent.add_child(mai)
	mai.position = p(-4.98,.04,10.0)
	var animation: AnimationPlayer = mai.get_node("AnimationPlayer")
	animation.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	animation.play("idle")
	b(-4.85,3.76,7.72,3.3,.14,.44,"dark")
	for z: float in [7.60,7.84]:
		b(-4.85,3.66,z,3.15,.060,.085,"fluoro")
	var light := OmniLight3D.new()
	light.position = p(-4.86,2.95,7.25)
	light.light_color = Color("#ffe4b7")
	light.light_energy = 1.8
	light.omni_range = 7.4
	light.omni_attenuation = 1.2
	light.distance_fade_enabled = true
	light.distance_fade_begin = 32
	light.distance_fade_length = 12
	draw.parent.add_child(light)

func _entry() -> void:
	# Fixed side panes narrow the truck opening but leave a wide level walk.
	for side: float in [-1.0,1.0]:
		var x := -5.15 + side*1.245
		b(x,1.35,4.26,.69,2.7,.065,"shop_glass",true)
		b(x,.20,4.26,.69,.40,.08,"silver")
		b(x,1.02,4.26,.69,.072,.08,"silver")
		b(-5.15 + side*.92,1.31,4.25,.055,2.62,.09,"silver")
	b(-5.15,2.55,4.24,3.22,.24,.18,"silver")
	b(-5.15,2.64,4.12,.20,.10,.10,"black")
	var door := Door.new()
	draw.parent.add_child(door)
	door.position = p(-5.15,0,4.36)
	door.fit(world.materials)
	world.fuel_door = door

func _coffee_service() -> void:
	# The orange decaf lever matches Mai's advice at the counter.
	for x: float in [-6.76,-6.24]:
		b(x,1.14,9.36,.39,.07,.54,"black")
		cyl(x,1.43,9.47,.27,.54,"silver")
		cyl(x,1.69,9.47,.28,.08,"black")
		beam(Vector3(x,1.64,9.44),Vector3(x,1.60,9.25),.07,.06,"dark")
		b(x,1.59,9.25,.065,.10,.075,"dark")
		b(x,1.74,9.42,.15,.06,.24,"decaf" if x == -6.76 else "dark")
	for n in 3:
		cyl(-5.76,1.20+n*.075,9.39,.16,.19,"white")
		cyl(-5.76,1.29+n*.075,9.39,.167,.014,"cream")
	# The wall menu hangs on its own clips above the coffee service.
	placard(Vector3(-6.60,2.24,11.50),"REGULAR  /  DECAF",2.87,.46,PI,"green")
	for x: float in [-7.72,-5.48]:
		b(x,2.50,11.52,.071,.15,.06,"silver")

func _register() -> void:
	b(-3.72,1.20,9.49,.66,.21,.53,"dark")
	b(-3.72,1.38,9.58,.55,.22,.30,"cream")
	b(-3.72,1.53,9.68,.35,.17,.08,"black")
	label(Vector3(-3.72,1.53,9.63),"0.75",.11,PI,Color("#b5d6aa"))
	for i in 4:
		for j in 3:
			b(-3.92+i*.085,1.32,9.26+j*.069,.06,.035,.048,"cream")
	# Mai's pencil tally lies beside the rolled register tape.
	b(-4.23,1.111,9.40,.21,.013,.43,"white")
	for j in 2:
		for i in 4:
			b(-4.28+i*.031,1.121,9.33+j*.11,.008,.006,.064,"black")
		draw.box(p(-4.232,1.125,9.33+j*.11),Vector3(.14,.006,.009),"black",false,Vector3(0,.26,0))

func _cooler() -> void:
	# The cold case and its milk cartons close the wall behind the till.
	b(-2.83,1.29,11.30,2.15,2.51,.56,"dark")
	for x: float in [-3.33,-2.33]:
		b(x,1.24,10.98,.88,1.94,.08,"glass")
		for level: float in [.58,1.09,1.60]:
			b(x,level,10.90,.86,.035,.10,"cream")
			for n in 3:
				b(x-.24+n*.24,level+.14,10.93,.13,.23,.08,"white")
				b(x-.24+n*.24,level+.21,10.88,.14,.05,.018,"green")
		b(x+.36,1.24,10.89,.035,.32,.06,"silver")
	placard(Vector3(-2.83,2.39,10.95),"DAIRY",1.88,.23,PI,"green")

func _pumps() -> void:
	b(0,4.20,-2,11,.47,6.8,"oxide")
	b(0,4.49,-2,11.19,.14,6.95,"snow")
	for xx: float in [-3.7,3.7]:
		b(xx,2.15,-2,.19,4.3,.2,"silver",true)
		b(xx,.12,-2,2.1,.24,1.02,"cream")
		b(xx,1.03,-2,1.07,1.85,.6,"oxide",true)
		b(xx,1.43,-2,1.12,.89,.68,"cream")
		b(xx,1.54,-2.36,.8,.34,.05,"glass")
		label(Vector3(xx,1.55,-2.39),"0.00",.18,PI,Color("#dbe2ca"))
		label(Vector3(xx,1.22,-2.36),"DIESEL",.125,PI,Color("#282b28"))
		beam(Vector3(xx+.48,1.54,-2.1),Vector3(xx+.80,1.17,-2.1),.050,.05,"black")
		beam(Vector3(xx+.80,1.17,-2.1),Vector3(xx+.85,.49,-2.1),.05,.05,"black")
		beam(Vector3(xx+.85,.49,-2.1),Vector3(xx+.75,.32,-2.1),.05,.05,"black")
		beam(Vector3(xx+.75,.32,-2.1),Vector3(xx+.63,.40,-2.1),.05,.05,"black")
		b(xx+.68,.91,-2.07,.09,1.1,.1,"black")
		b(xx,3.88,-2,1.3,.12,.3,"fluoro")
	beam(Vector3(2.4,1.40,-2),Vector3(2.4,.34,-2),.10,.10,"black")
	b(-12.8,2.0,-8.4,.29,4.0,.29,"silver")
	# The pole sign faces east and west along Highway 64.
	b(-12.8,5.18,-8.4,.32,2.64,4.72,"oxide")
	b(-12.8,5.52,-8.4,.34,1.55,4.47,"window")
	for side: float in [-1.0,1.0]:
		var yaw := side*PI*.5
		var face := -12.8+side*.18
		label(Vector3(face,5.55,-8.40),"FUEL",1.46,yaw,Color("#432c21"))
		label(Vector3(face,4.34,-8.40),"OPEN 24 HR",.52,yaw,Color("#ffe5bb"))
	lamp(-6.5,-5,4.1)
