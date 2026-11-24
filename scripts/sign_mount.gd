extends AudioStreamPlayer3D
## A loose sign bracket chatters once as the rising wind catches the blades.
var county: Node3D
var trigger_gust: float
var armed := true
var ring_time := 1.0

func _ready() -> void:
	var variation := fposmod(position.x*.27 + position.z*.16, 1.0)
	trigger_gust = lerpf(.57,.82,variation)
	pitch_scale = lerpf(.88,1.13,variation)
	stream = preload("res://assets/audio/sign_rattle.mp3")
	unit_size = 4.0
	max_distance = 26.0
	volume_db = -7.0

func _process(dt: float) -> void:
	if county.storm_gust < trigger_gust - .18:
		armed = true
	elif county.storm_gust >= trigger_gust and armed:
		armed = false
		var camera := get_viewport().get_camera_3d()
		if camera and global_position.distance_squared_to(camera.global_position) < 65.0*65.0:
			ring_time = 0.0
			play()
	if ring_time < 1.0:
		ring_time = minf(1.0, ring_time + dt*pitch_scale)
		var envelope := exp(-ring_time*4.7)*(1.0-ring_time)
		rotation.y = envelope*.14*sin(ring_time*45.0)
		rotation.z = envelope*.053*sin(ring_time*61.0)
