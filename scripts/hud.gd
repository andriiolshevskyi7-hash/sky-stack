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
	if (playing or game.state == game.State.PAUSE) and game.cam.cockpit_blend < 0.5:
		_draw_status(vs)
	elif playing:
		ctext(vs.x * 0.5, 44 * s, "%07d" % game.score, 30)
	if c != null and game.state == game.State.PLAY and game.touch_buttons_visible():
		_draw_touch(c)
	if game.state == game.State.PLAY:
		_draw_arrows(vs)
		_draw_small_buttons(c)
	# banner
	if game.banner_time > 0.0 and game.banner != "":
		var a := clampf(game.banner_time, 0.0, 1.0)
		ctext(vs.x * 0.5, vs.y * 0.36, game.banner, 46, Color(1, 0.95, 0.6, a))
		if game.banner_sub != "":
			ctext(vs.x * 0.5, vs.y * 0.36 + 44 * s, game.banner_sub, 22, Color(1, 1, 1, a))
	if OS.is_debug_build() and game.show_debug:
		_draw_debug(vs)
		# touch diagnostics: marker where the last touch landed
		if c != null and Time.get_ticks_msec() - c.last_touch_ms < 600:
			draw_arc(c.last_touch, 30.0 * s, 0, TAU, 24, Color(1, 1, 0, 0.9), 3.0 * s)


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.08, 0.14, 0.3, 0.72))


func _draw_status(vs: Vector2) -> void:
	var jet: Jet = game.jet
	var c: Controls = game.controls
	var x := 22.0 * s
	var y := 22.0 * s
	# KILLS + HULL panel (reference style)
	var pw := 360.0 * s
	var ph := 48.0 * s
	_panel(Rect2(Vector2(x, y), Vector2(pw, ph)))
	text(Vector2(x + 16 * s, y + 32 * s), "KILLS %02d" % game.kills, 20)
	text(Vector2(x + 150 * s, y + 32 * s), "HULL", 20)
	var segs := 7
	var lit := int(ceil(jet.health / jet.max_health * segs))
	for i in segs:
		var col := Color(1, 1, 1, 0.95) if i < lit else Color(1, 1, 1, 0.22)
		if i < lit and lit <= 2:
			col = Color(1.0, 0.3, 0.25)
		draw_rect(Rect2(Vector2(x + 210 * s + i * 18 * s, y + 13 * s), Vector2(11 * s, 22 * s)), col)
	# city + wave + altitude (small)
	_panel(Rect2(Vector2(x, y + ph + 8 * s), Vector2(pw, 30 * s)))
	text(Vector2(x + 16 * s, y + ph + 30 * s), "CITY", 15, Color(0.75, 0.9, 1.0))
	draw_rect(Rect2(Vector2(x + 70 * s, y + ph + 17 * s), Vector2(140 * s, 12 * s)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(Vector2(x + 70 * s, y + ph + 17 * s), Vector2(140 * s * game.city_hp / game.city_max, 12 * s)), C_CITY)
	if game.wave > 0 and not game.tutorial.active():
		text(Vector2(x + 225 * s, y + ph + 30 * s), "WAVE %d  %d" % [game.wave, game.enemies_left()], 15, Color(1, 0.85, 0.85))
	text(Vector2(x + 4 * s, y + ph + 66 * s), "ALT %d" % int(jet.position.y), 16, Color(0.85, 0.95, 1.0) if jet.position.y > CityGen.LOW_ALT else Color(1, 0.85, 0.3))
	# score
	ctext(vs.x * 0.5, 40 * s, "%07d" % game.score, 28)
	ctext(vs.x * 0.5, 62 * s, "HI %07d" % maxi(Save.high_score, game.score), 14, Color(1, 1, 1, 0.7))
	# INTEL / TUTORIAL buttons
	for n in ["intel", "tutorial"]:
		var r: Rect2 = c.btn[n]
		_panel(r)
		text(Vector2(r.position.x, r.get_center().y + 7 * s), n.to_upper(), 18, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if jet.multiplier > 1:
		var pulse := 0.75 + 0.25 * sin(_t * 10.0)
		ctext(vs.x * 0.5, vs.y - 40 * s, "LOW FLYING  x%d" % jet.multiplier, 26, Color(1, 0.85, 0.3, pulse))
	# tutorial instruction
	if game.tutorial.active():
		var tw := 760.0 * s
		var r := Rect2(Vector2(vs.x * 0.5 - tw * 0.5, 84 * s), Vector2(tw, 46 * s))
		_panel(r)
		text(Vector2(r.position.x, r.position.y + 31 * s), game.tutorial.text(), 20, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_draw_lock(vs)
	_draw_rings(vs)


func _screen(p: Vector3) -> Vector2:
	return game.cam.unproject_position(p) * game.pv.pixel_scale + game.pv.display.position


## Lock-on box around the target: white while locking, red when locked.
func _draw_lock(_vs: Vector2) -> void:
	var m: Missiles = game.missiles
	if m.lock_target == null or not m.lock_target.active or game.cam.is_position_behind(m.lock_target.pos):
		return
	var p := _screen(m.lock_target.pos)
	var k := clampf(m.lock_t / Missiles.LOCK_TIME, 0.0, 1.0)
	var half := lerpf(60.0, 28.0, k) * s
	var col := Color(1, 0.25, 0.2) if m.locked else Color(1, 1, 1, 0.8)
	var l := half * 0.45
	var w := maxf(2.0, 3.0 * s)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := p + Vector2(sx, sy) * half
			draw_line(c, c - Vector2(sx * l, 0), col, w)
			draw_line(c, c - Vector2(0, sy * l), col, w)
	if m.locked:
		text(p + Vector2(-half, half + 22 * s), "LOCK", 15, col, HORIZONTAL_ALIGNMENT_CENTER, half * 2.0)


## Incoming missile: an outer ring closes in on a fixed ring around the jet;
## roll when they meet to dodge.
func _draw_rings(_vs: Vector2) -> void:
	var m: Missiles = game.missiles
	if m.incoming_t > 2.0 or not game.jet.alive:
		return
	var p := _screen(game.jet.position) if not game.cam.is_position_behind(game.jet.position) else get_viewport_rect().size * 0.5
	var r0 := 46.0 * s
	var r1 := r0 + maxf(0.0, m.incoming_t - 0.3) * 150.0 * s
	var near := absf(r1 - r0) < 12.0 * s
	draw_arc(p, r0, 0, TAU, 48, Color(1, 1, 1, 0.9), maxf(2.0, 3.0 * s))
	draw_arc(p, r1, 0, TAU, 64, Color(1, 0.25, 0.2) if near else Color(1, 0.85, 0.3), maxf(2.0, 3.0 * s))
	if near:
		ctext(p.x, p.y - r0 - 14 * s, "ROLL!", 22, Color(1, 0.3, 0.25))


## Rectangular semi-transparent buttons (like the reference).
func _draw_touch(c: Controls) -> void:
	var jet: Jet = game.jet
	for n in ["loop", "view", "gun", "missile", "boost"]:
		var r: Rect2 = c.btn[n]
		var on: bool = c.pressed.get(n, false)
		draw_rect(r, Color(0.08, 0.13, 0.28, 0.62 if on else 0.42))
		draw_rect(r, Color(0.75, 0.85, 1.0, 0.55), false, maxf(1.0, 2.0 * s))
		var label: String = n.to_upper()
		var cy := r.position.y + r.size.y * 0.5
		match n:
			"gun":
				text(Vector2(r.position.x, cy - 2 * s), "GUN", 18, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				var am := "RELOAD" if jet.reloading > 0.0 else str(int(jet.ammo))
				text(Vector2(r.position.x, cy + 22 * s), am, 15, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			"missile":
				text(Vector2(r.position.x, cy - 2 * s), "MISSILE", 18, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				var mx: int = game.missiles_max()
				var have: int = game.missiles_left()
				var bw := 8.0 * s
				var x0 := r.get_center().x - (mx * (bw + 3 * s)) * 0.5
				for i in mx:
					draw_rect(Rect2(Vector2(x0 + i * (bw + 3 * s), cy + 10 * s), Vector2(bw, 12 * s)), Color(1, 1, 1, 0.9 if i < have else 0.25))
			_:
				text(Vector2(r.position.x, cy + 7 * s), label, 18, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if c.dragging:
		draw_arc(c.drag_start, c.drag_radius, 0, TAU, 40, Color(1, 1, 1, 0.18), 2.0 * s)
		draw_circle(c.drag_start + (c.drag_pos - c.drag_start).limit_length(c.drag_radius), 14.0 * s, Color(1, 1, 1, 0.3))


func _draw_small_buttons(c: Controls) -> void:
	if c == null:
		return
	var r: Rect2 = c.btn["pause"]
	draw_rect(r, Color(0.08, 0.13, 0.28, 0.5))
	draw_rect(r, Color(0.75, 0.85, 1.0, 0.5), false, maxf(1.0, 2.0 * s))
	var pp := r.get_center()
	draw_rect(Rect2(pp + Vector2(-8, -11) * s, Vector2(5, 22) * s), C_TEXT)
	draw_rect(Rect2(pp + Vector2(3, -11) * s, Vector2(5, 22) * s), C_TEXT)


func _draw_debug(vs: Vector2) -> void:
	var fps := Engine.get_frames_per_second()
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var lines := [
		"FPS %d   DRAW CALLS %d   OBJECTS %d" % [fps, dc, objs],
		"VIEW %dx%d x%d   CHUNKS %d   QUADS %dk" % [game.pv.low.x, game.pv.low.y, game.pv.pixel_scale, game.chunks.chunks.size(), game.chunks.total_quads() / 1000],
		game.debug_extra(),
		"TOUCHES %d  LAST %s  SCREEN %s" % [game.controls.touch_count, game.controls.last_touch.round(), vs],
	]
	var y := vs.y - 90 * s
	draw_rect(Rect2(Vector2(8 * s, y - 20 * s), Vector2(620 * s, 88 * s)), Color(0, 0, 0, 0.45))
	for l in lines:
		text(Vector2(14 * s, y), l, 14, Color(0.7, 1.0, 0.7))
		y += 20 * s


## Edge-of-screen arrows pointing to off-screen enemies.
func _draw_arrows(vs: Vector2) -> void:
	var cam: Camera3D = game.cam
	var pv: PixelView = game.pv
	var margin := 40.0 * s
	var center := vs * 0.5
	for e in game.enemies.pool:
		if not e.active:
			continue
		var behind := cam.is_position_behind(e.pos)
		var sp: Vector2 = cam.unproject_position(e.pos) * pv.pixel_scale + pv.display.position
		if not behind and Rect2(Vector2.ZERO, vs).grow(-10.0).has_point(sp):
			continue
		var d := (sp - center).normalized()
		if behind:
			d = -d
		var ext := center - Vector2(margin, margin)
		var k := minf(absf(ext.x / maxf(0.001, absf(d.x))), absf(ext.y / maxf(0.001, absf(d.y))))
		var p := center + d * k
		var col := Color("ff5a4a") if e.type != 3 else Color("ffb43c")
		var sz := (16.0 if e.type == 2 else 12.0) * s
		draw_rect(Rect2(p - Vector2(sz, sz) - Vector2(2, 2) * s, Vector2(sz, sz) * 2.0 + Vector2(4, 4) * s), Color(0.05, 0.05, 0.1, 0.9))
		draw_rect(Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), col)
