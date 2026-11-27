extends RefCounted
## Above the spillway the east-bank landing is firm enough for the wrecker.
## The ice-side cable can still be carried out and the car can be left at rest.

const EAST_EDGE := -449.
const WEST_EDGE := -501.
const ROAD_X := -434.
const LANDING := Rect2(-449.,-163.,29.,46.)
const MAX_LINE := 52.
const FEET_PER_METRE := 3.28084
var west_salvage := false
var creep := false
var lip := false
var seated := false
var eased := 0.
var cable_out := 0.
var markers: MultiMeshInstance3D
var end_reached := false

static func on_flowage(point: Vector3) -> bool:
	return point.x > WEST_EDGE-1. and point.x < EAST_EDGE+1. and point.z < -108.

static func mark_ice(draw,county) -> void:
	for i in 9:
		var hub := Vector2(-481.+sin(i*2.4)*10.,-118.-i*9.)
		var edge := 4.1+fmod(i*2.83,5.)
		var pts := []
		for k in 4:
			var x: float = hub.x + [-1.,.74,1.12,-.81][k]*edge
			var z: float = hub.y + [-.6,-.85,.40,.78][k]*edge
			pts.append(Vector3(x,county.ground_height(x,z)+.045,z))
		draw.quad(pts[0],pts[1],pts[2],pts[3],"flowage_ice")
	for i in 3:
		var start := Vector3(-492.+i*4.,-1.94,-125.-i*15.)
		for seam in 5:
			var end := start+Vector3(2.5+sin(i+seam),.001,cos(i*3+seam)*1.9)
			draw.beam(start,end,.042,.024,"slush")
			start = end

func fit_marks(rig) -> void:
	markers = MultiMeshInstance3D.new()
	markers.name = "FootageMarks"
	var tape := BoxMesh.new()
	tape.size = Vector3(.17,.047,.11)
	var coating := StandardMaterial3D.new()
	coating.vertex_color_use_as_albedo = true
	tape.material = coating
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = tape
	batch.instance_count = floori(MAX_LINE*FEET_PER_METRE/10.)
	batch.visible_instance_count = 0
	for i in batch.instance_count:
		batch.set_instance_color(i,Color("#e9a651") if (i+1)%5 else Color("#e8dfc5"))
	markers.multimesh = batch
	markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(markers)

func mark_line(rig, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var count := mini(markers.multimesh.instance_count,floori(length*FEET_PER_METRE/10.))
	var sag := clampf(length*.05,.07,1.25)*(1.-float(rig.tension)*.83)
	for i in count:
		var fraction := 10.*float(i+1)/FEET_PER_METRE/length
		var point := a.lerp(b,fraction)
		point.y = maxf(rig.ground_height(point)+.065,point.y-sin(fraction*PI)*sag)
		markers.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
	markers.multimesh.visible_instance_count = count
	if rig.phase == "cable": cable_out = maxf(cable_out,minf(length,MAX_LINE))

func limit_hook_walk(rig, from: Vector3, next: Vector3) -> Vector3:
	var drum: Vector3 = rig.drum_point()
	var before := Vector2(from.x-drum.x,from.z-drum.z)
	var proposed := Vector2(next.x-drum.x,next.z-drum.z)
	# Leave room for the hook in the operator's hands and the slope down to
	# the ice. An older position outside the radius can always walk back.
	var rise: float = rig.ground_height(next)+1.2-drum.y
	var reach := sqrt(maxf(1.,MAX_LINE*MAX_LINE-rise*rise))-.45
	if proposed.length() <= reach:
		if proposed.length() < reach-.8: end_reached = false
		return next
	if proposed.length_squared() <= before.length_squared(): return next
	if not end_reached:
		end_reached = true
		rig.show_note("End of the drum. Walk the hook back toward the truck.",4.)
	var edge := proposed.limit_length(maxf(before.length(),reach))
	return Vector3(drum.x+edge.x,next.y,drum.z+edge.y)

func supported(rig) -> bool:
	# Test both tandem and front tires. A dry driver's door can still leave
	# the opposite side of a crooked wrecker standing on the ice.
	for z: float in [rig.Truck.FRONT_AXLE_Z,rig.Truck.LAST_DRIVE_Z]:
		for x: float in [-1.23,1.23]:
			var wheel: Vector3 = rig.truck.to_global(Vector3(x,0,z))
			if west_salvage:
				if wheel.x > WEST_EDGE-.25 or absf(wheel.z-rig.job_site.z)>44.: return false
			elif not LANDING.has_point(Vector2(wheel.x,wheel.z)): return false
	var pull: Vector3 = rig.car.position-rig.drum_point()
	pull.y = 0.
	# An almost-loaded vehicle may already be at the tail of an old rig.
	return pull.length() < 2.5 or rig.truck.global_basis.z.dot(pull.normalized()) > .66

func setup_note() -> String:
	return "Use the solid west bank nearest the partly recovered car. Point the rear drum at the sedan." if west_salvage else "Take River Rd north from the east end of the Highway 64 bridge. Park all six wheels on the marked landing, rear drum toward the ice."

func action(rig, panel: bool) -> String:
	if not panel: return ""
	match rig.phase:
		"flared":
			if not supported(rig): return "ice_bank"
		"cable","rigged":
			if not supported(rig): return "ice_repack"
			if rig.phase == "rigged" and not creep: return "ice_creep"
	return ""

func meter(rig) -> String:
	if rig.phase == "cable":
		return "%d FT MARK" % (10*floori(cable_out*FEET_PER_METRE/10.))
	if not creep: return "SELECT CREEP"
	if lip and not seated: return "EASE THE DRUM"
	return "BANK SEATED" if seated else "CREEP"

func prepare(rig, operate: bool, dt: float) -> bool:
	if rig.phase != "rigged": return true
	if not creep or not supported(rig): return false
	var nearest_tire: float = rig.car.position.x + (-1. if west_salvage else 1.) * 1.6
	var at_lip := nearest_tire <= WEST_EDGE+2.4 if west_salvage else nearest_tire >= EAST_EDGE-2.4
	if not seated and at_lip:
		if not lip:
			lip = true
			rig.show_note("First tires at the ice lip. Release the winch to let them settle.",5.)
		if operate:
			eased = 0.
		else:
			eased = minf(.48,eased+dt)
			if eased >= .48:
				seated = true
				rig.show_note("Tires seated on the bank. Take it slowly to the lift.",4.)
		return seated
	return true

func save_state() -> Dictionary:
	return {"west":west_salvage,"creep":creep,"lip":lip,"seated":seated,"eased":eased,"out":cable_out}

func restore(rig, data: Dictionary) -> void:
	# A previous version allowed winching toward either bank. If an old pull
	# is already beyond the east landing's reach, finish on solid west ground.
	west_salvage = data.get("west",rig.phase in ["cable","rigged"] and rig.car.position.x < -493. and rig.truck.position.x < -482.)
	creep = data.get("creep",false)
	lip = data.get("lip",false)
	seated = data.get("seated",false)
	eased = clampf(data.get("eased",0.),0.,.48)
	cable_out = clampf(data.get("out",0.),0.,MAX_LINE)
