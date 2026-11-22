class_name Painter
extends RefCounted
## Tiny raster helper used by the procedural sprite generators.
## Draws into one slice cell (offset `ox`, size w x h) of a slice sheet image.
## Everything is built from scan-line fill_rect calls so it stays fast.

const EM_NIGHT := 1.0   ## emission alpha: only lit at night
const EM_ALWAYS := 0.66 ## emission alpha: always lit
const EM_BLINK := 0.33  ## emission alpha: blinking beacon

var img: Image
var emit: Image
var ox := 0
var w := 0
var h := 0


func _init(albedo: Image, emission: Image, cell_w: int, cell_h: int) -> void:
	img = albedo
	emit = emission
	w = cell_w
	h = cell_h


func _clip_fill(target: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	var x0 := clampi(x, 0, w)
	var y0 := clampi(y, 0, h)
	var x1 := clampi(x + rw, 0, w)
	var y1 := clampi(y + rh, 0, h)
	if x1 <= x0 or y1 <= y0:
		return
	target.fill_rect(Rect2i(ox + x0, y0, x1 - x0, y1 - y0), col)


func rect(x: int, y: int, rw: int, rh: int, col: Color) -> void:
	_clip_fill(img, x, y, rw, rh, col)


## Horizontally symmetric rect around the cell centre (cell width must be even
## for perfect symmetry). half = half width in pixels.
func srect(half: int, y0: int, y1: int, col: Color) -> void:
	var cx := w / 2
	_clip_fill(img, cx - half, y0, half * 2, y1 - y0, col)


func px(x: int, y: int, col: Color) -> void:
	if x >= 0 and x < w and y >= 0 and y < h:
		img.set_pixel(ox + x, y, col)


func ell(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	_ell_on(img, cx, cy, rx, ry, col)


func _ell_on(target: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		var dy := (float(y) + 0.5 - cy) / ry
		if absf(dy) > 1.0:
			continue
		var half := rx * sqrt(1.0 - dy * dy)
		var xa := int(round(cx - half))
		var xb := int(round(cx + half))
		if xb > xa:
			_clip_fill(target, xa, y, xb - xa, 1, col)


## Ring (outline ellipse) of thickness t.
func ring(cx: float, cy: float, r: float, t: float, col: Color) -> void:
	var y0 := int(floor(cy - r))
	var y1 := int(ceil(cy + r))
	for y in range(y0, y1 + 1):
		for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length()
			if d <= r and d >= r - t:
				px(x, y, col)


## Scan-line polygon fill (even-odd).
func poly(pts: PackedVector2Array, col: Color) -> void:
	_poly_on(img, pts, col)


func _poly_on(target: Image, pts: PackedVector2Array, col: Color) -> void:
	var miny := 1e9
	var maxy := -1e9
	for p in pts:
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var n := pts.size()
	for y in range(int(floor(miny)), int(ceil(maxy)) + 1):
		var sy := float(y) + 0.5
		var xs: Array[float] = []
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
				xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			var xa := int(round(xs[k]))
			var xb := int(round(xs[k + 1]))
			if xb > xa:
				_clip_fill(target, xa, y, xb - xa, 1, col)
			k += 2


## Mirror a polygon around the vertical centre line and fill both.
func mpoly(pts: PackedVector2Array, col: Color) -> void:
	poly(pts, col)
	var m := PackedVector2Array()
	for p in pts:
		m.append(Vector2(float(w) - p.x, p.y))
	poly(m, col)


func line(x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		px(x, y, col)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


# ---- emission (same coordinates; alpha encodes the emission class) ----

func erect(x: int, y: int, rw: int, rh: int, col: Color, cls: float = EM_NIGHT) -> void:
	var c := col
	c.a = cls
	_clip_fill(emit, x, y, rw, rh, c)
	_clip_fill(img, x, y, rw, rh, col.darkened(0.3))


func epx(x: int, y: int, col: Color, cls: float = EM_NIGHT) -> void:
	erect(x, y, 1, 1, col, cls)


func eell(cx: float, cy: float, rx: float, ry: float, col: Color, cls: float = EM_NIGHT) -> void:
	var c := col
	c.a = cls
	_ell_on(emit, cx, cy, rx, ry, c)
	_ell_on(img, cx, cy, rx, ry, col.darkened(0.3))
