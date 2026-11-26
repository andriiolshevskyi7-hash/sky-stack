class_name Cockpit
extends Node2D
## Symbology layer of the cockpit view (the cockpit itself is 3D geometry,
## see Cockpit3D). Drawn in the low-res view on top of the composited image:
##  HUD     - green symbology ONLY inside the combiner glass, as projected
##            from the 3D cockpit (it moves with the head): heading tape,
##            boxed speed and altitude, pitch ladder around the boresight,
##            flight-path marker, gun reticle per tier, G / rounds / AAM /
##            throttle read-outs; brighter at night
##  helmet  - seeker circle with arcs / a triangle towards enemies, yellow
##            brackets on enemies, red lock circle, yellow lead marker; these
##            may sit anywhere on the glass (not over the instrument panel)

var game: Node
var size := Vector2(748, 336)
var alpha := 0.0
## Fraction of the screen height where the glareshield lip is (HUD layer
## keeps markers above it).
var DASH_FRAC := 0.7

var HUD := Color(0.47, 0.95, 0.55, 0.92)
var HUD_DIM := Color(0.47, 0.95, 0.55, 0.5)
const YEL := Color("ffd84a")
const YEL_DIM := Color(1.0, 0.85, 0.3, 0.55)
const RED := Color("ff3b30")
const ORANGE := Color("f0580e")
const RETICLES := ["cross", "circle", "pipper", "diamond"]

var _font: Font
var _clip := Rect2()


func _ready() -> void:
	_font = UI.font(8)


func ptext(pos: Vector2, t: String, col: Color, center: bool = false, sc: int = 1) -> void:
	PixFont.draw(self, pos, t, col, center, sc)


func wtext(pos: Vector2, key: String, col: Color, fs: int = 8) -> void:
	var t := tr(key)
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(floorf(pos.x - w * 0.5), floorf(pos.y)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _process(_d: float) -> void:
	visible = alpha > 0.02
	if visible:
		queue_redraw()


var px_k := 1.0


func _draw() -> void:
	if game == null or game.cockpit3d == null:
		return
	modulate.a = alpha
	var jet: Jet = game.jet
	var c3: Cockpit3D = game.cockpit3d
	var night: float = game.daynight.night if game.daynight != null else 0.0
	var g: Color = c3.glow
	HUD = Color(g.r, g.g, g.b, lerpf(0.85, 1.0, night))
	HUD_DIM = Color(g.r, g.g, g.b, lerpf(0.45, 0.6, night))
	# the overlay is drawn in "classic" low-res pixels (px_k = 2 at HD), so
	# the symbology keeps its size on screen and gets twice as sharp
	var ly := c3.lip_y() / px_k
	DASH_FRAC = clampf(ly / maxf(1.0, size.y), 0.3, 1.0)
	var hs: Array = c3.hud_screen()
	var hr: Rect2 = Rect2(hs[0].position / px_k, hs[0].size / px_k)
	var bs: Vector2 = hs[1] / px_k if hs[1] != Vector2.INF else Vector2.INF
	var head_turned: bool = game.cam.look.length() > 0.25
	# the HUD is only readable looking through the combiner
	if hr.size.x > 10.0 and bs != Vector2.INF and game.cam.look.length() < 0.3:
		_hud(jet, hr, bs.round(), c3.tier)
	_targets(jet, bs.round() if bs != Vector2.INF else size * 0.5, ly, head_turned)


# ------------------------------------------------------------------ HUD

## Line clipped to the combiner (Liang-Barsky).
func _cline(a: Vector2, b: Vector2, col: Color) -> void:
	var r := _clip
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	var pq := [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]
	for e: Array in pq:
		var p: float = e[0]
		var q: float = e[1]
		if absf(p) < 1e-6:
			if q < 0.0:
				return
		else:
			var t := q / p
			if p < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 > t1:
		return
	draw_line((a + d * t0).round(), (a + d * t1).round(), col, 1.0)


func _hud(jet: Jet, hr: Rect2, c: Vector2, tier: int) -> void:
	_clip = hr.grow(-2)
	var roll := jet.roll + jet.roll_extra
	var pitch_deg := rad_to_deg(wrapf(jet.pitch, -PI, PI))
	var ppd := clampf(hr.size.y / 40.0, 1.2, 3.0) # px per degree
	var right := Vector2(cos(roll), sin(roll))
	var down := Vector2(-sin(roll), cos(roll))
	var half_w := floorf(hr.size.x * 0.18)
	for k in range(-18, 19):
		var deg := k * 5
		if deg % 10 != 0:
			continue
		var mid := c + down * (pitch_deg - deg) * ppd
		if not _clip.grow(half_w).has_point(mid):
			continue
		var half := half_w if deg != 0 else hr.size.x
		var gap := 5.0
		var col := HUD if deg >= 0 else HUD_DIM
		for side in [-1.0, 1.0]:
			if deg < 0:
				var t := gap
				while t < half:
					_cline(mid + right * side * t, mid + right * side * minf(t + 2.0, half), col)
					t += 4.0
			else:
				_cline(mid + right * side * gap, mid + right * side * half, col)
			if deg != 0:
				_cline(mid + right * side * half, mid + right * side * half + down * (2.0 if deg > 0 else -2.0), col)
		if deg != 0 and deg % 20 == 0:
			var lp := mid + right * (half + 6.0) - Vector2(0, 2)
			if _clip.has_point(lp) and _clip.has_point(lp + Vector2(7, 4)):
				ptext(lp, str(absi(deg)), col, true)
	# flight-path marker
	var fpm := c + Vector2(0, rad_to_deg(jet.aoa) * ppd)
	if _clip.has_point(fpm):
		draw_arc(fpm, 2.5, 0, TAU, 8, HUD, 1.0)
		draw_line(fpm + Vector2(-7, 0), fpm + Vector2(-3, 0), HUD, 1.0)
		draw_line(fpm + Vector2(3, 0), fpm + Vector2(7, 0), HUD, 1.0)
		draw_line(fpm + Vector2(0, -3), fpm + Vector2(0, -5), HUD, 1.0)
	if _clip.has_point(c):
		_reticle(c, tier)
	# heading tape along the top
	var hdg := fposmod(rad_to_deg(-jet.yaw), 360.0)
	var hy := _clip.position.y + 6
	for d in range(-20, 21, 5):
		var a := roundi(hdg / 5.0) * 5 + d
		var x := roundf(c.x + (a - hdg) * 1.6)
		if x < _clip.position.x + 2 or x > _clip.end.x - 2:
			continue
		draw_line(Vector2(x, hy), Vector2(x, hy - (3.0 if posmod(a, 10) == 0 else 1.0)), HUD_DIM, 1.0)
	ptext(Vector2(c.x, hy + 2), "%03d" % int(hdg), HUD, true, 2)
	# boxed speed (left) and altitude (right) at boresight height, big digits
	var by := clampf(c.y - 5, _clip.position.y + 20, maxf(_clip.position.y + 20, _clip.end.y - 34))
	var lx := _clip.position.x + 1
	var rx := _clip.end.x - 1
	var spd := str(int(jet.speed * 3.6))
	var alt := str(int(jet.position.y))
	var bws := PixFont.width(spd, 2) + 5
	var bwa := PixFont.width(alt, 2) + 5
	draw_rect(Rect2(lx, by - 2, bws, 14), HUD, false, 1.0)
	ptext(Vector2(lx + 3, by + 1), spd, HUD, false, 2)
	draw_rect(Rect2(rx - bwa, by - 2, bwa, 14), HUD, false, 1.0)
	ptext(Vector2(rx - bwa + 3, by + 1), alt, HUD, false, 2)
	# read-outs along the bottom: G and missiles big, rounds / throttle small
	var ry := _clip.end.y - 18
	var gs := "G%.1f" % jet.g_load
	ptext(Vector2(lx, ry), gs, YEL if jet.g_load > 7.0 else HUD, false, 2)
	ptext(Vector2(lx, ry + 12), "%d" % int(jet.ammo), HUD_DIM)
	var aam := "M%d" % game.missiles_left()
	ptext(Vector2(rx - PixFont.width(aam, 2), ry), aam, HUD, false, 2)
	var fl := "F%d" % jet.flares
	ptext(Vector2(rx - PixFont.width(fl), ry - 12), fl, (ORANGE if jet.flares_active > 0.0 else HUD_DIM) if jet.flares > 0 else RED)
	var thr := ("AB" if jet.boosting else "%d" % int(jet.throttle * 100.0))
	ptext(Vector2(rx - PixFont.width(thr), ry + 12), thr, ORANGE if jet.boosting else HUD_DIM)
	if jet.stalling and int(Time.get_ticks_msec() / 220) % 2 == 0:
		ptext(Vector2(c.x, _clip.end.y - 14), "STALL", RED, true)
	if game.missiles.incoming_t < 5.0 and int(Time.get_ticks_msec() / 150) % 2 == 0:
		ptext(Vector2(c.x, by + 10), "MISSILE", RED, true)
	if jet.multiplier > 1:
		ptext(Vector2(c.x, by + 18), "LOW X%d" % jet.multiplier, YEL, true)


func _reticle(c: Vector2, tier: int) -> void:
	match RETICLES[clampi(tier - 1, 0, 3)]:
		"cross":
			draw_line(c + Vector2(-3, 0), c + Vector2(3, 0), HUD, 1.0)
			draw_line(c + Vector2(0, -3), c + Vector2(0, 3), HUD, 1.0)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p := c + Vector2(sx * 9.0, sy * 9.0)
					draw_line(p, p - Vector2(sx * 4.0, 0), HUD, 1.0)
					draw_line(p, p - Vector2(0, sy * 4.0), HUD, 1.0)
		"circle":
			draw_arc(c, 7.0, 0, TAU, 18, HUD, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HUD)
		"pipper":
			var amm := clampf(game.jet.ammo / Jet.MAX_AMMO, 0.0, 1.0)
			draw_arc(c, 8.0, -PI * 0.5, -PI * 0.5 + TAU * amm, 20, HUD, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HUD)
		"diamond":
			draw_polyline(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0), c + Vector2(0, -6)]), HUD, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HUD)


# ------------------------------------------------------------------ helmet

func _targets(jet: Jet, c: Vector2, lip: float, head_turned: bool) -> void:
	var m: Missiles = game.missiles
	var w := size.x
	var tgts: Array = []
	for e0 in game.enemies.pool:
		if e0.active:
			tgts.append(e0)
	for pl in game.fleet.planes:
		if pl.alive and pl.team != jet.team:
			tgts.append(pl)
	var sr := 40.0
	if not tgts.is_empty() and not head_turned:
		for k in 24:
			var a0 := TAU * k / 24.0
			draw_arc(c, sr, a0, a0 + TAU / 48.0, 3, YEL_DIM, 1.0)
	var cam_r: Vector3 = game.cam.global_transform.basis.x
	var cam_u: Vector3 = game.cam.global_transform.basis.y
	var nearest := 1e9
	var near_ang := 0.0
	for e in tgts:
		var ep: Vector3 = Missiles.tpos(e)
		if ep == Vector3.INF:
			continue
		var to: Vector3 = ep - game.cam.global_position
		var dist := to.length()
		var behind: bool = game.cam.is_position_behind(ep)
		var sp := Vector2.ZERO
		if not behind:
			sp = (game.cam.unproject_position(ep) / px_k).round()
		var on_glass := not behind and sp.y < lip - 4 and sp.y > 4 and sp.x > 6 and sp.x < w - 6
		var ang := atan2(-to.dot(cam_u), to.dot(cam_r)) if (behind or not on_glass or sp.distance_to(c) > sr) else (sp - c).angle()
		if dist < nearest:
			nearest = dist
			near_ang = ang
		if on_glass and e != m.lock_target:
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p := sp + Vector2(sx * 6.0, sy * 6.0)
					draw_line(p, p - Vector2(sx * 3.0, 0), YEL, 1.0)
					draw_line(p, p - Vector2(0, sy * 3.0), YEL, 1.0)
		if (not on_glass or sp.distance_to(c) > sr) and not head_turned:
			draw_arc(c, sr, ang - 0.12, ang + 0.12, 6, YEL, 1.0)
	if nearest < 1e8 and not head_turned:
		var tn := Vector2(cos(near_ang), sin(near_ang))
		var tp := c + tn * (sr + 1)
		var tt := Vector2(-tn.y, tn.x)
		draw_colored_polygon(PackedVector2Array([tp + tn * 6.0, tp + tt * 3.0, tp - tt * 3.0]), YEL)
	var lpos: Vector3 = Missiles.tpos(m.lock_target)
	if lpos != Vector3.INF and not game.cam.is_position_behind(lpos):
		var lp2: Vector2 = (game.cam.unproject_position(lpos) / px_k).round()
		if lp2.y < lip:
			var k := clampf(m.lock_t / m.lock_time, 0.0, 1.0)
			var rr := lerpf(26.0, 9.0, k)
			draw_arc(lp2, rr, 0, TAU, 28, RED if m.locked else YEL, 1.0)
			var e = m.lock_target
			var dist2: float = jet.position.distance_to(lpos)
			var lead: Vector3 = lpos + Vector3(-sin(e.yaw), 0, -cos(e.yaw)) * e.speed * dist2 / 600.0
			if not game.cam.is_position_behind(lead):
				var ld: Vector2 = (game.cam.unproject_position(lead) / px_k).round()
				draw_arc(ld, 3.0, 0, TAU, 10, YEL, 1.0)
				draw_line(lp2, ld, Color(YEL.r, YEL.g, YEL.b, 0.4), 1.0)
			if m.locked:
				wtext(lp2 + Vector2(0, rr + 10), "LOCK", RED)
