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
	check(Stacks.sheets.has("plane_wren") and Stacks.get_sheet("plane_maul").n == PlaneArt.D, "12 plane sheets, %d slices each" % PlaneArt.D)
	check(Stacks.plane_palette_tex.get_height() == Planes.SKINS.size() * 3 and Stacks.plane_palette_tex.get_width() == PlaneArt.MATS, "plane palette: a row per skin and class")
	# every plane: art exists, mirror-symmetric paint, glowing nozzle, canopy
	var pa := PlaneArt.new()
	var art_ok := true
	for pi in Planes.LIST.size():
		if not PlaneArt.ART.has(Planes.LIST[pi]["id"]):
			art_ok = false
			continue
		pa.build(pi)
		var n_glow := 0
		var n_glass := 0
		var asym := 0
		var vox := 0
		for z in PlaneArt.D:
			for y in PlaneArt.W:
				for x in PlaneArt.W / 2:
					var a := pa.get_mat(x, y, z)
					var b := pa.get_mat(PlaneArt.W - 1 - x, y, z)
					if a != 0:
						vox += 1
					if (a == 0) != (b == 0):
						asym += 1
					if a == PlaneArt.GLOW or b == PlaneArt.GLOW:
						n_glow += 1
					if a == PlaneArt.GLASS or b == PlaneArt.GLASS:
						n_glass += 1
		if n_glow == 0 or n_glass == 0 or asym > 0 or vox < 600:
			art_ok = false
			print("  plane %s: glow %d glass %d asym %d vox %d" % [Planes.LIST[pi]["id"], n_glow, n_glass, asym, vox])
	check(art_ok, "all planes: symmetric voxel art with canopy glass and glowing nozzles")
	check(Stacks.jet_shadow_tex != null and Stacks.cloud_tex != null, "shadow/cloud textures")


func test_pixel_view() -> void:
	print("[pixel view]")
	var r: Array = PixelView.compute(Vector2i(2992, 1344))
	check(r[0] == 4 and r[1] == Vector2i(748, 336), "Pixel 9 Pro XL 2992x1344 -> 748x336 @4x (got %s)" % [r])
	var hd: Array = PixelView.compute(Vector2i(2992, 1344), PixelView.QUALITY_MAX_H[2])
	check(hd[0] == 2 and hd[1] == Vector2i(1496, 672), "HD voxel on the Pixel 9 Pro XL -> 1496x672 @2x (got %s)" % [hd])
	var md: Array = PixelView.compute(Vector2i(2992, 1344), PixelView.QUALITY_MAX_H[1])
	check(md[0] == 3 and md[1].y == 448, "medium quality -> 448 px @3x (got %s)" % [md])
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
	check((a["glow"] as Array).is_empty(), "street lamps cast no light pools")
	check(not (a["shadow"] as Array).is_empty(), "buildings and trees cast sun shadows")
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
	var labels: Array = []
	for it in main.menu.items:
		labels.append(str(it[0]))
	check(not labels.has("SKINS") and labels.has("HANGAR"), "main menu: no SKINS button (skins live in the hangar)")
	var start: Vector2 = main.menu.button_center(0)
	_touch(start, true)
	await _frames(3)
	_touch(start, false)
	await _frames(3)
	check(main.state == main.State.TITLE and main.menu.title == "CHOOSE MODE", "tap on title opens the mode menu")
	var city_i := 0
	for i in main.menu.items.size():
		if str(main.menu.items[i][0]) == "CITY DEFENCE":
			city_i = i
	var city_btn: Vector2 = main.menu.button_center(city_i)
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
	check(c.scheme == Controls.AIM, "aim scheme is the default")
	# --- classic stick scheme
	c.scheme = Controls.STICK
	# drag steering anywhere: drag right + down = turn right + climb
	var vs := c.get_viewport().get_visible_rect().size
	var jp := Vector2(vs.x * 0.45, vs.y * 0.45)
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(80, 80), 1)
	await _frames(2)
	check(c.stick.x > 0.5 and c.stick.y > 0.5, "drag steers: right turns, down climbs (stick=%s)" % c.stick)
	# FIRE + throttle into the afterburner zone with two more fingers
	_touch(c.button_center("fire"), true, 2)
	_touch(c.throttle_point(0.5), true, 3)
	await _frames(1)
	_drag(c.throttle_point(1.0), 3)
	await _frames(2)
	check(c.fire, "FIRE button held")
	check(c.boost and c.throttle > 0.95, "throttle pushed into the AB zone (%.2f)" % c.throttle)
	_drag(c.throttle_point(0.4), 3)
	await _frames(1)
	_touch(c.button_center("fire"), false, 2)
	_touch(c.throttle_point(0.4), false, 3)
	_touch(jp, false, 1)
	await _frames(2)
	check(not c.fire and not c.boost and c.stick == Vector2.ZERO, "buttons released, stick back to neutral")
	check(absf(c.throttle - 0.4) < 0.05, "throttle stays where it was left (%.2f)" % c.throttle)
	# dead zone: a tiny wiggle does nothing; half deflection is gentler than linear
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(c.drag_radius * 0.05, 0), 1)
	await _frames(2)
	check(c.stick == Vector2.ZERO, "dead zone ignores tiny movements")
	_drag(jp + Vector2(c.drag_radius * 0.5, 0), 1)
	await _frames(2)
	check(c.stick.x > 0.1 and c.stick.x < 0.45, "response curve: half drag -> gentle turn (%.2f)" % c.stick.x)
	# pressing FIRE while steering does not move the stick centre
	var before := c.drag_start
	_touch(c.button_center("fire"), true, 2)
	await _frames(2)
	check(c.drag_start == before and c.fire and c.stick.x > 0.1, "multitouch: steer + hold FIRE")
	_touch(c.button_center("fire"), false, 2)
	# double tap with a second finger WHILE steering = flares
	main.jet.flares = 5
	main.jet.flares_active = 0.0
	var free := Vector2(vs.x * 0.7, vs.y * 0.3)
	for k in 2:
		_touch(free, true, 4)
		await _frames(1)
		_touch(free, false, 4)
		await _frames(1)
	check(main.jet.flares == 4 and c.dragging, "double tap releases flares while the stick is held (%d)" % main.jet.flares)
	_touch(jp, false, 1)
	await _frames(10)
	main.jet.flares_active = 0.0
	# a single tap does nothing
	_touch(jp, true, 1)
	await _frames(1)
	_touch(jp, false, 1)
	await _frames(25)
	check(main.jet.flares == 4 and main.jet.man == Jet.M_NONE, "single tap does nothing")
	_touch(jp, true, 1)
	await _frames(1)
	_touch(jp, false, 1)
	await _frames(1)
	_touch(jp, true, 1)
	await _frames(1)
	_touch(jp, false, 1)
	await _frames(2)
	check(main.jet.flares == 3, "double tap releases flares (%d)" % main.jet.flares)
	check(main.jet.man == Jet.M_NONE, "no barrel roll any more")
	# --- aim + swipe: the left half is a trackpad for the aim circle
	c.scheme = Controls.AIM
	c.aim_joy = false
	main.jet.set_attitude(main.jet.yaw)
	c.set_aim(main.jet.forward3())
	var a0: Vector3 = c.aim_dir
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(60, 0), 1)
	await _frames(1)
	_drag(jp + Vector2(120, -60), 1)
	await _frames(1)
	var a1: Vector3 = c.aim_dir
	_touch(jp + Vector2(120, -60), false, 1)
	await _frames(3)
	var yaw_d := atan2(a0.cross(a1).y, a0.dot(a1)) # + = left
	check(yaw_d < -0.05 and a1.y > a0.y + 0.03, "aim drag right + up moves the aim right and up (yaw %.2f, dy %.2f)" % [yaw_d, a1.y - a0.y])
	check(c.aim_dir.distance_to(a1) < 0.01, "the aim stays where it was left")
	check(c.stick == Vector2.ZERO and not c.dragging, "no stick in the aim scheme")
	check(main.jet.aim_mode(), "player plane flies with the instructor")
	# --- aim + joystick (default): holding it keeps moving the aim
	c.aim_joy = true
	main.jet.set_attitude(main.jet.yaw)
	c.set_aim(main.jet.forward3())
	var j0: Vector3 = c.aim_dir
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(c.drag_radius * 0.15, 0), 1)
	await get_tree().create_timer(0.2).timeout
	var j_slow: float = j0.angle_to(c.aim_dir)
	_drag(jp + Vector2(c.drag_radius, 0), 1)
	var jy0 := atan2(-c.aim_dir.x, -c.aim_dir.z)
	await get_tree().create_timer(0.2).timeout
	var jy1 := atan2(-c.aim_dir.x, -c.aim_dir.z)
	await get_tree().create_timer(0.2).timeout
	var jy2 := atan2(-c.aim_dir.x, -c.aim_dir.z)
	var step1 := absf(wrapf(jy1 - jy0, -PI, PI))
	var step2 := absf(wrapf(jy2 - jy1, -PI, PI))
	check(c.dragging and step1 > 0.02 and step2 > 0.02, "joystick held right keeps moving the aim (%.3f, %.3f rad)" % [step1, step2])
	check(j_slow < step1 * 0.5, "small deflection moves the aim slowly (%.3f vs %.3f)" % [j_slow, step1])
	check(c.nose_dir == Vector3.INF or c.nose_dir.angle_to(c.aim_dir) <= Controls.AIM_LEAD_MAX + 0.01, "the aim never runs too far ahead of the nose")
	_touch(jp + Vector2(c.drag_radius, 0), false, 1)
	await _frames(2)
	var jr: Vector3 = c.aim_dir
	await get_tree().create_timer(0.2).timeout
	check(c.aim_dir.distance_to(jr) < 0.001 and not c.dragging, "released joystick: the aim circle stops")
	c.set_aim(main.jet.forward3())
	# LOOP
	main.jet.man = Jet.M_NONE
	_touch(c.button_center("loop"), true)
	await _frames(2)
	_touch(c.button_center("loop"), false)
	await _frames(2)
	check(main.jet.man == Jet.M_LOOP, "LOOP button starts a loop")
	main.jet.man = Jet.M_NONE
	main.jet.set_attitude(main.jet.yaw)
	# VIEW
	var mode_before: int = main.cam.mode
	_touch(c.button_center("view"), true)
	await _frames(2)
	_touch(c.button_center("view"), false)
	await _frames(2)
	check(main.cam.mode != mode_before, "VIEW button cycles the view")
	var seen := {}
	for k in 4:
		main.cam.cycle_mode()
		seen[main.cam.mode] = true
	check(seen.size() == 2 and seen.has(GameCamera.Mode.CHASE) and seen.has(GameCamera.Mode.COCKPIT), "VIEW toggles only chase <-> cockpit (no top-down view)")
	main.cam.mode = mode_before
	# drag in the free area on the right = look around (cockpit and chase),
	# springs back on release; the view does not change
	for md in [GameCamera.Mode.COCKPIT, GameCamera.Mode.CHASE]:
		main.cam.mode = md
		_touch(free, true, 5)
		await _frames(1)
		_drag(free + Vector2(-300, 0), 5)
		await _frames(25)
		var looked: float = main.cam.look.x
		_touch(free + Vector2(-300, 0), false, 5)
		await _frames(60)
		check(main.cam.mode == md and looked > 0.3 and absf(main.cam.look.x) < 0.1,
			"right-side drag looks left (%.2f rad) in view %d, then springs back (%.2f)" % [looked, md, main.cam.look.x])
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
	# contrails: high up, the trail keeps its points and builds a ribbon
	var ct := Contrails.new()
	ct.cam = main.cam
	main.add_child(ct)
	var j: Jet = main.jet
	var keep: Vector3 = j.position
	for i in 12:
		j.position = main.cam.global_position + Vector3(0, 0, -300.0 - i * 20.0)
		j.position.y = 3000.0
		ct.update_planes([j], 0.13)
	var n := 0
	for key in ct._bufs:
		n = maxi(n, ct._bufs[key].len)
	check(n >= 10 or not j.alive, "contrail keeps its points (%d, alive %s)" % [n, j.alive])
	check(ct.mesh.get_surface_count() == 1 or not j.alive, "contrail ribbon built")
	j.position = keep
	ct.queue_free()
	if main.has_method("test_hook"):
		var errs: Array = await main.test_hook(self)
		for e in errs:
			check(false, e)
	main.queue_free()
	await get_tree().process_frame
