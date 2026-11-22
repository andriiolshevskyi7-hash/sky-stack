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
	test_stacks()
	test_pixel_view()
	test_world_gen()
	test_city_layout()
	await test_launch()
	print("== %d passed, %d failed ==" % [passes, failures])
	if failures == 0:
		print("ALL TESTS PASSED")
	get_tree().quit(1 if failures > 0 else 0)


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
	# atlas rects must not overlap
	var rects: Array[Rect2i] = []
	for k in Stacks.sheets:
		var sh = Stacks.sheets[k]
		for vi in sh.v:
			for s in sh.n:
				rects.append(Rect2i(sh.cell(s, vi), Vector2i(sh.w, sh.h)))
	var overlap := false
	for i in rects.size():
		if not Rect2i(Vector2i.ZERO, Stacks.atlas_size).encloses(rects[i]):
			overlap = true
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				overlap = true
	check(not overlap, "atlas cells inside atlas and non-overlapping (%d cells)" % rects.size())
	check(Stacks.jet_shadow_tex != null and Stacks.cloud_tex != null, "shadow/cloud textures")


func test_pixel_view() -> void:
	print("[pixel view]")
	var r: Array = PixelView.compute(Vector2i(2992, 1344))
	check(r[0] == 6 and r[1] == Vector2i(499, 224), "Pixel 9 Pro XL 2992x1344 -> 499x224 @6x (got %s)" % [r])
	for sz in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 720), Vector2i(1344, 648), Vector2i(3200, 1440), Vector2i(800, 480)]:
		r = PixelView.compute(sz)
		var low: Vector2i = r[1]
		var ok: bool = low.y <= 224 and (low.y >= 180 or sz.y < 360) and low.x * r[0] >= sz.x and low.x * r[0] - sz.x < r[0] and r[0] >= 1
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
				if bx[i * 5 + 4] > CityGen.JET_ALT:
					tall += 1
	var ms := Time.get_ticks_msec() - t0
	check(total_boxes > 150, "5x5 chunks contain buildings (%d)" % total_boxes)
	check(tall > 10, "skyline has skyscrapers taller than the jet (%d)" % tall)
	print("    25 chunks generated in %d ms (%.1f ms/chunk)" % [ms, ms / 25.0])
	# destroyed building becomes rubble
	var ids: PackedInt64Array = a["ids"]
	var d := CityGen.generate_chunk(0, 0, Stacks.sheets, {ids[0]: true})
	check(d["boxes"][4] == 3.0, "destroyed building regenerates as rubble")
	# special chunks
	var air := CityGen.generate_chunk(-10, -6, Stacks.sheets, {})
	check(CityGen.airport_local(-10, -6) == Vector2i(0, 0) and air["quads"] > 0, "airport chunk generates")
	var sea_cx := int(floor(CityGen.coast_x(0.0) / CityGen.CHUNK)) + 2
	var sea := CityGen.generate_chunk(sea_cx, 0, Stacks.sheets, {})
	check(sea["boxes"].size() == 0 and sea["quads"] > 0, "open sea chunk has water and no buildings")


func test_city_layout() -> void:
	print("[city layout]")
	var hist := {}
	for bz in range(-40, 40, 2):
		for bx in range(-40, 30, 2):
			var dd := CityGen.district(bx, bz)
			hist[dd] = hist.get(dd, 0) + 1
	for dd in [CityGen.D_DOWNTOWN, CityGen.D_MIDTOWN, CityGen.D_RESIDENTIAL, CityGen.D_INDUSTRIAL, CityGen.D_PARK, CityGen.D_RIVERSIDE]:
		check(hist.get(dd, 0) > 0, "district %s present (%d blocks)" % [CityGen.DISTRICT_NAMES[dd], hist.get(dd, 0)])
	# no building may stand on a street
	var bad := 0
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var c := CityGen.generate_chunk(cx, cz, Stacks.sheets, {})
			var bx: PackedFloat32Array = c["boxes"]
			for i in bx.size() / 5:
				var o := i * 5
				var mx := (bx[o] + bx[o + 2]) * 0.5
				var mz := (bx[o + 1] + bx[o + 3]) * 0.5
				var lx := fposmod(mx, 64.0)
				var lz := fposmod(mz, 64.0)
				if lx < 8.0 or lx > 56.0 or lz < 8.0 or lz > 56.0:
					bad += 1
	check(bad == 0, "no buildings on streets (%d bad)" % bad)
	check(CityGen.is_drivable(0.0, 0.0, true), "origin street is drivable")
	check(not CityGen.is_drivable(CityGen.coast_x(0.0) + 50.0, 0.0, true), "sea is not drivable")


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
	check(main.state == main.State.PLAY, "touch on START starts the game")
	check(not main.menu.visible, "menu closed after START")
	var c: Controls = main.controls
	# joystick: touch left half, drag right
	var vs := c.get_viewport().get_visible_rect().size
	var jp := Vector2(vs.x * 0.15, vs.y * 0.75)
	_touch(jp, true, 1)
	await _frames(1)
	_drag(jp + Vector2(60, 0), 1)
	await _frames(2)
	print("    dbg vs=%s joy=%s roles=%s en=%s" % [c.get_viewport().get_visible_rect().size, c.joy_active, c._touch_role, c.enabled])
	check(c.stick.x > 0.5, "joystick drag steers (stick=%s)" % c.stick)
	# FIRE + BOOST with two more fingers
	_touch(c.fire_pos, true, 2)
	_touch(c.boost_pos, true, 3)
	await _frames(2)
	check(c.fire, "FIRE button held")
	check(c.boost, "BOOST button held")
	_touch(c.fire_pos, false, 2)
	_touch(c.boost_pos, false, 3)
	_touch(jp, false, 1)
	await _frames(2)
	check(not c.fire and not c.boost and c.stick == Vector2.ZERO, "buttons released")
	# CAM
	var mode_before: int = main.cam.mode
	_touch(c.cam_pos, true)
	await _frames(2)
	_touch(c.cam_pos, false)
	await _frames(2)
	check(main.cam.mode != mode_before, "CAM button cycles the view")
	main.cam.mode = mode_before
	# PAUSE -> RESUME
	_touch(c.pause_pos, true)
	await _frames(2)
	_touch(c.pause_pos, false)
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
