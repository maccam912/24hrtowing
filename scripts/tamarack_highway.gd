extends "res://scripts/county_sites.gd"
## Highway 64 east of County FF. One mile on the county plat is 400 metres.
const COUNTY_FF := 800
const SHOP_X := 2000
const CLOSURE_X := 2130
const LOT := Rect2(SHOP_X-31,4,78,57)
const DROP := Rect2(SHOP_X-15,15,36,13)
const CURB := Vector3(SHOP_X+3,0,22)
const DOOR := Vector3(SHOP_X+3,0,32)
const EAST_FIELD := Rect2(1050,-205,1130,410)
const OLD_FIELDS := Rect2(-775,-580,1925,1550)

static func boundary_distance(point: Vector3) -> float:
	var flat := Vector2(point.x,point.z)
	var mainland := flat.clamp(OLD_FIELDS.position,OLD_FIELDS.end)
	var corridor := flat.clamp(EAST_FIELD.position,EAST_FIELD.end)
	return minf(flat.distance_squared_to(mainland),flat.distance_squared_to(corridor))

func build() -> void:
	_roadside_sign(824,9,"COUNTY HIGHWAY SHOP","3 MILES EAST",false)
	_roadside_sign(1597,8,"COUNTY HIGHWAY SHOP","1 MILE EAST",false)
	_roadside_sign(1971,8,"COUNTY SERVICE CENTER","ENTER  →",false)
	_roadside_sign(2019,-8,"ESKER  5","COUNTY FF  3",true)
	_creek()
	_windbreaks()
	_shop()

func _roadside_sign(x: float, z: float, first: String, second: String, westbound: bool) -> void:
	site(x,z,world.ground_height(x,z))
	var yaw := PI*.5 if westbound else -PI*.5
	for edge: float in [-1.95,1.95]:
		b(0,1.65,edge,.15,3.30,.15,"wood")
	placard(Vector3(0,2.98,0),first,5.64,.67,yaw)
	placard(Vector3(0,2.38,0),second,5.64,.57,yaw)

func _creek() -> void:
	var x := 1325.
	site(x,0)
	for side: float in [-1,1]:
		# A buried culvert keeps the road level while its headwalls show in the ditch.
		for i in 9:
			b(-12+i*3,.42,side*5.82,.15,.84,.18,"post",true)
		b(0,.76,side*5.84,25,.28,.13,"silver",true)
		b(0,-.04,side*7.0,3.9,.85,.32,"slush")
		for i in 6:
			var z := side*(9+i*4.5)
			var xx := sin(i*.75+side)*1.3
			draw.box(p(xx,world.ground_height(x+xx,z)+.045,z),Vector3(2.8,.07,5.0),"river",false,Vector3(0,sin(i*.8)*.15,0))
	_roadside_sign(x-24,7.6,"CEDAR CREEK","CULVERT 64–18",false)
	_roadside_sign(x+24,-7.6,"CEDAR CREEK","CULVERT 64–18",true)

func _windbreaks() -> void:
	rng.seed = 641988
	for grove: Array in [[1042,-37,12],[1140,30,17],[1270,-42,15],[1436,38,17],[1550,-52,18],[1686,41,14],[1812,-47,19],[2072,68,13]]:
		for i in int(grove[2]):
			var x := float(grove[0])+i*3.6+rng.randf_range(-2.8,2.8)
			var z := float(grove[1])+rng.randf_range(-7,7)
			draw.spruce(Vector3(x,world.ground_height(x,z),z),rng.randf_range(5.8,12.0),rng.randf()*TAU)
	for run: Array in [[965,24,18],[1435,-28,19],[1705,-26,24]]:
		var last := Vector3.ZERO
		for i in int(run[2]):
			var x := float(run[0])+i*4.2
			var z := float(run[1])+sin(i*.2)*.55
			var base := Vector3(x,world.ground_height(x,z),z)
			draw.box(base+Vector3.UP*.61,Vector3(.13,1.22,.13),"wood")
			if i:
				draw.beam(last+Vector3.UP*.75,base+Vector3.UP*.75,.024,.024,"silver")
			last = base

func _shop() -> void:
	site(SHOP_X,0)
	# A pull-through apron leaves both ends open for long rigs and plow wings.
	for x: float in [-23,35]:
		lamp(x,26,6.5)
	for x: float in [-17,-9,0,9,18,26]:
		b(x,.13,8,6,.26,.48,"slush")
		draw.add("mound",p(x,.18,8),Vector3(7,1.1,1.5),"snow")
	# The middle door is up. The grader's blade and tandem wheels stand in the light.
	for wall_x: float in [6.65,31.35]:
		b(wall_x,3.25,42,.28,6.5,20,"silver",true)
	b(19,3.25,51.9,25,6.5,.30,"silver",true)
	b(19,5.68,32.0,25,1.80,.28,"silver",true)
	b(19,6.58,42,25.6,.28,20.7,"snow")
	b(19,5.86,31.88,25.0,.46,.17,"decaf")
	for bay in 3:
		var x := 10.8+bay*8.
		placard(Vector3(x,5.22,31.70),"0%d"%(bay+1),1.48,.81,PI,"dark")
		if bay == 1:
			for side: float in [-1,1]:
				b(x+side*3.43,2.49,32.10,.52,4.98,.44,"post",true)
			b(x,4.60,34.0,5.88,.34,3.64,"cream")
			b(x,4.80,37.4,3.95,.12,.38,"fluoro")
			_grader(x)
			continue
		b(x,2.35,31.92,6.3,4.70,.22,"dark",true)
		b(x,2.25,31.73,5.93,4.50,.12,"cream")
		for slat in 7:
			b(x,.45+.55*slat,31.64,5.93,.055,.08,"silver")
		for pane in 4:
			b(x-2.1+pane*1.40,2.94,31.61,1.05,.50,.09,"glass")
	b(-8.9,1.98,38.1,16.2,3.96,12.2,"brick",true)
	b(-8.9,4.04,38.1,16.7,.27,12.9,"snow")
	b(3,1.99,39,7.1,3.98,11.6,"brick",true)
	for x: float in [-13.2,-8.7,-4.2]:
		window(Vector3(x,1.95,31.91),2.95,1.47,PI,x != -8.7)
	b(3,3.26,31.37,5.55,.34,3.67,"green")
	b(3,3.47,31.37,5.78,.15,3.87,"snow")
	# The public door is recessed behind the exterior threshold.
	for x: float in [1.69,4.31]:
		b(x,1.38,32.03,.72,2.76,.15,"silver",true)
		b(x,1.63,31.91,.58,1.78,.095,"window")
	b(3,1.38,33.09,2.1,2.76,.13,"window")
	b(3,1.17,32.99,2.1,.10,.09,"silver")
	b(3,.045,30.66,6.3,.09,3.1,"cream")
	placard(Vector3(3,3.28,29.47),"CREW DOOR",4.35,.48,PI)
	placard(Vector3(-8.8,3.30,31.82),"COUNTY HIGHWAY DEPT.",13.4,.85,PI,"blue_sign")
	# A ribbed round salt shed and its open dark loading mouth identify the yard from the road.
	site(SHOP_X-16,48)
	cyl(0,2.05,0,16.5,4.1,"silver",true)
	draw.add("cone",p(0,6.55,0),Vector3(18.3,5.4,18.3),"wood")
	draw.add("cone",p(0,7.23,0),Vector3(14.6,4.29,14.6),"snow")
	b(0,2.15,-7.93,7.2,4.3,.3,"dark")
	draw.add("mound",p(0,.18,-8.2),Vector3(5.6,2.34,3.55),"cream")
	site(SHOP_X+42,32)
	b(0,2.35,6,9.9,4.7,12,"brick",true)
	b(0,4.80,6,10.4,.28,12.6,"snow")
	placard(Vector3(0,3.75,-.14),"SHERIFF  /  RADIO",8.9,.83,PI,"blue_sign")
	window(Vector3(-2.05,2.0,-.10),3.02,1.47,PI)
	b(2.42,1.3,-.12,1.25,2.6,.18,"green")
	draw.beam(p(2.5,4.9,7),p(2.5,15.9,7),.16,.16,"silver")
	for i in 4:
		b(2.5,13.7+i*.54,7,1.2-i*.22,.07,.06,"silver")
	cyl(2.5,16.0,7,.18,.22,"red")


func _grader(x: float) -> void:
	var z := 33.2
	# Narrow front frame, angled moldboard, tandem rear and a high glazed cab.
	b(x,1.08,z+.65,.5,.43,6.15,"dark")
	b(x,1.78,z+2.30,1.62,.95,2.46,"brass",true)
	b(x,2.03,z+.51,1.60,.52,1.70,"brass",true)
	b(x,2.88,z+.51,1.40,1.23,1.45,"glass",true)
	b(x,3.57,z+.51,1.76,.18,1.82,"brass")
	b(x,3.69,z+.51,1.75,.07,1.79,"snow")
	for side: float in [-1,1]:
		b(x+side*.69,2.88,z-.23,.10,1.23,.09,"brass")
		for axle: float in [-3.42,1.55,3.11]:
			var center := p(x+side*.96,.72,z+axle)
			draw.add("cylinder",center,Vector3(1.43,.48,1.43),"black",Vector3(0,0,PI*.5))
			draw.add("cylinder",center+Vector3.RIGHT*side*.251,Vector3(.68,.07,.68),"brass",Vector3(0,0,PI*.5))
		b(x+side*.65,1.63,z-3.25,.30,.16,.09,"white")
	draw.solid_box(p(x,1.10,z+.2),Vector3(2.43,2.20,8.1))
	draw.beam(p(x,1.3,z+.05),p(x,1.82,z-2.50),.28,.37,"brass")
	draw.beam(p(x,1.82,z-2.50),p(x,1.06,z-3.49),.28,.35,"brass")
	draw.box(p(x,.34,z-1.07),Vector3(3.58,.62,.21),"silver",false,Vector3(.18,.28,0))
