extends Node3D
const Kit = preload("res://scripts/rig_mesh.gd")
const MAROON := Color("#6b1f24")
const DEEP := Color("#491a20")
const CREAM := Color("#e8e0cb")
const RUBBER := Color("#232729")
const TREAD := Color("#303134")
const IRON := Color("#404747")
const STEEL := Color("#858c86")
const CHROME := Color("#b7bbb1")
const DASH := Color("#72766c")
const AMBER := Color("#ffaf32")
const TAIL := Color("#b3202a")
const INK := Color("#242523")
const GREEN := Color("#a7bb9e")
const EYE := Vector3(-0.55,2.56,-0.42)
const DOOR := Vector3(-1.55,0.0,-0.55)
const PANEL := Vector3(-1.43,1.05,2.38)
const DRUM := Vector3(0,1.38,4.0)
# Crossbar center with the underlift extended, before its vertical travel.
const HITCH := Vector3(0,0.47,5.85)
const FRONT_AXLE_Z := -2.85
const FIRST_DRIVE_Z := 1.64
const LAST_DRIVE_Z := 2.87
const REAR_AXLE_Z := (FIRST_DRIVE_Z + LAST_DRIVE_Z) * 0.5 # Tandem midpoint.
const WHEELBASE := REAR_AXLE_Z - FRONT_AXLE_Z
const HALF_TRACK := 1.02
const TIRE_RADIUS := 0.59
var wheels: Array[Node3D]=[]
var wheel_chains: Array[MeshInstance3D]=[]
var needles: Array[Node3D]=[]
var wipers: Array[Node3D]=[]
var mirrors: Array[SubViewport]=[]
var steer_wheel: Node3D
var pressure_needle: Node3D
var lift: Node3D
var stinger: Node3D
var boom: Node3D
var boom_extension: Node3D
var boom_tip: Node3D
var panel_face: StandardMaterial3D
var radio_faces: Array[Label3D] = []
var headlamps: Array[SpotLight3D] = []
var work_light:=SpotLight3D.new()
var odo_label: Label3D
var heading_label: Label3D
var radio_label: Label3D
var digital_timer := 0.0
var mirror_timer := 0.0
var mirror_step := 0
var elapsed := 0.0
var glass_material := ShaderMaterial.new()
var beacons: Array[MeshInstance3D]=[]
var seat_gear: Node3D

func build() -> void:
	var k = Kit.new(self)
	# Frame rails and tandem drives.
	for s in [-1.0,1.0]:
		k.box(Vector3(s*.52,.69,.06),Vector3(.16,.35,8.15),IRON)
	k.box(Vector3(0,.91,-2.7),Vector3(1.94,.42,2.25),IRON)
	k.box(Vector3(0,1.47,-2.73),Vector3(1.63,.69,2.08),MAROON,Vector3(-.055,0,0))
	k.box(Vector3(0,1.84,-2.77),Vector3(.09,.035,1.78),CHROME)
	k.box(Vector3(0,1.43,-3.83),Vector3(1.52,.84,.12),CHROME)
	k.box(Vector3(0,1.43,-3.903),Vector3(1.35,.70,.03),INK)
	for x in range(-8,9):
		k.box(Vector3(x*.076,1.43,-3.927),Vector3(.023,.65,.026),STEEL)
	k.box(Vector3(0,.75,-4),Vector3(2.45,.35,.22),CHROME)
	k.box(Vector3(0,.76,-4.13),Vector3(.48,.19,.025),CREAM)
	for s in [-1.0,1.0]:
		k.box(Vector3(s*.98,1.40,-2.97),Vector3(.56,.38,1.75),MAROON)
		k.box(Vector3(s*1.00,1.34,-3.87),Vector3(.49,.26,.07),IRON)
		for x in [-.109,.109]:
			k.box(Vector3(s*(1+x),1.36,-3.919),Vector3(.18,.15,.025),Color("#f0e9d6"),Vector3.ZERO,"lamp")
		var light := SpotLight3D.new()
		add_child(light)
		headlamps.append(light)
		light.position=Vector3(s*.95,1.34,-3.97)
		light.rotation.x=-.088
		light.light_color=Color("#fff1d4")
		light.light_energy=3.5
		light.spot_attenuation=.48
		light.spot_range=57.0
		light.spot_angle=24.0
		light.spot_angle_attenuation=.8
		k.tube(Vector3(s*.96,.81,-1.9),Vector3(s*.96,.81,-.07),.31,STEEL,16)
		for z in [-1.75,-.25]:
			k.tube(Vector3(s*.96,.81,z),Vector3(s*.96,.81,z+.07),.326,IRON,16)
		k.box(Vector3(s*1.12,.88,-.83),Vector3(.36,.08,1.0),STEEL)
		k.box(Vector3(s*1.21,.57,-.83),Vector3(.28,.08,1.04),IRON)
		k.tube(Vector3(s*.97,1.24,.06),Vector3(s*.97,3.33,.06),.09,CHROME,12)
		k.tube(Vector3(s*.97,1.48,.06),Vector3(s*.97,2.43,.06),.116,IRON,12)
		for h in [1.55,2.33]:
			k.tube(Vector3(s*.97,h,.06),Vector3(s*.97,h+.04,.06),.12,CHROME,12)
		k.box(Vector3(s*.99,1.59,-.87),Vector3(.14,.69,1.70),CREAM)
		k.box(Vector3(s*1.065,1.79,-.87),Vector3(.045,.19,1.71),MAROON)
		k.box(Vector3(s*1.04,1.97,-.87),Vector3(.12,.20,1.71),MAROON)
		k.box(Vector3(s*1.066,2.02,-.35),Vector3(.08,.045,.205),CHROME)
		k.beam(Vector3(s*1.02,2.04,-1.76),Vector3(s*.96,3.22,-1.49),.07,.075,CREAM)
		k.beam(Vector3(s*1.0,1.99,-.04),Vector3(s*.94,3.22,-.04),.11,.12,CREAM)
		k.box(Vector3(s*.98,2.61,-.32),Vector3(.075,1.19,.04),IRON)
		for z in [FRONT_AXLE_Z, FIRST_DRIVE_Z, LAST_DRIVE_Z]:
			var w := Kit.joint(self,Vector3(s*HALF_TRACK,.60,z),"Wheel")
			var wkit = Kit.new(w)
			wkit.tube(Vector3(-.19,0,0),Vector3(.19,0,0),TIRE_RADIUS,RUBBER,20,"paint")
			for tread in 20:
				var angle := TAU * (tread + .5) / 20.0
				var crown := Vector3(0,cos(angle),sin(angle)) * (TIRE_RADIUS - .007)
				wkit.box(crown,Vector3(.38,.016,.075),TREAD,Vector3(angle,0,0))
			wkit.tube(Vector3(s*.19,0,0),Vector3(s*.22,0,0),.46,TREAD,20,"paint")
			wkit.tube(Vector3(s*.225,0,0),Vector3(s*.237,0,0),.324,STEEL,16)
			wkit.tube(Vector3(s*.237,0,0),Vector3(s*.28,0,0),.124,IRON,12)
			for j in 8:
				var a := j*TAU/8.0
				var p := Vector3(s*.241,.215*sin(a),.215*cos(a))
				wkit.tube(p,p+Vector3(s*.017,0,0),.031,CHROME,6)
			wheels.append(wkit.finish())
	k.box(Vector3(0,1.24,-.81),Vector3(1.99,.18,1.82),DASH)
	k.box(Vector3(0,3.24,-.76),Vector3(2.11,.15,1.73),MAROON)
	k.box(Vector3(0,3.149,-.72),Vector3(1.95,.035,1.52),Color("#68635a"))
	k.box(Vector3(0,1.81,-.02),Vector3(2.0,.99,.14),MAROON)
	k.box(Vector3(0,3.08,-.02),Vector3(1.99,.15,.14),MAROON)
	for s in [-1.0,1.0]:
		k.box(Vector3(s*.8,2.59,-.02),Vector3(.39,.76,.14),MAROON)
	k.box(Vector3(0,3.38,-.76),Vector3(1.61,.11,.34),IRON)
	for s in [-1,1]:
		# Darker louvered separators preserve the silhouette when the strobes light.
		k.box(Vector3(s*.50,3.49,-.76),Vector3(.58,.145,.29),Color("#aa6c29"))
		var bk = Kit.new(self)
		bk.box(Vector3(s*.50,3.503,-.76),Vector3(.55,.126,.30),AMBER,Vector3.ZERO,"lamp")
		beacons.append(bk.finish())
	for x in [-.84,-.48,0,.48,.84]:
		k.box(Vector3(x,3.24,-1.62),Vector3(.075,.047,.053),AMBER,Vector3.ZERO,"lamp")
	# The glass is fitted inside the A-pillars. Only the cold gasket catches snow.
	var glass := QuadMesh.new()
	glass.size = Vector2(1.91,1.08)
	glass_material.shader = preload("res://assets/rig/windshield.gdshader")
	glass.material = glass_material
	var pane := MeshInstance3D.new()
	pane.mesh = glass
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pane)
	pane.position = Vector3(0,2.693,-1.645)
	pane.rotation.x = .233
	_bed(k)
	_cabin(k)
	k.finish()
	_panel_detail()
	for s in [-1.0,1.0]:
		var rot := Vector3(0,s*PI/2,0)
		Kit.label(self,"BRANDT",Vector3(s*1.074,1.618,-.87),.126,DEEP,rot)
		Kit.label(self,"TOWING & RECOVERY",Vector3(s*1.074,1.522,-.87),.049,DEEP,rot)
		Kit.label(self,"ESKER, WIS.  ·  24 HR",Vector3(s*1.071,1.455,-.87),.041,DEEP,rot)
	_mirror(-1.0)
	_mirror(1.0)

func set_chains(fitted: bool) -> void:
	if fitted and wheel_chains.is_empty():
		for wheel in wheels:
			var hub := wheel.get_parent_node_3d()
			if is_equal_approx(hub.position.z, FRONT_AXLE_Z): continue
			var side := signf(hub.position.x)
			var kit = Kit.new(wheel)
			for i in 12:
				var a := TAU*i/12.0
				var b := TAU*(i+1)/12.0
				var radial := Vector3(0,cos(a),sin(a))
				var next := Vector3(0,cos(b),sin(b))
				var rim := Vector3.RIGHT * side*.217
				var crown := radial*(TIRE_RADIUS+.009)
				kit.beam(rim+radial*.49,rim+next*.49,.026,.026,STEEL)
				kit.beam(rim+radial*.49,crown+Vector3.RIGHT*side*.165,.030,.030,STEEL)
				kit.beam(crown+Vector3.RIGHT*side*.165,crown-Vector3.RIGHT*side*.18,.034,.034,STEEL)
			wheel_chains.append(kit.finish())
	for chain in wheel_chains:
		chain.visible=fitted

func _bed(k) -> void:
	k.box(Vector3(0,1.12,2.18),Vector3(1.53,.40,4.18),DEEP)
	for s in [-1.0,1.0]:
		k.box(Vector3(s*.97,1.40,2.25),Vector3(.52,.51,3.96),MAROON)
		k.box(Vector3(s*1.238,1.38,2.25),Vector3(.025,.115,3.85),CREAM)
		k.box(Vector3(s*.97,1.682,2.24),Vector3(.55,.065,3.98),STEEL)
		for z in [.44,1.22,2.02,2.89,3.9]:
			k.box(Vector3(s*1.246,1.43,z),Vector3(.03,.38,.021),IRON)
		for z in [.77,1.6,2.53,3.38]:
			k.box(Vector3(s*1.256,1.55,z),Vector3(.035,.041,.15),CHROME)
		k.box(Vector3(s*.98,.92,4.12),Vector3(.52,.36,.27),DEEP)
		for x in [.85,1.08]:
			k.box(Vector3(s*x,.98,4.27),Vector3(.15,.11,.04),TAIL,Vector3.ZERO,"lamp")
		k.beam(Vector3(s*.72,1.53,.45),Vector3(s*.72,2.60,.94),.18,.22,MAROON)
		k.beam(Vector3(s*.72,2.60,.94),Vector3(s*.72,1.48,2.93),.24,.24,MAROON)
		k.tube(Vector3(s*.53,1.43,2.57),Vector3(s*.53,2.52,1.07),.102,IRON)
		k.tube(Vector3(s*.54,2.03,1.76),Vector3(s*.54,2.52,1.07),.07,CHROME)
	boom=Kit.joint(self,Vector3(0,2.28,.84),"RecoveryBoom")
	var arm:=Kit.new(boom)
	arm.beam(Vector3.ZERO,Vector3(0,.61,2.61),.50,.40,MAROON)
	for s in [-.12,.12]:
		arm.tube(Vector3(s,-.07,.24),Vector3(s,.75,3.25),.021,IRON)
	arm.finish()
	boom_extension=Kit.joint(boom,Vector3(0,.58,2.53),"InnerBoom")
	var extension:=Kit.new(boom_extension)
	extension.beam(Vector3(0,-.30,-1.50),Vector3(0,.19,.71),.33,.25,STEEL)
	extension.box(Vector3(0,.29,.66),Vector3(.29,.15,.17),IRON)
	extension.box(Vector3(0,.29,.752),Vector3(.24,.10,.02),CREAM)
	extension.finish()
	boom_tip=Kit.joint(boom_extension,Vector3(0,.19,.71),"Sheave")
	boom_tip.add_child(work_light)
	work_light.position=Vector3(0,.13,.1)
	work_light.rotation=Vector3(-.38,PI,0)
	work_light.light_color=Color("#fff0ca")
	work_light.light_energy=2.7
	work_light.spot_angle=43.0
	work_light.spot_range=18.0
	work_light.visible=false
	for z in [1.42,2.12]:
		k.tube(Vector3(-.31,1.73,z),Vector3(.31,1.73,z),.22,IRON,14)
		for x in range(-5,6):
			var a := Vector3(x*.057,1.73,z)
			k.tube(a,a+Vector3(.023,0,0),.231,STEEL,12)
	lift=Kit.joint(self,Vector3(0,.03,0),"Underlift")
	var u=Kit.new(lift)
	u.box(Vector3(0,.47,4.02),Vector3(.40,.22,1.19),IRON)
	u.finish()
	stinger=Kit.joint(lift,Vector3(0,0,-1.31),"TelescopingCrossbar")
	var forks=Kit.new(stinger)
	forks.box(Vector3(0,.47,5.14),Vector3(.27,.16,1.47),STEEL)
	forks.box(HITCH,Vector3(1.96,.18,.21),IRON)
	for s in [-1.0,1.0]:
		forks.box(HITCH+Vector3(s*.79,.02,0),Vector3(.12,.145,.64),IRON)
	forks.finish()

func aim_boom(at: Vector3) -> void:
	var toward := to_local(at)-boom.position
	boom.rotation.y = atan2(toward.x,toward.z)
	boom.rotation.x = clampf(.22-atan2(toward.y,Vector2(toward.x,toward.z).length()),-1.23,.1)
	var reach := clampf(toward.length(),3.32,20.0)
	# Extend steel from the base of the inner boom, keeping the tip over the load.
	boom_extension.scale.z = 1.0+(reach-3.32)/2.21
	boom_extension.position.z = 2.53+1.50*(boom_extension.scale.z-1.0)

func stow_boom() -> void:
	boom.rotation=Vector3.ZERO
	boom_extension.scale=Vector3.ONE
	boom_extension.position=Vector3(0,.58,2.53)

func set_electrics(amount: float) -> void:
	var power := 1.0-clampf(amount,0,1)
	for light in headlamps:
		light.light_energy=3.5*power
	RenderingServer.global_shader_parameter_set("headlamp_power",power)
	panel_face.albedo_color=Color.WHITE*lerpf(.06,1,power)
	for face in radio_faces:
		face.modulate.a=power
	odo_label.modulate.a=power

func _cabin(k) -> void:
	k.box(Vector3(0,1.74,-.37),Vector3(1.88,.18,.50),Color("#54534a"))
	k.box(Vector3(0,2.00,-.17),Vector3(1.89,.50,.12),Color("#5a594e"),Vector3(-.08,0,0))
	for x in [-.76,-.56,-.36,-.16,.04,.24,.44,.64,.84]:
		k.box(Vector3(x,2.02,-.243),Vector3(.017,.42,.011),Color("#47473e"))
	k.box(Vector3(0,2.005,-1.62),Vector3(1.98,.38,.47),DASH,Vector3.ZERO,"vinyl")
	k.box(Vector3(0,2.202,-1.64),Vector3(2.00,.062,.51),DASH,Vector3.ZERO,"vinyl")
	k.box(Vector3(-.48,2.16,-1.445),Vector3(.94,.34,.17),IRON)
	k.box(Vector3(-.48,2.339,-1.42),Vector3(.96,.032,.23),RUBBER)
	var face:=Kit.joint(self,Vector3(-.48,2.163,-1.354))
	panel_face=_screen(face,"res://assets/rig/instruments.png",Vector2(.92,.2875))
	for spec in [[184,160,.098],[492,160,.098],[720,114,.046],[913,114,.046]]:
		var pos:=Vector3((float(spec[0])/1024-.5)*.92,(.5-float(spec[1])/320)*.2875,.0025)
		needles.append(_needle(face,pos,spec[2]))
	odo_label=Kit.label(face,"082146.2",Vector3(.27,-.10,.004),.037,Color("#efcf90"),Vector3.ZERO,"dseg7")
	# Compact magnetic dash compass on an adhesive pad.
	k.box(Vector3(.13,2.299,-1.48),Vector3(.23,.12,.12),RUBBER)
	heading_label=Kit.label(self,"N",Vector3(.13,2.303,-1.413),.050,CREAM)
	steer_wheel=Kit.joint(self,Vector3(-.55,2.035,-.977),"SteeringWheel")
	steer_wheel.rotation.x=-.24
	var wheel=Kit.new(steer_wheel)
	wheel.ring(Vector3.ZERO,.192,.222,RUBBER,Vector3(PI/2,0,0))
	for a in [-1.35,1.35,PI]:
		wheel.beam(Vector3.ZERO,Vector3(sin(a)*.199,cos(a)*.199,0),.041,.031,IRON)
	wheel.box(Vector3.ZERO,Vector3(.135,.078,.055),Color("#414341"))
	wheel.finish()
	k.tube(Vector3(-.55,2.035,-1.00),Vector3(-.55,1.97,-1.33),.059,IRON)
	k.box(Vector3(.17,2.095,-1.349),Vector3(.36,.245,.11),RUBBER)
	for y in [2.02,2.098,2.175]:
		k.box(Vector3(.162,y,-1.286),Vector3(.297,.058,.018),Color("#4a4e48"))
		k.box(Vector3(.141,y,-1.274),Vector3(.205,.039,.016),Color("#23332c"))
		k.tube(Vector3(.285,y,-1.278),Vector3(.285,y,-1.253),.020,IRON)
	radio_label=Kit.label(self,"COUNTY 1",Vector3(.143,2.174,-1.255),.026,Color("#bdc898"),Vector3.ZERO,"dseg14")
	radio_faces.append(radio_label)
	radio_faces.append(Kit.label(self,"SCAN",Vector3(.141,2.096,-1.255),.020,GREEN,Vector3.ZERO,"dseg14"))
	radio_faces.append(Kit.label(self,"680 AM",Vector3(.141,2.02,-1.255),.023,GREEN,Vector3.ZERO,"dseg14"))
	k.box(Vector3(.67,1.973,-1.37),Vector3(.58,.21,.045),Color("#636457"))
	k.box(Vector3(.68,2.024,-1.33),Vector3(.12,.025,.024),CHROME)
	seat_gear = Kit.joint(self, Vector3.ZERO, "BenchGear")
	var gear := Kit.new(seat_gear)
	gear.box(Vector3(.45,1.849,-.40),Vector3(.45,.038,.34),Color("#b9ae88"),Vector3(0,-.16,0))
	Kit.label(seat_gear,"TAMARACK COUNTY\nPLAT BOOK",Vector3(.45,1.872,-.41),.039,DEEP,Vector3(-PI/2,-.16,0))
	for z in [-.53,-.49,-.45,-.41,-.37,-.33,-.29]:
		gear.tube(Vector3(.24,1.867,z),Vector3(.27,1.867,z),.009,STEEL)
	gear.box(Vector3(.05,1.848,-.43),Vector3(.23,.03,.32),Color("#71533b"),Vector3(0,.08,0))
	gear.box(Vector3(.05,1.869,-.43),Vector3(.21,.014,.29),CREAM,Vector3(0,.08,0))
	gear.tube(Vector3(.83,1.852,-.42),Vector3(.83,2.09,-.42),.055,Color("#46594e"),12)
	gear.tube(Vector3(.83,2.08,-.42),Vector3(.83,2.134,-.42),.057,STEEL,12)
	gear.finish()
	for x in [-.53,.49]:
		var w=Kit.joint(self,Vector3(x,2.185,-1.791))
		var wiper=Kit.new(w)
		wiper.beam(Vector3.ZERO,Vector3(-.24,.18,.055),.014,.013,RUBBER)
		wiper.beam(Vector3(-.48,.136,.042),Vector3(-.03,.224,.072),.017,.015,RUBBER)
		wiper.finish()
		wipers.append(w)

func _needle(p: Node3D, at: Vector3, length:float) -> Node3D:
	var pivot=Kit.joint(p,at)
	var g=Kit.new(pivot)
	g.beam(Vector3(0,-length*.2,0),Vector3(0,length,0),length*.069,.002,Color("#e89b64"),"lamp")
	g.tube(Vector3(0,0,.001),Vector3(0,0,.003),length*.104,IRON,8)
	g.finish()
	return pivot

func _screen(p:Node3D,path:String,size:Vector2) -> StandardMaterial3D:
	var quad:=QuadMesh.new()
	quad.size=size
	var mat:=StandardMaterial3D.new()
	mat.albedo_texture=load(path)
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material=mat
	var mesh:=MeshInstance3D.new()
	mesh.mesh=quad
	p.add_child(mesh)
	return mat

func _panel_detail() -> void:
	var panel=Kit.joint(self,Vector3(-1.269,1.475,2.34),"Hydraulics")
	panel.rotation.y=-PI/2
	var pk=Kit.new(panel)
	pk.box(Vector3.ZERO,Vector3(.75,.41,.05),Color("#333b37"))
	pk.box(Vector3(.13,-.07,.039),Vector3(.29,.07,.03),IRON)
	for i in 3:
		var x:=.02+i*.11
		pk.tube(Vector3(x,-.066,.052),Vector3(x,.003,.105),.012,STEEL)
		pk.tube(Vector3(x,.003,.105),Vector3(x,.031,.11),.022,RUBBER)
	pk.finish()
	var face=Kit.joint(panel,Vector3(-.18,.004,.033))
	_screen(face,"res://assets/rig/line_pressure.png",Vector2(.25,.25))
	pressure_needle=_needle(face,Vector3(0,0,.002),.077)
	Kit.label(panel,"PTO   IN   OUT",Vector3(.12,.109,.039),.032,CREAM)

func _mirror(s:float) -> void:
	var at:=Vector3(s*1.91,2.79,-1.68)
	var m=Kit.new(self)
	m.beam(Vector3(s*1.02,2.09,-1.67),at+Vector3(0,-.22,0),.035,.032,STEEL)
	m.beam(Vector3(s*1.01,2.74,-1.49),at+Vector3(0,.20,0),.022,.024,STEEL)
	m.finish()
	var frame=Kit.joint(self,at)
	frame.rotation.y=-s*(.46 if s<0 else .62)
	var f=Kit.new(frame)
	f.box(Vector3.ZERO,Vector3(.33,.54,.072),RUBBER)
	f.finish()
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(80,112)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size=0
	viewport.mesh_lod_threshold=4.0
	viewport.world_3d=get_world_3d()
	add_child(viewport)
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	camera.fov=38
	camera.far=570
	camera.cull_mask=1
	var loc=Kit.joint(self,at+Vector3(s*.08,0,.015),"MirrorEye")
	loc.rotation=Vector3(-.16,PI-s*.13,0)
	camera.set_meta("mount",loc)
	var quad:=QuadMesh.new()
	quad.size=Vector2(.296,.503)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture=viewport.get_texture()
	mat.uv1_scale=Vector3(-1,1,1)
	mat.uv1_offset=Vector3(1,0,0)
	quad.material=mat
	var screen:=MeshInstance3D.new()
	screen.mesh=quad
	screen.layers=2
	frame.add_child(screen)
	screen.position.z=.038
	mirrors.append(viewport)

func animate(dt:float, speed:float, steering:float, engine_rpm:float, load_on:bool, tension:float, fuel:float, odo:float, heading:float, cab:bool, has_job:bool) -> void:
	animate_weather(dt,has_job)
	var steer_tangent := tan(steering)
	var curvature := steer_tangent / WHEELBASE
	for wheel in wheels:
		var hub := wheel.get_parent_node_3d()
		var path_scale := 1.0 - hub.position.x * curvature
		if is_equal_approx(hub.position.z, FRONT_AXLE_Z):
			# Ackermann steering: both front wheels point around the same turn center.
			hub.rotation.y = -atan2(steer_tangent, path_scale)
			path_scale = Vector2(path_scale, steer_tangent).length()
		# The tire spins about the steered hub's local axle.
		wheel.rotate_x(-speed * dt * path_scale / TIRE_RADIUS)
	steer_wheel.rotation.z = -steering * 14.0
	var readings := [absf(speed)*2.237/80.0,engine_rpm/3000.0,fuel,.76]
	for i in needles.size():
		needles[i].rotation.z=deg_to_rad(132-264*clampf(readings[i],0,1))
	pressure_needle.rotation.z=deg_to_rad(132-264*tension)
	lift.position.y=move_toward(lift.position.y,.39 if load_on else .03,dt*.65)
	digital_timer-=dt
	if digital_timer<=0:
		digital_timer=.19
		odo_label.text="%08.1f" % odo
		heading_label.text=["N","NE","E","SE","S","SW","W","NW"][posmod(roundi(heading/45.0),8)]
	mirror_timer-=dt
	if cab and mirror_timer<=0 and DisplayServer.get_name()!="headless":
		mirror_timer=.073
		var v:=mirrors[mirror_step]
		mirror_step=1-mirror_step
		var cam:=v.get_camera_3d()
		var mount:Node3D=cam.get_meta("mount")
		cam.global_transform=mount.global_transform
		v.render_target_update_mode=SubViewport.UPDATE_ONCE

func animate_weather(dt: float, beacons_on: bool) -> void:
	RenderingServer.global_shader_parameter_set("headlamp_left", headlamps[0].global_position)
	RenderingServer.global_shader_parameter_set("headlamp_right", headlamps[1].global_position)
	RenderingServer.global_shader_parameter_set("headlamp_direction", -headlamps[0].global_basis.z)
	elapsed += dt
	var sweep := fmod(elapsed,3.6)
	for w in wipers:
		w.rotation.z = -pow(sin(sweep*PI/.96),2)*1.44 if sweep < .96 else 0.0
	for i in beacons.size():
		beacons[i].visible = beacons_on and fmod(elapsed*2.2+i*.5,1) < .25
