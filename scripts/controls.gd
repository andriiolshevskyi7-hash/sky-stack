class_name Controls
extends Node
## Touch: drag anywhere (outside the buttons) to fly - left/right turns, drag
## DOWN climbs, drag UP dives (invertible). A quick tap = barrel roll.
## Rectangular buttons: LOOP + VIEW (bottom left), MISSILE + GUN + BOOST
## (bottom right), pause (top right).
## Keyboard: A/D or arrows turn, S/Down climbs, W/Up dives, Shift boost,
## Space/J gun, M missile, L loop, R roll, C/V view, Esc/P pause.

signal cam_pressed
signal pause_pressed
signal roll_pressed
signal loop_pressed
signal missile_pressed
signal intel_pressed
signal tutorial_pressed

var stick := Vector2.ZERO # x: turn (+ right), y: + = climb, - = dive (already inverted)
var boost := false
var fire := false
var alt_axis := 0.0 # kept for API compatibility (always 0 now)
var touch_seen := false
var ui_scale := 1.0
var invert := false
var enabled := true

# button rects (screen px)
var btn := {} # name -> Rect2
var drag_radius := 110.0
var drag_start := Vector2.ZERO
var drag_pos := Vector2.ZERO
var dragging := false
var pressed := {} # name -> bool (for drawing)

var _touch_role := {} # index -> role
var _touch_t0 := {} # index -> msec
var _touch_p0 := {}
var _drag_index := -1
var _mouse_fire := false

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
	var m := 22.0 * ui_scale
	var bw := 128.0 * ui_scale
	var bh := 84.0 * ui_scale
	var gap := 14.0 * ui_scale
	btn = {
		"view": Rect2(Vector2(m, s.y - m - bh), Vector2(bw, bh)),
		"loop": Rect2(Vector2(m, s.y - m - bh * 2.0 - gap), Vector2(bw, bh)),
		"boost": Rect2(Vector2(s.x - m - bw, s.y - m - bh), Vector2(bw, bh)),
		"gun": Rect2(Vector2(s.x - m - bw * 2.0 - gap, s.y - m - bh), Vector2(bw, bh)),
		"missile": Rect2(Vector2(s.x - m - bw, s.y - m - bh * 2.0 - gap), Vector2(bw, bh)),
		"pause": Rect2(Vector2(s.x - m - 64.0 * ui_scale, m), Vector2(64.0 * ui_scale, 52.0 * ui_scale)),
		"tutorial": Rect2(Vector2(s.x - m - 64.0 * ui_scale - gap - 150.0 * ui_scale, m), Vector2(150.0 * ui_scale, 52.0 * ui_scale)),
		"intel": Rect2(Vector2(s.x - m - 64.0 * ui_scale - gap * 2.0 - 260.0 * ui_scale, m), Vector2(110.0 * ui_scale, 52.0 * ui_scale)),
	}
	drag_radius = 110.0 * ui_scale


## For tests/HUD: centre of a button.
func button_center(n: String) -> Vector2:
	return btn[n].get_center()


func reset() -> void:
	_touch_role.clear()
	_drag_index = -1
	dragging = false
	stick = Vector2.ZERO
	pressed.clear()


func _hit_button(p: Vector2) -> String:
	for n in btn:
		if btn[n].grow(6.0 * ui_scale).has_point(p):
			return n
	return ""


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
			if b == "tutorial":
				tutorial_pressed.emit()
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
			if b != "":
				_touch_role[e.index] = b
			elif _drag_index < 0:
				_touch_role[e.index] = "drag"
				_drag_index = e.index
				drag_start = e.position
				drag_pos = e.position
				dragging = true
				_touch_t0[e.index] = Time.get_ticks_msec()
				_touch_p0[e.index] = e.position
		else:
			var role: String = _touch_role.get(e.index, "")
			_touch_role.erase(e.index)
			if role == "drag":
				var dt: int = Time.get_ticks_msec() - int(_touch_t0.get(e.index, 0))
				var moved: float = e.position.distance_to(_touch_p0.get(e.index, e.position))
				if dt < 250 and moved < 14.0 * ui_scale and enabled:
					roll_pressed.emit()
				_drag_index = -1
				dragging = false
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _drag_index:
			drag_pos = e.position
			var d := drag_pos - drag_start
			if d.length() > drag_radius * 1.5:
				drag_start = drag_pos - d.normalized() * drag_radius * 1.5
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_fire = mb.pressed
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


func _process(_delta: float) -> void:
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		k.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		k.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		k.y += 1.0
	var t := Vector2.ZERO
	if dragging:
		t = ((drag_pos - drag_start) / drag_radius).limit_length(1.0)
	var raw := t if k == Vector2.ZERO else k
	# screen-down = climb (+y); invert flips it
	stick = Vector2(raw.x, -raw.y if invert else raw.y)
	pressed.clear()
	var held_boost := false
	var held_gun := false
	for i in _touch_role:
		var r: String = _touch_role[i]
		pressed[r] = true
		if r == "boost":
			held_boost = true
		elif r == "gun":
			held_gun = true
	boost = held_boost or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_K)
	fire = held_gun or _mouse_fire or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J)
	if not enabled:
		stick = Vector2.ZERO
		boost = false
		fire = false
