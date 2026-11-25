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
	draw_string(font, p, tr(t), al, w, int(size * s), col)


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
		"hangar":
			_draw_hangar(vs)
		"skins":
			_draw_skins(vs)


func _team_list(x: float, y: float, w: float, team: Array, col: Color, title: String) -> void:
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 46 * s)), col.darkened(0.45))
	_txt(Vector2(x + 18 * s, y + 31 * s), title, 22, col)
	y += 54 * s
	var rh := minf(46.0 * s, (get_viewport_rect().size.y - y - 120 * s) / maxf(1.0, team.size()))
	for e in team:
		draw_rect(Rect2(Vector2(x, y), Vector2(w, rh - 6 * s)), PANEL)
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
	_txt(Vector2(0, y + 60 * s), info.get("rank_text", ""), 18, Color(0.8, 0.85, 0.95), vs.x, HORIZONTAL_ALIGNMENT_CENTER)
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
	draw_set_transform_matrix(Transform2D(xa, ya, c + Vector2(0, sc * 6.0)))
	draw_circle(Vector2.ZERO, sh.w * 0.45, Color(0, 0, 0, 0.25))
	var lift := sc * 0.95
	for i in sh.n:
		var src := Rect2(Vector2(sh.cell(i, variant)), Vector2(sh.w, sh.h))
		var copies := maxi(1, int(ceil(lift)))
		for k in copies:
			var o := c - Vector2(0, i * lift + k * lift / copies)
			draw_set_transform_matrix(Transform2D(xa, ya, o))
			draw_texture_rect_region(tex, Rect2(-sh.w * 0.5, -sh.h * 0.5, sh.w, sh.h), src)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
	_txt(Vector2(vs.x - 270 * s, 56 * s), tr("COINS %d") % Profile.coins(), 24, GOLD, 240 * s, HORIZONTAL_ALIGNMENT_RIGHT)


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
		var col := PANEL.lightened(0.12) if pi == sel else PANEL
		_buttons.append([r, "plane_%d" % pi, func() -> void: sel = pi, col])
		draw_rect(r, col)
		if pi == sel:
			draw_rect(r, GOLD, false, maxf(1.0, 2.0 * s))
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
		draw_rect(row, PANEL)
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
	var fs := size
	while fs > 8.0 and font.get_string_size(tr(t), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * s)).x > w:
		fs -= 1.0
	_txt(p, t, fs, col)


func _small_button(r: Rect2, label: String, cb: Callable, col: Color) -> void:
	_buttons.append([r, label, cb, col])
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2 * s)), col.lightened(0.25))
	_txt(Vector2(r.position.x, r.get_center().y + 7 * s), label, 17, Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


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
		var col := PANEL.lightened(0.12) if i == skin_sel else PANEL
		_buttons.append([r, "skin_%d" % i, func() -> void: skin_sel = i, col])
		draw_rect(r, col)
		if i == skin_sel:
			draw_rect(r, GOLD, false, maxf(1.0, 2.0 * s))
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
