class_name Controls
extends Node
## Touch controls for a landscape phone. Settings -> Controls:
##  AIM + JOYSTICK (default, War Thunder style)
##   LEFT  (~60% of the screen) - a floating joystick (appears under the
##         thumb) that keeps MOVING the AIM circle while held: small
##         deflection = slow, precise; full = fast, for hard turns. Released,
##         the circle stays where it is. The AIM is the direction you want to
##         fly (a world direction); an instructor flies the nose onto it.
##  AIM + SWIPE
##   LEFT - a trackpad: dragging moves the aim circle by the drag.
##   RIGHT free area - drag = free look (camera / head turns, springs back
##         on release); the plane keeps flying to the aim.
##  STICK (classic)
##   LEFT - invisible floating stick (bank / pull), dead zone + curve.
##   RIGHT free area - drag = free look, as above.
##  Both: right edge THROTTLE lever (stays where left, top = afterburner),
##  FIRE / MISSILE / LOOP icon buttons in an arc, VIEW / PAUSE / INTEL at the
##  top. DOUBLE TAP anywhere off the buttons = release FLARES.
## Keyboard: arrows / WASD (aim: move the aim; stick: bank / pitch), T / G
## throttle, Shift afterburner, Space/J fire, M missile, L loop, R flares,
## C/V view, Esc/P pause, I intel, Q / E look left / right, middle mouse
## drag = look; in the aim scheme the mouse moves the aim.

signal cam_pressed
signal pause_pressed
signal flares_pressed
signal loop_pressed
signal missile_pressed
signal intel_pressed
signal tutorial_pressed

enum { AIM, STICK }
var scheme := AIM
var aim_sens := 1.0 # swipe sensitivity
## Aim scheme input: true = floating joystick moves the aim, false = swipe.
var aim_joy := true
var aim_speed := 1.0 # joystick: aim speed multiplier
## The player's nose (set by the plane each frame; INF = unknown): the
## joystick may not run the aim more than AIM_LEAD_MAX ahead of it.
var nose_dir := Vector3.INF
## Where the player wants to fly (world direction, unit length).
var aim_dir := Vector3.FORWARD

var stick := Vector2.ZERO # x: + = bank right, y: + = pull (already inverted)
var look := Vector2.ZERO # free look (rad, x + = left, y + = up)
var looking := false
var debug_look := Vector2.INF # tests / screenshots: fixed look
var boost := false # afterburner requested (throttle in the AB zone or Shift)
var fire := false
var throttle := 0.85 # lever position 0..1 (Jet.THR_MIL = military, >= THR_AB = afterburner)
var alt_axis := 0.0 # kept for API compatibility (always 0)
var touch_seen := false
var ui_scale := 1.0
var invert := false
var enabled := true
var helper_buttons := true
## While aiming: the finger on the trackpad (for the HUD).
var aiming := false

## Button shapes in screen px. Round buttons store their bounding square.
var btn := {} # name -> Rect2
const ROUND := ["fire", "missile", "loop"]
var throttle_rect := Rect2()
var drag_radius := 110.0
var drag_start := Vector2.ZERO
var drag_pos := Vector2.ZERO
var dragging := false
var show_indicator := true
const DEAD_ZONE := 0.08
const CURVE := 1.6
const TAP_MS := 220
const DOUBLE_TAP_MS := 330
const STICK_ZONE := 0.6 # left share of the screen: stick / aim trackpad
const AB_ZONE := 0.92
## One screen height of trackpad drag turns the aim this far (rad) at
## sensitivity 1.
const AIM_PER_SCREEN := 2.0
const LOOK_PER_SCREEN := 2.4
## Joystick: aim speed at full deflection (rad/s, speed 1), response curve,
## and how far the aim may lead the nose (then the plane just keeps turning).
const AIM_JOY_RATE := 1.5
const AIM_JOY_CURVE := 2.0
const AIM_LEAD_MAX := 0.9
var pressed := {} # name -> bool (for drawing)

var _touch_role := {} # index -> role
var _touch_t0 := {} # index -> msec
var _touch_p0 := {}
var _touch_last := {}
var _touch_max := {} # index -> furthest movement (px)
var _drag_index := -1
var _look_index := -1
var _mouse_fire := false
var _mouse_look := false
var _look_drag := Vector2.ZERO
var _last_tap_ms := -10000

# diagnostics
var last_touch := Vector2(-1, -1)
var touch_count := 0
var last_touch_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_seen = DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	ui_scale = clampf(s.y / 720.0, 0.6, 3.0)
	var u := ui_scale
	var m := 22.0 * u
	var tw := 78.0 * u
	throttle_rect = Rect2(Vector2(s.x - m - tw, 132.0 * u), Vector2(tw, s.y - m - 132.0 * u))
	# icon buttons on an arc around the right thumb, left of the throttle
	var c := Vector2(throttle_rect.position.x - 56.0 * u, s.y - m)
	var r := 215.0 * u
	btn = {
		"fire": _round(c + Vector2(cos(deg_to_rad(198.0)), sin(deg_to_rad(198.0))) * r, 66.0 * u),
		"missile": _round(c + Vector2(cos(deg_to_rad(236.0)), sin(deg_to_rad(236.0))) * r, 52.0 * u),
		"loop": _round(c + Vector2(cos(deg_to_rad(270.0)), sin(deg_to_rad(270.0))) * r, 46.0 * u),
		"pause": Rect2(Vector2(s.x - m - 64.0 * u, m), Vector2(64.0 * u, 56.0 * u)),
		"view": Rect2(Vector2(s.x - m - 64.0 * u * 2.0 - 14.0 * u, m), Vector2(64.0 * u, 56.0 * u)),
		"intel": Rect2(Vector2(s.x - m - 64.0 * u * 2.0 - 14.0 * u * 2.0 - 120.0 * u, m), Vector2(120.0 * u, 56.0 * u)),
		"tutorial": Rect2(Vector2(-1000, -1000), Vector2(1, 1)),
	}
	drag_radius = 90.0 * u


func _round(center: Vector2, radius: float) -> Rect2:
	return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


## For tests / HUD: centre of a button (or of the throttle lever).
func button_center(n: String) -> Vector2:
	if n == "throttle":
		return throttle_rect.get_center()
	return btn[n].get_center()


## Screen point on the throttle lever for a lever value (tests, HUD).
func throttle_point(v: float) -> Vector2:
	var t := throttle_rect
	return Vector2(t.get_center().x, t.end.y - 8.0 * ui_scale - v * (t.size.y - 16.0 * ui_scale))


func reset() -> void:
	_touch_role.clear()
	_drag_index = -1
	_look_index = -1
	dragging = false
	aiming = false
	stick = Vector2.ZERO
	_look_drag = Vector2.ZERO
	pressed.clear()
	throttle = Jet.THR_MIL


## Point the aim along a direction (spawn, respawn, leaving the area).
func set_aim(dir: Vector3) -> void:
	if dir.length_squared() > 1e-6:
		aim_dir = dir.normalized()


## Turn the aim by a yaw (rad, + = left) and pitch (rad, + = up); pitch is
## kept within +-80 degrees.
func turn_aim(yaw: float, pitch: float) -> void:
	var d := Basis(Vector3.UP, yaw) * aim_dir
	var p := asin(clampf(d.y, -1.0, 1.0))
	var np := clampf(p + pitch, -1.4, 1.4)
	var flat := Vector2(d.x, d.z)
	if flat.length() < 1e-4:
		flat = Vector2(0, -1)
	flat = flat.normalized() * cos(np)
	aim_dir = Vector3(flat.x, sin(np), flat.y).normalized()


## Joystick deflection after the dead zone and the response curve
## (x + = right, y + = down), length 0..1.
func joy_vector() -> Vector2:
	var d := ((drag_pos - drag_start) / drag_radius).limit_length(1.0)
	var m := d.length()
	if m < DEAD_ZONE:
		return Vector2.ZERO
	return d / m * pow((m - DEAD_ZONE) / (1.0 - DEAD_ZONE), AIM_JOY_CURVE)


## Keep the aim within AIM_LEAD_MAX of the nose: holding the joystick then
## means "keep turning" instead of running the circle round behind.
func _limit_lead() -> void:
	if nose_dir == Vector3.INF:
		return
	var a := nose_dir.angle_to(aim_dir)
	if a <= AIM_LEAD_MAX:
		return
	var ax := nose_dir.cross(aim_dir)
	if ax.length_squared() < 1e-8:
		return
	aim_dir = nose_dir.rotated(ax.normalized(), AIM_LEAD_MAX).normalized()


func _aim_drag(d: Vector2) -> void:
	if not enabled:
		return
	var hs := get_viewport().get_visible_rect().size.y
	var k := AIM_PER_SCREEN * aim_sens / maxf(1.0, hs)
	turn_aim(-d.x * k, (d.y if invert else -d.y) * k)


func _hit_button(p: Vector2) -> String:
	for n in btn:
		if n == "tutorial" or (not helper_buttons and n == "intel"):
			continue
		var r: Rect2 = btn[n]
		if n in ROUND:
			if p.distance_to(r.get_center()) < r.size.x * 0.5 + 6.0 * ui_scale:
				return n
		elif r.grow(6.0 * ui_scale).has_point(p):
			return n
	if throttle_rect.grow(10.0 * ui_scale).has_point(p):
		return "throttle"
	return ""


func _set_throttle_from(p: Vector2) -> void:
	var t := throttle_rect
	throttle = clampf((t.end.y - 8.0 * ui_scale - p.y) / (t.size.y - 16.0 * ui_scale), 0.0, 1.0)


## A quick touch (short, no movement) ended: two of them close together =
## flares.
func _tap() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < DOUBLE_TAP_MS:
		_last_tap_ms = -10000
		if enabled:
			flares_pressed.emit()
	else:
		_last_tap_ms = now


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_seen = true
		var e := event as InputEventScreenTouch
		if e.pressed:
			last_touch = e.position
			touch_count += 1
			last_touch_ms = Time.get_ticks_msec()
			var b := _hit_button(e.position)
			if b == "pause":
				pause_pressed.emit()
				return
			if b == "intel":
				intel_pressed.emit()
				return
			if not enabled:
				return
			match b:
				"view":
					cam_pressed.emit()
				"loop":
					loop_pressed.emit()
				"missile":
					missile_pressed.emit()
				"throttle":
					_set_throttle_from(e.position)
			_touch_t0[e.index] = Time.get_ticks_msec()
			_touch_p0[e.index] = e.position
			_touch_last[e.index] = e.position
			_touch_max[e.index] = 0.0
			var left := e.position.x < get_viewport().get_visible_rect().size.x * STICK_ZONE
			if b != "":
				_touch_role[e.index] = b
			elif left and _drag_index < 0:
				_drag_index = e.index
				if scheme == AIM and not aim_joy:
					_touch_role[e.index] = "aim"
					aiming = true
				else:
					aiming = scheme == AIM
					_touch_role[e.index] = "drag"
					drag_start = e.position
					drag_pos = e.position
					dragging = true
			elif not left and _look_index < 0:
				_touch_role[e.index] = "look"
				_look_index = e.index
				_look_drag = Vector2.ZERO
			else:
				_touch_role[e.index] = "tap" # extra finger: only taps count
		else:
			var role: String = _touch_role.get(e.index, "")
			_touch_role.erase(e.index)
			if role in ["drag", "aim", "look", "tap"]:
				var dt: int = Time.get_ticks_msec() - int(_touch_t0.get(e.index, 0))
				var moved: float = maxf(float(_touch_max.get(e.index, 0.0)), e.position.distance_to(_touch_p0.get(e.index, e.position)))
				if dt < TAP_MS and moved < 12.0 * ui_scale:
					_tap()
			if e.index == _drag_index:
				_drag_index = -1
				dragging = false
				aiming = false
			if e.index == _look_index:
				_look_index = -1
				_look_drag = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _touch_p0.has(e.index):
			_touch_max[e.index] = maxf(float(_touch_max.get(e.index, 0.0)), e.position.distance_to(_touch_p0[e.index]))
		var role: String = _touch_role.get(e.index, "")
		if role == "throttle" and enabled:
			_set_throttle_from(e.position)
		elif role == "aim":
			_aim_drag(e.position - _touch_last.get(e.index, e.position))
		elif role == "look":
			_look_drag = e.position - _touch_p0.get(e.index, e.position)
		elif e.index == _drag_index:
			drag_pos = e.position
			var d := drag_pos - drag_start
			if d.length() > drag_radius * 1.5:
				drag_start = drag_pos - d.normalized() * drag_radius * 1.5
		_touch_last[e.index] = e.position
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _mouse_look:
			_look_drag += mm.relative
		elif scheme == AIM and enabled and not touch_seen:
			_aim_drag(mm.relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_fire = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mouse_look = mb.pressed
			_look_drag = Vector2.ZERO
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			throttle = minf(1.0, throttle + 0.05)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			throttle = maxf(0.0, throttle - 0.05)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_C, KEY_V:
				if enabled:
					cam_pressed.emit()
			KEY_ESCAPE, KEY_P:
				pause_pressed.emit()
			KEY_R:
				if enabled:
					flares_pressed.emit()
			KEY_L:
				if enabled:
					loop_pressed.emit()
			KEY_M:
				if enabled:
					missile_pressed.emit()
			KEY_I:
				intel_pressed.emit()


## Per-axis dead zone + response curve: small moves are precise, full
## deflection is fast.
func _curve(v: Vector2) -> Vector2:
	return Vector2(_axis(v.x), _axis(v.y))


func _axis(a: float) -> float:
	var m := absf(a)
	if m < DEAD_ZONE:
		return 0.0
	return signf(a) * pow((m - DEAD_ZONE) / (1.0 - DEAD_ZONE), CURVE)


func _process(delta: float) -> void:
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		k.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		k.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		k.y += 1.0
	if Input.is_physical_key_pressed(KEY_T):
		throttle = minf(1.0, throttle + 0.6 * delta)
	if Input.is_physical_key_pressed(KEY_G):
		throttle = maxf(0.0, throttle - 0.6 * delta)
	if scheme == AIM:
		# keys move the aim (W = aim down like a stick push, S = up)
		if k != Vector2.ZERO and enabled:
			turn_aim(-k.x * 1.3 * delta, k.y * 1.0 * delta * (-1.0 if invert else 1.0))
		# floating joystick: the aim keeps moving while it is held
		if aim_joy and dragging and enabled:
			var v := joy_vector()
			if v != Vector2.ZERO:
				var rate := AIM_JOY_RATE * aim_speed * delta
				turn_aim(-v.x * rate, (v.y if invert else -v.y) * rate)
				_limit_lead()
		stick = Vector2.ZERO
	else:
		var t := Vector2.ZERO
		if dragging:
			t = _curve(((drag_pos - drag_start) / drag_radius).limit_length(1.0))
		var raw := t if k == Vector2.ZERO else k
		# screen-down = pull (+y); invert flips it
		stick = Vector2(raw.x, -raw.y if invert else raw.y)
	# free look: drag on the right side (or middle mouse); one screen height
	# of drag turns the view ~140 degrees; Q / E look left / right
	var lk := Vector2.ZERO
	var kq := Input.is_physical_key_pressed(KEY_Q)
	var ke := Input.is_physical_key_pressed(KEY_E)
	if kq and ke:
		lk = Vector2(2.0, 0.2)
	elif kq:
		lk = Vector2(1.5, 0.05)
	elif ke:
		lk = Vector2(-1.5, 0.05)
	var look_held := _look_index >= 0 or _mouse_look
	if look_held:
		var hs := get_viewport().get_visible_rect().size.y
		lk = Vector2(-_look_drag.x, -_look_drag.y) / hs * LOOK_PER_SCREEN
	if debug_look != Vector2.INF:
		lk = debug_look
	looking = lk != Vector2.ZERO or look_held
	look = lk
	pressed.clear()
	var held_fire := false
	for i in _touch_role:
		var r: String = _touch_role[i]
		pressed[r] = true
		if r == "fire":
			held_fire = true
	boost = throttle >= AB_ZONE or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_K)
	fire = held_fire or _mouse_fire or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J)
	if not enabled:
		stick = Vector2.ZERO
		fire = false


## Short vibration (hits, lock, stall, crash) if enabled in the settings.
static func haptic(ms: int, strength: float = 0.6) -> void:
	if not bool(Save.settings.get("vibration", true)):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, strength)
