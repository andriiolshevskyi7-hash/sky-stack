class_name Menu
extends Control
## Simple full-resolution overlay menu (title / pause / game over).
## Items: [[label (String or Callable->String), action Callable], ...]

var title := ""
var subtitle := ""
var lines: Array = [] # extra info lines (String or Callable)
var items: Array = []
var font: Font
var s := 1.0
var _rects: Array[Rect2] = []
var _hover := -1
var dim := 0.55
## If set, a tap anywhere outside the buttons triggers item 0 (title screen).
var tap_anywhere := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(p_title: String, p_sub: String, p_items: Array, p_lines: Array = [], p_dim: float = 0.55, p_tap_anywhere: bool = false) -> void:
	tap_anywhere = p_tap_anywhere
	title = p_title
	subtitle = p_sub
	items = p_items
	lines = p_lines
	dim = p_dim
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _str(v: Variant) -> String:
	if v is Callable:
		return (v as Callable).call()
	return str(v)


func _draw() -> void:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.08, dim))
	var y := vs.y * 0.2
	_ctext(vs.x * 0.5, y, title, 64, Color(1, 0.9, 0.45))
	y += 46 * s
	if subtitle != "":
		_ctext(vs.x * 0.5, y, subtitle, 22, Color(1, 1, 1, 0.85))
		y += 34 * s
	for l in lines:
		_ctext(vs.x * 0.5, y, _str(l), 20, Color(0.8, 0.95, 1.0))
		y += 28 * s
	layout()
	for i in _rects.size():
		var r := _rects[i]
		draw_rect(r, Color(0.1, 0.14, 0.28, 0.9) if i != _hover else Color(0.2, 0.3, 0.55, 0.95))
		draw_rect(r, Color(0.6, 0.8, 1.0, 0.8), false, 2.0 * s)
		_ctext(vs.x * 0.5, r.position.y + r.size.y * 0.68, _str(items[i][0]), 24, Color.WHITE)


## Button rects in screen pixels. Computed independently of drawing so input
## works even before the first frame is drawn.
func layout() -> void:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	var y := vs.y * 0.2 + 46 * s
	if subtitle != "":
		y += 34 * s
	y += 28 * s * lines.size() + 14 * s
	_rects.clear()
	var bw := 420.0 * s
	var bh := 54.0 * s
	for i in items.size():
		_rects.append(Rect2(Vector2(vs.x * 0.5 - bw * 0.5, y), Vector2(bw, bh)))
		y += bh + 12 * s


func button_center(i: int) -> Vector2:
	layout()
	return _rects[i].get_center() if i < _rects.size() else Vector2.ZERO


func _ctext(cx: float, y: float, t: String, size: float, col: Color) -> void:
	t = tr(t)
	var fs := int(size * s)
	var w := get_viewport_rect().size.x
	draw_string_outline(font, Vector2(cx - w * 0.5, y), t, HORIZONTAL_ALIGNMENT_CENTER, w, fs, maxi(2, int(5 * s)), Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(cx - w * 0.5, y), t, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)


## Handles touch DIRECTLY (InputEventScreenTouch) so it never depends on
## touch->mouse emulation or GUI picking. Real mouse clicks also work; mouse
## events emulated from touch are ignored to avoid double activation.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var p := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		p = event.position
	elif event is InputEventMouseMotion:
		_hover = _hit(event.position)
		return
	else:
		return
	var i := _hit(p)
	if i < 0 and tap_anywhere and not items.is_empty():
		i = 0
	if i >= 0:
		Sfx.play("ui")
		var cb: Callable = items[i][1]
		cb.call_deferred()
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and not event.echo and (event as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if not items.is_empty():
			Sfx.play("ui")
			(items[0][1] as Callable).call()


func _hit(p: Vector2) -> int:
	layout()
	for i in _rects.size():
		if _rects[i].has_point(p):
			return i
	return -1
