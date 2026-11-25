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


var _name_edit: LineEdit


func _ready() -> void:
	_name_edit = LineEdit.new()
	_name_edit.visible = false
	_name_edit.max_length = 16
	_name_edit.text_submitted.connect(func(t: String) -> void: _finish_name())
	_name_edit.focus_exited.connect(_finish_name)
	add_child(_name_edit)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = UI.base_font()
	visible = false


func show_page(p: String, p_info: Dictionary) -> void:
	page = p
	info = p_info
	_t = 0.0
	visible = true


func close() -> void:
	visible = false
	page = ""
	if _name_edit != null:
		_name_edit.visible = false


func _finish_name() -> void:
	if _name_edit.visible:
		Profile.set_player_name(_name_edit.text)
		_name_edit.visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _txt(p: Vector2, t: String, size: float, col: Color, w: float = -1.0, al: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	UI.text(self, p, tr(t), size * s, col, al, w)


## Button style from the colour the caller asked for (orange = primary).
static func _kind(col: Color) -> int:
	if col.r > 0.85 and col.g < 0.5:
		return UI.PRIMARY
	if col.g > col.r + 0.2 and col.g > col.b:
		return UI.GOOD
	if absf(col.r - col.g) < 0.05 and absf(col.g - col.b) < 0.1 and col.r < 0.35:
		return UI.DISABLED
	return UI.NORMAL


func _button(r: Rect2, label: String, cb: Callable, col: Color = Color(0.94, 0.35, 0.06)) -> void:
	_buttons.append([r, label, cb, col])
	UI.button(self, r, tr(label), s, _kind(col), 24, label)


## Card / row background in the pixel style; selected = white border.
func _card(r: Rect2, selected: bool = false) -> void:
	UI.panel(self, r, s, UI.NAVY_HI if selected else UI.NAVY, Color.WHITE if selected else UI.BORDER_DIM)


var _xf := Transform2D.IDENTITY
var _page_t := 0.0
var _last_page := ""


func _draw() -> void:
	var vs := get_viewport_rect().size
	s = clampf(vs.y / 720.0, 0.6, 3.0)
	_buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, vs), BG)
	# panel slide-in when a page opens
	if page != _last_page:
		_last_page = page
		_page_t = 0.0
	_page_t += get_process_delta_time()
	_xf = Transform2D(0.0, Vector2(0, UI.slide(_page_t, s)))
	draw_set_transform_matrix(_xf)
	match page:
		"lobby":
			_draw_lobby(vs)
		"results":
			_draw_results(vs)
		"hangar":
			_draw_hangar(vs)
		"missions":
			_draw_missions(vs)
		"profile":
			_draw_profile(vs)
		"skins":
			_draw_skins(vs)


func _team_list(x: float, y: float, w: float, team: Array, col: Color, title: String) -> void:
	UI.panel(self, Rect2(Vector2(x, y), Vector2(w, 46 * s)), s, col.darkened(0.6), col)
	_txt(Vector2(x + 18 * s, y + 31 * s), title, 22, col)
	y += 54 * s
	var rh := minf(46.0 * s, (get_viewport_rect().size.y - y - 120 * s) / maxf(1.0, team.size()))
	for e in team:
		_card(Rect2(Vector2(x, y), Vector2(w, rh - 6 * s)))
		var nm: String = e["name"]
		var is_me: bool = e.get("player", false)
		_txt(Vector2(x + 18 * s, y + rh * 0.62), nm + (("  " + tr("(YOU)")) if is_me else ""), 19, GOLD if is_me else Color.WHITE)
		if not is_me:
			var lbl: String = tr(Match.skill_label(e["skill"])) + "  " + tr(BotBrain.ROLE_NAMES[e["role"]])
			_txt(Vector2(x, y + rh * 0.62), lbl, 14, Color(0.7, 0.75, 0.85), w - 18 * s, HORIZONTAL_ALIGNMENT_RIGHT)
		y += rh


func _draw_lobby(vs: Vector2) -> void:
	_txt(Vector2(0, 70 * s), info.get("mode_name", ""), 40, Color.WHITE, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 104 * s), "%s  -  %s     %s" % [tr(info.get("map_name", "")), tr(info.get("map_info", "")), tr(info.get("mode_info", ""))], 18, Color(0.75, 0.8, 0.9), vs.x, HORIZONTAL_ALIGNMENT_CENTER)
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
	_txt(Vector2(0, 108 * s), "%s   %d  :  %d   %s" % [tr("BLUE"), sc[0], sc[1], tr("RED")], 22, Color.WHITE, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
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
		var is_mvp: bool = nm == info.get("mvp", "")
		if is_mvp:
			nm = "* " + nm + "  " + tr("MVP")
		_txt(Vector2(x + 10 * s, y + rh * 0.7), nm, 17, GOLD if is_mvp else Color.WHITE)
		var vals := [str(r["k"]), str(r["a"]), str(r["d"]), str(r["dmg"]) + ("+%d" % r["base"] if r["base"] > 0 else ""), str(r["score"])]
		for i in vals.size():
			_txt(Vector2(x + w * cols[i + 1] + 10 * s, y + rh * 0.7), vals[i], 17, Color.WHITE)
		y += rh
	# rewards
	y = vs.y - 190 * s
	var k := clampf(_t / 1.2, 0.0, 1.0)
	_txt(Vector2(0, y), tr("+%d XP     +%d COINS") % [int(info.get("xp", 0) * k), int(info.get("coins", 0) * k)] + (("     " + tr("MVP BONUS")) if info.get("me_mvp", false) else ""), 26, GOLD, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	var bar := Rect2(Vector2(vs.x * 0.5 - 300 * s, y + 18 * s), Vector2(600 * s, 18 * s))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var f: float = lerpf(info.get("rank_from", 0.0), info.get("rank_to", 0.0), k)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fmod(f, 1.0) if info.get("rank_to", 0.0) - info.get("rank_from", 0.0) < 1.0 else f - floorf(f), 0.0, 1.0), bar.size.y)), BLUE)
	var rank_col := Color(0.8, 0.85, 0.95)
	if info.get("rank_up", false) and _t > 1.2:
		# rank-up flash: white burst, then the line pulses gold
		var ft := _t - 1.2
		if ft < 0.6:
			draw_rect(Rect2(Vector2(0, -50 * s), vs + Vector2(0, 100 * s)), Color(1, 1, 1, 0.45 * (1.0 - ft / 0.6)))
		rank_col = UI.GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 6.0))
	_txt(Vector2(0, y + 60 * s), info.get("rank_text", ""), 18, rank_col, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	var achs: Array = info.get("achievements", [])
	if not achs.is_empty():
		var names: Array = []
		for a in achs:
			names.append(tr(a[0]) + " (" + tr(Missions.TIER_NAMES[a[1]]) + ")")
		_fit_txt(Vector2(30 * s, y + 88 * s), tr("ACHIEVEMENT") + ":  " + ", ".join(names), 16, Missions.TIER_COLORS[achs[-1][1]], vs.x - 60 * s)
	var bw := 260.0 * s
	var bh := 58.0 * s
	_button(Rect2(Vector2(vs.x * 0.5 + 10 * s, vs.y - bh - 18 * s), Vector2(bw, bh)), "PLAY AGAIN", info.get("on_again", Callable()))
	_button(Rect2(Vector2(vs.x * 0.5 - bw - 10 * s, vs.y - bh - 18 * s), Vector2(bw, bh)), "MENU", info.get("on_menu", Callable()), Color(0.25, 0.3, 0.42))


# ------------------------------------------------------------------ hangar

var sel := 0 # plane shown in the hangar
var skin_sel := 0 # skin shown on the skins page
const STAT_NAMES := ["SPEED", "TURN", "ARMOR", "FIREPOWER"]


func open_hangar(on_back: Callable) -> void:
	sel = Profile.plane_index()
	show_page("hangar", {"on_back": on_back})


## Rotating sprite stack drawn in 2D: every slice is the same texture region,
## rotated, squashed for a 3/4 view and lifted one layer per slice.
func _draw_stack(sheet: String, variant: int, c: Vector2, sc: float, yaw: float) -> void:
	var sh = Stacks.get_sheet(sheet)
	var tex: Texture2D = Stacks.plane_atlas_tex if sh.atlas == 1 else Stacks.atlas_tex
	var squash := 0.62
	var xa := Vector2(cos(yaw), sin(yaw) * squash) * sc
	var ya := Vector2(-sin(yaw), cos(yaw) * squash) * sc
	# soft shadow
	draw_set_transform_matrix(_xf * Transform2D(xa, ya, c + Vector2(0, sc * 6.0)))
	draw_circle(Vector2.ZERO, sh.w * 0.45, Color(0, 0, 0, 0.25))
	var lift := sc * 0.95
	for i in sh.n:
		var src := Rect2(Vector2(sh.cell(i, variant)), Vector2(sh.w, sh.h))
		var copies := maxi(1, int(ceil(lift)))
		for k in copies:
			var o := c - Vector2(0, i * lift + k * lift / copies)
			draw_set_transform_matrix(_xf * Transform2D(xa, ya, o))
			draw_texture_rect_region(tex, Rect2(-sh.w * 0.5, -sh.h * 0.5, sh.w, sh.h), src)
	draw_set_transform_matrix(_xf)


## Top-down icon (all slices on top of each other).
func _draw_icon(pi: int, variant: int, c: Vector2, sc: float) -> void:
	var sh = Stacks.get_sheet(Planes.sheet_of(pi))
	for i in sh.n:
		var src := Rect2(Vector2(sh.cell(i, variant)), Vector2(sh.w, sh.h))
		draw_texture_rect_region(Stacks.plane_atlas_tex, Rect2(c - Vector2(sh.w, sh.h) * 0.5 * sc, Vector2(sh.w, sh.h) * sc), src)


func _header(vs: Vector2, title: String) -> void:
	_txt(Vector2(28 * s, 58 * s), title, 34, Color.WHITE)
	var rk := Profile.rank_of(Profile.xp())
	var rc: Color = Profile.rank_color(rk[0])
	var x := vs.x - 520 * s
	_txt(Vector2(x, 44 * s), Profile.RANKS[rk[0]], 20, rc)
	var bar := Rect2(Vector2(x, 54 * s), Vector2(220 * s, 8 * s))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	if rk[2] > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(rk[1]) / rk[2], bar.size.y)), rc)
	_txt(Vector2(vs.x - 270 * s, 56 * s), tr("COINS %d") % UI.coins_shown(Profile.coins()), 24, GOLD, 240 * s, HORIZONTAL_ALIGNMENT_RIGHT)


func _bar_row(x: float, y: float, w: float, label: String, f: float, col: Color) -> void:
	_txt(Vector2(x, y), label, 15, Color(0.75, 0.8, 0.9))
	var r := Rect2(Vector2(x + w * 0.38, y - 11 * s), Vector2(w * 0.6, 10 * s))
	draw_rect(r, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), col)


func _draw_hangar(vs: Vector2) -> void:
	_header(vs, "HANGAR")
	var top := 92.0 * s
	# --- aircraft tree: 3 branches x 4 tiers
	var tw := vs.x * 0.42
	var gap := 10.0 * s
	var cw := (tw - gap * 2.0) / 3.0
	var ch := minf(118.0 * s, (vs.y - top - 120 * s) / 4.0)
	for b in 3:
		var x := 24 * s + b * (cw + gap)
		_txt(Vector2(x, top + 14 * s), Planes.BRANCH_NAMES[b], 14, Color(0.65, 0.75, 0.9), cw, HORIZONTAL_ALIGNMENT_CENTER)
	for pi in Planes.LIST.size():
		var p: Dictionary = Planes.LIST[pi]
		var r := Rect2(Vector2(24 * s + int(p["branch"]) * (cw + gap), top + 24 * s + (int(p["tier"]) - 1) * (ch + gap)), Vector2(cw, ch))
		var owned := Profile.owns(pi)
		var lock := "" if owned else Profile.plane_lock_reason(pi)
		_buttons.append([r, "plane_%d" % pi, func() -> void: sel = pi, PANEL])
		_card(r, pi == sel)
		_draw_icon(pi, Profile.skin_of(pi) if owned else 0, r.position + Vector2(r.size.y * 0.42, r.size.y * 0.5), r.size.y / 52.0)
		var tx := r.position.x + r.size.y * 0.84
		var tww := r.end.x - tx - 6 * s
		_txt(Vector2(tx, r.position.y + 26 * s), p["name"], 17, Color.WHITE if lock == "" else Color(0.6, 0.62, 0.7))
		_txt(Vector2(tx, r.position.y + 44 * s), p["code"], 12, Color(0.6, 0.66, 0.78))
		var status := ""
		var sc := Color(0.75, 0.8, 0.9)
		if Profile.plane_index() == pi:
			status = tr("SELECTED")
			sc = GOLD
		elif owned:
			status = tr("OWNED")
		elif lock != "":
			status = lock
			sc = Color(1, 0.5, 0.45)
		else:
			status = tr("COINS %d") % int(p["price"])
			sc = GOLD
		_fit_txt(Vector2(tx, r.end.y - 10 * s), status, 12, sc, tww)
	# --- preview + stats
	var p: Dictionary = Planes.LIST[sel]
	var owned_sel := Profile.owns(sel)
	var cx := vs.x * 0.585
	var lv := Profile.levels(sel) if owned_sel else {}
	_txt(Vector2(cx - vs.x * 0.13, top + 20 * s), p["name"] + "  " + p["code"], 26, Color.WHITE, vs.x * 0.26, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(cx - vs.x * 0.13, top + 42 * s), Planes.BRANCH_NAMES[int(p["branch"])], 14, Color(0.65, 0.75, 0.9), vs.x * 0.26, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_stack(Planes.sheet_of(sel), Profile.skin_of(sel) if owned_sel else 0, Vector2(cx, top + 175 * s), 6.0 * s, _t * 0.6)
	var bars := Planes.bars(sel, lv)
	var bw := vs.x * 0.25
	for i in 4:
		_bar_row(cx - bw * 0.5, top + 330 * s + i * 30 * s, bw, STAT_NAMES[i], bars[i], BLUE)
	# --- upgrades
	var ux := vs.x * 0.725
	var uw := vs.x - ux - 24 * s
	_txt(Vector2(ux, top + 20 * s), "UPGRADES", 18, Color(0.75, 0.8, 0.9))
	for i in Planes.UPGRADES.size():
		var key: String = Planes.UPGRADES[i]
		var y := top + 34 * s + i * 50 * s
		var row := Rect2(Vector2(ux, y), Vector2(uw, 44 * s))
		_card(row)
		_txt(Vector2(ux + 10 * s, y + 18 * s), Planes.UPGRADE_NAMES[i], 14, Color.WHITE)
		var level: int = int(lv.get(key, 0))
		for k in Planes.MAX_LEVEL:
			draw_rect(Rect2(Vector2(ux + 10 * s + k * 16 * s, y + 26 * s), Vector2(12 * s, 8 * s)), BLUE if k < level else Color(0.25, 0.28, 0.36))
		var br := Rect2(Vector2(row.end.x - 118 * s, y + 6 * s), Vector2(110 * s, 32 * s))
		if not owned_sel:
			continue
		if level >= Planes.MAX_LEVEL:
			_txt(Vector2(br.position.x, y + 28 * s), "MAX", 15, GOLD, br.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var cost := Planes.upgrade_cost(sel, level)
		var can := Profile.coins() >= cost
		_small_button(br, "+ %d" % cost, func() -> void:
			if Profile.upgrade(sel, key):
				Sfx.play("tone", -8.0), Color(0.2, 0.55, 0.3) if can else Color(0.3, 0.3, 0.36))
	# --- actions
	var ay := vs.y - 82 * s
	var abw := (uw - 10 * s) * 0.5
	if Profile.plane_index() == sel:
		_small_button(Rect2(Vector2(ux, ay), Vector2(abw, 58 * s)), "SELECTED", Callable(), Color(0.3, 0.32, 0.4))
	elif owned_sel:
		_small_button(Rect2(Vector2(ux, ay), Vector2(abw, 58 * s)), "SELECT", func() -> void: Profile.select_plane(sel), Color(0.94, 0.35, 0.06))
	else:
		var lock := Profile.plane_lock_reason(sel)
		var price := int(p["price"])
		var ok := lock == "" and Profile.coins() >= price
		_small_button(Rect2(Vector2(ux, ay), Vector2(abw, 58 * s)), (tr("BUY") + "  " + str(price)) if lock == "" else lock, func() -> void:
			if Profile.buy_plane(sel):
				Sfx.play("tone", -6.0)
				Profile.select_plane(sel), Color(0.94, 0.35, 0.06) if ok else Color(0.3, 0.3, 0.36))
	_small_button(Rect2(Vector2(ux + abw + 10 * s, ay), Vector2(abw, 58 * s)), "SKINS", func() -> void:
		skin_sel = Profile.skin_of(sel)
		page = "skins", Color(0.25, 0.4, 0.6))
	_button(Rect2(Vector2(24 * s, vs.y - 70 * s), Vector2(200 * s, 54 * s)), "BACK", info.get("on_back", Callable()), Color(0.25, 0.3, 0.42))


## Text that shrinks to fit a width (long translations).
func _fit_txt(p: Vector2, t: String, size: float, col: Color, w: float) -> void:
	UI.text(self, p, tr(t), UI.fit(tr(t), size * s, w), col)


func _small_button(r: Rect2, label: String, cb: Callable, col: Color) -> void:
	_buttons.append([r, label, cb, col])
	UI.button(self, r, tr(label), s, _kind(col), 17, label)


func _draw_skins(vs: Vector2) -> void:
	_header(vs, "SKINS")
	var top := 92.0 * s
	var p: Dictionary = Planes.LIST[sel]
	# --- skin list (aggressor = red team only)
	var lw := vs.x * 0.36
	var cw := (lw - 10 * s) * 0.5
	var ch := minf(74.0 * s, (vs.y - top - 110 * s) / 4.0)
	for i in Planes.RED_SKIN:
		var r := Rect2(Vector2(24 * s + (i % 2) * (cw + 10 * s), top + 24 * s + (i / 2) * (ch + 8 * s)), Vector2(cw, ch))
		_buttons.append([r, "skin_%d" % i, func() -> void: skin_sel = i, PANEL])
		_card(r, i == skin_sel)
		_draw_icon(sel, i, r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y / 46.0)
		var tx := r.position.x + r.size.y
		_txt(Vector2(tx, r.position.y + 28 * s), Planes.SKINS[i]["name"], 16, Color.WHITE)
		var st := ""
		var sc := Color(0.75, 0.8, 0.9)
		if Profile.skin_of(sel) == i:
			st = tr("EQUIPPED")
			sc = GOLD
		elif Profile.has_skin(i):
			st = tr("OWNED")
		else:
			var lock := Profile.skin_lock_reason(i)
			var u: Array = Planes.SKINS[i]["unlock"]
			if lock != "":
				st = lock
				sc = Color(1, 0.5, 0.45)
			elif u[0] == "coins":
				st = tr("COINS %d") % int(u[1])
				sc = GOLD
			else:
				st = tr("UNLOCKED")
				sc = Color(0.5, 1, 0.6)
		_txt(Vector2(tx, r.end.y - 12 * s), st, 12, sc)
	# --- preview
	var cx := vs.x * 0.62
	_txt(Vector2(cx - vs.x * 0.15, top + 20 * s), p["name"] + "  -  " + tr(Planes.SKINS[skin_sel]["name"]), 24, Color.WHITE, vs.x * 0.3, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_stack(Planes.sheet_of(sel), skin_sel, Vector2(cx, top + 190 * s), 6.2 * s, _t * 0.6)
	_txt(Vector2(cx - vs.x * 0.15, top + 340 * s), tr("TAIL NUMBER") + "  #%02d" % Profile.tail(), 20, Color.WHITE, vs.x * 0.3, HORIZONTAL_ALIGNMENT_CENTER)
	_small_button(Rect2(Vector2(cx - 130 * s, top + 352 * s), Vector2(56 * s, 44 * s)), "-", func() -> void: Profile.set_tail(Profile.tail() - 1), Color(0.25, 0.3, 0.42))
	_small_button(Rect2(Vector2(cx + 74 * s, top + 352 * s), Vector2(56 * s, 44 * s)), "+", func() -> void: Profile.set_tail(Profile.tail() + 1), Color(0.25, 0.3, 0.42))
	# --- action
	var ax := vs.x * 0.8
	var ar := Rect2(Vector2(ax, vs.y - 82 * s), Vector2(vs.x - ax - 24 * s, 58 * s))
	var owned_plane := Profile.owns(sel)
	if Profile.skin_of(sel) == skin_sel:
		_small_button(ar, "EQUIPPED", Callable(), Color(0.3, 0.32, 0.4))
	elif Profile.has_skin(skin_sel):
		_small_button(ar, "EQUIP" if owned_plane else "BUY THE PLANE FIRST", func() -> void: Profile.equip_skin(sel, skin_sel), Color(0.94, 0.35, 0.06) if owned_plane else Color(0.3, 0.3, 0.36))
	else:
		var lock := Profile.skin_lock_reason(skin_sel)
		var u: Array = Planes.SKINS[skin_sel]["unlock"]
		var label: String = lock if lock != "" else ((tr("BUY") + "  " + str(int(u[1]))) if u[0] == "coins" else tr("UNLOCK"))
		_small_button(ar, label, func() -> void:
			if Profile.unlock_skin(skin_sel):
				Sfx.play("tone", -6.0)
				if owned_plane:
					Profile.equip_skin(sel, skin_sel), Color(0.94, 0.35, 0.06) if lock == "" else Color(0.3, 0.3, 0.36))
	_button(Rect2(Vector2(24 * s, vs.y - 70 * s), Vector2(200 * s, 54 * s)), "BACK", func() -> void: page = "hangar", Color(0.25, 0.3, 0.42))


# ------------------------------------------------------------------ missions

var mtab := 0 # 0 missions, 1 achievements


func _tab(r: Rect2, label: String, on: bool, cb: Callable) -> void:
	_buttons.append([r, label, cb, Color.WHITE])
	UI.button(self, r, tr(label), s, UI.SELECTED if on else UI.NORMAL, 18, label)


func _mission_row(r: Rect2, e: Dictionary, d: Array, weekly_list: bool, idx: int) -> void:
	_card(r)
	var goal := float(d[3])
	var p := minf(float(e["p"]), goal)
	var done := p >= goal
	_fit_txt(Vector2(r.position.x + 14 * s, r.position.y + 26 * s), tr(d[1]) % Missions.shown(d[2], goal), 17, Color.WHITE, r.size.x * 0.55)
	var bar := Rect2(Vector2(r.position.x + 14 * s, r.position.y + 36 * s), Vector2(r.size.x * 0.4, 9 * s))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * p / goal, bar.size.y)), GOLD if done else BLUE)
	_txt(Vector2(bar.end.x + 10 * s, bar.end.y + 1 * s), "%d / %d" % [Missions.shown(d[2], p), Missions.shown(d[2], goal)], 13, Color(0.75, 0.8, 0.9))
	_txt(Vector2(r.position.x + r.size.x * 0.58, r.position.y + 34 * s), tr("+%d COINS  +%d XP") % [int(d[4]), int(d[5])], 14, GOLD)
	var br := Rect2(Vector2(r.end.x - 130 * s, r.position.y + 8 * s), Vector2(120 * s, r.size.y - 16 * s))
	if e["claimed"]:
		_txt(Vector2(br.position.x, br.get_center().y + 6 * s), "CLAIMED", 15, Color(0.6, 0.65, 0.75), br.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif done:
		_small_button(br, "CLAIM", func() -> void:
			if Profile.claim_mission(idx, weekly_list):
				Sfx.play("tone", -4.0, 1.3), Color(0.94, 0.35, 0.06))
		draw_circle(br.position + Vector2(br.size.x - 6 * s, 6 * s), 6 * s, Color(0.95, 0.2, 0.15))
	elif not weekly_list and not Profile.data["missions"]["reroll_used"]:
		_small_button(br, "REROLL", func() -> void: Profile.reroll(idx), Color(0.25, 0.3, 0.42))


func _draw_missions(vs: Vector2) -> void:
	_header(vs, "MISSIONS")
	var top := 84.0 * s
	var tw := 240.0 * s
	_tab(Rect2(Vector2(vs.x * 0.5 - tw - 6 * s, top), Vector2(tw, 40 * s)), "MISSIONS", mtab == 0, func() -> void: mtab = 0)
	_tab(Rect2(Vector2(vs.x * 0.5 + 6 * s, top), Vector2(tw, 40 * s)), "ACHIEVEMENTS", mtab == 1, func() -> void: mtab = 1)
	var x := 40.0 * s
	var w := vs.x - 80 * s
	var y := top + 56 * s
	if mtab == 0:
		var now := Time.get_time_dict_from_system()
		var left := 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_txt(Vector2(x, y + 18 * s), "DAILY", 20, BLUE)
		_txt(Vector2(x, y + 18 * s), tr("NEW IN %d:%02d") % [left / 3600, (left / 60) % 60] + ("" if Profile.data["missions"]["reroll_used"] else "     " + tr("1 FREE REROLL")), 14, Color(0.7, 0.75, 0.85), w, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 28 * s
		var rh := 58.0 * s
		var dl: Array = Profile.daily()
		for i in dl.size():
			_mission_row(Rect2(Vector2(x, y), Vector2(w, rh - 6 * s)), dl[i], Missions.daily_def(dl[i]["id"]), false, i)
			y += rh
		y += 10 * s
		_txt(Vector2(x, y + 18 * s), "WEEKLY", 20, GOLD)
		y += 28 * s
		var wl: Array = Profile.weekly()
		for i in wl.size():
			_mission_row(Rect2(Vector2(x, y), Vector2(w, rh - 6 * s)), wl[i], Missions.weekly_def(wl[i]["id"]), true, i)
			y += rh
	else:
		var ap := Profile.ach_progress()
		_txt(Vector2(x, y + 16 * s), tr("%d / %d TIERS") % [ap[0], ap[1]], 16, Color(0.75, 0.8, 0.9))
		y += 26 * s
		var cols := 2
		var n := Missions.ACHIEVEMENTS.size()
		var rows := (n + cols - 1) / cols
		var cw := (w - 12 * s) / cols
		var rh := minf(46.0 * s, (vs.y - y - 86 * s) / rows)
		for i in n:
			var a: Array = Missions.ACHIEVEMENTS[i]
			var r := Rect2(Vector2(x + (i / rows) * (cw + 12 * s), y + (i % rows) * rh), Vector2(cw, rh - 4 * s))
			_card(r)
			var reached := Profile.ach_reached(a[0])
			var claimed := Profile.ach_claimed(a[0])
			for t in 3:
				var pc: Color = Missions.TIER_COLORS[t] if t <= reached else Color(0.25, 0.28, 0.36)
				draw_rect(Rect2(r.position + Vector2(8 * s + t * 12 * s, r.size.y * 0.5 - 5 * s), Vector2(9 * s, 10 * s)), pc)
			var next := mini(reached + 1, 2)
			var goal := float(a[4][next])
			_fit_txt(Vector2(r.position.x + 50 * s, r.position.y + r.size.y * 0.42), a[1], 15, Color.WHITE, cw * 0.48)
			_fit_txt(Vector2(r.position.x + 50 * s, r.position.y + r.size.y * 0.86), tr(a[2]) % Missions.shown(a[3], goal), 11, Color(0.65, 0.7, 0.8), cw * 0.48)
			var prog := "%d / %d" % [Missions.shown(a[3], minf(Profile.counter(a[3]), goal)), Missions.shown(a[3], goal)]
			_txt(Vector2(r.position.x + cw * 0.58, r.position.y + r.size.y * 0.5 + 5 * s), prog, 13, Color(0.7, 0.75, 0.85))
			if reached > claimed:
				var aid: String = a[0]
				_small_button(Rect2(Vector2(r.end.x - 100 * s, r.position.y + 3 * s), Vector2(94 * s, r.size.y - 6 * s)), "CLAIM", func() -> void:
					if Profile.claim_achievement(aid):
						Sfx.play("tone", -4.0, 1.3), Color(0.94, 0.35, 0.06))
			elif reached >= 0:
				_txt(Vector2(r.end.x - 100 * s, r.position.y + r.size.y * 0.5 + 5 * s), Missions.TIER_NAMES[reached], 13, Missions.TIER_COLORS[reached], 94 * s, HORIZONTAL_ALIGNMENT_CENTER)
	_button(Rect2(Vector2(24 * s, vs.y - 70 * s), Vector2(200 * s, 54 * s)), "BACK", info.get("on_back", Callable()), Color(0.25, 0.3, 0.42))


# ------------------------------------------------------------------ profile

func _draw_profile(vs: Vector2) -> void:
	_header(vs, "PROFILE")
	var top := 100.0 * s
	var x := 40.0 * s
	# name + edit
	var nr := Rect2(Vector2(x, top), Vector2(vs.x * 0.42, 56 * s))
	_card(nr)
	if not _name_edit.visible:
		_txt(Vector2(nr.position.x + 16 * s, nr.position.y + 38 * s), Profile.player_name(), 28, Color.WHITE)
	var er := Rect2(Vector2(nr.end.x + 10 * s, top), Vector2(120 * s, 56 * s))
	_small_button(er, "EDIT", func() -> void:
		_name_edit.position = nr.position + Vector2(8 * s, 8 * s)
		_name_edit.size = nr.size - Vector2(16 * s, 16 * s)
		_name_edit.add_theme_font_override("font", UI.font(UI.px(24 * s)))
		_name_edit.add_theme_font_size_override("font_size", UI.px(24 * s))
		_name_edit.text = Profile.player_name()
		_name_edit.visible = true
		_name_edit.grab_focus()
		_name_edit.select_all(), Color(0.25, 0.4, 0.6))
	# rank badge
	var rk := Profile.rank_of(Profile.xp())
	var rc: Color = Profile.rank_color(rk[0])
	var bc := Vector2(vs.x * 0.78, top + 110 * s)
	var pts := PackedVector2Array()
	for k in 6:
		var a := TAU * k / 6.0 - PI * 0.5
		pts.append(bc + Vector2(cos(a), sin(a)) * 74 * s)
	draw_colored_polygon(pts, rc.darkened(0.55))
	pts.append(pts[0])
	draw_polyline(pts, rc, maxf(2.0, 4.0 * s))
	_txt(Vector2(bc.x - 150 * s, bc.y + 10 * s), Profile.RANKS[rk[0]], 24, rc, 300 * s, HORIZONTAL_ALIGNMENT_CENTER)
	if rk[2] > 0:
		_txt(Vector2(bc.x - 150 * s, bc.y + 106 * s), "%d / %d XP" % [rk[1], rk[2]], 15, Color(0.75, 0.8, 0.9), 300 * s, HORIZONTAL_ALIGNMENT_CENTER)
	# stats
	var battles := Profile.stat("battles")
	var wins := Profile.stat("wins")
	var deaths := maxf(1.0, Profile.stat("deaths"))
	var shots := Profile.stat("shots")
	var t := int(Profile.stat("play_time"))
	var rows := [
		["BATTLES", str(int(battles))],
		["WINS", str(int(wins))],
		["WIN RATE", "%d%%" % int(round(100.0 * wins / maxf(1.0, battles)))],
		["K/D", "%.2f" % (Profile.stat("kills") / deaths)],
		["ACCURACY", "%d%%" % int(round(100.0 * Profile.stat("hits") / shots)) if shots > 0 else "-"],
		["FAVOURITE PLANE", Profile.favourite_plane()],
		["BEST STREAK", str(int(Profile.counter("streak")))],
		["TIME PLAYED", "%dh %02dm" % [t / 3600, (t / 60) % 60]],
		["MVP", str(int(Profile.stat("mvp")))],
	]
	var y := top + 80 * s
	var rw := vs.x * 0.42 + 130 * s
	for r in rows:
		_card(Rect2(Vector2(x, y), Vector2(rw, 38 * s)))
		_txt(Vector2(x + 16 * s, y + 26 * s), r[0], 17, Color(0.75, 0.8, 0.9))
		_txt(Vector2(x, y + 26 * s), r[1], 19, Color.WHITE, rw - 16 * s, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 42 * s
	# achievements progress
	var ap := Profile.ach_progress()
	var ar := Rect2(Vector2(vs.x * 0.62, top + 250 * s), Vector2(vs.x * 0.33, 14 * s))
	_txt(Vector2(ar.position.x, ar.position.y - 10 * s), tr("ACHIEVEMENTS") + "  " + "%d / %d" % [ap[0], ap[1]], 18, Color.WHITE)
	draw_rect(ar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(ar.position, Vector2(ar.size.x * float(ap[0]) / ap[1], ar.size.y)), GOLD)
	_button(Rect2(Vector2(24 * s, vs.y - 70 * s), Vector2(200 * s, 54 * s)), "BACK", info.get("on_back", Callable()), Color(0.25, 0.3, 0.42))


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
		if _xf.basis_xform(Vector2.ONE) != Vector2.ZERO and b[0].has_point(p - _xf.origin):
			Sfx.play("ui")
			UI.press(b[1])
			var cb: Callable = b[2]
			if cb.is_valid():
				cb.call_deferred()
			return
