class_name GameCamera
extends Camera3D
## Orthographic camera that smoothly blends (no cuts) between CHASE (rotates
## with the jet), ISO and TOP views. Auto zoom-out at speed, screen shake.
## 1 world unit = 1 low-res pixel at zoom 1.

enum Mode { CHASE, ISO, TOP }
const MODE_NAMES := ["CHASE", "ISO", "TOP"]
const PITCH := [deg_to_rad(42.0), deg_to_rad(45.0), deg_to_rad(72.0)]
const LOOK_AHEAD := [62.0, 30.0, 30.0]

var mode := Mode.CHASE
var view_h := 224.0
var pitch := deg_to_rad(42.0)
var cam_yaw := 0.0
var zoom := 1.0
var focus := Vector3.ZERO
var shake := 0.0
var _shake_off := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _first := true


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 1.0
	far = 2400.0
	current = true


func cycle_mode() -> void:
	mode = ((mode + 1) % 3) as Mode


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 8.0)


## Ground-plane right / up vectors of the screen (for screen-relative steering).
func screen_right() -> Vector3:
	return Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))


func screen_up() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))


func update_cam(delta: float, target: Vector3, target_yaw: float, speed_ratio: float) -> void:
	var t_pitch: float = PITCH[mode]
	var t_yaw := target_yaw
	match mode:
		Mode.ISO:
			t_yaw = PI * 0.25
		Mode.TOP:
			t_yaw = 0.0
	var fwd := Vector3(-sin(target_yaw), 0.0, -cos(target_yaw))
	var t_focus := target + fwd * float(LOOK_AHEAD[mode]) * (0.6 + 0.6 * speed_ratio)
	var t_zoom := lerpf(1.0, 0.72, clampf(speed_ratio, 0.0, 1.0))
	if _first:
		_first = false
		pitch = t_pitch
		cam_yaw = t_yaw
		focus = t_focus
		zoom = t_zoom
	var k := 1.0 - exp(-delta * 2.5)
	pitch = lerpf(pitch, t_pitch, k)
	cam_yaw = lerp_angle(cam_yaw, t_yaw, 1.0 - exp(-delta * (3.2 if mode == Mode.CHASE else 2.0)))
	focus = focus.lerp(t_focus, 1.0 - exp(-delta * 4.0))
	zoom = lerpf(zoom, t_zoom, 1.0 - exp(-delta * 1.5))
	shake = maxf(0.0, shake - delta * 14.0)
	if shake > 0.01:
		_shake_off = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * shake
	else:
		_shake_off = Vector3.ZERO
	var b := Basis.from_euler(Vector3(-pitch, cam_yaw, 0.0))
	size = view_h / zoom
	global_transform = Transform3D(b, focus + b.z * 900.0 + b * _shake_off)
