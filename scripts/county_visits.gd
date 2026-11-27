extends Node3D
## Paid county checks are offered beside the current tow. Findings belong to the accepted ticket.
const Sites := preload("res://scripts/county_sites.gd")
const Dryhouse := preload("res://scripts/ginseng_dryhouse.gd")
const CHECKS := {
	"parish":{"title":"Parish warming room","road":"County K","location":"St. Hedwig’s","point":Vector3(9,0,73),
		"dispatch":"The county garage has two stranded motorists warming up. Before I send them down to St. Hedwig's, can you find out if the side door is open?",
		"directions":"Take County K south of Main. Pull in before the church's twin steeples. There's a chalkboard out by the side entrance.",
		"steps":["Read the chalkboard beside the church walk.","Ask the volunteer at the lit side entrance if there’s room."],
		"actions":["Read the parish chalkboard","Ask if the warming room can take two"],"buttons":["READ BOARD","ASK"],
		"observations":["Chalk says WARM ROOM. Somebody added a fresh arrow toward the side entrance.","Two more? Send them. We've got four cots left and they can keep their bags with them."],
		"speaker":"PARISH VOLUNTEER","report":"Report four open cots","ack":"Copy, four cots at St. Hedwig's. I'll tell the garage to send those two to the side door. Thanks for asking.",
		"result":"Volunteer confirmed four open cots at the side entrance."},
	"landing":{"title":"Dam landing barrier","road":"Highway 64","location":"Dam landing","point":Vector3(-443,0,-32),
		"dispatch":"Somebody crossing the bridge saw stripes lying in the snow at the dam landing. Can you check whether the ice-closure barrier is still up?",
		"directions":"Take sixty-four west. Before the bridge, turn north at DAM LANDING. Stop on the bank at the striped barrier.",
		"steps":["Look at the striped barrier from the bank.","Lift the free end onto its catch. Stay on the shore."],
		"actions":["Inspect the fallen ice barrier","Hang the gate on its catch"],"buttons":["INSPECT","HANG GATE"],
		"observations":["Hinge is still together. Wind pushed the free end off its catch.","Pin’s seated. The orange stripes face the landing approach again."],
		"speaker":"BRANDT","report":"Report the gate secured","ack":"Copy, barrier up at the landing. I'll pass that to the dam tender. The entrance stays closed.",
		"result":"Closure gate rehung and pinned from the bank."},
	"dryhouse":{"title":"Lights at the dryhouse","road":"County K","location":"Duda Ginseng","point":Vector3(13,0,-212),
		"dispatch":"A driver saw amber flashes in the ginseng frames north of town. Roman's got a grading room over there. Can you find where they're coming from?",
		"directions":"Head north on K to Duda's green fire plate. Look along the wall with the wooden louvers, then check with Roman on the loading side.",
		"steps":["Find the flashing lamp on the drying shed and look at it.","Ask Roman at the scale what the amber lamp means."],
		"actions":["Watch the flashing wall lamp","Ask Roman about the grading-room lamp"],"buttons":["WATCH LAMP","ASK ROMAN"],
		"observations":["A steady pair of amber flashes. It’s a wall lamp beside the drying louvers.","That's my low-temperature lamp. Been back and forth to the woodpile since midnight. Appreciate somebody checking."],
		"speaker":"ROMAN DUDA","report":"Identify the amber lamp","ack":"Copy. It's the dryhouse temperature lamp, and Roman's there tending it. I'll close the caller's report.",
		"result":"Grower identified the grading-room temperature signal."},
}

var gate: Node3D
var beacon: Node3D
var glow: Node3D
var clock := 0.0
var flashing := false
var gate_target := 0.0
var flashes_seen := 0
var watching_lit := false

static func offer(seed_value: int, slips: Array, issued: int, declined_round: int) -> Dictionary:
	var ordinary := 0
	var last_round := -1
	for slip: Dictionary in slips:
		if slip.get("kind") == "field_visit":
			last_round = maxi(last_round,int(slip.get("visit_round",-1)))
		elif not slip.has("case_id") and slip.get("kind") in ["ditch","hazard","passenger"]:
			ordinary += 1
	if ordinary < 4 or (ordinary-4)%7 != 0 or ordinary in [last_round,declined_round]:
		return {}
	var id: String = CHECKS.keys()[posmod(seed_value+floori(float(ordinary-4)/7.),CHECKS.size())]
	var row: Dictionary = CHECKS[id]
	return {"kind":"field_visit","id":id,"site":id,"route":id,"visit_round":ordinary,"visit_step":0,
		"number":1001+issued,"point":row.point,"angle":0.0,"title":row.title,"road":row.road,
		"location":row.road+" · "+row.location,"vehicle":"County field visit","plate":"—","vin":"—",
		"dispatch":row.dispatch,"directions":row.directions,"schedule":0.0}

func setup(county) -> void:
	name = "PublicCountyChecks"
	var s = Sites.new(county,county.Batch.new(self,county.materials))
	# A volunteer can speak to callers from the sheltered side entrance.
	s.site(13.9,76.6,county.ground_height(13.9,76.6))
	s.b(0,2.65,0,3.4,.20,3.05,"oxide",true)
	s.b(0,2.80,0,3.5,.12,3.15,"snow")
	for side: float in [-1.,1.]:
		s.b(-1.49,1.26,side*1.27,.115,2.52,.115,"wood",true)
	s.b(.82,.48,0,1.08,.95,1.28,"wood",true)
	s.cyl(.8,1.14,.26,.29,.36,"silver")
	s.b(.96,1.20,.27,.18,.09,.10,"dark")
	s.b(.70,1.02,-.20,.17,.20,.18,"cream")
	s.b(-.10,2.47,-.12,.45,.14,.38,"lamp")
	# The side door opens off the public walk. Folded blankets sit beside the urn.
	s.b(1.66,1.17,1.17,.13,2.34,1.16,"cream")
	s.b(1.58,1.14,1.17,.06,2.23,1.02,"green")
	s.b(1.535,1.62,1.17,.042,.65,.62,"window")
	s.b(1.51,1.0,1.57,.09,.07,.13,"brass")
	for layer in 3:
		s.b(.52,1.01+.075*layer,-.34,.56,.067,.42,"silver" if layer==1 else "green")
	var helper: Node3D = county.Scene.person(self,false,0)
	helper.name = "WarmingRoomVolunteer"
	helper.position = point(county,"parish",1)-Vector3.UP
	helper.rotation.y = PI*.63
	s.origin = point(county,"parish",0)-Vector3.UP*1.12
	for side: float in [-.47,.47]:
		s.beam(Vector3(side,0,.28),Vector3(side,1.60,-.04),.075,.08,"wood")
		s.beam(Vector3(side,0,-.32),Vector3(side,1.60,-.04),.075,.08,"wood")
	s.placard(Vector3(0,1.22,.09),"WARM ROOM",1.24,.40,0,"green",true)
	s.placard(Vector3(0,.81,.10),"SIDE DOOR  →",1.24,.35,0,"dark",true)

	# The striped rail is hinged above the shoreline. Its handle stays on the dry bank.
	var bankside := Node3D.new()
	bankside.position = Vector3(-446.4,county.ground_height(-446.4,-35.5),-35.5)
	bankside.rotation.y = -PI*.5
	add_child(bankside)
	var posts = Sites.new(county,county.Batch.new(bankside,county.materials))
	posts.b(-1.45,.62,0,.25,1.25,.26,"wood",true)
	posts.b(1.55,.62,0,.23,1.25,.26,"wood",true)
	posts.b(1.55,1.18,0,.32,.12,.20,"post")
	posts.draw.finish()
	gate = Node3D.new()
	gate.name = "LandingClosureRail"
	gate.position = Vector3(-1.45,1.16,0)
	bankside.add_child(gate)
	var rail = Sites.new(county,county.Batch.new(gate,county.materials))
	rail.b(1.50,0,0,3.0,.22,.095,"cream")
	for i in 7:
		for side: float in [-1.,1.]:
			rail.draw.box(Vector3(.16+i*.43,0,.059*side),Vector3(.20,.23,.019),"oxide",false,Vector3(0,0,-.36))
	rail.placard(Vector3(1.5,-.23,.068),"ICE CLOSED",1.32,.30,0,"oxide",true)
	rail.draw.finish()

	# Twin flashes belong to the local thermostat, fixed to the real outside wall.
	beacon = Node3D.new()
	beacon.name = "DryhouseTemperatureLamp"
	beacon.position = point(county,"dryhouse",0)
	add_child(beacon)
	var alarm = Sites.new(county,county.Batch.new(beacon,county.materials))
	alarm.b(.03,0,0,.24,.48,.47,"dark")
	alarm.b(-.12,0,0,.14,.27,.29,"oxide")
	alarm.draw.finish()
	glow = Node3D.new()
	beacon.add_child(glow)
	var lens = Sites.new(county,county.Batch.new(glow,county.materials))
	lens.b(-.17,0,0,.12,.25,.25,"amber_lens")
	for yaw: float in [0.,PI*.5]:
		lens.draw.add("quad",Vector3(-.25,0,0),Vector3(2.3,2.3,1.0),"sodium",Vector3(0,yaw,0))
	lens.draw.finish()
	glow.hide()
	s.draw.finish()

static func point(county, id: String, step: int) -> Vector3:
	var xz: Vector2
	var height := 1.0
	match id:
		"parish":
			xz = Vector2(9.1,73.3) if step == 0 else Vector2(13.72,76.58)
			height = 1.12 if step == 0 else 1.0
		"landing":
			xz = Vector2(-446.2,-35.5) if step == 0 else Vector2(-446.1,-34.18)
			height = .53 if step == 0 else .73
		"dryhouse":
			if step == 1:
				return Dryhouse.grower_position(county)+Vector3.UP
			return Vector3(18.54,county.ground_height(23,-220)+3.42,-223.3)
	return Vector3(xz.x,county.ground_height(xz.x,xz.y)+height,xz.y)

func sync(ticket: Dictionary, snap := false) -> void:
	var id := str(ticket.get("id","")) if ticket.get("kind") == "field_visit" else ""
	flashing = id == "dryhouse"
	if id == "landing":
		gate_target = -.31 if int(ticket.get("visit_step",0)) < 2 else 0.0
	if snap:
		gate.rotation.z = gate_target
	if not flashing:
		flashes_seen = 0
		watching_lit = false

func advance(dt: float, game) -> void:
	gate.rotation.z = move_toward(gate.rotation.z,gate_target,dt*.85)
	if game.rig.get_player_position().distance_squared_to(beacon.global_position) > 115.*115.:
		glow.hide()
		flashes_seen = 0
		watching_lit = false
		return
	clock = fmod(clock+dt,2.25)
	glow.visible = clock < .20 or (clock >= .34 and clock < .57)
	var watching := flashing and int(game.job.get("visit_step",0)) == 0 and step_in_reach(game)
	if not watching:
		flashes_seen = 0
	elif glow.visible and not watching_lit:
		flashes_seen = mini(2,flashes_seen+1)
	watching_lit = watching and glow.visible

static func step_in_reach(game) -> bool:
	var ticket: Dictionary = game.job
	if ticket.get("kind") != "field_visit" or game.rig.in_cab or int(ticket.visit_step) >= 2:
		return false
	var id: String = ticket.id
	var step := int(ticket.visit_step)
	var reach := 23.0 if id == "dryhouse" and step == 0 else 3.15
	var target := point(game.county,id,step)
	var eye: Camera3D = game.rig.get_camera()
	var ray := target-eye.global_position
	return ray.length() < reach and ray.normalized().dot(-eye.global_basis.z) > (.93 if reach > 4 else .62) and game.rig.cast_ray(eye.global_position,target).is_empty()

static func instruction(ticket: Dictionary) -> String:
	var step := int(ticket.get("visit_step",0))
	return "Return to the cab radio and report what you found." if step >= 2 else str(CHECKS[ticket.id].steps[step])
