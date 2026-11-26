extends RefCounted
## The empty front bench is visible through the glass of this passing sedan.
const Kit := preload("res://scripts/rig_mesh.gd")
const Car := preload("res://scripts/rig_scene.gd")
const DRIVER := Vector3(-.41,1.43,-.10)
const RUN := 130.0
const CUT_OFF := -2.55
const RECOGNITION := 15.0

static func build(parent: Node3D, identity: Dictionary) -> Node3D:
	var sedan := Car.car(parent,"oncoming",0,identity,true)
	var size: Vector3 = sedan.get_meta("body_size")
	var base := size.y
	var cabin := Kit.joint(sedan,Vector3.ZERO,"EmptyCabin")
	var interior := Kit.new(cabin)
	var cloth := Color("#a28d72")
	var piping := Color("#c9b99d")
	for x: float in [-.41,.41]:
		interior.box(Vector3(x,base+.46,-.015),Vector3(.62,.15,.68),cloth)
		interior.box(Vector3(x,base+.67,.29),Vector3(.61,.40,.13),cloth,Vector3(.12,0,0))
		interior.box(Vector3(x,base+.91,.32),Vector3(.31,.16,.13),piping)
		for seam: float in [-.15,0,.15]:
			interior.box(Vector3(x+seam,base+.68,.216),Vector3(.023,.25,.026),piping,Vector3(.12,0,0))
	interior.box(Vector3(0,base+.64,-.78),Vector3(1.55,.15,.30),Color("#565857"))
	var column := Vector3(-.41,base+.75,-.57)
	interior.beam(column+Vector3(0,-.13,-.15),column,.06,.07,Color("#47433d"))
	interior.ring(column,.15,.185,Color("#2b2724"),Vector3(1.22,0,0))
	interior.beam(column-Vector3.RIGHT*.14,column+Vector3.RIGHT*.14,.037,.036,Color("#b7ad94"))
	interior.finish()
	var glazing := StandardMaterial3D.new()
	glazing.albedo_color = Color(.65,.78,.80,.10)
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.cull_mode = BaseMaterial3D.CULL_DISABLED
	glazing.roughness=.34
	glazing.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_pane(cabin,Vector3(0,base+.82,-.75),Vector2(size.x*1.76,.74),Vector3(atan2(.40,.62),0,0),glazing)
	_pane(cabin,Vector3(0,base+.81,.86),Vector2(size.x*1.72,.72),Vector3(-atan2(.36,.60),0,0),glazing)
	for side: float in [-1,1]:
		_pane(cabin,Vector3(side*size.x*.87,base+.80,.06),Vector2(1.23,.58),Vector3(0,side*PI*.5,side*.14),glazing)
	var lamps := Car.car_lamps(sedan,"running",-1)
	var glow := ShaderMaterial.new()
	glow.shader=preload("res://assets/county/oncoming_headlamp.gdshader")
	for side: float in [-1.,1.]:
		var lens := _pane(lamps,Vector3(side*size.x*.82,base+.25,-size.z-.03),Vector2(1.9,1.14),Vector3(0,PI,0),glow)
		lens.name="LeftHeadlight" if side<0 else "RightHeadlight"
	sedan.visible = not identity.get("passed",false)
	return sedan

static func _pane(parent: Node3D, at: Vector3, size: Vector2, angle: Vector3, surface: Material) -> MeshInstance3D:
	var quad:=QuadMesh.new()
	quad.size=size
	quad.material=surface
	var panel:=MeshInstance3D.new()
	parent.add_child(panel)
	panel.position=at
	panel.rotation=angle
	panel.mesh=quad
	panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return panel

static func clear_road(game, center: Vector3, along: Vector3, street: String) -> bool:
	var nav = game._current_road_map()
	var side := along.cross(Vector3.UP)
	for distance: float in [0.,32.,64.,96.,RUN]:
		var station:=center-along*distance
		if nav.driven_road(Vector2(station.x,station.z))!=street or game.county.road_distance(station.x,station.z)>1.: return false
		# An intersecting road or an unresolved endpoint breaks the straightaway.
		var bank:=station-side*8.5
		if game.county.road_distance(bank.x,bank.z)<6.: return false
	return true
