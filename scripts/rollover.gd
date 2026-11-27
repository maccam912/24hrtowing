extends "res://scripts/recovery_levers.gd"
## The main drum raises the load up to its balance point. The brake holds it
## there while the operator pays out the check line on the other drum.

const HAYFIELD := Vector3(374,0,182)
var fetched := false
var check_cleared := false
var preload_fraction := 0.

static func hayfield(draw, county) -> void:
	# Three old corner posts extend from the road into the hay. Leave an
	# open path alongside them for the wrecker and its cable.
	for i in 3:
		var at := HAYFIELD + Vector3(4.+7.*i,0,4.8)
		at.y = county.ground_height(at.x,at.z)
		draw.box(at+Vector3.UP*.54,Vector3(.16,1.08,.16),"wood",true,Vector3(0,0,.045*i))
		draw.box(at+Vector3.UP*1.09,Vector3(.18,.05,.18),"snow")
	for i in 24:
		var at := HAYFIELD + Vector3(cos(i*2.3)*(3.8+i*.49),0,sin(i*2.3)*(4.+i*.43))
		at.y = county.ground_height(at.x,at.z)
		draw.beam(at,at+Vector3(.07,.23,0),.035,.026,"stripe")
		draw.beam(at+Vector3.RIGHT*.12,at+Vector3(.01,.16,.07),.032,.026,"wood")
	for i in 2:
		var at := HAYFIELD + Vector3(-14.-3.*i,0,8.5-i*3.)
		at.y = county.ground_height(at.x,at.z)+.68
		draw.add("cylinder",at,Vector3(1.39,1.60,1.39),"stripe",Vector3(0,.1,PI*.5))
		draw.add("mound",at+Vector3.UP*.47,Vector3(1.61,.46,.98),"snow")

func axle_eye(rig, side: float) -> Vector3:
	var offset := Vector3(-side*.9,.50,.35)
	if rig.recovery_kind() == "nose":
		offset = Vector3(side*.72,.45,-side*1.42)
	return rig.car.to_global(offset)

func draw_lines(rig) -> void:
	var main := axle_eye(rig,-1.)
	var check := axle_eye(rig,1.)
	var aux: Vector3 = rig.body.to_global(Vector3(.87,1.97,4.10))
	var hand: Vector3 = rig.eyes.global_transform*Vector3(.25,-.32,-.46)
	if rig.phase == "cable":
		rig.cable_strand(main,rig.side_eye(-1.))
		rig.cable_strand(check,rig.side_eye(1.))
		main = rig.side_eye(-1.) if rig.second_line else hand
		check = hand if fetched else aux
	rig.pulley.global_position = main
	rig.cable_strand(rig.drum_point(),main)
	rig.cable_strand(rig.body.to_global(Vector3(-.81,1.65,3.28)),main+Vector3.UP*.09)
	if fetched:
		rig.cable_strand(aux,check)

func action(rig, panel: bool) -> String:
	if controls: return "roll_leave"
	if rig.phase == "rigged" and rig.special_work >= 1. and not check_cleared:
		if rig.in_range(rig.side_eye(1.),2.3): return "roll_clear"
		if panel: return "roll_hold"
	if rig.phase == "cable" and rig.second_line and not fetched:
		return "roll_fetch" if panel else ""
	if rig.phase == "rigged" and rig.special_work < 1. and panel:
		return "roll_levers"
	return ""

func instruction(rig) -> String:
	if preload_fraction < 1.: return "Take the slack out of the check line"
	if rig.special_work < .5:
		return "Draw the rear axle over" if rig.recovery_kind()=="nose" else "Roll onto the near-side tires"
	return "Ease the check line to set it upright"

func stroke(rig, move: Vector2, dt: float) -> void:
	if not rig.second_winch or not rig.snatch_block:
		release()
		rig.working = false
		return
	var used_dt := minf(dt,float(rig.fuel)/rig.WINCH_FUEL_PER_SECOND)
	var command := move if move.length() > .15 else Vector2.ZERO
	var old_preload := preload_fraction
	var old_progress := float(rig.special_work)
	if preload_fraction < 1.:
		preload_fraction = minf(1.,preload_fraction+maxf(0.,-command.x)*used_dt*.58)
	elif rig.special_work < .5:
		rig.special_work = minf(.5,rig.special_work+maxf(0.,-command.y)*used_dt*.15)
	else:
		rig.special_work = minf(1.,rig.special_work+maxf(0.,command.y)*used_dt*.115)
	var moved: bool = preload_fraction != old_preload or rig.special_work != old_progress
	if moved:
		rig.fuel = maxf(0.,rig.fuel-used_dt*rig.WINCH_FUEL_PER_SECOND)
		if not rig.working: rig.sound_event.emit("winch_start")
		rig.pose_roll(rig.special_work)
	rig.working = moved and rig.fuel > 0.
	rig.tension = move_toward(rig.tension,(.49+.25*sin(PI*rig.special_work)) if moved else 0.,dt*.65)
	if rig.special_work >= 1.:
		release()
		rig.working = false
		rig.free_line = rig.flat_distance(rig.drum_point(),rig.eyelet_point(rig.line_end))+.30
		rig.sound_event.emit("ratchet")
		rig.show_note("Both axles down. Unpin the check line on the far side.",6.)
	elif rig.fuel <= 0.:
		release()
		rig.working = false
		rig.show_note(rig.reserve_hint(),6.)
