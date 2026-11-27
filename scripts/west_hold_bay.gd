extends Node3D

const Sites := preload("res://scripts/county_sites.gd")
const Batch := preload("res://scripts/county_mesh.gd")
const CENTER := Vector3(-91,0,-64)
const FLOOR := Rect2(-98.2,-68.5,14.4,9.0)
const LATCH := Vector3(-83.8,1.12,-68.5)
const BOOK := Vector3(-81.9,1.26,-70.1)
const COUNTERSIGN := Vector3(-82.7,0,-57.4)
const DROP := {"center":CENTER,"sign":"WEST HOLD 2","approach":"Go through the west gate. Back the whole car between the hold fences straight ahead."}
var gate := Node3D.new()
var barrier := CollisionShape3D.new()
var lock := Node3D.new()
var vehicle: Node3D
var clerk: Node3D
var displayed_order := ""
var latched := false
var county_world

func build(county) -> void:
	county_world=county
	name = "WestHoldBay"
	var site := Sites.new(county,Batch.new(self,county.materials))
	var left := Vector3(FLOOR.end.x,0,FLOOR.position.y)
	var right := Vector3(FLOOR.end.x,0,FLOOR.end.y)
	for post: Vector3 in [left,right]:
		site.fence(Vector3(FLOOR.position.x,0,post.z),post,2.16,true,true)
		site.cyl(post.x,1.17,post.z,.24,2.34,"oxide",true)
		site.cyl(post.x,.98,post.z,.25,.16,"cream")
		site.b(post.x,1.19,post.z,.30,.23,.31,"post")
		site.b(CENTER.x,.12,post.z,13.8,.16,.18,"cream")
	site.placard(right+Vector3(.21,2.48,0),"WEST HOLD 2",3.35,.72,PI*.5,"green",true)
	site.placard(right+Vector3(.21,1.90,0),"SHERIFF USE",1.81,.28,PI*.5,"black",true)
	# A shielded work lamp lights the chain and plate when the yard is dark.
	site.b(right.x,1.78,right.z,.16,3.56,.17,"post")
	site.beam(right+Vector3(0,3.48,0),right+Vector3(.66,3.42,-.20),.065,.075,"silver")
	site.b(right.x+.66,3.40,right.z-.20,.48,.12,.34,"dark")
	site.b(right.x+.66,3.32,right.z-.20,.37,.033,.26,"lamp")
	var light := OmniLight3D.new()
	light.position=right+Vector3(.66,3.27,-.20)
	light.light_color=Color("#ffc980")
	light.light_energy=1.8
	light.omni_range=9.
	light.distance_fade_enabled=true
	light.distance_fade_begin=34.
	add_child(light)
	site.b(BOOK.x,.62,BOOK.z,.24,1.24,.26,"post",true)
	site.b(BOOK.x,BOOK.y,BOOK.z,1.06,.20,.79,"green")
	site.b(BOOK.x,BOOK.y+.12,BOOK.z,.65,.05,.43,"cream")
	site.b(BOOK.x,BOOK.y+.16,BOOK.z-.16,.32,.02,.074,"silver")
	site.placard(BOOK+Vector3(0,-.19,.4),"HOLD ORDERS",1.02,.24,0,"green")
	for s:float in [-1.,1.]:
		site.b(BOOK.x+s*.46,BOOK.y+.25,BOOK.z-.33,.042,.53,.045,"post")
	site.b(BOOK.x,BOOK.y+.54,BOOK.z,1.16,.09,.94,"silver")
	site.draw.finish()
	add_child(gate)
	gate.position = right+Vector3.UP*LATCH.y
	var steel := Batch.new(gate,county.materials)
	for i in 32:
		var a := float(i)/32
		var b := float(i+1)/32
		var p := Vector3(0,-.30*sin(a*PI),-a*FLOOR.size.y)
		var q := Vector3(0,-.30*sin(b*PI),-b*FLOOR.size.y)
		var rim := Vector3(.037,.018,0) if i%2 else Vector3(0,.05,0)
		var middle := (p+q)*.5
		for offset:Vector3 in [rim,-rim]:
			steel.beam(p,middle+offset,.03,.03,"post")
			steel.beam(middle+offset,q,.03,.03,"post")
	steel.finish()
	add_child(lock)
	lock.position=LATCH
	var latch := Batch.new(lock,county.materials)
	latch.box(Vector3(.15,-.10,0),Vector3(.16,.21,.12),"brass")
	latch.box(Vector3(.15,.034,0),Vector3(.13,.079,.05),"silver")
	latch.finish()
	var post := StaticBody3D.new()
	add_child(post)
	post.position = (left+right)*.5+Vector3.UP*.8
	var shape := BoxShape3D.new()
	shape.size=Vector3(.13,1.6,FLOOR.size.y)
	barrier.shape=shape
	post.add_child(barrier)
	_make_clerk()
	set_locked(false)

func _make_clerk() -> void:
	clerk = county_world.Scene.person(self,true,1)
	clerk.position=COUNTERSIGN
	clerk.rotation.y=.68
	clerk.hide()

func hand_off(rig, row: Dictionary) -> void:
	if not vehicle: return
	var ticket := row.duplicate()
	ticket.west_release = true
	ticket.driver_variant = 1
	vehicle.reparent(rig,true)
	clerk.reparent(rig,true)
	var lamps: Node3D = rig.Scene.car_lamps(vehicle,"hazard",-1)
	rig.departures.append(rig.DepartingDriver.new(rig,vehicle,clerk,lamps,vehicle.position,vehicle.rotation.y,ticket))
	vehicle = null
	_make_clerk()

static func fits(car: Node3D, landing := Vector3.INF, yaw := 0.) -> bool:
	var forecasting := landing.is_finite()
	var pose := Transform3D(Basis(Vector3.UP,yaw),landing) if forecasting else car.global_transform
	var footprint := FLOOR.grow(-.60 if forecasting else -.18)
	var size: Vector3 = car.get_meta("body_size")
	for x:float in [-size.x,size.x]:
		for z:float in [-size.z,size.z]:
			var at := pose*Vector3(x,0,z)
			if not footprint.has_point(Vector2(at.x,at.z)): return false
	return true

func set_locked(value:bool) -> void:
	latched = value
	gate.scale.z=1.0 if value else .018
	lock.rotation.x=0.0 if value else -.62
	barrier.set_deferred("disabled",not value)

func sync(game) -> void:
	var row: Dictionary = game.west_orders.current
	var id := str(row.get("sheriff_order",""))
	if displayed_order != id:
		if vehicle:
			vehicle.hide()
			vehicle.queue_free()
			vehicle = null
		displayed_order=id
		if not id.is_empty():
			var parked: Vector3 = game.rig.unpack_point(row.get("parked"),CENTER)
			vehicle = game.rig.Scene.car(self,"hazard",int(row.variant),row)
			vehicle.position = parked
			vehicle.position.y = county_world.ground_height(parked.x,parked.z)
			vehicle.rotation.y = float(row.get("yaw",-PI/2))
	set_locked(game.west_orders.locked)
	clerk.visible = game.west_orders.can_release(game.completed)
