extends Node3D
## Paired rear lens clusters on the service body, sliding bed and wired tow bar.
## Running and brake filaments share the red lens. A separate clear lens backs
## onto the same housing and stays dark until reverse is selected.
const Kit := preload("res://scripts/rig_mesh.gd")
var brakes: MeshInstance3D
var reverse: MeshInstance3D

func fit(parent: Node3D, center: Vector3, spacing: float, lens: Vector2, backward := false) -> void:
	name = "RoadSignals"
	parent.add_child(self)
	position = center
	rotation.y = PI if backward else 0.
	var housing := Kit.new(self)
	var stop := Kit.new(self)
	var backing := Kit.new(self)
	for side: float in [-1.,1.]:
		var red := Vector3(side*spacing,0,0)
		var clear := red-Vector3.RIGHT*side*lens.x*.84
		var red_size := Vector3(lens.x,lens.y,.034)
		var clear_size := Vector3(lens.x*.49,lens.y*.88,.034)
		housing.box(red.lerp(clear,.34)-Vector3.BACK*.025,Vector3(lens.x*1.66,lens.y*1.28,.066),Color("#383838"))
		housing.box(red,red_size,Color("#9e292b"),Vector3.ZERO,"lamp")
		housing.box(clear,clear_size,Color("#847e73"))
		stop.box(red+Vector3.BACK*.012,red_size,Color("#ff5745"),Vector3.ZERO,"lamp")
		backing.box(clear+Vector3.BACK*.012,clear_size,Color("#fff0cd"),Vector3.ZERO,"lamp")
	housing.finish()
	brakes = stop.finish()
	reverse = backing.finish()
	brakes.name = "BrakeFilaments"
	reverse.name = "ReverseFilaments"
	set_lit(false,false)

func set_lit(braking: bool, backing: bool) -> void:
	brakes.visible = braking
	reverse.visible = backing
