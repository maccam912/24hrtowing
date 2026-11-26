extends RefCounted
## A stationary snatch block sends the effort around the end of an existing field fence.
const Kit := preload("res://scripts/rig_mesh.gd")
const SITES := [
	{"road_x":0., "gate_z":337., "opening":1., "road":"County K","landmark":"south pasture gate","site":"k_pasture",
	 "directions":"Head south on K, past St. Hedwig’s. Look on the left before Hendricks where the east pasture fence ends."},
	{"road_x":400., "gate_z":490., "opening":-1., "road":"Kolpack Rd","landmark":"north hay gate","site":"kolpack_pasture",
	 "directions":"Follow Kolpack south across Hendricks. Look on the left where the west end of the hay lane meets the road."}
]
const ANCHORS := [Vector2(7.6,12.),Vector2(9.9,16.8)]
const FENCE_X := 13.
const EYE_HEIGHT := .84
const BLOCK_CLEARANCE := 2.6
var site: Dictionary
var selected := -1
var easing := false
var route_used := false
var sling: Node3D

func _init(index: int) -> void:
	site = SITES[clampi(index,0,SITES.size()-1)]

static func point(spec: Dictionary, x: float, z: float) -> Vector3:
	return Vector3(float(spec.road_x)+x,0,float(spec.gate_z)+z*float(spec.opening))

static func ticket(issued: int, seed_value: int, count: int) -> Dictionary:
	var index := posmod(seed_value+count,SITES.size())
	var spec: Dictionary = SITES[index]
	var number := 1001+issued
	var driver := "Calf feeder" if index==0 else "Hay hauler"
	var vehicle := "Gray station wagon" if index==0 else "Brown sedan"
	return {"id":"pasture_pull","kind":"ditch","route":spec.site,"site":spec.site,"number":number,
		"field_gate":index,"point":point(spec,18.8,-7.4),"angle":PI if float(spec.opening)>0 else 0.,
		"variant":2 if index==0 else 1,"driver_variant":index,"road":spec.road,"shoulder":"east","location":spec.road+" · "+spec.landmark,
		"vehicle":vehicle,"person":driver,"reply":"dairy_hand" if index==0 else "shift_worker","plate":"EGK %03d" % posmod(number*17+seed_value,1000),
		"vin":"1G2NE55M6TC%06d" % posmod(number*529+seed_value,1000000),"schedule":snappedf((spec.road_x+absf(spec.gate_z))/400.,.1),
		"dispatch":"%s off %s at the %s. It went through the opening and slid behind the wire. Driver wants it back on the road. Bring a tree strap and your block." % [vehicle,spec.road,spec.landmark],
		"directions":spec.directions,"driver_line":"The gate was open when I slid through. That corner’s the only way out. Can you leave the wire standing?"}

static func limb(draw, a: Vector3, b: Vector3, thick: float, thin: float, sides := 7) -> void:
	var axis := (b-a).normalized()
	var across := axis.cross(Vector3.FORWARD).normalized()
	var around := axis.cross(across)
	for face in sides:
		var angle := TAU*face/sides
		var next := TAU*(face+1)/sides
		var r := across*cos(angle)+around*sin(angle)
		var r_next := across*cos(next)+around*sin(next)
		draw.quad(a+r*thick,b+r*thin,b+r_next*thin,a+r_next*thick,"wood")

static func grow(county, draw) -> void:
	for spec: Dictionary in SITES:
		for i in ANCHORS.size():
			var offset: Vector2 = ANCHORS[i]
			var base := point(spec,offset.x,offset.y)
			base.y = county.ground_height(base.x,base.z)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(base.z)*79+i
			var tilt := Vector3(rng.randf_range(-.18,.18),0,rng.randf_range(-.18,.18))
			var fork := base+Vector3.UP*(2.9+.36*i)+tilt
			var leader := fork+Vector3(.22,1.84,-.19)
			var crown := leader+Vector3(-.4,1.45,.30)
			limb(draw,base-Vector3.UP*.12,fork,.375,.275,10)
			limb(draw,fork,leader,.275,.19)
			limb(draw,leader,crown,.19,.10)
			limb(draw,crown,crown+Vector3(.36,1.40,-.22),.10,.018)
			draw.solid_box(base+Vector3.UP*1.25,Vector3(.64,2.5,.59))
			for root in 5:
				var radial := Vector3.RIGHT.rotated(Vector3.UP,root*TAU/5+.55*i)
				limb(draw,base+Vector3.UP*.34+radial*.18,base+radial*.68-Vector3.UP*.04,.14,.045)
			for branch in 9:
				var direction := branch*2.4+rng.randf_range(-.38,.38)+i
				var outward := Vector3.RIGHT.rotated(Vector3.UP,direction)
				var across := outward.rotated(Vector3.UP,PI/2)
				var collar := fork.lerp(crown,branch/10.)
				var length := lerpf(2.6,1.1,branch/9.)*rng.randf_range(.8,1.17)
				var elbow := collar+outward*length+Vector3.UP*rng.randf_range(.63,1.4)
				var wrist := elbow+outward*length*.47+across*rng.randf_range(-.5,.5)+Vector3.UP*rng.randf_range(.5,1.2)
				limb(draw,collar,elbow,.15-branch*.008,.08)
				limb(draw,elbow,wrist,.084,.044)
				draw.beam(collar.lerp(elbow,.15)+Vector3.UP*.11,elbow+Vector3.UP*.075,.054,.035,"snow")
				for twig in 3:
					var seed := elbow.lerp(wrist,twig*.47)
					var turn := outward.rotated(Vector3.UP,rng.randf_range(-1.15,1.15))
					var joint := seed+turn*rng.randf_range(.34,.79)+Vector3.UP*rng.randf_range(.3,.8)
					var tip := joint+turn*rng.randf_range(.36,.75)+Vector3.UP*rng.randf_range(.4,1.1)
					limb(draw,seed,joint,.042,.025,5)
					limb(draw,joint,tip,.026,.009,5)
					limb(draw,joint,joint+across*rng.randf_range(-.5,.5)+Vector3.UP*.49,.021,.008,5)

func anchor(rig, index: int) -> Vector3:
	var offset: Vector2 = ANCHORS[index]
	var root := point(site,offset.x,offset.y)
	return Vector3(root.x+.34,rig._ground(root)+EYE_HEIGHT,root.z)

func cuts_wire(a: Vector3, b: Vector3, clearance := .0) -> bool:
	var fence := float(site.road_x)+FENCE_X
	if minf(a.x,b.x)>fence+clearance or maxf(a.x,b.x)<fence-clearance: return false
	# The car's width needs space at the corner even where a bare line fits.
	var fraction := clampf((fence-a.x)/(b.x-a.x),0.,1.) if absf(b.x-a.x)>.001 else .5
	var where := lerpf(a.z,b.z,fraction)
	return (where-float(site.gate_z))*float(site.opening) < clearance

func clear_anchor(rig, index: int) -> bool:
	var tree := anchor(rig,index)
	var eye: Vector3 = rig._eyelet(rig.line_end if rig.phase=="rigged" else -1)
	return not cuts_wire(rig._drum(),tree) and not cuts_wire(rig.car.position,tree,1.55) and rig._drum().distance_to(tree)+tree.distance_to(eye)<=rig.CABLE_REACH

func direct(rig) -> bool:
	return not cuts_wire(rig.car.position,rig._drum(),1.55)

func nearby(rig) -> int:
	for i in ANCHORS.size():
		if rig._in_range(anchor(rig,i),2.15): return i
	return -1

func at_post(rig) -> bool:
	var post := point(site,FENCE_X,0.)
	post.y=rig._ground(post)+.9
	return rig._in_range(post,1.7)

func action(rig, panel: bool) -> String:
	if rig.phase=="flared" and panel:
		if rig._road(rig._drum())>5.2: return "field_park"
		if not rig.snatch_block and not direct(rig): return "field_stock"
	if rig.phase=="cable":
		var tree := nearby(rig)
		if tree>=0 and rig.snatch_block:
			if selected==tree: return "field_unwrap"
			return "field_wrap" if clear_anchor(rig,tree) else "field_reach"
		if at_post(rig): return "field_post"
		if rig._in_range(rig._eyelet(rig._nearest_eyelet()),2.45):
			if selected<0 and not direct(rig): return "field_fence"
			if selected>=0 and rig._drum().distance_to(anchor(rig,selected))+anchor(rig,selected).distance_to(rig._eyelet(rig._nearest_eyelet()))>rig.CABLE_REACH: return "field_reach"
	elif rig.phase=="rigged" and selected<0 and panel and rig._flat_distance(rig._eyelet(rig.line_end),rig._drum())<1.3 and rig._road(rig.car.position)>=4.55:
		return "field_more_road"
	elif rig.phase=="rigged" and easing:
		if nearby(rig)==selected: return "field_transfer" if direct(rig) else "field_restow"
		if panel: return "field_clear"
	return ""

func prompt(id: String) -> String:
	match id:
		"field_wrap": return "Wrap the tree strap and reeve the snatch block"
		"field_unwrap": return "Take the strap and block to another anchor"
		"field_reach": return "Both lengths of cable must reach. Move the truck closer to the opening."
		"field_fence": return "A straight pull catches the fence. Route the block through the opening or reposition the truck."
		"field_park": return "Keep the drum on the road side of the ditch."
		"field_more_road": return "Line is in. Unhook at the car and move the truck farther onto the road."
		"field_stock": return "Take a clear straight pull through the opening, or bring the block."
		"field_post": return "Loose fence post. The hardwoods beside the gate will hold the strap."
		"field_transfer": return "Remove the slack block and run the line straight to the truck"
		"field_restow": return "Remove the block and stow the slack line to reposition the truck"
		"field_clear": return "Line slack at the tree. Walk to the block to change the pull."
	return ""

func hint(rig) -> String:
	if easing: return prompt("field_clear")
	if rig.phase=="flared": return "Leave the truck on the firm shoulder beside the gate. Take the line at the left rear panel."
	if rig.phase=="cable" and selected<0 and not direct(rig): return "Walk the cable around the wire. Wrap one of the hardwoods at the opening, then hook the car."
	if rig.phase=="cable" and selected>=0: return "Carry the free end from the block through the opening to a tow eye."
	if rig.phase=="rigged" and selected>=0: return "Reel from the side panel until the car clears the post. The line will stop short of the tree."
	return ""

func marker(rig) -> Vector3:
	if easing: return anchor(rig,selected)
	if selected>=0 or direct(rig): return rig._eyelet(rig._nearest_eyelet())
	var best := Vector3.INF
	for i in ANCHORS.size():
		var root := anchor(rig,i)
		if clear_anchor(rig,i) and (not best.is_finite() or rig.foot.distance_squared_to(root)<rig.foot.distance_squared_to(best)): best=root
	return best

func remove_webbing() -> void:
	if is_instance_valid(sling):
		sling.hide()
		sling.queue_free()
	sling = null
	selected = -1

func fit_strap(rig, index: int) -> void:
	remove_webbing()
	selected=index
	sling=Kit.joint(rig,anchor(rig,index),"FieldTreeStrap")
	var kit:=Kit.new(sling)
	var start:=Vector3(.02,0,.1)
	for i in 12:
		var angle:=TAU*(i+1)/12.
		var end:=Vector3(-.34+.39*cos(angle),sin(angle)*.035,.37*sin(angle))
		kit.beam(start,end,.095,.047,Color("#bd8745"))
		start=end
	kit.ring(Vector3(.06,-.02,0),.07,.10,Color("#a3aaa6"),Vector3(PI/2,0,0))
	kit.finish()

func handle(rig, id: String) -> void:
	match id:
		"field_wrap":
			fit_strap(rig,nearby(rig))
			rig.sound_event.emit("ratchet")
			rig._note("Tree strap snug. Carry the hook on to the car.",5.)
		"field_unwrap": remove_webbing()
		"field_transfer":
			remove_webbing()
			easing=false
			rig.free_line=rig._flat_distance(rig._drum(),rig._eyelet(rig.line_end))+.45
			rig.sound_event.emit("ratchet")
			rig._note("Straight line clear. Finish the pull from the side panel.",5.)
		"field_restow":
			remove_webbing()
			easing=false
			rig.phase="flared"
			if rig.chocks: rig.chocks.queue_free()
			rig.chocks=null
			rig.tension=0.
			rig._note("Line stowed. Move the truck where the cable clears the end post.",5.)
		_: rig._note(prompt(id),5.)

func lines(rig) -> void:
	var sheave := anchor(rig,selected)
	var end: Vector3 = rig._eyelet(rig.line_end) if rig.phase=="rigged" else rig.eyes.to_global(Vector3(.25,-.32,-.46))
	rig.pulley.global_position = sheave
	rig.pulley.rotation.y = atan2(end.x-sheave.x,end.z-sheave.z)
	rig._cable_strand(rig._drum(),sheave+rig.pulley.global_basis.x*.065)
	rig._cable_strand(sheave-rig.pulley.global_basis.x*.065,end)
