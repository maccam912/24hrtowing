extends Node3D
## The sensor sees the operator from both sides of the entrance.
const Batch = preload("res://scripts/county_mesh.gd")
const HALF_OPENING := .92
var leaves: Array[Node3D] = []
var travel := 0.0
var rider_wait := 0.0

func fit(palette: Dictionary) -> void:
	for side: float in [-1.0,1.0]:
		var leaf := Node3D.new()
		leaf.position.x = side * HALF_OPENING * .5
		add_child(leaf)
		leaves.append(leaf)
		var pane = Batch.new(leaf,palette)
		pane.box(Vector3(0,1.33,0),Vector3(HALF_OPENING-.07,1.96,.035),"shop_glass")
		pane.box(Vector3(0,.19,0),Vector3(HALF_OPENING,.38,.053),"silver")
		pane.box(Vector3(0,2.36,0),Vector3(HALF_OPENING,.13,.06),"silver")
		pane.box(Vector3(0,1.02,-.009),Vector3(HALF_OPENING,.075,.065),"silver")
		for edge: float in [-1,1]:
			pane.box(Vector3(edge*(HALF_OPENING-.052)*.5,1.21,0),Vector3(.052,2.42,.07),"silver")
		pane.solid_box(Vector3(0,1.21,0),Vector3(HALF_OPENING,2.42,.07))
		pane.finish()

func hold_for_rider() -> void:
	rider_wait = 1.0

func sense(eye: Vector3, dt: float) -> void:
	rider_wait = maxf(0.0,rider_wait-dt)
	var local := to_local(eye)
	var approach := absf(local.x) < 2.4 and absf(local.z) < 3.7 and local.y < 3.4
	approach = approach or rider_wait > 0.0
	var next := move_toward(travel,1.0 if approach else 0.0,dt*(2.8 if approach else 1.1))
	if next == travel:
		return
	travel = next
	var offset := HALF_OPENING * (.5+smoothstep(0.0,1.0,travel))
	leaves[0].position.x = -offset
	leaves[1].position.x = offset
