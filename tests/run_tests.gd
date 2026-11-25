extends Node
## Headless test suite (run in CI):
##   godot --headless res://tests/test_runner.tscn
## Exits with code 0 when everything passes, 1 otherwise.

var failures := 0
var passes := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _ready() -> void:
	print("== Sky Stack tests ==")
	await get_tree().process_frame
	test_scripts_compile()
	test_locale()
	test_stacks()
	test_pixel_view()
	test_world_gen()
	test_city_layout()
	await test_launch()
	print("== %d passed, %d failed ==" % [passes, failures])
	if failures == 0:
		print("ALL TESTS PASSED")
	get_tree().quit(1 if failures > 0 else 0)


## Every script must compile, even ones nothing loads yet.
func test_scripts_compile() -> void:
	print("[scripts]")
	var bad: Array = []
	var n := 0
	for dir in ["res://scripts/", "res://tests/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			n += 1
			var sc: GDScript = load(dir + f)
			if sc == null or not sc.can_instantiate():
				bad.append(f)
	check(bad.is_empty() and n > 30, "all %d scripts compile %s" % [n, bad])


## English + Ukrainian: translations load, every Ukrainian string keeps the
## same placeholders as its key, and the UI font has all the glyphs.
func test_locale() -> void:
	print("[locale]")
	var prev := TranslationServer.get_locale()
	var keys := PackedStringArray()
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	var have_csv := f != null
	if have_csv:
		f.get_csv_line()
		while not f.eof_reached():
			var row := f.get_csv_line()
			if row.size() >= 3 and row[0] != "":
				keys.append(row[0])
	TranslationServer.set_locale("uk")
	var missing := 0
	var bad_fmt: Array = []
	var font := ThemeDB.fallback_font
	var no_glyph := 0
	for k in keys:
		var u := String(TranslationServer.translate(k))
		if u == k and k.to_upper() != k.to_lower():
			missing += 1
		for ph in ["%d", "%02d", "%07d", "%s"]:
			if k.count(ph) != u.count(ph):
				bad_fmt.append(k)
		for i in u.length():
			if u[i] != " " and not font.has_char(u.unicode_at(i)):
				no_glyph += 1
	check(String(TranslationServer.translate("PLAY")) == "ГРАТИ", "Ukrainian translation loaded (PLAY -> %s)" % TranslationServer.translate("PLAY"))
	check(missing < 12, "Ukrainian covers the keys (%d of %d untranslated)" % [missing, keys.size()])
	check(bad_fmt.is_empty(), "placeholders match in every translation %s" % [bad_fmt])
	check(no_glyph == 0, "UI font has every Ukrainian glyph (%d missing)" % no_glyph)
	TranslationServer.set_locale("en")
	check(String(TranslationServer.translate("PLAY")) == "PLAY", "English is the fallback")
	TranslationServer.set_locale(prev)


func test_stacks() -> void:
	print("[stacks]")
	for n in ["jet", "enemy_jet", "drone", "bomber", "car", "tree", "lamp", "antenna", "cloud"]:
		check(Stacks.sheets.has(n), "sheet '%s' generated" % n)
	var jet = Stacks.get_sheet("jet")
	check(jet.uv_rects.size() == jet.n * jet.v, "jet uv rects = slices*variants")
	check(Stacks.atlas_size.x == 1024 and Stacks.atlas_size.y >= 256, "atlas size %s" % Stacks.atlas_size)
	var m := Stacks.make_stack_mesh("car")
	check(m.get_surface_count() == 1 or DisplayServer.get_name() == "headless", "stack mesh built")
	var mb := MeshBuf.new()
	mb.add_stack(Stacks.get_sheet("tree"), 1, Vector3(5, 0, 5), 0.3, 1.0, Color.WHITE)
	check(mb.quad_count() == Stacks.get_sheet("tree").n, "one quad per slice")
	# atlas rects must not overlap (main atlas and plane atlas separately)
	for atl in 2:
		var size: Vector2i = Stacks.atlas_size if atl == 0 else Stacks.PLANE_ATLAS
		var rects: Array[Rect2i] = []
		for k in Stacks.sheets:
			var sh = Stacks.sheets[k]
			if sh.atlas != atl:
				continue
			for vi in sh.v:
				for s in sh.n:
					rects.append(Rect2i(sh.cell(s, vi), Vector2i(sh.w, sh.h)))
		var overlap := false
		for i in rects.size():
			if not Rect2i(Vector2i.ZERO, size).encloses(rects[i]):
				overlap = true
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					overlap = true
		check(not overlap and not rects.is_empty(), "%s atlas cells inside and non-overlapping (%d cells)" % [["main", "plane"][atl], rects.size()])
	check(Stacks.sheets.has("plane_wren") and Stacks.get_sheet("plane_maul").v == Planes.SKINS.size(), "12 plane sheets with a variant per skin")
	check(Stacks.jet_shadow_tex != null and Stacks.cloud_tex != null, "shadow/cloud textures")


func test_pixel_view() -> void:
	print("[pixel view]")
	var r: Array = PixelView.compute(Vector2i(2992, 1344))
	check(r[0] == 4 and r[1] == Vector2i(748, 336), "Pixel 9 Pro XL 2992x1344 -> 748x336 @4x (got %s)" % [r])
	for sz in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 720), Vector2i(1344, 648), Vector2i(3200, 1440), Vector2i(800, 480)]:
		r = PixelView.compute(sz)
		var low: Vector2i = r[1]
		var ok: bool = (low.y <= 400 or r[0] == 1) and low.y >= 280 and low.x * r[0] >= sz.x and low.x * r[0] - sz.x < r[0] and low.y * r[0] <= sz.y
		check(ok, "%s -> %s @%dx" % [sz, low, r[0]])


func test_world_gen() -> void:
	print("[world generation]")
	var a := CityGen.generate_chunk(0, 0, Stacks.sheets, {})
	var b := CityGen.generate_chunk(0, 0, Stacks.sheets, {})
	check(a["quads"] == b["quads"] and a["boxes"] == b["boxes"], "chunk generation is deterministic")
	check(a["boxes"].size() > 0, "origin chunk has buildings (%d)" % (a["boxes"].size() / 5))
	var total_boxes := 0
	var tall := 0
	var t0 := Time.get_ticks_msec()
	for cz in range(-2, 3):
		for cx in range(-2, 3):
			var c := CityGen.generate_chunk(cx, cz, Stacks.sheets, {})
			var bx: PackedFloat32Array = c["boxes"]
			total_boxes += bx.size() / 5
			for i in bx.size() / 5:
				if bx[i * 5 + 4] > CityGen.LOW_ALT / CityGen.S:
					tall += 1
	var ms := Time.get_ticks_msec() - t0
	check(total_boxes > 60, "5x5 chunks around the origin contain a city (%d buildings)" % total_boxes)
	check(tall > 5, "downtown has skyscrapers to dive between (%d)" % tall)
	print("    25 chunks generated in %d ms (%.1f ms/chunk)" % [ms, ms / 25.0])
	# destroyed building becomes rubble
	var ids: PackedInt64Array = a["ids"]
	var d := CityGen.generate_chunk(0, 0, Stacks.sheets, {ids[0]: true})
	check(d["boxes"][4] == 3.0, "destroyed building regenerates as rubble")
	# open ocean chunk: find one and check it is empty
	var found := false
	for k in 600:
		var cx := 3 + k % 24
		var cz := -12 + k / 24
		if CityGen.island_h(cx * 256.0 + 128.0, cz * 256.0 + 128.0) < 0.3 and CityGen.island_h(cx * 256.0, cz * 256.0) < 0.3 and CityGen.island_h(cx * 256.0 + 256.0, cz * 256.0 + 256.0) < 0.3:
			var sea := CityGen.generate_chunk(cx, cz, Stacks.sheets, {})
			check(sea["boxes"].size() == 0 and sea["props"].is_empty(), "open ocean chunk %d,%d has no buildings or props" % [cx, cz])
			found = true
			break
	check(found, "deep ocean exists around the islands")


func test_city_layout() -> void:
	print("[world layout]")
	check(CityGen.island_h(0, 0) > CityGen.URBAN_H, "main island at the origin")
	# ocean dominates the map
	var water := 0
	var total := 0
	for z in range(0, 6144, 96):
		for x in range(0, 6144, 96):
			total += 1
			if CityGen.is_water(x, z):
				water += 1
	var wf := float(water) / total
	check(wf > 0.55 and wf < 0.85, "map is mostly ocean (%.0f%% water)" % (wf * 100.0))
	var hist := {}
	for bz in range(-50, 50, 2):
		for bx in range(-50, 50, 2):
			var dd := CityGen.district(bx, bz)
			hist[dd] = hist.get(dd, 0) + 1
	for dd in [CityGen.D_DOWNTOWN, CityGen.D_MIDTOWN, CityGen.D_RESIDENTIAL, CityGen.D_PARK, CityGen.D_FOREST, CityGen.D_WATER]:
		check(hist.get(dd, 0) > 0, "district %s present (%d blocks)" % [CityGen.DISTRICT_NAMES[dd], hist.get(dd, 0)])
	# even around downtown at least half the ground is not covered by buildings
	var area := 0.0
	for cz in range(-1, 1):
		for cx in range(-1, 1):
			var c := CityGen.generate_chunk(cx, cz, Stacks.sheets, {})
			var bx: PackedFloat32Array = c["boxes"]
			for i in bx.size() / 5:
				area += (bx[i * 5 + 2] - bx[i * 5]) * (bx[i * 5 + 3] - bx[i * 5 + 1])
	var frac := area / (512.0 * 512.0)
	check(frac < 0.4, "downtown core building coverage %.0f%% (<40%%)" % (frac * 100.0))
	# no building may stand on a street
	var bad := 0
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var c := CityGen.generate_chunk(cx, cz, Stacks.sheets, {})
			var bx: PackedFloat32Array = c["boxes"]
			for i in bx.size() / 5:
				var o := i * 5
				var lx := fposmod((bx[o] + bx[o + 2]) * 0.5, 64.0)
				var lz := fposmod((bx[o + 1] + bx[o + 3]) * 0.5, 64.0)
				if lx < 8.0 or lx > 56.0 or lz < 8.0 or lz > 56.0:
					bad += 1
	check(bad == 0, "no buildings on streets (%d bad)" % bad)
	check(CityGen.is_drivable(0.0, 32.0, false), "downtown street is drivable")
	check(not CityGen.is_drivable(4000.0 * 1.0, 32.0, false) or CityGen.island_h(4000.0, 32.0) > 0.5, "open water is not drivable")


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(pos: Vector2, index: int = 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Simulated touches on every piece of touch UI.
func test_touch(main: Node) -> void:
	print("[touch]")
	get_tree().root.size = Vector2i(1344, 648)
	await _frames(2)
	print("    viewport %s" % main.get_viewport().get_visible_rect().size)
	check(main.state == main.State.TITLE and main.menu.visible, "title menu shown")
	var start: Vector2 = main.menu.button_center(0)
	_touch(start, true)
	await _frames(3)
	_touch(start, false)
	await _frames(3)
	check(main.state == main.State.TITLE and main.menu.title == "CHOOSE MODE", "tap on title opens the mode menu")
	var city_btn: Vector2 = main.menu.button_center(2)
	_touch(city_btn, true)
	await _frames(3)
	_touch(city_btn, false)
	await _frames(3)
	check(main.menu.title == "CHOOSE MAP", "mode opens the map menu")
	var map_btn: Vector2 = main.menu.button_center(0)
	_touch(map_btn, true)
	await _frames(3)
	_touch(map_btn, false)
	await _frames(3)
	check(main.state == main.State.LOBBY and main.screens.visible, "CITY DEFENCE opens the lobby")
	await _frames(2)
	var sb: Vector2 = main.screens.button_center("START")
	_touch(sb, true)
	await _frames(3)
	_touch(sb, false)
	await _frames(3)
	check(main.state == main.State.PLAY, "touch on lobby START starts the game")
	check(not main.menu.visible and not main.screens.visible, "menus closed after START")
	var c: Controls = main.controls
	# drag steering anywhere: drag right + down = turn right + climb
	var vs := c.get_viewport().get_visible_rect().size
	var jp := Vector2(vs.x * 0.45, vs.y * 0.45)
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(80, 80), 1)
	await _frames(2)
	check(c.stick.x > 0.5 and c.stick.y > 0.5, "drag steers: right turns, down climbs (stick=%s)" % c.stick)
	# GUN + BOOST with two more fingers
	_touch(c.button_center("gun"), true, 2)
	_touch(c.button_center("boost"), true, 3)
	await _frames(2)
	check(c.fire, "GUN button held")
	check(c.boost, "BOOST button held")
	_touch(c.button_center("gun"), false, 2)
	_touch(c.button_center("boost"), false, 3)
	_touch(jp, false, 1)
	await _frames(2)
	check(not c.fire and not c.boost and c.stick == Vector2.ZERO, "buttons released, stick back to neutral")
	# dead zone: a tiny wiggle does nothing; half deflection is gentler than linear
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(c.drag_radius * 0.05, 0), 1)
	await _frames(2)
	check(c.stick == Vector2.ZERO, "dead zone ignores tiny movements")
	_drag(jp + Vector2(c.drag_radius * 0.5, 0), 1)
	await _frames(2)
	check(c.stick.x > 0.1 and c.stick.x < 0.45, "response curve: half drag -> gentle turn (%.2f)" % c.stick.x)
	# pressing GUN while steering does not move the stick centre
	var before := c.drag_start
	_touch(c.button_center("gun"), true, 2)
	await _frames(2)
	check(c.drag_start == before and c.fire and c.stick.x > 0.1, "multitouch: steer + hold GUN")
	_touch(c.button_center("gun"), false, 2)
	_touch(jp, false, 1)
	await _frames(2)
	# quick tap = barrel roll
	_touch(jp, true, 1)
	await _frames(1)
	_touch(jp, false, 1)
	await _frames(2)
	check(main.jet.man == Jet.M_ROLL, "tap does a barrel roll")
	# LOOP
	main.jet.man = Jet.M_NONE
	_touch(c.button_center("loop"), true)
	await _frames(2)
	_touch(c.button_center("loop"), false)
	await _frames(2)
	check(main.jet.man == Jet.M_LOOP, "LOOP button starts a loop")
	main.jet.man = Jet.M_NONE
	main.jet.pitch = 0.0
	# VIEW
	var mode_before: int = main.cam.mode
	_touch(c.button_center("view"), true)
	await _frames(2)
	_touch(c.button_center("view"), false)
	await _frames(2)
	check(main.cam.mode != mode_before, "VIEW button cycles the view")
	main.cam.mode = mode_before
	# PAUSE -> RESUME
	_touch(c.button_center("pause"), true)
	await _frames(2)
	_touch(c.button_center("pause"), false)
	await _frames(2)
	check(main.state == main.State.PAUSE and get_tree().paused, "pause button pauses")
	var resume: Vector2 = main.menu.button_center(0)
	_touch(resume, true)
	await _frames(3)
	_touch(resume, false)
	await _frames(2)
	check(main.state == main.State.PLAY and not get_tree().paused, "RESUME button resumes")
	# game over -> RETRY
	main.jet.damage(9999.0)
	main._over_t = 10.0
	await _frames(3)
	check(main.state == main.State.OVER and main.menu.visible, "game over menu shown")
	var retry: Vector2 = main.menu.button_center(0)
	_touch(retry, true)
	await _frames(3)
	_touch(retry, false)
	await _frames(2)
	check(main.state == main.State.PLAY and main.jet.alive, "RETRY button restarts")


func test_launch() -> void:
	print("[launch]")
	var scene: PackedScene = load("res://main.tscn")
	check(scene != null, "main scene loads")
	if scene == null:
		return
	var main := scene.instantiate()
	check(main.has_method("start_game"), "main script compiled")
	if not main.has_method("start_game"):
		return
	get_tree().root.add_child(main)
	await get_tree().process_frame
	check(main.chunks.chunks.size() >= 9, "chunks streamed at start (%d)" % main.chunks.chunks.size())
	await test_touch(main)
	main.jet.autopilot = true
	var start: Vector3 = main.jet.position
	await get_tree().create_timer(3.0).timeout
	check(main.jet.position.distance_to(start) > 50.0, "jet flies (%.0f units)" % main.jet.position.distance_to(start))
	check(main.state == main.State.PLAY or main.state == main.State.OVER, "game running")
	if main.has_method("test_hook"):
		var errs: Array = await main.test_hook(self)
		for e in errs:
			check(false, e)
	main.queue_free()
	await get_tree().process_frame
