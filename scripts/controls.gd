class_name Controls
extends Node
## Touch controls for a landscape phone:
##  LEFT  (~60% of the screen) - invisible floating stick: touch anywhere,
##        that point is the stick centre; drag to bank / pull (shown as a
##        control-stick icon while held). Dead zone + response curve.
##  RIGHT edge - vertical THROTTLE lever: drag up / down, it stays where you
##        leave it; the top zone is the afterburner.
##  Icon buttons in an arc next to the throttle: FIRE (big), MISSILE, LOOP.
##  Small icons at the top: VIEW, PAUSE (+ INTEL).
##  DOUBLE TAP anywhere free = barrel roll (works with a second finger while
##  the first one keeps steering).
##  VIEW (eye): tap = next camera; hold and drag = look around in the
##  cockpit (springs back to the front when released).
## Keyboard: A/D or arrows bank, S/Down pull, W/Up push, T / G throttle up /
## down, Shift afterburner, Space/J fire, M missile, L loop, R roll, C/V view,
## Esc/P pause, I intel, hold Q / E look left / right (both = over the
## left shoulder),
## middle mouse drag = look around.

signal cam_pressed
signal pause_pressed
signal roll_pressed
signal loop_pressed
signal missile_pressed
signal intel_pressed
signal tutorial_pressed

var stick := Vector2.ZERO # x: + = bank right, y: + = pull (already inverted)
var look := Vector2.ZERO # head look in the cockpit (rad, x + = left, y + = up)
var looking := false
var debug_look := Vector2.INF # tests / screenshots: fixed head look
var boost := false # afterburner requested (throttle in the AB zone or Shift)
var fire := false
var throttle := 0.85 # lever position 0..1 (Jet.THR_MIL = military, >= THR_AB = afterburner)
var alt_axis := 0.0 # kept for API compatibility (always 0)
var touch_seen := false
var ui_scale := 1.0
var invert := false
var enabled := true
var helper_buttons := true

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
const STICK_ZONE := 0.6 # left share of the screen that starts the stick
const AB_ZONE := 0.92
var pressed := {} # name -> bool (for drawing)

var _touch_role := {} # index -> role
var _touch_t0 := {} # index -> msec
var _touch_p0 := {}
var _touch_max := {} # index -> furthest movement (px)
var _drag_index := -1
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
	dragging = false
	stick = Vector2.ZERO
	pressed.clear()
	throttle = Jet.THR_MIL


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


## A quick touch (short, no movement) ended: two of them close together = roll.
func _tap() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < DOUBLE_TAP_MS:
		_last_tap_ms = -10000
		if enabled:
			roll_pressed.emit()
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
					_look_drag = Vector2.ZERO # tap = next view (on release), drag = look
				"loop":
					loop_pressed.emit()
				"missile":
					missile_pressed.emit()
				"throttle":
					_set_throttle_from(e.position)
			_touch_t0[e.index] = Time.get_ticks_msec()
			_touch_p0[e.index] = e.position
			_touch_max[e.index] = 0.0
			if b != "":
				_touch_role[e.index] = b
			elif _drag_index < 0 and e.position.x < get_viewport().get_visible_rect().size.x * STICK_ZONE:
				_touch_role[e.index] = "drag"
				_drag_index = e.index
				drag_start = e.position
				drag_pos = e.position
				dragging = true
			else:
				_touch_role[e.index] = "tap" # free finger: only taps count
		else:
			var role: String = _touch_role.get(e.index, "")
			_touch_role.erase(e.index)
			if role == "view":
				var dtv: int = Time.get_ticks_msec() - int(_touch_t0.get(e.index, 0))
				var mv: float = maxf(float(_touch_max.get(e.index, 0.0)), e.position.distance_to(_touch_p0.get(e.index, e.position)))
				if mv < 14.0 * ui_scale and dtv < 450 and enabled:
					cam_pressed.emit()
				_look_drag = Vector2.ZERO
			if role == "drag" or role == "tap":
				var dt: int = Time.get_ticks_msec() - int(_touch_t0.get(e.index, 0))
				var moved: float = maxf(float(_touch_max.get(e.index, 0.0)), e.position.distance_to(_touch_p0.get(e.index, e.position)))
				if dt < TAP_MS and moved < 12.0 * ui_scale:
					_tap()
			if role == "drag":
				_drag_index = -1
				dragging = false
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _touch_p0.has(e.index):
			_touch_max[e.index] = maxf(float(_touch_max.get(e.index, 0.0)), e.position.distance_to(_touch_p0[e.index]))
		var role: String = _touch_role.get(e.index, "")
		if role == "throttle" and enabled:
			_set_throttle_from(e.position)
		elif role == "view":
			_look_drag = e.position - _touch_p0.get(e.index, e.position)
		elif e.index == _drag_index:
			drag_pos = e.position
			var d := drag_pos - drag_start
			if d.length() > drag_radius * 1.5:
				drag_start = drag_pos - d.normalized() * drag_radius * 1.5
	elif event is InputEventMouseMotion and _mouse_look:
		_look_drag += (event as InputEventMouseMotion).relative
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
					roll_pressed.emit()
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
	var t := Vector2.ZERO
	if dragging:
		t = _curve(((drag_pos - drag_start) / drag_radius).limit_length(1.0))
	var raw := t if k == Vector2.ZERO else k
	# screen-down = pull (+y); invert flips it
	stick = Vector2(raw.x, -raw.y if invert else raw.y)
	# head look: drag on the eye (or middle mouse) - one screen height of
	# drag turns the head ~140 degrees; Q / E look left / right, both = back
	var lk := Vector2.ZERO
	var kq := Input.is_physical_key_pressed(KEY_Q)
	var ke := Input.is_physical_key_pressed(KEY_E)
	if kq and ke:
		lk = Vector2(2.0, 0.2)
	elif kq:
		lk = Vector2(1.5, 0.05)
	elif ke:
		lk = Vector2(-1.5, 0.05)
	var view_held := _touch_role.values().has("view") or _mouse_look
	if view_held:
		var hs := get_viewport().get_visible_rect().size.y
		lk = Vector2(-_look_drag.x, -_look_drag.y) / hs * 2.4
	if debug_look != Vector2.INF:
		lk = debug_look
	looking = lk != Vector2.ZERO or view_held
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
