extends RefCounted

var controls := false
var awaiting_neutral := false
var watch_load := true

func take_controls(rig) -> void:
	controls = true
	watch_load = true
	frame_load(rig,Vector2.ZERO,1.)
	rig.info_timer = 0.

func release() -> void:
	controls = false
	awaiting_neutral = true

func holds_operator(move: Vector2) -> bool:
	if awaiting_neutral and move.length() < .15: awaiting_neutral = false
	return controls or awaiting_neutral

func frame_load(rig, look: Vector2, dt: float) -> void:
	if not look.is_zero_approx(): watch_load = false
	if not watch_load: return
	var view: Vector3 = rig.car.global_position+Vector3.UP*.65-rig.eyes.global_position
	var angle := atan2(-view.x,-view.z)
	var pitch := atan2(view.y,Vector2(view.x,view.z).length())
	rig.camera_yaw = lerp_angle(rig.camera_yaw,angle,1.-exp(-7.*dt))
	rig.camera_pitch = lerp_angle(rig.camera_pitch,pitch,1.-exp(-7.*dt))

func stroke(_rig, _move: Vector2, _dt: float) -> void:
	pass
