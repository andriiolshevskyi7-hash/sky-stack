class_name Intel
extends Control
## INTEL: pause screen listing every control, tabs Touch / Controller / Mouse+Keys.
## Tap a tab to switch, tap outside the panel (or CLOSE) to resume.

signal closed

const TABS := ["TOUCH", "CONTROLLER", "MOUSE + KEYS"]
const ROWS := {
	"TOUCH": [["FLY", ""], ["TURN", "Drag left or right"], ["CLIMB / DIVE", "Drag down to climb, up to dive"], ["THRUSTERS", "Hold BOOST"], ["CHANGE VIEW", "VIEW"],
		["TRICKS", ""], ["ROLL", "Tap"], ["BACK FLIP", "Full climb with thrusters, held"], ["FRONT FLIP", "Full dive with thrusters, held. Needs height"], ["LOOP", "LOOP (flown for you)"], ["EJECT", "Hold a dive into the ground, thrusters off"],
		["FIGHT", ""], ["CANNON", "Hold GUN"], ["LOCK ON", "Keep an enemy ahead until the box turns red"], ["MISSILE", "MISSILE"], ["DODGE A MISSILE", "Roll as the two rings meet"], ["COUNTER", "Missile straight after a dodge fires three, free"], ["AMMO", "300 rounds, 6 missiles. Run out and it takes 5 s to reload"]],
	"CONTROLLER": [["FLY", ""], ["TURN / PITCH", "Left stick"], ["THRUSTERS", "Right trigger"], ["CANNON", "A / Cross"], ["MISSILE", "B / Circle"], ["ROLL", "X / Square"], ["LOOP", "Y / Triangle"], ["VIEW", "Back / Select"], ["PAUSE", "Start"]],
	"MOUSE + KEYS": [["FLY", ""], ["TURN", "A / D or arrows"], ["CLIMB / DIVE", "S climbs, W dives"], ["THRUSTERS", "Shift"], ["CANNON", "Space, J or mouse button"], ["MISSILE", "M"], ["ROLL", "R"], ["LOOP", "L"], ["VIEW", "C or V"], ["PAUSE / INTEL", "Esc / I"]],
}

var tab := 0
var font: Font
var s := 1.0
var _panel := Rect2()
var _tabs: Array[Rect2] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	visible = false


func open(touch: bool) -> void:
	tab = 0 if touch else 2
	visible = true
	queue_redraw()


func _layout() -> void:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	var w := minf(vs.x - 40 * s, 900 * s)
	var h := vs.y - 120 * s
	_panel = Rect2(Vector2((vs.x - w) * 0.5, 90 * s), Vector2(w, h))
	_tabs.clear()
	var x := _panel.position.x + 20 * s
	for t in TABS:
		var tw: float = (t.length() * 13.0 + 30.0) * s
		_tabs.append(Rect2(Vector2(x, _panel.position.y + 16 * s), Vector2(tw, 38 * s)))
		x += tw + 10 * s


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.35))
	draw_rect(_panel, Color(0.07, 0.12, 0.25, 0.94))
	for i in TABS.size():
		var r := _tabs[i]
		draw_rect(r, Color(1, 1, 1, 0.95) if i == tab else Color(0.2, 0.28, 0.45, 0.9))
		_t(Vector2(r.position.x, r.position.y + 26 * s), TABS[i], 18, Color(0.05, 0.08, 0.18) if i == tab else Color.WHITE, r.size.x)
	_t(Vector2(_panel.end.x - 140 * s, _panel.position.y + 42 * s), "PAUSED", 18, Color(1, 1, 1, 0.6), 120 * s)
	var y := _panel.position.y + 90 * s
	var lh := 28.0 * s
	var rows: Array = ROWS[TABS[tab]]
	if rows.size() * lh > _panel.size.y - 140 * s:
		lh = (_panel.size.y - 140 * s) / rows.size()
	for r in rows:
		if r[1] == "":
			_t(Vector2(_panel.position.x + 30 * s, y), r[0], 15, Color(0.6, 0.7, 0.85), -1)
		else:
			_t(Vector2(_panel.position.x + 30 * s, y), r[0], 16, Color(0.85, 0.9, 1.0), -1)
			_t(Vector2(_panel.position.x + _panel.size.x * 0.38, y), r[1], 16, Color.WHITE, -1)
		y += lh
	_t(Vector2(_panel.position.x + 30 * s, _panel.end.y - 20 * s), "Tap outside to shut this. TUTORIAL flies you through it all.", 15, Color(0.6, 0.7, 0.85), -1)


func _t(p: Vector2, txt: String, size: float, col: Color, w: float) -> void:
	draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER if w > 0 else HORIZONTAL_ALIGNMENT_LEFT, w, int(size * s), col)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var p := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		p = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		visible = false
		closed.emit()
		return
	if p == Vector2.INF:
		return
	_layout()
	for i in _tabs.size():
		if _tabs[i].has_point(p):
			tab = i
			return
	if not _panel.has_point(p):
		visible = false
		closed.emit()
