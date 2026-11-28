extends "res://scripts/county_sites.gd"
## The passenger loop is off Highway 64, just west of the county offices.
const LOT := Rect2(822,4,62,43)
const DROP := Rect2(829,14,48,10)
const CURB := Vector3(852,0,19)
const DOOR := Vector3(853,0,27)

func build() -> void:
	site(853,26)
	# Two low patient wings with an inset, lit night entrance between them.
	b(-12,3.13,9,19.7,6.26,13,"brick",true)
	b(11.5,3.13,9,18.7,6.26,13,"brick",true)
	b(0,3.12,13.4,5.4,6.24,4.2,"brick",true)
	for wing: float in [-11.98,11.48]:
		var width := 20.4 if wing < 0 else 19.4
		b(wing,6.32,9,width,.28,13.8,"snow")
		b(wing,5.84,2.45,width-.4,.38,.20,"cream")
		for i in 5:
			var x := wing-6.8+i*3.4
			window(Vector3(x,3.64,2.43),2.4,1.59,PI,i%3 != 2)
	b(-16,7.05,9.7,4.6,1.35,2.8,"silver")
	b(-16,7.80,9.7,4.82,.14,3.04,"snow")
	b(0,4.12,1.4,13.5,.61,7.1,"green")
	b(0,4.51,1.4,13.8,.21,7.4,"snow")
	placard(Vector3(0,4.10,-2.24),"NIGHT ENTRANCE",8.4,.62,PI,"green")
	for x: float in [-5.88,5.88]:
		# Bollards mark the sidewalk. The signed passenger lane stays open.
		cyl(x,1.88,-1.67,.26,3.76,"cream",true)
		for z: float in [-2.22,.82]:
			cyl(x,.42,z,.27,.84,"brass",true)
	b(0,2.0,2.7,4.7,4.0,.20,"dark")
	# Open vestibule doors frame a second, warm set back into the building.
	for side: float in [-1,1]:
		b(side*1.61,1.39,.97,.88,2.78,.10,"silver",true)
		b(side*1.61,1.55,.90,.76,2.08,.06,"window")
		b(side*1.61,1.06,.845,.84,.08,.07,"silver")
		b(side*1.61,.30,.885,.88,.47,.07,"silver")
		b(side*1.12,1.42,.99,.06,2.84,.12,"cream")
		b(side*.64,1.48,2.54,1.22,2.75,.07,"window")
		b(side*.64,1.15,2.47,1.24,.075,.06,"silver")
	b(0,2.95,1.02,4.55,.18,.20,"cream")
	b(0,3.73,.06,3.1,.1,.30,"fluoro")
	placard(Vector3(-11.9,5.13,2.31),"TAMARACK MEMORIAL",17.6,1.17,PI,"green")
	b(0,.045,-1.45,18.8,.09,4.4,"cream")
	b(0,.095,-3.53,19.1,.09,.20,"brass")
	for i in 7:
		b(-1.97+i*.66,.014,-6.0,.24,.026,3.85,"slush")
	# Twin entrances leave room for the wrecker to pull through in either direction.
	for i: int in range(-10,11,2):
		b(i,.14,-14.7,2.0,.28,.45,"slush")
	for x: float in [-8.5,-5.,4.,8.]:
		draw.add("mound",p(x,.1,-14.48),Vector3(4.4,.82,2.08),"snow")
	for x: float in [-19,18.6]:
		lamp(x,-1.4,5.1)
	# The H faces the highway in both directions.
	site(829,7.7)
	b(0,1.61,0,.25,3.22,.24,"post",true)
	b(0,4.54,0,.24,2.81,2.98,"blue_sign")
	for side: float in [-1,1]:
		label(Vector3(side*.13,4.6,0),"H",2.36,side*PI*.5,Color("#f5f1db"))
	site(839,15)
	b(0,.80,0,.10,1.60,.11,"post")
	placard(Vector3(0,1.61,0),"PATIENT DROP-OFF",3.5,.51,PI,"green",true)
