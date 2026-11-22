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
	var c := Vector2(floorf(w * 0.5), floorf(h * 0.42))
	_draw_hud(jet, c, w, h)
	_draw_canopy(w, h)
	_draw_dash(jet, w, h)


func _draw_hud(jet: Jet, c: Vector2, w: float, h: float) -> void:
	var px_per_deg := h / 76.0
	var roll := jet.roll
	var pitch_deg := rad_to_deg(jet.pitch)
	var right := Vector2(cos(roll), sin(roll))
	var down := Vector2(-sin(roll), cos(roll))
	# pitch ladder every 10 degrees
	for k in range(-6, 7):
		var deg := k * 10
		var off := (pitch_deg - deg) * px_per_deg
		if absf(off) > h * 0.3:
			continue
		var mid := c + down * off
		var half := 26.0 if deg != 0 else 60.0
		var gap := 8.0
		var col := HUD if deg >= 0 else HUD_DIM
		draw_line((mid - right * half).round(), (mid - right * gap).round(), col, 1.0)
		draw_line((mid + right * gap).round(), (mid + right * half).round(), col, 1.0)
		if deg != 0:
			ptext(mid + right * (half + 4) - Vector2(0, 2), str(absi(deg)), col)
	# boresight
	draw_line(c + Vector2(-6, 0), c + Vector2(-2, 0), HUD, 1.0)
	draw_line(c + Vector2(2, 0), c + Vector2(6, 0), HUD, 1.0)
	draw_line(c + Vector2(0, 2), c + Vector2(0, 4), HUD, 1.0)
	draw_arc(c, 10.0, 0, TAU, 20, HUD_DIM, 1.0)
	# heading tape
	var hdg := fposmod(rad_to_deg(-jet.yaw), 360.0)
	var ty := floorf(h * 0.1)
	draw_line(Vector2(c.x - 70, ty + 8), Vector2(c.x + 70, ty + 8), HUD_DIM, 1.0)
	for d in range(-40, 41, 5):
		var a := roundi(hdg / 5.0) * 5 + d
		var x := c.x + (a - hdg) * 1.7
		if absf(x - c.x) > 70.0:
			continue
		var tick := 4.0 if posmod(a, 10) == 0 else 2.0
		draw_line(Vector2(roundf(x), ty + 8), Vector2(roundf(x), ty + 8 - tick), HUD, 1.0)
		if posmod(a, 30) == 0:
			var lbl := str(posmod(a, 360) / 10)
			match posmod(a, 360):
				0:
					lbl = "N"
				90:
					lbl = "E"
				180:
					lbl = "S"
				270:
					lbl = "W"
			ptext(Vector2(x, ty - 2), lbl, HUD, true)
	draw_rect(Rect2(c.x - 9, ty + 10, 19, 7), Color(0, 0, 0, 0.35))
	ptext(Vector2(c.x, ty + 11), "%03d" % int(hdg), HUD, true)
	# speed / altitude boxes
	ptext(Vector2(c.x - 110, c.y - 2), "%d" % int(jet.speed * 3.6), HUD)
	ptext(Vector2(c.x + 96, c.y - 2), "%d" % int(jet.position.y), HUD)
	ptext(Vector2(c.x - 110, c.y + 6), "KMH", HUD_DIM)
	ptext(Vector2(c.x + 96, c.y + 6), "ALT", HUD_DIM)
	if jet.multiplier > 1:
		ptext(Vector2(c.x, c.y + 40), "LOW X%d" % jet.multiplier, AMBER, true)


func _draw_canopy(w: float, h: float) -> void:
	# top bow + side struts
	draw_rect(Rect2(0, 0, w, 6), FRAME)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.2, 0), Vector2(w * 0.08, h * 0.25), Vector2(0, h * 0.45)]), FRAME)
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w * 0.8, 0), Vector2(w * 0.92, h * 0.25), Vector2(w, h * 0.45)]), FRAME)
	draw_line(Vector2(w * 0.2, 0), Vector2(w * 0.08, h * 0.25), FRAME_HI, 1.0)
	draw_line(Vector2(w * 0.8, 0), Vector2(w * 0.92, h * 0.25), FRAME_HI, 1.0)
	draw_rect(Rect2(w * 0.5 - 3, 0, 6, 9), FRAME)
	# side rails down to the dash
	draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.45), Vector2(w * 0.08, h * 0.25), Vector2(w * 0.1, h * 0.7), Vector2(0, h * 0.75)]), FRAME)
	draw_colored_polygon(PackedVector2Array([Vector2(w, h * 0.45), Vector2(w * 0.92, h * 0.25), Vector2(w * 0.9, h * 0.7), Vector2(w, h * 0.75)]), FRAME)


func _draw_dash(jet: Jet, w: float, h: float) -> void:
	var top := floorf(h * 0.7)
	# glare shield + panel
	var pts := PackedVector2Array([Vector2(0, top + 8), Vector2(w * 0.25, top), Vector2(w * 0.75, top), Vector2(w, top + 8), Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(pts, DASH)
	draw_polyline(PackedVector2Array([Vector2(0, top + 8), Vector2(w * 0.25, top), Vector2(w * 0.75, top), Vector2(w, top + 8)]), DASH_HI, 1.0)
	var panel_h := h - top
	var cy := floorf(top + panel_h * 0.55)
	var r := floorf(minf(panel_h * 0.38, 34.0))
	_radar(jet, Vector2(floorf(w * 0.3), cy), r)
	_attitude(jet, Vector2(floorf(w * 0.5), cy), r)
	_gauges(jet, Vector2(floorf(w * 0.7), cy), r)


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
