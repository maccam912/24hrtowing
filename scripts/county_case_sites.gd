extends "res://scripts/county_sites.gd"
## Objects located by the county's later reports. Point heights are above the ground.
const ALDER_X := 441.0
const ALDER_END := -548.0
const HOUSE_YARD := Rect2(443,-482,31,21)
const TANK_PLATFORM := 35.5
const HOFFMANN_SEDAN := {"plate":"WLP 504","vin":"1BTAL52C8TJ510428"}
const ANGIE_PATH := [Vector2(462.5,-469.5),Vector2(455,-467),Vector2(ALDER_X+2,-467),Vector2(ALDER_X+2,-537)]
const POINTS := {
	"house": Vector3(446,1.22,331.2),
	"farm_ring": Vector3(427, .11, 330),
	"tower_ladder": Vector3(48.7, 1.1, -65.9),
	"car_ring": Vector3(473, 1.15, 243),
	"hoffmann_ring": Vector3(534, .1, 243),
	"auction_car": Vector3(-56, 0, -66),
	"mailboxes": Vector3(437, 1.20, 330.6),
	"carrier_prints": Vector3(435, .10, 298),
	"last_cap": Vector3(447.1, .15, -536),
	"tou": Vector3(443.8, 1.1, -544),
	"angie_house": Vector3(462.5, 1.3, -469.5),
	"angie": Vector3(462.5, 1.3, -469.5),
	"angie_walking": Vector3(462.5, 1.3, -469.5),
}

func build_landmark(id: String) -> void:
	var point: Vector3 = world.story_point(id)
	origin = Vector3(point.x, world.ground_height(point.x,point.z), point.z)
	match id:
		"car_ring","hoffmann_ring": _car_ring(id == "hoffmann_ring")
		"auction_car": _auction_car()
		"mailboxes": _rural_boxes()
		"carrier_prints":
			footprints(Vector3(434,0,331),point,49)
		"last_cap": _last_corner()
		"angie_house": _alder_house()
		"tou","angie","angie_walking": _resident(id)
	draw.finish()
	if id in ["car_ring","hoffmann_ring"]:
		for mesh in draw.parent.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end = 950.0

func _car_ring(hoffmann_only: bool) -> void:
	# One long, broken necklace across the section. Keep its westernmost
	# cars clear of Kolpack Rd and its eastern arc out of the dairy yard.
	var center: Vector3 = POINTS.car_ring
	if not draw.materials.has("headlight_pool"):
		var pool := ShaderMaterial.new()
		pool.shader = preload("res://assets/county/headlight_pool.gdshader")
		draw.materials.headlight_pool = pool
		var glint := ShaderMaterial.new()
		glint.shader = preload("res://assets/county/light_halo.gdshader")
		glint.set_shader_parameter("tint",Color(1,.92,.71,1.0))
		draw.materials.headlight_glint = glint
	for i in (range(1) if hoffmann_only else range(1,26)):
		var angle := float(i)*TAU/26
		var x := center.x + cos(angle)*61
		var z := center.z + sin(angle)*57
		var at := Vector3(x,world.ground_height(x,z),z)
		var nose := Vector3(-sin(angle)*61,0,cos(angle)*57).normalized()
		var yaw := atan2(-nose.x,-nose.z)
		if i == 0:
			# The Hoffmanns’ own blue sedan is among the ring. This one has
			# a readable plate if Brandt returns at ground level.
			var car: Node3D = world.Scene.car(draw.parent,"unattended",0,HOFFMANN_SEDAN)
			car.name = "HoffmannSedan"
			car.position = at
			car.rotation.y = yaw
			world.Scene.car_lamps(car,"running",-1)
		else:
			var axis := Basis(Vector3.UP,yaw)
			draw.box(at + Vector3.UP*.60,Vector3(1.86,.60,4.4),["oxide","silver","green","cream"][i%4],false,Vector3(0,yaw,0))
			draw.box(at + Vector3.UP*1.13,Vector3(1.53,.54,2.05),"glass",false,Vector3(0,yaw,0))
			draw.box(at + Vector3.UP*1.43,Vector3(1.55,.09,1.81),"snow",false,Vector3(0,yaw,0))
			for side: float in [-1,1]:
				for axle: float in [-1.38,1.38]:
					draw.box(at+axis*Vector3(side*.84,.34,axle),Vector3(.24,.64,.64),"black",false,Vector3(0,yaw,0))
				draw.box(at+axis*Vector3(side*.70,.73,-2.21),Vector3(.36,.21,.04),"fluoro",false,Vector3(0,yaw,0))
				draw.box(at+axis*Vector3(side*.74,.76,2.21),Vector3(.28,.16,.04),"red",false,Vector3(0,yaw,0))
		var side := nose.cross(Vector3.UP)
		# Shallow pools on the snow let the headlights trace the arc from the tank.
		var a := at+nose*2.2
		var b_end := at+nose*14.4
		var corners: Array[Vector3] = [a-side*.86,b_end-side*3.6,b_end+side*3.6,a+side*.86]
		for j in corners.size():
			corners[j].y = world.ground_height(corners[j].x,corners[j].z)+.07
		draw.quad(corners[0],corners[1],corners[2],corners[3],"headlight_pool",PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]))
		for lamp_side: float in [-.74,.74]:
			var lens := a+nose*.07+side*lamp_side+Vector3.UP*.77
			draw.add("quad",lens,Vector3(2.6,2.6,1),"headlight_glint",Vector3(0,yaw,0))

func _auction_car() -> void:
	var car: Node3D = world.Scene.car(draw.parent,"unattended",0,HOFFMANN_SEDAN)
	car.name = "HoffmannSedan"
	car.position = origin
	b(1.65,.53,-1.35,.08,1.06,.08,"wood")
	placard(Vector3(1.65,1.19,-1.35),"AUCTION  ·  LOT 3",1.55,.39,PI*.5,"green",true)

func _rural_boxes() -> void:
	b(0,.52,0,.17,1.04,.19,"wood",true)
	b(0,.98,0,1.50,.13,.17,"wood")
	for i in 2:
		var x := -.39 if i == 0 else .39
		var finish := "silver" if i == 0 else "green"
		for side: float in [-1,1]:
			b(x+side*.24,1.19,0,.026,.31,.80,finish)
		b(x,1.04,0,.49,.04,.80,finish)
		b(x,1.19,-.39,.49,.30,.03,finish)
		draw.add("mound",p(x,1.34,-.01),Vector3(.51,.28,.81),finish)
		draw.add("mound",p(x-.04,1.425,-.042),Vector3(.39,.14,.70),"snow")
		if i == 0:
			b(x,1.19,.413,.48,.30,.033,"dark")
			b(x,1.22,.435,.43,.21,.011,"cream")
			label(Vector3(x,1.22,.443),"BOX 6",.092,0,Color("#2b332e"))
		else:
			b(x,1.19,.413,.48,.30,.033,"green")
			label(Vector3(x,1.22,.436),"ROUTE 2",.088,0,Color("#dfdfc5"))

		b(x+.26,1.39,-.14,.023,.28,.041,"oxide")
		b(x+.26,1.50,-.071,.025,.082,.16,"oxide")

func alder_cut() -> void:
	street_sign(ALDER_X+6.8,-405.9,"SWAMP RD","ALDER CUT RD")
	# Paired winter stakes follow the cut through the trees.
	for z in range(-417,-546,-21):
		for side: float in [-1,1]:
			var x := ALDER_X+side*5.8
			site(x,z,world.ground_height(x,z))
			b(0,.65,0,.08,1.3,.08,"wood")
			b(0,1.18,0,.086,.20,.086,"white")

func _last_corner() -> void:
	cyl(0,.052,0,.64,.104,"slush")
	cyl(0,.123,0,.42,.045,"brass")
	for angle: float in [0, PI*.5]:
		draw.box(p(0,.148,0),Vector3(.162,.007,.012),"dark",false,Vector3(0,angle,0))
	var section := label(Vector3(0,.150,.103),"S3 NW",.050,0,Color("#2c2921"))
	section.rotation.x = -PI*.5
	var year := label(Vector3(0,.150,-.107),"1936",.042,0,Color("#2c2921"))
	year.rotation.x = -PI*.5
	for offset: float in [-.93,.93]:
		b(offset,.81,-.49,.105,1.62,.10,"oxide")
		b(offset,1.41,-.49,.109,.24,.106,"white")
	# A filed notch and horizontal rule let the cap be found again under snow.
	b(0,1.15,-.50,1.95,.14,.11,"wood")
	placard(Vector3(0,1.20,-.41),"COUNTY SURVEY",1.12,.23,0,"green")
	draw.box(p(.27,.064,.16), Vector3(.23,.017,.018),"safety_yellow",false,Vector3(0,.32,0))

func _alder_house() -> void:
	# Leave the near end of the drive clear for the hook and wheel-lift.
	site(462.5,-475.9)
	b(0,1.96,0,8.4,3.92,9.6,"siding",true)
	roof(0,3.92,0,8.7,2.6,9.9)
	b(-2.6,5.12,-.98,.73,2.55,.72,"brick")
	window(Vector3(-2.64,1.92,4.88),1.66,1.37)
	window(Vector3(2.79,1.92,4.88),1.55,1.37)
	window(Vector3(-4.27,1.93,-1.23),1.49,1.32,-PI*.5)
	b(0,1.18,4.85,1.11,2.36,.13,"green")
	b(.36,1.05,4.955,.097,.07,.10,"brass")
	b(0,.11,5.61,4.56,.22,1.74,"wood")
	draw.box(p(0,2.93,5.76),Vector3(4.91,.18,2.29),"snow",false,Vector3(.12,0,0))
	for x: float in [-2.13,2.13]:
		b(x,1.52,6.58,.14,2.72,.15,"wood",true)
	placard(Vector3(1.39,1.76,4.91),"N 5420",.91,.31,0,"green")
	placard(Vector3(0,2.56,4.91),"1936",.50,.19,0,"dark")

func _resident(id: String) -> void:
	var surveyor := id == "tou"
	var figure: Node3D = world.Scene.person(draw.parent,false,3 if surveyor else 0)
	figure.name = "TouVang" if surveyor else "AngieKraemer"
	figure.position = origin + Vector3.UP*(.22 if not surveyor else 0.0)
	figure.rotation.y = PI if surveyor else PI*.50
	if surveyor:
		bare_ring(origin,3.6)
		b(.51,1.02,.2,.081,2.04,.067,"cream")
		for i in 10:
			b(.51,.15+.19*i,.239,.080,.047,.014,"oxide")
		cyl(.33,.16,.50,.145,.32,"green")
		cyl(.33,.345,.50,.136,.05,"silver")
	elif id == "angie_walking":
		world.Scene.walk_person(figure)

# Walk the same route after resuming a shift. The case file keeps distance
# covered, so a paused or reloaded tow cannot send Angie back to the porch.
static func place_angie(county, figure: Node3D, distance: float) -> bool:
	for i in range(1,ANGIE_PATH.size()):
		var start: Vector2 = ANGIE_PATH[i-1]
		var end: Vector2 = ANGIE_PATH[i]
		var length := start.distance_to(end)
		if distance < length:
			var t := distance/length
			var at := start.lerp(end,t)
			var porch_height := .22*(1.0-t) if i == 1 else 0.0
			figure.position = Vector3(at.x,county.ground_height(at.x,at.y)+porch_height,at.y)
			figure.rotation.y = atan2(start.x-end.x,start.y-end.y)
			return false
		distance -= length
	figure.hide()
	return true
