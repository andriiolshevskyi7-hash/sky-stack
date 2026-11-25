extends Node

## Z-fighting probe (local diagnostics, not part of CI). Run with:
##   godot res://tests/zprobe.tscn -- --pcam=0..2 --pmap=0..4
## Freezes the game,
## renders, nudges the camera by 2 cm, renders again and counts ground pixels
## that changed. Real geometry barely moves; z-fighting pixels flip.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var cam_mode := 1
	var map := 0
	for a in args:
		if a.begins_with("--pcam="):
			cam_mode = int(a.substr(7))
		elif a.begins_with("--pmap="):
			map = int(a.substr(7))
	var main: Node = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.5).timeout
	if map != 0 and main.get("world_map") != null:
		main.world_map.apply(map)
		main.apply_settings("")
	main.start_game()
	main.cam.mode = cam_mode
	main.cam._since_switch = 99.0
	main.show_debug = false
	main.cam.fog_enabled = false
	main.jet.position = Vector3(300, 360, 900)
	main.jet.yaw = 0.3
	for i in 120:
		await get_tree().process_frame
	main.chunks.load_all_now()
	for i in 30:
		await get_tree().process_frame
	main.state = main.State.PAUSE # main._process returns early: camera frozen
	get_tree().paused = true # traffic, fx, clouds stop
	main.world_map.process_mode = Node.PROCESS_MODE_DISABLED
	var vp: Viewport = main.pv.world_vp
	var base := 0
	var moved := 0
	var total := 0
	for k in 6:
		await RenderingServer.frame_post_draw
		var a := vp.get_texture().get_image()
		await RenderingServer.frame_post_draw
		var still := vp.get_texture().get_image()
		main.cam.global_position += Vector3(0.02, 0.0, 0.0) * (1.0 if k % 2 == 0 else -1.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var b := vp.get_texture().get_image()
		var c := _diff(a, still)
		base += c[0]
		moved += _diff(a, b)[0]
		if k == 0:
			var m := a.duplicate() as Image
			for y in a.get_height():
				for x in a.get_width():
					var ca := a.get_pixel(x, y)
					var cb := b.get_pixel(x, y)
					if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.12:
						m.set_pixel(x, y, Color(0, 1, 0))
			m.save_png("user://zdiff_%d_%d.png" % [map, cam_mode]) # green = pixel changed
		total += c[1]
	print("ZPROBE map=%d cam=%d  still-noise=%.3f%%  after-2cm-nudge=%.3f%%  camera-sensitive=%.3f%%" % [map, cam_mode,
		100.0 * base / total, 100.0 * moved / total, 100.0 * maxf(0, moved - base) / total])
	get_tree().quit()


func _diff(a: Image, b: Image) -> Array:
	var n := 0
	var t := 0
	for y in range(a.get_height() / 2, a.get_height()):
		for x in a.get_width():
			t += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.12:
				n += 1
	return [n, t]
