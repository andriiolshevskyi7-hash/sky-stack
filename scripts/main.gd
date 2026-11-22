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
var fx: Fx
var combat: Combat
var enemies: Enemies
var traffic: Traffic
var daynight: DayNight
var clouds: Clouds
var speed_lines: SpeedLines
var flash := 0.0
var _chim_t := 0.0
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
var over_reason := ""
# waves
var wave_queue: Array[int] = []
var spawn_cd := 0.0
var between_t := 0.0
var kills := 0
var rng := RandomNumberGenerator.new()
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

	fx = Fx.new()
	fx.name = "Fx"
	world.add_child(fx)
	combat = Combat.new()
	combat.name = "Combat"
	world.add_child(combat)
	enemies = Enemies.new()
	enemies.name = "Enemies"
	world.add_child(enemies)
	traffic = Traffic.new()
	traffic.name = "Traffic"
	world.add_child(traffic)

	daynight = DayNight.new()
	daynight.name = "DayNight"
	daynight.env = env
	world.add_child(daynight)
	clouds = Clouds.new()
	clouds.name = "Clouds"
	clouds.daynight = daynight
	world.add_child(clouds)
	speed_lines = SpeedLines.new()
	pv.overlay.add_child(speed_lines)

	controls = Controls.new()
	controls.name = "Controls"
	add_child(controls)
	jet.controls = controls
	jet.cam = cam
	jet.chunks = chunks
	jet.combat = combat
	jet.fx = fx
	combat.game = self
	combat.jet = jet
	combat.enemies = enemies
	combat.chunks = chunks
	combat.fx = fx
	enemies.game = self
	enemies.jet = jet
	enemies.chunks = chunks
	enemies.combat = combat
	enemies.fx = fx
	rng.randomize()

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
	jet.damaged.connect(func(a: float) -> void: flash = minf(0.8, flash + 0.25 + a * 0.02))

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
		elif a.begins_with("--time="):
			daynight.t = float(a.substr(7))
		elif a.begins_with("--wave="):
			between_t = 0.0
			_start_wave(int(a.substr(7)))


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
	traffic.focus = cam.focus
	fx.clear_columns_far(cam.focus, 900.0)
	daynight.focus = cam.focus
	clouds.focus = cam.focus
	_chim_t -= delta
	if _chim_t <= 0.0:
		_chim_t = 1.0
		chunks.chimney_tops(cam.focus, 450.0, fx.chimneys)
	# post effects: cloud fog, hit flash, speed lines
	pv.set_post("fog", clouds.fog_at(jet.position, delta) if jet.alive else 0.0)
	flash = maxf(0.0, flash - delta * 2.0)
	pv.set_post("flash", flash)
	speed_lines.size = Vector2(pv.low)
	speed_lines.strength = lerpf(speed_lines.strength, 1.0 if jet.boosting else 0.0, 1.0 - exp(-delta * 6.0))
	if state == State.PLAY:
		_update_waves(delta)
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
	over_reason = ""
	jet.autopilot = false
	jet.reset(jet.position, jet.yaw)
	score = 0
	wave = 0
	kills = 0
	city_hp = city_max
	enemies.clear()
	combat.clear()
	wave_queue.clear()
	between_t = 3.0
	show_banner("GET READY", "Protect the city", 2.5)


# ------------------------------------------------------------------ waves

func _start_wave(n: int) -> void:
	wave = n
	wave_queue.clear()
	for i in 3 + n:
		wave_queue.append(Enemies.DRONE)
	for i in maxi(0, n - 1) + n / 2:
		wave_queue.append(Enemies.JET)
	if n >= 3:
		for i in (n - 1) / 2:
			wave_queue.append(Enemies.BOMBER)
	wave_queue.shuffle()
	if n >= 4:
		for i in mini(4, n - 3):
			wave_queue.push_front(Enemies.AAGUN)
	spawn_cd = 1.0
	show_banner("WAVE %d" % n, "Rooftop anti-air guns detected!" if n == 4 else "Enemies inbound", 2.5)
	Sfx.play("alarm", -4.0)


func _update_waves(delta: float) -> void:
	if not jet.alive:
		return
	if between_t > 0.0:
		between_t -= delta
		if between_t <= 0.0:
			_start_wave(wave + 1)
		return
	spawn_cd -= delta
	if not wave_queue.is_empty() and spawn_cd <= 0.0:
		var t: int = wave_queue[0]
		var ok := false
		if t == Enemies.AAGUN:
			var p := chunks.roof_spot(jet.position, 180.0, 420.0, rng)
			if p != Vector3.INF:
				ok = enemies.spawn(t, p + Vector3(0, 0.3, 0))
		else:
			var a := rng.randf() * TAU
			var p := jet.position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(420.0, 520.0)
			ok = enemies.spawn(t, p)
		if ok:
			wave_queue.pop_front()
		spawn_cd = rng.randf_range(0.6, 1.4)
	if wave_queue.is_empty() and enemies.count_active() == 0:
		var bonus := 500 * wave + int(city_hp / city_max * 500.0)
		score += bonus
		jet.health = minf(jet.max_health, jet.health + 20.0)
		show_banner("WAVE %d CLEAR" % wave, "+%d bonus   +20 HP" % bonus, 3.0)
		Sfx.play("clear")
		between_t = 4.0


func on_enemy_killed(type: int, at: Vector3, value: int) -> void:
	kills += 1
	score += value * jet.multiplier
	if Vector2(at.x - jet.position.x, at.z - jet.position.z).length() < 160.0:
		cam.add_shake(2.5 if type != Enemies.BOMBER else 5.0)


func damage_building(id: int, amount: float, at: Vector3) -> void:
	if state != State.PLAY:
		return
	city_hp = maxf(0.0, city_hp - amount)
	if chunks.damage_building(id, amount):
		city_hp = maxf(0.0, city_hp - 25.0)
		fx.explosion(at, 2.0)
		fx.add_column(at, 0.7)
		Sfx.play("big_explode", -3.0)
		if Vector2(at.x - jet.position.x, at.z - jet.position.z).length() < 250.0:
			cam.add_shake(4.0)
	if city_hp <= 0.0:
		over_reason = "THE CITY HAS FALLEN"
		jet.damage(9999.0)


func show_banner(t: String, sub: String = "", time: float = 2.5) -> void:
	banner = t
	banner_sub = sub
	banner_time = time


func enemies_left() -> int:
	return wave_queue.size() + enemies.count_active()


func debug_extra() -> String:
	return "T %.2f N %.1f  CARS %d  FX %d  BULLETS %d  ENEMIES %d | JET %d,%d  SPD %d  NEAR %d  CAM %s pitch %d" % [daynight.t, daynight.night, traffic.active_cars, fx.n, combat.n, enemies.count_active(), jet.position.x, jet.position.z, jet.speed, jet.near_tall, GameCamera.MODE_NAMES[cam.mode], rad_to_deg(cam.pitch)]


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
	if over_reason == "":
		over_reason = "YOUR JET WAS SHOT DOWN" 
	controls.enabled = false
	Sfx.play("gameover")


func _open_game_over() -> void:
	var record := Save.submit_score(score)
	menu.open("GAME OVER", over_reason + ("   -   NEW HIGH SCORE!" if record else ""), [
		["RETRY", start_game],
		["TITLE", _to_title],
	], ["SCORE  %d" % score, "WAVE  %d" % wave, "HIGH SCORE  %d" % Save.high_score])


## Extra checks for the headless launch test (tests/run_tests.gd).
func test_hook(t: Node) -> Array:
	var errs: Array = []
	_start_wave(4)
	for i in 30:
		spawn_cd = 0.0
		_update_waves(0.016)
	await t.get_tree().create_timer(1.5).timeout
	if enemies.count_active() == 0:
		errs.append("no enemies spawned in wave 4")
	if traffic.active_cars < 20:
		errs.append("too few cars (%d)" % traffic.active_cars)
	# shoot: guaranteed kill of one enemy through the combat path
	var before := kills
	for e in enemies.pool:
		if e.active and e.type != Enemies.AAGUN:
			e.hp = 0.5
			enemies.hit_test(e.pos, 1.0)
			break
	if kills != before + 1:
		errs.append("enemy kill not registered")
	print("    enemies=%d cars=%d fx=%d score=%d" % [enemies.count_active(), traffic.active_cars, fx.n, score])
	return errs
