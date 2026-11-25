class_name Menu
extends Control
## Simple full-resolution overlay menu (title / pause / game over).
## Items: [[label (String or Callable->String), action Callable, badge
## Callable->bool (optional, red dot)], ...]. More than 5 items -> 2 columns.

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
## Main menu: rank badge + coins bar across the top.
var status_bar := false
var _open_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = UI.base_font()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(p_title: String, p_sub: String, p_items: Array, p_lines: Array = [], p_dim: float = 0.55, p_tap_anywhere: bool = false, p_status: bool = false) -> void:
	tap_anywhere = p_tap_anywhere
	status_bar = p_status
	_open_t = 0.0
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
	_open_t += get_process_delta_time()
	if status_bar:
		_draw_main(vs)
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.08, dim))
	var off := UI.slide(_open_t, s)
	var y := vs.y * 0.2 + off
	_ctext(vs.x * 0.5, y, title, 56, UI.GOLD)
	y += 46 * s
	if subtitle != "":
		_ctext(vs.x * 0.5, y, subtitle, 24, UI.TEXT)
		y += 34 * s
	for l in lines:
		_ctext(vs.x * 0.5, y, _str(l), 16, UI.MUTED)
		y += 28 * s
	layout()
	for i in _rects.size():
		var r := _rects[i]
		r.position.y += off
		var label := tr(_str(items[i][0]))
		var kind := UI.SELECTED if i == _hover else (UI.PRIMARY if i == 0 else UI.NORMAL)
		UI.button(self, r, label, s, kind, 24, "menu_%d" % i)
		if items[i].size() > 2 and (items[i][2] as Callable).call():
			_badge(r.position + Vector2(r.size.x - 10 * s, 10 * s))
	if status_bar:
		_draw_status(vs)


## Main menu (War Thunder style): the 3D plane fills the screen behind;
## buttons in a column on the left over a soft dark gradient, the game title
## above them, the selected plane's name and class bottom right.
func _draw_main(vs: Vector2) -> void:
	var gw := 560.0 * s
	for i in 16:
		var a := 0.62 * (1.0 - i / 16.0)
		draw_rect(Rect2(i * gw / 16.0, 0, gw / 16.0 + 1, vs.y), Color(0.02, 0.03, 0.08, a))
	var off := UI.slide(_open_t, s)
	UI.text(self, Vector2(48 * s, 150 * s + off), tr(title), 56 * s, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(2, int(4 * s)))
	if subtitle != "":
		UI.text(self, Vector2(50 * s, 188 * s + off), tr(subtitle), 20 * s, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	layout()
	for i in _rects.size():
		var r := _rects[i]
		r.position.x += off
		var label := tr(_str(items[i][0]))
		var kind := UI.SELECTED if i == _hover else (UI.PRIMARY if i == 0 else UI.NORMAL)
		UI.button(self, r, label, s, kind, 26, "menu_%d" % i)
		if items[i].size() > 2 and (items[i][2] as Callable).call():
			_badge(r.position + Vector2(r.size.x - 10 * s, 10 * s))
	# selected plane: name, code and class
	var pi := Profile.plane_index()
	var d: Dictionary = Planes.LIST[pi]
	var name_y := vs.y - 70 * s
	UI.text(self, Vector2(0, name_y), str(d["name"]), 48 * s, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 48 * s, maxi(2, int(4 * s)))
	UI.text(self, Vector2(0, name_y + 36 * s), "%s  ·  %s" % [d["code"], tr(Planes.BRANCH_NAMES[int(d["branch"])])], 20 * s, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 50 * s, 2)
	_draw_status(vs)


## Red "something to claim" dot, pixel style.
func _badge(c: Vector2) -> void:
	var r := Rect2((c - Vector2(7, 7) * s).round(), (Vector2(14, 14) * s).round())
	draw_rect(r, Color(0.95, 0.2, 0.15))
	UI.frame(self, r, s, Color(1, 0.75, 0.7))


func _draw_status(vs: Vector2) -> void:
	var rk := Profile.rank_of(Profile.xp())
	var rc: Color = Profile.rank_color(rk[0])
	var r := Rect2(Vector2(20 * s, 16 * s), Vector2(300 * s, 52 * s))
	UI.panel(self, r, s, UI.NAVY, rc)
	UI.text(self, r.position + Vector2(14 * s, 26 * s), tr(Profile.RANKS[rk[0]]), 16 * s, rc)
	var bar := Rect2((r.position + Vector2(14 * s, 34 * s)).round(), Vector2(r.size.x - 28 * s, 8 * s).round())
	draw_rect(bar, Color(0, 0, 0, 0.5))
	if rk[2] > 0:
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * float(rk[1]) / rk[2]), bar.size.y)), rc)
	var cr := Rect2(Vector2(vs.x - 300 * s, 16 * s), Vector2(280 * s, 52 * s))
	UI.panel(self, cr, s, UI.NAVY, UI.GOLD)
	UI.text(self, cr.position + Vector2(0, 34 * s), tr("COINS %d") % UI.coins_shown(Profile.coins()), 24 * s, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)


## Button rects in screen pixels. Computed independently of drawing so input
## works even before the first frame is drawn.
func layout() -> void:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	_rects.clear()
	if status_bar:
		# main menu: one column on the left
		var bw0 := 400.0 * s
		var bh0 := 62.0 * s
		var y0 := 226.0 * s
		var gap := minf(14.0 * s, (vs.y - y0 - 24.0 * s - bh0 * items.size()) / maxf(1.0, items.size() - 1))
		for i in items.size():
			_rects.append(Rect2(Vector2(48 * s, y0 + i * (bh0 + gap)), Vector2(bw0, bh0)))
		return
	var y := vs.y * 0.2 + 46 * s
	if subtitle != "":
		y += 34 * s
	y += 28 * s * lines.size() + 14 * s
	_rects.clear()
	var bh := 54.0 * s
	if items.size() > 5:
		# two columns
		var bw := 340.0 * s
		var rows := (items.size() + 1) / 2
		for i in items.size():
			var col := i / rows
			var row := i % rows
			_rects.append(Rect2(Vector2(vs.x * 0.5 + (-bw - 8 * s if col == 0 else 8 * s), y + row * (bh + 12 * s)), Vector2(bw, bh)))
		return
	var bw := 420.0 * s
	for i in items.size():
		_rects.append(Rect2(Vector2(vs.x * 0.5 - bw * 0.5, y), Vector2(bw, bh)))
		y += bh + 12 * s


func button_center(i: int) -> Vector2:
	layout()
	return _rects[i].get_center() if i < _rects.size() else Vector2.ZERO


func _ctext(cx: float, y: float, t: String, size: float, col: Color) -> void:
	t = tr(t)
	var w0 := get_viewport_rect().size.x
	UI.text(self, Vector2(cx - w0 * 0.5, y), t, UI.fit(t, size * s, w0 - 40 * s), col, HORIZONTAL_ALIGNMENT_CENTER, w0, maxi(2, int(4 * s)))


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
		UI.press("menu_%d" % i)
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
