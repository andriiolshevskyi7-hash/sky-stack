class_name Screens
extends Control
## Full-screen pre/post match screens drawn at full resolution:
##  lobby   - mode + map, both teams (names, skill tier), START / BACK
##  results - VICTORY / DEFEAT, team score, every pilot's K/A/D, damage,
##            base damage and score, MVP, XP + coins earned, rank progress

var font: Font
var s := 1.0
var page := ""
var info := {}
var _buttons: Array = [] # [Rect2, label, Callable, color]
var _t := 0.0

const BG := Color(0.05, 0.07, 0.13, 0.92)
const PANEL := Color(0.1, 0.13, 0.22, 0.95)
const BLUE := Color(0.4, 0.7, 1.0)
const RED := Color(1.0, 0.42, 0.38)
const GOLD := Color(1.0, 0.85, 0.35)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	visible = false


func show_page(p: String, p_info: Dictionary) -> void:
	page = p
	info = p_info
	_t = 0.0
	visible = true


func close() -> void:
	visible = false
	page = ""


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _txt(p: Vector2, t: String, size: float, col: Color, w: float = -1.0, al: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, p, t, al, w, int(size * s), col)


func _button(r: Rect2, label: String, cb: Callable, col: Color = Color(0.94, 0.35, 0.06)) -> void:
	_buttons.append([r, label, cb, col])
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3 * s)), col.lightened(0.25))
	_txt(Vector2(r.position.x, r.get_center().y + 9 * s), label, 24, Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw() -> void:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	_buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, vs), BG)
	match page:
		"lobby":
			_draw_lobby(vs)
		"results":
			_draw_results(vs)


func _team_list(x: float, y: float, w: float, team: Array, col: Color, title: String) -> void:
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 46 * s)), col.darkened(0.45))
	_txt(Vector2(x + 18 * s, y + 31 * s), title, 22, col)
	y += 54 * s
	var rh := minf(46.0 * s, (get_viewport_rect().size.y - y - 120 * s) / maxf(1.0, team.size()))
	for e in team:
		draw_rect(Rect2(Vector2(x, y), Vector2(w, rh - 6 * s)), PANEL)
		var nm: String = e["name"]
		var is_me: bool = e.get("player", false)
		_txt(Vector2(x + 18 * s, y + rh * 0.62), nm + ("  (YOU)" if is_me else ""), 19, GOLD if is_me else Color.WHITE)
		if not is_me:
			var lbl: String = Match.skill_label(e["skill"]) + "  " + BotBrain.ROLE_NAMES[e["role"]]
			_txt(Vector2(x, y + rh * 0.62), lbl, 14, Color(0.7, 0.75, 0.85), w - 18 * s, HORIZONTAL_ALIGNMENT_RIGHT)
		y += rh


func _draw_lobby(vs: Vector2) -> void:
	_txt(Vector2(0, 70 * s), info.get("mode_name", ""), 40, Color.WHITE, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 104 * s), "%s  -  %s     %s" % [info.get("map_name", ""), info.get("map_info", ""), info.get("mode_info", "")], 18, Color(0.75, 0.8, 0.9), vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	var roster: Array = info.get("roster", [[], []])
	var w := minf(560.0 * s, vs.x * 0.42)
	var gap := 40.0 * s
	var x0 := vs.x * 0.5 - w - gap * 0.5
	if not roster[0].is_empty():
		_team_list(x0, 130 * s, w, roster[0], BLUE, "BLUE TEAM")
		_team_list(vs.x * 0.5 + gap * 0.5, 130 * s, w, roster[1], RED, "RED TEAM")
	var bw := 260.0 * s
	var bh := 62.0 * s
	_button(Rect2(Vector2(vs.x * 0.5 + 10 * s, vs.y - bh - 24 * s), Vector2(bw, bh)), "START", info.get("on_start", Callable()))
	_button(Rect2(Vector2(vs.x * 0.5 - bw - 10 * s, vs.y - bh - 24 * s), Vector2(bw, bh)), "BACK", info.get("on_back", Callable()), Color(0.25, 0.3, 0.42))


func _draw_results(vs: Vector2) -> void:
	var title := "DRAW" if info.get("draw", false) else ("VICTORY" if info.get("won", false) else "DEFEAT")
	var tcol := Color(0.8, 0.8, 0.8) if info.get("draw", false) else (GOLD if info.get("won", false) else RED)
	_txt(Vector2(0, 72 * s), title, 52, tcol, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	var sc: Array = info.get("score", [0, 0])
	_txt(Vector2(0, 108 * s), "%s   %d  :  %d   %s" % ["BLUE", sc[0], sc[1], "RED"], 22, Color.WHITE, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	# table
	var rows: Array = info.get("rows", [])
	var w := minf(1100.0 * s, vs.x - 60 * s)
	var x := (vs.x - w) * 0.5
	var y := 130.0 * s
	var cols := [0.0, 0.46, 0.54, 0.62, 0.72, 0.84]
	var heads := ["PILOT", "K", "A", "D", "DMG", "SCORE"]
	for i in heads.size():
		_txt(Vector2(x + w * cols[i] + 10 * s, y + 20 * s), heads[i], 15, Color(0.65, 0.7, 0.8))
	y += 28 * s
	var rh := minf(34.0 * s, (vs.y - y - 210 * s) / maxf(1.0, rows.size()))
	for r in rows:
		var col := BLUE if r["team"] == 0 else RED
		draw_rect(Rect2(Vector2(x, y), Vector2(w, rh - 3 * s)), col.darkened(0.7) if not r["player"] else col.darkened(0.45))
		var nm: String = r["name"]
		if nm == info.get("mvp", ""):
			nm = "* " + nm + "  MVP"
		_txt(Vector2(x + 10 * s, y + rh * 0.7), nm, 17, GOLD if nm.ends_with("MVP") else Color.WHITE)
		var vals := [str(r["k"]), str(r["a"]), str(r["d"]), str(r["dmg"]) + ("+%d" % r["base"] if r["base"] > 0 else ""), str(r["score"])]
		for i in vals.size():
			_txt(Vector2(x + w * cols[i + 1] + 10 * s, y + rh * 0.7), vals[i], 17, Color.WHITE)
		y += rh
	# rewards
	y = vs.y - 190 * s
	var k := clampf(_t / 1.2, 0.0, 1.0)
	_txt(Vector2(0, y), "+%d XP     +%d COINS%s" % [int(info.get("xp", 0) * k), int(info.get("coins", 0) * k), "     MVP BONUS" if info.get("me_mvp", false) else ""], 26, GOLD, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	var bar := Rect2(Vector2(vs.x * 0.5 - 300 * s, y + 18 * s), Vector2(600 * s, 18 * s))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var f: float = lerpf(info.get("rank_from", 0.0), info.get("rank_to", 0.0), k)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fmod(f, 1.0) if info.get("rank_to", 0.0) - info.get("rank_from", 0.0) < 1.0 else f - floorf(f), 0.0, 1.0), bar.size.y)), BLUE)
	_txt(Vector2(0, y + 60 * s), info.get("rank_text", ""), 18, Color(0.8, 0.85, 0.95), vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	var bw := 260.0 * s
	var bh := 58.0 * s
	_button(Rect2(Vector2(vs.x * 0.5 + 10 * s, vs.y - bh - 18 * s), Vector2(bw, bh)), "PLAY AGAIN", info.get("on_again", Callable()))
	_button(Rect2(Vector2(vs.x * 0.5 - bw - 10 * s, vs.y - bh - 18 * s), Vector2(bw, bh)), "MENU", info.get("on_menu", Callable()), Color(0.25, 0.3, 0.42))


func button_center(label: String) -> Vector2:
	queue_redraw()
	for b in _buttons:
		if b[1] == label:
			return b[0].get_center()
	return Vector2(-1, -1)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var p := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		p = event.position
	if p == Vector2.INF:
		return
	for b in _buttons:
		if b[0].has_point(p):
			Sfx.play("ui")
			var cb: Callable = b[2]
			if cb.is_valid():
				cb.call_deferred()
			return
