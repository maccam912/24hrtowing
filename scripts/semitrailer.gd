extends Node3D

const Kit := preload("res://scripts/rig_mesh.gd")
const VARIANT := 7
const SIZE := Vector3(1.18,.90,3.38)
const WHEEL_RADIUS := .54
const FRONT_AXLE := -2.48
const REAR_AXLE := 1.86
const KINGPIN := Vector3(0,1.14,1.88)
const BOGIE := 8.45
const BACK := 10.68
const WIDTH := 1.29
const BLACK := Color("#292d2e")
const STEEL := Color("#989b93")
const CREAM := Color("#dad8c8")
const GLASS := Color("#45555d")
const RED := Color("#a63f3b")
const AUX_FAIRLEAD := Vector3(.92,1.85,4.16)
var trailer: Node3D
var rigging := "tractor"
var chain_side := 1.0
var initial_bend := 0.0

func build(parent: Node3D, ticket: Dictionary) -> void:
	name = "FreightTractor"
	parent.add_child(self)
	set_meta("body_size",SIZE)
	set_meta("plate",ticket.get("plate",""))
	set_meta("vin",ticket.get("vin",""))
	set_meta("paint",int(ticket.get("paint",0)))
	var base := Color("#586d79") if int(ticket.get("paint",0)) == 0 else Color("#8b5547")
	var g := Kit.new(self)
	g.box(Vector3(0,.76,0),Vector3(.96,.37,6.61),BLACK)
	g.box(Vector3(0,1.53,-2.55),Vector3(1.63,.87,1.55),base)
	g.box(Vector3(0,1.51,-3.35),Vector3(1.27,.83,.09),BLACK)
	for rib in 12:
		g.box(Vector3((rib-5.5)*.101,1.52,-3.41),Vector3(.047,.79,.039),STEEL)
	g.box(Vector3(0,.84,-3.39),Vector3(2.38,.24,.12),STEEL)
	g.ring(Vector3(0,SIZE.y-.087,-SIZE.z*1.016),.075,.13,Color("#d0af74"),Vector3(PI/2,0,0))
	g.box(Vector3(0,1.63,-.94),Vector3(2.13,.97,1.81),base)
	g.box(Vector3(0,2.39,-1.73),Vector3(2.02,.74,.074),GLASS,Vector3(.17,0,0))
	g.box(Vector3(0,2.39,-1.785),Vector3(.055,.75,.06),STEEL,Vector3(.17,0,0))
	g.box(Vector3(0,2.84,-.93),Vector3(2.16,.14,1.77),base)
	g.box(Vector3(0,2.04,.23),Vector3(2.23,2.10,.89),base)
	g.box(Vector3(0,3.10,.23),Vector3(2.23,.08,.88),CREAM)
	g.tube(Vector3(0,1.06,1.88),KINGPIN,.60,BLACK,14)
	for s:float in [-1,1]:
		var x := s*1.07
		g.box(Vector3(x,2.40,-.94),Vector3(.051,.69,1.26),GLASS)
		g.box(Vector3(x,2.42,-.72),Vector3(.055,.73,.07),base)
		g.box(Vector3(x,1.74,-.94),Vector3(.052,.18,1.70),CREAM)
		g.box(Vector3(x,1.22,-2.51),Vector3(.41,.42,1.34),base)
		g.box(Vector3(x,1.25,-3.18),Vector3(.34,.20,.06),CREAM)
		g.box(Vector3(x,1.02,-.99),Vector3(.41,.14,1.38),STEEL)
		g.tube(Vector3(x,.80,-.90),Vector3(x,.80,.22),.25,STEEL)
		g.tube(Vector3(x,1.07,.74),Vector3(x,3.31,.74),.079,STEEL,10)
		g.beam(Vector3(x,2.46,-1.40),Vector3(s*1.38,2.54,-1.47),.045,.045,STEEL)
		g.box(Vector3(s*1.38,2.54,-1.47),Vector3(.11,.38,.15),STEEL)
		g.box(Vector3(x,.57,3.0),Vector3(.40,.69,.072),BLACK)
		for z:float in [FRONT_AXLE,REAR_AXLE-.53,REAR_AXLE+.53]:
			g.truck_wheel(s,z,WHEEL_RADIUS,1.07,0)
	Kit.label(self,get_meta("plate"),Vector3(.05,1.01,-3.46),.082,CREAM,Vector3(0,PI,0))
	g.finish()
	trailer = Kit.joint(self,Vector3.ZERO,"FreightTrailer")
	trailer.top_level = true
	g = Kit.new(trailer)
	# The trailer's origin is its kingpin. Its tandem follows well behind it.
	g.box(Vector3(0,1.43,4.86),Vector3(WIDTH*2,2.78,11.62),CREAM)
	g.box(Vector3(0,-.008,4.86),Vector3(2.57,.13,11.68),STEEL)
	g.box(Vector3(0,2.84,4.86),Vector3(2.64,.095,11.68),STEEL)
	for s:float in [-1,1]:
		for i in 16:
			g.box(Vector3(s*1.304,1.44,-.88+i*.745),Vector3(.033,2.78,.038),STEEL)
		g.box(Vector3(s*1.313,1.55,4.87),Vector3(.029,.33,11.56),base)
		Kit.label(trailer,"NORTH COUNTRY FREIGHT",Vector3(s*1.335,1.57,4.73),.205,CREAM,Vector3(0,s*PI/2,0))
		for i in 11:
			g.box(Vector3(s*1.305,.19,-.75+i*1.06),Vector3(.025,.074,.43),RED)
		g.box(Vector3(s*.81,-.24,2.68),Vector3(.15,.53,.18),STEEL)
		g.box(Vector3(s*.81,-.52,2.68),Vector3(.34,.067,.28),BLACK)
		for z:float in [BOGIE-.58,BOGIE+.58]:
			g.truck_wheel(s,z,.51,1.13,-KINGPIN.y)
		g.box(Vector3(s*1.12,-.56,9.68),Vector3(.39,.79,.065),BLACK)
		g.box(Vector3(s*.64,1.43,BACK+.023),Vector3(1.23,2.68,.037),Color("#b8bcb5"))
		g.tube(Vector3(s*.82,.22,BACK+.07),Vector3(s*.82,2.64,BACK+.07),.029,STEEL)
		g.box(Vector3(s*1.08,.12,BACK+.09),Vector3(.22,.13,.04),RED)
		g.ring(Vector3(s*(WIDTH-.03),-.16,BOGIE-.8),.075,.132,Color("#bf9a62"),Vector3(0,0,PI/2))
	g.box(Vector3(0,-.48,BACK-.09),Vector3(2.27,.17,.11),STEEL)
	g.finish()

func set_trailer_heading(yaw: float, ground: Callable) -> void:
	var pin := to_global(KINGPIN)
	var tail := pin+Vector3.BACK.rotated(Vector3.UP,yaw)*BOGIE
	var grade := atan2(pin.y-(float(ground.call(tail))+KINGPIN.y),BOGIE)
	trailer.global_rotation = Vector3(clampf(grade,-.22,.22),yaw,0)
	trailer.global_position = pin

func follow(ground: Callable) -> void:
	var tail := trailer.to_global(Vector3.BACK*BOGIE)-to_global(KINGPIN)
	var bend := wrapf(atan2(tail.x,tail.z)-rotation.y,-PI,PI)
	set_trailer_heading(rotation.y+clampf(bend,-1.22,1.22),ground)

func park_at(point: Vector3, yaw: float, fold: float, ground: Callable) -> void:
	position = point
	rotation.y = yaw
	initial_bend = fold
	set_trailer_heading(yaw+fold,ground)

func axle_eye(side: float) -> Vector3:
	return trailer.to_global(Vector3(side*(WIDTH-.03),-.16,BOGIE-.8))

func nearest_axle(point: Vector3) -> float:
	return 1.0 if point.distance_squared_to(axle_eye(1)) < point.distance_squared_to(axle_eye(-1)) else -1.0

func outside_trailer(destination: Vector3, previous: Vector3) -> Vector3:
	var p := trailer.to_local(destination)
	if absf(p.x)>=WIDTH+.14 or p.z<= -1.17 or p.z>=BACK+.16: return destination
	var before := trailer.to_local(previous)
	if absf(before.x)>WIDTH+.105: p.x = signf(before.x)*(WIDTH+.15)
	else: p.z = BACK+.17 if before.z>4.85 else -1.18
	return trailer.to_global(p)

func straighten(rig, dt: float) -> void:
	var previous_yaw := trailer.global_rotation.y
	var toward:Vector3 = rig._drum()-global_position
	toward.y = 0
	# The tractor inches forward under the main line as the other drum
	# draws the tandem back behind the fifth wheel.
	var travel := minf(maxf(toward.length()-6.0,0),dt*.31)
	position += toward.normalized()*travel
	position.y = rig._ground(position)
	var aimed := atan2(-toward.x,-toward.z)
	rotation.y = rotate_toward(rotation.y,aimed,travel*.055)
	var yaw := rotate_toward(previous_yaw,rotation.y,dt*.097)
	set_trailer_heading(yaw,rig._ground)
	var angle := absf(angle_difference(yaw,rotation.y))
	rig.tension = move_toward(rig.tension,.48+angle*.28,dt*.43)
	rig.special_work = clampf(1.0-angle/absf(initial_bend),0,1)
	if angle < .025:
		rig.special_work = 1.0
		rigging = "release"
		rig.phase = "cable"
		rig.working = false
		rig._note("Trailer straight. Set the brake on the drum and unpin the check line at the tandem.",6.0)

func snapshot() -> Dictionary:
	return {"yaw":trailer.global_rotation.y,"rigging":rigging,"side":chain_side,"fold":initial_bend}

func restore(state: Dictionary, ground: Callable) -> void:
	rigging = state.get("rigging","tractor")
	chain_side = state.get("side",1.0)
	initial_bend = state.get("fold",initial_bend)
	set_trailer_heading(state.get("yaw",rotation.y+initial_bend),ground)

func freight_lamps() -> Node3D:
	var lamps := Kit.joint(trailer,Vector3.ZERO,"TowLights")
	var g := Kit.new(lamps)
	g.box(Vector3(0,.69,BACK+.14),Vector3(2.31,.18,.18),BLACK)
	for s:float in [-1,1]:
		g.box(Vector3(s*.85,.69,BACK+.24),Vector3(.26,.135,.047),Color("#f64d3c"),Vector3.ZERO,"lamp")
		g.box(Vector3(s*1.13,.69,BACK+.15),Vector3(.14,.14,.20),Color("#f8ac46"),Vector3.ZERO,"lamp")
	g.finish()
	return lamps

static func fit_auxiliary_drum(body: Node3D) -> Node3D:
	var drum := Kit.joint(body,Vector3(.84,1.95,3.45),"AuxiliaryWinch")
	var g := Kit.new(drum)
	for x: float in [-.23,.23]:
		g.box(Vector3(x,-.13,.01),Vector3(.08,.33,.53),BLACK)
		g.tube(Vector3(x-.023,.03,0),Vector3(x+.023,.03,0),.24,RED,12)
	for loop in 10:
		var at := Vector3(-.198+loop*.044,.03,0)
		g.tube(at,at+Vector3.RIGHT*.038,.164,STEEL,12)
	g.box(Vector3(.08,-.10,.70),Vector3(.37,.17,.08),BLACK)
	g.finish()
	return drum

func cable_action(rig, at_panel: bool) -> String:
	match rigging:
		"tractor":
			if rig._in_range(rig._eyelet(-1),2.45): return "freight_tractor"
			if at_panel: return "restow"
		"fetch":
			if at_panel: return "freight_second"
			if rig._in_range(rig._eyelet(-1),1.8): return "unhook"
		"axle":
			if rig._in_range(axle_eye(nearest_axle(rig.foot)),2.45): return "freight_axle"
			if at_panel: return "freight_cancel_second"
		"release":
			if rig._in_range(axle_eye(chain_side),2.45): return "freight_unpin"
		"stow":
			if at_panel: return "freight_stow"
	return "enter" if rig._at_door() else ""

func handle_work(rig, action: String) -> void:
	match action:
		"freight_tractor":
			rig.line_end = -1
			rig.free_line = rig._flat_distance(rig._drum(),rig._eyelet(-1))+.45
			if rig.special_work >= 1.0:
				rigging = "straight"
				rig.phase = "rigged"
			else:
				rigging = "fetch"
			rig.sound_event.emit("ratchet")
		"freight_second": rigging = "axle"
		"freight_cancel_second": rigging = "fetch"
		"freight_axle":
			chain_side = nearest_axle(rig.foot)
			rigging = "both"
			rig.phase = "rigged"
			rig.sound_event.emit("ratchet")
		"freight_unpin":
			rigging = "stow"
			rig.sound_event.emit("ratchet")
		"freight_stow":
			rigging = "straight"
			rig.phase = "rigged"
			rig.free_line = rig._flat_distance(rig._drum(),rig._eyelet(-1))+.35
			rig.sound_event.emit("ratchet")

const PROMPTS := {
	"freight_position":"Park ahead of the tractor facing along US 59",
	"freight_tractor":"Shackle the block to the tractor's front eye",
	"freight_second":"Take the check line from the second drum",
	"freight_cancel_second":"Rewind the check line",
	"freight_axle":"Pin the check line to the trailer tandem",
	"freight_unpin":"Unpin the check line at the trailer tandem",
	"freight_stow":"Stow the check line at the rear controls",
	"need_second_winch":"Fit the second winch at the yard",
}
func instructions(phase: String) -> String:
	if phase == "scene": return "Pull up on firm road ahead of the tractor with the wrecker's rear facing its grille. Step down and set a flare."
	if phase == "flared": return "Take the main line and snatch block at the wrecker’s rear panel."
	if phase not in ["cable","rigged"]: return ""
	match rigging:
		"tractor": return "Shackle the block to the eye centered below the tractor’s grille."
		"fetch": return "The main line holds the tractor. Go back to the wrecker’s side panel for the second drum’s check line."
		"axle": return "Pin the second line to either side of the trailer frame just ahead of its tandem wheels."
		"both": return "At the side panel, hold WINCH. Watch the rear of the box swing back into line behind the tractor."
		"release": return "Walk to the trailer tandem and unpin the check line."
		"stow": return "Carry the check line back to the side panel and stow it."
		"straight": return "Hold WINCH at the panel to bring the tractor’s steer axle up to the lift."
	return ""

func draw_lines(rig) -> void:
	var hand: Vector3 = rig.eyes.global_transform*Vector3(.25,-.32,-.46)
	var end: Vector3 = hand if rigging=="tractor" else rig._eyelet(-1)
	rig.pulley.global_position = end+Vector3.UP*.10
	rig.pulley.rotation.y = atan2(end.x-rig._drum().x,end.z-rig._drum().z)
	rig._cable_strand(rig._drum(),rig.pulley.global_position-rig.pulley.global_basis.x*.07)
	rig._cable_strand(rig.body.to_global(Vector3(.40,1.3,4.1)),rig.pulley.global_position+rig.pulley.global_basis.x*.07)
	if rigging in ["axle","stow","both","release"]:
		var check: Vector3 = hand if rigging in ["axle","stow"] else axle_eye(chain_side)
		rig._cable_strand(rig.body.to_global(AUX_FAIRLEAD),check)

func marking(rig) -> Vector3:
	match rigging:
		"tractor": return rig._eyelet(-1)
		"axle": return axle_eye(nearest_axle(rig.foot))
		"release": return axle_eye(chain_side)
	return Vector3.INF

func fits(bay: Rect2) -> bool:
	for end:float in [-SIZE.z,SIZE.z]:
		for side:float in [-SIZE.x,SIZE.x]:
			var at := to_global(Vector3(side,0,end))
			if not bay.has_point(Vector2(at.x,at.z)): return false
	for end:float in [-1.,BACK]:
		for side:float in [-WIDTH,WIDTH]:
			var at := trailer.to_global(Vector3(side,0,end))
			if not bay.has_point(Vector2(at.x,at.z)): return false
	return true

func crosses_wrecker(truck: Node3D, step: Vector3, turn: float, speed: float) -> bool:
	var nose := truck.global_basis.z*(-signf(speed)*4.0)
	for x:float in [-1.06,1.06]:
		var offset := nose + truck.global_basis.x*x
		var probe := truck.global_position+step+offset.rotated(Vector3.UP,turn)
		if not outside_trailer(probe,truck.global_position+offset).is_equal_approx(probe):
			return true
	return false

func tow_obstructed(rig, step: Vector3, turn: float) -> bool:
	# Predict both axle arcs before committing the wrecker's movement. Check
	# the long sides too, which swing inside the wheels on a tight turn.
	var tractor:Transform3D = rig.forecast_tow(step,turn,FRONT_AXLE,REAR_AXLE,WHEEL_RADIUS)
	if rig.load_obstructed(self,tractor,SIZE.x,1.0,[-SIZE.z,0,SIZE.z]):
		return true
	var pin := tractor*KINGPIN
	var tail := trailer.to_global(Vector3.BACK*BOGIE)-pin
	var yaw := atan2(tractor.basis.z.x,tractor.basis.z.z)
	var box_yaw := yaw+clampf(angle_difference(yaw,atan2(tail.x,tail.z)),-1.22,1.22)
	var box_pose := Transform3D(Basis(Vector3.UP,box_yaw),pin)
	return rig.load_obstructed(trailer,box_pose,WIDTH,-.07,[-.98,2.0,4.9,7.8,BACK])

func settle(ground: Callable) -> void:
	rotation.x = 0
	rotation.z = 0
	position.y = ground.call(position)
	set_trailer_heading(trailer.global_rotation.y,ground)
	_solid(self,Vector3(0,1.2,-.76),Vector3(2.26,2.24,5.25))
	_solid(trailer,Vector3(0,1.28,4.86),Vector3(WIDTH*2,2.9,11.68))

func _solid(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	collision.position = at

func delivery_record() -> Dictionary:
	return {"plate":get_meta("plate"),"vin":get_meta("vin"),"paint":get_meta("paint"),"x":position.x,"z":position.z,
		"yaw":rotation.y,"trailer_yaw":trailer.global_rotation.y}

func restore_delivery(parent: Node3D, data: Dictionary, ground: Callable) -> void:
	build(parent,data)
	park_at(Vector3(data.x,0,data.z),data.yaw,0.0,ground)
	set_trailer_heading(data.trailer_yaw,ground)
	settle(ground)
