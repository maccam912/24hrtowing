extends "res://scripts/county_sites.gd"

const East := preload("res://scripts/tamarack_highway.gd")
const Fault := preload("res://scripts/damaged_axle.gd")
const CENTER := Vector3(East.SHOP_X+32,0,19.6)
const APRON := Rect2(CENTER.x-8.4,CENTER.z-5.2,16.8,10.4)
const DROP := {"center":CENTER,"sign":"REPAIR 03","approach":"Take Highway 64 east, three miles past County FF. Back into the striped REPAIR 03 pad outside the highway garage."}
const SITES := [
	{"road":"Highway 64","site":"cedar_creek","landmark":"Cedar Creek culvert","point":Vector3(1360,0,-5.1),"angle":-1.48,
	 "directions":"Go east on sixty-four past County FF. Cross the Cedar Creek culvert. Look on the north shoulder, beyond the guardrail."},
	{"road":"County FF","site":"ff_county","landmark":"Tamarack turn","point":Vector3(805.1,0,61),"angle":.12,
	 "directions":"East on sixty-four from Esker. Turn south on County FF. The car is on the east shoulder near the turn."},
]
static func ticket(issued: int,seed_value: int,prior: int) -> Dictionary:
	var index := posmod(seed_value+prior,2)
	var site: Dictionary = SITES[index]
	var number := 1001+issued
	var variant := 2 if index==0 else 3
	var vehicle := "County pool wagon" if index==0 else "County pool sedan"
	var fault: String = Fault.REAR_AXLE if index==0 else Fault.FRONT_BRAKE
	return {"id":"pool_repair","kind":"hazard","route":site.site,"site":site.site,"number":number,"point":site.point,
		"angle":site.angle,"variant":variant,"driver_variant":0,"road":site.road,"location":site.road+" · "+site.landmark,
		"vehicle":vehicle,"plate":"TCM %03d" % posmod(number+129,1000),"vin":"2G4WS52M4T9%06d" % posmod(seed_value+number*779,1000000),
		"wheel_fault":fault,"wheel_side":1 if posmod(seed_value+prior*3,4)>=2 else -1,"schedule":snappedf((site.point.x+absf(site.point.z))/400.,.1),
		"dispatch":"%s by the %s on %s. One tire dragged a stripe through the snow. Have a look before you tow it. County shop wants it at door three." % [vehicle,site.landmark,site.road],
		"directions":site.directions,"haul_line":"Bring that pool car to REPAIR 03, beside the county highway garage. Stay on sixty-four east past the creek."}

func build() -> void:
	site(CENTER.x,CENTER.z)
	for x:float in [-8.,8.]:
		b(x,.065,0,.11,.025,9.7,"stripe")
		for z:float in [-4.8,4.8]: b(x-signf(x)*.62,.065,z,1.3,.025,.1,"stripe")
	for post: float in [-8.65,-6.55]:
		b(post,1.20,5.83,.10,2.4,.11,"post",true)
	placard(Vector3(-7.6,2.14,5.65),"REPAIR 03",3.0,.72,PI,"green",true)
	placard(Vector3(-7.6,1.56,5.65),"MOTOR POOL",2.09,.32,PI,"blue_sign",true)
	b(-5.11,.54,6.17,.74,1.08,.49,"oxide",true)
	b(-5.11,1.14,6.17,.80,.15,.53,"dark")
	placard(Vector3(-5.11,.78,5.90),"KEY DROP",.71,.22,PI,"cream")

static func fits(car: Node3D, pose: Transform3D, margin := .18) -> bool:
	var size: Vector3 = car.get_meta("body_size")
	for x:float in [-size.x,size.x]:
		for z:float in [-size.z,size.z]:
			var at := pose*Vector3(x,0,z)
			if not APRON.grow(-margin).has_point(Vector2(at.x,at.z)): return false
	return true
