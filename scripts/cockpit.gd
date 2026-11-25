class_name Cockpit
extends Node2D
## First-person cockpit drawn in code INSIDE the low-res view, so it is pixel
## art at exactly the world's pixel size. Modelled on real fighter cockpits:
##  canopy    - a big arched canopy bow over the head (bubble canopy), bolts
##              and a highlight edge; attackers add thick windscreen posts
##  HUD       - a combiner glass on two posts above the dash with green
##              symbology only inside it: heading tape, boxed speed and
##              altitude, pitch ladder, flight-path marker, gun reticle,
##              G / gun / missile readouts; the seeker circle, brackets on
##              enemies, lock circle and lead marker are helmet symbology
##              and may sit anywhere on the glass
##  UFCP      - up-front control panel under the HUD: keypad with labelled
##              keys and two small green read-outs
##  dash      - dark glareshield, multi-function displays with soft keys
##              around the bezel (radar scope with live contacts, primary
##              flight display, engine page, moving map), small standby
##              gauges, warning lights, the pilot's knees and the stick
##              between them moving with the input
##  consoles  - side consoles with switch rows, striped handles, green lamps
##  night     - panel paint dims, displays and key labels glow
## Every class has its own interior and the tiers differ (see _apply_style):
##  light     - light-grey trainer-style panel, three displays in a row
##              (tier 1: analog gauges instead of the left display)
##  heavy     - charcoal; tiers 1-2 two displays and a round ball, tiers 3-4
##              one wide panoramic display (flight / radar / engine pages)
##  attack    - dark olive, big keypad, moving map + monochrome radar
##              (tiers 1-2: analog cluster on the right), windscreen posts
## Head look: the camera turns (GameCamera.look) and this whole picture is
## shifted to stay fixed to the plane; looking sideways shows the canopy
## sill and side wall, further back the rear canopy bow and the seat.

var game: Node
var size := Vector2(748, 336)
var alpha := 0.0

var HUD := Color(0.47, 0.95, 0.55, 0.92) # per class
var HUD_DIM := Color(0.47, 0.95, 0.55, 0.5)
const YEL := Color("ffd84a")
const YEL_DIM := Color(1.0, 0.85, 0.3, 0.55)
const RED := Color("ff3b30")
const ORANGE := Color("f0580e")
const ORANGE_L := Color("ff9a4a")
const SKY := Color("4fa3ee")
const SKY_D := Color("3a8bd8")
const GROUND := Color("9a6232")
const GROUND_D := Color("80501f")
const SCREEN := Color("070b09")
const LAMP_G := Color("5cff7a")
const STRIPE_Y := Color("e8c030")
## panel paint (dimmed at night), canopy bow, flight suit
var P0 := Color("17181d")
var P1 := Color("2d3038")
var P2 := Color("41454f")
var P3 := Color("5f6472")
var P4 := Color("8f96a5")
var A0 := Color("101114")
var A1 := Color("26282e")
var A2 := Color("4a4e58")
var SUIT := Color("5d6447")
const RIV := Color("a9afbb")
const DIAL := Color("121318")

var DASH_FRAC := 0.7 # glareshield line (HUD markers stay above it)
const TOP := 8.0
var st := {}
var _style_plane := -2

## Class interiors: panel paint, canopy bow, suit, HUD colour, bow width.
const CLASS_STYLE := [
	{"panel": ["2c3037", "6f7681", "878e99", "a3aab4", "c9ced6"], "arch": ["15171b", "2c2f36", "5a5f69"], "suit": "a68d63",
		"hud": Color(0.45, 1.0, 0.55), "bow": 7.0, "dash": 0.71},
	{"panel": ["0e0f12", "1d1f24", "2a2d33", "3d4149", "666c78"], "arch": ["0b0c0e", "1f2125", "43474f"], "suit": "5b6246",
		"hud": Color(0.5, 1.0, 0.68), "bow": 9.0, "dash": 0.7},
	{"panel": ["101109", "20221a", "2d3024", "434734", "6a6f58"], "arch": ["0d0e0a", "23251d", "4b4f40"], "suit": "4f5a3c",
		"hud": Color(0.68, 1.0, 0.36), "bow": 11.0, "dash": 0.69},
]
const RETICLES := ["cross", "circle", "pipper", "diamond"]

## 3x5 pixel font for numbers (crisp at the world pixel size).
const GLYPHS := {
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7], "3": [7, 1, 7, 1, 7],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7], "6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 2, 2],
	"8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 7], "-": [0, 0, 7, 0, 0], " ": [0, 0, 0, 0, 0],
	".": [0, 0, 0, 0, 2], "G": [7, 4, 5, 5, 7], "A": [2, 5, 7, 5, 5], "M": [5, 7, 7, 5, 5],
	"U": [5, 5, 5, 5, 7], "N": [7, 5, 5, 5, 5], "B": [6, 5, 6, 5, 6], "%": [5, 1, 2, 4, 5],
}
## Keypad labels (UFCP).
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "0", "."]

var _font: Font
var _clip := Rect2() # HUD combiner (symbology is clipped to it)


func _ready() -> void:
	_font = UI.font(8)


## Pixel digits / a few letters; sc = size of one glyph pixel.
func ptext(pos: Vector2, t: String, col: Color, center: bool = false, sc: int = 1) -> void:
	var adv := 4 * sc
	var x := floorf(pos.x - (t.length() * adv - sc) * 0.5) if center else floorf(pos.x)
	var y := floorf(pos.y)
	for i in t.length():
		var g: Array = GLYPHS.get(t[i], GLYPHS[" "])
		for row in 5:
			var bits: int = g[row]
			for b in 3:
				if bits & (4 >> b):
					draw_rect(Rect2(x + i * adv + b * sc, y + row * sc, sc, sc), col)


## Words (translated; Cyrillic needs a real font) - small and centred.
func wtext(pos: Vector2, key: String, col: Color, fs: int = 8) -> void:
	var t := tr(key)
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(floorf(pos.x - w * 0.5), floorf(pos.y)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _process(_d: float) -> void:
	visible = alpha > 0.02
	if visible:
		queue_redraw()


## Pick the interior for the plane being flown.
func _apply_style(pi: int) -> void:
	_style_plane = pi
	var d: Dictionary = Planes.LIST[maxi(pi, 0)]
	var cls := int(d["branch"])
	var tier := int(d["tier"])
	var c: Dictionary = CLASS_STYLE[cls]
	var hc: Color = c["hud"]
	HUD = Color(hc.r, hc.g, hc.b, 0.92)
	HUD_DIM = Color(hc.r, hc.g, hc.b, 0.5)
	DASH_FRAC = c["dash"]
	st = {
		"cls": cls, "tier": tier, "bow": c["bow"], "panel": c["panel"], "arch": c["arch"], "suit": Color(c["suit"]),
		"stripe": Color.from_hsv(fmod(0.07 + maxi(pi, 0) * 0.137, 1.0), 0.55, 0.85),
		"warn": 4 + (tier + 1) / 2,
		"reticle": RETICLES[tier - 1],
		"code": "%s %s" % [d["code"], d["name"]],
	}


## Panel paint for this frame (dimmed at night).
func _paint(night: float) -> void:
	var k := lerpf(1.0, 0.45, night)
	var p: Array = st["panel"]
	var a: Array = st["arch"]
	P0 = Color(p[0]) * k
	P1 = Color(p[1]) * k
	P2 = Color(p[2]) * k
	P3 = Color(p[3]) * k
	P4 = Color(p[4]) * k
	A0 = Color(a[0]) * k
	A1 = Color(a[1]) * k
	A2 = Color(a[2]) * k
	SUIT = Color(st["suit"]) * k
	P0.a = 1.0
	P1.a = 1.0
	P2.a = 1.0
	P3.a = 1.0
	P4.a = 1.0
	A0.a = 1.0
	A1.a = 1.0
	A2.a = 1.0
	SUIT.a = 1.0


func _draw() -> void:
	if game == null:
		return
	modulate.a = alpha
	var jet: Jet = game.jet
	if jet.plane != _style_plane:
		_apply_style(jet.plane)
	var night: float = game.daynight.night if game.daynight != null else 0.0
	_paint(night)
	var w := floorf(size.x)
	var h := floorf(size.y)
	var dash_top := floorf(h * DASH_FRAC)
	var c := Vector2(floorf(w * 0.5), floorf(TOP + (dash_top - TOP) * 0.48))
	# head look: shift the plane-fixed picture (approx. a picture plane)
	var cam: GameCamera = game.cam
	var f := (h * 0.5) / tan(deg_to_rad(cam.fov) * 0.5)
	var look: Vector2 = cam.look
	var off := Vector2(tan(clampf(look.x, -1.45, 1.45)) * f, tan(clampf(look.y, -1.2, 1.2)) * f).round()
	_sides(w, h, c, f, look)
	draw_set_transform(off)
	_glass(w, dash_top)
	_combiner_hud(jet, c, w, dash_top)
	_canopy(w, h, dash_top)
	_dash(jet, w, h, dash_top, c, night)
	draw_set_transform(Vector2.ZERO)
	_targets(jet, c + off, w, h, dash_top + off.y, look.length() > 0.25)


# ------------------------------------------------------------------ glass

func _glass(w: float, dash_top: float) -> void:
	# faint reflections on the canopy
	draw_line(Vector2(w * 0.72, TOP + 14), Vector2(w * 0.86, dash_top * 0.5), Color(1, 1, 1, 0.05), 3.0)
	draw_line(Vector2(w * 0.12, TOP + 30), Vector2(w * 0.2, TOP + 12), Color(1, 1, 1, 0.04), 2.0)


## Line clipped to the HUD combiner (Liang-Barsky).
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


func _in_clip(p: Vector2) -> bool:
	return _clip.has_point(p)


## HUD combiner: glass on two posts, symbology inside only.
func _combiner_hud(jet: Jet, c: Vector2, w: float, dash_top: float) -> void:
	var cw := floorf(minf(w * 0.27, 210.0))
	var y0 := c.y - 58.0
	var y1 := dash_top - 14.0
	var x0 := c.x - cw * 0.5
	# glass (slightly wider at the top), tint + reflection
	var gl := PackedVector2Array([Vector2(x0 - 4, y0), Vector2(x0 + cw + 4, y0), Vector2(x0 + cw, y1), Vector2(x0, y1)])
	draw_colored_polygon(gl, Color(HUD.r * 0.5, HUD.g * 0.6, HUD.b * 0.6, 0.07))
	draw_line(Vector2(x0 + 8, y0 + 4), Vector2(x0 + 30, y0 + 4), Color(1, 1, 1, 0.12), 1.0)
	_clip = Rect2(x0 + 3, y0 + 3, cw - 6, y1 - y0 - 6)
	var roll := jet.roll + jet.roll_extra
	var pitch_deg := rad_to_deg(wrapf(jet.pitch, -PI, PI))
	var ppd := 3.0 # px per degree
	var right := Vector2(cos(roll), sin(roll))
	var down := Vector2(-sin(roll), cos(roll))
	# pitch ladder (solid above, dashed below, bent ends) + horizon
	for k in range(-18, 19):
		var deg := k * 5
		if deg % 10 != 0 and deg != 5 and deg != -5:
			continue
		var mid := c + down * (pitch_deg - deg) * ppd
		if not _clip.grow(30).has_point(mid):
			continue
		var half := 26.0 if deg != 0 else 140.0
		var gap := 9.0
		var col := HUD if deg >= 0 else HUD_DIM
		for side in [-1.0, 1.0]:
			if deg < 0:
				var t := gap
				while t < half:
					_cline(mid + right * side * t, mid + right * side * minf(t + 3.0, half), col)
					t += 6.0
			else:
				_cline(mid + right * side * gap, mid + right * side * half, col)
			if deg != 0:
				var tip := down * (3.0 if deg > 0 else -3.0)
				_cline(mid + right * side * half, mid + right * side * half + tip, col)
		if deg != 0 and deg % 10 == 0:
			var lp := mid + right * (half + 8.0) - Vector2(0, 2)
			if _in_clip(lp) and _in_clip(lp + Vector2(6, 4)):
				ptext(lp, str(absi(deg)), col, true)
	# flight-path marker (below the gun cross by the angle of attack)
	var fpm := c + Vector2(0, rad_to_deg(jet.aoa) * ppd)
	if _in_clip(fpm):
		draw_arc(fpm, 3.0, 0, TAU, 10, HUD, 1.0)
		draw_line(fpm + Vector2(-9, 0), fpm + Vector2(-4, 0), HUD, 1.0)
		draw_line(fpm + Vector2(4, 0), fpm + Vector2(9, 0), HUD, 1.0)
		draw_line(fpm + Vector2(0, -4), fpm + Vector2(0, -7), HUD, 1.0)
	_reticle(c)
	# heading tape across the top of the combiner
	var hdg := fposmod(rad_to_deg(-jet.yaw), 360.0)
	var hy := _clip.position.y + 12
	for d in range(-30, 31, 5):
		var a := roundi(hdg / 5.0) * 5 + d
		var x := roundf(c.x + (a - hdg) * 2.2)
		if absf(x - c.x) > cw * 0.42:
			continue
		var major := posmod(a, 10) == 0
		draw_line(Vector2(x, hy), Vector2(x, hy - (4.0 if major else 2.0)), HUD, 1.0)
		if posmod(a, 30) == 0:
			ptext(Vector2(x, hy - 10), "%02d" % (posmod(a, 360) / 10), HUD_DIM, true)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, hy + 1), Vector2(c.x - 3, hy + 5), Vector2(c.x + 3, hy + 5)]), HUD)
	ptext(Vector2(c.x, hy + 7), "%03d" % int(hdg), HUD, true)
	# boxed speed (left) and altitude (right)
	var by := c.y - 4
	var lx := _clip.position.x + 4
	var rx := _clip.end.x - 4
	draw_rect(Rect2(lx, by - 2, 24, 10), HUD, false, 1.0)
	ptext(Vector2(lx + 12, by), str(int(jet.speed * 3.6)), HUD, true)
	draw_rect(Rect2(rx - 24, by - 2, 24, 10), HUD, false, 1.0)
	ptext(Vector2(rx - 12, by), str(int(jet.position.y)), HUD, true)
	_tape(lx + 2, by - 34, 30, jet.speed * 3.6, 10.0, 1.0, false)
	_tape(lx + 2, by + 12, 30, jet.speed * 3.6 - 30.0, 10.0, 1.0, false)
	_tape(rx - 2, by - 34, 30, jet.position.y, 20.0, 0.5, true)
	_tape(rx - 2, by + 12, 30, jet.position.y - 60.0, 20.0, 0.5, true)
	# bottom read-outs: G, gun rounds, missiles, throttle
	var ry := _clip.end.y - 9
	ptext(Vector2(lx, ry - 9), "G %.1f" % jet.g_load, YEL if jet.g_load > 7.0 else HUD)
	ptext(Vector2(lx, ry), "GUN %d" % int(jet.ammo), HUD_DIM)
	ptext(Vector2(rx - 28, ry - 9), "AAM %d" % game.missiles_left(), HUD)
	ptext(Vector2(rx - 28, ry), ("AB " if jet.boosting else "") + "%d%%" % int(jet.throttle * 100.0), ORANGE if jet.boosting else HUD_DIM)
	if jet.multiplier > 1:
		wtext(Vector2(c.x, c.y + 30), tr("LOW X%d") % jet.multiplier, YEL)
	if game.missiles.counter_t > 0.0:
		wtext(Vector2(c.x, c.y - 24), "COUNTER", RED)
	if jet.stalling and int(Time.get_ticks_msec() / 220) % 2 == 0:
		wtext(Vector2(c.x, c.y + 42), "STALL", RED)
	# combiner frame: two posts, thin top bar, projector housing below
	draw_line(Vector2(x0 - 4, y0), Vector2(x0, y1), A1, 3.0)
	draw_line(Vector2(x0 + cw + 4, y0), Vector2(x0 + cw, y1), A1, 3.0)
	draw_line(Vector2(x0 - 5, y0), Vector2(x0 - 1, y1), A2, 1.0)
	draw_line(Vector2(x0 - 4, y0), Vector2(x0 + cw + 4, y0), A1, 2.0)
	draw_line(Vector2(x0 - 4, y0 - 1), Vector2(x0 + cw + 4, y0 - 1), A2, 1.0)


func _tape(x: float, y0: float, hgt: float, value: float, step: float, px_per_unit: float, right_side: bool) -> void:
	var dir := 1.0 if right_side else -1.0
	var v := floorf(value / step) * step
	var cy := y0 + hgt * 0.5
	for k in range(-4, 5):
		var vv := v + k * step
		var y := roundf(cy - (vv - value) * px_per_unit)
		if y < y0 or y > y0 + hgt:
			continue
		var major := posmod(int(round(vv / step)), 5) == 0
		var x2 := x - dir * (4.0 if major else 2.0)
		draw_line(Vector2(x, y), Vector2(x2, y), HUD_DIM, 1.0)


## Gun reticle, different per tier: bracket box + cross, circle + dot,
## pipper with a range ring (rounds left), diamond with a centre dot.
func _reticle(c: Vector2) -> void:
	match st.get("reticle", "cross"):
		"cross":
			draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), HUD, 1.0)
			draw_line(c + Vector2(0, -5), c + Vector2(0, 5), HUD, 1.0)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p := c + Vector2(sx * 14.0, sy * 14.0)
					draw_line(p, p - Vector2(sx * 6.0, 0), HUD, 1.0)
					draw_line(p, p - Vector2(0, sy * 6.0), HUD, 1.0)
		"circle":
			draw_arc(c, 11.0, 0, TAU, 24, HUD, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HUD)
			for k in 4:
				var a := TAU * k / 4.0
				draw_line(c + Vector2(cos(a), sin(a)) * 11.0, c + Vector2(cos(a), sin(a)) * 15.0, HUD, 1.0)
		"pipper":
			var amm := clampf(game.jet.ammo / Jet.MAX_AMMO, 0.0, 1.0)
			draw_arc(c, 13.0, -PI * 0.5, -PI * 0.5 + TAU * amm, 28, HUD, 1.0)
			draw_arc(c, 16.0, 0, TAU, 32, HUD_DIM, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), HUD)
		"diamond":
			draw_polyline(PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0), c + Vector2(0, -10)]), HUD, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HUD)
			draw_line(c + Vector2(-20, 0), c + Vector2(-13, 0), HUD, 1.0)
			draw_line(c + Vector2(13, 0), c + Vector2(20, 0), HUD, 1.0)


## Helmet symbology (screen space): seeker circle with arcs / a triangle
## towards enemies, yellow brackets on enemies in view, red lock circle,
## yellow lead marker. Hidden seeker while the head is turned.
func _targets(jet: Jet, c: Vector2, w: float, h: float, dash_top: float, head_turned: bool) -> void:
	var m: Missiles = game.missiles
	var tgts: Array = []
	for e0 in game.enemies.pool:
		if e0.active:
			tgts.append(e0)
	for pl in game.fleet.planes:
		if pl.alive and pl.team != jet.team:
			tgts.append(pl)
	var sr := 46.0 # seeker circle radius (inside the combiner)
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
			sp = game.cam.unproject_position(ep).round()
		var on_glass := not behind and (sp.y < dash_top - 4 or head_turned) and sp.y > 4 and sp.y < h - 4 and sp.x > 8 and sp.x < w - 8
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
		draw_colored_polygon(PackedVector2Array([tp + tn * 7.0, tp + tt * 4.0, tp - tt * 4.0]), YEL)
	var lpos: Vector3 = Missiles.tpos(m.lock_target)
	if lpos != Vector3.INF and not game.cam.is_position_behind(lpos):
		var lp2: Vector2 = game.cam.unproject_position(lpos).round()
		var k := clampf(m.lock_t / m.lock_time, 0.0, 1.0)
		var rr := lerpf(30.0, 11.0, k)
		draw_arc(lp2, rr, 0, TAU, 28, RED if m.locked else YEL, 1.0)
		var e = m.lock_target
		var dist2: float = jet.position.distance_to(lpos)
		var lead: Vector3 = lpos + Vector3(-sin(e.yaw), 0, -cos(e.yaw)) * e.speed * dist2 / 600.0
		if not game.cam.is_position_behind(lead):
			var ld: Vector2 = game.cam.unproject_position(lead).round()
			draw_arc(ld, 4.0, 0, TAU, 10, YEL, 1.0)
			draw_line(lp2, ld, Color(YEL.r, YEL.g, YEL.b, 0.4), 1.0)
		if m.locked:
			wtext(lp2 + Vector2(0, rr + 11), "LOCK", RED)


# ------------------------------------------------------------------ canopy

func _rivets(a: Vector2, b: Vector2, n: int) -> void:
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n).round()
		draw_rect(Rect2(p, Vector2(1, 1)), P4)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), A0)


## Worn paint: scattered scratches (stable per position).
func _wear(r: Rect2, n: int, salt: int, base: Color) -> void:
	for i in n:
		var x := r.position.x + CityGen.hashf(i, salt, 71) * r.size.x
		var y := r.position.y + CityGen.hashf(i, salt, 72) * r.size.y
		var k := CityGen.hashf(i, salt, 73)
		var col := base.lightened(0.12) if k < 0.6 else base.darkened(0.25)
		draw_rect(Rect2(floorf(x), floorf(y), 2 if k > 0.7 else 1, 1), col)


## Big arched canopy bow over the head; attackers add windscreen posts.
func _canopy(w: float, h: float, dash_top: float) -> void:
	var t: float = st.get("bow", 8.0)
	var cxy := Vector2(w * 0.5, dash_top + 34.0)
	var rx := w * 0.5 - 4.0
	var ry := cxy.y - TOP + 4.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := 40
	for k in n + 1:
		var a := lerpf(-0.04, PI + 0.04, float(k) / n)
		var dirv := Vector2(cos(a), -sin(a))
		outer.append(cxy + Vector2(dirv.x * rx, dirv.y * ry))
		inner.append(cxy + Vector2(dirv.x * (rx - t), dirv.y * (ry - t)))
	var band := PackedVector2Array(outer)
	for k in range(n, -1, -1):
		band.append(inner[k])
	draw_colored_polygon(band, A1)
	draw_polyline(inner, A2, 1.0)
	draw_polyline(outer, A0, 1.0)
	# a softer highlight along the inner edge's upper half + bolts
	for k in range(4, n - 3, 3):
		var p := inner[k].lerp(outer[k], 0.5).round()
		draw_rect(Rect2(p, Vector2(1, 1)), A2.lightened(0.2))
	# mirror on top of the bow
	var mp := Vector2(w * 0.5, TOP + t + 2)
	draw_rect(Rect2(mp + Vector2(-22, -2), Vector2(44, 7)), A0)
	draw_rect(Rect2(mp + Vector2(-21, -1), Vector2(42, 5)), Color(0.42, 0.55, 0.72) * Color(1, 1, 1, 0.9))
	draw_rect(Rect2(mp + Vector2(-21, -1), Vector2(42, 1)), Color(0.75, 0.82, 0.9, 0.9))
	if int(st.get("cls", 0)) == Planes.ATTACK:
		for side in [-1.0, 1.0]:
			var xt: float = w * 0.5 + side * w * 0.24
			var xb: float = w * 0.5 + side * w * 0.21
			var yt := cxy.y - ry * sqrt(maxf(0.0, 1.0 - pow((xt - cxy.x) / rx, 2.0))) + t * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(xt - 3, yt), Vector2(xt + 3, yt), Vector2(xb + 3, dash_top), Vector2(xb - 3, dash_top)]), A1)
			draw_line(Vector2(xt - side * 3, yt), Vector2(xb - side * 3, dash_top), A2, 1.0)
			_rivets(Vector2(xt, yt + 6), Vector2(xb, dash_top - 6), 8)


# ------------------------------------------------------------------ dash

func _dash(jet: Jet, w: float, h: float, top: float, c: Vector2, night: float) -> void:
	var cls: int = st.get("cls", 0)
	var tier: int = st.get("tier", 1)
	var m: Missiles = game.missiles
	# cockpit tub: sills from the canopy base to the glareshield ends
	var tub := PackedVector2Array([Vector2(0, top + 34), Vector2(w * 0.14, top + 10), Vector2(w * 0.86, top + 10), Vector2(w, top + 34), Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(tub, P0)
	draw_line(Vector2(0, top + 34), Vector2(w * 0.14, top + 10), A2, 1.0)
	draw_line(Vector2(w, top + 34), Vector2(w * 0.86, top + 10), A2, 1.0)
	draw_line(Vector2(0, top + 36), Vector2(w * 0.14, top + 12), A1, 2.0)
	draw_line(Vector2(w, top + 36), Vector2(w * 0.86, top + 12), A1, 2.0)
	# side consoles (below the canopy sills)
	_console(Rect2(0, top + 26, w * 0.24, h - top - 26), 1.0, night)
	_console(Rect2(w * 0.76, top + 26, w * 0.24, h - top - 26), -1.0, night)
	# instrument panel face
	var face := PackedVector2Array([Vector2(w * 0.17, top + 10), Vector2(w * 0.83, top + 10), Vector2(w * 0.8, h), Vector2(w * 0.2, h)])
	draw_colored_polygon(face, P1)
	_wear(Rect2(w * 0.2, top + 12, w * 0.6, h - top - 12), 90, 2, P1)
	# glareshield: dark hood curving over the panel, accent stripe
	var gs := PackedVector2Array()
	for k in 17:
		var x := lerpf(w * 0.14, w * 0.86, k / 16.0)
		var u := (x - w * 0.5) / (w * 0.36)
		gs.append(Vector2(x, top + 2 + 8.0 * u * u))
	var hood := PackedVector2Array(gs)
	for k in range(16, -1, -1):
		hood.append(gs[k] + Vector2(0, 9))
	draw_colored_polygon(hood, A0)
	draw_polyline(gs, A2, 1.0)
	var lip := PackedVector2Array()
	for p in gs:
		lip.append(p + Vector2(0, 9))
	draw_polyline(lip, Color(st.get("stripe", ORANGE)).darkened(0.35 + 0.3 * night), 1.0)
	# warning lights on the glareshield, left and right of the UFCP
	var warn := [jet.health < jet.max_health * 0.4, m.incoming_t < 3.0, jet.reloading > 0.0 or m.reload > 0.0, jet.boosting,
		jet.position.y < CityGen.LOW_ALT or jet.stalling, jet.overheated, jet.gloc > 0.1]
	warn.resize(int(st.get("warn", 5)))
	var blink := int(Time.get_ticks_msec() / 180) % 2 == 0
	for i in warn.size():
		var on: bool = warn[i]
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := c.x + side * (54.0 + (i / 2) * 12.0) - 5.0
		var y := top + 4 + 8.0 * pow((x - w * 0.5) / (w * 0.36), 2.0)
		var col := Color("3a1608") if not on else (RED if (i <= 1 and blink) else ORANGE)
		draw_rect(Rect2(x - 1, y - 1, 11, 5), A0)
		draw_rect(Rect2(x, y, 9, 3), col)
	# displays per class / tier
	var dy := top + 22.0
	var mh := h - dy - 5.0
	match cls:
		Planes.LIGHT:
			var mw := 88.0
			var lr := Rect2(c.x - 52 - mw, dy, mw, mh)
			var rr := Rect2(c.x + 52, dy, mw, mh)
			if tier == 1:
				_gauge_cluster(jet, lr)
			else:
				_radar(lr)
			_engine_page(jet, rr)
			_pfd(jet, Rect2(c.x - 40, top + 30, 80, h - top - 34))
		Planes.HEAVY:
			if tier <= 2:
				var mw := 96.0
				_radar(Rect2(c.x - 50 - mw, dy, mw, mh))
				_engine_page(jet, Rect2(c.x + 50, dy, mw, mh))
				var r := floorf(minf(26.0, (h - top - 36) * 0.5))
				_ball(jet, Vector2(c.x, h - r - 8), r)
			else:
				_panoramic(jet, Rect2(c.x - 150, top + 30, 300, h - top - 34))
		_:
			var mw := 84.0
			_map(jet, Rect2(c.x - 58 - mw, dy, mw, mh))
			if tier <= 2:
				_gauge_cluster(jet, Rect2(c.x + 58, dy, mw, mh))
			else:
				_radar(Rect2(c.x + 58, dy, mw, mh))
			# standby gauges under the keypad
			for k in 3:
				_gauge(Vector2(c.x - 22 + k * 22, h - 14), 8.0, [jet.speed / (jet.boost_speed() * 1.05), jet.position.y / 1000.0, jet.heat / 100.0][k])
	_ufcp(jet, c, top, cls == Planes.ATTACK, night)
	# data plate with the plane's code
	var code: String = st.get("code", "")
	var pw := _font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
	var pp := Vector2(floorf(w * 0.2 + 4), floorf(top + 14))
	draw_rect(Rect2(pp, Vector2(pw, 11)), A0)
	draw_rect(Rect2(pp + Vector2(1, 1), Vector2(pw - 2, 9)), Color("b8b09a") * lerpf(1.0, 0.5, night))
	draw_string(_font, pp + Vector2(4, 9), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("24221c"))
	_legs(w, h, c)
	_stick(Vector2(c.x, h + 4))


## Side console: angled switch panels, striped handle, green lamps.
func _console(r: Rect2, side: float, night: float) -> void:
	var x_in := r.end.x if side > 0.0 else r.position.x
	var x_out := r.position.x if side > 0.0 else r.end.x
	var poly := PackedVector2Array([Vector2(x_out, r.position.y + 16), Vector2(x_in, r.position.y), Vector2(x_in - side * 8, r.end.y), Vector2(x_out, r.end.y)])
	draw_colored_polygon(poly, P0)
	draw_line(Vector2(x_out, r.position.y + 16), Vector2(x_in, r.position.y), P3, 1.0)
	var lamp := LAMP_G if night > 0.4 else Color("3a5a3e")
	for row in 4:
		var y := r.position.y + 12 + row * 15
		if y > r.end.y - 6:
			break
		var x0 := minf(x_in, x_out) + 8 + row * 2
		var x1 := maxf(x_in, x_out) - 14
		draw_rect(Rect2(x0, y, x1 - x0, 11), P1)
		draw_line(Vector2(x0, y), Vector2(x1, y), P2, 1.0)
		var k := 0
		var x := x0 + 4
		while x < x1 - 6:
			var hsh := CityGen.hashf(k, row, 31 if side > 0 else 37)
			if hsh < 0.5:
				draw_rect(Rect2(x, y + 3, 2, 5), P3) # toggle
				draw_rect(Rect2(x, y + (2 if hsh < 0.22 else 6), 2, 2), P4)
			elif hsh < 0.7:
				draw_circle(Vector2(x + 2, y + 5), 2.0, P3) # knob
				draw_rect(Rect2(x + 1, y + 4, 2, 1), P0)
			elif hsh < 0.93:
				draw_rect(Rect2(x, y + 4, 2, 2), lamp)
			else:
				draw_rect(Rect2(x, y + 2, 5, 7), STRIPE_Y * lerpf(1.0, 0.6, night)) # striped guard
				draw_line(Vector2(x, y + 7), Vector2(x + 4, y + 3), P0, 1.0)
			x += 7
			k += 1
	# a big striped handle near the front
	var hx := x_in - side * 26.0
	var hy := r.position.y + 6
	draw_rect(Rect2(hx - 3, hy, 7, 18), P0)
	for i in 4:
		draw_rect(Rect2(hx - 2, hy + 1 + i * 4, 5, 2), STRIPE_Y * lerpf(1.0, 0.6, night))


## Up-front control panel: keypad with two small read-outs; the HUD
## projector housing sits on top of it.
func _ufcp(jet: Jet, c: Vector2, top: float, big: bool, night: float) -> void:
	var bw := 92.0 if big else 80.0
	var bh := 60.0 if big else 40.0
	var r := Rect2(c.x - bw * 0.5, top - 14.0, bw, bh)
	draw_rect(r.grow(1), A0)
	draw_rect(r, P2)
	draw_line(r.position, Vector2(r.end.x, r.position.y), P4, 1.0)
	# read-outs
	var ro := Rect2(r.position + Vector2(5, 4), Vector2(bw - 10, 9))
	draw_rect(ro, SCREEN)
	var lc := LAMP_G
	ptext(ro.position + Vector2(2, 2), "%03d" % int(fposmod(rad_to_deg(-jet.yaw), 360.0)), lc)
	ptext(Vector2(ro.end.x - 22, ro.position.y + 2), "%d" % int(jet.speed * 3.6), lc)
	# keys
	var cols := 6 if big else 5
	var rows := 4 if big else 2
	var kw := floorf((bw - 10.0) / cols)
	for row in rows:
		for col in cols:
			var kp := r.position + Vector2(5 + col * kw, 16 + row * 10)
			draw_rect(Rect2(kp, Vector2(kw - 2, 8)), P0)
			draw_rect(Rect2(kp + Vector2(0, 0), Vector2(kw - 2, 1)), P3)
			var lab: String = KEYS[(row * cols + col) % KEYS.size()] if row < 2 else ["A", "B", "G", "M", "N", "U"][col % 6]
			var labc := LAMP_G if night > 0.4 else Color("d8dce4") * Color(1, 1, 1, 0.85)
			ptext(kp + Vector2(floorf((kw - 2) * 0.5) - 1, 2), lab, labc)
	# HUD projector housing on top
	draw_rect(Rect2(c.x - 30, top - 20, 60, 7), A0)
	draw_rect(Rect2(c.x - 29, top - 19, 58, 1), A2)


## Display bezel with soft keys on all four sides.
func _mfd_frame(rr: Rect2) -> void:
	draw_rect(rr.grow(5), A0)
	draw_rect(rr.grow(4), P2)
	draw_line(rr.grow(4).position, Vector2(rr.grow(4).end.x, rr.grow(4).position.y), P4, 1.0)
	draw_rect(rr, SCREEN)
	var nx := maxi(3, int(rr.size.x / 16))
	for k in nx:
		var x := rr.position.x + (k + 0.5) * rr.size.x / nx
		draw_rect(Rect2(x - 2, rr.position.y - 4, 4, 2), P0)
		draw_rect(Rect2(x - 2, rr.end.y + 2, 4, 2), P0)
	var ny := maxi(2, int(rr.size.y / 16))
	for k in ny:
		var y := rr.position.y + (k + 0.5) * rr.size.y / ny
		draw_rect(Rect2(rr.position.x - 4, y - 2, 2, 4), P0)
		draw_rect(Rect2(rr.end.x + 2, y - 2, 2, 4), P0)
	draw_line(rr.position + Vector2(1, 1), Vector2(rr.end.x - 2, rr.position.y + 1), Color(1, 1, 1, 0.07), 1.0)


## Radar scope: arcs, sweep, contacts (enemies yellow, locked red, friends
## cyan), own symbol at the bottom.
func _radar(rr0: Rect2) -> void:
	var rr := Rect2(rr0.position.round(), rr0.size.round()).grow(-5)
	_mfd_frame(rr)
	var c := Vector2(floorf(rr.get_center().x), floorf(rr.end.y - 4))
	var rad := minf(rr.size.y - 8, rr.size.x * 0.5 - 3)
	var g := Color(HUD.r, HUD.g, HUD.b, 0.3)
	for k in [0.33, 0.66, 1.0]:
		draw_arc(c, rad * k, PI * 1.15, PI * 1.85, 16, g, 1.0)
	draw_line(c, c + Vector2(0, -rad), g, 1.0)
	var sw := PI * 1.15 + fmod(Time.get_ticks_msec() / 1000.0 * 1.6, 1.0) * PI * 0.7
	draw_line(c, (c + Vector2(cos(sw), sin(sw)) * rad).round(), Color(HUD.r, HUD.g, HUD.b, 0.6), 1.0)
	var jet: Jet = game.jet
	var rng := 2200.0
	var fwd := Vector2(-sin(jet.yaw), -cos(jet.yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var lt = game.missiles.lock_target
	var cons: Array = []
	for pl in game.fleet.planes:
		if pl.alive and pl != jet:
			cons.append(pl)
	for e0 in game.enemies.pool:
		if e0.active:
			cons.append(e0)
	for e in cons:
		var ep: Vector3 = Missiles.tpos(e)
		if ep == Vector3.INF:
			continue
		var d := Vector2(ep.x - jet.position.x, ep.z - jet.position.z)
		var p := Vector2(d.dot(right), -d.dot(fwd)) / rng * rad
		if p.y > 0.0 or p.length() > rad:
			continue
		var col := YEL
		if "team" in e and e.team == jet.team:
			col = Color(0.4, 0.9, 1.0)
		if e == lt:
			col = RED
		draw_rect(Rect2((c + p).round() - Vector2(1, 1), Vector2(3, 2)), col)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), HUD)
	ptext(rr.position + Vector2(2, 2), "22", HUD_DIM)


## Engine page: throttle / heat bars and digital speed, G, altitude.
func _engine_page(jet: Jet, rr0: Rect2) -> void:
	var rr := Rect2(rr0.position.round(), rr0.size.round()).grow(-5)
	_mfd_frame(rr)
	var bh := rr.size.y - 12
	for k in 2:
		var v: float = jet.throttle if k == 0 else jet.heat / 100.0
		var x := rr.position.x + 5 + k * 12
		draw_rect(Rect2(x, rr.position.y + 4, 8, bh), Color(HUD.r, HUD.g, HUD.b, 0.12))
		var col := HUD if k == 0 else (RED if jet.overheated else ORANGE)
		if k == 0 and jet.boosting:
			col = ORANGE
		var fh := floorf(bh * clampf(v, 0.0, 1.0))
		draw_rect(Rect2(x, rr.position.y + 4 + bh - fh, 8, fh), col)
	# small round dials like a real engine page
	var dc := Vector2(rr.end.x - 16, rr.position.y + 14)
	for k in 2:
		var cc := dc + Vector2(0, k * 22)
		if cc.y + 9 > rr.end.y:
			break
		draw_arc(cc, 9.0, PI * 0.75, PI * 2.25, 14, HUD_DIM, 1.0)
		var v2: float = jet.throttle if k == 0 else clampf(jet.speed / jet.boost_speed(), 0.0, 1.0)
		var a := lerpf(PI * 0.75, PI * 2.25, v2)
		draw_line(cc, (cc + Vector2(cos(a), sin(a)) * 8.0).round(), YEL, 1.0)
	var tx := rr.position.x + 32
	ptext(Vector2(tx, rr.position.y + 4), "%d" % int(jet.speed * 3.6), HUD)
	ptext(Vector2(tx, rr.position.y + 13), "%.1f" % jet.g_load, HUD)
	ptext(Vector2(tx, rr.position.y + 22), str(int(jet.position.y)), HUD_DIM)


## Primary flight display: digital attitude (sky / ground) with speed and
## altitude boxes.
func _pfd(jet: Jet, rr0: Rect2) -> void:
	var rr := Rect2(rr0.position.round(), rr0.size.round()).grow(-5)
	_mfd_frame(rr)
	var r := floorf(minf(rr.size.x, rr.size.y) * 0.5 - 2)
	var c := rr.get_center().floor()
	_attitude(jet, c, r)
	draw_rect(Rect2(rr.position + Vector2(1, rr.size.y * 0.5 - 4), Vector2(18, 8)), SCREEN)
	ptext(rr.position + Vector2(2, rr.size.y * 0.5 - 2), str(int(jet.speed * 3.6)), Color.WHITE)


## Older round attitude ball in a bezel (heavy tiers 1-2).
func _ball(jet: Jet, c: Vector2, r: float) -> void:
	draw_circle(c, r + 5, A0)
	draw_circle(c, r + 4, P3)
	draw_arc(c, r + 3, PI * 0.9, PI * 1.6, 20, P4, 1.0)
	draw_circle(c, r + 1, A0)
	_attitude(jet, c, r)


## Panoramic display (heavy tiers 3-4): flight / radar / engine pages.
func _panoramic(jet: Jet, rr0: Rect2) -> void:
	var rr := Rect2(rr0.position.round(), rr0.size.round()).grow(-5)
	_mfd_frame(rr)
	var third := floorf(rr.size.x / 3.0)
	# page tabs along the top
	for k in 6:
		var tx := rr.position.x + 4 + k * floorf(rr.size.x / 6.0)
		draw_rect(Rect2(tx, rr.position.y + 1, floorf(rr.size.x / 6.0) - 6, 5), Color(HUD.r, HUD.g, HUD.b, 0.18 if k != 1 else 0.45))
	var r := floorf(minf(third * 0.5, (rr.size.y - 8) * 0.5) - 3)
	_attitude(jet, Vector2(rr.position.x + third * 0.5, rr.position.y + 8 + (rr.size.y - 8) * 0.5).floor(), r)
	var mid := Rect2(rr.position.x + third + 3, rr.position.y + 9, third - 6, rr.size.y - 11)
	draw_rect(mid, Color(0.04, 0.09, 0.06))
	_radar_inner(mid)
	var eng := Rect2(rr.position.x + third * 2 + 3, rr.position.y + 9, third - 6, rr.size.y - 11)
	for k in 4:
		var v: float = [jet.throttle, jet.heat / 100.0, clampf(jet.speed / jet.boost_speed(), 0.0, 1.0), jet.health / jet.max_health][k]
		var x := eng.position.x + 4 + k * 13
		var bh := eng.size.y - 12
		draw_rect(Rect2(x, eng.position.y + 2, 8, bh), Color(HUD.r, HUD.g, HUD.b, 0.12))
		var col := HUD
		if k == 1:
			col = RED if jet.overheated else ORANGE
		elif k == 3 and v < 0.4:
			col = RED
		var fh := floorf(bh * clampf(v, 0.0, 1.0))
		draw_rect(Rect2(x, eng.position.y + 2 + bh - fh, 8, fh), col)
	ptext(Vector2(eng.position.x + 2, eng.end.y - 7), "%.1f G" % jet.g_load, HUD)


func _radar_inner(rr: Rect2) -> void:
	var c := Vector2(floorf(rr.get_center().x), floorf(rr.end.y - 3))
	var rad := minf(rr.size.y - 5, rr.size.x * 0.5 - 2)
	var g := Color(HUD.r, HUD.g, HUD.b, 0.3)
	for k in [0.5, 1.0]:
		draw_arc(c, rad * k, PI * 1.15, PI * 1.85, 14, g, 1.0)
	var sw := PI * 1.15 + fmod(Time.get_ticks_msec() / 1000.0 * 1.6, 1.0) * PI * 0.7
	draw_line(c, (c + Vector2(cos(sw), sin(sw)) * rad).round(), Color(HUD.r, HUD.g, HUD.b, 0.6), 1.0)
	var jet: Jet = game.jet
	var fwd := Vector2(-sin(jet.yaw), -cos(jet.yaw))
	var right := Vector2(-fwd.y, fwd.x)
	for pl in game.fleet.planes:
		if not pl.alive or pl == jet:
			continue
		var d := Vector2(pl.position.x - jet.position.x, pl.position.z - jet.position.z)
		var p := Vector2(d.dot(right), -d.dot(fwd)) / 2200.0 * rad
		if p.y > 0.0 or p.length() > rad:
			continue
		draw_rect(Rect2((c + p).round() - Vector2(1, 1), Vector2(3, 2)), Color(0.4, 0.9, 1.0) if pl.team == jet.team else YEL)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), HUD)


## Moving map (attackers): north-up grid, battle-area edge, bases, contacts,
## own arrow turning with the heading.
func _map(jet: Jet, rr0: Rect2) -> void:
	var rr := Rect2(rr0.position.round(), rr0.size.round()).grow(-5)
	_mfd_frame(rr)
	draw_rect(rr, Color(0.1, 0.16, 0.12))
	var c := rr.get_center().floor()
	var sc := (rr.size.x * 0.5) / 3000.0
	var grid := 1000.0
	var ox := fposmod(jet.position.x, grid) * sc
	var oz := fposmod(jet.position.z, grid) * sc
	var gc := Color(0.35, 0.6, 0.4, 0.35)
	var x := rr.position.x + fposmod(c.x - rr.position.x - ox, grid * sc)
	while x < rr.end.x:
		draw_line(Vector2(floorf(x), rr.position.y), Vector2(floorf(x), rr.end.y), gc, 1.0)
		x += grid * sc
	var y := rr.position.y + fposmod(c.y - rr.position.y - oz, grid * sc)
	while y < rr.end.y:
		draw_line(Vector2(rr.position.x, floorf(y)), Vector2(rr.end.x, floorf(y)), gc, 1.0)
		y += grid * sc
	if "bases" in game and game.bases != null and "centers" in game.bases:
		for bc in game.bases.centers:
			var p := c + Vector2(bc.x - jet.position.x, bc.z - jet.position.z) * sc
			if rr.grow(-2).has_point(p):
				draw_rect(Rect2(p.round() - Vector2(2, 2), Vector2(5, 5)), Color(0.9, 0.7, 0.3), false, 1.0)
	for pl in game.fleet.planes:
		if not pl.alive or pl == jet:
			continue
		var p := c + Vector2(pl.position.x - jet.position.x, pl.position.z - jet.position.z) * sc
		if rr.grow(-2).has_point(p):
			draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(0.4, 0.9, 1.0) if pl.team == jet.team else RED)
	var fw := Vector2(-sin(jet.yaw), -cos(jet.yaw))
	var rt := Vector2(-fw.y, fw.x)
	draw_colored_polygon(PackedVector2Array([c + fw * 5.0, c - fw * 3.0 + rt * 3.0, c - fw * 3.0 - rt * 3.0]), Color.WHITE)
	ptext(rr.position + Vector2(2, 2), "N", Color(0.8, 0.9, 0.8))


## Analog cluster: four small round gauges in a panel.
func _gauge_cluster(jet: Jet, rr0: Rect2) -> void:
	var rr := Rect2(rr0.position.round(), rr0.size.round()).grow(-3)
	draw_rect(rr.grow(2), A0)
	draw_rect(rr, P2)
	var gr := floorf(minf(rr.size.x, rr.size.y) * 0.25 - 2)
	var vals := [jet.speed / (jet.boost_speed() * 1.05), jet.position.y / 1000.0, jet.throttle, jet.health / jet.max_health]
	for k in 4:
		var gc := rr.position + Vector2(rr.size.x * (0.27 + 0.46 * (k % 2)), rr.size.y * (0.27 + 0.46 * (k / 2)))
		_gauge(gc.floor(), gr, vals[k])


func _gauge(c: Vector2, r: float, frac: float) -> void:
	draw_circle(c, r + 2, A0)
	draw_circle(c, r + 1, P3)
	draw_circle(c, r, DIAL)
	for k in 9:
		var a := lerpf(PI * 0.75, PI * 2.25, k / 8.0)
		var o := c + Vector2(cos(a), sin(a)) * (r - 1)
		var i := c + Vector2(cos(a), sin(a)) * (r - (3.0 if k % 4 == 0 else 2.0))
		draw_line(i.round(), o.round(), Color(0.85, 0.87, 0.9, 0.8) if k % 4 == 0 else Color(0.5, 0.52, 0.56), 1.0)
	draw_arc(c, r - 1, PI * 2.0, PI * 2.25, 4, Color("8a1a10"), 1.0)
	var na := lerpf(PI * 0.75, PI * 2.25, clampf(frac, 0.0, 1.0))
	draw_line(c, (c + Vector2(cos(na), sin(na)) * (r - 2)).round(), ORANGE, 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), P4)


func _attitude(jet: Jet, c: Vector2, r: float) -> void:
	var roll := jet.roll + jet.roll_extra
	var n := Vector2(-sin(roll), cos(roll))
	var tang := Vector2(n.y, -n.x)
	var off := rad_to_deg(wrapf(jet.pitch, -PI, PI)) * r / 45.0
	var amb: Color = Color(1, 1, 1)
	if game.daynight != null:
		amb = Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.85), game.daynight.night * 0.5)
	var sky := SKY * amb
	var sky_d := SKY_D * amb
	var gnd := GROUND * amb
	var gnd_d := GROUND_D * amb
	for yy in range(int(-r), int(r) + 1):
		var half := sqrt(maxf(0.0, r * r - yy * yy))
		var y := c.y + yy
		var a := Vector2(c.x - half, y)
		var b := Vector2(c.x + half, y)
		var da := n.dot(a - c) - off
		var db := n.dot(b - c) - off
		var sc := sky if yy % 4 != 0 else sky_d
		var gc := gnd if yy % 4 != 0 else gnd_d
		if da <= 0.0 and db <= 0.0:
			draw_line(a, b, sc, 1.0)
		elif da > 0.0 and db > 0.0:
			draw_line(a, b, gc, 1.0)
		else:
			var t := da / (da - db)
			var mm := a.lerp(b, t)
			draw_line(a, mm, sc if da <= 0.0 else gc, 1.0)
			draw_line(mm, b, gc if da <= 0.0 else sc, 1.0)
	var hz := c + n * off
	draw_line(hz - tang * r * 0.95, hz + tang * r * 0.95, Color.WHITE, 1.0)
	for k in [-2, -1, 1, 2]:
		var p: Vector2 = hz - n * (k * r * 0.22)
		if p.distance_to(c) < r - 3:
			draw_line(p - tang * r * 0.16, p + tang * r * 0.16, Color(1, 1, 1, 0.8), 1.0)
	draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(-5, 0), YEL, 1.0)
	draw_line(c + Vector2(5, 0), c + Vector2(r * 0.55, 0), YEL, 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), YEL)


## The pilot's knees in the flight suit, left and right of the stick.
func _legs(w: float, h: float, c: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var kc := Vector2(c.x + side * 100.0, h + 12.0)
		draw_circle(kc, 34.0, SUIT.darkened(0.25))
		draw_circle(kc + Vector2(-side * 2.0, -2.0), 31.0, SUIT)
		draw_circle(kc + Vector2(-side * 8.0, -12.0), 12.0, SUIT.lightened(0.08))
		# knee-board strap and a thigh pocket seam
		draw_rect(Rect2(kc.x - 20, kc.y - 26, 40, 3), SUIT.darkened(0.4))
		draw_line(kc + Vector2(-side * 14, -14), kc + Vector2(-side * 4, 0), SUIT.darkened(0.3), 1.0)


## Centre stick between the knees, moves with the input.
func _stick(base: Vector2) -> void:
	var s: Vector2 = game.controls.stick
	var knob := base + Vector2(s.x * 10.0, -40.0 + s.y * 6.0)
	draw_rect(Rect2(base.x - 12, base.y - 10, 24, 10), A0)
	for i in 3:
		draw_rect(Rect2(base.x - 10 + i, base.y - 9 + i * 3, 20 - i * 2, 1), P2)
	var segs := 9
	for i in segs:
		var p := base.lerp(knob, (i + 0.5) / segs)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 4)), A0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 2)), P3 if i % 2 == 0 else P2)
	# grip: dark, red trigger, hat, pinkie switch
	draw_rect(Rect2(knob - Vector2(7, 14), Vector2(14, 18)), A0)
	draw_rect(Rect2(knob - Vector2(6, 13), Vector2(12, 16)), A1)
	draw_rect(Rect2(knob - Vector2(6, 13), Vector2(12, 2)), A2)
	draw_rect(Rect2(knob + Vector2(-5, -6), Vector2(3, 4)), ORANGE if game.controls.fire else Color("8a2a10"))
	draw_rect(Rect2(knob + Vector2(1, -11), Vector2(4, 4)), A0)
	draw_rect(Rect2(knob + Vector2(2, -10), Vector2(2, 2)), P4 if game.controls.boost else P3)
	draw_rect(Rect2(knob + Vector2(-6, 0), Vector2(12, 2)), A0)


# ------------------------------------------------------------------ head look

## Screen point of a plane-fixed direction (yaw +left, pitch +up) for the
## current head look; INF when it is out of view.
func _dir2scr(yaw: float, pitch: float, c: Vector2, f: float, look: Vector2) -> Vector2:
	var dy := wrapf(yaw - look.x, -PI, PI)
	var dp := pitch - look.y
	if absf(dy) > 1.35 or absf(dp) > 1.35:
		return Vector2.INF
	return Vector2(c.x - tan(dy) * f, c.y - tan(dp) * f)


## What you see when turning the head: the canopy sill and side wall with a
## console, the rear canopy bow and the ejection seat's headrest.
func _sides(w: float, h: float, c: Vector2, f: float, look: Vector2) -> void:
	if absf(look.x) < 0.3:
		return
	for s in [1.0, -1.0]:
		# sill: pitch along the side going back
		var top := PackedVector2Array()
		var yaw := 0.95
		while yaw <= 3.15:
			var pitch := lerpf(-0.62, -0.5, clampf((yaw - 0.95) / 1.0, 0.0, 1.0))
			var p := _dir2scr(s * yaw, pitch, c, f, look)
			if p != Vector2.INF:
				top.append(Vector2(clampf(p.x, -40, w + 40), p.y))
			yaw += 0.08
		if top.size() >= 2:
			var poly := PackedVector2Array(top)
			poly.append(Vector2(top[top.size() - 1].x, h + 2))
			poly.append(Vector2(top[0].x, h + 2))
			draw_colored_polygon(poly, P1)
			var rail := PackedVector2Array()
			for p in top:
				rail.append(p + Vector2(0, 4))
			draw_polyline(top, A0, 1.0)
			draw_polyline(rail, A1, 4.0)
			draw_polyline(rail, P3, 1.0)
			# switch rows on the side console
			for k in range(1, top.size() - 1, 3):
				var p: Vector2 = top[k]
				for row in 3:
					var y := p.y + 12 + row * 12
					if y < h - 4:
						draw_rect(Rect2(p.x - 6, y, 12, 8), P0)
						draw_rect(Rect2(p.x - 4, y + 2, 2, 4), P3)
						draw_rect(Rect2(p.x + 1, y + 3, 2, 2), LAMP_G if (k + row) % 4 == 0 else P2)
		# left: throttle quadrant with the lever at the current throttle;
		# right: a small console display
		var qa := _dir2scr(s * 1.3, -0.66, c, f, look)
		var qb := _dir2scr(s * 1.6, -0.62, c, f, look)
		if qa != Vector2.INF and qb != Vector2.INF:
			var x0 := minf(qa.x, qb.x)
			var qw := absf(qb.x - qa.x)
			var qr := Rect2(x0, qa.y + 8, qw, 30)
			draw_rect(qr.grow(1), A0)
			draw_rect(qr, P2)
			if s > 0.0:
				var jet: Jet = game.jet
				var slot := Rect2(qr.position.x + 6, qr.get_center().y - 2, qw - 12, 4)
				draw_rect(slot, A0)
				var hx := slot.position.x + slot.size.x * (1.0 - jet.throttle)
				draw_rect(Rect2(hx - 5, slot.position.y - 22, 10, 22), A1)
				draw_rect(Rect2(hx - 6, slot.position.y - 30, 12, 10), A0)
				draw_rect(Rect2(hx - 5, slot.position.y - 29, 10, 8), P3)
				draw_rect(Rect2(hx - 4, slot.position.y - 28, 3, 2), ORANGE if jet.boosting else P4)
			else:
				var sr := qr.grow(-5)
				draw_rect(sr, SCREEN)
				ptext(sr.position + Vector2(3, 3), "%d" % int(game.jet.heat), LAMP_G)
				draw_rect(Rect2(sr.position.x + 3, sr.end.y - 6, (sr.size.x - 6) * clampf(game.jet.health / game.jet.max_health, 0.0, 1.0), 3), LAMP_G)
		# rear canopy bow rising from the sill over the head
		var bow := PackedVector2Array()
		var pt := -0.42
		while pt < 1.25:
			var p := _dir2scr(s * 1.85, pt, c, f, look)
			if p != Vector2.INF:
				bow.append(p)
			pt += 0.1
		if bow.size() >= 2:
			draw_polyline(bow, A1, st.get("bow", 8.0))
			draw_polyline(bow, A2, 1.0)
	# ejection seat headrest behind the head
	var hl := _dir2scr(PI, 0.22, c, f, look)
	var hr := _dir2scr(PI, -0.4, c, f, look)
	if hl != Vector2.INF and hr != Vector2.INF:
		var half := tan(0.3) * f
		var r := Rect2(Vector2(hl.x - half, hl.y), Vector2(half * 2.0, hr.y - hl.y))
		draw_rect(r, A1)
		draw_rect(r.grow(-3), P2)
		for k in range(1, 4):
			var yy := r.position.y + r.size.y * k / 4.0
			draw_line(Vector2(r.position.x + 3, yy), Vector2(r.end.x - 3, yy), P1, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), A2)
		# yellow-black ejection handle loop on top
		var lp := Vector2(r.get_center().x, r.position.y - 6)
		draw_rect(Rect2(lp - Vector2(10, 0), Vector2(20, 6)), A0)
		for i in 5:
			draw_rect(Rect2(lp + Vector2(-9 + i * 4, 1), Vector2(2, 4)), STRIPE_Y)
