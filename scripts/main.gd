extends Node
## Game root: builds the pixel view, world, HUD and runs the game state machine.

enum State { TITLE, PLAY, PAUSE, OVER }

const SPAWN := Vector3(0, 0, 0)

var state := State.TITLE
var pv: PixelView
var world: Node3D
var cam: GameCamera
var chunks: ChunkManager
var jet: Jet
var controls: Controls
var hud: Hud
var menu: Menu
var env: Environment

var score := 0
var wave := 0
var city_hp := 1000.0
var city_max := 1000.0
var banner := ""
var banner_sub := ""
var banner_time := 0.0
var show_debug := true
var _score_acc := 0.0
var _over_t := 0.0
# --shot=<file.png> --frames=<n> [--play] [--cam=0..2] [--time=0..1]: debug screenshots
var _shot_path := ""
var _shot_frames := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	pv = PixelView.new()
	pv.name = "PixelView"
	add_child(pv)
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_to_group("stack_world")
	pv.world_vp.add_child(world)

	cam = GameCamera.new()
	cam.name = "Camera"
	world.add_child(cam)
	cam.mode = Save.cam_mode as GameCamera.Mode
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6a9fd8")
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env

	chunks = ChunkManager.new()
	chunks.name = "Chunks"
	world.add_child(chunks)

	jet = Jet.new()
	jet.name = "Jet"
	world.add_child(jet)

	controls = Controls.new()
	controls.name = "Controls"
	add_child(controls)
	jet.controls = controls
	jet.cam = cam
	jet.chunks = chunks

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	menu = Menu.new()
	layer.add_child(menu)

	controls.cam_pressed.connect(_on_cam)
	controls.pause_pressed.connect(_on_pause)
	jet.died.connect(_on_jet_died)

	jet.reset(SPAWN, 0.0)
	cam.view_h = pv.low.y
	cam.update_cam(0.016, jet.position, jet.yaw, 0.0)
	chunks.focus = cam.focus
	chunks.load_all_now()
	_to_title()
	_parse_args()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
		elif a == "--play":
			start_game()
		elif a.begins_with("--cam="):
			cam.mode = int(a.substr(6)) as GameCamera.Mode
		elif a == "--nodebug":
			show_debug = false
		elif a == "--auto":
			jet.autopilot = true


func _shot_tick() -> void:
	if _shot_path == "":
		return
	_frame += 1
	if _frame == _shot_frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("screenshot saved: ", _shot_path)
		get_tree().quit()


func _process(delta: float) -> void:
	_shot_tick()
	if state == State.PAUSE:
		return
	delta = minf(delta, 0.05)
	jet.step(delta)
	cam.view_h = pv.low.y
	cam.update_cam(delta, jet.position, jet.yaw, jet.speed_ratio())
	chunks.focus = cam.focus
	RenderingServer.global_shader_parameter_set("jet_pos", jet.global_position if jet.alive else Vector3(0, -1000, 0))
	RenderingServer.global_shader_parameter_set("jet_yaw", jet.yaw)
	banner_time -= delta
	Sfx.set_engine(state == State.PLAY and jet.alive, jet.speed_ratio())
	if state == State.PLAY and jet.alive:
		_score_acc += delta * (2.0 + 6.0 * (jet.multiplier - 1))
		if _score_acc >= 1.0:
			score += int(_score_acc)
			_score_acc -= int(_score_acc)
	if state == State.OVER:
		_over_t += delta
		if _over_t > 1.6 and not menu.visible:
			_open_game_over()


# ------------------------------------------------------------------ states

func _to_title() -> void:
	state = State.TITLE
	get_tree().paused = false
	jet.autopilot = true
	controls.enabled = false
	menu.open("SKY STACK", "Defend the city.  Fly low between skyscrapers for a score multiplier.",
		[["START", start_game]],
		[func() -> String: return "HIGH SCORE  %d" % Save.high_score,
		"Touch: stick left - BOOST / FIRE right      Keys: WASD  Shift  Space  C  Esc"], 0.25)


func start_game() -> void:
	menu.close()
	state = State.PLAY
	get_tree().paused = false
	controls.enabled = true
	controls.reset()
	jet.autopilot = false
	jet.reset(jet.position, jet.yaw)
	score = 0
	wave = 0
	city_hp = city_max
	show_banner("GET READY", "Protect the city", 2.5)


func show_banner(t: String, sub: String = "", time: float = 2.5) -> void:
	banner = t
	banner_sub = sub
	banner_time = time


func enemies_left() -> int:
	return 0


func debug_extra() -> String:
	return "JET %d,%d  SPD %d  NEAR %d  CAM %s pitch %d" % [jet.position.x, jet.position.z, jet.speed, jet.near_tall, GameCamera.MODE_NAMES[cam.mode], rad_to_deg(cam.pitch)]


func _on_cam() -> void:
	cam.cycle_mode()
	Save.cam_mode = cam.mode
	Save.store()
	Sfx.play("ui")


func _on_pause() -> void:
	if state == State.PLAY:
		_open_pause()
	elif state == State.PAUSE:
		_resume()


func _open_pause() -> void:
	state = State.PAUSE
	get_tree().paused = true
	controls.reset()
	Sfx.set_engine(false, 0.0)
	menu.open("PAUSED", "", [
		["RESUME", _resume],
		[func() -> String: return "CAMERA: " + GameCamera.MODE_NAMES[cam.mode], _on_cam],
		[func() -> String: return "SPRITE TURN: " + ("64 STEPS" if Save.sprite_snap else "SMOOTH"), _toggle_snap],
		[func() -> String: return "DEBUG OVERLAY: " + ("ON" if show_debug else "OFF"), func() -> void: show_debug = not show_debug],
		["QUIT TO TITLE", _to_title],
	])


func _resume() -> void:
	menu.close()
	state = State.PLAY
	get_tree().paused = false


func _toggle_snap() -> void:
	Save.sprite_snap = not Save.sprite_snap
	Save.apply()
	Save.store()


func _on_jet_died() -> void:
	if state != State.PLAY:
		return
	state = State.OVER
	_over_t = 0.0
	controls.enabled = false
	Sfx.play("gameover")


func _open_game_over() -> void:
	var record := Save.submit_score(score)
	menu.open("GAME OVER", "NEW HIGH SCORE!" if record else "", [
		["RETRY", start_game],
		["TITLE", _to_title],
	], ["SCORE  %d" % score, "WAVE  %d" % wave, "HIGH SCORE  %d" % Save.high_score])
