class_name Hud
extends Control
## Full-resolution HUD drawn on top of the pixel view (stays sharp).

var game: Node # main.gd
var font: Font
var s := 1.0 # ui scale
var _t := 0.0

const C_TEXT := Color(1, 1, 1)
const C_SHADOW := Color(0, 0, 0, 0.75)
const C_HP := Color("6fae4a")
const C_HP_LOW := Color("c8402e")
const C_CITY := Color("43e0d8")
const C_BOOST := Color("ffb43c")
const C_PANEL := Color(0.04, 0.05, 0.1, 0.55)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func text(pos: Vector2, t: String, size: float, col: Color = C_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var fs := int(size * s)
	draw_string_outline(font, pos, t, align, width, fs, maxi(2, int(4 * s)), C_SHADOW)
	draw_string(font, pos, t, align, width, fs, col)


func ctext(center_x: float, y: float, t: String, size: float, col: Color = C_TEXT) -> void:
	var w := size_x()
	text(Vector2(center_x - w * 0.5, y), t, size, col, HORIZONTAL_ALIGNMENT_CENTER, w)


func size_x() -> float:
	return get_viewport_rect().size.x


func bar(pos: Vector2, w: float, h: float, frac: float, col: Color, label: String) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2) * s, Vector2(w, h) + Vector2(4, 4) * s), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h)), col)
	# pixel-ish segments
	var seg := 10
	for i in range(1, seg):
		draw_rect(Rect2(pos + Vector2(w * i / seg, 0), Vector2(maxf(1.0, s), h)), Color(0, 0, 0, 0.35))
	text(pos + Vector2(w + 10 * s, h - 2 * s), label, 18)


func _draw() -> void:
	if game == null:
		return
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	var c: Controls = game.controls
	var playing: bool = game.state == game.State.PLAY
	if playing or game.state == game.State.PAUSE:
		_draw_status(vs)
	if c != null and c.touch_seen and game.state == game.State.PLAY:
		_draw_touch(c)
	if game.state == game.State.PLAY:
		_draw_small_buttons(c)
	# banner
	if game.banner_time > 0.0 and game.banner != "":
		var a := clampf(game.banner_time, 0.0, 1.0)
		ctext(vs.x * 0.5, vs.y * 0.36, game.banner, 46, Color(1, 0.95, 0.6, a))
		if game.banner_sub != "":
			ctext(vs.x * 0.5, vs.y * 0.36 + 44 * s, game.banner_sub, 22, Color(1, 1, 1, a))
	if OS.is_debug_build() and game.show_debug:
		_draw_debug(vs)


func _draw_status(vs: Vector2) -> void:
	var jet: Jet = game.jet
	var x := 24.0 * s
	var y := 22.0 * s
	var w := 200.0 * s
	var h := 14.0 * s
	var hpf := jet.health / jet.max_health
	bar(Vector2(x, y), w, h, hpf, C_HP if hpf > 0.35 else C_HP_LOW, "HP")
	bar(Vector2(x, y + 26 * s), w, h, game.city_hp / game.city_max, C_CITY, "CITY")
	bar(Vector2(x, y + 52 * s), w * 0.6, h * 0.6, jet.boost_energy / 100.0, C_BOOST, "")
	ctext(vs.x * 0.5, 44 * s, "%07d" % game.score, 34)
	ctext(vs.x * 0.5, 70 * s, "HI %07d" % maxi(Save.high_score, game.score), 16, Color(1, 1, 1, 0.75))
	if game.wave > 0:
		text(Vector2(vs.x - 380 * s, 40 * s), "WAVE %d" % game.wave, 26)
		text(Vector2(vs.x - 380 * s, 64 * s), "ENEMIES %d" % game.enemies_left(), 16, Color(1, 0.8, 0.8))
	if jet.multiplier > 1:
		var pulse := 0.75 + 0.25 * sin(_t * 10.0)
		ctext(vs.x * 0.5, vs.y - 40 * s, "LOW FLYING  x%d" % jet.multiplier, 28, Color(1, 0.85, 0.3, pulse))


func _draw_touch(c: Controls) -> void:
	# joystick
	draw_circle(c.joy_center, c.joy_radius, Color(1, 1, 1, 0.10))
	draw_arc(c.joy_center, c.joy_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0 * s)
	draw_circle(c.joy_knob, c.joy_radius * 0.42, Color(1, 1, 1, 0.45 if c.joy_active else 0.25))
	# buttons
	_btn(c.fire_pos, c.btn_radius, "FIRE", c.fire, Color(1.0, 0.35, 0.3))
	_btn(c.boost_pos, c.btn_radius * 0.85, "BOOST", c.boost, Color(1.0, 0.75, 0.25))


func _btn(p: Vector2, r: float, label: String, pressed: bool, col: Color) -> void:
	var fill := col
	fill.a = 0.55 if pressed else 0.22
	draw_circle(p, r, fill)
	draw_arc(p, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.9), 3.0 * s)
	text(p + Vector2(-r, 8 * s), label, 20, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _draw_small_buttons(c: Controls) -> void:
	if c == null:
		return
	for p in [c.pause_pos, c.cam_pos]:
		draw_circle(p, c.small_radius, Color(0, 0, 0, 0.35))
		draw_arc(p, c.small_radius, 0, TAU, 32, Color(1, 1, 1, 0.6), 2.0 * s)
	# pause icon
	var pp: Vector2 = c.pause_pos
	draw_rect(Rect2(pp + Vector2(-9, -11) * s, Vector2(6, 22) * s), C_TEXT)
	draw_rect(Rect2(pp + Vector2(3, -11) * s, Vector2(6, 22) * s), C_TEXT)
	var mode_name: String = GameCamera.MODE_NAMES[game.cam.mode]
	text(c.cam_pos + Vector2(-c.small_radius, 6 * s), mode_name.substr(0, 3), 15, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, c.small_radius * 2.0)


func _draw_debug(vs: Vector2) -> void:
	var fps := Engine.get_frames_per_second()
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var lines := [
		"FPS %d   DRAW CALLS %d   OBJECTS %d" % [fps, dc, objs],
		"VIEW %dx%d x%d   CHUNKS %d   QUADS %dk" % [game.pv.low.x, game.pv.low.y, game.pv.pixel_scale, game.chunks.chunks.size(), game.chunks.total_quads() / 1000],
		game.debug_extra(),
	]
	var y := vs.y - 70 * s
	draw_rect(Rect2(Vector2(8 * s, y - 20 * s), Vector2(560 * s, 68 * s)), Color(0, 0, 0, 0.45))
	for l in lines:
		text(Vector2(14 * s, y), l, 14, Color(0.7, 1.0, 0.7))
		y += 20 * s
