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
	font = UI.base_font()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func text(pos: Vector2, t: String, size: float, col: Color = C_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	t = tr(t)
	UI.text(self, pos, t, size * s, col, align, width, maxi(2, int(round(3 * s))))


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
	elif playing and not game.match_rules.is_team_mode():
		# cockpit: the score is a small tag in the top-left corner
		var sr := Rect2(Vector2(22 * s, 22 * s), Vector2(150 * s, 34 * s))
		UI.panel(self, sr, s, Color(0.05, 0.08, 0.18, 0.55), Color(0.62, 0.74, 0.98, 0.4))
		text(Vector2(sr.position.x + 10 * s, sr.position.y + 23 * s), "%07d" % game.score, 16, Color(1, 1, 1, 0.8))
	if playing and game.match_rules.is_team_mode():
		_draw_team_bar(vs, game.match_rules)
		var cockpit_on: bool = game.cam.cockpit_blend >= 0.5
		_draw_minimap(Vector2((22.0 + 90.0) * s, (150.0 if cockpit_on else 240.0) * s), 82.0 * s)
	if not _toasts.is_empty():
		_draw_toasts(vs)
	if playing:
		_draw_border_warning(vs)
		_draw_flight(vs)
		_draw_tags(vs)
		_draw_feed(vs)
		_draw_rings(vs)
		_draw_missile_arrow(vs)
		_draw_popups()
		_draw_boss(vs)
	if c != null and game.state == game.State.PLAY and game.touch_buttons_visible():
		_draw_touch(c)
	if game.state == game.State.PLAY:
		if game.cam.cockpit_blend < 0.5:
			_draw_arrows(vs) # the cockpit HUD has its own seeker circle
		_draw_small_buttons(c)
	# banner
	if game.banner_time > 0.0 and game.banner != "":
		var a := clampf(game.banner_time, 0.0, 1.0)
		ctext(vs.x * 0.5, vs.y * 0.36, game.banner, 46, Color(1, 0.95, 0.6, a))
		if game.banner_sub != "":
			ctext(vs.x * 0.5, vs.y * 0.36 + 44 * s, game.banner_sub, 22, Color(1, 1, 1, a))
	if game.show_debug:
		_draw_debug(vs)
		# touch diagnostics: marker where the last touch landed
		if c != null and Time.get_ticks_msec() - c.last_touch_ms < 600:
			draw_arc(c.last_touch, 30.0 * s, 0, TAU, 24, Color(1, 1, 0, 0.9), 3.0 * s)


func _panel(r: Rect2) -> void:
	UI.panel(self, r, s, Color(0.05, 0.08, 0.18, 0.7), UI.BORDER_DIM)


func _draw_status(vs: Vector2) -> void:
	var jet: Jet = game.jet
	var c: Controls = game.controls
	var x := 22.0 * s
	var y := 22.0 * s
	# KILLS + HULL panel (reference style)
	# widths follow the translated labels (Ukrainian words are longer)
	var kills_txt: String = tr("KILLS %02d") % game.kills
	var kw := UI.width(kills_txt, UI.px(20 * s))
	var hw := UI.width(tr("HULL"), UI.px(20 * s))
	var hx := x + 16 * s + maxf(kw, 110 * s) + 24 * s
	var bx := hx + hw + 12 * s
	var pw := bx - x + 7 * 18 * s + 10 * s
	var ph := 48.0 * s
	_panel(Rect2(Vector2(x, y), Vector2(pw, ph)))
	text(Vector2(x + 16 * s, y + 32 * s), kills_txt, 20)
	text(Vector2(hx, y + 32 * s), "HULL", 20)
	var segs := 7
	var lit := int(ceil(jet.health / jet.max_health * segs))
	for i in segs:
		var col := Color(1, 1, 1, 0.95) if i < lit else Color(1, 1, 1, 0.22)
		if i < lit and lit <= 2:
			col = Color(1.0, 0.3, 0.25)
		draw_rect(Rect2(Vector2(bx + i * 18 * s, y + 13 * s), Vector2(11 * s, 22 * s)), col)
	var mr: Match = game.match_rules
	if mr.is_team_mode():
		pass # team bar + minimap are drawn in _draw (also in the cockpit)
	else:
		# city + wave + altitude (small)
		_panel(Rect2(Vector2(x, y + ph + 8 * s), Vector2(pw, 30 * s)))
		text(Vector2(x + 16 * s, y + ph + 30 * s), "CITY", 15, Color(0.75, 0.9, 1.0))
		draw_rect(Rect2(Vector2(x + 70 * s, y + ph + 17 * s), Vector2(140 * s, 12 * s)), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(Vector2(x + 70 * s, y + ph + 17 * s), Vector2(140 * s * game.city_hp / game.city_max, 12 * s)), C_CITY)
		if game.wave > 0 and not game.tutorial.active():
			text(Vector2(x + 225 * s, y + ph + 30 * s), tr("WAVE %d  %d") % [game.wave, game.enemies_left()], 15, Color(1, 0.85, 0.85))
		text(Vector2(x + 4 * s, y + ph + 66 * s), tr("ALT %d") % int(jet.position.y), 16, Color(0.85, 0.95, 1.0) if jet.position.y > CityGen.LOW_ALT else Color(1, 0.85, 0.3))
		ctext(vs.x * 0.5, 40 * s, "%07d" % game.score, 28)
		ctext(vs.x * 0.5, 62 * s, tr("HI %07d") % maxi(Save.high_score, game.score), 14, Color(1, 1, 1, 0.7))
	# INTEL / TUTORIAL buttons
	for n in ["intel"]:
		if not c.helper_buttons:
			break
		var r: Rect2 = c.btn[n]
		_panel(r)
		text(Vector2(r.position.x, r.get_center().y + 7 * s), n.to_upper(), 18, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if jet.multiplier > 1:
		var pulse := 0.75 + 0.25 * sin(_t * 10.0)
		ctext(vs.x * 0.5, vs.y - 40 * s, tr("LOW FLYING  x%d") % jet.multiplier, 26, Color(1, 0.85, 0.3, pulse))
	# tutorial instruction
	if game.tutorial.active():
		var tw := 760.0 * s
		var r := Rect2(Vector2(vs.x * 0.5 - tw * 0.5, 84 * s), Vector2(tw, 46 * s))
		_panel(r)
		text(Vector2(r.position.x, r.position.y + 31 * s), game.tutorial.text(), 20, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_draw_lock(vs)


## Pilot names over planes: blue = your team, red = enemy (+ health bar).
func _draw_tags(vs: Vector2) -> void:
	var cam: Camera3D = game.cam
	for pl in game.fleet.planes:
		if not pl.alive or pl == game.jet:
			continue
		if cam.is_position_behind(pl.position):
			continue
		var d: float = cam.global_position.distance_to(pl.position)
		if d > 2200.0:
			continue
		var sp := _screen(pl.position)
		if not Rect2(Vector2.ZERO, vs).has_point(sp):
			continue
		if game.cam.cockpit_blend > 0.5 and sp.y > vs.y * game.cockpit.DASH_FRAC - 6.0 * s:
			continue # behind the dashboard
		var ally: bool = pl.team == game.jet.team
		var col := Color(0.45, 0.75, 1.0, 0.95) if ally else Color(1.0, 0.4, 0.35, 0.95)
		var fs := 15.0 if d < 900.0 else 12.0
		ctext(sp.x, sp.y - 34 * s, pl.pilot, fs, col)
		if not ally and d < 1200.0:
			var bw := 46.0 * s
			draw_rect(Rect2(sp + Vector2(-bw * 0.5, -28 * s), Vector2(bw, 4 * s)), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(sp + Vector2(-bw * 0.5, -28 * s), Vector2(bw * pl.health / pl.max_health, 4 * s)), col)


## Kill feed (top right, under the buttons).
func _draw_feed(vs: Vector2) -> void:
	var y := 120.0 * s
	for kf in game.kill_feed:
		var a := clampf(6.0 - float(kf[1]), 0.0, 1.0)
		var c: Color = kf[2]
		c.a = a
		text(Vector2(vs.x - 520 * s, y), kf[0], 16, c, HORIZONTAL_ALIGNMENT_RIGHT, 500 * s)
		y += 22 * s


## Red arrow around the screen centre pointing at the incoming missile.
func _draw_missile_arrow(vs: Vector2) -> void:
	var m: Missiles = game.missiles
	if m.incoming_t > 3.5 or not game.jet.alive:
		return
	var c := vs * 0.5
	var sp := _screen(m.incoming_pos)
	var d := (sp - c).normalized()
	if game.cam.is_position_behind(m.incoming_pos):
		d = -d
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	var p := c + d * 150.0 * s
	var perp := Vector2(-d.y, d.x)
	var blink := int(Time.get_ticks_msec() / 150) % 2 == 0
	var col := Color(1, 0.2, 0.15, 0.95 if blink else 0.55)
	draw_colored_polygon(PackedVector2Array([p + d * 26.0 * s, p - d * 10.0 * s + perp * 18.0 * s, p - d * 10.0 * s - perp * 18.0 * s]), col)
	ctext(c.x, c.y + 190.0 * s, "MISSILE", 18, col)


## Floating "+150" kill popups.
# ------------------------------------------------------------------ achievement toasts

var _toasts: Array = [] # [name, tier, age]


func toast(name: String, tier: int) -> void:
	_toasts.append([name, tier, 0.0])
	Sfx.play("tone", -4.0, 1.5)


func _draw_toasts(vs: Vector2) -> void:
	var dt := get_process_delta_time()
	var y := 150.0 * s
	var i := 0
	while i < _toasts.size():
		var t: Array = _toasts[i]
		t[2] += dt
		if t[2] > 4.0:
			_toasts.remove_at(i)
			continue
		# slide in from the right, slide out after 3.5 s
		var k := clampf(t[2] / 0.3, 0.0, 1.0) * clampf((4.0 - t[2]) / 0.3, 0.0, 1.0)
		var w := 420.0 * s
		var h := 64.0 * s
		var x := vs.x - (w + 20 * s) * (1.0 - pow(1.0 - k, 3.0))
		var tc: Color = Missions.TIER_COLORS[t[1]]
		var r := Rect2(Vector2(x, y), Vector2(w, h))
		UI.panel(self, r, s, Color(0.05, 0.08, 0.16, 0.92), tc)
		draw_rect(Rect2(r.position.round(), Vector2(8 * s, h).round()), tc)
		text(Vector2(x + 22 * s, y + 26 * s), tr("ACHIEVEMENT") + "  -  " + tr(Missions.TIER_NAMES[t[1]]), 15, tc)
		text(Vector2(x + 22 * s, y + 52 * s), tr(t[0]), 22, Color.WHITE)
		y += h + 10 * s
		i += 1


func _draw_popups() -> void:
	for pp in game.popups:
		var wp: Vector3 = pp[0]
		if game.cam.is_position_behind(wp):
			continue
		var age: float = pp[2]
		var sp := _screen(wp) - Vector2(0, age * 60.0 * s)
		ctext(sp.x, sp.y, pp[1], 24, Color(1, 0.92, 0.4, clampf(1.6 - age * 1.4, 0.0, 1.0)))


func _draw_boss(vs: Vector2) -> void:
	var b = game.enemies.boss
	if b == null or not b.active:
		return
	var w := 500.0 * s
	var r := Rect2(Vector2(vs.x * 0.5 - w * 0.5, 84 * s), Vector2(w, 16 * s))
	_panel(r.grow(6 * s))
	draw_rect(r, Color(0.2, 0.05, 0.05))
	draw_rect(Rect2(r.position, Vector2(w * clampf(b.hp / b.max_hp, 0.0, 1.0), r.size.y)), Color(1, 0.3, 0.2))
	ctext(vs.x * 0.5, 80 * s, "BOSS BOMBER", 16, Color(1, 0.8, 0.7))


## Team score bar + timer (team modes).
func _draw_team_bar(vs: Vector2, mr: Match) -> void:
	var w := 520.0 * s
	var h := 40.0 * s
	var x0 := vs.x * 0.5 - w * 0.5
	var y0 := 18.0 * s
	var tgt := float(mr.kill_target) if mr.mode != Match.BASE else 100.0
	_panel(Rect2(Vector2(x0, y0), Vector2(w, h)))
	var half := w * 0.5 - 60 * s
	var fb := clampf(mr.score[0] / tgt, 0.0, 1.0)
	var fr := clampf(mr.score[1] / tgt, 0.0, 1.0)
	draw_rect(Rect2(Vector2(x0 + 60 * s + half - half * fb, y0 + 8 * s), Vector2(half * fb, h - 16 * s)) if false else Rect2(Vector2(x0 + 8 * s, y0 + 8 * s), Vector2((half - 8 * s) * fb, h - 16 * s)), Color(0.35, 0.65, 1.0, 0.9))
	draw_rect(Rect2(Vector2(x0 + w - 8 * s - (half - 8 * s) * fr, y0 + 8 * s), Vector2((half - 8 * s) * fr, h - 16 * s)), Color(1.0, 0.4, 0.35, 0.9))
	text(Vector2(x0 + 14 * s, y0 + 28 * s), str(mr.score[0]) + ("%" if mr.mode == Match.BASE else ""), 20)
	text(Vector2(x0, y0 + 28 * s), str(mr.score[1]) + ("%" if mr.mode == Match.BASE else ""), 20, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, w - 14 * s)
	var tl := maxi(0, int(ceil(mr.time_left)))
	ctext(vs.x * 0.5, y0 + 29 * s, "%d:%02d" % [tl / 60, tl % 60], 22, Color(1, 0.95, 0.7))
	if mr.mode != Match.BASE:
		ctext(vs.x * 0.5, y0 + h + 18 * s, tr("FIRST TO %d") % mr.kill_target, 13, Color(1, 1, 1, 0.65))
	if mr.countdown > 0.0:
		ctext(vs.x * 0.5, vs.y * 0.45, str(ceili(mr.countdown)), 96, Color(1, 0.9, 0.4))
	if game._player_respawn > 0.0:
		ctext(vs.x * 0.5, vs.y * 0.84, tr("RESPAWN %d") % ceili(game._player_respawn), 32, Color(1, 1, 1, 0.9))


## Heading-up minimap: planes (blue/red), bases, your jet in the middle.
func _draw_minimap(c: Vector2, r: float) -> void:
	# pixel frame around the round radar scope
	UI.panel(self, Rect2(c - Vector2(r + 6 * s, r + 6 * s), Vector2(r + 6 * s, r + 6 * s) * 2.0), s, Color(0.05, 0.08, 0.18, 0.6), UI.BORDER_DIM)
	draw_circle(c, r, Color(0.08, 0.16, 0.28, 0.8))
	for k in 4:
		var a := TAU * k / 4.0
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 6 * s), c + Vector2(cos(a), sin(a)) * r, Color(0.6, 0.8, 1.0, 0.5), maxf(1.0, roundf(s)))
	var jet: Jet = game.jet
	var rng_w := 4200.0
	var cy := cos(jet.yaw)
	var sy := sin(jet.yaw)
	var see_enemies: bool = game.match_rules.mode != Match.BASE or game.bases.radar_up(jet.team)
	# battle-area edge (rotated square) and landmarks
	var wm: WorldMap = game.world_map
	var h := wm.half
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var pts := PackedVector2Array()
	for q in corners:
		var d := Vector2(q.x - jet.position.x, q.z - jet.position.z)
		pts.append(c + Vector2(cy * d.x - sy * d.y, sy * d.x + cy * d.y) / rng_w * r)
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		# clip to the disc by sampling (cheap, 12 segments per side)
		for k in 12:
			var p0 := a.lerp(b, k / 12.0)
			var p1 := a.lerp(b, (k + 1) / 12.0)
			if p0.distance_to(c) < r and p1.distance_to(c) < r:
				draw_line(p0, p1, Color(1, 0.3, 0.25, 0.9), maxf(1.0, 2.0 * s))
	for lm in wm.landmarks:
		var lp: Vector3 = lm["pos"]
		var d := Vector2(lp.x - jet.position.x, lp.z - jet.position.z)
		var l := Vector2(cy * d.x - sy * d.y, sy * d.x + cy * d.y) / rng_w * r
		if l.length() < r - 4.0:
			var q := c + l
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5) * s, q + Vector2(4, 0) * s, q + Vector2(0, 5) * s, q + Vector2(-4, 0) * s]), Color(1, 0.95, 0.6))
	for st in game.bases.structures:
		_mm_dot(c, r, rng_w, cy, sy, st.pos, Color(0.4, 0.7, 1.0, 0.8) if st.team == 0 else Color(1, 0.45, 0.4, 0.8), 3.0 if st.active else 1.5, true)
	for pl in game.fleet.planes:
		if not pl.alive or pl == jet:
			continue
		if pl.team != jet.team and not see_enemies:
			continue
		_mm_dot(c, r, rng_w, cy, sy, pl.position, Color(0.45, 0.75, 1.0) if pl.team == jet.team else Color(1.0, 0.35, 0.3), 3.5, false)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7) * s, c + Vector2(5, 6) * s, c + Vector2(-5, 6) * s]), Color.WHITE)
	if not see_enemies:
		ctext(c.x, c.y + r + 18 * s, "RADAR DOWN", 13, Color(1, 0.5, 0.4))


## Flight data strip (bottom centre, outside the cockpit): speed, altitude,
## G load, throttle / afterburner heat; STALL warning everywhere.
func _draw_flight(vs: Vector2) -> void:
	var jet: Jet = game.jet
	if not jet.alive:
		return
	if jet.stalling:
		var on := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
		ctext(vs.x * 0.5, vs.y * 0.62, "STALL", 34, Color(1, 0.3, 0.25) if on else Color(1, 0.75, 0.3))
	if game.cam.cockpit_blend >= 0.5:
		return
	var w := 560.0 * s
	var h := 40.0 * s
	var r := Rect2(Vector2(vs.x * 0.5 - w * 0.5, vs.y - h - 14 * s), Vector2(w, h))
	_panel(r)
	var y := r.position.y + 28 * s
	var cw := w / 4.0
	text(Vector2(r.position.x + 12 * s, y), "%d" % int(jet.speed * 3.6) + " " + tr("KM/H"), 18)
	text(Vector2(r.position.x + cw + 8 * s, y), tr("ALT %d") % int(jet.position.y), 18, C_TEXT if jet.position.y > 60.0 else Color(1, 0.6, 0.3))
	var gcol := C_TEXT
	if jet.g_load > float(jet.cfg.get("g_tol", 8.0)) or jet.g_load < -2.5:
		gcol = Color(1, 0.4, 0.3)
	text(Vector2(r.position.x + cw * 2.0 + 8 * s, y), "%.1f G" % jet.g_load, 18, gcol)
	# throttle / afterburner + heat
	var tx := r.position.x + cw * 3.0 + 4 * s
	var bar := Rect2(Vector2(tx, r.position.y + 10 * s), Vector2(cw - 16 * s, h - 20 * s))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var thr: float = jet.throttle
	if game.controls != null and "throttle" in game.controls and game.controls.throttle >= 0.0:
		thr = game.controls.throttle
	var tcol := Color(1.0, 0.55, 0.15) if jet.boosting else Color(0.55, 0.8, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(1.0 if jet.boosting else thr / Jet.THR_MIL, 0.0, 1.0), bar.size.y * 0.55)), tcol)
	# heat underneath (red when overheated)
	draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * 0.7), Vector2(bar.size.x * jet.heat / 100.0, bar.size.y * 0.3)), Color(1, 0.25, 0.2) if jet.overheated else Color(1, 0.7, 0.3))


## Red flashing warning near / outside the battle-area edge.
func _draw_border_warning(vs: Vector2) -> void:
	var wm: WorldMap = game.world_map
	var jet: Jet = game.jet
	if not jet.alive:
		return
	var o := wm.outside(jet.position)
	if o < -WorldMap.BORDER_WARN:
		return
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4
	var col := Color(1, 0.3, 0.25, 1.0 if blink else 0.6)
	ctext(vs.x * 0.5, vs.y * 0.3, "RETURN TO BATTLE AREA", 34, col)
	var msg := "TURNING BACK" if jet.steer_home else ("LEAVING THE AREA" if o < 0.0 else tr("AUTO TURN IN %d") % maxi(1, ceili(4.0 - game.border_t)))
	ctext(vs.x * 0.5, vs.y * 0.3 + 34 * s, msg, 18, Color(1, 0.85, 0.8))


func _mm_dot(c: Vector2, r: float, rng_w: float, cy: float, sy: float, p: Vector3, col: Color, size: float, square: bool) -> void:
	var jp: Vector3 = game.jet.position
	var d := Vector2(p.x - jp.x, p.z - jp.z)
	var l := Vector2(cy * d.x - sy * d.y, sy * d.x + cy * d.y) / rng_w * r
	if l.length() > r - 3.0:
		l = l.normalized() * (r - 3.0)
	if square:
		draw_rect(Rect2(c + l - Vector2(size, size) * s, Vector2(size, size) * 2.0 * s), col)
	else:
		draw_circle(c + l, size * s, col)


func _screen(p: Vector3) -> Vector2:
	return game.cam.unproject_position(p) * game.pv.pixel_scale + game.pv.display.position


## Lock-on box around the target: white while locking, red when locked.
func _draw_lock(_vs: Vector2) -> void:
	var m: Missiles = game.missiles
	var lpos: Vector3 = Missiles.tpos(m.lock_target)
	if lpos == Vector3.INF or game.cam.is_position_behind(lpos):
		return
	var p := _screen(lpos)
	var k := clampf(m.lock_t / m.lock_time, 0.0, 1.0)
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
	var r1 := r0 + maxf(0.0, m.incoming_t - 0.4) * 130.0 * s
	var near := absf(r1 - r0) < 22.0 * s
	draw_arc(p, r0, 0, TAU, 48, Color(1, 1, 1, 0.9), maxf(2.0, 3.0 * s))
	draw_arc(p, r1, 0, TAU, 64, Color(1, 0.25, 0.2) if near else Color(1, 0.85, 0.3), maxf(2.0, 3.0 * s))
	if near:
		ctext(p.x, p.y - r0 - 14 * s, "ROLL!", 22, Color(1, 0.3, 0.25))


## Rectangular semi-transparent buttons (like the reference).
func _draw_touch(c: Controls) -> void:
	var jet: Jet = game.jet
	_draw_throttle(c, jet)
	for n in ["fire", "missile", "loop"]:
		var r: Rect2 = c.btn[n]
		var on: bool = c.pressed.get(n, false)
		var ctr := r.get_center().round()
		var rad := r.size.x * 0.5 * (0.93 if on else 1.0)
		# round pixel button: dark disc, light ring
		draw_circle(ctr, rad, Color(0.03, 0.05, 0.12, 0.72) if on else Color(0.06, 0.1, 0.22, 0.45))
		draw_arc(ctr, rad, 0, TAU, 40, Color(0.75, 0.85, 1.0, 0.9 if on else 0.6), maxf(2.0, roundf(2.0 * s)))
		var k := rad / 46.0
		var col := Color(1, 1, 1, 0.95)
		match n:
			"fire":
				_icon_fire(ctr, k, col)
				var am := tr("RELOAD") if jet.reloading > 0.0 else str(int(jet.ammo))
				text(Vector2(ctr.x - rad, ctr.y + rad * 0.86), am, 18, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0)
			"missile":
				_icon_missile(ctr - Vector2(0, 6) * k, k, col)
				text(Vector2(ctr.x - rad, ctr.y + rad * 0.8), "%d" % game.missiles_left(), 24, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0)
				if game.missiles.reload > 0.0:
					var f: float = 1.0 - game.missiles.reload / maxf(0.1, game.missiles.reload_time)
					draw_arc(ctr, rad - 4.0 * s, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Color(1, 0.7, 0.3, 0.9), maxf(2.0, 3.0 * s))
			"loop":
				_icon_loop(ctr, k, col)
	if c.dragging and c.show_indicator:
		_draw_stick_icon(c)


## Control-stick icon under the thumb: base ring where the touch started, a
## stick leaning towards the finger with a pilot grip on top.
func _draw_stick_icon(c: Controls) -> void:
	var base := c.drag_start.round()
	var d := (c.drag_pos - c.drag_start).limit_length(c.drag_radius)
	var tip := (base + d * 0.8).round()
	draw_circle(base, c.drag_radius, Color(0.06, 0.1, 0.22, 0.18))
	draw_arc(base, c.drag_radius, 0, TAU, 48, Color(0.8, 0.9, 1.0, 0.28), maxf(1.0, roundf(2.0 * s)))
	# rubber boot
	draw_circle(base, 18.0 * s, Color(0.12, 0.13, 0.16, 0.85))
	draw_arc(base, 18.0 * s, 0, TAU, 24, Color(0.5, 0.53, 0.6, 0.85), maxf(1.0, roundf(2.0 * s)))
	# shaft
	draw_line(base, tip, Color(0.2, 0.21, 0.25, 0.95), 10.0 * s)
	draw_line(base, tip, Color(0.42, 0.45, 0.52, 0.95), 4.0 * s)
	# grip: dark block with the trigger and a hat switch
	var g := Rect2(tip - Vector2(20, 28) * s, Vector2(40, 44) * s)
	draw_rect(Rect2(g.position.round(), g.size.round()), Color(0.14, 0.15, 0.18, 0.95))
	draw_rect(Rect2((g.position + Vector2(3, 3) * s).round(), (Vector2(34, 8) * s).round()), Color(0.34, 0.36, 0.42, 0.95))
	draw_rect(Rect2((tip + Vector2(5, -18) * s).round(), (Vector2(11, 11) * s).round()), Color("f0580e"))
	draw_rect(Rect2((tip + Vector2(-15, -19) * s).round(), (Vector2(9, 9) * s).round()), Color(0.6, 0.63, 0.7))


## Throttle lever on the right edge: track with notches, orange afterburner
## band at the top, T-handle at the current setting, % / AB / heat.
func _draw_throttle(c: Controls, jet: Jet) -> void:
	var t: Rect2 = c.throttle_rect
	var on: bool = c.pressed.get("throttle", false)
	UI.panel(self, t, s, Color(0.03, 0.05, 0.12, 0.65) if on else Color(0.05, 0.08, 0.18, 0.42), Color(0.75, 0.85, 1.0, 0.8 if on else 0.55))
	var top := c.throttle_point(1.0)
	var ab0 := c.throttle_point(Controls.AB_ZONE)
	var bottom := c.throttle_point(0.0)
	# afterburner zone
	draw_rect(Rect2(Vector2(t.position.x + 6 * s, top.y), Vector2(t.size.x - 12 * s, ab0.y - top.y)).abs(), Color(1.0, 0.45, 0.1, 0.55))
	text(Vector2(t.position.x, top.y + 22 * s), "AB", 14, Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, t.size.x)
	# track + notches (idle, 25/50/75%, military)
	draw_rect(Rect2(Vector2(t.get_center().x - 3 * s, ab0.y), Vector2(6 * s, bottom.y - ab0.y)).abs(), Color(0, 0, 0, 0.55))
	for v in [0.0, 0.25, 0.5, 0.75, Jet.THR_MIL]:
		var py: float = c.throttle_point(v * 1.0).y
		draw_rect(Rect2(Vector2(t.position.x + 10 * s, py), Vector2(t.size.x - 20 * s, maxf(1.0, roundf(2 * s)))), Color(0.8, 0.88, 1.0, 0.5))
	# handle
	var h := c.throttle_point(c.throttle)
	var hcol := Color("f0580e") if jet.boosting else (Color(1, 0.3, 0.25) if jet.overheated and c.throttle >= Controls.AB_ZONE else Color(0.9, 0.93, 1.0))
	var hr := Rect2(Vector2(t.position.x + 4 * s, h.y - 13 * s), Vector2(t.size.x - 8 * s, 26 * s))
	draw_rect(Rect2(hr.position.round(), hr.size.round()), hcol)
	draw_rect(Rect2((hr.position + Vector2(0, hr.size.y - 4 * s)).round(), Vector2(hr.size.x, 4 * s).round()), hcol.darkened(0.35))
	var label := "AB" if jet.boosting else "%d%%" % int(round(minf(c.throttle, Jet.THR_MIL) / Jet.THR_MIL * 100.0))
	text(Vector2(t.position.x - 90 * s, h.y + 7 * s), label, 16, hcol, HORIZONTAL_ALIGNMENT_RIGHT, 82 * s)
	# heat strip along the left edge of the lever
	var hh := (bottom.y - top.y) * jet.heat / 100.0
	draw_rect(Rect2(Vector2(t.position.x + 2 * s, bottom.y - hh), Vector2(3 * s, hh)), Color(1, 0.3, 0.2) if jet.overheated else Color(1, 0.65, 0.3, 0.8))


## Pixel icons (k = scale, 1 = 92 px button).
func _icon_fire(c: Vector2, k: float, col: Color) -> void:
	var w := maxf(2.0, roundf(4.0 * k))
	draw_arc(c, 20.0 * k, 0, TAU, 28, col, w)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		draw_line((c + d * 10.0 * k).round(), (c + d * 30.0 * k).round(), col, w)
	draw_rect(Rect2((c - Vector2(3, 3) * k).round(), (Vector2(6, 6) * k).round()), Color(1, 0.55, 0.2))


func _icon_missile(c: Vector2, k: float, col: Color) -> void:
	# missile seen from the side, nose up-right
	var b := Transform2D(-PI * 0.25, c)
	var body := PackedVector2Array([Vector2(-26, -5), Vector2(16, -5), Vector2(26, 0), Vector2(16, 5), Vector2(-26, 5)])
	var fin1 := PackedVector2Array([Vector2(-26, -5), Vector2(-18, -5), Vector2(-26, -14)])
	var fin2 := PackedVector2Array([Vector2(-26, 5), Vector2(-18, 5), Vector2(-26, 14)])
	for poly in [body, fin1, fin2]:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append((b * (p * k)).round())
		draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([(b * (Vector2(-30, -3) * k)).round(), (b * (Vector2(-26, -3) * k)).round(), (b * (Vector2(-26, 3) * k)).round(), (b * (Vector2(-30, 3) * k)).round()]), Color(1, 0.55, 0.2))


func _icon_loop(c: Vector2, k: float, col: Color) -> void:
	var w := maxf(2.0, roundf(4.0 * k))
	draw_arc(c, 17.0 * k, -PI * 0.15, PI * 1.55, 28, col, w)
	var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * 17.0 * k
	draw_colored_polygon(PackedVector2Array([(tip + Vector2(-9, -2) * k).round(), (tip + Vector2(6, -6) * k).round(), (tip + Vector2(2, 9) * k).round()]), col)


func _icon_view(c: Vector2, k: float, col: Color) -> void:
	# eye
	var w := maxf(2.0, roundf(3.0 * k))
	draw_arc(c + Vector2(0, 10) * k, 18.0 * k, -PI * 0.82, -PI * 0.18, 16, col, w)
	draw_arc(c - Vector2(0, 10) * k, 18.0 * k, PI * 0.18, PI * 0.82, 16, col, w)
	draw_circle(c, 6.0 * k, col)


func _draw_small_buttons(c: Controls) -> void:
	if c == null:
		return
	if game.state == game.State.PLAY and game.touch_buttons_visible():
		var vr: Rect2 = c.btn["view"]
		var von: bool = c.pressed.get("view", false)
		UI.panel(self, vr, s, Color(0.03, 0.05, 0.12, 0.7) if von else Color(0.06, 0.1, 0.22, 0.5), Color(0.75, 0.85, 1.0, 0.6))
		_icon_view(vr.get_center().round(), vr.size.y / 72.0, Color(1, 1, 1, 0.95))
	var r: Rect2 = c.btn["pause"]
	UI.panel(self, r, s, Color(0.06, 0.1, 0.22, 0.5), Color(0.75, 0.85, 1.0, 0.6))
	var pp := r.get_center().round()
	draw_rect(Rect2(pp + (Vector2(-8, -11) * s).round(), (Vector2(5, 22) * s).round()), C_TEXT)
	draw_rect(Rect2(pp + (Vector2(3, -11) * s).round(), (Vector2(5, 22) * s).round()), C_TEXT)


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
	var objs: Array = []
	for e in game.enemies.pool:
		if e.active:
			objs.append(e)
	for pl in game.fleet.planes:
		if pl.alive and pl.team != game.jet.team:
			objs.append(pl)
	for e in objs:
		var epos: Vector3 = Missiles.tpos(e)
		var behind := cam.is_position_behind(epos)
		var sp: Vector2 = cam.unproject_position(epos) * pv.pixel_scale + pv.display.position
		if not behind and Rect2(Vector2.ZERO, vs).grow(-10.0).has_point(sp):
			continue
		var d := (sp - center).normalized()
		if behind:
			d = -d
		var ext := center - Vector2(margin, margin)
		var k := minf(absf(ext.x / maxf(0.001, absf(d.x))), absf(ext.y / maxf(0.001, absf(d.y))))
		var p := center + d * k
		# keep markers off the top HUD strip (kills, score bar, timer, pause)
		p.y = clampf(p.y, 120.0 * s, vs.y - 80.0 * s) # above the flight strip
		var et: int = -1 if e is Jet else e.type
		var col := Color("ff5a4a") if et != 3 else Color("ffb43c")
		var sz := (16.0 if et == 2 else 12.0) * s
		draw_rect(Rect2(p - Vector2(sz, sz) - Vector2(2, 2) * s, Vector2(sz, sz) * 2.0 + Vector2(4, 4) * s), Color(0.05, 0.05, 0.1, 0.9))
		draw_rect(Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), col)
