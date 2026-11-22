class_name GameCamera
extends Camera3D
## Perspective camera with three views that blend smoothly (no cuts):
##  OVERHEAD - high above, looking straight down, north up, jet in the centre
##  CHASE    - behind and above the jet, real perspective ground plane receding
##             to the horizon (Mode-7 style), sprite stacks scale with distance
##  COCKPIT  - first person from the canopy; horizon tilts with the jet's roll
## The camera eases towards the target transform of the current mode, so
## switching modes swoops the camera between viewpoints.

enum Mode { OVERHEAD, CHASE, COCKPIT }
const MODE_NAMES := ["OVERHEAD", "CHASE", "COCKPIT"]
const FOV := [48.0, 62.0, 76.0]
const FOG_FAR := [0.0, 3600.0, 3600.0]
## chase framing: jet width as a fraction of the screen height
const CHASE_JET_FRAC := 0.19
const CHASE_HEIGHT_DEG := 25.0

var mode := Mode.CHASE
var view_h := 336.0 # unused in perspective, kept for API compatibility
var cam_yaw := 0.0 # yaw used for screen-relative steering
var focus := Vector3.ZERO
var shake := 0.0
var cockpit_blend := 0.0 # 0..1, how far the camera is "inside" the cockpit
var fog_enabled := true
var _rng := RandomNumberGenerator.new()
var _first := true
var _pos := Vector3.ZERO
var _rot := Quaternion.IDENTITY
var _fov := 62.0
var _fog := 0.0
var _since_switch := 10.0


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	near = 0.5
	far = 9000.0
	fov = 62.0
	current = true


func cycle_mode() -> void:
	mode = ((mode + 1) % 3) as Mode
	_since_switch = 0.0


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 8.0)


## Ground-plane right / up vectors of the screen (for screen-relative steering).
func screen_right() -> Vector3:
	return Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))


func screen_up() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))


func _target(m: int, jet: Node3D) -> Transform3D:
	var jp: Vector3 = jet.position
	match m:
		Mode.OVERHEAD:
			var p := jp + Vector3(0.0, 430.0, 40.0)
			return Transform3D(Basis.IDENTITY, p).looking_at(jp + Vector3(0, 0, -6.0), Vector3.FORWARD)
		Mode.CHASE:
			var f: Vector3 = jet.forward()
			var f3: Vector3 = jet.forward3()
			# distance so the jet's wingspan covers CHASE_JET_FRAC of the screen height
			var dist := 40.0 / (2.0 * tan(deg_to_rad(FOV[Mode.CHASE]) * 0.5) * CHASE_JET_FRAC)
			var el := deg_to_rad(CHASE_HEIGHT_DEG)
			var p := jp - f * dist * cos(el) + Vector3.UP * (dist * sin(el) - sin(jet.pitch) * dist * 0.5)
			var t := jp + f3 * dist * 0.6
			var tr := Transform3D(Basis.IDENTITY, p).looking_at(t, Vector3.UP)
			tr.basis = tr.basis * Basis(Vector3.BACK, -jet.roll * 0.22)
			return tr
		_:
			var b: Basis = jet.visual_basis()
			return Transform3D(b, jp + b * Vector3(0.0, 4.5, -7.0))


func update_cam(delta: float, jet: Node3D, speed_ratio: float) -> void:
	_since_switch += delta
	var t := _target(mode, jet)
	var t_fov: float = FOV[mode] + 9.0 * speed_ratio
	if _first:
		_first = false
		_pos = t.origin
		_rot = t.basis.get_rotation_quaternion()
		_fov = t_fov
	var rate_p := 7.0
	var rate_r := 6.0
	if mode == Mode.OVERHEAD:
		rate_p = 5.0
		rate_r = 4.0
	elif mode == Mode.COCKPIT:
		# ease in, then lock rigidly to the canopy (a lagging follow would
		# never catch a jet doing ~100 units/s)
		var k := clampf((_since_switch - 0.6) / 0.8, 0.0, 1.0)
		rate_p = lerpf(4.0, 200.0, k * k)
		rate_r = lerpf(4.0, 200.0, k * k)
	elif _since_switch < 1.2:
		rate_p = minf(rate_p, 3.2)
		rate_r = minf(rate_r, 3.0)
	_pos = _pos.lerp(t.origin, 1.0 - exp(-delta * rate_p))
	if mode == Mode.COCKPIT and _since_switch > 1.4:
		_pos = t.origin
	_rot = _rot.slerp(t.basis.get_rotation_quaternion(), 1.0 - exp(-delta * rate_r))
	_fov = lerpf(_fov, t_fov, 1.0 - exp(-delta * 3.0))
	_fog = lerpf(_fog, FOG_FAR[mode] if fog_enabled else 0.0, 1.0 - exp(-delta * 2.0))
	cockpit_blend = clampf(1.0 - (_pos.distance_to(_target(Mode.COCKPIT, jet).origin) - 2.0) / 20.0, 0.0, 1.0)
	shake = maxf(0.0, shake - delta * 14.0)
	var b := Basis(_rot)
	var off := Vector3.ZERO
	if shake > 0.01:
		off = b * Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * shake * 0.6
	global_transform = Transform3D(b, _pos + off)
	fov = _fov
	focus = jet.position
	# steering frame: overhead is north-up, otherwise follow the camera
	var fwd := -b.z
	cam_yaw = 0.0 if mode == Mode.OVERHEAD else atan2(-fwd.x, -fwd.z)
	RenderingServer.global_shader_parameter_set("cam_pos", global_position)
	RenderingServer.global_shader_parameter_set("fog_far", _fog if _fog > 50.0 else 0.0)


## Point on the ground the camera is looking at (for streaming).
func ground_point() -> Vector3:
	var f := -global_transform.basis.z
	var o := global_position
	if f.y < -0.08:
		var t := minf(-o.y / f.y, 700.0)
		var p := o + f * t
		return Vector3(p.x, 0.0, p.z)
	var p2 := o + Vector3(f.x, 0.0, f.z).normalized() * 450.0
	return Vector3(p2.x, 0.0, p2.z)
