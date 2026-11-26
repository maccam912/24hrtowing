extends "res://scripts/county_sites.gd"
## The Main Street run from the closed cheese works to the volunteer hall.
const HALL := Vector2(105,26)
const APRON := Rect2(91,4,33,23)
const TANKER_X := 108.4
const CHEESE_YARD := Rect2(-181,-39,37,33)
const ZION_YARD := Rect2(-36,60,26,37)

func build() -> void:
	_tap_blade()
	_cheese_factory()
	_zion()
	_fire_hall()

func _tap_blade() -> void:
	site(-30,14)
	# These bent neon tubes are wide enough to see through the low-resolution windshield.
	b(-4.52,4.53,.04,.14,.14,4.56,"dark")
	b(-4.52,3.43,-.28,.24,2.19,3.78,"black")
	var letters := [
		[Vector2(-1.55,.58),Vector2(-.61,.58)], [Vector2(-1.08,.58),Vector2(-1.08,-.54)],
		[Vector2(-.47,-.54),Vector2(-.11,.58),Vector2(.13,.58),Vector2(.45,-.54)],
		[Vector2(-.30,-.08),Vector2(.29,-.08)],
		[Vector2(.71,-.54),Vector2(.71,.58),Vector2(1.33,.58),Vector2(1.51,.40),Vector2(1.51,.04),Vector2(1.33,-.12),Vector2(.71,-.12)]
	]
	for side: float in [-1,1]:
		var face := Vector3(-4.52+side*.15,3.55,-.28)
		for line: Array in letters:
			for i in range(1,line.size()):
				var start: Vector2 = line[i-1]
				var end: Vector2 = line[i]
				beam(face+Vector3(0,start.y,-side*start.x),face+Vector3(0,end.y,-side*end.x),.142,.142,"amber_lens")
		label(face+Vector3(0,-.86,0),"ESKER",.39,side*PI*.5,Color("#ffcf9b"))
	# A little of the sign's light reaches the brackets and brickwork.
	var spill := OmniLight3D.new()
	spill.position = p(-4.52,3.7,.14)
	spill.light_color = Color("#ffa458")
	spill.light_energy = .85
	spill.omni_range = 4.8
	spill.distance_fade_enabled = true
	spill.distance_fade_begin = 22.
	spill.distance_fade_length = 10.
	draw.parent.add_child(spill)
	placard(Vector3(0,1.67,2.29),"CLOSED",.78,.26,PI,"black")

func _painted_board(at: Vector3, words: String, width: float, height: float, yaw: float, both := false) -> void:
	draw.box(origin+at,Vector3(width,height,.10),"cream",false,Vector3(0,yaw,0))
	var front := Basis(Vector3.UP,yaw)*Vector3.BACK
	var size := minf(height*.81,width/words.length()*1.75)
	label(at+front*.06,words,size,yaw,Color("#4a4036"))
	if both: label(at-front*.06,words,size,yaw+PI,Color("#4a4036"))

func _cheese_factory() -> void:
	site(-164,-20)
	# The receiving platform still has its overhead can rail and scale.
	b(-3,2.93,-2,22.5,5.86,17,"brick",true)
	b(-3,5.98,-2,22.90,.26,17.5,"snow")
	b(-3,5.69,6.58,22.63,.37,.20,"cream")
	b(9.15,2.36,0,2.05,4.72,11,"silver",true)
	_painted_board(Vector3(-3,4.84,6.62),"ESKER CHEESE FACTORY",17,1.09,0.0)
	# A tall square boiler chimney and the twin receiving vents stand above the block.
	b(-11.2,6.76,-7.42,2.22,13.52,2.22,"brick",true)
	b(-11.2,13.58,-7.42,2.50,.30,2.49,"dark")
	b(-11.2,13.81,-7.42,2.05,.15,2.08,"snow")
	for x: float in [-.7,2.4]:
		cyl(x,6.73,-5.8,.66,1.66,"silver")
		draw.add("cone",p(x,7.61,-5.8),Vector3(1.08,.61,1.08),"dark")
	for x: float in [-11,-7.8,-4.6]:
		window(Vector3(x,2.59,6.59),2.0,1.56,0,false)
		for y: float in [2.19,2.89]:
			b(x,y,6.75,2.23,.23,.07,"wood")
	b(1.75,2.44,6.59,5.86,3.85,.16,"silver")
	for i in 7:
		b(1.75,.76+i*.47,6.70,5.73,.04,.05,"dark")
	b(1.75,.48,8.15,8.90,.95,3.03,"slush",true)
	for x: float in [-2.31,5.78]:
		b(x,2.35,9.43,.16,3.72,.16,"wood")
	b(1.75,4.25,8.29,9.28,.23,3.29,"dark")
	b(1.75,4.42,8.29,9.45,.12,3.50,"snow")
	b(-.9,3.81,8.67,.11,.19,3.10,"post")
	for z:float in [8.39,9.14]:
		cyl(-.9,3.49,z,.042,.62,"dark")
	b(1.9,1.01,8.73,1.44,.14,.96,"post")
	placard(Vector3(1.75,2.62,6.79),"RECEIVING CLOSED",3.83,.58,0,"black")
	site(-147.3,-8.0)
	b(0,1.56,0,.16,3.12,.17,"wood")
	placard(Vector3(0,2.92,0),"CHEESE",3.69,.89,PI*.5,"oxide",true)
	_painted_board(Vector3(0,2.18,0),"PLANT CLOSED",3.69,.57,PI*.5,true)

func _zion() -> void:
	site(-24,73)
	b(-.8,2.72,3.1,10.0,5.44,17.8,"cream",true)
	roof(-.8,5.44,3.1,10.36,3.24,18.07,"snow")
	b(3.35,3.72,-4.29,3.64,7.44,3.94,"cream",true)
	b(3.35,7.56,-4.29,3.97,.26,4.20,"dark")
	for x: float in [2.13,4.57]:
		for z: float in [-5.73,-2.85]: b(x,8.54,z,.2,1.90,.2,"cream")
	cyl(3.35,8.64,-4.29,.91,.69,"dark")
	draw.add("cone",p(3.35,10.41,-4.29),Vector3(4.76,2.24,4.76),"dark")
	b(3.35,11.99,-4.29,.085,1.30,.085,"post")
	b(3.35,12.25,-4.29,.58,.083,.085,"post")
	for z: float in [.8,4.3,7.8]:
		window(Vector3(4.24,2.82,z),1.25,2.29,PI*.5,z!=4.3)
	b(-1.09,1.5,-5.89,2.08,3,.16,"oxide")
	b(-1.09,3.32,-6.89,4.6,.27,2.34,"dark")
	for x: float in [-2.96,.78]: b(x,1.64,-7.83,.18,3.28,.18,"cream")
	b(-1.09,.14,-7.23,4.6,.28,2.96,"slush")
	site(-8.46,68.0)
	for z: float in [-1.14,1.14]: b(0,1.17,z,.18,2.34,.18,"wood")
	placard(Vector3(0,2.16,0),"ZION",2.82,.83,PI*.5,"green",true)
	placard(Vector3(0,1.47,0),"LUTHERAN",2.82,.56,PI*.5,"green",true)

func _fire_hall() -> void:
	site(HALL.x,HALL.y)
	# Two appliance bays on Main and a narrow hose-drying tower out back.
	b(.75,3.50,13.90,23.0,7,.28,"siding",true)
	for x: float in [-10.61,12.12]: b(x,3.50,6.95,.28,7,14.2,"brick",true)
	b(.75,6.24,0,23.0,1.55,.32,"oxide",true)
	b(.75,7.09,6.96,23.42,.29,14.70,"snow")
	b(-.69,2.79,0,1.12,5.58,.34,"brick",true)
	b(8.35,2.79,0,1.29,5.58,.34,"brick",true)
	b(10.24,2.79,0,2.39,5.58,.34,"brick",true)
	b(-9.64,2.79,0,2.14,5.58,.34,"brick",true)
	b(-4.66,2.68,-.035,7.21,5.36,.2,"oxide",true)
	for i in 9: b(-4.67,.31+i*.56,-.154,7.05,.044,.07,"dark")
	for x: float in [-6.96,-5.44,-3.91,-2.39]: b(x,3.59,-.16,1.22,.73,.061,"glass")
	placard(Vector3(.35,6.25,-.20),"ESKER VOLUNTEER FIRE DEPT.",20.60,1.12,PI,"oxide")
	b(10.28,1.39,-.21,1.32,2.78,.07,"dark")
	b(10.28,1.80,-.27,.91,.96,.07,"window")
	b(10.28,3.08,-.67,2.24,.24,1.48,"cream")
	b(10.28,3.04,-1.15,.29,.09,.16,"fluoro")
	b(-7.43,8.42,11.53,5.16,16.84,4.58,"brick",true)
	b(-7.43,16.93,11.53,5.56,.34,4.91,"cream")
	for face: float in [-1,1]:
		b(-7.43,14.58,11.53+face*2.31,2.7,2.18,.10,"dark")
		for slat in 5: b(-7.43,13.73+slat*.41,11.53+face*2.40,2.82,.15,.09,"silver")
	placard(Vector3(-7.43,11.68,9.17),"E.F.D.",3.53,1.01,PI,"oxide")
	# The sign projects toward Main. The big white letters face traffic on both approaches.
	site(95.5,8.5)
	for z: float in [-1.55,1.55]: b(0,1.93,z,.17,3.86,.17,"post")
	for side: float in [-1,1]:
		placard(Vector3(side*.08,3.20,0),"FIRE",3.76,1.24,side*PI*.5,"oxide")
		_painted_board(Vector3(side*.08,2.14,0),"ESKER  •  VOL.",3.76,.74,side*PI*.5)
	site(HALL.x,HALL.y)
	lamp(12,-2.7,5.8,true)
	b(3.42,5.47,10.70,3.41,.11,.47,"fluoro")
