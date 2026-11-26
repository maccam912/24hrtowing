extends "res://scripts/county_sites.gd"

# A pull-through beside the diner. A full rig can enter from either end of 59.
const LOT := Rect2(-611,5,63,94)
const BAY := Rect2(-601,34,10,37)
const CENTER := Vector3(-596,0,52.5)
const DROP := {"center":CENTER,"sign":"RIVER LANES RECEIVING","radio":"freight_dir",
	"approach":"Pull through the amber lane beside the diner until tractor and trailer are between the end posts."}
const NORTH_SITE := Vector3(-600.2,0,-151)
const SOUTH_SITE := Vector3(-600.2,0,240)

func build() -> void:
	site(CENTER.x,CENTER.z)
	# Marks survive between jobs. The amber beacons come on for an inbound tow.
	for x:float in [-5.0,5.0]:
		for z in range(-16,17,4):
			b(x,.032,z,.18,.045,2.8,"safety_yellow")
	site(-582,55)
	placard(Vector3(0,3.48,0),"RIVER LANES",9.2,1.27,-PI*.5,"green",true)
	placard(Vector3(0,2.25,0),"TRUCK RECEIVING",8.3,.91,-PI*.5,"black",true)
	for z:float in [-3.55,3.55]:
		b(0,1.84,z,.15,3.7,.15,"post")
	lamp(3.8,6.5,7.7)
	site(-573,78)
	b(0,1.52,0,7.2,3.04,5.1,"siding",true)
	b(0,3.18,0,7.5,.29,5.33,"snow")
	placard(Vector3(-3.66,2.3,0),"NIGHT SERVICE",3.67,.54,-PI*.5,"black")
	b(-3.64,.92,1.22,.10,1.84,1.12,"cream")
	window(Vector3(-3.65,1.62,-.76),1.50,.94,-PI*.5)
	for scene: Array in [[NORTH_SITE,"NORTH TURNOUT"],[SOUTH_SITE,"SOUTH TURNOUT"]]:
		var point: Vector3 = scene[0]
		site(point.x+12,point.z-23)
		placard(Vector3(0,1.80,0),scene[1],4.3,.70,0,"green",true)
		b(0,.90,0,.14,1.80,.14,"wood")

func build_guide() -> void:
	for x:float in [-5.,5.]:
		for z:float in [-18.5,18.5]:
			b(x,.12,z,.61,.24,.61,"black")
			cyl(x,.80,z,.20,1.42,"safety_yellow")
			cyl(x,1.61,z,.33,.32,"amber_lens")
			for yaw:float in [0.,PI*.5]:
				draw.add("quad",p(x,1.63,z),Vector3(3.,3.,1),"sodium",Vector3(0,yaw,0))
