extends "res://scripts/recovery_levers.gd"
## A two-axis hydraulic control and a ground-reachable sling for the Swamp Road car.

const Kit := preload("res://scripts/rig_mesh.gd")
const SITE := Vector3(207,2.44,-409)
const LIMB_CLEARANCE := .65
const HOIST_MPS := .85
const SWING_MPS := 1.45

var block_set := false
var sling: Node3D
var eye := Vector3.ZERO

# A bare tamarack fork stands on each side of the sedan. Snow caught on the
# flat tops makes the clearance visible in the truck's work light.
static func grow_grove(draw, county) -> void:
	for side: float in [-1.,1.]:
		var root := Vector3(SITE.x+side*1.52,0,SITE.z-.45)
		root.y = county.ground_height(root.x,root.z)
		var crotch := root+Vector3(side*.13,1.53,0)
		var spine := crotch+Vector3(side*.56,1.83,-.1)
		draw.beam(root,crotch,.24,.20,"wood")
		draw.beam(crotch,spine,.16,.14,"wood")
		for tier in 4:
			var base: Vector3 = root.lerp(spine,.25+.18*tier)
			for branch: float in [-1.,1.]:
				var fork := base+Vector3(-side*(.55+.07*tier),.20,branch*(.59+.12*tier))
				var tip := fork+Vector3(-side*.17,.20,branch*.38)
				draw.beam(base,fork,.11,.12,"wood")
				draw.beam(fork,tip,.072,.07,"wood")
				draw.beam(base+Vector3.UP*.057,fork+Vector3.UP*.057,.07,.035,"snow")
				draw.beam(fork,fork+Vector3(side*.28,.30,branch*.34),.045,.04,"wood")
		var leader := spine+Vector3(side*.38,1.52,-.49)
		draw.beam(spine,leader,.10,.09,"wood")
		draw.beam(leader,leader+Vector3(side*.25,.46,.06),.05,.05,"wood")

func deploy(rig) -> void:
	clear_sling()
	var side: float = signf(rig.car.to_local(rig._drum()).x)
	var point: Vector3 = rig.car.to_global(Vector3((-1. if side == 0. else side)*1.66,0,1.26))
	eye = Vector3(point.x,rig._ground(point)+.9,point.z)
	sling = Kit.joint(rig,eye,"SlingTail")
	var mesh = Kit.new(sling)
	var upper: Vector3 = rig.car.to_global(Vector3(0,1.7,.2))-eye
	mesh.beam(upper,Vector3(-.09,.18,0),.061,.025,Color("#ca8b3e"))
	mesh.beam(upper+Vector3(.13,0,.05),Vector3(.09,.18,0),.061,.025,Color("#d99447"))
	mesh.ring(Vector3(0,.12,0),.077,.112,Color("#b7ada0"),Vector3(PI*.5,0,0))
	mesh.finish()

func clear_sling() -> void:
	if is_instance_valid(sling):
		sling.hide()
		sling.queue_free()
	sling = null

func action(rig, at_panel: bool) -> String:
	if controls: return "tree_leave"
	if rig.phase == "cable":
		if not block_set and rig._in_range(eye,2.1):
			return "tree_block"
		if at_panel: return "tree_boom" if block_set else "restow"
	if rig.phase == "rigged" and rig.special_work < 1.0 and at_panel: return "tree_boom"
	return ""

func engage(rig) -> void:
	clear_sling()
	take_controls(rig)
	rig.phase = "rigged"
	rig.line_end = rig._nearest_eyelet()
	rig.sound_event.emit("lift")

func instruction(rig) -> String:
	var landing: Vector3 = rig._boom_landing()
	if rig._flat_distance(rig.car.position,landing) < .6: return "Lower to the snow"
	var perch := float(rig._ground(rig.job_site)) + (float(rig.job_site.y) if rig.job_site.y > 0. else 5.)
	if rig.car.position.y < perch + LIMB_CLEARANCE - .015: return "Raise clear of the limbs"
	return "Swing in over the verge"

func stroke(rig, move: Vector2, dt: float) -> void:
	var landing: Vector3 = rig._boom_landing()
	var start: Vector3 = rig.job_site
	start.y = rig._ground(start) + (start.y if start.y > 0. else 5.)
	var axis := Vector3(landing.x-start.x,0,landing.z-start.z)
	var reach := axis.length()
	if reach <= .01: return
	axis /= reach
	var car: Vector3 = rig.car.position
	var travel := clampf((car-start).dot(axis),0.,reach)
	var clear_height := start.y + LIMB_CLEARANCE
	var drive := Vector2.ZERO if move.length() < .15 else move
	# The crowns support the load until the underbody clears them. A blocked
	# stroke holds the car. Releasing either lever also holds its position.
	var used_dt := minf(dt,float(rig.fuel)/rig.WINCH_FUEL_PER_SECOND)
	var vertical := -drive.y * HOIST_MPS * used_dt
	var height := clampf(car.y+vertical,landing.y,start.y+1.35)
	if travel < reach-.6:
		height = maxf(height,start.y if travel < .08 else minf(car.y,clear_height))
	if height >= clear_height-.015:
		travel = clampf(travel+drive.x*SWING_MPS*used_dt,0.,reach)
	var next := start+axis*travel
	next.y = height
	var moved := car.distance_squared_to(next) > .00000001
	if moved:
		rig.fuel = maxf(0.,float(rig.fuel)-used_dt*rig.WINCH_FUEL_PER_SECOND)
		if not rig.working: rig.sound_event.emit("winch_start")
		rig.car.position = next
		rig.special_work = maxf(float(rig.special_work),.01)
	rig.working = moved and rig.fuel > 0.
	rig.tension = move_toward(rig.tension,.65 if rig.working else 0.,dt*.65)
	if travel >= reach-.6 and height <= landing.y+.01:
		rig.special_work = 1.
		release()
		rig.working = false
		rig.free_line = rig._flat_distance(rig._drum(),rig._eyelet(rig.line_end))+.30
		rig.body.stow_boom()
		rig.sound_event.emit("ratchet")
		rig._note("All four wheels on the snow. Winch to the underlift.",6)
	elif rig.fuel <= 0:
		release()
		rig.working = false
		rig._note(rig.reserve_hint(),6)
