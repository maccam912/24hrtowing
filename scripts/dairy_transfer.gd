extends "res://scripts/county_sites.gd"

const CENTER := Vector3(111,0,413)
const BAY := Rect2(100,409,22,8)
const APRON := Rect2(98,401,46,16)
const DROP := {"center":CENTER,"sign":"BRZEZINSKI MILK TRANSFER","radio":"milk_dir",
	"approach":"Use the concrete pad along the north side of the milk house. Stop the milk truck inside the white stripes."}

func build() -> void:
	site(CENTER.x,CENTER.z)
	b(7,-.04,-2,36,.14,12,"pavement")
	for z:float in [-4.,4.]:
		for x in range(-10,11,4):
			b(x,.04,z,2.8,.04,.14,"cream")
	site(112,424)
	b(0,1.55,0,8.4,3.1,5.8,"siding",true)
	roof(0,3.13,0,8.55,1.48,6.0)
	b(-2.55,1.04,-2.94,1.02,2.08,.12,"cream")
	window(Vector3(.76,1.77,-2.97),1.78,.76,PI)
	placard(Vector3(0,2.64,-3.0),"MILK HOUSE   •   TRANSFER",6.2,.49,PI,"green")
	# The relief hauler draws the sealed milk through the outside transfer cabinet.
	b(1.40,.73,-3.27,1.62,1.46,.69,"silver",true)
	for loop in 3:
		var center := Vector3(1.75,.91,-3.65-loop*.062)
		for i in 14:
			var from := center+Vector3(cos(TAU*i/14.)*.37,sin(TAU*i/14.)*.37,0)
			var to := center+Vector3(cos(TAU*(i+1)/14.)*.37,sin(TAU*(i+1)/14.)*.37,0)
			beam(from,to,.065,.065,"black")
	lamp(-3.65,4.7,-3.8)

func build_guide() -> void:
	for x:float in [-11.,11.]:
		for z:float in [-4.,4.]:
			cyl(x,.43,z,.14,.86,"safety_yellow")
			cyl(x,.92,z,.22,.16,"amber_lens")
			for yaw:float in [0.,PI*.5]:
				draw.add("quad",p(x,.94,z),Vector3(1.65,1.65,1),"sodium",Vector3(0,yaw,0))
