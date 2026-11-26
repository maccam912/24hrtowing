extends Node3D
## The second set of keys always belongs to the truck actually standing in the yard.
const Truck := preload("res://scripts/rig_truck.gd")
const DELIVERY := Vector3(-16, 0, -44)
const ALTERNATE := Vector3(-29, 0, -51)
const SALE_MILES := 126804.2
var parked := {}
var model: Node3D
var alternate_offer := {}

func receive(rig) -> void:
	if not parked.is_empty():
		return
	var at := DELIVERY
	if rig._flat_distance(at,rig.get_truck_position()) < 10.0:
		at = ALTERNATE
	parked = {"rollback":true,"at":[at.x,at.y,at.z],"heading":-PI/2,
		"odo":SALE_MILES,"fuel":0.5,"wear":0.0,"reserve":0.0}
	show_parked()

func clear_model() -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.free()
	model = null

func door() -> Vector3:
	if not is_instance_valid(model): return Vector3.INF
	return model.to_global(Truck.DOOR + Vector3.UP * 1.22)

func switch_trucks(game) -> void:
	var rig = game.rig
	var incoming := parked
	var at: Vector3 = rig.get_truck_position()
	parked = {"rollback":rig.rollback_active,"at":[at.x,at.y,at.z],"heading":rig.heading,
		"odo":rig.odo,"fuel":rig.fuel,"wear":rig.wear,"reserve":rig.reserve_fuel,
		"climate":rig.climate.save_state(),"ice":rig.body.mirror_ice.duplicate(),"spot_on":rig.spot_on}
	clear_model()
	rig.use_rollback(incoming.rollback)
	game._fit_equipment()
	rig.odo = incoming.odo
	rig.fuel = incoming.fuel
	rig.wear = incoming.wear
	rig.reserve_fuel = incoming.get("reserve",0.0)
	rig.climate.restore(incoming.get("climate",{}))
	var ice: Array = incoming.get("ice",[0.0,0.0])
	for side in 2:
		rig.body.set_mirror_ice(side,ice[side])
	rig.spot_on = incoming.get("spot_on",false)
	if rig.aux_tank: rig.aux_tank.set_reading(rig.reserve_fuel)
	rig.recover_to_yard(Vector3(incoming.at[0],incoming.at[1],incoming.at[2]),incoming.heading)
	show_parked()

func show_parked() -> void:
	clear_model()
	if parked.is_empty(): return
	var rollback: bool = parked.rollback
	var truck := Truck.new()
	model = truck
	add_child(model)
	model.position = Vector3(parked.at[0],parked.at[1],parked.at[2])
	model.rotation.y = parked.heading
	model.name = "ParkedCarCarrier" if rollback else "ParkedWrecker"
	truck.build(true,rollback)
	for part: GeometryInstance3D in model.find_children("*","GeometryInstance3D",true,false):
		part.visibility_range_end = 140.0
	var solid := StaticBody3D.new()
	model.add_child(solid)
	solid.collision_layer = 1
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.54,2.86,10.5 if rollback else 9.1)
	shape.position = Vector3(0,1.54,1.18 if rollback else .49)
	shape.shape = box
	solid.add_child(shape)
