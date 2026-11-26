class_name Intel
extends Control
## INTEL: pause screen listing every control, tabs Touch / Controller / Mouse+Keys.
## Tap a tab to switch, tap outside the panel (or CLOSE) to resume.

signal closed

const TABS := ["TOUCH", "CONTROLLER", "MOUSE + KEYS"]
const ROWS := {
	"TOUCH": [["FLY", ""], ["AIM", "Drag on the left half like a trackpad: the circle is where you fly"], ["NOSE", "The small cross is where the nose points; the instructor flies it onto the circle"], ["STICK SCHEME", "Settings: Controls - Stick (classic) puts a stick on the left half"], ["THROTTLE", "Drag the lever on the right edge; the top zone is afterburner"], ["LOOK AROUND", "Drag in the free area on the right; let go and the view returns"], ["CHANGE VIEW", "VIEW"],
		["ENERGY", "Climbing and hard turns cost speed, diving gains it"], ["PULL UP", "Low and diving: the instructor pulls up for you"], ["LOOP", "LOOP (flown for you)"], ["CRASH", "Hitting anything is fatal: the pilot ejects"],
		["FIGHT", ""], ["CANNON", "Hold FIRE; put the nose on the diamond to lead the target"], ["LOCK ON", "Keep an enemy ahead until the box turns red"], ["MISSILE", "MISSILE"], ["FLARES", "Double tap anywhere free. Best 1-2 s before the missile hits"], ["MISSILE DEFENCE", "Turn hard across its path: it bleeds energy and loses you"], ["AMMO", "300 rounds, 6 missiles. Run out and it takes 5 s to reload"]],
	"CONTROLLER": [["FLY", ""], ["TURN / PITCH", "Left stick"], ["THRUSTERS", "Right trigger"], ["CANNON", "A / Cross"], ["MISSILE", "B / Circle"], ["FLARES", "X / Square"], ["LOOP", "Y / Triangle"], ["VIEW", "Back / Select"], ["PAUSE", "Start"]],
	"MOUSE + KEYS": [["FLY", ""], ["AIM", "Move the mouse (aim scheme), or arrows / WASD"], ["TURN", "A / D or arrows (stick scheme)"], ["CLIMB / DIVE", "S climbs, W dives"], ["THROTTLE", "T / G or the mouse wheel"], ["CANNON", "Space, J or mouse button"], ["MISSILE", "M"], ["FLARES", "R"], ["LOOP", "L"], ["VIEW", "C or V"], ["LOOK AROUND", "Hold Q / E, or drag with the middle mouse button"], ["PAUSE / INTEL", "Esc / I"]],
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
	font = UI.base_font()
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
		var tw: float = UI.width(tr(t), UI.px(18 * s)) + 30.0 * s
		_tabs.append(Rect2(Vector2(x, _panel.position.y + 16 * s), Vector2(tw, 38 * s)))
		x += tw + 10 * s


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.35))
	UI.panel(self, _panel, s, Color(0.05, 0.08, 0.18, 0.94), UI.BORDER)
	for i in TABS.size():
		var r := _tabs[i]
		UI.button(self, r, tr(TABS[i]), s, UI.SELECTED if i == tab else UI.NORMAL, 18, "intel_tab_%d" % i)
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
	_t(Vector2(_panel.position.x + 30 * s, _panel.end.y - 20 * s), "Tap outside to shut this.", 15, Color(0.6, 0.7, 0.85), -1)


func _t(p: Vector2, txt: String, size: float, col: Color, w: float) -> void:
	UI.text(self, p, tr(txt), size * s, col, HORIZONTAL_ALIGNMENT_CENTER if w > 0 else HORIZONTAL_ALIGNMENT_LEFT, w)


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
			UI.press("intel_tab_%d" % i)
			tab = i
			return
	if not _panel.has_point(p):
		visible = false
		closed.emit()
