class_name SettingsScreen
extends Control
## Pause-menu settings screen: a scrollable list of sections with sliders,
## toggles and segmented choices. Values live in Save.settings (user://).
## Touch: drag a slider to set it, tap toggles/choices, drag elsewhere to
## scroll. DONE (or Esc) closes and applies.

signal closed
signal changed(key: String)

## [section, key, label, type, default, a, b, step]  type: f = slider, b = toggle, c = choice (a = options)
const SCHEMA := [
	["FLIGHT", "speed", "Speed", "f", 130.0, 40.0, 300.0, 1.0],
	["FLIGHT", "boost", "Thruster boost (x speed while held)", "f", 1.8, 1.0, 3.0, 0.05],
	["FLIGHT", "turn", "Turn rate", "f", 1.25, 0.5, 3.0, 0.05],
	["FLIGHT", "bank", "Bank angle", "f", 52.0, 0.0, 85.0, 1.0],
	["FLIGHT", "cruise", "Cruising altitude", "f", 220.0, 60.0, 800.0, 10.0],
	["FLIGHT", "ceiling", "Ceiling (highest it climbs)", "f", 3000.0, 400.0, 6000.0, 100.0],
	["FLIGHT", "clearance", "Ground clearance (lowest it skims)", "f", 14.0, 4.0, 80.0, 1.0],
	["FLIGHT", "wingmen", "Wingmen", "f", 1.0, 0.0, 3.0, 1.0],
	["FLIGHT", "invert", "Invert climb/dive (drag up climbs)", "b", false],
	["FLIGHT", "crashes", "Crashes (dive into the ground to eject)", "b", true],
	["COMBAT", "team_size", "Team size (bots per side)", "f", 4.0, 2.0, 8.0, 1.0],
	["COMBAT", "cannon", "Cannon rounds before a reload", "f", 300.0, 50.0, 1000.0, 50.0],
	["COMBAT", "missiles", "Missiles before a reload", "f", 6.0, 1.0, 20.0, 1.0],
	["COMBAT", "reload", "Reload time (seconds)", "f", 5.0, 1.0, 15.0, 0.5],
	["COMBAT", "enemy_jets", "Enemy jets", "f", 3.0, 0.0, 8.0, 1.0],
	["COMBAT", "slowmo", "Dodge slow motion (seconds, 0 = off)", "f", 1.3, 0.0, 3.0, 0.1],
	["CAMERA", "view", "View", "c", 1, ["top", "chase", "cockpit"]],
	["CAMERA", "view_change", "View change (seconds)", "f", 1.4, 0.3, 3.0, 0.1],
	["CAMERA", "overhead_follow", "Overhead: turn with the jet", "f", 0.6, 0.0, 1.0, 0.05],
	["CAMERA", "chase_dist", "Chase: distance (jet lengths)", "f", 2.6, 1.5, 6.0, 0.1],
	["CAMERA", "chase_height", "Chase: height (degrees)", "f", 25.0, 5.0, 60.0, 1.0],
	["WORLD", "time", "Time of day", "c", 0, ["day", "sunset", "night"]],
	["WORLD", "day_cycle", "Day/night cycle", "b", false],
	["WORLD", "islands", "Islands", "f", 0.33, 0.15, 0.6, 0.01],
	["WORLD", "clouds", "Clouds", "f", 0.45, 0.0, 1.0, 0.05],
	["WORLD", "seed", "World seed", "f", 7.0, 1.0, 99.0, 1.0],
	["WORLD", "jet_shadow", "Jet shadow", "b", true],
	["WORLD", "traffic", "Traffic", "c", 1, ["off", "low", "normal"]],
	["LOOK", "glow", "Glow (fire, sun, engines, glints)", "f", 0.6, 0.0, 2.0, 0.05],
	["LOOK", "contrast", "Colour depth and contrast", "f", 0.05, 0.0, 1.0, 0.05],
	["LOOK", "vignette", "Darkened corners", "f", 0.2, 0.0, 1.0, 0.05],
	["LOOK", "grain", "Film grain", "f", 0.1, 0.0, 1.0, 0.05],
	["LOOK", "sprite_snap", "Sprite turn: 64 steps", "b", false],
	["EFFECTS", "flames", "Thruster flames", "c", 0, ["pixel", "realistic"]],
	["EFFECTS", "afterburner", "Afterburner", "f", 0.75, 0.0, 2.0, 0.05],
	["EFFECTS", "trails", "Wingtip trails", "b", true],
	["EFFECTS", "spray", "Wake and spray low over the sea", "f", 1.0, 0.0, 2.0, 0.1],
	["EFFECTS", "sparks", "Explosion: flash and sparks", "f", 0.6, 0.0, 2.0, 0.1],
	["EFFECTS", "shake", "Explosion: camera shake", "f", 1.0, 0.0, 2.0, 0.1],
	["HELPERS", "touch_buttons", "Touch buttons", "c", 0, ["auto", "on", "off"]],
	["HELPERS", "stick_indicator", "Floating stick indicator", "b", true],
	["HELPERS", "helper_buttons", "Intel button", "b", true],
	["HELPERS", "debug", "Debug overlay (FPS, draw calls)", "b", false],
	["LANGUAGE", "lang", "Language", "c", 0, ["auto", "English", "Українська"]],
	["SOUND", "sound", "Sound", "b", true],
	["SOUND", "volume", "Volume", "f", 0.6, 0.0, 1.0, 0.05],
]


static func defaults() -> Dictionary:
	var d := {}
	for r in SCHEMA:
		d[r[1]] = r[4]
	return d


var font: Font
var s := 1.0
var scroll := 0.0
var _rows: Array = [] # [rect, schema_row] or [rect, "section", name]
var _done := Rect2()
var _drag_slider := -1
var _drag_scroll := false
var _drag_y := 0.0
var _press_p := Vector2.ZERO
var _content_h := 0.0
var _open_t := 0.0
var _reset := Rect2()
var _confirm := false # reset confirmation dialog open
var _yes := Rect2()
var _no := Rect2()
## Keys that RESET TO DEFAULTS keeps (not settings in the schema sense).
const KEEP_ON_RESET := ["map", "lang"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = UI.base_font()
	visible = false


func open() -> void:
	scroll = 0.0
	_open_t = 0.0
	_confirm = false
	visible = true


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _panel_rect() -> Rect2:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	var w := minf(vs.x - 40 * s, 980 * s)
	return Rect2(Vector2((vs.x - w) * 0.5, 20 * s), Vector2(w, vs.y - 40 * s))


func _layout() -> void:
	var pr := _panel_rect()
	_rows.clear()
	var y := pr.position.y + 70 * s - scroll
	var rh := 52.0 * s
	var last := ""
	for r in SCHEMA:
		if r[0] != last:
			last = r[0]
			_rows.append([Rect2(Vector2(pr.position.x + 20 * s, y), Vector2(pr.size.x - 40 * s, 40 * s)), "section", last])
			y += 40 * s
		_rows.append([Rect2(Vector2(pr.position.x + 20 * s, y), Vector2(pr.size.x - 40 * s, rh - 8 * s)), r])
		y += rh
	_content_h = y + scroll - (pr.position.y + 70 * s)
	_done = Rect2(Vector2(pr.end.x - 170 * s, pr.position.y + 12 * s), Vector2(150 * s, 46 * s))
	_reset = Rect2(Vector2(_done.position.x - 250 * s, _done.position.y), Vector2(234 * s, 46 * s))
	var cw := 520.0 * s
	var cc := pr.get_center()
	_yes = Rect2(Vector2(cc.x + 10 * s, cc.y + 20 * s), Vector2(cw * 0.5 - 30 * s, 56 * s))
	_no = Rect2(Vector2(cc.x - cw * 0.5 + 20 * s, cc.y + 20 * s), Vector2(cw * 0.5 - 30 * s, 56 * s))


func _val(key: String) -> Variant:
	return Save.settings.get(key, defaults()[key])


func _draw() -> void:
	_layout()
	var pr := _panel_rect()
	_open_t += get_process_delta_time()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2(0, UI.slide(_open_t, s)))
	UI.panel(self, pr, s, Color(0.04, 0.06, 0.14, 0.95), UI.BORDER)
	var clip_top := pr.position.y + 64 * s
	var clip_bot := pr.end.y - 8 * s
	for row in _rows:
		var r: Rect2 = row[0]
		if r.position.y < clip_top or r.end.y > clip_bot:
			continue
		if row[1] is String:
			_t(Vector2(r.position.x + 6 * s, r.position.y + 28 * s), "> " + tr(row[2]), 16, UI.MUTED)
			continue
		var sc: Array = row[1]
		UI.panel(self, r, s, UI.NAVY, UI.BORDER_DIM)
		var key: String = sc[1]
		var ty := r.position.y + r.size.y * 0.5 + 6 * s
		match sc[3]:
			"f":
				var v: float = _val(key)
				var fr := (v - float(sc[5])) / (float(sc[6]) - float(sc[5]))
				# pixel slider: track + fill + square knob on the right half
				var tr0 := Rect2(Vector2(r.position.x + r.size.x * 0.5, r.get_center().y - 4 * s), Vector2(r.size.x * 0.36, 8 * s))
				tr0 = Rect2(tr0.position.round(), tr0.size.round())
				draw_rect(tr0, Color(0, 0, 0, 0.5))
				draw_rect(Rect2(tr0.position, Vector2(roundf(tr0.size.x * clampf(fr, 0.0, 1.0)), tr0.size.y)), UI.BLUE)
				var kx := roundf(tr0.position.x + tr0.size.x * clampf(fr, 0.0, 1.0) - 6 * s)
				var kn := Rect2(Vector2(kx, r.get_center().y - 10 * s), Vector2(12 * s, 20 * s))
				UI.panel(self, kn, s, UI.WHITE_FILL, Color.WHITE)
				_tfit(Vector2(r.position.x + 16 * s, ty), sc[2], 18, UI.TEXT, r.size.x * 0.47)
				var txt := str(int(v)) if float(sc[7]) >= 1.0 else ("%.2f" % v).rstrip("0").rstrip(".")
				_t(Vector2(r.end.x - 110 * s, ty), txt, 18, UI.TEXT, 96 * s, HORIZONTAL_ALIGNMENT_RIGHT)
			"b":
				_tfit(Vector2(r.position.x + 16 * s, ty), sc[2], 18, UI.TEXT, r.size.x - 110 * s)
				var on: bool = _val(key)
				var tg := Rect2(Vector2(r.end.x - 76 * s, r.get_center().y - 13 * s), Vector2(56 * s, 26 * s))
				UI.panel(self, tg, s, UI.ORANGE if on else Color(0.12, 0.14, 0.22), UI.ORANGE_HI if on else UI.BORDER_DIM)
				var kx := tg.end.x - 24 * s if on else tg.position.x + 4 * s
				draw_rect(Rect2(Vector2(kx, tg.position.y + 4 * s).round(), Vector2(20 * s, 18 * s).round()), Color.WHITE)
			"c":
				var opts: Array = sc[5]
				var ow := 118.0 * s
				_tfit(Vector2(r.position.x + 16 * s, ty), sc[2], 18, UI.TEXT, r.size.x - ow * opts.size() - 30 * s)
				var cur: int = int(_val(key))
				for i in opts.size():
					var orr := _opt_rect(r, opts.size(), i, ow)
					UI.button(self, orr, tr(opts[i]), s, UI.SELECTED if i == cur else UI.NORMAL, 16, "opt_%s_%d" % [key, i])
	# header (drawn last so it covers scrolled rows)
	draw_rect(Rect2(pr.position + Vector2(2, 2) * s, Vector2(pr.size.x - 4 * s, 62 * s)), Color(0.04, 0.06, 0.14))
	_t(Vector2(pr.position.x + 24 * s, pr.position.y + 44 * s), "SETTINGS", 32, UI.TEXT)
	UI.button(self, _done, tr("DONE"), s, UI.PRIMARY, 20, "DONE")
	UI.button(self, _reset, tr("RESET TO DEFAULTS"), s, UI.NORMAL, 16, "RESET TO DEFAULTS")
	if _confirm:
		draw_rect(pr, Color(0, 0, 0, 0.6))
		var cc := pr.get_center()
		var box := Rect2(Vector2(cc.x - 280 * s, cc.y - 90 * s), Vector2(560 * s, 196 * s))
		UI.panel(self, box, s, UI.NAVY_HI, UI.BORDER)
		var q := tr("Reset all settings to their default values?")
		UI.text(self, Vector2(box.position.x, box.position.y + 56 * s), q, UI.fit(q, 20 * s, box.size.x - 30 * s), UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		UI.button(self, _yes, tr("RESET"), s, UI.PRIMARY, 20, "RESET")
		UI.button(self, _no, tr("CANCEL"), s, UI.NORMAL, 20, "CANCEL")
	draw_set_transform(Vector2.ZERO)


func _opt_rect(r: Rect2, n: int, i: int, ow: float) -> Rect2:
	return Rect2(Vector2(r.end.x - 10 * s - ow * (n - i), r.position.y + 5 * s), Vector2(ow - 4 * s, r.size.y - 10 * s))


func _t(p: Vector2, txt: String, size: float, col: Color, w: float = -1.0, al: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	UI.text(self, p, tr(txt), size * s, col, al, w)


## Label that shrinks (on the pixel grid) to fit a width.
func _tfit(p: Vector2, txt: String, size: float, col: Color, w: float) -> void:
	var t := tr(txt)
	UI.text(self, p, t, UI.fit(t, size * s, w), col)


func set_value(key: String, v: Variant) -> void:
	Save.settings[key] = v
	changed.emit(key)


func _slider_at(i: int, x: float) -> void:
	var r: Rect2 = _rows[i][0]
	var sc: Array = _rows[i][1]
	# the track covers 50%..86% of the row (see _draw)
	var fr := clampf((x - (r.position.x + r.size.x * 0.5)) / (r.size.x * 0.36), 0.0, 1.0)
	var v := lerpf(float(sc[5]), float(sc[6]), fr)
	v = snappedf(v, float(sc[7]))
	set_value(sc[1], v)


func _row_at(p: Vector2) -> int:
	for i in _rows.size():
		if _rows[i][0].has_point(p) and not (_rows[i][1] is String):
			return i
	return -1


## Restore every schema default (keeps the chosen map and language).
func reset_to_defaults() -> void:
	var keep := {}
	for k in KEEP_ON_RESET:
		if Save.settings.has(k):
			keep[k] = Save.settings[k]
	Save.settings = defaults()
	Save.settings.merge(keep, true)
	Save.store()
	changed.emit("")
	changed.emit("islands")


func _press(p: Vector2) -> void:
	_layout()
	_press_p = p
	if _confirm:
		if _yes.has_point(p):
			UI.press("RESET")
			_confirm = false
			reset_to_defaults()
		elif _no.has_point(p):
			_confirm = false
		return
	if _reset.has_point(p):
		UI.press("RESET TO DEFAULTS")
		_confirm = true
		return
	if _done.has_point(p):
		UI.press("DONE")
		visible = false
		Save.store()
		closed.emit()
		return
	var i := _row_at(p)
	if i >= 0 and _rows[i][1][3] == "f" and p.x > _rows[i][0].position.x + _rows[i][0].size.x * 0.45:
		_drag_slider = i
		_slider_at(i, p.x)
		return
	_drag_scroll = true
	_drag_y = p.y


func _release(p: Vector2) -> void:
	if _confirm:
		return
	if _drag_scroll and p.distance_to(_press_p) < 12.0 * s:
		var i := _row_at(p)
		if i >= 0:
			var sc: Array = _rows[i][1]
			match sc[3]:
				"b":
					set_value(sc[1], not bool(_val(sc[1])))
				"c":
					var opts: Array = sc[5]
					for k in opts.size():
						if _opt_rect(_rows[i][0], opts.size(), k, 118.0 * s).has_point(p):
							set_value(sc[1], k)
				"f":
					_slider_at(i, p.x)
	_drag_slider = -1
	_drag_scroll = false


func _move(p: Vector2) -> void:
	if _drag_slider >= 0:
		_slider_at(_drag_slider, p.x)
	elif _drag_scroll:
		var pr := _panel_rect()
		scroll = clampf(scroll - (p.y - _drag_y), 0.0, maxf(0.0, _content_h - (pr.size.y - 80 * s)))
		_drag_y = p.y


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0:
			_move(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			scroll += 60 * s
			_move(Vector2.ZERO)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			scroll = maxf(0.0, scroll - 60 * s)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(event.position)
			else:
				_release(event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_move(event.position)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		visible = false
		Save.store()
		closed.emit()
		get_viewport().set_input_as_handled()
