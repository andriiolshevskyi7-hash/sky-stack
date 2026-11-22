class_name Cockpit
extends Node2D
## First-person cockpit drawn in code INSIDE the low-res view (so it is pixel
## art like the world): canopy frame, green HUD (boresight, pitch ladder,
## heading tape), dashboard with radar (enemies), attitude indicator and
## speed / altitude / ammo / boost / health gauges.

var game: Node
var size := Vector2(640, 336)
var alpha := 0.0

const FRAME := Color("1a1c2c")
const FRAME_HI := Color("3b4a74")
const DASH := Color("2a2f3e")
const DASH_HI := Color("4a5064")
const HUD := Color(0.45, 1.0, 0.55)
const HUD_DIM := Color(0.45, 1.0, 0.55, 0.55)
const SKY := Color("4d9be6")
const GROUND := Color("8a5a3c")
const RED := Color("ff5050")
const AMBER := Color("ffb43c")

## 3x5 pixel font (digits, a few letters, symbols)
const GLYPHS := {
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7], "3": [7, 1, 7, 1, 7],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7], "6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 2, 2],
	"8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 7], "N": [7, 5, 5, 5, 5], "E": [7, 4, 6, 4, 7],
	"S": [7, 4, 7, 1, 7], "W": [5, 5, 7, 7, 5], "A": [7, 5, 7, 5, 5], "L": [4, 4, 4, 4, 7],
	"T": [7, 2, 2, 2, 2], "P": [7, 5, 7, 4, 4], "D": [6, 5, 5, 5, 6], "M": [5, 7, 7, 5, 5],
	"O": [7, 5, 5, 5, 7], "H": [5, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "R": [6, 5, 6, 5, 5],
	"X": [5, 5, 2, 5, 5], "G": [7, 4, 5, 5, 7], "C": [7, 4, 4, 4, 7], "I": [7, 2, 2, 2, 7],
	"Y": [5, 5, 7, 2, 2], "K": [5, 5, 6, 5, 5], "-": [0, 0, 7, 0, 0], ".": [0, 0, 0, 0, 2],
	" ": [0, 0, 0, 0, 0],
}


func ptext(pos: Vector2, t: String, col: Color, center: bool = false) -> void:
	var x := pos.x - (t.length() * 4 - 1) * 0.5 if center else pos.x
	x = floorf(x)
	for i in t.length():
		var g: Array = GLYPHS.get(t[i], GLYPHS[" "])
		for row in 5:
			var bits: int = g[row]
			for b in 3:
				if bits & (4 >> b):
					draw_rect(Rect2(x + i * 4 + b, floorf(pos.y) + row, 1, 1), col)


func _process(_d: float) -> void:
	visible = alpha > 0.02
	if visible:
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	modulate.a = alpha
	var jet: Jet = game.jet
	var w := size.x
	var h := size.y
	var c := Vector2(floorf(w * 0.5), floorf(h * 0.4))
	_draw_hud(jet, c, w, h)
	_draw_canopy(w, h)
	_draw_dash(jet, w, h)


func _tape(x: float, y0: float, hgt: float, value: float, step: float, px_per_unit: float, right_side: bool, label: String) -> void:
	# vertical tape with ticks and a boxed readout
	var cy := y0 + hgt * 0.5
	draw_line(Vector2(x, y0), Vector2(x, y0 + hgt), HUD_DIM, 1.0)
	var first := floorf((value - hgt * 0.5 / px_per_unit) / step) * step
	var v := first
	while v <= value + hgt * 0.5 / px_per_unit:
		var y := roundf(cy - (v - value) * px_per_unit)
		if y >= y0 and y <= y0 + hgt:
			var major := is_zero_approx(fmod(absf(v), step * 5.0))
			var tl := 5.0 if major else 2.0
			draw_line(Vector2(x, y), Vector2(x + (tl if right_side else -tl), y), HUD, 1.0)
		v += step
	var bx := x + (3.0 if right_side else -27.0)
	draw_rect(Rect2(bx, cy - 4, 24, 9), Color(0, 0.1, 0, 0.55))
	draw_rect(Rect2(bx, cy - 4, 24, 9), HUD, false, 1.0)
	ptext(Vector2(bx + 12, cy - 2), str(int(value)), HUD, true)
	ptext(Vector2(x + (4.0 if right_side else -24.0), y0 - 8), label, HUD_DIM)


func _draw_hud(jet: Jet, c: Vector2, w: float, h: float) -> void:
	var px_per_deg := h / 70.0
	var roll := jet.roll + jet.roll_extra
	var pitch_deg := rad_to_deg(wrapf(jet.pitch, -PI, PI))
	var right := Vector2(cos(roll), sin(roll))
	var down := Vector2(-sin(roll), cos(roll))
	# pitch ladder: solid above the horizon, dashed below, bracket ends
	for k in range(-9, 10):
		var deg := k * 10
		var off := (pitch_deg - deg) * px_per_deg
		if absf(off) > h * 0.26:
			continue
		var mid := c + down * off
		var half := 30.0 if deg != 0 else 80.0
		var gap := 12.0
		var col := HUD if deg >= 0 else HUD_DIM
		if deg < 0:
			for side in [-1.0, 1.0]:
				var t := gap
				while t < half:
					draw_line((mid + right * side * t).round(), (mid + right * side * minf(t + 3.0, half)).round(), col, 1.0)
					t += 6.0
		else:
			draw_line((mid - right * half).round(), (mid - right * gap).round(), col, 1.0)
			draw_line((mid + right * gap).round(), (mid + right * half).round(), col, 1.0)
		if deg != 0:
			var tip := down * (3.0 if deg > 0 else -3.0)
			draw_line((mid - right * half).round(), (mid - right * half + tip).round(), col, 1.0)
			draw_line((mid + right * half).round(), (mid + right * half + tip).round(), col, 1.0)
			ptext(mid + right * (half + 5) - Vector2(0, 2), str(absi(deg)), col)
	# gun reticle: cross + corner brackets
	draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), HUD, 1.0)
	draw_line(c + Vector2(0, -4), c + Vector2(0, 4), HUD, 1.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * 14.0, sy * 14.0)
			draw_line(p, p - Vector2(sx * 5.0, 0), HUD, 1.0)
			draw_line(p, p - Vector2(0, sy * 5.0), HUD, 1.0)
	# lock-on circle around the target
	var m: Missiles = game.missiles
	if m.lock_target != null and m.lock_target.active and not game.cam.is_position_behind(m.lock_target.pos):
		var tp: Vector2 = game.cam.unproject_position(m.lock_target.pos)
		var k2 := clampf(m.lock_t / Missiles.LOCK_TIME, 0.0, 1.0)
		var rr := lerpf(26.0, 10.0, k2)
		draw_arc(tp.round(), rr, 0, TAU, 24, RED if m.locked else Color(1, 0.85, 0.3), 1.0)
		if m.locked:
			ptext(tp + Vector2(0, rr + 3), "LOCK", RED, true)
	# speed + altitude tapes
	_tape(floorf(w * 0.17), c.y - 50, 100, jet.speed * 3.6, 10.0, 1.2, false, "SPD")
	_tape(floorf(w * 0.83), c.y - 50, 100, jet.position.y, 10.0, 1.0, true, "ALT")
	# heading scale (bottom of the HUD glass)
	var hdg := fposmod(rad_to_deg(-jet.yaw), 360.0)
	var ty := floorf(h * 0.55)
	draw_line(Vector2(c.x - 80, ty), Vector2(c.x + 80, ty), HUD_DIM, 1.0)
	for d in range(-45, 46, 5):
		var a := roundi(hdg / 5.0) * 5 + d
		var x := c.x + (a - hdg) * 1.7
		if absf(x - c.x) > 80.0:
			continue
		var tick := 4.0 if posmod(a, 10) == 0 else 2.0
		draw_line(Vector2(roundf(x), ty), Vector2(roundf(x), ty - tick), HUD, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, ty + 1), Vector2(c.x - 3, ty + 5), Vector2(c.x + 3, ty + 5)]), HUD)
	ptext(Vector2(c.x, ty - 12), "%03d" % int(hdg), HUD, true)
	if jet.multiplier > 1:
		ptext(Vector2(c.x, c.y + 30), "LOW X%d" % jet.multiplier, AMBER, true)
	if m.counter_t > 0.0:
		ptext(Vector2(c.x, c.y - 34), "COUNTER", RED, true)


const METAL := Color("4a4f5c")
const METAL_D := Color("2b2e37")
const METAL_L := Color("6d7386")
const RIVET := Color("8b8d96")


func _rivets(a: Vector2, b: Vector2, n: int) -> void:
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n).round()
		draw_rect(Rect2(p, Vector2(1, 1)), RIVET)


func _draw_canopy(w: float, h: float) -> void:
	# top bow with mirror
	draw_rect(Rect2(0, 0, w, 9), METAL_D)
	draw_rect(Rect2(0, 9, w, 2), METAL)
	_rivets(Vector2(0, 5), Vector2(w, 5), 40)
	var mw := floorf(w * 0.2)
	var mx := floorf(w * 0.5 - mw * 0.5)
	draw_colored_polygon(PackedVector2Array([Vector2(mx - 10, 0), Vector2(mx + mw + 10, 0), Vector2(mx + mw, 22), Vector2(mx, 22)]), METAL_D)
	draw_rect(Rect2(mx + 4, 6, mw - 8, 10), Color("f0580e"))
	draw_rect(Rect2(mx + 4, 6, mw - 8, 3), Color("ffb06a"))
	# side frames
	for side in [0, 1]:
		var x0 := 0.0 if side == 0 else w
		var dir := 1.0 if side == 0 else -1.0
		var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + dir * w * 0.17, 0), Vector2(x0 + dir * w * 0.05, h * 0.3), Vector2(x0 + dir * w * 0.035, h * 0.72), Vector2(x0, h * 0.72)])
		draw_colored_polygon(pts, METAL_D)
		draw_line(Vector2(x0 + dir * w * 0.17, 0), Vector2(x0 + dir * w * 0.05, h * 0.3), METAL_L, 1.0)
		draw_line(Vector2(x0 + dir * w * 0.05, h * 0.3), Vector2(x0 + dir * w * 0.035, h * 0.72), METAL_L, 1.0)
		_rivets(Vector2(x0 + dir * w * 0.13, 3), Vector2(x0 + dir * w * 0.035, h * 0.3), 9)
		_rivets(Vector2(x0 + dir * w * 0.025, h * 0.33), Vector2(x0 + dir * w * 0.02, h * 0.7), 8)


func _draw_dash(jet: Jet, w: float, h: float) -> void:
	var top := floorf(h * 0.6)
	# glare shield
	var pts := PackedVector2Array([Vector2(0, top + 10), Vector2(w * 0.18, top), Vector2(w * 0.82, top), Vector2(w, top + 10), Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(pts, METAL_D)
	draw_rect(Rect2(w * 0.18, top, w * 0.64, 7), Color("1d1f27"))
	draw_line(Vector2(0, top + 10), Vector2(w * 0.18, top), METAL_L, 1.0)
	draw_line(Vector2(w * 0.18, top), Vector2(w * 0.82, top), METAL_L, 1.0)
	draw_line(Vector2(w * 0.82, top), Vector2(w, top + 10), METAL_L, 1.0)
	# warning lights
	var m: Missiles = game.missiles
	var warn := [
		jet.health < 40.0,
		m.incoming_t < 2.0,
		jet.reloading > 0.0 or m.reload > 0.0,
		jet.boosting,
		jet.position.y < CityGen.LOW_ALT,
	]
	var lw := 14.0
	var lx := floorf(w * 0.5 - warn.size() * (lw + 3) * 0.5)
	for i in warn.size():
		var on: bool = warn[i]
		var blink: bool = on and (i == 1 or i == 0) and int(Time.get_ticks_msec() / 200) % 2 == 0
		var col := Color("ff3b2e") if blink else (Color("f0580e") if on else Color("5a2a1a"))
		draw_rect(Rect2(lx + i * (lw + 3), top + 12, lw, 5), col)
	# instrument panel
	draw_rect(Rect2(0, top + 20, w, h - top - 20), METAL)
	draw_line(Vector2(0, top + 20), Vector2(w, top + 20), METAL_L, 1.0)
	var panel_h := h - top - 20
	var cy := floorf(top + 20 + panel_h * 0.4)
	var r := floorf(minf(panel_h * 0.33, 44.0))
	# big attitude ball with bezel
	draw_circle(Vector2(w * 0.5, cy), r + 5, Color("8b8d96"))
	draw_circle(Vector2(w * 0.5, cy), r + 3, METAL_D)
	_attitude(jet, Vector2(floorf(w * 0.5), cy), r)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		draw_rect(Rect2((Vector2(w * 0.5, cy) + Vector2(cos(a), sin(a)) * (r + 4)).round() - Vector2(1, 1), Vector2(2, 2)), Color("ffb43c"))
	# side gauges
	var gr := floorf(r * 0.5)
	_dial(Vector2(floorf(w * 0.2), cy - gr * 0.8), gr, jet.speed / 200.0, "SPD", AMBER)
	_dial(Vector2(floorf(w * 0.2), cy + gr * 1.6), gr, jet.boost_energy / 100.0, "THR", AMBER)
	_dial(Vector2(floorf(w * 0.8), cy - gr * 0.8), gr, jet.position.y / 400.0, "ALT", HUD)
	_dial(Vector2(floorf(w * 0.8), cy + gr * 1.6), gr, jet.health / jet.max_health, "HUL", HUD if jet.health > 35.0 else RED)
	_radar(jet, Vector2(floorf(w * 0.33), cy), floorf(r * 0.6))
	var bx := floorf(w * 0.64)
	var bh := r * 1.3
	_bar(Vector2(bx, cy - bh * 0.5), bh, jet.ammo / Jet.MAX_AMMO, Color("ffe066"), "GN")
	_bar(Vector2(bx + 12, cy - bh * 0.5), bh, float(game.missiles_left()) / maxf(1.0, game.missiles_max()), Color("f4f4f4"), "MS")
	# control stick, moves with the input
	var st: Vector2 = game.controls.stick
	var base := Vector2(floorf(w * 0.5), h - 2)
	var knob := base + Vector2(st.x * 10.0, -18.0 + st.y * 4.0)
	draw_rect(Rect2(base.x - 10, h - 8, 20, 8), METAL_D)
	draw_line(base, knob, Color("1d1f27"), 4.0)
	draw_line(base, knob, METAL_L, 2.0)
	draw_rect(Rect2(knob - Vector2(5, 6), Vector2(10, 10)), Color("1d1f27"))
	draw_rect(Rect2(knob - Vector2(4, 5), Vector2(8, 8)), METAL)
	draw_rect(Rect2(knob + Vector2(1, -4), Vector2(3, 3)), Color("f0580e") if game.controls.fire else Color("8a2a10"))


func _radar(jet: Jet, c: Vector2, r: float) -> void:
	draw_circle(c, r + 2, Color("0a0a14"))
	draw_circle(c, r, Color("0d2a18"))
	draw_arc(c, r * 0.5, 0, TAU, 20, Color(0.3, 0.8, 0.4, 0.35), 1.0)
	draw_arc(c, r, 0, TAU, 28, Color(0.3, 0.8, 0.4, 0.6), 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0.3, 0.8, 0.4, 0.25), 1.0)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0.3, 0.8, 0.4, 0.25), 1.0)
	var sweep := fmod(Time.get_ticks_msec() * 0.003, TAU)
	draw_line(c, c + Vector2(cos(sweep), sin(sweep)) * r, Color(0.4, 1.0, 0.5, 0.5), 1.0)
	var range_w := 700.0
	var cy := cos(jet.yaw)
	var sy := sin(jet.yaw)
	for e in game.enemies.pool:
		if not e.active:
			continue
		var d := Vector2(e.pos.x - jet.position.x, e.pos.z - jet.position.z)
		# rotate so the jet's heading points up
		var l := Vector2(cy * d.x - sy * d.y, sy * d.x + cy * d.y) / range_w * r
		if l.length() > r - 1.0:
			l = l.normalized() * (r - 1.0)
		var col := AMBER if e.type == 3 else RED
		draw_rect(Rect2((c + l).round() - Vector2(1, 1), Vector2(2, 2)), col)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
	ptext(c + Vector2(0, r + 4), "RDR", HUD_DIM, true)


func _attitude(jet: Jet, c: Vector2, r: float) -> void:
	draw_circle(c, r + 2, Color("0a0a14"))
	var roll := jet.roll
	var n := Vector2(-sin(roll), cos(roll)) # "down" normal of the horizon line
	var off := rad_to_deg(jet.pitch) * r / 45.0
	for yy in range(int(-r), int(r) + 1):
		var half := sqrt(maxf(0.0, r * r - yy * yy))
		var y := c.y + yy
		var a := Vector2(c.x - half, y)
		var b := Vector2(c.x + half, y)
		# split the row where n.(p - c) = off
		var da := n.dot(a - c) - off
		var db := n.dot(b - c) - off
		if da <= 0.0 and db <= 0.0:
			draw_line(a, b, SKY, 1.0)
		elif da > 0.0 and db > 0.0:
			draw_line(a, b, GROUND, 1.0)
		else:
			var t := da / (da - db)
			var m := a.lerp(b, t)
			draw_line(a, m, SKY if da <= 0.0 else GROUND, 1.0)
			draw_line(m, b, GROUND if da <= 0.0 else SKY, 1.0)
	var hz := c + n * off
	var tang := Vector2(n.y, -n.x)
	draw_line(hz - tang * r * 0.9, hz + tang * r * 0.9, Color.WHITE, 1.0)
	draw_line(c + Vector2(-10, 0), c + Vector2(-3, 0), AMBER, 1.0)
	draw_line(c + Vector2(3, 0), c + Vector2(10, 0), AMBER, 1.0)
	draw_rect(Rect2(c - Vector2(0, 0), Vector2(1, 1)), AMBER)
	ptext(c + Vector2(0, r + 4), "ATT", HUD_DIM, true)


func _dial(c: Vector2, r: float, frac: float, label: String, col: Color) -> void:
	draw_circle(c, r + 1, Color("0a0a14"))
	draw_circle(c, r, Color("1f2433"))
	for k in 9:
		var a := lerpf(PI * 0.75, PI * 2.25, k / 8.0)
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 2), c + Vector2(cos(a), sin(a)) * r, Color(1, 1, 1, 0.5), 1.0)
	var na := lerpf(PI * 0.75, PI * 2.25, clampf(frac, 0.0, 1.0))
	draw_line(c, (c + Vector2(cos(na), sin(na)) * (r - 2)).round(), col, 1.0)
	ptext(c + Vector2(0, r + 3), label, HUD_DIM, true)


func _bar(pos: Vector2, hgt: float, frac: float, col: Color, label: String) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(6, hgt + 2)), Color("0a0a14"))
	var fh := floorf(hgt * clampf(frac, 0.0, 1.0))
	draw_rect(Rect2(pos + Vector2(0, hgt - fh), Vector2(4, fh)), col)
	ptext(pos + Vector2(2, hgt + 3), label, HUD_DIM, true)


func _gauges(jet: Jet, c: Vector2, r: float) -> void:
	var dr := floorf(r * 0.55)
	_dial(c + Vector2(-dr - 2, -dr * 0.4), dr, jet.speed / 200.0, "SPD", AMBER)
	_dial(c + Vector2(dr + 2, -dr * 0.4), dr, jet.position.y / Jet.MAX_ALT, "ALT", HUD)
	var bx := c.x + dr * 2 + 12
	var hgt := r * 1.4
	_bar(Vector2(bx, c.y - hgt * 0.5), hgt, jet.ammo / Jet.MAX_AMMO, Color("ffe066"), "AM")
	_bar(Vector2(bx + 12, c.y - hgt * 0.5), hgt, jet.boost_energy / 100.0, AMBER, "BO")
	_bar(Vector2(bx + 24, c.y - hgt * 0.5), hgt, jet.health / jet.max_health, Color("6fae4a") if jet.health > 35.0 else RED, "HP")
