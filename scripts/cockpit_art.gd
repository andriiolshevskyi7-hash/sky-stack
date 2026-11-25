class_name CockpitArt
extends Node2D
## Pixel-art textures of the 3D cockpit, drawn into one 512x512 canvas
## (a SubViewport) that the cockpit meshes sample. Two layers:
##  STATIC  (redrawn when the plane or the light changes): instrument panel
##          with display bezels and soft keys, switch clusters, knobs, labels,
##          striped handles, side consoles, tub walls, canopy rail, frame
##          metal, glareshield, flight suit, seat, kneeboard, stick grip
##  DYNAMIC (every frame): the displays - radar with contacts, colour
##          attitude, moving map, engine page, panoramic page - the keypad
##          with lit keys and read-outs, the warning-light strip
## At night the paint is dark, labels glow green / amber, displays stay bright.

enum { STATIC, DYNAMIC }
const SIZE := Vector2i(512, 512)
const R := {
	"panel": Rect2(0, 0, 304, 112),
	"dl": Rect2(0, 112, 104, 80), "dr": Rect2(104, 112, 104, 80), "dc": Rect2(208, 112, 72, 56),
	"dp": Rect2(0, 192, 280, 64),
	"ufc": Rect2(304, 0, 80, 48), "warn": Rect2(304, 48, 80, 8),
	"wall": Rect2(304, 56, 80, 80), "metal": Rect2(304, 136, 32, 32), "glare": Rect2(336, 136, 32, 32),
	"stick": Rect2(368, 136, 16, 32), "frame": Rect2(304, 168, 80, 16),
	"cons_l": Rect2(384, 0, 128, 160), "cons_r": Rect2(384, 160, 128, 160),
	"sill": Rect2(0, 256, 256, 16), "knee": Rect2(0, 272, 256, 48),
	"suit": Rect2(256, 256, 64, 64), "seat": Rect2(320, 256, 64, 96), "thr": Rect2(384, 320, 32, 32),
	"board": Rect2(416, 320, 48, 64), "glass": Rect2(464, 320, 16, 16),
}
## Display slots on the panel texture per class (panel pixels).
const SLOTS := {
	"l": Rect2(12, 24, 104, 80), "r": Rect2(188, 24, 104, 80), "c": Rect2(116, 34, 72, 56), "p": Rect2(12, 26, 280, 64),
}

const SKY := Color("4fa3ee")
const GROUND := Color("9a6232")
const SCREEN := Color("050907")
const YEL := Color("ffd84a")
const RED := Color("ff3b30")
const ORANGE := Color("f0580e")
const STRIPE := Color("e8c030")

var mode := STATIC
var owner3d: Node # Cockpit3D
var _map_cache: Array = []
var _map_t := 0.0


func _process(_d: float) -> void:
	if mode == DYNAMIC and owner3d != null and owner3d.active:
		queue_redraw()


func _draw() -> void:
	if owner3d == null or owner3d.pc.is_empty() or owner3d.cls < 0:
		return
	if mode == STATIC:
		_draw_static()
	else:
		_draw_dynamic()


# ------------------------------------------------------------------ helpers

func c(i: int) -> Color:
	return owner3d.pc[i]


func a(i: int) -> Color:
	return owner3d.ac[i]


func night() -> float:
	return owner3d.night_q


## Label colour: light paint by day, glowing green / amber at night.
func label() -> Color:
	var day := Color(0.86, 0.88, 0.9) if owner3d.cls != Planes.LIGHT else Color(0.12, 0.13, 0.15)
	return day.lerp(owner3d.glow, smoothstep(0.3, 0.7, night()))


func txt(p: Vector2, t: String, col: Color, center: bool = false) -> void:
	PixFont.draw(self, p, t, col, center)


func h01(i: int, j: int, s: int) -> float:
	return CityGen.hashf(i, j, s)


## Small hardware: toggle, knob, push button, lamp, guarded switch.
func toggle(p: Vector2, up: bool) -> void:
	draw_rect(Rect2(p, Vector2(4, 6)), c(0))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 4)), c(2))
	draw_rect(Rect2(p + Vector2(1, 0 if up else 4), Vector2(2, 2)), c(4))


func knob(p: Vector2, r: float = 2.5) -> void:
	draw_circle(p, r + 1.0, c(0))
	draw_circle(p, r, c(3))
	draw_rect(Rect2(p + Vector2(-0.5, -r), Vector2(1, r)), c(0))


func lamp(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(4, 4)), c(0))
	draw_rect(Rect2(p, Vector2(2, 2)), col)


func guard(p: Vector2) -> void:
	var k := lerpf(1.0, 0.55, night())
	draw_rect(Rect2(p, Vector2(7, 9)), c(0))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(5, 7)), Color("8a1a10") * k)
	for i in 3:
		draw_line(p + Vector2(1, 3 + i * 3), p + Vector2(5, 1 + i * 3), STRIPE * k, 1.0)


func striped(r: Rect2) -> void:
	var k := lerpf(1.0, 0.55, night())
	draw_rect(r, Color(0.1, 0.1, 0.1))
	var x := r.position.x - r.size.y
	while x < r.end.x:
		for i in int(r.size.y):
			var xx := x + i
			if xx >= r.position.x and xx < r.end.x - 1:
				draw_rect(Rect2(xx, r.position.y + r.size.y - 1 - i, 2, 1), STRIPE * k)
		x += 5


func screws(r: Rect2) -> void:
	for p in [r.position + Vector2(1, 1), Vector2(r.end.x - 3, r.position.y + 1), Vector2(r.position.x + 1, r.end.y - 3), r.end - Vector2(3, 3)]:
		draw_rect(Rect2(p, Vector2(2, 2)), c(4))
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), c(0))


## A switch panel (sub-plate) full of hardware, deterministic per salt.
func plate(r: Rect2, salt: int, rows: int = -1) -> void:
	draw_rect(r, c(0))
	draw_rect(r.grow(-1), c(2))
	draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 2, r.position.y + 1), c(3), 1.0)
	screws(r.grow(-1))
	var n := rows if rows > 0 else maxi(1, int((r.size.y - 4) / 11))
	for row in n:
		var y := r.position.y + 4 + row * 11
		if y + 9 > r.end.y:
			break
		var x := r.position.x + 5
		var k := 0
		while x < r.end.x - 7:
			var hsh := h01(k, row, salt)
			if hsh < 0.38:
				toggle(Vector2(x, y + 1), hsh < 0.2)
				x += 6
			elif hsh < 0.62:
				knob(Vector2(x + 3, y + 4))
				x += 8
			elif hsh < 0.8:
				lamp(Vector2(x + 1, y + 3), owner3d.glow if hsh < 0.72 else Color("ffb030"))
				x += 6
			elif hsh < 0.9:
				guard(Vector2(x, y))
				x += 9
			else:
				draw_rect(Rect2(x, y + 1, 7, 6), c(0))
				draw_rect(Rect2(x + 1, y + 2, 5, 4), c(3))
				x += 9
			k += 1
		# a label under the row
		if h01(row, salt, 5) < 0.7 and y + 10 < r.end.y:
			var labels := ["ARM", "MODE", "FUEL", "NAV", "ECM", "TACAN", "IFF", "RDR", "AUTO", "MAN", "ENG", "HYD", "OXY", "CMDS"]
			txt(Vector2(r.position.x + 5 + int(h01(row, salt, 7) * 12), y + 9), labels[int(h01(row, salt, 9) * labels.size()) % labels.size()], label())


## Display bezel (screen hole is drawn by the display quad) with soft keys.
func bezel(r: Rect2) -> void:
	draw_rect(r.grow(5), c(0))
	draw_rect(r.grow(4), c(2))
	draw_line(r.grow(4).position, Vector2(r.grow(4).end.x, r.grow(4).position.y), c(3), 1.0)
	draw_rect(r.grow(1), Color(0.02, 0.02, 0.02))
	var nx := maxi(3, int(r.size.x / 16))
	for k in nx:
		var x := r.position.x + (k + 0.5) * r.size.x / nx
		draw_rect(Rect2(x - 3, r.position.y - 4, 6, 3), c(0))
		draw_rect(Rect2(x - 3, r.end.y + 1, 6, 3), c(0))
		draw_rect(Rect2(x - 2, r.position.y - 4, 4, 1), c(3))
		draw_rect(Rect2(x - 2, r.end.y + 1, 4, 1), c(3))
	var ny := maxi(2, int(r.size.y / 16))
	for k in ny:
		var y := r.position.y + (k + 0.5) * r.size.y / ny
		draw_rect(Rect2(r.position.x - 4, y - 2, 3, 5), c(0))
		draw_rect(Rect2(r.end.x + 1, y - 2, 3, 5), c(0))
	screws(r.grow(4))


# ------------------------------------------------------------------ static

func _draw_static() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Color(0, 0, 0, 0))
	_panel()
	_knee()
	_console(R["cons_l"], true)
	_console(R["cons_r"], false)
	_wall()
	_tile(R["metal"], a(1), a(2), true)
	_tile(R["frame"], c(2), c(3), false)
	_glare()
	_sill()
	_suit()
	_seat()
	_thr()
	_board()
	_stick()
	draw_rect(R["glass"], Color(1, 1, 1))


func _panel() -> void:
	var r: Rect2 = R["panel"]
	draw_rect(r, c(1))
	# shadow under the glareshield
	for i in 8:
		draw_rect(Rect2(r.position.x, r.position.y + i, r.size.x, 1), c(0).lerp(c(1), i / 8.0))
	# panel seams
	for x in [r.position.x + 104 + 8, r.position.x + 192 - 8]:
		draw_line(Vector2(x, 10), Vector2(x, r.end.y), c(0), 1.0)
	var cls: int = owner3d.cls
	var tier: int = owner3d.tier
	var slots: Array = owner3d.slots
	for s: String in slots:
		bezel(SLOTS[s])
	# switch clusters between / around the displays
	if not slots.has("p"):
		plate(Rect2(116, 94, 72, 18), 11 + cls, 1)
	else:
		plate(Rect2(12, 96, 130, 16), 21 + cls, 1)
		plate(Rect2(162, 96, 130, 16), 23 + cls, 1)
	plate(Rect2(0, 10, 10, 100), 31 + cls)
	plate(Rect2(294, 10, 10, 100), 33 + cls)
	if not slots.has("c") and not slots.has("p"):
		plate(Rect2(116, 34, 72, 56), 41 + cls)
	# striped emergency handles, a small standby compass
	striped(Rect2(2, 2, 22, 6))
	striped(Rect2(280, 2, 22, 6))
	if cls == Planes.ATTACK:
		striped(Rect2(126, 104, 52, 6))
	txt(Vector2(14, 15), "MFD", label())
	txt(Vector2(188, 15), "MFD", label())
	if tier >= 3:
		txt(Vector2(244, 15), "DATA", label())


func _knee() -> void:
	var r: Rect2 = R["knee"]
	draw_rect(r, c(1))
	plate(Rect2(r.position + Vector2(4, 4), Vector2(118, 40)), 51 + owner3d.cls)
	plate(Rect2(r.position + Vector2(134, 4), Vector2(118, 40)), 53 + owner3d.cls)


## Side console seen from above: u across (inner -> outer), v along (front
## -> back). Left: throttle quadrant; right: a small display and keypads.
func _console(r: Rect2, left: bool) -> void:
	draw_rect(r, c(0))
	var y := r.position.y + 2
	var k := 0
	while y < r.end.y - 10:
		var hh := 18 + int(h01(k, 3 if left else 4, 77) * 16)
		hh = mini(hh, int(r.end.y - y - 2))
		var pr := Rect2(r.position.x + 2, y, r.size.x - 4, hh)
		if left and k == 1:
			# throttle quadrant: slot with detents (the lever is 3D)
			draw_rect(pr, c(1))
			draw_rect(Rect2(pr.position.x + 40, pr.position.y + 3, 6, pr.size.y - 6), Color(0.02, 0.02, 0.02))
			for d in 4:
				draw_rect(Rect2(pr.position.x + 36, pr.position.y + 5 + d * (pr.size.y - 10) / 3.0, 14, 1), c(3))
			txt(Vector2(pr.position.x + 52, pr.position.y + 4), "AB", Color("ffb030"))
			txt(Vector2(pr.position.x + 52, pr.end.y - 8), "OFF", label())
			plate(Rect2(pr.position.x + 64, pr.position.y + 2, pr.size.x - 66, pr.size.y - 4), 61)
		elif not left and k == 2:
			draw_rect(pr, c(1))
			var sr := Rect2(pr.position.x + 6, pr.position.y + 3, 40, pr.size.y - 6)
			draw_rect(sr.grow(2), c(0))
			draw_rect(sr, Color("0a1410"))
			for i in 4:
				txt(sr.position + Vector2(2, 2 + i * 7), ["COM1", "243", "UHF", "PRST"][i], owner3d.glow * Color(1, 1, 1, 0.9))
			plate(Rect2(pr.position.x + 52, pr.position.y + 2, pr.size.x - 54, pr.size.y - 4), 62)
		else:
			plate(pr, 70 + k + (0 if left else 20))
		y += hh + 2
		k += 1
	if left:
		striped(Rect2(r.end.x - 14, r.position.y + 4, 10, 30))


func _wall() -> void:
	var r: Rect2 = R["wall"]
	draw_rect(r, c(0))
	for x in range(int(r.position.x), int(r.end.x), 16):
		draw_rect(Rect2(x, r.position.y, 3, r.size.y), c(1))
		draw_rect(Rect2(x, r.position.y, 1, r.size.y), c(2))
		for y in range(int(r.position.y) + 3, int(r.end.y), 7):
			draw_rect(Rect2(x + 1, y, 1, 1), c(3))
	# cable bundle and a pipe
	draw_line(Vector2(r.position.x, r.position.y + 50), Vector2(r.end.x, r.position.y + 46), Color(0.15, 0.13, 0.1), 3.0)
	draw_line(Vector2(r.position.x, r.position.y + 62), Vector2(r.end.x, r.position.y + 62), c(3), 2.0)


func _tile(r: Rect2, base: Color, hi: Color, rivets: bool) -> void:
	draw_rect(r, base)
	draw_line(r.position, Vector2(r.end.x, r.position.y), hi, 1.0)
	if rivets:
		for x in range(int(r.position.x) + 3, int(r.end.x), 6):
			draw_rect(Rect2(x, r.get_center().y, 1, 1), hi.lightened(0.2))
	for i in 20:
		var p := r.position + Vector2(h01(i, int(r.position.x), 3) * r.size.x, h01(i, int(r.position.y), 4) * r.size.y)
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), base.darkened(0.2) if i % 2 == 0 else base.lightened(0.08))


func _glare() -> void:
	var r: Rect2 = R["glare"]
	draw_rect(r, a(0))
	for i in 40:
		var p := r.position + Vector2(h01(i, 1, 13) * r.size.x, h01(i, 2, 13) * r.size.y)
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), a(0).lightened(0.06))


func _sill() -> void:
	var r: Rect2 = R["sill"]
	draw_rect(r, a(1))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), a(2))
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), a(0))
	for x in range(int(r.position.x) + 4, int(r.end.x), 10):
		draw_rect(Rect2(x, r.position.y + 6, 2, 2), a(2).lightened(0.15))
		draw_rect(Rect2(x + 1, r.position.y + 7, 1, 1), a(0))
	# canopy seal
	draw_line(Vector2(r.position.x, r.position.y + 3), Vector2(r.end.x, r.position.y + 3), Color(0.08, 0.08, 0.08), 1.0)


func _suit() -> void:
	var r: Rect2 = R["suit"]
	var s: Color = owner3d.suit
	draw_rect(r, s)
	# folds (diagonal creases), seams, a thigh pocket with zip, knee pad
	for i in 7:
		var y := r.position.y + 4 + i * 9
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + 18, y + 5), s.darkened(0.22), 1.0)
		draw_line(Vector2(r.end.x - 20, y + 3), Vector2(r.end.x, y - 2), s.lightened(0.1), 1.0)
	draw_line(Vector2(r.position.x + 32, r.position.y), Vector2(r.position.x + 32, r.end.y), s.darkened(0.3), 1.0)
	var pk := Rect2(r.position + Vector2(8, 34), Vector2(20, 18))
	draw_rect(pk, s.darkened(0.1))
	draw_rect(Rect2(pk.position, Vector2(pk.size.x, 2)), s.darkened(0.35))
	draw_line(pk.position + Vector2(10, 2), pk.position + Vector2(10, 16), Color(0.75, 0.75, 0.7), 1.0)
	draw_rect(Rect2(r.position + Vector2(36, 6), Vector2(22, 18)), s.darkened(0.3))
	draw_rect(Rect2(r.position + Vector2(36, 12), Vector2(22, 3)), Color(0.12, 0.12, 0.12))


func _seat() -> void:
	var r: Rect2 = R["seat"]
	draw_rect(r, c(0))
	var cu := Rect2(r.position + Vector2(4, 14), Vector2(56, 76))
	draw_rect(cu, owner3d.suit.darkened(0.45))
	for i in range(1, 4):
		draw_line(Vector2(cu.position.x, cu.position.y + i * 19), Vector2(cu.end.x, cu.position.y + i * 19), owner3d.suit.darkened(0.6), 1.0)
	draw_rect(Rect2(r.position + Vector2(16, 2), Vector2(32, 10)), Color(0.1, 0.1, 0.1))
	for i in 7:
		draw_rect(Rect2(r.position.x + 17 + i * 4, r.position.y + 3, 2, 8), STRIPE)


func _thr() -> void:
	var r: Rect2 = R["thr"]
	draw_rect(r, a(0))
	draw_rect(r.grow(-2), a(1))
	draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(5, 5)), Color("8a2a10"))
	draw_rect(Rect2(r.position + Vector2(18, 8), Vector2(6, 4)), c(3))
	draw_rect(Rect2(r.position + Vector2(8, 18), Vector2(14, 3)), c(2))


func _board() -> void:
	var r: Rect2 = R["board"]
	draw_rect(r, Color(0.88, 0.87, 0.8) * lerpf(1.0, 0.5, night()))
	for i in 8:
		draw_line(Vector2(r.position.x + 4, r.position.y + 12 + i * 6), Vector2(r.end.x - 4 - (i % 3) * 6, r.position.y + 12 + i * 6), Color(0.4, 0.42, 0.5), 1.0)
	draw_rect(Rect2(r.position + Vector2(14, 0), Vector2(20, 6)), Color(0.55, 0.56, 0.6))


func _stick() -> void:
	var r: Rect2 = R["stick"]
	draw_rect(r, Color(0.07, 0.07, 0.08))
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(12, 3)), Color(0.18, 0.18, 0.2))
	draw_rect(Rect2(r.position + Vector2(3, 8), Vector2(4, 5)), Color("b02418"))
	draw_rect(Rect2(r.position + Vector2(9, 6), Vector2(4, 4)), Color(0.3, 0.3, 0.32))
	for y in range(int(r.position.y) + 16, int(r.end.y), 3):
		draw_line(Vector2(r.position.x + 1, y), Vector2(r.end.x - 1, y), Color(0.12, 0.12, 0.13), 1.0)


# ------------------------------------------------------------------ dynamic

func _draw_dynamic() -> void:
	var g: Node = owner3d.game
	if g == null or g.jet == null:
		return
	var jet: Jet = g.jet
	var cls: int = owner3d.cls
	var tier: int = owner3d.tier
	var slots: Array = owner3d.slots
	if slots.has("p"):
		_panoramic(jet, R["dp"])
	if slots.has("l"):
		if cls == Planes.ATTACK:
			_map(jet, R["dl"])
		elif cls == Planes.LIGHT and tier == 1:
			_cluster(jet, R["dl"])
		else:
			_radar(jet, R["dl"])
	if slots.has("r"):
		if cls == Planes.ATTACK and tier <= 2:
			_cluster(jet, R["dr"])
		elif cls == Planes.ATTACK:
			_radar(jet, R["dr"])
		else:
			_engine(jet, R["dr"])
	if slots.has("c"):
		if cls == Planes.ATTACK:
			_standby(jet, R["dc"])
		else:
			_adi(jet, R["dc"], true)
	_ufc(jet, R["ufc"])
	_warn(jet, R["warn"])


func hud() -> Color:
	return owner3d.glow


func _screen(r: Rect2) -> void:
	draw_rect(r, SCREEN)
	# page title strip + soft-key labels along the top
	draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), Color(0.06, 0.12, 0.09))


func _radar(jet: Jet, r: Rect2) -> void:
	_screen(r)
	var g := hud()
	var labels := ["RWS", "RNG", "TWS", "40"]
	for i in labels.size():
		PixFont.draw(self, r.position + Vector2(2 + i * r.size.x / 4.0, 1), labels[i], g * Color(1, 1, 1, 0.8))
	var cc := Vector2(floorf(r.get_center().x), floorf(r.end.y - 4))
	var rad := minf(r.size.y - 14, r.size.x * 0.5 - 4)
	var dim := Color(g.r, g.g, g.b, 0.35)
	for k in [0.25, 0.5, 0.75, 1.0]:
		draw_arc(cc, rad * k, PI * 1.17, PI * 1.83, 18, dim, 1.0)
	for k in [-1.0, 0.0, 1.0]:
		var an: float = -PI * 0.5 + k * PI * 0.33
		draw_line(cc, cc + Vector2(cos(an), sin(an)) * rad, dim, 1.0)
	var sw := PI * 1.17 + fmod(Time.get_ticks_msec() / 1000.0 * 1.3, 1.0) * PI * 0.66
	draw_line(cc, (cc + Vector2(cos(sw), sin(sw)) * rad).round(), Color(g.r, g.g, g.b, 0.8), 1.0)
	var fwd := Vector2(-sin(jet.yaw), -cos(jet.yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var game: Node = owner3d.game
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
		var p := Vector2(d.dot(right), -d.dot(fwd)) / 2400.0 * rad
		if p.y > 0.0 or p.length() > rad:
			continue
		var col := YEL
		if "team" in e and e.team == jet.team:
			col = Color(0.4, 0.9, 1.0)
		if e == lt:
			col = RED
			draw_rect(Rect2((cc + p).round() - Vector2(3, 3), Vector2(7, 6)), col, false, 1.0)
		draw_rect(Rect2((cc + p).round() - Vector2(1, 1), Vector2(3, 2)), col)
	draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -3), cc + Vector2(-3, 1), cc + Vector2(3, 1)]), g)


## Colour attitude display: sky / ground, pitch lines, roll scale, speed and
## altitude tapes, heading at the bottom.
func _adi(jet: Jet, r: Rect2, tapes: bool) -> void:
	_screen(r)
	var cc := r.get_center().floor() + Vector2(0, 3)
	var wide := tapes and r.size.x > 60
	var inner := Rect2(r.position + Vector2(14 if wide else 2, 8), Vector2(r.size.x - (28 if wide else 4), r.size.y - 16))
	var roll := jet.roll + jet.roll_extra
	var n := Vector2(-sin(roll), cos(roll))
	var tang := Vector2(n.y, -n.x)
	var ppd := inner.size.y / 50.0
	var off := rad_to_deg(wrapf(jet.pitch, -PI, PI)) * ppd
	for yy in range(int(inner.position.y), int(inner.end.y)):
		var aa := Vector2(inner.position.x, yy)
		var bb := Vector2(inner.end.x, yy)
		var da := n.dot(aa - cc) - off
		var db := n.dot(bb - cc) - off
		var sc := SKY if yy % 3 != 0 else SKY.darkened(0.08)
		var gc := GROUND if yy % 3 != 0 else GROUND.darkened(0.1)
		if da <= 0.0 and db <= 0.0:
			draw_line(aa, bb, sc, 1.0)
		elif da > 0.0 and db > 0.0:
			draw_line(aa, bb, gc, 1.0)
		else:
			var t := da / (da - db)
			var mm := aa.lerp(bb, t)
			draw_line(aa, mm, sc if da <= 0.0 else gc, 1.0)
			draw_line(mm, bb, gc if da <= 0.0 else sc, 1.0)
	var hz := cc + n * off
	for k in range(-3, 4):
		var p: Vector2 = hz - n * (k * 10.0 * ppd)
		if inner.grow(-2).has_point(p):
			var half := inner.size.x * (0.4 if k == 0 else 0.14)
			draw_line((p - tang * half).round(), (p + tang * half).round(), Color(1, 1, 1, 0.9 if k == 0 else 0.7), 1.0)
	# aircraft symbol
	draw_line(cc + Vector2(-12, 0), cc + Vector2(-4, 0), YEL, 1.0)
	draw_line(cc + Vector2(4, 0), cc + Vector2(12, 0), YEL, 1.0)
	draw_rect(Rect2(cc - Vector2(1, 1), Vector2(2, 2)), YEL)
	# roll pointer on top
	var rp := cc + Vector2(sin(roll), -cos(roll)) * (inner.size.y * 0.45)
	draw_colored_polygon(PackedVector2Array([rp, rp + Vector2(-2, -3), rp + Vector2(2, -3)]), Color.WHITE)
	if wide:
		draw_rect(Rect2(r.position.x, cc.y - 4, 14, 8), Color.BLACK)
		PixFont.draw(self, Vector2(r.position.x + 1, cc.y - 2), str(int(jet.speed * 3.6)).left(3), Color.WHITE)
		draw_rect(Rect2(r.end.x - 14, cc.y - 4, 14, 8), Color.BLACK)
		PixFont.draw(self, Vector2(r.end.x - 13, cc.y - 2), str(int(jet.position.y / 10.0)).left(3), Color.WHITE)
	PixFont.draw(self, Vector2(cc.x, r.end.y - 7), "%03d" % int(fposmod(rad_to_deg(-jet.yaw), 360.0)), Color.WHITE, true)
	PixFont.draw(self, r.position + Vector2(2, 1), "ADI", hud())


## Engine page: bars, two round dials, digits, engine icon.
func _engine(jet: Jet, r: Rect2) -> void:
	_screen(r)
	var g := hud()
	PixFont.draw(self, r.position + Vector2(2, 1), "ENG", g)
	PixFont.draw(self, r.position + Vector2(r.size.x - 22, 1), "FUEL", g * Color(1, 1, 1, 0.7))
	var bh := r.size.y - 22
	var vals := [jet.throttle, jet.heat / 100.0, clampf(jet.speed / jet.boost_speed(), 0.0, 1.0)]
	var names := ["THR", "EGT", "N2"]
	for k in 3:
		var x := r.position.x + 4 + k * 13
		draw_rect(Rect2(x, r.position.y + 10, 8, bh), Color(g.r, g.g, g.b, 0.12))
		var col: Color = g
		if k == 1:
			col = RED if jet.overheated else (ORANGE if vals[k] > 0.6 else g)
		elif k == 0 and jet.boosting:
			col = ORANGE
		var fh := floorf(bh * clampf(vals[k], 0.0, 1.0))
		draw_rect(Rect2(x, r.position.y + 10 + bh - fh, 8, fh), col)
		PixFont.draw(self, Vector2(x - 1, r.end.y - 9), names[k].left(2), g * Color(1, 1, 1, 0.7))
	for k in 2:
		var dc := Vector2(r.end.x - 18, r.position.y + 22 + k * 26)
		draw_arc(dc, 10.0, PI * 0.75, PI * 2.25, 16, Color(1, 1, 1, 0.5), 1.0)
		draw_arc(dc, 10.0, PI * 2.0, PI * 2.25, 4, RED, 1.0)
		var v2: float = [jet.throttle, clampf(jet.g_load / 9.0, 0.0, 1.0)][k]
		var an := lerpf(PI * 0.75, PI * 2.25, v2)
		draw_line(dc, (dc + Vector2(cos(an), sin(an)) * 9.0).round(), YEL, 1.0)
		PixFont.draw(self, dc + Vector2(-7, 4), ["RPM", "G"][k], Color(1, 1, 1, 0.7))
	PixFont.draw(self, Vector2(r.position.x + 44, r.position.y + 12), "%d" % int(jet.speed * 3.6), Color.WHITE)
	PixFont.draw(self, Vector2(r.position.x + 44, r.position.y + 20), "%.1f" % jet.g_load, Color.WHITE)
	PixFont.draw(self, Vector2(r.position.x + 44, r.position.y + 28), "AB" if jet.boosting else "MIL", ORANGE if jet.boosting else g)
	PixFont.draw(self, Vector2(r.position.x + 44, r.position.y + 40), "%d" % int(jet.health / jet.max_health * 100.0), RED if jet.health < jet.max_health * 0.4 else g)


## Moving map: terrain colours (sea, land, forest, city, rock) sampled from
## the world, grid, bases, contacts, own arrow; refreshed 4x per second.
func _map(jet: Jet, r: Rect2) -> void:
	_screen(r)
	var cell := 4
	var cols := int(r.size.x / cell)
	var rows := int((r.size.y - 8) / cell)
	var span := 5200.0
	var sc := r.size.x / span
	_map_t -= get_process_delta_time()
	if _map_t <= 0.0 or _map_cache.size() != cols * rows:
		_map_t = 0.25
		_map_cache.resize(cols * rows)
		for j in rows:
			for i in cols:
				var wx := jet.position.x + (i + 0.5 - cols * 0.5) * cell / sc
				var wz := jet.position.z + (j + 0.5 - rows * 0.5) * cell / sc
				var col := Color("1d4f8a")
				if not CityGen.is_water(wx, wz):
					col = Color("4f7a3a")
					if CityGen.relief_hw(wx, wz) > 60.0:
						col = Color("8a6a46")
					elif CityGen.city_val(wx, wz) > 0.5:
						col = Color("8a8a86")
					elif CityGen.forest_v(wx, wz) > 0.5:
						col = Color("335a2c")
				_map_cache[j * cols + i] = col
	var top := r.position.y + 8
	for j in rows:
		for i in cols:
			draw_rect(Rect2(r.position.x + i * cell, top + j * cell, cell, cell), _map_cache[j * cols + i])
	var cc := Vector2(r.get_center().x, top + rows * cell * 0.5).floor()
	var game: Node = owner3d.game
	if game.bases != null and "centers" in game.bases:
		for bc in game.bases.centers:
			var p := cc + Vector2(bc.x - jet.position.x, bc.z - jet.position.z) * sc
			if r.grow(-3).has_point(p):
				draw_rect(Rect2(p.round() - Vector2(3, 3), Vector2(7, 7)), YEL, false, 1.0)
	for pl in game.fleet.planes:
		if not pl.alive or pl == jet:
			continue
		var p := cc + Vector2(pl.position.x - jet.position.x, pl.position.z - jet.position.z) * sc
		if r.grow(-3).has_point(p):
			draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 3)), Color(0.4, 0.9, 1.0) if pl.team == jet.team else RED)
	var fw := Vector2(-sin(jet.yaw), -cos(jet.yaw))
	var rt := Vector2(-fw.y, fw.x)
	draw_colored_polygon(PackedVector2Array([cc + fw * 6.0, cc - fw * 3.0 + rt * 4.0, cc - fw * 3.0 - rt * 4.0]), Color.WHITE)
	PixFont.draw(self, r.position + Vector2(2, 1), "MAP  N", hud())


## Analog cluster: four round gauges on a dark face (older planes).
func _cluster(jet: Jet, r: Rect2) -> void:
	draw_rect(r, Color(0.08, 0.08, 0.09))
	var gr := floorf(minf(r.size.x, r.size.y) * 0.25 - 2)
	var vals := [jet.speed / (jet.boost_speed() * 1.05), jet.position.y / 1000.0, jet.throttle, jet.health / jet.max_health]
	var names := ["KMH", "ALT", "RPM", "HYD"]
	for k in 4:
		var gc := (r.position + Vector2(r.size.x * (0.26 + 0.48 * (k % 2)), r.size.y * (0.27 + 0.48 * (k / 2)))).floor()
		_gauge(gc, gr, vals[k])
		PixFont.draw(self, gc + Vector2(0, gr * 0.35), names[k], Color(0.85, 0.85, 0.8), true)


func _standby(jet: Jet, r: Rect2) -> void:
	draw_rect(r, Color(0.08, 0.08, 0.09))
	var gr := floorf(r.size.y * 0.3)
	_gauge(Vector2(r.position.x + gr + 3, r.position.y + gr + 4), gr, jet.speed / (jet.boost_speed() * 1.05))
	_gauge(Vector2(r.end.x - gr - 3, r.position.y + gr + 4), gr, jet.position.y / 1000.0)
	var mini := Rect2(r.position + Vector2(r.size.x * 0.5 - 12, r.size.y * 0.55), Vector2(24, 20))
	_adi(jet, mini, false)


func _gauge(cc: Vector2, rr: float, frac: float) -> void:
	draw_circle(cc, rr + 2, Color(0.02, 0.02, 0.02))
	draw_circle(cc, rr + 1, c(3))
	draw_circle(cc, rr, Color("111216"))
	for k in 9:
		var an := lerpf(PI * 0.75, PI * 2.25, k / 8.0)
		var o := cc + Vector2(cos(an), sin(an)) * (rr - 1)
		var i := cc + Vector2(cos(an), sin(an)) * (rr - (3.0 if k % 4 == 0 else 2.0))
		draw_line(i.round(), o.round(), Color(0.9, 0.9, 0.88) if k % 4 == 0 else Color(0.55, 0.55, 0.55), 1.0)
	draw_arc(cc, rr - 1, PI * 2.0, PI * 2.25, 4, Color("c02a18"), 1.0)
	var na := lerpf(PI * 0.75, PI * 2.25, clampf(frac, 0.0, 1.0))
	draw_line(cc, (cc + Vector2(cos(na), sin(na)) * (rr - 2)).round(), Color("ff9a3a"), 1.0)
	draw_rect(Rect2(cc - Vector2(1, 1), Vector2(2, 2)), Color(0.7, 0.7, 0.7))


func _panoramic(jet: Jet, r: Rect2) -> void:
	_screen(r)
	var third := floorf(r.size.x / 3.0)
	_adi(jet, Rect2(r.position + Vector2(1, 0), Vector2(third - 2, r.size.y)), true)
	_radar(jet, Rect2(r.position + Vector2(third + 1, 0), Vector2(third - 2, r.size.y)))
	_engine(jet, Rect2(r.position + Vector2(third * 2 + 1, 0), Vector2(third - 2, r.size.y)))
	for k in 2:
		draw_line(Vector2(r.position.x + third * (k + 1), r.position.y), Vector2(r.position.x + third * (k + 1), r.end.y), Color(0.3, 0.35, 0.3), 1.0)


## Up-front control: two read-outs over a keypad with lit keys.
func _ufc(jet: Jet, r: Rect2) -> void:
	draw_rect(r, c(1))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c(3))
	var g := hud()
	var ro := Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8, 9))
	draw_rect(ro, Color(0.02, 0.05, 0.03))
	PixFont.draw(self, ro.position + Vector2(2, 2), "%03d" % int(fposmod(rad_to_deg(-jet.yaw), 360.0)), g)
	PixFont.draw(self, Vector2(ro.end.x - 24, ro.position.y + 2), "%d" % int(jet.position.y), g)
	var keys := ["1", "2", "3", "A", "4", "5", "6", "B", "7", "8", "9", "C", "-", "0", ".", "E"]
	var kw := (r.size.x - 8) / 4.0
	var lit := lerpf(0.75, 1.0, night())
	for i in 16:
		var kp := r.position + Vector2(4 + (i % 4) * kw, 15 + (i / 4) * 8)
		draw_rect(Rect2(kp, Vector2(kw - 2, 7)), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(kp, Vector2(kw - 2, 1)), c(3))
		PixFont.draw(self, kp + Vector2(floorf((kw - 2) * 0.5) - 1, 1), keys[i], g * lit if night() > 0.3 else Color(0.9, 0.92, 0.9))


func _warn(jet: Jet, r: Rect2) -> void:
	var game: Node = owner3d.game
	var m: Missiles = game.missiles
	var warn := [jet.health < jet.max_health * 0.4, m.incoming_t < 3.0, jet.reloading > 0.0 or m.reload > 0.0, jet.boosting,
		jet.position.y < CityGen.LOW_ALT or jet.stalling, jet.overheated, jet.gloc > 0.1, m.locked]
	var blink := int(Time.get_ticks_msec() / 180) % 2 == 0
	draw_rect(r, Color(0.03, 0.03, 0.03))
	var lw := r.size.x / warn.size()
	for i in warn.size():
		var on: bool = warn[i]
		var col := Color("2a1206") if i < 6 else Color("0b2410")
		if on:
			col = (RED if blink else Color("7a1008")) if i <= 1 else (ORANGE if i < 6 else Color("4cff70"))
		draw_rect(Rect2(r.position.x + i * lw + 1, r.position.y + 1, lw - 2, r.size.y - 2), col)
