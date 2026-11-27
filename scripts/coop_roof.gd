extends "res://scripts/recovery_levers.gd"
## The carrier canopy has one way onto the roof and one clear apron below it.
## The wrecker sits across the apron with its boom free to slew past the eave.
const Kit := preload("res://scripts/rig_mesh.gd")
const SITE := Vector3(37.,4.75,-13.6)
const LADDER := Vector3(31.15,0,-12.65)
const LANDING := Vector3(37.60,0,-5.8)
const TRUCK_PAD := Rect2(21.5,-9.55,7.4,4.7)
const TOP := 4.75
const CLEARANCE := .68
const IRON := Color("#525a57")
const STEEL := Color("#8b9290")
const OCHRE := Color("#c18e49")
const PROMPTS := {
	"roof_park":"Park in the striped pocket west of the canopy, hood toward County K",
	"roof_setup":"Plant the stabilizers and swing the spreader over the roof",
	"roof_repack":"Stow the unused spreader and lift the stabilizers",
	"roof_ladder":"Take the service ladder on the west edge",
	"roof_top":"Step through onto the canopy",
	"roof_down":"Take the ladder down",
	"roof_off":"Step off onto the pavement",
	"roof_shackle":"Pin this pair of wheel slings to the spreader",
	"roof_wait":"Rig both sides from the roof, then climb back down",
	"roof_boom":"Take the hoist and slew levers",
	"roof_leave":"Let go of the boom levers",
}
var ladder := -1.
var on_roof := false
var slings := 0
var sweep := 0.
var installed := false
var feet_travelled := 0.
var stabilizers: Node3D
var spreader: Node3D
var chains: Array[Node3D] = []

static func furnish(site) -> void:
	# Coordinates here are local to the co-op at (37,-23). The ladder clears
	# the delivery posts and rises above the outside edge of the canopy.
	for z:float in [10.06,10.64]:
		site.b(-5.65,2.82,z,.054,5.62,.057,"post")
		site.beam(Vector3(-5.65,5.6,z),Vector3(-5.20,5.6,z),.054,.054,"post")
	for i in 15:
		site.beam(Vector3(-5.65,.28+i*.31,10.03),Vector3(-5.65,.28+i*.31,10.66),.051,.059,"post")
	for z:float in [10.06,10.64]:
		site.beam(Vector3(-5.67,4.51,z),Vector3(-5.38,4.51,z),.068,.068,"post")
	site.placard(Vector3(-5.7,1.68,11.55),"ROOF ACCESS",1.25,.32,-PI/2,"green")
	for x:float in [-4.03,4.03]:
		site.b(x,4.90,12.43,.095,.31,.095,"oxide")
	# The foreman kept this striped loading pocket clear for deliveries.
	for z:float in [13.45,18.15]:
		site.b(-11.85,.023,z,6.8,.034,.11,"cream")
	for x:float in [-15.22,-8.47]:
		site.b(x,.023,15.8,.11,.034,4.81,"cream")
	for x:float in [-2.38,3.57]:
		for z:float in [15.46,19.05]:
			site.b(x,.026,z,.65,.035,.085,"cream")
			site.b(x,.026,z,.085,.035,.55,"cream")

func properly_parked(rig) -> bool:
	var p: Vector3 = rig.truck.position
	return TRUCK_PAD.has_point(Vector2(p.x,p.z)) and rig.truck.global_basis.z.dot(Vector3.RIGHT)>.82 and rig.flat_distance(rig.drum_point(),rig.job_site)<15.

func install(rig) -> void:
	installed = true
	stabilizers = Kit.joint(rig.truck,Vector3.ZERO,"CanopyStabilizers")
	var jacks := Kit.new(stabilizers)
	for side:float in [-1.,1.]:
		jacks.box(Vector3(side*1.32,.82,2.02),Vector3(1.25,.19,.21),IRON)
		jacks.tube(Vector3(side*1.87,.85,2.02),Vector3(side*1.87,.13,2.02),.074,STEEL,10)
		jacks.box(Vector3(side*1.87,.083,2.02),Vector3(.52,.14,.55),OCHRE)
	jacks.finish()
	spreader = Kit.joint(rig.car,Vector3(0,2.08,0),"RoofSpreader")
	var frame := Kit.new(spreader)
	for x:float in [-1.04,1.04]:
		frame.box(Vector3(x,0,0),Vector3(.12,.15,2.88),OCHRE)
		frame.beam(Vector3(x,.02,0),Vector3(0,.72,0),.042,.045,IRON)
	frame.box(Vector3.ZERO,Vector3(2.13,.15,.16),OCHRE)
	frame.finish()
	for s:float in [-1.,1.]:
		var side := Kit.joint(spreader,Vector3.ZERO,"WheelBridle")
		var web := Kit.new(side)
		for z:float in [-1.28,1.28]:
			web.beam(Vector3(s*1.04,-.04,z),Vector3(s*1.02,-1.56,z),.061,.03,OCHRE)
			web.beam(Vector3(s*1.02,-1.56,z),Vector3(s*.86,-1.78,z),.061,.03,OCHRE)
		web.finish()
		chains.append(side)
		side.visible = (slings & (1 if s<0 else 2)) != 0
	rig.body.aim_boom(rig.car.to_global(Vector3.UP*4.05))

func clear() -> void:
	if is_instance_valid(stabilizers): stabilizers.queue_free()
	if is_instance_valid(spreader): spreader.queue_free()
	stabilizers = null
	spreader = null
	chains.clear()

func ladder_base(rig) -> Vector3:
	return Vector3(LADDER.x,rig.ground_height(LADDER),LADDER.z)

func pin(rig, side: float) -> Vector3:
	return rig.car.to_global(Vector3(side*1.08,.86,0))

func open_side(rig) -> int:
	for i in 2:
		if not slings & (1 << i) and rig.in_range(pin(rig,-1. if i==0 else 1.),1.70): return 1 << i
	return 0

func action(rig, panel: bool) -> String:
	if controls: return "roof_leave"
	if ladder >= 0.:
		if ladder >= TOP: return "roof_top"
		return "roof_off" if ladder <= 0. else ""
	if on_roof:
		if open_side(rig): return "roof_shackle"
		if rig.flat_distance(rig.foot,LADDER)<1.35: return "roof_down"
		return ""
	if rig.phase=="flared" and panel: return "roof_setup" if properly_parked(rig) else "roof_park"
	if rig.phase in ["cable","rigged"] and rig.special_work < 1.:
		if rig.in_range(ladder_base(rig)+Vector3.UP*1.35,1.95): return "roof_ladder"
		if panel:
			if slings == 0: return "roof_repack"
			return "roof_boom" if slings == 3 else "roof_wait"
	return ""

func step(rig, move: Vector2, dt: float) -> bool:
	if ladder >= 0.:
		var before := ladder
		ladder = clampf(ladder-move.y*2.2*dt,0.,TOP)
		rig.foot = ladder_base(rig)+Vector3(-.25,ladder,0)
		footfall(rig,absf(ladder-before))
		return true
	if not on_roof: return false
	var dir := Vector3(move.x,0,move.y).rotated(Vector3.UP,rig.camera_yaw)
	var dest: Vector3 = rig.foot+dir.limit_length(1.)*2.65*dt
	dest.x = clampf(dest.x,31.72,42.28)
	dest.z = clampf(dest.z,-16.48,-10.72)
	dest.y = ladder_base(rig).y+TOP
	var local: Vector3 = rig.car.to_local(dest)
	if absf(local.x)<1.16 and absf(local.z)<2.35:
		var old: Vector3 = rig.car.to_local(rig.foot)
		if absf(old.x)>=1.15: local.x = signf(old.x)*1.165
		else: local.z = signf(old.z)*2.355
		dest = rig.car.to_global(local)
	footfall(rig,rig.foot.distance_to(dest))
	rig.foot = dest
	return true

func footfall(rig, distance: float) -> void:
	feet_travelled += distance
	if feet_travelled >= 1.34:
		feet_travelled = 0.
		rig.sound_event.emit("footstep")

func handle(rig, id: String) -> void:
	match id:
		"roof_setup":
			rig.phase = "cable"
			rig.set_chocks()
			install(rig)
			rig.sound_event.emit("lift")
			rig.show_note("Spreader overhead. Climb the service ladder on the west edge of the canopy.",5.)
		"roof_repack":
			clear()
			installed = false
			rig.phase = "flared"
			rig.body.stow_boom()
			if rig.chocks: rig.chocks.queue_free()
			rig.chocks = null
			rig.sound_event.emit("lift")
		"roof_ladder","roof_down":
			ladder = TOP if on_roof else 0.
			on_roof = false
			rig.camera_yaw = -PI/2
			rig.camera_pitch = -.21 if ladder == TOP else .40
			rig.foot = ladder_base(rig)+Vector3(-.25,ladder,0)
		"roof_off","roof_top":
			on_roof = id == "roof_top"
			rig.foot = ladder_base(rig)+(Vector3(.70,TOP,0) if on_roof else Vector3(-.85,0,0))
			ladder = -1.
			rig.camera_pitch = -.09
		"roof_shackle":
			slings |= open_side(rig)
			for i in chains.size(): chains[i].visible = (slings & (1 << i)) != 0
			rig.sound_event.emit("ratchet")
			if slings == 3:
				rig.phase = "rigged"
				rig.line_end = -1 if rig.flat_distance(rig.eyelet_point(-1),rig.drum_point())<rig.flat_distance(rig.eyelet_point(1),rig.drum_point()) else 1
				rig.show_note("Both wheel bridles pinned. Climb down to the hoist controls.",5.)
		"roof_boom": take_controls(rig)
		"roof_leave": release()
		_: rig.show_note(PROMPTS.get(id,""),4.)
	rig.update_eyes()

func hint(rig) -> String:
	if rig.special_work >= 1.: return "The sedan is on the loading apron. Winch it to the wheel-lift." if rig.phase=="rigged" else ""
	if controls: return instruction(rig)
	if ladder >= 0.: return "Use up and down to climb. Step off at either end of the ladder."
	if on_roof:
		return "Both bridles are pinned. Return to the west-edge ladder." if slings==3 else "Walk to each side of the sedan and pin the two wheel bridles."
	match rig.phase:
		"scene","flared": return "Park along the two stripes west of the canopy, hood west toward County K. Set a flare and plant the stabilizers at the side controls."
		"cable": return "Find ROOF ACCESS on the west edge of the canopy. The spreader is waiting over the sedan."
		"rigged": return "Take the boom controls at the truck's left side."
	return ""

func instruction(rig) -> String:
	if sweep>=1.: return "Lower into the chalk corners"
	if rig.car.position.y < rig.job_site.y+CLEARANCE-.01: return "Hoist clear of the canopy lip"
	return "Slew left over the loading apron"

func stroke(rig, move: Vector2, dt: float) -> void:
	var ground:float = rig.ground_height(SITE)
	var perch := ground+TOP
	var p: Vector3 = rig.car.position
	var drive := Vector2.ZERO if move.length()<.15 else move
	var used := minf(dt,float(rig.fuel)/rig.WINCH_FUEL_PER_SECOND)
	var floor_y := float(rig.ground_height(LANDING)) if sweep>=1. else (perch if sweep<=.001 else minf(p.y,perch+CLEARANCE))
	var height := clampf(p.y-drive.y*used*.96,floor_y,perch+1.55)
	var delta_sweep := -drive.x*used*.25
	if height >= perch+CLEARANCE-.01: sweep = clampf(sweep+delta_sweep,0.,1.)
	var pivot: Vector3 = rig.body.boom.global_position
	var from := Vector2(SITE.x-pivot.x,SITE.z-pivot.z)
	var to := Vector2(LANDING.x-pivot.x,LANDING.z-pivot.z)
	var angle := lerp_angle(from.angle(),to.angle(),sweep)
	var radius := lerpf(from.length(),to.length(),smoothstep(0.,1.,sweep))
	var at := Vector3(pivot.x+cos(angle)*radius,height,pivot.z+sin(angle)*radius)
	var was_working: bool = rig.working
	rig.working = at.distance_squared_to(p)>.00000001 and rig.fuel>0.
	if rig.working:
		if not was_working: rig.sound_event.emit("winch_start")
		rig.fuel = maxf(0.,rig.fuel-used*rig.WINCH_FUEL_PER_SECOND)
		rig.special_work = .01+sweep*.85
		rig.car.position = at
		rig.body.aim_boom(rig.car.to_global(Vector3.UP*4.05))
	rig.tension = move_toward(rig.tension,.55 if rig.working else 0.,dt*.8)
	if sweep>=1. and height<=floor_y+.012:
		rig.special_work = 1.
		release()
		rig.working = false
		rig.free_line = rig.flat_distance(rig.drum_point(),rig.eyelet_point(rig.line_end))+.30
		clear()
		rig.body.stow_boom()
		rig.sound_event.emit("ratchet")
		rig.show_note("On the apron. Winch the sedan to the wheel-lift.",5.)
	elif rig.fuel <= 0.:
		release()
		rig.working = false
		rig.show_note(rig.reserve_hint(),6.)

func lines(rig) -> void:
	rig.body.aim_boom(rig.car.to_global(Vector3.UP*4.05))
	rig.cable_strand(rig.body.boom_tip.global_position,rig.car.to_global(Vector3.UP*2.8))

func save_state() -> Dictionary:
	return {"ladder":ladder,"top":on_roof,"slings":slings,"sweep":sweep,"controls":controls,"watch":watch_load,"installed":installed}

func restore(rig, data: Dictionary) -> void:
	ladder = clampf(data.get("ladder",-1.),-1.,TOP)
	on_roof = data.get("top",false)
	slings = int(data.get("slings",0)) & 3
	sweep = clampf(data.get("sweep",0.),0.,1.)
	controls = data.get("controls",false) and rig.phase=="rigged" and not rig.in_cab and rig.fuel>0. and rig.special_work<1.
	watch_load = data.get("watch",true)
	if data.get("installed",false) and rig.special_work < 1.: install(rig)
