class_name Controls
extends Node
## Input: floating virtual joystick (left half), BOOST + FIRE buttons (right),
## CAM + PAUSE buttons (top right). Keyboard/mouse for desktop testing:
##   WASD / arrows steer (screen-relative), Shift = boost, Space / LMB = fire,
##   C = camera, Esc / P = pause.

signal cam_pressed
signal pause_pressed

var stick := Vector2.ZERO # screen space, y down, length <= 1
var boost := false
var fire := false
var alt_axis := 0.0 # +1 climb, -1 dive (CLIMB/DIVE buttons, Q/E)
var show_alt_buttons := false
var climb_pos := Vector2.ZERO
var dive_pos := Vector2.ZERO
var _touch_climb := false
var _touch_dive := false
var touch_seen := false
var ui_scale := 1.0

# touch layout (screen px), recomputed on resize
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var joy_active := false
var joy_radius := 80.0
var boost_pos := Vector2.ZERO
var fire_pos := Vector2.ZERO
var btn_radius := 70.0
var cam_pos := Vector2.ZERO
var pause_pos := Vector2.ZERO
var small_radius := 36.0

var _touch_role := {} # index -> "joy"/"boost"/"fire"
var _touch_stick := Vector2.ZERO
var _touch_boost := false
var _touch_fire := false
var _mouse_fire := false
var enabled := true
# diagnostics (shown in the debug overlay)
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
	joy_radius = 80.0 * ui_scale
	btn_radius = 66.0 * ui_scale
	small_radius = 34.0 * ui_scale
	boost_pos = Vector2(s.x - 290.0 * ui_scale, s.y - 105.0 * ui_scale)
	fire_pos = Vector2(s.x - 120.0 * ui_scale, s.y - 175.0 * ui_scale)
	pause_pos = Vector2(s.x - 60.0 * ui_scale, 56.0 * ui_scale)
	cam_pos = Vector2(s.x - 145.0 * ui_scale, 56.0 * ui_scale)
	joy_center = Vector2(170.0 * ui_scale, s.y - 170.0 * ui_scale)
	climb_pos = Vector2(s.x - 290.0 * ui_scale, s.y - 290.0 * ui_scale)
	dive_pos = Vector2(s.x - 290.0 * ui_scale, s.y - 210.0 * ui_scale)
	if not joy_active:
		joy_knob = joy_center


func reset() -> void:
	_touch_role.clear()
	_touch_stick = Vector2.ZERO
	_touch_boost = false
	_touch_fire = false
	joy_active = false
	joy_knob = joy_center


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_seen = true
		var e := event as InputEventScreenTouch
		if e.pressed:
			last_touch = e.position
			touch_count += 1
			last_touch_ms = Time.get_ticks_msec()
			if e.position.distance_to(pause_pos) < small_radius * 1.4:
				pause_pressed.emit()
				return
			if not enabled:
				return
			if e.position.distance_to(cam_pos) < small_radius * 1.4:
				cam_pressed.emit()
				return
			if show_alt_buttons and e.position.distance_to(climb_pos) < small_radius * 1.2:
				_touch_role[e.index] = "climb"
			elif show_alt_buttons and e.position.distance_to(dive_pos) < small_radius * 1.2:
				_touch_role[e.index] = "dive"
			elif e.position.distance_to(fire_pos) < btn_radius * 1.3:
				_touch_role[e.index] = "fire"
			elif e.position.distance_to(boost_pos) < btn_radius * 1.3:
				_touch_role[e.index] = "boost"
			elif e.position.x < get_viewport().get_visible_rect().size.x * 0.5:
				_touch_role[e.index] = "joy"
				joy_active = true
				joy_center = e.position
				joy_knob = e.position
				_touch_stick = Vector2.ZERO
		else:
			var role: String = _touch_role.get(e.index, "")
			_touch_role.erase(e.index)
			if role == "joy":
				joy_active = false
				_touch_stick = Vector2.ZERO
				_layout()
		_refresh_buttons()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		var role: String = _touch_role.get(e.index, "")
		if role == "joy":
			var d := e.position - joy_center
			if d.length() > joy_radius * 1.6:
				# drag the base along so the stick never "runs out"
				joy_center += d - d.normalized() * joy_radius * 1.6
				d = e.position - joy_center
			var dl := d.limit_length(joy_radius)
			joy_knob = joy_center + dl
			_touch_stick = dl / joy_radius
		elif role == "fire" or role == "boost":
			# allow sliding between the two buttons
			var new_role := role
			if e.position.distance_to(fire_pos) < btn_radius * 1.3:
				new_role = "fire"
			elif e.position.distance_to(boost_pos) < btn_radius * 1.3:
				new_role = "boost"
			_touch_role[e.index] = new_role
			_refresh_buttons()
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if m.button_index == MOUSE_BUTTON_LEFT:
			_mouse_fire = m.pressed
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_C:
				if enabled:
					cam_pressed.emit()
			KEY_ESCAPE, KEY_P:
				pause_pressed.emit()


func _refresh_buttons() -> void:
	_touch_boost = false
	_touch_fire = false
	_touch_climb = false
	_touch_dive = false
	for i in _touch_role:
		match _touch_role[i]:
			"climb":
				_touch_climb = true
			"dive":
				_touch_dive = true
			"boost":
				_touch_boost = true
			"fire":
				_touch_fire = true


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
	stick = _touch_stick if k == Vector2.ZERO else k.normalized()
	boost = _touch_boost or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_K)
	fire = _touch_fire or _mouse_fire or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J)
	alt_axis = 0.0
	if _touch_climb or Input.is_physical_key_pressed(KEY_E):
		alt_axis += 1.0
	if _touch_dive or Input.is_physical_key_pressed(KEY_Q):
		alt_axis -= 1.0
	if not enabled:
		alt_axis = 0.0
		stick = Vector2.ZERO
		boost = false
		fire = false
