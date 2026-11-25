class_name PixFont
## 3x5 pixel font (digits, A-Z, a few signs) for cockpit displays, labels
## and the HUD: crisp at the world's pixel size.

const GLYPHS := {
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7], "3": [7, 1, 7, 1, 7],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7], "6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 2, 2],
	"8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 7], "-": [0, 0, 7, 0, 0], " ": [0, 0, 0, 0, 0],
	".": [0, 0, 0, 0, 2], "%": [5, 1, 2, 4, 5], "/": [1, 1, 2, 4, 4], ":": [0, 2, 0, 2, 0],
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7], "F": [7, 4, 6, 4, 4], "G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5],
	"I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2], "K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7],
	"M": [5, 7, 7, 5, 5], "N": [6, 5, 5, 5, 5], "O": [2, 5, 5, 5, 2], "P": [6, 5, 6, 4, 4],
	"Q": [2, 5, 5, 6, 3], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2], "Z": [7, 1, 2, 4, 7],
}


static func width(t: String, sc: int = 1) -> int:
	return t.length() * 4 * sc - sc


## Draw text on a canvas item; sc = size of one glyph pixel.
static func draw(ci: CanvasItem, pos: Vector2, t: String, col: Color, center: bool = false, sc: int = 1) -> void:
	var adv := 4 * sc
	var x := floorf(pos.x - width(t, sc) * 0.5) if center else floorf(pos.x)
	var y := floorf(pos.y)
	for i in t.length():
		var g: Array = GLYPHS.get(t[i], GLYPHS[" "])
		for row in 5:
			var bits: int = g[row]
			for b in 3:
				if bits & (4 >> b):
					ci.draw_rect(Rect2(x + i * adv + b * sc, y + row * sc, sc, sc), col)
