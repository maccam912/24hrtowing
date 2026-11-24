extends "res://scripts/county_sites.gd"
## Objects located by the county's later reports. Point heights are above the ground.
const ALDER_X := 441.0
const ALDER_END := -548.0
const HOUSE_YARD := Rect2(443,-482,31,21)
const POINTS := {
	"bridge_plate": Vector3(-447, 1.04, 5.97),
	"bridge_plate_far": Vector3(-502, 1.04, 5.97),
	"mailboxes": Vector3(437, 1.20, 330.6),
	"checked_sedan": Vector3(426.0, 1.04, 329.2),
	"last_cap": Vector3(447.1, .15, -536),
	"tou": Vector3(443.8, 1.1, -544),
	"angie_house": Vector3(462.5, 1.3, -469.5),
	"angie": Vector3(462.5, 1.3, -469.5),
}

func build_landmark(id: String) -> void:
	var point: Vector3 = world.story_point(id)
	origin = Vector3(point.x, world.ground_height(point.x,point.z), point.z)
	match id:
		"bridge_plate","bridge_plate_far": _bridge_plate()
		"mailboxes": _rural_boxes()
		"last_cap": _last_corner()
		"angie_house": _alder_house()
		"tou","angie": _resident(id)
	draw.finish()

func _bridge_plate() -> void:
	# Mounted just inside the south guardrail so both faces are readable from the deck.
	b(0,1.04,.065,1.42,.62,.095,"dark")
	b(0,1.04,.010,1.36,.56,.025,"brass")
	label(Vector3(0,1.18,-.006),"TC-14",.19,PI,Color("#292d28"))
	label(Vector3(0,1.014,-.006),"EAST ABUTMENT",.125,PI,Color("#292d28"))
	label(Vector3(0,.885,-.006),"1931",.097,PI,Color("#292d28"))
	b(.608,.868,-.009,.042,.205,.007,"green")
	for xx: float in [-.61,.61]:
		for yy: float in [.83,1.25]:
			b(xx,yy,-.017,.042,.042,.023,"post")

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
		b(x+.26,1.39,-.14,.023,.28,.041,"oxide")
		b(x+.26,1.50,-.071,.025,.082,.16,"oxide")
	var flap := Node3D.new()
	flap.name = "Box6ALid"
	flap.position = p(.39,1.034,.421)
	draw.parent.add_child(flap)
	var lid = world.Sites.new(world,world.Batch.new(flap,world.materials))
	lid.b(0,.158,0,.49,.315,.033,"dark")
	lid.b(0,.181,.020,.43,.18,.016,"cream")
	lid.label(Vector3(0,.181,.030),"BOX 6A",.085,0,Color("#2b332e"))
	lid.b(0,.160,-.022,.451,.21,.015,"cream")
	var hold_band: Label3D = lid.label(Vector3(0,.112,-.033),"HOLD AT BOX",.057,PI,Color("#313833"))
	var addressee: Label3D = lid.label(Vector3(0,.195,-.033),"T. VANG",.066,PI,Color("#313833"))
	hold_band.rotate_object_local(Vector3.BACK,PI)
	addressee.rotate_object_local(Vector3.BACK,PI)
	lid.draw.finish()

static func set_mail_open(boxes: Node3D, opened: bool, animate: bool) -> void:
	var flap: Node3D = boxes.get_node("Box6ALid")
	if flap.get_meta("opened",false) == opened:
		return
	flap.set_meta("opened",opened)
	var angle := 1.70 if opened else 0.0
	if animate:
		var swing := flap.create_tween()
		swing.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		swing.tween_property(flap,"rotation:x",angle,.36)
	else:
		flap.rotation.x = angle

func alder_cut() -> void:
	street_sign(ALDER_X+6.8,-405.9,"SWAMP RD","ALDER CUT RD")
	# Paired winter stakes follow the cut through the trees.
	for z in range(-417,-546,-21):
		for side: float in [-1,1]:
			var x := ALDER_X+side*5.8
			site(x,z,world.ground_height(x,z))
			b(0,.65,0,.08,1.3,.08,"wood")
			b(0,1.18,0,.086,.20,.086,"white")
	site(452,-540,world.ground_height(452,-540))
	lamp(0,0,5.5,true)
	site(454,-462,world.ground_height(454,-462))
	lamp(0,0,5.1,true)

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
	address(448,-469,"N 5420",-PI*.5)

func _resident(id: String) -> void:
	var surveyor := id == "tou"
	var figure: Node3D = world.Scene.person(draw.parent,false,1 if surveyor else 0)
	figure.name = "TouVang" if surveyor else "AngieKraemer"
	figure.position = origin + Vector3.UP*(.22 if not surveyor else 0.0)
	figure.rotation.y = PI if surveyor else PI*.50
	if surveyor:
		# Tou kept the graduated rod and his waterproof book out in the field.
		b(.51,1.02,.2,.081,2.04,.067,"cream")
		for i in 10:
			b(.51,.15+.19*i,.239,.080,.047,.014,"oxide")
		b(.78,.16,.29,.59,.32,.41,"green")
		b(.78,.334,.29,.64,.044,.44,"dark")
		b(.76,.373,.30,.26,.031,.32,"safety_yellow")
