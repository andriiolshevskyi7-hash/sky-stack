class_name SheetGen
## Procedural slice-sheet generators. Each generator paints ONE slice of ONE
## variant into the Painter's current cell. Slice 0 is the bottom slice.
## Image "up" (y = 0) is the object's FRONT (nose of a jet, bonnet of a car).

## name: [cell_w, cell_h, slices, variants, generator method]
const DEFS := {
	"jet": [40, 40, 11, 1, "_jet"],
	"enemy_jet": [28, 28, 7, 1, "_enemy_jet"],
	"drone": [18, 18, 4, 1, "_drone"],
	"bomber": [52, 52, 9, 1, "_bomber"],
	"aagun": [14, 14, 7, 1, "_aagun"],
	"car": [16, 28, 7, 6, "_car"],
	"bus": [20, 56, 10, 2, "_bus"],
	"train": [12, 44, 8, 2, "_train"],
	"boat": [28, 68, 9, 2, "_boat"],
	"ship": [60, 192, 14, 1, "_ship"],
	"airliner": [56, 56, 8, 1, "_airliner"],
	"tree": [14, 14, 12, 3, "_tree"],
	"bush": [8, 8, 4, 2, "_bush"],
	"rock": [14, 14, 8, 3, "_rock"],
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
	"parachute": [26, 26, 14, 1, "_parachute"],
	"chute": [48, 48, 24, 1, "_chute"],
	"pilot": [14, 14, 11, 1, "_pilot"],
	"eseat": [18, 18, 12, 1, "_eseat"],
	"canopy": [16, 26, 4, 1, "_canopy"],
}


static func P(i: int) -> Color:
	return Pal.c(i)


# ------------------------------------------------------------------ aircraft

static func _jet(p: Painter, s: int, v: int) -> void:
	# sleek dark fighter: swept wings, twin canted tails, orange accents
	var body := Color("545969")
	var dark := Color("3a3e4b")
	var light := Color("6d7386")
	var acc := Color("f0580e")
	var canopy := Color("1e8ca0")
	match s:
		0:
			p.srect(2, 7, 36, dark)
		1:
			p.srect(3, 4, 37, dark)
			p.srect(4, 12, 23, Color("2c2f39"))
		2:
			p.srect(1, 0, 3, body)
			p.srect(2, 3, 7, body)
			p.srect(3, 7, 37, body)
			p.rect(16, 37, 3, 2, dark)
			p.rect(21, 37, 3, 2, dark)
			p.erect(17, 39, 1, 1, Color("ffb43c"), Painter.EM_ALWAYS)
			p.erect(22, 39, 1, 1, Color("ffb43c"), Painter.EM_ALWAYS)
		3:
			p.mpoly(PackedVector2Array([Vector2(20, 13), Vector2(3, 27), Vector2(3, 30), Vector2(20, 26)]), body)
			p.mpoly(PackedVector2Array([Vector2(20, 29), Vector2(10, 35), Vector2(10, 38), Vector2(20, 36)]), body)
			p.srect(3, 2, 38, body)
			p.rect(3, 27, 2, 3, acc)
			p.rect(35, 27, 2, 3, acc)
		4:
			p.mpoly(PackedVector2Array([Vector2(20, 15), Vector2(6, 26), Vector2(6, 28), Vector2(20, 25)]), light)
			p.srect(3, 3, 36, light)
			p.srect(1, 2, 5, acc)
		5:
			p.srect(2, 4, 34, body)
			p.srect(1, 16, 30, light)
		6:
			p.srect(2, 6, 13, canopy)
			p.srect(1, 13, 33, body)
			p.rect(14, 28, 2, 9, dark)
			p.rect(24, 28, 2, 9, dark)
		7:
			p.srect(1, 7, 12, canopy.lightened(0.35))
			p.rect(13, 30, 2, 7, body)
			p.rect(25, 30, 2, 7, body)
		8:
			p.rect(13, 31, 2, 6, body)
			p.rect(25, 31, 2, 6, body)
		9:
			p.rect(12, 32, 2, 5, body)
			p.rect(26, 32, 2, 5, body)
		10:
			p.rect(12, 33, 2, 3, acc)
			p.rect(26, 33, 2, 3, acc)


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
	# 16x28, 7 slices: tyres, bumpers, lights, glass, roof details
	var col := P(CAR_COLS[v])
	var dark := col.darkened(0.25)
	var glass := Color("2c3e5a")
	var glass_hi := Color("7fb0d8")
	match s:
		0:
			for wy in [4, 19]:
				p.rect(1, wy, 3, 6, P(Pal.BLACK))
				p.rect(12, wy, 3, 6, P(Pal.BLACK))
			p.rect(3, 2, 10, 24, P(Pal.CHAR))
		1:
			for wy in [4, 19]:
				p.rect(1, wy, 3, 6, P(Pal.CHAR))
				p.rect(12, wy, 3, 6, P(Pal.CHAR))
				p.rect(1, wy + 2, 3, 2, P(Pal.GRAY))
				p.rect(12, wy + 2, 3, 2, P(Pal.GRAY))
			p.rect(3, 1, 10, 26, dark)
		2:
			p.rect(2, 0, 12, 28, dark)
			p.rect(3, 0, 10, 1, P(Pal.LGRAY))
			p.rect(3, 27, 10, 1, P(Pal.GRAY))
			p.erect(3, 0, 3, 1, P(Pal.WARM))
			p.erect(10, 0, 3, 1, P(Pal.WARM))
			p.erect(3, 27, 3, 1, P(Pal.RED))
			p.erect(10, 27, 3, 1, P(Pal.RED))
		3:
			p.rect(2, 1, 12, 26, col)
			p.rect(2, 9, 1, 10, dark)
			p.rect(13, 9, 1, 10, dark)
			p.rect(4, 2, 8, 1, col.lightened(0.2))
		4:
			p.rect(2, 2, 12, 24, col)
			p.rect(3, 8, 10, 3, glass)
			p.rect(4, 8, 3, 1, glass_hi)
			p.rect(3, 19, 10, 2, glass)
			p.rect(2, 11, 1, 8, glass)
			p.rect(13, 11, 1, 8, glass)
		5:
			p.rect(3, 10, 10, 10, col.lightened(0.08))
			p.rect(3, 10, 10, 1, glass)
		6:
			p.rect(4, 11, 8, 8, col.lightened(0.18))
			p.rect(4, 11, 8, 1, col.lightened(0.35))
			if v == 2:
				p.rect(6, 13, 4, 3, P(Pal.ORANGE))
				p.rect(7, 14, 2, 1, P(Pal.BLACK))
			elif v == 5:
				p.erect(4, 14, 4, 2, P(Pal.RED), Painter.EM_BLINK)
				p.erect(8, 14, 4, 2, P(Pal.SKY), Painter.EM_BLINK)


static func _bus(p: Painter, s: int, v: int) -> void:
	# 20x56, 10 slices: city bus (v0) / delivery truck (v1)
	var col := P(Pal.AMBER) if v == 0 else P(Pal.WHITE)
	var col2 := P(Pal.ORANGE) if v == 0 else P(Pal.RED)
	var glass := Color("2c3e5a")
	match s:
		0:
			for wy in [6, 40]:
				p.rect(1, wy, 4, 9, P(Pal.BLACK))
				p.rect(15, wy, 4, 9, P(Pal.BLACK))
			p.rect(3, 2, 14, 52, P(Pal.CHAR))
		1:
			for wy in [6, 40]:
				p.rect(1, wy + 3, 4, 3, P(Pal.GRAY))
				p.rect(15, wy + 3, 4, 3, P(Pal.GRAY))
			p.rect(2, 0, 16, 56, col2.darkened(0.2))
			p.erect(3, 0, 3, 1, P(Pal.WARM))
			p.erect(14, 0, 3, 1, P(Pal.WARM))
			p.erect(3, 55, 3, 1, P(Pal.RED))
			p.erect(14, 55, 3, 1, P(Pal.RED))
		2, 3:
			p.rect(2, 0, 16, 56, col if v == 0 else (col if s == 2 else col2))
			if v == 1:
				p.rect(2, 0, 16, 14, col)
		4, 5, 6:
			if v == 0:
				p.rect(2, 0, 16, 56, col)
				p.rect(3, 1, 14, 3, glass)
				for wy in range(8, 54, 6):
					p.rect(2, wy, 1, 4, glass)
					p.rect(17, wy, 1, 4, glass)
					p.erect(2, wy + 1, 1, 2, P(Pal.WARM))
					p.erect(17, wy + 1, 1, 2, P(Pal.WARM))
			else:
				p.rect(2, 1, 16, 12, col)
				p.rect(3, 1, 14, 3, glass)
				p.rect(2, 16, 16, 40, col2)
				p.rect(2, 16 + (s - 4) * 12, 16, 1, col2.darkened(0.2))
		7, 8:
			if v == 0:
				p.rect(2, 0, 16, 56, col.lightened(0.05) if s == 7 else col)
				p.rect(2, 0, 16, 1, col.lightened(0.25))
			else:
				p.rect(2, 16, 16, 40, col2.lightened(0.05))
				if s == 8:
					p.rect(4, 3, 12, 8, col.lightened(0.1))
		9:
			if v == 0:
				p.rect(6, 20, 8, 12, P(Pal.LGRAY))
				p.rect(7, 22, 6, 1, P(Pal.GRAY))
				p.rect(7, 26, 6, 1, P(Pal.GRAY))
			else:
				p.rect(3, 17, 14, 38, P(Pal.LGRAY))
				for x in range(4, 16, 3):
					p.rect(x, 17, 1, 38, P(Pal.GRAY))


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
	# 28x68, 9 slices: white speedboat (v0) / red tug (v1)
	var hull := P(Pal.WHITE) if v == 0 else P(Pal.RED)
	var hull_d := hull.darkened(0.2)
	var deck := P(Pal.TAN) if v == 0 else P(Pal.DGRAY)
	var outline := PackedVector2Array([Vector2(14, 0), Vector2(26, 16), Vector2(26, 66), Vector2(2, 66), Vector2(2, 16)])
	var inner := PackedVector2Array([Vector2(14, 4), Vector2(23, 17), Vector2(23, 63), Vector2(5, 63), Vector2(5, 17)])
	match s:
		0:
			p.poly(PackedVector2Array([Vector2(14, 4), Vector2(24, 18), Vector2(24, 64), Vector2(4, 64), Vector2(4, 18)]), P(Pal.DGRAY))
		1, 2:
			p.poly(outline, hull_d if s == 1 else hull)
			if s == 2:
				p.rect(2, 40, 24, 2, P(Pal.NAVY) if v == 0 else P(Pal.WHITE))
		3:
			p.poly(outline, hull)
			p.poly(inner, deck)
			for y in range(20, 62, 4):
				p.rect(6, y, 16, 1, deck.darkened(0.12))
			if v == 1:
				for y in range(18, 64, 8):
					p.rect(2, y, 1, 4, P(Pal.CHAR))
					p.rect(25, y, 1, 4, P(Pal.CHAR))
		4, 5:
			var cy := 26 if v == 0 else 22
			p.rect(6, cy, 16, 20, P(Pal.WHITE) if v == 1 else P(Pal.LGRAY))
			p.rect(7, cy, 14, 3, Color("2c3e5a"))
			if s == 5:
				p.erect(7, cy + 1, 14, 1, P(Pal.WARM))
				p.rect(6, cy + 6, 1, 10, Color("2c3e5a"))
				p.rect(21, cy + 6, 1, 10, Color("2c3e5a"))
		6:
			p.rect(7, (27 if v == 0 else 23), 14, 18, P(Pal.LGRAY))
		7:
			if v == 1:
				p.rect(11, 30, 6, 6, P(Pal.CHAR))
				p.rect(11, 30, 6, 2, P(Pal.RED))
			else:
				p.rect(9, 30, 10, 12, P(Pal.WHITE))
		8:
			p.rect(13, 32, 2, 2, P(Pal.GRAY))
			p.epx(13, 31, P(Pal.RED), Painter.EM_BLINK)


static func _ship(p: Painter, s: int, v: int) -> void:
	# 60x192, 14 slices: container ship with a stern superstructure
	var hull := PackedVector2Array([Vector2(30, 0), Vector2(58, 26), Vector2(58, 190), Vector2(2, 190), Vector2(2, 26)])
	var deck := PackedVector2Array([Vector2(30, 6), Vector2(54, 28), Vector2(54, 186), Vector2(6, 186), Vector2(6, 28)])
	match s:
		0:
			p.poly(PackedVector2Array([Vector2(30, 6), Vector2(55, 28), Vector2(55, 188), Vector2(5, 188), Vector2(5, 28)]), P(Pal.RED_D))
		1, 2:
			p.poly(hull, P(Pal.RED_D) if s == 1 else P(Pal.NAVY))
		3, 4:
			p.poly(hull, P(Pal.NAVY))
			if s == 4:
				p.rect(2, 60, 56, 1, P(Pal.WHITE))
		5:
			p.poly(hull, P(Pal.DGRAY))
			p.poly(deck, P(Pal.GRAY))
			for y in range(30, 186, 10):
				p.rect(6, y, 48, 1, P(Pal.DGRAY))
		6, 7, 8, 9:
			var cols := [Pal.RED, Pal.OCEAN, Pal.GREEN, Pal.AMBER, Pal.LGRAY, Pal.ORANGE, Pal.WHITE, Pal.STEEL]
			var layer := s - 6
			for row in 6:
				for k in 4:
					if layer >= 2 and CityGen.hashf(row, k, 31 + layer) < 0.35:
						continue
					var ci: int = cols[int(CityGen.hashf(row, k, 7 + layer) * cols.size()) % cols.size()]
					var c := P(ci)
					p.rect(8 + k * 11, 34 + row * 22, 10, 20, c)
					if layer % 2 == 1:
						for y in range(35 + row * 22, 53 + row * 22, 3):
							p.rect(8 + k * 11, y, 10, 1, c.darkened(0.15))
		10, 11:
			p.rect(10, 160, 40, 24, P(Pal.WHITE))
			for wx in range(12, 48, 4):
				p.erect(wx, 160, 2, 1, P(Pal.WARM))
				p.erect(wx, 183, 2, 1, P(Pal.WARM))
		12:
			p.rect(8, 162, 44, 10, P(Pal.LGRAY))
			p.rect(9, 162, 42, 2, Color("2c3e5a"))
			p.rect(24, 174, 10, 8, P(Pal.RED))
		13:
			p.rect(25, 175, 8, 6, P(Pal.CHAR))
			p.rect(28, 163, 2, 4, P(Pal.GRAY))
			p.epx(29, 162, P(Pal.RED), Painter.EM_BLINK)


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


## Boulder: lumpy outline shrinking upwards, lit top, dark cracks and
## speckles; v = 0 grey granite, 1 sandstone, 2 granite with a snow cap.
static func _rock(p: Painter, s: int, v: int) -> void:
	var base: Color = [Color("8a8d94"), Color("c98a58"), Color("8a8d94")][v]
	var t := float(s) / 7.0
	var r := 6.2 * sqrt(1.0 - t * t * 0.92)
	for k in 10:
		var a := TAU * k / 10.0
		var w := 0.75 + 0.25 * CityGen.hashf(k, v, 41)
		var cx := 7.0 + cos(a) * r * 0.35 * w
		var cy := 7.0 + sin(a) * r * 0.3 * w
		p.ell(cx, cy, r * 0.72 * w, r * 0.62 * w, base.darkened(0.18 - t * 0.3))
	# top face: highlight towards the sun (top-left), cracks, speckles
	if s >= 5:
		p.ell(6.0, 6.0, r * 0.6, r * 0.5, base.lightened(0.12))
	for i in 6:
		var x := 2 + int(CityGen.hashf(i, s, 43 + v) * 10)
		var y := 2 + int(CityGen.hashf(i, s, 47 + v) * 10)
		p.px(x, y, base.darkened(0.35) if i % 2 == 0 else base.lightened(0.2))
	if s == 3:
		p.rect(4, 7, 5, 1, base.darkened(0.4))
	if v == 2 and s >= 5:
		p.ell(6.5, 6.0, r * 0.75, r * 0.6, Color("eef3fa"))
	elif v == 0 and s == 7:
		p.px(8, 8, Color("5f8a4a")) # a bit of moss


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
		p.px(5, 4, P(Pal.LGRAY)) # unlit lens


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


static func _parachute(p: Painter, s: int, v: int) -> void:
	# pilot (bottom), shroud lines, striped canopy dome (top)
	if s < 3:
		p.rect(12, 12, 2, 2, Color("f0580e") if s < 2 else Color("e8c99b"))
		if s == 1:
			p.rect(11, 12, 4, 1, Color("f0580e"))
	elif s < 9:
		var k := float(s - 3) / 5.0
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			p.px(int(13 + c.x * (1 + k * 9)), int(13 + c.y * (1 + k * 9)), Color("c2c3c7"))
	else:
		var r := 12.5 * sqrt(maxf(0.0, 1.0 - pow(float(s - 9) / 5.0, 2.0)))
		for seg in 8:
			var col := Color("f0580e") if seg % 2 == 0 else Color("f4f4f4")
			var a0 := TAU * seg / 8.0
			var a1 := TAU * (seg + 1) / 8.0
			p.poly(PackedVector2Array([Vector2(13, 13), Vector2(13 + cos(a0) * r, 13 + sin(a0) * r), Vector2(13 + cos(a1) * r, 13 + sin(a1) * r)]), col)


# ------------------------------------------------------------------ ejection

## Round parachute: 12 orange / white gores with dark seams, a vent at the
## top, hollow underside, suspension lines converging on the harness point.
static func _chute(p: Painter, s: int, v: int) -> void:
	var c := 24.0
	var orange := Color("f0580e")
	var white := Color("f2efe8")
	if s < 13:
		# lines: from the harness (centre) out to the canopy rim
		var r := 1.0 + 20.0 * pow(float(s) / 12.0, 1.15)
		for k in 12:
			var a := TAU * (k + 0.5) / 12.0
			p.px(int(round(c + cos(a) * r)), int(round(c + sin(a) * r)), Color("d8d4cc") if s % 3 else Color("a9a59c"))
		if s < 2:
			p.rect(22, 22, 4, 4, Color("3a3d44")) # risers / harness link
		return
	var k := float(s - 13) / 10.0
	var r_out := 21.5 * sqrt(maxf(0.0, 1.0 - k * k))
	var r_in := maxf(0.0, r_out - (2.5 if s < 20 else 99.0)) # hollow underneath
	var shade := lerpf(0.78, 1.0, k) # underside darker
	for y in 48:
		for x in 48:
			var dx := x + 0.5 - c
			var dy := y + 0.5 - c
			var d := sqrt(dx * dx + dy * dy)
			if d > r_out or d < r_in:
				continue
			if s == 23 and d < 2.5:
				continue # vent
			var a := fposmod(atan2(dy, dx), TAU)
			var gore := int(a / (TAU / 12.0))
			var col := orange if gore % 2 == 0 else white
			var edge := fposmod(a, TAU / 12.0)
			if edge < 0.06 or edge > TAU / 12.0 - 0.06:
				col = col.darkened(0.35) # seam
			if d > r_out - 1.0:
				col = col.darkened(0.18) # rim
			p.px(x, y, Color(col.r * shade, col.g * shade, col.b * shade))


## Pilot hanging in the harness (front = up in the image).
static func _pilot(p: Painter, s: int, v: int) -> void:
	var suit := Color("e2611f")
	match s:
		0, 1:
			p.rect(4, 6, 2, 3, Color("2a2a2e"))
			p.rect(8, 6, 2, 3, Color("2a2a2e"))
		2, 3, 4:
			p.rect(4, 5, 2, 4, Color("6b6a4a"))
			p.rect(8, 5, 2, 4, Color("6b6a4a"))
		5, 6, 7:
			p.rect(4, 4, 6, 5, suit)
			p.rect(4, 4, 6, 1, suit.lightened(0.2))
			p.rect(6, 4, 2, 5, Color("4a4c55")) # harness strap
			if s == 6:
				p.rect(2, 5, 2, 2, suit)
				p.rect(10, 5, 2, 2, suit)
		8:
			p.rect(4, 4, 6, 4, suit.darkened(0.1))
			p.rect(3, 5, 1, 2, Color("4a4c55"))
			p.rect(10, 5, 1, 2, Color("4a4c55"))
		9, 10:
			p.rect(5, 4, 4, 4, Color("eeeeea"))
			p.rect(5, 4, 4, 1, Color("1b2c3a")) # visor (front)
			if s == 10:
				p.rect(6, 5, 2, 2, Color("ffffff"))


## Rocket ejection seat with the pilot strapped in.
static func _eseat(p: Painter, s: int, v: int) -> void:
	var frame := Color("4d5058")
	var suit := Color("e2611f")
	match s:
		0, 1:
			p.rect(6, 7, 6, 6, Color("2b2d33"))
			p.erect(8, 9, 2, 2, Color("ffb43c"), Painter.EM_ALWAYS) # rocket nozzle
		2, 3:
			p.rect(5, 5, 8, 9, frame)
			p.rect(5, 5, 8, 1, frame.lightened(0.25))
			if s == 3:
				for x in range(6, 12, 2):
					p.px(x, 4, Color("f2c400"))
					p.px(x + 1, 4, Color("111111"))
		4, 5, 6:
			p.rect(5, 11, 8, 3, frame) # seat back
			p.rect(6, 6, 6, 6, suit)
			p.rect(8, 6, 2, 6, Color("4a4c55"))
		7, 8, 9:
			p.rect(5, 11, 8, 3, frame.lightened(0.1))
			p.rect(6, 8, 6, 4, suit.darkened(0.1))
		10:
			p.rect(5, 11, 8, 3, frame)
			p.rect(7, 7, 4, 4, Color("eeeeea"))
			p.rect(7, 7, 4, 1, Color("1b2c3a"))
		11:
			p.rect(6, 12, 6, 2, Color("6c6f78")) # headrest
			p.rect(8, 8, 2, 2, Color("ffffff"))


## Canopy: framed bubble with glass highlights.
static func _canopy(p: Painter, s: int, v: int) -> void:
	var frame := Color("3e424c")
	var glass := Color("6fb8d8")
	match s:
		0:
			p.rect(2, 1, 12, 24, frame)
			p.rect(4, 3, 8, 20, Color(0, 0, 0, 0))
		1, 2:
			p.rect(3, 2, 10, 22, glass if s == 1 else glass.lightened(0.15))
			p.rect(3, 9, 10, 1, frame)
			p.rect(3, 16, 10, 1, frame)
			p.rect(5, 3, 1, 5, Color(1, 1, 1, 0.9)) # glint
		3:
			p.rect(5, 4, 6, 18, glass.lightened(0.3))
			p.rect(6, 5, 1, 4, Color.WHITE)
