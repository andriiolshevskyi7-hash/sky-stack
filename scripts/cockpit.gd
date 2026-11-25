class_name Cockpit
extends Node2D
## First-person cockpit drawn in code INSIDE the low-res view, so it is pixel
## art at exactly the world's pixel size. Layout follows the reference
## cockpit, adapted to landscape:
##  canopy  - thick dark-grey frame across the top with bevels, rivets and
##            worn paint, a centre housing with an orange indicator, thin side
##            pillars and a faint reflection line across the glass
##  dash    - bottom ~30%: coaming with a row of orange/red warning lights,
##            a BIG attitude ball (sky blue / ground brown, cloud streaks,
##            rolls and pitches) in a chunky bezel with gold screws, round
##            dark gauges with orange needles both sides, small switches,
##            and a control stick in front that moves with the input
##  HUD     - soft green on the glass: speed / altitude numbers over tapes,
##            pitch ladder rolling with the jet, heading number + scale with
##            a triangle, gun reticle (brackets + cross); yellow seeker circle
##            with arcs pointing at enemies, yellow brackets on enemies in
##            view, red lock circle, yellow lead marker
## Touch buttons sit at the outer edges of the dashboard; every instrument
## and HUD number stays inside the free centre band.

var game: Node
var size := Vector2(748, 336)
var alpha := 0.0

const HUD := Color(0.47, 0.95, 0.55, 0.92) # soft green
const HUD_DIM := Color(0.47, 0.95, 0.55, 0.5)
const YEL := Color("ffd84a")
const YEL_DIM := Color(1.0, 0.85, 0.3, 0.55)
const RED := Color("ff3b30")
const ORANGE := Color("f0580e")
const ORANGE_L := Color("ff9a4a")
const ORANGE_D := Color("7a2a0e")
const GOLD := Color("c9a03c")
const GOLD_L := Color("f0d27a")
const SKY := Color("4fa3ee")
const SKY_D := Color("3a8bd8")
const GROUND := Color("9a6232")
const GROUND_D := Color("80501f")
const F0 := Color("17181d") # darkest metal / outlines
const F1 := Color("2d3038")
const F2 := Color("41454f")
const F3 := Color("5f6472")
const F4 := Color("8f96a5") # highlights
const RIV := Color("a9afbb")
const DIAL := Color("121318")

const DASH_FRAC := 0.69 # glass above, dashboard below (bottom ~30%)
const TOP_BAR := 15.0

## 3x5 pixel font for numbers (crisp at the world pixel size).
const GLYPHS := {
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7], "3": [7, 1, 7, 1, 7],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7], "6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 2, 2],
	"8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 7], "-": [0, 0, 7, 0, 0], " ": [0, 0, 0, 0, 0],
}

var _font: Font


func _ready() -> void:
	_font = UI.font(8)


## Pixel digits; sc = size of one glyph pixel.
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


func _draw() -> void:
	if game == null:
		return
	modulate.a = alpha
	var jet: Jet = game.jet
	var w := floorf(size.x)
	var h := floorf(size.y)
	var dash_top := floorf(h * DASH_FRAC)
	var c := Vector2(floorf(w * 0.5), floorf(TOP_BAR + (dash_top - TOP_BAR) * 0.5) + 2)
	_glass(w, dash_top)
	_hud(jet, c, w, h, dash_top)
	_canopy(w, h, dash_top)
	_dash(jet, w, h, dash_top)


# ------------------------------------------------------------------ glass

func _glass(w: float, dash_top: float) -> void:
	# faint reflection line across the glass, plus a soft diagonal glint
	var ry := floorf(TOP_BAR + (dash_top - TOP_BAR) * 0.16)
	draw_line(Vector2(0, ry), Vector2(w, ry), Color(1, 1, 1, 0.13), 1.0)
	draw_line(Vector2(0, ry + 1), Vector2(w, ry + 1), Color(1, 1, 1, 0.05), 1.0)
	draw_line(Vector2(w * 0.78, TOP_BAR + 4), Vector2(w * 0.9, dash_top * 0.45), Color(1, 1, 1, 0.05), 3.0)


# ------------------------------------------------------------------ HUD

func _hud(jet: Jet, c: Vector2, w: float, h: float, dash_top: float) -> void:
	var roll := jet.roll + jet.roll_extra
	var pitch_deg := rad_to_deg(wrapf(jet.pitch, -PI, PI))
	var glass_h := dash_top - TOP_BAR
	var px_per_deg := glass_h / 55.0
	var right := Vector2(cos(roll), sin(roll))
	var down := Vector2(-sin(roll), cos(roll))
	# pitch ladder (solid above the horizon, dashed below, bent ends)
	for k in range(-9, 10):
		var deg := k * 10
		var off := (pitch_deg - deg) * px_per_deg
		if absf(off) > glass_h * 0.36:
			continue
		var mid := c + down * off
		var half := 34.0 if deg != 0 else 100.0
		var gap := 16.0
		var col := HUD if deg >= 0 else HUD_DIM
		for side in [-1.0, 1.0]:
			if deg < 0:
				var t := gap
				while t < half:
					draw_line((mid + right * side * t).round(), (mid + right * side * minf(t + 4.0, half)).round(), col, 1.0)
					t += 7.0
			else:
				draw_line((mid + right * side * gap).round(), (mid + right * side * half).round(), col, 1.0)
			if deg != 0:
				var tip := down * (4.0 if deg > 0 else -4.0)
				draw_line((mid + right * side * half).round(), (mid + right * side * half + tip).round(), col, 1.0)
		if deg != 0:
			ptext(mid + right * (half + 9.0) - Vector2(0, 2), str(absi(deg)), col, true)
	# gun reticle: bracket box + cross
	draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), HUD, 1.0)
	draw_line(c + Vector2(0, -5), c + Vector2(0, 5), HUD, 1.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * 16.0, sy * 16.0)
			draw_line(p, p - Vector2(sx * 7.0, 0), HUD, 1.0)
			draw_line(p, p - Vector2(0, sy * 7.0), HUD, 1.0)
	_targets(jet, c, w, dash_top, glass_h)
	# speed (left) and altitude (right): big numbers above tapes
	var tape_h := floorf(glass_h * 0.5)
	var ty := c.y - tape_h * 0.5
	var lx := floorf(w * 0.17)
	var rx := floorf(w * 0.83)
	_tape(lx, ty, tape_h, jet.speed * 3.6, 10.0, 1.0, false)
	_tape(rx, ty, tape_h, jet.position.y, 20.0, 0.5, true)
	ptext(Vector2(lx, ty - 16), str(int(jet.speed * 3.6)), HUD, true, 2)
	ptext(Vector2(rx, ty - 16), str(int(jet.position.y)), HUD, true, 2)
	# heading scale + number at the bottom of the glass, triangle marker
	var hdg := fposmod(rad_to_deg(-jet.yaw), 360.0)
	var hy := floorf(dash_top - 16)
	draw_line(Vector2(c.x - 90, hy), Vector2(c.x + 90, hy), HUD, 1.0)
	for d in range(-50, 51, 5):
		var a := roundi(hdg / 5.0) * 5 + d
		var x := roundf(c.x + (a - hdg) * 1.8)
		if absf(x - c.x) > 90.0:
			continue
		draw_line(Vector2(x, hy), Vector2(x, hy - (6.0 if posmod(a, 10) == 0 else 3.0)), HUD, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, hy + 2), Vector2(c.x - 4, hy + 7), Vector2(c.x + 4, hy + 7)]), HUD)
	ptext(Vector2(c.x, hy - 19), "%03d" % int(hdg), HUD, true, 2)
	if jet.multiplier > 1:
		wtext(Vector2(c.x, c.y + 34), tr("LOW X%d") % jet.multiplier, YEL)
	if game.missiles.counter_t > 0.0:
		wtext(Vector2(c.x, c.y - 30), "COUNTER", RED)


## Yellow seeker circle with arcs/triangles towards enemies, brackets on
## enemies in view, red lock circle, yellow lead marker.
func _targets(jet: Jet, c: Vector2, w: float, dash_top: float, glass_h: float) -> void:
	var m: Missiles = game.missiles
	var tgts: Array = []
	for e0 in game.enemies.pool:
		if e0.active:
			tgts.append(e0)
	for pl in game.fleet.planes:
		if pl.alive and pl.team != jet.team:
			tgts.append(pl)
	var sr := floorf(glass_h * 0.36) # seeker circle radius
	if not tgts.is_empty():
		# dashed seeker circle
		for k in 24:
			var a0 := TAU * k / 24.0
			draw_arc(c, sr, a0, a0 + TAU / 48.0, 3, YEL_DIM, 1.0)
	var fwd: Vector3 = -game.cam.global_transform.basis.z
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
		var on_glass := not behind and sp.y < dash_top - 4 and sp.y > TOP_BAR + 2 and sp.x > 8 and sp.x < w - 8
		# direction on the seeker circle
		var ang := atan2(-to.dot(cam_u), to.dot(cam_r)) if (behind or not on_glass or sp.distance_to(c) > sr) else (sp - c).angle()
		if dist < nearest:
			nearest = dist
			near_ang = ang
		if on_glass and e != m.lock_target:
			# yellow corner brackets on the enemy
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p := sp + Vector2(sx * 6.0, sy * 6.0)
					draw_line(p, p - Vector2(sx * 3.0, 0), YEL, 1.0)
					draw_line(p, p - Vector2(0, sy * 3.0), YEL, 1.0)
		if not on_glass or sp.distance_to(c) > sr:
			# short yellow arc on the seeker circle towards it
			draw_arc(c, sr, ang - 0.12, ang + 0.12, 6, YEL, 1.0)
	if nearest < 1e8:
		var tp := c + Vector2(cos(near_ang), sin(near_ang)) * (sr + 1)
		var tn := Vector2(cos(near_ang), sin(near_ang))
		var tt := Vector2(-tn.y, tn.x)
		draw_colored_polygon(PackedVector2Array([tp + tn * 7.0, tp + tt * 4.0, tp - tt * 4.0]), YEL)
	var lpos: Vector3 = Missiles.tpos(m.lock_target)
	if lpos != Vector3.INF and not game.cam.is_position_behind(lpos):
		var lp2: Vector2 = game.cam.unproject_position(lpos).round()
		var k := clampf(m.lock_t / m.lock_time, 0.0, 1.0)
		var rr := lerpf(30.0, 11.0, k)
		draw_arc(lp2, rr, 0, TAU, 28, RED if m.locked else YEL, 1.0)
		# lead marker: where to point the nose for the cannon
		var e = m.lock_target
		var dist2: float = jet.position.distance_to(lpos)
		var lead: Vector3 = lpos + Vector3(-sin(e.yaw), 0, -cos(e.yaw)) * e.speed * dist2 / 600.0
		if not game.cam.is_position_behind(lead):
			var ld: Vector2 = game.cam.unproject_position(lead).round()
			draw_arc(ld, 4.0, 0, TAU, 10, YEL, 1.0)
			draw_line(lp2, ld, Color(YEL.r, YEL.g, YEL.b, 0.4), 1.0)
		if m.locked:
			wtext(lp2 + Vector2(0, rr + 11), "LOCK", RED)


func _tape(x: float, y0: float, hgt: float, value: float, step: float, px_per_unit: float, right_side: bool) -> void:
	var cy := y0 + hgt * 0.5
	var dir := 1.0 if right_side else -1.0
	draw_line(Vector2(x, y0), Vector2(x, y0 + hgt), HUD, 1.0)
	var v := floorf((value - hgt * 0.5 / px_per_unit) / step) * step
	while v <= value + hgt * 0.5 / px_per_unit:
		var y := roundf(cy - (v - value) * px_per_unit)
		if y >= y0 and y <= y0 + hgt:
			var major := posmod(int(round(v / step)), 5) == 0
			draw_line(Vector2(x, y), Vector2(x - dir * (8.0 if major else 4.0), y), HUD, 1.0)
		v += step
	# pointer triangle at the current value
	var px := x + dir * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(px, cy), Vector2(px + dir * 7.0, cy - 5), Vector2(px + dir * 7.0, cy + 5)]), HUD)


# ------------------------------------------------------------------ canopy

func _rivets(a: Vector2, b: Vector2, n: int) -> void:
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n).round()
		draw_rect(Rect2(p, Vector2(1, 1)), RIV)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), F0)


## Worn paint: scattered scratches (stable per position).
func _wear(r: Rect2, n: int, salt: int) -> void:
	for i in n:
		var x := r.position.x + CityGen.hashf(i, salt, 71) * r.size.x
		var y := r.position.y + CityGen.hashf(i, salt, 72) * r.size.y
		var k := CityGen.hashf(i, salt, 73)
		var col := F3 if k < 0.55 else (F0 if k < 0.85 else ORANGE_D)
		draw_rect(Rect2(floorf(x), floorf(y), 2 if k > 0.7 else 1, 1), col)


func _canopy(w: float, h: float, dash_top: float) -> void:
	# thick top frame with bevels, rivets and wear
	draw_rect(Rect2(0, 0, w, TOP_BAR), F1)
	draw_rect(Rect2(0, 1, w, 1), F3)
	draw_rect(Rect2(0, TOP_BAR - 3, w, 2), F2)
	draw_rect(Rect2(0, TOP_BAR - 1, w, 1), F0)
	_rivets(Vector2(0, 6), Vector2(w, 6), int(w / 16))
	_wear(Rect2(0, 2, w, TOP_BAR - 5), 70, 1)
	# centre housing hanging down with the orange indicator
	var cw := floorf(w * 0.22)
	var cx := floorf(w * 0.5 - cw * 0.5)
	var hb := TOP_BAR + 14
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 16, 0), Vector2(cx + cw + 16, 0), Vector2(cx + cw + 5, hb), Vector2(cx - 5, hb)]), F1)
	draw_line(Vector2(cx - 5, hb), Vector2(cx + cw + 5, hb), F0, 1.0)
	draw_line(Vector2(cx - 15, 1), Vector2(cx - 5, hb - 1), F3, 1.0)
	draw_line(Vector2(cx + cw + 15, 1), Vector2(cx + cw + 5, hb - 1), F0, 1.0)
	draw_rect(Rect2(cx + 8, 7, cw - 16, 11), F0)
	draw_rect(Rect2(cx + 9, 8, cw - 18, 9), ORANGE)
	draw_rect(Rect2(cx + 9, 8, cw - 18, 2), ORANGE_L)
	draw_rect(Rect2(cx + 9, 15, cw - 18, 2), Color("c2400a"))
	_rivets(Vector2(cx + 2, hb - 5), Vector2(cx + cw - 2, hb - 5), 8)
	# thin side pillars with a highlight edge and rivets
	for side in [0, 1]:
		var sx := 1.0 if side == 0 else -1.0
		var x0 := 0.0 if side == 0 else w
		var pw := 7.0
		var r := Rect2(Vector2(x0 if side == 0 else x0 - pw, TOP_BAR - 1), Vector2(pw, dash_top - TOP_BAR + 1))
		draw_rect(r, F1)
		var inner := x0 + sx * pw
		draw_line(Vector2(inner, TOP_BAR), Vector2(inner, dash_top), F0, 1.0)
		draw_line(Vector2(inner - sx * 2, TOP_BAR), Vector2(inner - sx * 2, dash_top), F3, 1.0)
		_rivets(Vector2(x0 + sx * 3, TOP_BAR + 10), Vector2(x0 + sx * 3, dash_top - 8), 9)
		# corner gusset where the pillar meets the top frame
		draw_colored_polygon(PackedVector2Array([Vector2(inner, TOP_BAR - 1), Vector2(inner + sx * 14, TOP_BAR - 1), Vector2(inner, TOP_BAR + 12)]), F1)
		draw_line(Vector2(inner + sx * 14, TOP_BAR - 1), Vector2(inner, TOP_BAR + 12), F3, 1.0)


# ------------------------------------------------------------------ dashboard

func _dash(jet: Jet, w: float, h: float, top: float) -> void:
	# coaming: raised edge in front of the glass, angled at the sides
	var gs := PackedVector2Array([Vector2(0, top + 7), Vector2(w * 0.16, top), Vector2(w * 0.84, top), Vector2(w, top + 7), Vector2(w, top + 18), Vector2(0, top + 18)])
	draw_colored_polygon(gs, F0)
	draw_polyline(PackedVector2Array([Vector2(0, top + 7), Vector2(w * 0.16, top), Vector2(w * 0.84, top), Vector2(w, top + 7)]), F3, 1.0)
	draw_line(Vector2(w * 0.16, top + 1), Vector2(w * 0.84, top + 1), F2, 1.0)
	# warning lights row (orange / red, blink when urgent)
	var m: Missiles = game.missiles
	var warn := [jet.health < jet.max_health * 0.4, m.incoming_t < 3.0, jet.reloading > 0.0 or m.reload > 0.0, jet.boosting, jet.position.y < CityGen.LOW_ALT or jet.stalling]
	var lw := 20.0
	var lx := floorf(w * 0.5 - warn.size() * (lw + 3) * 0.5)
	var blink := int(Time.get_ticks_msec() / 180) % 2 == 0
	for i in warn.size():
		var on: bool = warn[i]
		var col := Color("4a1a0a") if i % 2 == 0 else Color("5a2410")
		if on:
			col = RED if (i <= 1 and blink) else ORANGE
		draw_rect(Rect2(lx + i * (lw + 3) - 1, top + 5, lw + 2, 9), F0)
		draw_rect(Rect2(lx + i * (lw + 3), top + 6, lw, 7), col)
		draw_rect(Rect2(lx + i * (lw + 3), top + 6, lw, 1), ORANGE_L if on else Color(1, 0.5, 0.2, 0.25))
	# panel body: dark grey with wear
	var py := top + 18
	draw_rect(Rect2(0, py, w, h - py), F1)
	draw_line(Vector2(0, py), Vector2(w, py), F2, 1.0)
	_wear(Rect2(0, py + 1, w, h - py - 1), 140, 2)
	var panel_h := h - py
	# the whole ball + bezel fits between the coaming and the screen edge
	var r := floorf(minf((panel_h - 20.0) * 0.5, 56.0))
	var bc := Vector2(floorf(w * 0.5), floorf(py + r + 10))
	# round gauges both sides (inside the band free of touch buttons)
	var gr := floorf(r * 0.48)
	var g1 := floorf(w * 0.5 - r - gr - 22)
	var g2 := floorf(g1 - gr * 2 - 12)
	var g3 := floorf(w * 0.5 + r + gr + 22)
	var g4 := floorf(g3 + gr * 2 + 12)
	var gy := floorf(py + gr + 7)
	_gauge(Vector2(g1, gy), gr, jet.speed / (jet.boost_speed() * 1.05))
	_gauge(Vector2(g2, gy + 6), gr, jet.boost_energy / 100.0)
	_gauge(Vector2(g3, gy), gr, jet.position.y / 1000.0)
	_gauge(Vector2(g4, gy + 6), gr, jet.health / jet.max_health)
	# small orange / grey switches under the gauges
	_switches(Vector2(g1 - 9, gy + gr + 8), [jet.ammo > 0.0 and jet.reloading <= 0.0, game.missiles_left() > 0])
	_switches(Vector2(g3 - 9, gy + gr + 8), [m.locked, m.counter_t > 0.0])
	_switches(Vector2(g2 - 9, gy + gr + 14), [jet.boosting, false])
	_switches(Vector2(g4 - 9, gy + gr + 14), [jet.health < jet.max_health * 0.4, false])
	# big attitude ball in a chunky metal bezel with gold screws
	draw_circle(bc, r + 9, F0)
	draw_circle(bc, r + 8, F2)
	draw_arc(bc, r + 7, PI * 0.9, PI * 1.6, 24, F4, 2.0) # top-left highlight
	draw_arc(bc, r + 7, -PI * 0.1, PI * 0.6, 24, F0, 2.0)
	draw_circle(bc, r + 4, F3)
	draw_circle(bc, r + 2, F0)
	_attitude(jet, bc, r)
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		var sp := (bc + Vector2(cos(a), sin(a)) * (r + 6)).round()
		draw_rect(Rect2(sp - Vector2(1, 1), Vector2(3, 3)), GOLD)
		draw_rect(Rect2(sp - Vector2(1, 1), Vector2(1, 1)), GOLD_L)
	draw_colored_polygon(PackedVector2Array([bc + Vector2(-4, -r - 8), bc + Vector2(4, -r - 8), bc + Vector2(0, -r - 1)]), YEL)
	# control stick in front of the lower bezel, moves with the input
	_stick(Vector2(floorf(w * 0.5), h), r)


func _gauge(c: Vector2, r: float, frac: float) -> void:
	draw_circle(c, r + 3, F0)
	draw_circle(c, r + 2, F3)
	draw_arc(c, r + 2, PI * 0.95, PI * 1.55, 12, F4, 1.0)
	draw_circle(c, r, DIAL)
	for k in 11:
		var a := lerpf(PI * 0.75, PI * 2.25, k / 10.0)
		var o := c + Vector2(cos(a), sin(a)) * (r - 1)
		var i := c + Vector2(cos(a), sin(a)) * (r - (3.0 if k % 5 == 0 else 2.0))
		draw_line(i.round(), o.round(), F4 if k % 5 == 0 else F3, 1.0)
	# red zone on the last ticks
	draw_arc(c, r - 1, PI * 2.0, PI * 2.25, 4, Color("8a1a10"), 1.0)
	var na := lerpf(PI * 0.75, PI * 2.25, clampf(frac, 0.0, 1.0))
	draw_line(c, (c + Vector2(cos(na), sin(na)) * (r - 3)).round(), ORANGE, 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), F4)


func _switches(p: Vector2, states: Array) -> void:
	for i in states.size():
		var on: bool = states[i]
		draw_rect(Rect2(p + Vector2(i * 11, 0), Vector2(9, 6)), F0)
		draw_rect(Rect2(p + Vector2(i * 11 + 1, 1), Vector2(7, 4)), ORANGE if on else F3)
		draw_rect(Rect2(p + Vector2(i * 11 + 1, 1), Vector2(7, 1)), ORANGE_L if on else F4)


func _attitude(jet: Jet, c: Vector2, r: float) -> void:
	var roll := jet.roll + jet.roll_extra
	var n := Vector2(-sin(roll), cos(roll))
	var tang := Vector2(n.y, -n.x)
	var off := rad_to_deg(wrapf(jet.pitch, -PI, PI)) * r / 45.0
	# sky / ground follow the time of day a little (dusk, night)
	var amb: Color = Color(1, 1, 1)
	if game.daynight != null:
		amb = Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.85), game.daynight.night * 0.6)
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
	# white cloud streaks on the sky half (fixed to the horizon frame)
	for k in 9:
		var u := (CityGen.hashf(k, 1, 61) - 0.5) * r * 1.6
		var v := -(6.0 + CityGen.hashf(k, 2, 61) * r * 0.9)
		var p := hz + tang * u + n * v
		var l := 4.0 + CityGen.hashf(k, 3, 61) * 6.0
		var p0 := p - tang * l * 0.5 - n * 2.0
		var p1 := p + tang * l * 0.5 + n * 2.0
		if p0.distance_to(c) < r - 2 and p1.distance_to(c) < r - 2:
			draw_line(p0.round(), p1.round(), Color(1, 1, 1, 0.85), 1.0)
	# horizon + pitch marks
	draw_line(hz - tang * r * 0.95, hz + tang * r * 0.95, Color.WHITE, 1.0)
	for k in [-2, -1, 1, 2]:
		var p: Vector2 = hz - n * (k * r * 0.22)
		if p.distance_to(c) < r - 3:
			draw_line(p - tang * r * 0.16, p + tang * r * 0.16, Color(1, 1, 1, 0.8), 1.0)
	# fixed aircraft symbol (gold)
	draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(-7, 0), YEL, 2.0)
	draw_line(c + Vector2(7, 0), c + Vector2(r * 0.55, 0), YEL, 2.0)
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), YEL)


func _stick(base: Vector2, r: float) -> void:
	var st: Vector2 = game.controls.stick
	var len := minf(r * 0.3, 12.0) # grip overlaps only the lower bezel
	var knob := base + Vector2(st.x * 10.0, -len + st.y * 6.0)
	# ribbed rubber boot
	draw_rect(Rect2(base.x - 16, base.y - 9, 32, 9), F0)
	for i in 4:
		draw_rect(Rect2(base.x - 14 + i, base.y - 8 + i * 2, 28 - i * 2, 1), F2 if i % 2 == 0 else F3)
	# ribbed shaft
	var segs := 7
	for i in segs:
		var p := base.lerp(knob, (i + 0.5) / segs)
		draw_rect(Rect2(p - Vector2(4, 2), Vector2(8, 4)), F0)
		draw_rect(Rect2(p - Vector2(3, 1), Vector2(6, 2)), F3 if i % 2 == 0 else F2)
	# grip: dark, with the orange trigger and a hat switch
	draw_rect(Rect2(knob - Vector2(10, 13), Vector2(20, 18)), F0)
	draw_rect(Rect2(knob - Vector2(9, 12), Vector2(18, 16)), F2)
	draw_rect(Rect2(knob - Vector2(9, 12), Vector2(18, 2)), F3)
	draw_circle(knob + Vector2(4, -6), 3.0, ORANGE if game.controls.fire else Color("8a2a10"))
	draw_rect(Rect2(knob + Vector2(-7, -8), Vector2(5, 5)), F0)
	draw_rect(Rect2(knob + Vector2(-6, -7), Vector2(3, 3)), F4 if game.controls.boost else F3)
