extends Node3D
## Brandt's car carrier. The cable follows the sliding bed. Both axles ride
## aboard after the straps are tightened and the bed comes home against its locks.
const Kit := preload("res://scripts/rig_mesh.gd")
const HOME := Vector3(0,1.37,3.32)
const DEPLOYED_Z := 6.12
const HALF_LENGTH := 3.10
const CAR_CENTER := .16
const PANEL := Vector3(-1.38,1.04,2.56)
const STEEL := Color("#686f6e")
const DARK := Color("#3b4347")
const CREAM := Color("#dfd4bc")
const MAROON := Color("#80353a")
const WEBBING := Color("#cc9042")
const PROMPTS := {
	"deck_align":"Back the tail toward the car. Leave room to slide the bed out.",
	"deck_out":"Slide the carrier bed back and down",
	"deck_moving":"Bed hydraulics running",
	"deck_support":"Keep the hook on until the car is strapped on the bed",
	"deck_stow":"Bring the empty bed home and pull the chocks",
	"deck_strap":"Ratchet the two wheel straps on this side",
	"deck_other":"Walk round and strap the other pair of wheels",
	"deck_home":"Retract the bed into its travel locks",
	"deck_unload":"Lower the bed at the storage bay",
	"deck_unstrap":"Release the wheel straps on this side",
	"deck_pay":"Select winch payout for unloading",
	"deck_store":"Place the rear of the carrier over the amber storage bay",
}
var bed: Node3D
var restraints: Array[Node3D] = []
var extension := 0.
var motion := ""
var sides := 0
var unloading := false
var tail_at := 0.

static func supports(ticket: Dictionary) -> bool:
	if ticket.is_empty(): return true
	var kind: String = ticket.get("kind","")
	if kind in ["looksee","field_visit","passenger"]: return true
	if kind not in ["ditch","hazard"] or ticket.get("heavy_recovery",false): return false
	var model := int(ticket.get("variant",0))
	if model > 3 and model != preload("res://scripts/county_squad.gd").VARIANT: return false
	return ticket.get("recovery","") in ["","gate","level_field"]

func assemble(parent: Node3D) -> void:
	name = "RollbackCarrier"
	parent.add_child(self)
	var fixed := Kit.new(self)
	for side: float in [-1.,1.]:
		fixed.box(Vector3(side*.66,1.05,2.75),Vector3(.17,.21,5.52),DARK)
		fixed.box(Vector3(side*1.02,.85,.79),Vector3(.45,.44,.93),MAROON)
		fixed.box(Vector3(side*1.25,.86,.80),Vector3(.032,.28,.73),STEEL)
		fixed.box(Vector3(side*1.27,.91,.80),Vector3(.025,.034,.18),CREAM)
		fixed.beam(Vector3(side*.49,.78,2.50),Vector3(side*.49,1.18,4.75),.15,.15,STEEL)
	fixed.box(Vector3(-1.17,1.00,2.56),Vector3(.31,.34,.78),MAROON)
	for i in 3:
		var handle := Vector3(-1.345,1.02,2.34+i*.18)
		fixed.tube(handle,handle+Vector3(-.07,.10,0),.018,STEEL)
		fixed.tube(handle+Vector3(-.07,.10,0),handle+Vector3(-.085,.12,0),.035,DARK)
	fixed.finish()
	Kit.label(self,"TILT    SLIDE    WINCH",Vector3(-1.338,1.13,2.56),.036,CREAM,Vector3(0,-PI/2,0))
	bed = Kit.joint(self,HOME,"SlidingSteelBed")
	var g := Kit.new(bed)
	g.box(Vector3(0,-.094,0),Vector3(2.54,.18,HALF_LENGTH*2),DARK)
	for side: float in [-1.,1.]:
		g.box(Vector3(side*.83,-.013,.02),Vector3(.71,.037,6.02),STEEL)
		g.box(Vector3(side*1.235,-.085,0),Vector3(.084,.17,6.20),MAROON)
		for i in 9:
			g.box(Vector3(side*1.281,-.07,-2.78+i*.65),Vector3(.011,.044,.29),CREAM if i%2 else Color("#b96b55"))
		for i in 34:
			g.box(Vector3(side*.83,.012,-2.76+i*.17),Vector3(.63,.014,.027),Color("#555d5b"))
		g.beam(Vector3(side*1.16,0,-2.99),Vector3(side*1.16,1.05,-2.99),.07,.09,DARK)
		g.box(Vector3(side*1.06,-.09,3.115),Vector3(.24,.066,.027),Color("#cb3936"),Vector3.ZERO,"lamp")
		g.tube(Vector3(side*.88,.04,-2.54),Vector3(side*.88,.04,-2.37),.07,WEBBING)
	for h:float in [.42,.77,1.05]:
		g.box(Vector3(0,h,-2.99),Vector3(2.37,.055,.075),STEEL)
	g.box(Vector3(0,1.04,-2.95),Vector3(.28,.15,.12),DARK)
	g.box(Vector3(0,1.04,-2.88),Vector3(.24,.11,.02),CREAM,Vector3.ZERO,"lamp")
	g.tube(Vector3(-.35,.25,-2.69),Vector3(.35,.25,-2.69),.16,DARK,12)
	for i in 15:
		g.tube(Vector3(-.30+i*.041,.25,-2.69),Vector3(-.28+i*.041,.25,-2.69),.167,STEEL,10)
	g.tube(Vector3(-.46,-.059,3.09),Vector3(.46,-.059,3.09),.067,STEEL,12)
	g.finish()
	for side:float in [-1.,1.]:
		var straps := Kit.joint(bed,Vector3.ZERO,"WheelStraps")
		var web := Kit.new(straps)
		for axle:float in [-1.,1.]:
			var center := Vector3(side*.89,.355,CAR_CENTER+axle*1.293)
			for i in 10:
				var a := lerpf(-.90,PI+.90,float(i)/10.)
				var b := lerpf(-.90,PI+.90,float(i+1)/10.)
				web.beam(center+Vector3(0,sin(a),cos(a))*.367,center+Vector3(0,sin(b),cos(b))*.367,.092,.022,WEBBING)
			for zside:float in [-1.,1.]:
				web.beam(center+Vector3(0,-.275,zside*.24),Vector3(side*1.14,.022,center.z+zside*.41),.072,.020,WEBBING)
			web.box(Vector3(side*1.11,.052,center.z+.40),Vector3(.11,.054,.085),STEEL)
		web.finish()
		straps.hide()
		restraints.append(straps)

func reset() -> void:
	extension = 0.
	motion = ""
	unloading = false
	sides = 0
	tail_at = 0.
	bed.position = HOME
	bed.rotation = Vector3.ZERO
	for strap in restraints: strap.hide()

func hauls(rig) -> bool:
	return rig.kind == "hazard" and is_instance_valid(rig.car)

func position_bed(rig) -> void:
	var toe: Vector3 = rig.body.to_global(Vector3(0,0,DEPLOYED_Z+HALF_LENGTH))
	toe.y = rig._ground(toe)+.035
	var low: float = rig.body.to_local(toe).y
	var angle := clampf(atan2(HOME.y-low,6.04),.09,.38)
	var lowered := Vector3(0,low+sin(angle)*HALF_LENGTH,DEPLOYED_Z)
	bed.position = HOME.lerp(lowered,extension)
	bed.rotation.x = angle*extension
	for i in restraints.size(): restraints[i].visible = (sides & (1 << i)) != 0

func drum(rig) -> Vector3:
	if rig.kind == "ditch": return bed.to_global(Vector3(0,.015,HALF_LENGTH))
	return bed.to_global(Vector3(0,.22,-2.49))

func lined_up(rig) -> bool:
	var at: Vector3 = rig.body.to_local(rig.car.position)
	return at.z >= 10.6 and at.z < 36. and absf(at.x) <= minf(7.,(at.z-5.)*.49)

func bay_point(rig) -> Vector3:
	var point: Vector3 = rig.truck.to_global(Vector3(0,0,DEPLOYED_Z+HALF_LENGTH+2.64))
	point.y = rig._ground(point)
	return point

func fits_bay(rig) -> bool:
	var p := bay_point(rig)
	var along: Vector3 = rig.truck.global_basis.z*1.95
	var side: Vector3 = rig.truck.global_basis.x*.88
	for corner: Vector3 in [along+side,along-side,-along+side,-along-side]:
		if not rig.YardDrop.contains(rig.dropoff.center,p+corner): return false
	return true

func side_here(rig) -> int:
	var at := bed.to_local(rig.foot)
	if absf(at.x) < 1.23 or absf(at.x)>2.95 or absf(at.z-CAR_CENTER)>2.2: return 0
	return 1 if at.x < 0 else 2

func action(rig, panel: bool) -> String:
	if not hauls(rig): return ""
	if motion == "pay": return "winch" if panel else ""
	if not motion.is_empty(): return "deck_moving" if panel else ""
	match rig.phase:
		"flared":
			if panel: return "deck_out" if lined_up(rig) else "deck_align"
		"cable":
			if panel: return "deck_stow"
		"rigged":
			if not panel and projected(rig.car.position).z < HALF_LENGTH+2.12 and rig._in_range(rig._eyelet(rig.line_end),1.8): return "deck_support"
		"at_lift":
			var here := side_here(rig)
			if unloading:
				if sides & here: return "deck_unstrap"
				if panel and sides == 0: return "deck_pay"
			else:
				if here and not (sides & here): return "deck_strap"
				if panel and sides == 3: return "deck_home"
			return "deck_other" if here or panel else ""
		"loaded":
			if panel: return "deck_unload" if fits_bay(rig) else "deck_store"
	return ""

func instruction(rig) -> String:
	if not hauls(rig): return ""
	match rig.phase:
		"scene","flared": return "Back the carrier toward the car and leave room for the sliding tail. Set a flare, then lower the bed at the left side panel."
		"cable": return "Take the carrier cable to the nearest tow eye."
		"rigged": return "Return to the left side panel. Hold the winch to draw the car up the runners."
		"at_lift":
			if motion == "pay": return "Hold the winch at the left panel to pay the car down into storage."
			if unloading: return "Release the straps on each side of the bed. Select payout at the left panel."
			return "Walk to each side of the car and ratchet its wheel straps. Return to the left panel and bring the bed home."
		"loaded": return "Back the tail toward the amber storage bay. Leave enough room to roll the car down the bed."
	return ""

func handle(rig, id: String) -> void:
	if id in ["deck_out","deck_home","deck_unload","deck_pay","deck_stow"] and rig.fuel <= 0.:
		rig._note(rig.reserve_hint(),5.)
		return
	match id:
		"deck_out":
			rig._set_chocks()
			motion = "extend"
		"deck_home": motion = "load"
		"deck_unload":
			rig._set_chocks()
			unloading = true
			motion = "tip"
		"deck_stow": motion = "stow"
		"deck_pay": motion = "pay"
		"deck_strap","deck_unstrap":
			var here := side_here(rig)
			sides = sides | here if id == "deck_strap" else sides & ~here
			rig.sound_event.emit("ratchet")
			position_bed(rig)
			return
		_:
			rig._note(PROMPTS.get(id,""),3.)
			return
	rig.sound_event.emit("lift")

func unchock(rig) -> void:
	if rig.chocks: rig.chocks.queue_free()
	rig.chocks = null

func pay(rig, dt: float) -> void:
	tail_at = move_toward(tail_at,HALF_LENGTH+2.64,dt*1.83)
	set_load(rig,0.,tail_at)
	rig.tension = move_toward(rig.tension,.34,dt)
	if tail_at >= HALF_LENGTH+2.64:
		motion = "return"
		rig.car.position.y = rig._ground(rig.car.position)
		rig.car.rotation = Vector3(0,rig.car.rotation.y,0)

func animate_bed(rig, dt: float) -> void:
	if motion in ["","pay"] or rig.fuel <= 0.: return
	rig.fuel = maxf(0.,rig.fuel-rig.WINCH_FUEL_PER_SECOND*dt)
	var target := 1. if motion in ["extend","tip"] else 0.
	extension = move_toward(extension,target,dt*.67)
	position_bed(rig)
	if motion in ["tip","load"]: track(rig)
	if extension != target: return
	var finished := motion
	motion = ""
	match finished:
		"extend":
			rig.phase = "cable"
			rig._note("Bed down. Take the hook to the nearest tow eye.",4.)
		"stow":
			rig.phase = "flared"
			unchock(rig)
		"load":
			rig.phase = "loaded"
			rig.loaded = true
			unchock(rig)
			rig._set_car_lamps("tow")
			rig._finish_recovery()
		"tip":
			rig.phase = "at_lift"
			rig.loaded = false
			tail_at = CAR_CENTER
		"return":
			rig.phase = "done"
			unloading = false
			unchock(rig)
			rig.dropped.emit()

func projected(point: Vector3) -> Vector3:
	# Project vertically onto the sloping steel. Dropping local Y directly
	# would shift the casualty along Z every frame while it climbs the ramp.
	var normal := bed.global_basis.y
	point.y += normal.dot(bed.global_position-point)/normal.y
	return bed.to_local(point)

func height_at(rig, point: Vector3) -> float:
	var at := projected(point)
	var ground: float = rig._ground(point)
	if at.z > HALF_LENGTH+.05 or absf(at.x)>1.35: return ground
	return maxf(ground,bed.to_global(Vector3(at.x,.018,at.z)).y)

func set_load(rig, x: float, z: float) -> void:
	var point := bed.to_global(Vector3(x,0,z))
	var yaw:float = rig.heading+(PI if rig.line_end>0 else 0.)
	var axis := Vector3.BACK.rotated(Vector3.UP,yaw)*1.293
	var front := height_at(rig,point-axis)
	var rear := height_at(rig,point+axis)
	rig.car.global_position = Vector3(point.x,(front+rear)*.5+.01,point.z)
	rig.car.rotation = Vector3(atan2(front-rear,2.586),yaw,0)

func track(rig) -> void:
	rig.car.global_transform = bed.global_transform*Transform3D(Basis(Vector3.UP,PI if rig.line_end>0 else 0.),Vector3(0,.025,CAR_CENTER))

func reel(rig, dt: float) -> void:
	var here := projected(rig.car.position)
	var target := bed.to_global(Vector3(0,0,CAR_CENTER))
	var diff := Vector2(target.x-rig.car.position.x,target.z-rig.car.position.z)
	var step := minf(diff.length(),dt*2.72*(1.-float(rig.wear)*.17))
	var direction := diff.normalized()
	var next: Vector3 = rig.car.position+Vector3(direction.x,0,direction.y)*step
	var at := projected(next)
	# The headboard fairlead brings the hooked axle between the runners
	# before the body reaches the steel, even on a slightly oblique approach.
	at.x = move_toward(at.x,0.,dt*.72)
	var yaw:float = rig.heading+(PI if rig.line_end>0 else 0.)
	var blend := 1.-smoothstep(HALF_LENGTH,HALF_LENGTH+3.,here.z)
	var next_yaw := lerp_angle(rig.car.rotation.y,yaw,1.-exp(-dt*(1.5+4.*blend)))
	set_load(rig,at.x,at.z)
	rig.car.rotation.y = next_yaw
	rig.free_line = rig._drum().distance_to(rig._eyelet(rig.line_end))
	rig.tension = move_toward(rig.tension,.47+.14*blend,dt*.9)
	if diff.length() <= .10:
		track(rig)
		rig.phase = "at_lift"
		rig.working = false
		rig.tension = 0.
		rig.sound_event.emit("ratchet")
		rig._note("At the headboard. Ratchet both pairs of wheel straps.",4.)

func save_state() -> Dictionary:
	return {"extension":extension,"motion":motion,"sides":sides,"unloading":unloading,"tail_at":tail_at}

func restore(rig, data: Dictionary) -> void:
	extension = clampf(data.get("extension",0.),0.,1.)
	motion = data.get("motion","")
	sides = int(data.get("sides",0)) & 3
	unloading = data.get("unloading",false)
	tail_at = data.get("tail_at",CAR_CENTER)
	position_bed(rig)
