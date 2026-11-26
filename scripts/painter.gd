class_name Painter
extends RefCounted
## Raster helper used by the procedural sprite generators.
## Draws into one slice cell (offset `ox`, size w x h) of a slice sheet image.
## HD voxel: the generators keep drawing in "art pixels" (w x h), but every
## shape is rasterised K times finer (polygons, ellipses, rings and lines get
## smooth edges instead of up-scaled steps); detail() then adds texel-level
## bevels, edge darkening and surface grain at the fine resolution.
## Everything is built from scan-line fill_rect calls so it stays fast.

const EM_NIGHT := 1.0   ## emission alpha: only lit at night
const EM_ALWAYS := 0.66 ## emission alpha: always lit
const EM_BLINK := 0.33  ## emission alpha: blinking beacon

var img: Image
var emit: Image
var ox := 0 ## cell offset in art pixels
var w := 0 ## cell size in art pixels
var h := 0
var k := 1 ## texels per art pixel


func _init(albedo: Image, emission: Image, cell_w: int, cell_h: int, texels: int = 1) -> void:
	img = albedo
	emit = emission
	w = cell_w
	h = cell_h
	k = texels


## Fill a rectangle given in fine texels (cell space), clipped to the cell.
func _fill_t(target: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	x0 = clampi(x0, 0, w * k)
	y0 = clampi(y0, 0, h * k)
	x1 = clampi(x1, 0, w * k)
	y1 = clampi(y1, 0, h * k)
	if x1 <= x0 or y1 <= y0:
		return
	target.fill_rect(Rect2i(ox * k + x0, y0, x1 - x0, y1 - y0), col)


func _clip_fill(target: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	_fill_t(target, x * k, y * k, (x + rw) * k, (y + rh) * k, col)


func rect(x: int, y: int, rw: int, rh: int, col: Color) -> void:
	_clip_fill(img, x, y, rw, rh, col)


## Horizontally symmetric rect around the cell centre (cell width must be even
## for perfect symmetry). half = half width in pixels.
func srect(half: int, y0: int, y1: int, col: Color) -> void:
	var cx := w / 2
	_clip_fill(img, cx - half, y0, half * 2, y1 - y0, col)


func px(x: int, y: int, col: Color) -> void:
	_clip_fill(img, x, y, 1, 1, col)


func ell(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	_ell_on(img, cx, cy, rx, ry, col)


func _ell_on(target: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var kc := float(k)
	var tcx := cx * kc
	var tcy := cy * kc
	var trx := rx * kc
	var try_ := ry * kc
	for y in range(int(floor(tcy - try_)), int(ceil(tcy + try_)) + 1):
		var dy := (float(y) + 0.5 - tcy) / try_
		if absf(dy) > 1.0:
			continue
		var half := trx * sqrt(1.0 - dy * dy)
		var xa := int(round(tcx - half))
		var xb := int(round(tcx + half))
		if xb > xa:
			_fill_t(target, xa, y, xb, y + 1, col)


## Ring (outline ellipse) of thickness t.
func ring(cx: float, cy: float, r: float, t: float, col: Color) -> void:
	var kc := float(k)
	var tcx := cx * kc
	var tcy := cy * kc
	var tr := r * kc
	var tt := t * kc
	for y in range(int(floor(tcy - tr)), int(ceil(tcy + tr)) + 1):
		for x in range(int(floor(tcx - tr)), int(ceil(tcx + tr)) + 1):
			var d := Vector2(float(x) + 0.5 - tcx, float(y) + 0.5 - tcy).length()
			if d <= tr and d >= tr - tt:
				_fill_t(img, x, y, x + 1, y + 1, col)


## Scan-line polygon fill (even-odd).
func poly(pts: PackedVector2Array, col: Color) -> void:
	_poly_on(img, pts, col)


func _poly_on(target: Image, pts: PackedVector2Array, col: Color) -> void:
	var kc := float(k)
	var miny := 1e9
	var maxy := -1e9
	for p in pts:
		miny = minf(miny, p.y * kc)
		maxy = maxf(maxy, p.y * kc)
	var n := pts.size()
	for y in range(int(floor(miny)), int(ceil(maxy)) + 1):
		var sy := float(y) + 0.5
		var xs: Array[float] = []
		for i in n:
			var a := pts[i] * kc
			var b := pts[(i + 1) % n] * kc
			if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
				xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var j := 0
		while j + 1 < xs.size():
			var xa := int(round(xs[j]))
			var xb := int(round(xs[j + 1]))
			if xb > xa:
				_fill_t(target, xa, y, xb, y + 1, col)
			j += 2


## Mirror a polygon around the vertical centre line and fill both.
func mpoly(pts: PackedVector2Array, col: Color) -> void:
	poly(pts, col)
	var m := PackedVector2Array()
	for p in pts:
		m.append(Vector2(float(w) - p.x, p.y))
	poly(m, col)


## One art pixel wide line between art pixel centres, drawn on the fine
## grid (smooth diagonals).
func line(x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var a := Vector2(x0 + 0.5, y0 + 0.5) * k
	var b := Vector2(x1 + 0.5, y1 + 0.5) * k
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	var half := k * 0.5
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var tx := int(floor(p.x - half + 0.5))
		var ty := int(floor(p.y - half + 0.5))
		_fill_t(img, tx, ty, tx + k, ty + k, col)


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


## HD detail pass over a whole slice-strip image (fine texels): a soft
## darker rim where a slice ends (reads as the voxel's edge), a one-texel
## bevel at boundaries between materials (light on the upper-left, dark on
## the lower-right) and a little grain, so surfaces get texture at the fine
## resolution. Emissive texels are left alone.
static func detail(albedo: Image, emission: Image, cell_w_t: int) -> void:
	var tw := albedo.get_width()
	var th := albedo.get_height()
	var a := albedo.get_data()
	var e := emission.get_data()
	var o := a.duplicate()
	for y in th:
		for x in tw:
			var i := (y * tw + x) * 4
			if a[i + 3] < 128 or e[i + 3] > 0:
				continue
			var cx := x % cell_w_t
			var c := a.decode_u32(i)
			var edge := false
			var lit := 0
			# neighbours inside the same cell
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx := cx + d.x
				var ny := y + d.y
				if nx < 0 or nx >= cell_w_t or ny < 0 or ny >= th:
					edge = true
					continue
				var j := ((ny * tw) + (x + d.x)) * 4
				if a[j + 3] < 128:
					edge = true
				elif a.decode_u32(j) != c and e[j + 3] == 0:
					lit += 1 if (d.x > 0 or d.y > 0) else -1
			var f := 1.0
			if edge:
				f = 0.88
			elif lit > 0:
				f = 0.9 # boundary on the right / below: the shape's dark side
			elif lit < 0:
				f = 1.07 # boundary on the left / above: the lit side
			# grain: two octaves of per-texel hash
			var hh := ((x * 73856093) ^ (y * 19349663)) & 1023
			f *= 0.97 + float(hh) / 1023.0 * 0.06
			for ch in 3:
				o[i + ch] = clampi(int(a[i + ch] * f), 0, 255)
	albedo.set_data(tw, th, false, Image.FORMAT_RGBA8, o)
