class_name Cockpit
extends Node2D
## First-person cockpit drawn in code INSIDE the low-res view (pixel art at
## the game's pixel size):
##  canopy  - thick dark-grey frame with highlights and rivets, top bar with an
##            orange indicator, side pillars in perspective
##  dash    - glare shield with a warning-light row, big attitude ball in a
##            metal bezel, round needle gauges both sides, status lamps and a
##            control stick that moves with the input
##  HUD     - bright green: pitch ladder rolling with the jet, big speed and
##            altitude numbers over tapes, heading scale, gun reticle, yellow
##            target/lead markers, red lock circle

var game: Node
var size := Vector2(748, 336)
var alpha := 0.0

const HUD := Color("5dff7a")
const HUD_DIM := Color(0.36, 1.0, 0.48, 0.55)
const YEL := Color("ffd84a")
const RED := Color("ff3b30")
const ORANGE := Color("f0580e")
const ORANGE_L := Color("ff9a4a")
const SKY := Color("4a9ff0")
const SKY_D := Color("2f7fd4")
const GROUND := Color("9a6232")
const GROUND_D := Color("7a4a22")
const F0 := Color("1c1e25") # darkest metal / outlines
const F1 := Color("33363f")
const F2 := Color("4a4e59")
const F3 := Color("6c7180")
const F4 := Color("9aa0ad") # highlights
const RIV := Color("b4b9c4")

## 3x5 pixel font
const GLYPHS := {
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7], "3": [7, 1, 7, 1, 7],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7], "6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 2, 2],
	"8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 7], "N": [7, 5, 5, 5, 5], "E": [7, 4, 6, 4, 7],
	"S": [7, 4, 7, 1, 7], "W": [5, 5, 7, 7, 5], "A": [7, 5, 7, 5, 5], "L": [4, 4, 4, 4, 7],
	"T": [7, 2, 2, 2, 2], "P": [7, 5, 7, 4, 4], "D": [6, 5, 5, 5, 6], "M": [5, 7, 7, 5, 5],
	"O": [7, 5, 5, 5, 7], "H": [5, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "R": [6, 5, 6, 5, 5],
	"X": [5, 5, 2, 5, 5], "G": [7, 4, 5, 5, 7], "C": [7, 4, 4, 4, 7], "I": [7, 2, 2, 2, 7],
	"Y": [5, 5, 7, 2, 2], "K": [5, 5, 6, 5, 5], "U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2],
	"-": [0, 0, 7, 0, 0], ".": [0, 0, 0, 0, 2], " ": [0, 0, 0, 0, 0], "!": [2, 2, 2, 0, 2],
}


## Pixel text; sc = pixel size of a glyph pixel (1 or 2).
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
	var dash_top := floorf(h * 0.64)
	var c := Vector2(floorf(w * 0.5), floorf(dash_top * 0.5) + 6)
	_hud(jet, c, w, h, dash_top)
	_canopy(w, h, dash_top)
	_dash(jet, w, h, dash_top)


# ------------------------------------------------------------------ HUD

func _hud(jet: Jet, c: Vector2, w: float, h: float, dash_top: float) -> void:
	var roll := jet.roll + jet.roll_extra
	var pitch_deg := rad_to_deg(wrapf(jet.pitch, -PI, PI))
	var px_per_deg := dash_top / 55.0
	var right := Vector2(cos(roll), sin(roll))
	var down := Vector2(-sin(roll), cos(roll))
	# pitch ladder
	for k in range(-9, 10):
		var deg := k * 10
		var off := (pitch_deg - deg) * px_per_deg
		if absf(off) > dash_top * 0.36:
			continue
		var mid := c + down * off
		var half := 34.0 if deg != 0 else 96.0
		var gap := 14.0
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
			ptext(mid + right * (half + 8.0) - Vector2(0, 2), str(absi(deg)), col, true)
	# gun reticle: cross + square brackets
	draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), HUD, 1.0)
	draw_line(c + Vector2(0, -5), c + Vector2(0, 5), HUD, 1.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * 16.0, sy * 16.0)
			draw_line(p, p - Vector2(sx * 6.0, 0), HUD, 1.0)
			draw_line(p, p - Vector2(0, sy * 6.0), HUD, 1.0)
	# target markers (yellow) + lead marker + red lock circle
	var m: Missiles = game.missiles
	var tgts: Array = []
	for e0 in game.enemies.pool:
		if e0.active:
			tgts.append(e0)
	for pl in game.fleet.planes:
		if pl.alive and pl.team != jet.team:
			tgts.append(pl)
	for e in tgts:
		var ep: Vector3 = Missiles.tpos(e)
		if game.cam.is_position_behind(ep):
			continue
		var sp: Vector2 = game.cam.unproject_position(ep).round()
		if sp.y > dash_top - 4 or sp.y < 14:
			continue
		var is_lock: bool = e == m.lock_target
		if not is_lock:
			draw_line(sp + Vector2(0, -6), sp + Vector2(6, 0), YEL, 1.0)
			draw_line(sp + Vector2(6, 0), sp + Vector2(0, 6), YEL, 1.0)
			draw_line(sp + Vector2(0, 6), sp + Vector2(-6, 0), YEL, 1.0)
			draw_line(sp + Vector2(-6, 0), sp + Vector2(0, -6), YEL, 1.0)
	var lpos: Vector3 = Missiles.tpos(m.lock_target)
	if lpos != Vector3.INF and not game.cam.is_position_behind(lpos):
		var tp: Vector2 = game.cam.unproject_position(lpos).round()
		var k := clampf(m.lock_t / Missiles.LOCK_TIME, 0.0, 1.0)
		var rr := lerpf(34.0, 12.0, k)
		draw_arc(tp, rr, 0, TAU, 28, RED if m.locked else YEL, 1.0)
		# lead marker: where to point the nose for the cannon
		var e = m.lock_target
		var dist: float = jet.position.distance_to(lpos)
		var lead: Vector3 = lpos + Vector3(-sin(e.yaw), 0, -cos(e.yaw)) * e.speed * dist / 600.0
		if not game.cam.is_position_behind(lead):
			var lp: Vector2 = game.cam.unproject_position(lead).round()
			draw_arc(lp, 4.0, 0, TAU, 10, YEL, 1.0)
			draw_line(tp, lp, Color(YEL.r, YEL.g, YEL.b, 0.4), 1.0)
		if m.locked:
			ptext(tp + Vector2(0, rr + 4), "LOCK", RED, true)
	# speed (left) and altitude (right): big numbers above tapes
	var tape_h := floorf(dash_top * 0.46)
	var ty := c.y - tape_h * 0.5
	_tape(floorf(w * 0.2), ty, tape_h, jet.speed * 3.6, 10.0, 1.0, false)
	_tape(floorf(w * 0.8), ty, tape_h, jet.position.y, 20.0, 0.5, true)
	ptext(Vector2(floorf(w * 0.2), ty - 16), str(int(jet.speed * 3.6)), HUD, true, 2)
	ptext(Vector2(floorf(w * 0.8), ty - 16), str(int(jet.position.y)), HUD, true, 2)
	# heading scale with number (bottom of the glass)
	var hdg := fposmod(rad_to_deg(-jet.yaw), 360.0)
	var hy := floorf(dash_top - 26)
	draw_line(Vector2(c.x - 90, hy), Vector2(c.x + 90, hy), HUD, 1.0)
	for d in range(-50, 51, 5):
		var a := roundi(hdg / 5.0) * 5 + d
		var x := roundf(c.x + (a - hdg) * 1.8)
		if absf(x - c.x) > 90.0:
			continue
		draw_line(Vector2(x, hy), Vector2(x, hy - (5.0 if posmod(a, 10) == 0 else 2.0)), HUD, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, hy + 2), Vector2(c.x - 4, hy + 7), Vector2(c.x + 4, hy + 7)]), HUD)
	ptext(Vector2(c.x, hy - 18), "%03d" % int(hdg), HUD, true, 2)
	if jet.multiplier > 1:
		ptext(Vector2(c.x, c.y + 26), "LOW X%d" % jet.multiplier, YEL, true)
	if m.counter_t > 0.0:
		ptext(Vector2(c.x, c.y - 30), "COUNTER", RED, true)


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


func _canopy(w: float, h: float, dash_top: float) -> void:
	# top bar
	draw_rect(Rect2(0, 0, w, 12), F1)
	draw_rect(Rect2(0, 12, w, 2), F2)
	draw_rect(Rect2(0, 14, w, 1), F0)
	draw_rect(Rect2(0, 1, w, 1), F3)
	_rivets(Vector2(0, 6), Vector2(w, 6), int(w / 14))
	# central housing with orange indicator
	var cw := floorf(w * 0.24)
	var cx := floorf(w * 0.5 - cw * 0.5)
	var pts := PackedVector2Array([Vector2(cx - 14, 0), Vector2(cx + cw + 14, 0), Vector2(cx + cw + 4, 26), Vector2(cx - 4, 26)])
	draw_colored_polygon(pts, F1)
	draw_polyline(PackedVector2Array([Vector2(cx - 4, 26), Vector2(cx + cw + 4, 26)]), F0, 1.0)
	draw_line(Vector2(cx - 13, 1), Vector2(cx - 4, 25), F3, 1.0)
	draw_line(Vector2(cx + cw + 13, 1), Vector2(cx + cw + 4, 25), F0, 1.0)
	draw_rect(Rect2(cx + 8, 8, cw - 16, 9), F0)
	draw_rect(Rect2(cx + 9, 9, cw - 18, 7), ORANGE)
	draw_rect(Rect2(cx + 9, 9, cw - 18, 2), ORANGE_L)
	# side pillars in perspective (thick, highlighted, riveted)
	for side in [0, 1]:
		var sx := 1.0 if side == 0 else -1.0
		var x0 := 0.0 if side == 0 else w
		var top_in := x0 + sx * w * 0.13
		var bot_in := x0 + sx * w * 0.035
		var outer := PackedVector2Array([Vector2(x0, 0), Vector2(top_in, 0), Vector2(bot_in, dash_top), Vector2(x0, dash_top)])
		draw_colored_polygon(outer, F1)
		# bevel highlight on the inner edge
		draw_line(Vector2(top_in, 0), Vector2(bot_in, dash_top), F0, 1.0)
		draw_line(Vector2(top_in - sx * 2, 0), Vector2(bot_in - sx * 2, dash_top), F3, 1.0)
		draw_line(Vector2(top_in - sx * 4, 0), Vector2(bot_in - sx * 4, dash_top), F2, 1.0)
		_rivets(Vector2(top_in - sx * 8, 18), Vector2(bot_in - sx * 8, dash_top - 6), 12)
		# small mirror-like bracket
		draw_rect(Rect2(Vector2(top_in - sx * 22 - (14 if side == 1 else 0), 18), Vector2(14, 6)), F0)


# ------------------------------------------------------------------ dashboard

func _dash(jet: Jet, w: float, h: float, top: float) -> void:
	# glare shield
	var gs := PackedVector2Array([Vector2(0, top + 6), Vector2(w * 0.14, top), Vector2(w * 0.86, top), Vector2(w, top + 6), Vector2(w, top + 22), Vector2(0, top + 22)])
	draw_colored_polygon(gs, F0)
	draw_line(Vector2(0, top + 6), Vector2(w * 0.14, top), F3, 1.0)
	draw_line(Vector2(w * 0.14, top), Vector2(w * 0.86, top), F3, 1.0)
	draw_line(Vector2(w * 0.86, top), Vector2(w, top + 6), F3, 1.0)
	# warning lights row
	var m: Missiles = game.missiles
	var warn := [jet.health < 40.0, m.incoming_t < 3.0, jet.reloading > 0.0 or m.reload > 0.0, jet.boosting, jet.position.y < CityGen.LOW_ALT]
	var lw := 18.0
	var lx := floorf(w * 0.5 - warn.size() * (lw + 3) * 0.5)
	var blink := int(Time.get_ticks_msec() / 180) % 2 == 0
	for i in warn.size():
		var on: bool = warn[i]
		var col := Color("5a2410")
		if on:
			col = RED if (i <= 1 and blink) else ORANGE
		draw_rect(Rect2(lx + i * (lw + 3) - 1, top + 9, lw + 2, 8), F0)
		draw_rect(Rect2(lx + i * (lw + 3), top + 10, lw, 6), col)
		if on:
			draw_rect(Rect2(lx + i * (lw + 3), top + 10, lw, 1), ORANGE_L)
	# panel body with a little texture
	var py := top + 22
	draw_rect(Rect2(0, py, w, h - py), F1)
	draw_line(Vector2(0, py), Vector2(w, py), F2, 1.0)
	for i in 60:
		var hx := CityGen.hashf(i, 3, 77) * w
		var hy := py + CityGen.hashf(i, 5, 77) * (h - py)
		draw_rect(Rect2(floorf(hx), floorf(hy), 1, 1), F2 if i % 2 == 0 else F0)
	var panel_h := h - py
	var cy := floorf(py + panel_h * 0.46)
	var r := floorf(minf(panel_h * 0.42, 52.0))
	# big attitude ball in a metal bezel
	var bc := Vector2(floorf(w * 0.5), cy)
	draw_circle(bc, r + 7, F0)
	draw_circle(bc, r + 6, F4)
	draw_circle(bc, r + 4, F3)
	draw_circle(bc, r + 2, F0)
	_attitude(jet, bc, r)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		draw_rect(Rect2((bc + Vector2(cos(a), sin(a)) * (r + 5)).round() - Vector2(1, 1), Vector2(3, 3)), YEL)
	draw_colored_polygon(PackedVector2Array([bc + Vector2(-4, -r - 6), bc + Vector2(4, -r - 6), bc + Vector2(0, -r)]), YEL)
	# round gauges either side, kept inside the area free of touch buttons
	var gr := floorf(r * 0.5)
	var gl := floorf(w * 0.5 - r - gr - 28)
	var grx := floorf(w * 0.5 + r + gr + 28)
	_gauge(Vector2(gl, cy - gr * 0.55), gr, jet.speed / (jet.boost_speed() * 1.05), ORANGE)
	_gauge(Vector2(gl - gr * 2 - 10, cy + gr * 0.3), gr, jet.boost_energy / 100.0, ORANGE)
	_gauge(Vector2(grx, cy - gr * 0.55), gr, jet.position.y / 1000.0, ORANGE)
	_gauge(Vector2(grx + gr * 2 + 10, cy + gr * 0.3), gr, jet.health / jet.max_health, RED if jet.health < 35.0 else ORANGE)
	# status lamps under the gauges (gun / missiles)
	_lamps(Vector2(gl - 10, cy + gr + 6), [jet.ammo > 0.0 and jet.reloading <= 0.0, game.missiles_left() > 0])
	_lamps(Vector2(grx - 10, cy + gr + 6), [m.locked, m.counter_t > 0.0])
	# control stick, moves with the input
	_stick(Vector2(floorf(w * 0.5), h), r)


func _gauge(c: Vector2, r: float, frac: float, needle: Color) -> void:
	draw_circle(c, r + 3, F0)
	draw_circle(c, r + 2, F3)
	draw_circle(c, r, Color("15161b"))
	for k in 11:
		var a := lerpf(PI * 0.75, PI * 2.25, k / 10.0)
		var o := c + Vector2(cos(a), sin(a)) * (r - 1)
		var i := c + Vector2(cos(a), sin(a)) * (r - (3.0 if k % 5 == 0 else 2.0))
		draw_line(i.round(), o.round(), F4 if k % 5 == 0 else F3, 1.0)
	var na := lerpf(PI * 0.75, PI * 2.25, clampf(frac, 0.0, 1.0))
	draw_line(c, (c + Vector2(cos(na), sin(na)) * (r - 3)).round(), needle, 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), F4)


func _lamps(p: Vector2, states: Array) -> void:
	for i in states.size():
		var on: bool = states[i]
		draw_rect(Rect2(p + Vector2(i * 12, 0), Vector2(10, 6)), F0)
		draw_rect(Rect2(p + Vector2(i * 12 + 1, 1), Vector2(8, 4)), ORANGE if on else F2)


func _attitude(jet: Jet, c: Vector2, r: float) -> void:
	var roll := jet.roll + jet.roll_extra
	var n := Vector2(-sin(roll), cos(roll))
	var off := rad_to_deg(wrapf(jet.pitch, -PI, PI)) * r / 45.0
	for yy in range(int(-r), int(r) + 1):
		var half := sqrt(maxf(0.0, r * r - yy * yy))
		var y := c.y + yy
		var a := Vector2(c.x - half, y)
		var b := Vector2(c.x + half, y)
		var da := n.dot(a - c) - off
		var db := n.dot(b - c) - off
		var sky := SKY if yy % 4 != 0 else SKY_D
		var gnd := GROUND if yy % 4 != 0 else GROUND_D
		if da <= 0.0 and db <= 0.0:
			draw_line(a, b, sky, 1.0)
		elif da > 0.0 and db > 0.0:
			draw_line(a, b, gnd, 1.0)
		else:
			var t := da / (da - db)
			var mm := a.lerp(b, t)
			draw_line(a, mm, sky if da <= 0.0 else gnd, 1.0)
			draw_line(mm, b, gnd if da <= 0.0 else sky, 1.0)
	# horizon + pitch marks on the ball
	var tang := Vector2(n.y, -n.x)
	var hz := c + n * off
	draw_line(hz - tang * r * 0.95, hz + tang * r * 0.95, Color.WHITE, 1.0)
	for k in [-2, -1, 1, 2]:
		var p: Vector2 = hz - n * (k * r * 0.22)
		if p.distance_to(c) < r - 3:
			draw_line(p - tang * r * 0.18, p + tang * r * 0.18, Color(1, 1, 1, 0.8), 1.0)
	# fixed aircraft symbol
	draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(-6, 0), YEL, 2.0)
	draw_line(c + Vector2(6, 0), c + Vector2(r * 0.55, 0), YEL, 2.0)
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), YEL)


func _stick(base: Vector2, r: float) -> void:
	var st: Vector2 = game.controls.stick
	var len := minf(r * 0.42, 22.0)
	var knob := base + Vector2(st.x * 10.0, -len + st.y * 6.0)
	# boot
	draw_rect(Rect2(base.x - 14, base.y - 8, 28, 8), F0)
	draw_rect(Rect2(base.x - 12, base.y - 7, 24, 6), F2)
	# ribbed shaft
	var segs := 6
	for i in segs:
		var p := base.lerp(knob, (i + 0.5) / segs)
		draw_rect(Rect2(p - Vector2(4, 2), Vector2(8, 4)), F0)
		draw_rect(Rect2(p - Vector2(3, 1), Vector2(6, 2)), F3 if i % 2 == 0 else F2)
	# grip with buttons
	draw_rect(Rect2(knob - Vector2(9, 12), Vector2(18, 16)), F0)
	draw_rect(Rect2(knob - Vector2(8, 11), Vector2(16, 14)), F2)
	draw_rect(Rect2(knob - Vector2(8, 11), Vector2(16, 2)), F3)
	draw_circle(knob + Vector2(4, -6), 3.0, ORANGE if game.controls.fire else Color("8a2a10"))
	draw_circle(knob + Vector2(-4, -6), 2.0, F4 if game.controls.boost else F3)
