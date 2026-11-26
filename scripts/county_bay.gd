extends Node3D
## The underlift can approach from either open side. Two retracting chains meet
## at the keyed corner hasp, so the hold vehicle stays accessible from the yard.
const Batch = preload("res://scripts/county_mesh.gd")
const FURNACE := Vector3(-54.8,3.92,-39.68)
const LATCH := Vector3(-42.35,1.2,-50.85)
const MOUNTS := [Vector3(-59.4,1.28,-50.85),Vector3(-42.35,1.28,-38.8)]
# Include a little room around the chains for the operator and the crossbar.
const FLOOR := Rect2(MOUNTS[0].x - .3, LATCH.z - .3,
	LATCH.x - MOUNTS[0].x + .6, MOUNTS[1].z - LATCH.z + .6)
# Heat stays under the roof, inside the two chain lines and the metal walls.
const HEATED_FLOOR := Rect2(MOUNTS[0].x,LATCH.z,LATCH.x-MOUNTS[0].x,MOUNTS[1].z-LATCH.z)
var chains: Array[Node3D] = []
var stops: Array[CollisionShape3D] = []
var lock: Node3D
var tween: Tween
var extension := 0.012
var locked := false

static func sheltered(point: Vector3) -> bool:
	return point.y >= -.3 and point.y < 4.7 and HEATED_FLOOR.has_point(Vector2(point.x,point.z))

func setup(materials: Dictionary, initial: bool) -> void:
	var stand = Batch.new(self,materials)
	stand.box(FURNACE,Vector3(1.75,.92,.86),"cream")
	stand.box(FURNACE+Vector3(0,0,-.44),Vector3(1.38,.59,.06),"dark")
	for i in 5:
		stand.box(FURNACE+Vector3(0,.22-i*.105,-.50),Vector3(1.35,.038,.092),"post",false,Vector3(-.29,0,0))
	for side: float in [-1.,1.]:
		stand.box(FURNACE+Vector3(side*.71,.64,0),Vector3(.037,.39,.037),"post")
	stand.add("cylinder",FURNACE+Vector3(.5,1.04,.17),Vector3(.23,1.23,.23),"silver")
	stand.box(FURNACE+Vector3(.5,1.68,.17),Vector3(.40,.065,.40),"post")
	stand.box(LATCH+Vector3(.13,-.04,-.10),Vector3(.23,.38,.16),"silver")
	stand.box(LATCH+Vector3(.13,-.05,-.195),Vector3(.103,.06,.04),"black")
	for mount:Vector3 in MOUNTS:
		stand.box(mount,Vector3(.34,.34,.34),"dark")
		stand.box(mount+Vector3.UP*.13,Vector3(.37,.10,.38),"post")
		var chain := Node3D.new()
		add_child(chain)
		var span := Vector2(LATCH.x-mount.x,LATCH.z-mount.z)
		chain.position = mount
		chain.rotation.y = -atan2(span.y,span.x)
		chains.append(chain)
		var g = Batch.new(chain,materials)
		var length := span.length()
		var steps := ceili(length/.31)
		for i in steps:
			var t0 := float(i)/steps
			var t1 := float(i+1)/steps
			var x := (t0+t1)*.5*length
			var drop := -.43 * sin((t0+t1)*.5*PI)
			var a := Vector3(t0*length,drop,0)
			var b := Vector3(t1*length,drop,0)
			var rim := Vector3(0,.056,0) if i%2==0 else Vector3(0,.013,.063)
			g.beam(a,Vector3(x,drop,0)+rim,.027,.032,"post")
			g.beam(Vector3(x,drop,0)+rim,b,.027,.032,"post")
			g.beam(b,Vector3(x,drop,0)-rim,.027,.032,"post")
			g.beam(Vector3(x,drop,0)-rim,a,.027,.032,"post")
		g.finish()
		# Lower steelwork is represented by a continuous blocking surface when
		# secured. It vanishes as soon as Brandt operates the key.
		var body := StaticBody3D.new()
		body.position=mount+Vector3(span.x*.5,-.54,span.y*.5)
		body.rotation.y=chain.rotation.y
		add_child(body)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(length,1.50,.13)
		cs.shape=shape
		body.add_child(cs)
		stops.append(cs)
	stand.finish()
	lock=Node3D.new()
	add_child(lock)
	var metal = Batch.new(lock,materials)
	metal.box(Vector3.ZERO,Vector3(.18,.22,.12),"post")
	metal.box(Vector3(0,-.027,-.064),Vector3(.026,.051,.012),"black")
	for x:float in [-.055,.055]:
		metal.box(Vector3(x,.161,0),Vector3(.026,.114,.035),"white")
	metal.box(Vector3(0,.211,0),Vector3(.127,.026,.035),"white")
	metal.finish()
	set_locked(initial, false)

func set_locked(value: bool, animate := true) -> void:
	locked=value
	for shape:CollisionShape3D in stops:
		shape.set_deferred("disabled",not value)
	if tween:
		tween.kill()
	var target := 1.0 if value else .012
	if animate:
		tween=create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(_show_extension,extension,target,.57)
	else:
		_show_extension(target)

func _show_extension(fraction: float) -> void:
	extension=fraction
	for chain:Node3D in chains:
		chain.scale.x=fraction
	# The operator keeps the unlocked padlock on the hasp.
	lock.position=LATCH+Vector3(.16,-.16-(1.-fraction)*.19,-.21)
	lock.rotation.z=(1.-fraction)*.46
