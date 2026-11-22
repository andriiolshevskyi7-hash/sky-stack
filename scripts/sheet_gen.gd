class_name SheetGen
## Procedural slice-sheet generators. Each generator paints ONE slice of ONE
## variant into the Painter's current cell. Slice 0 is the bottom slice.
## Image "up" (y = 0) is the object's FRONT (nose of a jet, bonnet of a car).

## name: [cell_w, cell_h, slices, variants, generator method]
const DEFS := {
	"jet": [32, 32, 9, 1, "_jet"],
	"enemy_jet": [28, 28, 7, 1, "_enemy_jet"],
	"drone": [18, 18, 4, 1, "_drone"],
	"bomber": [52, 52, 9, 1, "_bomber"],
	"aagun": [14, 14, 7, 1, "_aagun"],
	"car": [8, 14, 5, 6, "_car"],
	"bus": [10, 28, 7, 2, "_bus"],
	"train": [12, 44, 8, 2, "_train"],
	"boat": [14, 34, 6, 2, "_boat"],
	"ship": [30, 96, 10, 1, "_ship"],
	"airliner": [56, 56, 8, 1, "_airliner"],
	"tree": [14, 14, 12, 3, "_tree"],
	"bush": [8, 8, 4, 2, "_bush"],
	"lamp": [8, 8, 14, 1, "_lamp"],
	"ac_unit": [8, 8, 4, 1, "_ac"],
	"water_tank": [10, 10, 12, 1, "_tank"],
	"antenna": [7, 7, 32, 1, "_antenna"],
	"helipad": [26, 26, 1, 1, "_helipad"],
	"neon_sign": [24, 4, 12, 3, "_neon"],
	"chimney": [10, 10, 36, 1, "_chimney"],
	"crane": [50, 50, 42, 1, "_crane"],
	"container": [8, 20, 8, 4, "_container"],
	"fountain": [18, 18, 4, 1, "_fountain"],
	"cloud": [64, 64, 14, 3, "_cloud"],
}


static func P(i: int) -> Color:
	return Pal.c(i)


# ------------------------------------------------------------------ aircraft

static func _jet(p: Painter, s: int, v: int) -> void:
	var body := P(Pal.LGRAY)
	var dark := P(Pal.GRAY)
	var wing := P(Pal.STEEL)
	var acc := P(Pal.RED)
	match s:
		0:
			p.srect(2, 8, 29, dark)
			p.srect(3, 24, 31, P(Pal.DGRAY))
		1:
			p.srect(3, 6, 30, body)
			p.srect(4, 12, 19, dark)
			p.srect(3, 27, 31, P(Pal.DGRAY))
		2:
			p.srect(1, 1, 4, body)
			p.srect(2, 3, 6, body)
			p.srect(3, 6, 30, body)
			p.srect(2, 30, 32, dark)
			p.erect(13, 31, 6, 1, P(Pal.AMBER), Painter.EM_ALWAYS)
		3:
			p.mpoly(PackedVector2Array([Vector2(16, 10), Vector2(2, 23), Vector2(2, 26), Vector2(16, 24)]), wing)
			p.mpoly(PackedVector2Array([Vector2(16, 25), Vector2(8, 30), Vector2(8, 32), Vector2(16, 31)]), wing)
			p.srect(3, 3, 31, body)
			p.rect(2, 23, 2, 3, acc)
			p.rect(28, 23, 2, 3, acc)
		4:
			p.mpoly(PackedVector2Array([Vector2(16, 13), Vector2(6, 22), Vector2(6, 24), Vector2(16, 23)]), wing.lightened(0.1))
			p.srect(3, 4, 29, body)
			p.srect(1, 14, 22, acc)
		5:
			p.srect(2, 5, 27, body)
			p.srect(2, 7, 12, P(Pal.SKY))
		6:
			p.srect(2, 7, 12, P(Pal.PALE))
			p.srect(1, 12, 27, body)
			p.rect(10, 22, 2, 8, dark)
			p.rect(20, 22, 2, 8, dark)
		7:
			p.srect(1, 8, 11, P(Pal.WHITE))
			p.rect(10, 24, 2, 6, dark)
			p.rect(20, 24, 2, 6, dark)
		8:
			p.rect(10, 26, 2, 4, acc)
			p.rect(20, 26, 2, 4, acc)


static func _enemy_jet(p: Painter, s: int, v: int) -> void:
	var body := P(Pal.DGRAY)
	var wing := P(Pal.RED_D)
	var acc := P(Pal.RED)
	match s:
		0:
			p.srect(2, 6, 26, P(Pal.CHAR))
		1:
			p.srect(3, 4, 27, body)
			p.erect(11, 27, 6, 1, P(Pal.ORANGE), Painter.EM_ALWAYS)
		2:
			p.mpoly(PackedVector2Array([Vector2(14, 6), Vector2(1, 18), Vector2(4, 22), Vector2(14, 19)]), wing)
			p.mpoly(PackedVector2Array([Vector2(14, 21), Vector2(7, 27), Vector2(14, 27)]), wing)
			p.srect(2, 1, 27, body)
			p.rect(1, 17, 3, 2, acc)
			p.rect(24, 17, 3, 2, acc)
		3:
			p.srect(2, 3, 25, body.lightened(0.1))
		4:
			p.srect(2, 6, 10, P(Pal.AMBER))
			p.srect(1, 10, 24, body)
			p.rect(13, 20, 2, 7, acc)
		5:
			p.srect(1, 7, 9, P(Pal.YELLOW))
			p.rect(13, 21, 2, 6, acc)
		6:
			p.rect(13, 23, 2, 4, P(Pal.RED_D))


static func _drone(p: Painter, s: int, v: int) -> void:
	match s:
		0:
			p.line(3, 3, 14, 14, P(Pal.CHAR))
			p.line(14, 3, 3, 14, P(Pal.CHAR))
			p.line(4, 3, 14, 13, P(Pal.CHAR))
			p.line(13, 3, 3, 13, P(Pal.CHAR))
		1:
			p.ell(9, 9, 4, 4, P(Pal.GRAY))
			for c in [Vector2(3.5, 3.5), Vector2(14.5, 3.5), Vector2(3.5, 14.5), Vector2(14.5, 14.5)]:
				p.ring(c.x, c.y, 3.5, 1.2, P(Pal.DGRAY))
		2:
			p.ell(9, 9, 3, 3, P(Pal.LGRAY))
			p.erect(8, 6, 2, 2, P(Pal.RED), Painter.EM_ALWAYS)
		3:
			for c in [Vector2(3, 3), Vector2(14, 3), Vector2(3, 14), Vector2(14, 14)]:
				p.rect(int(c.x) - 2, int(c.y), 5, 1, P(Pal.PALE))


static func _bomber(p: Painter, s: int, v: int) -> void:
	var a := P(Pal.GREEN_D)
	var b := P(Pal.CHAR)
	match s:
		0:
			p.srect(4, 8, 44, b)
		1:
			p.mpoly(PackedVector2Array([Vector2(26, 10), Vector2(6, 32), Vector2(8, 36), Vector2(26, 30)]), b)
			p.srect(5, 6, 46, a)
		2:
			p.mpoly(PackedVector2Array([Vector2(26, 8), Vector2(1, 34), Vector2(4, 39), Vector2(26, 31)]), a)
			p.srect(5, 3, 48, a.lightened(0.08))
			for ex in [12, 18, 31, 37]:
				p.rect(ex, 30, 3, 6, b)
				p.erect(ex, 36, 3, 1, P(Pal.ORANGE), Painter.EM_ALWAYS)
			p.mpoly(PackedVector2Array([Vector2(26, 42), Vector2(14, 50), Vector2(26, 50)]), a)
		3:
			p.mpoly(PackedVector2Array([Vector2(26, 12), Vector2(8, 31), Vector2(10, 33), Vector2(26, 28)]), a.lightened(0.15))
			p.srect(4, 4, 46, a)
			p.rect(4, 33, 3, 2, P(Pal.RED))
			p.rect(45, 33, 3, 2, P(Pal.RED))
		4:
			p.srect(4, 6, 44, a.lightened(0.1))
			p.srect(2, 6, 11, P(Pal.SKY))
		5:
			p.srect(3, 8, 42, a)
			p.srect(2, 7, 11, P(Pal.PALE))
		6:
			p.srect(1, 36, 49, b)
		7:
			p.srect(1, 38, 49, b)
		8:
			p.srect(1, 40, 48, P(Pal.RED_D))


static func _aagun(p: Painter, s: int, v: int) -> void:
	match s:
		0, 1:
			p.ell(7, 7, 6.5, 6.5, P(Pal.DGRAY))
		2, 3:
			p.ell(7, 7, 5, 5, P(Pal.GRAY))
		4, 5:
			p.rect(3, 4, 8, 8, P(Pal.GREEN_D))
			p.rect(4, 0, 2, 5, P(Pal.CHAR))
			p.rect(8, 0, 2, 5, P(Pal.CHAR))
		6:
			p.rect(4, 5, 6, 6, P(Pal.GREEN))
			p.erect(6, 6, 2, 1, P(Pal.RED), Painter.EM_ALWAYS)


# ------------------------------------------------------------------ vehicles

const CAR_COLS := [Pal.RED, Pal.OCEAN, Pal.YELLOW, Pal.WHITE, Pal.GREEN, Pal.NAVY]


static func _car(p: Painter, s: int, v: int) -> void:
	var col := P(CAR_COLS[v])
	match s:
		0:
			p.rect(0, 2, 8, 3, P(Pal.BLACK))
			p.rect(0, 9, 8, 3, P(Pal.BLACK))
			p.rect(1, 1, 6, 12, P(Pal.CHAR))
		1:
			p.rect(1, 0, 6, 14, col.darkened(0.15))
			p.epx(1, 0, P(Pal.WARM))
			p.epx(6, 0, P(Pal.WARM))
			p.epx(1, 13, P(Pal.RED))
			p.epx(6, 13, P(Pal.RED))
		2:
			p.rect(1, 0, 6, 14, col)
		3:
			p.rect(1, 3, 6, 8, col)
			p.rect(2, 3, 4, 2, P(Pal.STEEL))
			p.rect(2, 9, 4, 1, P(Pal.STEEL))
		4:
			p.rect(2, 5, 4, 4, col.lightened(0.2))
			if v == 2:
				p.rect(3, 6, 2, 1, P(Pal.ORANGE))
			elif v == 5:
				p.epx(2, 6, P(Pal.RED), Painter.EM_BLINK)
				p.epx(5, 6, P(Pal.SKY), Painter.EM_BLINK)


static func _bus(p: Painter, s: int, v: int) -> void:
	var col := P(Pal.AMBER) if v == 0 else P(Pal.WHITE)
	var col2 := P(Pal.ORANGE) if v == 0 else P(Pal.RED)
	match s:
		0:
			p.rect(0, 3, 10, 4, P(Pal.BLACK))
			p.rect(0, 20, 10, 4, P(Pal.BLACK))
			p.rect(1, 1, 8, 26, P(Pal.CHAR))
		1:
			p.rect(1, 0, 8, 28, col2)
			p.epx(1, 0, P(Pal.WARM))
			p.epx(8, 0, P(Pal.WARM))
			p.epx(1, 27, P(Pal.RED))
			p.epx(8, 27, P(Pal.RED))
		2, 3:
			p.rect(1, 0, 8, 28, col)
			if v == 1:
				p.rect(1, 8, 8, 20, col2)
		4:
			if v == 0:
				p.rect(1, 0, 8, 28, P(Pal.STEEL))
				p.epx(1, 10, P(Pal.WARM))
				p.epx(8, 16, P(Pal.WARM))
			else:
				p.rect(1, 0, 8, 6, P(Pal.STEEL))
				p.rect(1, 8, 8, 20, col2)
		5:
			if v == 0:
				p.rect(1, 0, 8, 28, col)
			else:
				p.rect(1, 1, 8, 4, col)
				p.rect(1, 8, 8, 20, col2.darkened(0.1))
		6:
			if v == 0:
				p.rect(2, 2, 6, 24, col.lightened(0.15))
			else:
				p.rect(1, 8, 8, 20, P(Pal.LGRAY))


static func _train(p: Painter, s: int, v: int) -> void:
	var col := P(Pal.RED) if v == 0 else P(Pal.LGRAY)
	match s:
		0:
			p.rect(1, 2, 10, 40, P(Pal.BLACK))
		1:
			p.rect(1, 1, 10, 42, P(Pal.CHAR))
			if v == 0:
				p.epx(2, 1, P(Pal.WARM))
				p.epx(9, 1, P(Pal.WARM))
		2, 3:
			p.rect(1, 1, 10, 42, col)
		4:
			p.rect(1, 1, 10, 42, P(Pal.STEEL))
			for wy in range(4, 40, 5):
				p.erect(1, wy, 1, 3, P(Pal.WARM))
				p.erect(10, wy, 1, 3, P(Pal.WARM))
		5:
			p.rect(1, 1, 10, 42, col)
		6:
			p.rect(1, 2, 10, 40, P(Pal.GRAY))
		7:
			p.rect(3, 4, 6, 36, P(Pal.LGRAY))
			if v == 0:
				p.rect(4, 2, 4, 3, P(Pal.SKY))


static func _boat(p: Painter, s: int, v: int) -> void:
	var hull := P(Pal.WHITE) if v == 0 else P(Pal.RED)
	var hull_pts := PackedVector2Array([Vector2(7, 0), Vector2(13, 8), Vector2(13, 33), Vector2(1, 33), Vector2(1, 8)])
	match s:
		0:
			p.poly(PackedVector2Array([Vector2(7, 2), Vector2(12, 9), Vector2(12, 32), Vector2(2, 32), Vector2(2, 9)]), P(Pal.DGRAY))
		1, 2:
			p.poly(hull_pts, hull)
		3:
			p.poly(hull_pts, hull.darkened(0.1))
			p.poly(PackedVector2Array([Vector2(7, 3), Vector2(11, 9), Vector2(11, 31), Vector2(3, 31), Vector2(3, 9)]), P(Pal.TAN))
		4:
			p.rect(3, 14, 8, 12, P(Pal.WHITE) if v == 1 else P(Pal.STEEL))
			p.erect(4, 14, 6, 1, P(Pal.WARM))
		5:
			p.rect(4, 15, 6, 9, P(Pal.LGRAY))
			if v == 1:
				p.rect(6, 22, 2, 2, P(Pal.CHAR))
			p.epx(7, 15, P(Pal.RED), Painter.EM_BLINK)


static func _ship(p: Painter, s: int, v: int) -> void:
	var hull := PackedVector2Array([Vector2(15, 0), Vector2(29, 14), Vector2(29, 95), Vector2(1, 95), Vector2(1, 14)])
	match s:
		0:
			p.poly(PackedVector2Array([Vector2(15, 3), Vector2(27, 15), Vector2(27, 94), Vector2(3, 94), Vector2(3, 15)]), P(Pal.RED_D))
		1, 2, 3:
			p.poly(hull, P(Pal.NAVY))
		4:
			p.poly(hull, P(Pal.DGRAY))
			p.poly(PackedVector2Array([Vector2(15, 4), Vector2(27, 16), Vector2(27, 93), Vector2(3, 93), Vector2(3, 16)]), P(Pal.RED_D))
		5, 6, 7:
			var cols := [Pal.RED, Pal.OCEAN, Pal.GREEN, Pal.AMBER, Pal.LGRAY, Pal.ORANGE]
			for row in range(4):
				for k in range(3):
					var ci: int = cols[(row * 3 + k + s) % cols.size()]
					p.rect(4 + k * 8, 18 + row * 14, 7, 12, P(ci))
			p.rect(4, 80, 22, 13, P(Pal.WHITE))
		8:
			p.rect(5, 80, 20, 12, P(Pal.WHITE))
			for wx in range(6, 24, 3):
				p.erect(wx, 80, 2, 1, P(Pal.WARM))
		9:
			p.rect(6, 82, 18, 8, P(Pal.LGRAY))
			p.rect(13, 88, 4, 4, P(Pal.RED))
			p.epx(15, 82, P(Pal.RED), Painter.EM_BLINK)


static func _airliner(p: Painter, s: int, v: int) -> void:
	var white := P(Pal.WHITE)
	var gray := P(Pal.LGRAY)
	match s:
		0:
			p.srect(3, 6, 52, P(Pal.GRAY))
		1:
			p.srect(4, 4, 52, gray)
			p.mpoly(PackedVector2Array([Vector2(28, 20), Vector2(4, 36), Vector2(5, 39), Vector2(28, 30)]), P(Pal.GRAY))
			p.rect(14, 28, 4, 6, P(Pal.DGRAY))
			p.rect(38, 28, 4, 6, P(Pal.DGRAY))
		2:
			p.mpoly(PackedVector2Array([Vector2(28, 19), Vector2(3, 35), Vector2(4, 38), Vector2(28, 29)]), gray)
			p.srect(4, 3, 53, white)
			p.srect(3, 1, 4, white)
			p.mpoly(PackedVector2Array([Vector2(28, 46), Vector2(17, 54), Vector2(17, 55), Vector2(28, 52)]), gray)
			p.epx(3, 36, P(Pal.RED), Painter.EM_BLINK)
			p.epx(52, 36, P(Pal.GREEN_L), Painter.EM_BLINK)
		3:
			p.srect(4, 4, 51, white)
			for wy in range(8, 46, 3):
				p.epx(24, wy, P(Pal.WARM))
				p.epx(31, wy, P(Pal.WARM))
		4:
			p.srect(3, 5, 49, white)
			p.srect(2, 4, 7, P(Pal.STEEL))
		5:
			p.srect(1, 44, 54, P(Pal.OCEAN))
		6:
			p.srect(1, 46, 54, P(Pal.OCEAN))
		7:
			p.srect(1, 48, 54, P(Pal.RED))


# ------------------------------------------------------------------ props

static func _tree(p: Painter, s: int, v: int) -> void:
	var trunk := P(Pal.BROWN_D)
	var leaf: Color
	var leaf2: Color
	match v:
		0:
			leaf = P(Pal.GREEN)
			leaf2 = P(Pal.GREEN_L)
		1:
			leaf = P(Pal.GREEN_D)
			leaf2 = P(Pal.GREEN)
		_:
			leaf = P(Pal.ORANGE)
			leaf2 = P(Pal.AMBER)
	if v == 1:
		# pine: cone
		if s < 2:
			p.rect(6, 6, 2, 2, trunk)
		else:
			var r := 6.5 * (1.0 - float(s - 2) / 10.0)
			p.ell(7, 7, r, r, leaf)
			if s % 3 == 0:
				p.ell(6.5, 6.5, r * 0.6, r * 0.6, leaf2)
		return
	if s < 4:
		p.rect(6, 6, 2, 2, trunk)
		return
	var t := float(s - 4) / 7.0
	var rr := 6.5 * sin(PI * (0.25 + 0.75 * t))
	p.ell(7, 7, rr, rr, leaf)
	if s >= 8:
		p.ell(6, 6, rr * 0.6, rr * 0.6, leaf2)


static func _bush(p: Painter, s: int, v: int) -> void:
	var c := P(Pal.GREEN) if v == 0 else P(Pal.GREEN_D)
	var r: float = [3.8, 4.0, 3.3, 2.0][s]
	p.ell(4, 4, r, r, c if s < 3 else c.lightened(0.2))
	if v == 1 and s == 3:
		p.px(3, 3, P(Pal.PINK))
		p.px(5, 4, P(Pal.YELLOW))


static func _lamp(p: Painter, s: int, v: int) -> void:
	var pole := P(Pal.CHAR)
	if s < 12:
		p.px(2, 4, pole)
		if s == 0:
			p.rect(1, 3, 3, 3, pole)
	elif s == 12:
		p.rect(2, 4, 5, 1, pole)
	else:
		p.rect(4, 3, 3, 3, P(Pal.DGRAY))
		p.erect(5, 4, 1, 1, P(Pal.WARM))


static func _ac(p: Painter, s: int, v: int) -> void:
	p.rect(0, 1, 8, 6, P(Pal.LGRAY) if s < 3 else P(Pal.GRAY))
	if s == 3:
		p.ring(4, 4, 2.5, 1.0, P(Pal.CHAR))


static func _tank(p: Painter, s: int, v: int) -> void:
	if s < 5:
		for c in [Vector2i(1, 1), Vector2i(8, 1), Vector2i(1, 8), Vector2i(8, 8)]:
			p.px(c.x, c.y, P(Pal.CHAR))
	elif s < 10:
		p.ell(5, 5, 4.5, 4.5, P(Pal.BROWN))
		p.rect(4, 0, 1, 10, P(Pal.BROWN_D))
	elif s == 10:
		p.ell(5, 5, 3.5, 3.5, P(Pal.BROWN_D))
	else:
		p.ell(5, 5, 1.5, 1.5, P(Pal.BROWN_D))


static func _antenna(p: Painter, s: int, v: int) -> void:
	var c := P(Pal.LGRAY) if (s / 4) % 2 == 0 else P(Pal.RED)
	if s < 12:
		p.rect(2, 2, 3, 3, P(Pal.GRAY))
		p.px(3, 3, c)
	elif s < 31:
		p.px(3, 3, c)
	if s % 8 == 7 and s < 28:
		p.rect(1, 3, 5, 1, P(Pal.GRAY))
	if s == 31:
		p.epx(3, 3, P(Pal.RED), Painter.EM_BLINK)


static func _helipad(p: Painter, s: int, v: int) -> void:
	p.ell(13, 13, 12.5, 12.5, P(Pal.CHAR))
	p.ring(13, 13, 11.5, 1.2, P(Pal.YELLOW))
	var wc := P(Pal.WHITE)
	p.rect(9, 8, 2, 10, wc)
	p.rect(15, 8, 2, 10, wc)
	p.rect(11, 12, 4, 2, wc)
	for a in range(8):
		var ang := TAU * a / 8.0
		p.epx(int(13 + cos(ang) * 11.0), int(13 + sin(ang) * 11.0), P(Pal.GREEN_L))


const NEON_WORDS := ["HOTEL", "CAFE", "NEON"]
const NEON_COLS := [Pal.PINK, Pal.CYAN, Pal.YELLOW]
## 3x5 bitmap font for neon signs (rows top->bottom, 3 bits per row).
const FONT := {
	"A": [7, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [7, 4, 4, 4, 7], "E": [7, 4, 6, 4, 7],
	"F": [7, 4, 6, 4, 4], "H": [5, 5, 7, 5, 5], "L": [4, 4, 4, 4, 7], "N": [7, 5, 5, 5, 5],
	"O": [7, 5, 5, 5, 7], "R": [6, 5, 6, 5, 5], "T": [7, 2, 2, 2, 2], "S": [7, 4, 7, 1, 7],
	"K": [5, 5, 6, 5, 5], "Y": [5, 5, 7, 2, 2], "I": [7, 2, 2, 2, 7], "M": [5, 7, 7, 5, 5],
}


static func _neon(p: Painter, s: int, v: int) -> void:
	# Vertical sign facing "front" (-y). Each slice is one pixel row of the face.
	var col := P(NEON_COLS[v])
	if s < 3:
		p.px(4, 2, P(Pal.CHAR))
		p.px(19, 2, P(Pal.CHAR))
		return
	p.rect(1, 2, 22, 2, P(Pal.CHAR))
	var row := 11 - s  # 0 = top row of the face
	if row == 0 or row == 8:
		p.erect(1, 1, 22, 1, col)
		return
	p.erect(1, 1, 1, 1, col)
	p.erect(22, 1, 1, 1, col)
	var fr := row - 2
	if fr < 0 or fr > 4:
		return
	var word: String = NEON_WORDS[v]
	var x0 := 12 - (word.length() * 4 - 1) / 2
	for i in word.length():
		var g: Array = FONT.get(word[i], [0, 0, 0, 0, 0])
		var bits: int = g[fr]
		for b in 3:
			if bits & (4 >> b):
				p.epx(x0 + i * 4 + b, 1, col.lightened(0.3))


static func _chimney(p: Painter, s: int, v: int) -> void:
	var r := 4.5 - float(s) / 36.0 * 1.5
	var band := (s / 5) % 2 == 0
	var c := P(Pal.RED) if band else P(Pal.WHITE)
	if s >= 34:
		p.ring(5, 5, r, 1.2, P(Pal.CHAR))
		p.ell(5, 5, r - 1.0, r - 1.0, P(Pal.BLACK))
	else:
		p.ell(5, 5, r, r, c)


static func _crane(p: Painter, s: int, v: int) -> void:
	var y := P(Pal.AMBER)
	if s < 40:
		p.rect(24, 24, 3, 3, y if s % 3 != 0 else P(Pal.ORANGE))
		if s < 2:
			p.rect(22, 22, 7, 7, P(Pal.CHAR))
	elif s == 40:
		p.rect(4, 24, 46, 2, y)
		p.rect(4, 22, 8, 6, P(Pal.GRAY))
		p.rect(22, 21, 6, 8, y.darkened(0.2))
		p.rect(40, 26, 1, 3, P(Pal.CHAR))
	else:
		p.rect(24, 24, 3, 3, y)
		p.line(25, 25, 49, 25, P(Pal.CHAR))
		p.line(25, 25, 5, 25, P(Pal.CHAR))
		p.epx(25, 25, P(Pal.RED), Painter.EM_BLINK)


const CONT_COLS := [Pal.RED, Pal.OCEAN, Pal.GREEN, Pal.ORANGE]


static func _container(p: Painter, s: int, v: int) -> void:
	var c := P(CONT_COLS[v])
	p.rect(0, 0, 8, 20, c.darkened(0.2) if s % 4 == 0 else c)
	if s % 4 == 3:
		for yy in range(1, 20, 2):
			p.rect(1, yy, 6, 1, c.lightened(0.15))


static func _fountain(p: Painter, s: int, v: int) -> void:
	match s:
		0:
			p.ell(9, 9, 8.5, 8.5, P(Pal.LGRAY))
		1:
			p.ring(9, 9, 8.5, 1.5, P(Pal.LGRAY))
			p.ell(9, 9, 7, 7, P(Pal.OCEAN))
			p.ell(9, 9, 2, 2, P(Pal.GRAY))
		2:
			p.ell(9, 9, 1.5, 1.5, P(Pal.PALE))
		3:
			p.ell(9, 9, 3, 3, P(Pal.PALE))
			p.px(9, 9, P(Pal.WHITE))


static func _cloud(p: Painter, s: int, v: int) -> void:
	# a cluster of spheres: each slice is the cross-section at that height
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + v * 77
	var y := float(s) + 0.5
	var top := Color("f4f8fd")
	var mid := Color("e3ecf7")
	var low := Color("bccfe8")
	var col := low if s < 3 else (mid if s < 7 else top)
	for i in 9:
		var cx := rng.randf_range(18.0, 46.0)
		var cy := rng.randf_range(18.0, 46.0)
		var r := rng.randf_range(9.0, 15.0)
		var cz := rng.randf_range(r * 0.35, r * 0.7) # sphere centre height (flat-ish bottom)
		var dz := y - cz
		if absf(dz) >= r or y < 1.0 and r < 11.0:
			continue
		var rr := sqrt(r * r - dz * dz)
		p.ell(cx, cy, rr, rr * 0.92, col)
		if s >= 7:
			p.ell(cx - rr * 0.25, cy - rr * 0.25, rr * 0.55, rr * 0.5, top)
