class_name UI
## Shared pixel-art UI style (menus, screens, settings, INTEL, HUD):
##  font    - Tiny5 pixel font (Latin + Cyrillic, OFL), no antialiasing, no
##            hinting, sizes snapped to multiples of 8 px so every font pixel
##            is a whole number of screen pixels, wide letter spacing
##  panels  - dark navy, semi-transparent, sharp corners, 1-2 px lighter border
##  buttons - normal (navy), primary (orange #F0580E), selected (white fill,
##            dark text), disabled (dim); pressed = darker + a small bounce
##  motion  - panel slide-in, coin counter ticking up, rank-up flash

const NAVY := Color(0.05, 0.08, 0.18, 0.88)
const NAVY_HI := Color(0.13, 0.19, 0.36, 0.94)
const BORDER := Color(0.62, 0.74, 0.98, 0.9)
const BORDER_DIM := Color(0.42, 0.52, 0.76, 0.7)
const ORANGE := Color("f0580e")
const ORANGE_HI := Color("ff8a3c")
const WHITE_FILL := Color(0.94, 0.95, 0.97)
const INK := Color(0.05, 0.08, 0.18)
const TEXT := Color(0.93, 0.95, 1.0)
const MUTED := Color(0.62, 0.7, 0.86)
const GOLD := Color(1.0, 0.84, 0.35)
const RED := Color(1.0, 0.42, 0.38)
const BLUE := Color(0.4, 0.7, 1.0)
const GREEN := Color(0.35, 0.85, 0.45)

enum { NORMAL, PRIMARY, SELECTED, DISABLED, GOOD }

static var _base: Font
static var _cache := {}
static var _press := {}
static var _coins := -1.0
static var _coins_ms := 0


static func _load_face(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	f.multichannel_signed_distance_field = false
	return f


## Tiny5 Latin with Latin-ext and Cyrillic as fallbacks, then the engine
## font for anything else (never a missing glyph).
static func base_font() -> Font:
	if _base == null:
		var lat := _load_face("res://assets/fonts/tiny5-latin.woff2")
		var ext := _load_face("res://assets/fonts/tiny5-latin-ext.woff2")
		var cyr := _load_face("res://assets/fonts/tiny5-cyrillic.woff2")
		lat.fallbacks = [cyr, ext, ThemeDB.fallback_font]
		_base = lat
	return _base


## Smallest text: 2 screen pixels per font pixel on phones (readable on a
## 6.8" screen), 1 on small desktop windows.
static func min_px() -> int:
	# Tiny5 capitals are 5/8 of the font size: 24 px on a 1344 px tall phone
	# gives 15 px capitals (~0.8 mm), 16 px on 1008, 8 px on small windows
	var h := float(DisplayServer.window_get_size().y)
	return 8 * maxi(1, int(round(h / 480.0)))


## All text is drawn this much bigger than the layout sizes ask for.
const SCALE := 1.25


## Font size snapped to the 8 px pixel grid of the font.
static func px(size: float) -> int:
	return maxi(min_px(), int(round(size * SCALE / 8.0)) * 8)


## Split text into lines no wider than w at a font size (word wrap; a single
## over-long word stays on its own line).
static func wrap_lines(t: String, size: float, w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in t.split(" ", false):
		var trial := word if cur == "" else cur + " " + word
		if cur != "" and width(trial, size) > w:
			out.append(cur)
			cur = word
		else:
			cur = trial
	if cur != "" or out.is_empty():
		out.append(cur)
	return out


## Text that wraps onto more lines instead of shrinking. `pos` is the
## baseline of a single line; extra lines are centred around it, grow
## downwards (down = 1) or upwards so the last line sits on pos (down = -1). Only if it would need more than max_lines
## does the size step down. Returns the number of lines drawn.
static func text_wrap(ci: CanvasItem, pos: Vector2, t: String, size: float, col: Color, w: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, max_lines: int = 2, down: int = 0, outline: int = 0) -> int:
	var fs := float(px(size))
	var lines := wrap_lines(t, fs, w)
	# only when it cannot wrap (too many lines, or one word wider than w)
	# does the size step down
	while (lines.size() > max_lines or _widest(lines, fs) > w) and fs > float(min_px()):
		fs -= 8.0
		lines = wrap_lines(t, fs, w)
	var lh := fs * 1.05
	var y0 := pos.y - (lines.size() - 1) * lh * 0.5
	if down > 0:
		y0 = pos.y
	elif down < 0:
		y0 = pos.y - (lines.size() - 1) * lh
	for i in lines.size():
		var lp := Vector2(pos.x, y0 + i * lh)
		_text_px(ci, lp, lines[i], int(fs), col, align, w, outline)
	return lines.size()


static func _widest(lines: PackedStringArray, fs: float) -> float:
	var m := 0.0
	for l in lines:
		m = maxf(m, width(l, fs))
	return m


static func _text_px(ci: CanvasItem, pos: Vector2, t: String, fs: int, col: Color, align: HorizontalAlignment, w: float, outline: int) -> void:
	var f := font(fs)
	pos = pos.round()
	if outline > 0:
		ci.draw_string_outline(f, pos, t, align, w, fs, outline, Color(0, 0, 0, 0.75))
	ci.draw_string(f, pos, t, align, w, fs, col)


## Font at a snapped size with wide letter spacing (one font pixel).
static func font(size_px: int) -> Font:
	if not _cache.has(size_px):
		var fv := FontVariation.new()
		fv.base_font = base_font()
		fv.spacing_glyph = maxi(1, size_px / 8)
		fv.spacing_space = maxi(1, size_px / 8)
		_cache[size_px] = fv
	return _cache[size_px]


## Width of t at an already snapped pixel size.
static func width(t: String, fs_px: float) -> float:
	var fs := int(fs_px)
	return font(fs).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Largest snapped size <= size at which t fits in w (returned as a layout
## size, i.e. already divided by SCALE).
static func fit(t: String, size: float, w: float) -> float:
	var fs := float(px(size))
	while fs > float(min_px()) and width(t, fs) > w:
		fs -= 8.0
	return fs / SCALE


static func text(ci: CanvasItem, pos: Vector2, t: String, size: float, col: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0, outline: int = 0) -> void:
	var fs := px(size)
	var f := font(fs)
	pos = pos.round()
	if outline > 0:
		ci.draw_string_outline(f, pos, t, align, w, fs, outline, Color(0, 0, 0, 0.75))
	ci.draw_string(f, pos, t, align, w, fs, col)


## Border thickness: 1 px on small screens, 2 px on big ones.
static func bw(s: float) -> float:
	return 2.0 if s >= 1.2 else 1.0


static func frame(ci: CanvasItem, r: Rect2, s: float, col: Color) -> void:
	r = Rect2(r.position.round(), r.size.round())
	var b := bw(s)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, b)), col)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - b), Vector2(r.size.x, b)), col)
	ci.draw_rect(Rect2(r.position, Vector2(b, r.size.y)), col)
	ci.draw_rect(Rect2(Vector2(r.end.x - b, r.position.y), Vector2(b, r.size.y)), col)


static func panel(ci: CanvasItem, r: Rect2, s: float, fill: Color = NAVY, border: Color = BORDER) -> void:
	ci.draw_rect(Rect2(r.position.round(), r.size.round()), fill)
	frame(ci, r, s, border)


## Remember a press (for the bounce + darker pressed look).
static func press(key: String) -> void:
	_press[key] = Time.get_ticks_msec()


## 0..1..0 over 180 ms after a press.
static func bounce(key: String) -> float:
	var dt := (Time.get_ticks_msec() - int(_press.get(key, -100000))) / 1000.0
	return sin(clampf(dt / 0.18, 0.0, 1.0) * PI) if dt < 0.18 else 0.0


static func button(ci: CanvasItem, r: Rect2, label: String, s: float, kind: int = NORMAL, size: float = 20.0, key: String = "") -> void:
	var k := bounce(key if key != "" else label)
	r = r.grow(-minf(r.size.x, r.size.y) * 0.05 * k)
	var fill := NAVY
	var border := BORDER
	var col := TEXT
	match kind:
		PRIMARY:
			fill = ORANGE
			border = ORANGE_HI
		SELECTED:
			fill = WHITE_FILL
			border = Color.WHITE
			col = INK
		DISABLED:
			fill = Color(0.12, 0.14, 0.2, 0.85)
			border = BORDER_DIM
			col = MUTED
		GOOD:
			fill = Color(0.12, 0.42, 0.22, 0.95)
			border = GREEN
	if k > 0.0:
		fill = fill.darkened(0.25)
	panel(ci, r, s, fill, border)
	# long labels wrap onto two lines (centred) instead of shrinking
	var fs := float(px(size * s))
	text_wrap(ci, Vector2(r.position.x + 6.0 * s, r.get_center().y + fs * 0.34), label, size * s, col, r.size.x - 12.0 * s, HORIZONTAL_ALIGNMENT_CENTER, 2)


## Slide-in offset (px) for a panel opened `t` seconds ago.
static func slide(t: float, s: float) -> float:
	var k := clampf(t / 0.28, 0.0, 1.0)
	return (1.0 - (1.0 - pow(1.0 - k, 3.0))) * 40.0 * s


## Coin counter that ticks up/down towards the real value.
static func coins_shown(real: int) -> int:
	var now := Time.get_ticks_msec()
	var dt := minf(0.1, (now - _coins_ms) / 1000.0)
	_coins_ms = now
	if _coins < 0.0:
		_coins = real
	var diff := real - _coins
	_coins += signf(diff) * minf(absf(diff), maxf(1.0, absf(diff) * 6.0 * dt) + 40.0 * dt)
	return int(round(_coins))
