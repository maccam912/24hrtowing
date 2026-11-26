extends "res://scripts/county_sites.gd"

const GROWER := Vector2(18.7,-213.27)
const Addresses := preload("res://scripts/fire_numbers.gd")

func build() -> void:
	# A dark enamel ground holds contrast when the pillar spot hits the letters head-on.
	var plate_paint := StandardMaterial3D.new()
	plate_paint.albedo_color = Color("#0c3427")
	plate_paint.roughness = 1.0
	plate_paint.metallic_specular = .05
	world.materials["fire_enamel"] = plate_paint
	for id: String in Addresses.PARCELS:
		var row: Dictionary = Addresses.PARCELS[id]
		var at: Vector3 = Addresses.post(world,id)
		origin = at - Vector3.UP*Addresses.SIGN_HEIGHT
		var heading := 0.0 if Addresses.north_south(row.road) else PI*.5
		# Both faces look along traffic. A plow can throw snow below the bottom edge.
		b(0,1.03,0,.084,2.06,.095,"post")
		var twist := Vector3(0,heading,0)
		var normal := Vector3.BACK.rotated(Vector3.UP,heading)
		var center := Vector3.UP*Addresses.SIGN_HEIGHT
		draw.box(origin+center,Vector3(1.88,.71,.074),"post",false,twist)
		for side: float in [-1.0,1.0]:
			draw.box(origin+center+normal*.040*side,Vector3(1.82,.65,.026),"fire_enamel",false,twist)
			var number := label(center+normal*.059*side,Addresses.number(id),.64,heading+(PI if side < 0 else 0.),Color("#fcf8dc"))
			number.name = "FirePlate_"+id+("_A" if side>0 else "_B")
	_dryhouse()
	_cemetery()

func _dryhouse() -> void:
	# The fall crop dried here. In January the shade cloth is rolled up and the grading room stays lit.
	# The raised loading dock faces County K and leaves the ditch outside both ordinary recovery sites.
	site(23,-220,world.ground_height(23,-220))
	b(0,2.73,0,8.7,5.46,12.9,"siding",true)
	roof(0,5.45,0,9.05,3.2,13.25)
	for z: float in [-4.65,0.,4.65]:
		b(0,8.61,z,1.61,1.42,1.78,"dark")
		for slit in 4:
			b(-.83,8.17+.24*slit,z,.11,.10,1.87,"silver")
			b(.83,8.17+.24*slit,z,.11,.10,1.87,"silver")
		roof(0,9.3,z,2.14,.6,2.2)
	# The old stove stack stands above the gable, guyed to the ridge.
	cyl(2.75,5.6,-4,.42,11.2,"oxide")
	cyl(2.75,11.16,-4,.64,.16,"dark")
	beam(Vector3(2.75,10.0,-4),Vector3(-1.5,7.5,-1.8),.034,.034,"post")
	for z: float in [-4.20,-2.10,0.0,2.10]:
		b(-4.39,3.69,z,.10,1.95,1.45,"dark")
		for slit in 6:
			b(-4.46,2.94+slit*.29,z,.16,.13,1.53,"wood")
	b(-4.48,1.81,3.82,.22,3.62,2.4,"oxide",true)
	b(-5.51,.57,3.78,2.25,.22,4.35,"wood",true)
	for z: float in [2.13,5.44]:
		_footing(-6.4,z,.52,.21,.21)
	window(Vector3(-2.57,2.45,6.52),1.71,1.49,0,true)
	placard(Vector3(0,5.92,6.68),"DUDA",4.86,1.28,0,"dark")
	placard(Vector3(0,4.92,6.68),"GINSENG",4.86,.62,0,"dark")
	for z: float in [-1.7,-.25,1.2]:
		for level in 2:
			b(-5.15,.35+level*.60,z,.99,.53,1.31,"wood",true)
			for band: float in [-.43,.43]:
				b(-5.66,.35+level*.60,z+band,.032,.49,.069,"silver")
	lamp(-5.3,6.65,4.50)
	# Roman is up checking the grading room thermometer. A ticket scale waits on the low bench.
	b(-4.05,.53,7.37,1.68,.12,.74,"wood",true)
	for x: float in [-4.72,-3.38]:
		_footing(x,7.37,.50,.11,.56)
	b(-3.73,.68,7.33,.39,.17,.34,"green")
	cyl(-3.73,.81,7.33,.34,.08,"silver")
	b(-3.55,1.02,7.36,.07,.47,.08,"green")
	b(-3.55,1.19,7.39,.26,.19,.08,"cream")
	b(-3.55,1.20,7.44,.018,.11,.02,"oxide")
	b(-4.44,.62,7.47,.41,.057,.30,"cream")
	draw.box(p(-4.40,.66,7.45),Vector3(.26,.022,.024),"safety_yellow",false,Vector3(0,.28,0))
	var roman: Node3D = world.Scene.person(draw.parent,false,1)
	roman.name = "RomanDuda"
	roman.position = grower_position(world)
	roman.rotation.y = PI*.75
	var coat := roman.find_child("Jacket",true,false) as MeshInstance3D
	var wool := ShaderMaterial.new()
	wool.shader = preload("res://assets/characters/grower_wool.gdshader")
	wool.set_shader_parameter("palette",preload("res://assets/characters/winter_palette.png"))
	coat.material_override = wool
	# A short gravel apron crosses the ditch at the drying shed's loading end.
	site(0,0)
	draw.box(Vector3(12.5,.028,-211.3),Vector3(16,.09,4.5),"slush",true)

func _footing(x: float, z: float, top: float, width: float, depth: float) -> void:
	var bottom: float = world.ground_height(origin.x+x,origin.z+z)-origin.y-.12
	var height := maxf(.12,top-bottom)
	b(x,top-height*.5,z,width,height,depth,"wood")

static func grower_position(county) -> Vector3:
	return Vector3(GROWER.x,county.ground_height(GROWER.x,GROWER.y)+.04,GROWER.y)

static func say(job: Dictionary, visit: int) -> String:
	var parcel := str(job.get("site",""))
	if visit % 3 == 0:
		return "Lights blinked twice. Lost the pipes in this grading room once already. You can leave your truck by the loading dock."
	if Addresses.PARCELS.has(parcel) and Addresses.PARCELS[parcel].road == "County K":
		if parcel == "frames":
			return "That's my green plate. Check the %s side of K for your car. I'll keep the dock clear." % job.get("shoulder","other")
		return "You're after %s? That's %s. Go south toward the steeples. The numbers run down that way." % [Addresses.PARCELS[parcel].owner,Addresses.number(parcel)]
	if visit % 3 == 1:
		return "See the green plate? %s here, %s at Brandt's gate. Smaller numbers going south. I can find that drive in a whiteout." % [Addresses.number("frames"),Addresses.number("brandt")]
	return "When we dig in the fall, those trays go right up to the louvers. Come winter all I'm weighing down here is freight."

func _cemetery() -> void:
	site(-17,133)
	for side: float in [-1.,1.]:
		b(0,1.04,side*1.6,.28,2.15,.28,"brick")
		fence(Vector3(0,0,side*1.7),Vector3(0,0,side*8.0),.78,true)
	for row in 2:
		for i in 5:
			var x := -2.3-row*3.6
			var z := -5.4+i*2.65
			b(x,.30,z,.31,.60,.62,"slush")
			b(x,.64,z,.35,.11,.66,"snow")
