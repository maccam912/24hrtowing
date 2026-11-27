extends RefCounted
## Ground, frozen crest and cribbing use the same footprint as the rendered plow ridge.
const Kit := preload("res://scripts/rig_mesh.gd")
const Wheels := preload("res://scripts/road_wheels.gd")
const CRIB_RUN := 1.48
const CREST := .59
const PAN_CLEARANCE := .26
const SITES := [
	{"road":"Hendricks Rd","site":"dairy","entrance":"milk_lane_berm","shoulder":"south","station":[94.,400.],"landmark":"Brzezinski milk lane","point":Vector3(94,0,405.6),"angle":0.,
	 "directions":"Go south on K to Hendricks, then east to Brzezinski. Check the short milk drive just beyond the barns’ west corner."},
	{"road":"Kolpack Rd","site":"farm","entrance":"farm_lane_berm","shoulder":"east","station":[400.,246.],"landmark":"Lindquist field entrance","point":Vector3(406.4,0,246.),"angle":PI/2.,
	 "directions":"Take sixty-four east to Kolpack, then south to the Lindquist silo. The car is on the east side in the farm drive."}
]
var ground: Callable
var patch: Node3D
var car: Node3D
var wheels: Wheels
var high_end: int
var inspected := false
var collected := false
var placed := 0
var cleared := false
var used_blocks := false
var blocked := false
var heights := PackedFloat32Array([.3,.3])
var wedges: Array[Node3D] = []
var rack: Node3D
var bundle: Node3D
var warning_left := 0.
static var windpack: StandardMaterial3D

static func ticket(issued: int, seed_value: int, prior: int) -> Dictionary:
	var index := posmod(seed_value+prior,2)
	var site: Dictionary = SITES[index]
	var number := 1001+issued
	var vehicle := "Tan four-door sedan" if index==0 else "Gray station wagon"
	return {"id":"high_center","kind":"hazard","route":site.site,"site":site.site,"run":site.entrance,"road_station":site.station,"shoulder":site.shoulder,"reply":"clear","number":number,"point":site.point,"angle":site.angle,
		"vehicle":vehicle,"variant":3 if index==0 else 2,"driver_variant":index,"road":site.road,"location":site.road+" · "+site.landmark,
		"field_berm":-1 if index==0 else 1,"plate":"FHN %03d" % posmod(number*11,1000),"vin":"1G4HP52K4VH%06d" % posmod(number*331+seed_value,1000000),
		"schedule":snappedf((site.point.x+absf(site.point.z))/400.,.1),
		"dispatch":"%s across the plow ridge at the %s, %s side of %s. The deputy checked it and the driver got a ride. Bring it to storage and leave the lane open." % [vehicle,site.landmark,site.shoulder,site.road],
		"directions":"%s Look for the %s on the %s side." % [site.directions,vehicle.to_lower(),site.shoulder]}

func _init(model: Node3D, end: int, terrain: Callable) -> void:
	car = model
	high_end = 1 if end>0 else -1
	ground = terrain
	wheels = car.get_node("RoadWheels")
	patch = Kit.joint(car,Vector3.ZERO,"FrozenWindrow")
	patch.top_level = true
	patch.global_position = Vector3(car.position.x,0,car.position.z)
	patch.rotation.y = car.rotation.y
	_shape_ridge()
	settle()
	for i in 2:
		var wheel: Vector3 = wheel_point(i)
		heights[i] = clampf(wheel.y-wheels.radius-float(ground.call(wheel))+.018,.10,.68)
		wedges.append(_crib(i))
		wedges[i].hide()

func crest(x: float, z: float) -> float:
	var offset := sin(x*1.7)*.072+x*.085
	var top := CREST+.027*cos(x*2.8)
	return top*(1.-smoothstep(.10,1.06,absf(z-offset)))*(1.-smoothstep(2.05,3.47,absf(x)))

func mesh_point(x: float, z: float) -> Vector3:
	var world := patch.to_global(Vector3(x,0,z))
	return Vector3(x,float(ground.call(world))+crest(x,z)-.015,z)

func _shape_ridge() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 15:
		var x := -3.6+.48*row
		for col in 12:
			var z := -1.45+col*.245
			var a := mesh_point(x,z)
			var b := mesh_point(x+.48,z)
			var c := mesh_point(x+.48,z+.245)
			var d := mesh_point(x,z+.245)
			for vertex: Vector3 in [a,b,c,a,c,d]:
				var high := crest(vertex.x,vertex.z)
				var slope_x := crest(vertex.x+.03,vertex.z)-crest(vertex.x-.03,vertex.z)
				var slope_z := crest(vertex.x,vertex.z+.03)-crest(vertex.x,vertex.z-.03)
				var world := patch.to_global(vertex)
				surface.set_normal(Vector3(-slope_x,.06,-slope_z).normalized())
				surface.set_uv(Vector2(world.x,world.z)*.34)
				surface.set_color(Color("#9ba7ad").lerp(Color("#d7dfe4"),clampf(high/CREST,0.,1.)))
				surface.add_vertex(vertex)
	var crust := MeshInstance3D.new()
	crust.mesh = surface.commit()
	if not windpack:
		windpack = StandardMaterial3D.new()
		windpack.albedo_texture = preload("res://assets/county/windpack.png")
		windpack.vertex_color_use_as_albedo = true
		windpack.vertex_color_is_srgb = true
		windpack.roughness = 1.
	crust.material_override = windpack
	patch.add_child(crust)
	crust.create_trimesh_collision()

func _crib(index: int) -> Node3D:
	var side := -1. if index==0 else 1.
	var location := Vector3(side*wheels.track,0,high_end*wheels.axle_z)
	location.y = ground.call(patch.to_global(location))
	var stack := Kit.joint(patch,location,"CribLeft" if index==0 else "CribRight")
	var kit := Kit.new(stack)
	var layer := heights[index]/3.
	for i in 3:
		var length := CRIB_RUN*(1.-i/3.)+.33
		var center := high_end*(length*.5-.33)
		kit.box(Vector3(0,(i+.5)*layer,center),Vector3(.43,layer*.98,length),Color("#896641").lightened(.025*i))
		var tip := center+high_end*length*.493
		kit.box(Vector3(0,(i+.5)*layer,tip),Vector3(.413,layer*.89,.027),Color("#a57f55"))
		for line in 2:
			var grain := (i+.30+line*.23)*layer
			kit.beam(Vector3(-.18,grain,tip+high_end*.015),Vector3(.19,grain+.013,tip+high_end*.015),.009,.010,Color("#866545"))

	kit.finish()
	return stack

func pack_truck(rig) -> void:
	rack=Kit.joint(rig.truck,_rack_local(rig),"CribbingPacks")
	var kit:=Kit.new(rack)
	for i in 2:
		kit.box(Vector3(i*.22,0,0),Vector3(.19,.25,1.12),Color("#b38a5d"))
		kit.box(Vector3(i*.22,.19,-.14),Vector3(.19,.12,.82),Color("#c39b70"))
	for z: float in [-.32,.32]:
		kit.box(Vector3(.11,.27,z),Vector3(.48,.036,.06),Color("#4d4b40"))
	kit.finish()
	bundle=Kit.joint(rig.eyes,Vector3(.32,-.36,-.56),"CarriedCribbing")
	var hand := Kit.new(bundle)
	hand.box(Vector3.ZERO,Vector3(.17,.15,.67),Color("#c29769"),Vector3(.12,-.25,0))
	hand.finish()
	refresh_kit(rig)

func _rack_local(rig) -> Vector3:
	return Vector3(-1.10,.74,.18) if rig.rollback_active else Vector3(-1.18,1.47,.32)

func refresh_kit(rig) -> void:
	if rack: rack.visible = not collected or (cleared and not used_blocks)
	if bundle: bundle.visible = collected and placed!=3 and not cleared and not rig.in_cab
	for i in 2: wedges[i].visible = bool(placed & (1<<i))

func dispose() -> void:
	for part in [rack,bundle]:
		if is_instance_valid(part):
			part.hide()
			part.queue_free()

func wheel_point(index: int) -> Vector3:
	return wheels.hubs[index*2+(1 if high_end>0 else 0)].global_position

func _support_at(world: Vector3) -> float:
	var local := patch.to_local(world)
	var rise := crest(local.x,local.z)
	for i in 2:
		if not placed & (1<<i): continue
		var side := -1. if i==0 else 1.
		var travel := high_end*local.z-wheels.axle_z
		if absf(local.x-side*wheels.track)>.235 or travel<-.33 or travel>CRIB_RUN: continue
		var steps := clampi(3-floori((travel+.015)/(CRIB_RUN/3.)),1,3)
		rise = maxf(rise,heights[i]*steps/3.)
	return float(ground.call(world))+rise

func settle() -> void:
	var axis := Vector3.BACK.rotated(Vector3.UP,car.rotation.y)
	var across := Vector3.RIGHT.rotated(Vector3.UP,car.rotation.y)
	var half := wheels.axle_z
	var support := PackedFloat32Array()
	for end: float in [-1.,1.]:
		var axle := car.position+axis*half*end
		support.append((_support_at(axle-across*wheels.track)+_support_at(axle+across*wheels.track))*.5)
	var low := 0 if high_end>0 else 1
	var high := 1-low
	var correction := 0.
	# Pivot on the grounded axle until the exposed pan clears the ridge.
	for i in 9:
		var toward := (i+1)/10.
		var offset := high_end*half*(2.*toward-1.)
		var contact := car.position+axis*offset
		var under := lerpf(support[low],support[high],toward)+PAN_CLEARANCE
		correction = maxf(correction,(_support_at(contact)-under)/toward)
	support[high] += correction
	car.rotation.x = atan2(support[0]-support[1],half*2.)
	car.position.y = (support[0]+support[1])*.5
	car.rotation.z=0.

func side_at(rig) -> int:
	for i in 2:
		var side := -1. if i==0 else 1.
		if car.to_local(rig.foot).x*side>.58 and rig.in_range(wheel_point(i),1.6):
			return i
	return -1

func action(rig) -> String:
	if cleared or not rig.phase in ["flared","cable","rigged"]: return ""
	var here := car.to_local(rig.foot)
	if not inspected and absf(here.z)<.78 and absf(here.x)>.58 and rig.in_range(car.to_global(Vector3(signf(here.x)*.88,.38,0)),1.68):
		return "crib_inspect"
	if not collected and rig.in_range(rack.global_position,1.58): return "crib_fetch"
	if collected:
		var side := side_at(rig)
		if side>=0 and not placed & (1<<side): return "crib_place"
	return ""

func prompt(id: String) -> String:
	match id:
		"crib_inspect": return "Look under the rocker panel"
		"crib_fetch": return "Take the hardwood cribbing from the side rack"
		"crib_place": return "Seat a crib pack under this raised tire"
	return ""

func instructions(rig) -> String:
	if cleared: return ""
	if rig.phase=="flared" and not inspected: return "Look under the sill. Check which axle is hanging above the snow."
	if blocked: return "Ease off. Lay cribbing under both raised wheels for this pull, or stow the cable and pull back toward the grounded axle."
	if collected and placed!=3: return "Seat one crib pack at each suspended tire. Leave the grounded axle where it is."
	return ""

func handle(rig, id: String) -> void:
	match id:
		"crib_inspect":
			inspected=true
			rig.show_note("Pan resting on the frozen ridge. Both %s tires hang clear. Pull back on the grounded axle, or crib the hanging pair to come over." % ("rear" if high_end>0 else "front"),8.)
		"crib_fetch":
			collected=true
			rig.sound_event.emit("ratchet")
			rig.show_note("Two hardwood packs. Slide one under each hanging tire.",5.)
		"crib_place":
			var i:=side_at(rig)
			if i>=0: placed |= 1<<i
			if placed==3: blocked=false
			rig.sound_event.emit("ratchet")
			rig.show_note("Both wheels supported." if placed==3 else "One wheel supported. Take the other pack around the car.",4.)
	refresh_kit(rig)

func pull(rig, dt: float) -> void:
	var direction: Vector3 = rig.drum_point()-car.position
	direction.y=0.
	direction=direction.normalized()
	var alignment := direction.dot(patch.global_basis.z)*high_end
	var over: bool = alignment>.54 and rig.line_end==high_end
	var back: bool = alignment<-.54 and rig.line_end==-high_end
	blocked = not back and not (over and placed==3)
	if blocked:
		rig.tension=move_toward(rig.tension,.87,dt*.53)
		warning_left=maxf(0.,warning_left-dt)
		if warning_left<=0:
			rig.show_note("The belly is bearing on ice. Crib the raised wheels or bring the line back from the grounded end." if absf(alignment)>.54 else "The line is pulling across the ridge. Stow it and bring the truck around to an end.",6.)
			warning_left=6.
		return
	used_blocks = used_blocks or over
	var drag := .62 if over else .71
	rig.tension=move_toward(rig.tension,drag,dt*.65)
	var advance := direction*dt*(.96 if over else .78)*smoothstep(.15,drag,rig.tension)
	car.position+=advance
	var desired := atan2(direction.x,direction.z)+(PI if rig.line_end<0 else 0.)
	car.rotation.y=lerp_angle(car.rotation.y,desired,minf(1.,advance.length()*.14))
	settle()
	for i in 4: wheels.roll_on_ground(i,false)
	rig.free_line=rig.flat_distance(rig.drum_point(),rig.eyelet_point(rig.line_end))
	var local := patch.to_local(car.position)
	if absf(local.z)>wheels.axle_z+CRIB_RUN+.52 or absf(local.x)>4.6:
		cleared = true
		blocked = false
		rig.show_note("Four tires down. Keep reeling from the side panel.",5.)
		refresh_kit(rig)

func save_state() -> Dictionary:
	return {"inspected":inspected,"collected":collected,"placed":placed,"cleared":cleared,"used":used_blocks,"blocked":blocked}

func restore(rig, data: Dictionary) -> void:
	inspected=data.get("inspected",false)
	collected=data.get("collected",false)
	placed=int(data.get("placed",0)) & 3
	cleared=data.get("cleared",false)
	used_blocks=data.get("used",false)
	blocked=data.get("blocked",false)
	refresh_kit(rig)
