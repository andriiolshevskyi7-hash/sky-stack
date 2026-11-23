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
var terrain: MeshInstance3D
var clouds: Clouds
var speed_lines: SpeedLines
var flash := 0.0
var _chim_t := 0.0
var controls: Controls
var hud: Hud
var menu: Menu
var env: Environment
var sky_mat: ShaderMaterial
var cockpit: Cockpit
var trails: Trails
var missiles: Missiles
var wingmen: Wingmen
var intel: Intel
var tutorial: Tutorial
var settings_ui: SettingsScreen
var enemy_jets := 3

var score := 0
var wave := 0
var city_hp := 1000.0
var city_max := 1000.0
var banner := ""
var banner_sub := ""
var banner_time := 0.0
var show_debug := false
var _score_acc := 0.0
var _over_t := 0.0
var over_reason := ""
# waves
var wave_queue: Array[int] = []
var spawn_cd := 0.0
var between_t := 0.0
var kills := 0
const SWARM := 100
var popups: Array = [] # [world pos, text, age]
var _hitstop_until := 0
var _aa_fail := 0
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
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env

	terrain = MeshInstance3D.new()
	terrain.name = "Terrain"
	var plane := PlaneMesh.new()
	plane.size = Vector2(40000, 40000)
	terrain.mesh = plane
	var tmat := ShaderMaterial.new()
	tmat.shader = preload("res://shaders/terrain.gdshader")
	terrain.material_override = tmat
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.custom_aabb = AABB(Vector3(-20000, -10, -20000), Vector3(40000, 20, 40000))
	world.add_child(terrain)

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
	missiles = Missiles.new()
	missiles.name = "Missiles"
	world.add_child(missiles)
	wingmen = Wingmen.new()
	wingmen.name = "Wingmen"
	world.add_child(wingmen)
	traffic = Traffic.new()
	traffic.name = "Traffic"
	world.add_child(traffic)

	daynight = DayNight.new()
	daynight.name = "DayNight"
	daynight.env = env
	daynight.sky_mat = sky_mat
	daynight.cycle = Save.day_cycle
	world.add_child(daynight)
	clouds = Clouds.new()
	clouds.name = "Clouds"
	clouds.daynight = daynight
	world.add_child(clouds)
	speed_lines = SpeedLines.new()
	pv.overlay.add_child(speed_lines)
	cockpit = Cockpit.new()
	cockpit.game = self
	pv.overlay.add_child(cockpit)

	controls = Controls.new()
	controls.name = "Controls"
	add_child(controls)
	jet.controls = controls
	jet.cam = cam
	jet.chunks = chunks
	jet.combat = combat
	jet.fx = fx
	trails = Trails.new()
	trails.name = "Trails"
	trails.cam = cam
	world.add_child(trails)
	jet.trails = trails
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
	enemies.missiles = null
	traffic.fx = fx
	missiles.game = self
	missiles.jet = jet
	missiles.enemies = enemies
	missiles.fx = fx
	enemies.missiles = missiles
	wingmen.jet = jet
	wingmen.enemies = enemies
	wingmen.combat = combat
	tutorial = Tutorial.new()
	tutorial.game = self
	add_child(tutorial)
	jet.invert_pitch = Save.invert_pitch
	rng.randomize()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	menu = Menu.new()
	layer.add_child(menu)
	intel = Intel.new()
	layer.add_child(intel)
	settings_ui = SettingsScreen.new()
	layer.add_child(settings_ui)
	settings_ui.changed.connect(func(k: String) -> void: apply_settings(k))
	settings_ui.closed.connect(_open_pause)
	intel.closed.connect(func() -> void:
		if state == State.PAUSE and not menu.visible:
			_resume())

	controls.cam_pressed.connect(_on_cam)
	controls.pause_pressed.connect(_on_pause)
	controls.roll_pressed.connect(func() -> void: jet.barrel_roll())
	controls.loop_pressed.connect(func() -> void: jet.loop(false))
	controls.missile_pressed.connect(_on_missile)
	controls.intel_pressed.connect(_on_intel)
	controls.tutorial_pressed.connect(_on_tutorial)
	jet.ejected.connect(_on_ejected)
	jet.trick.connect(func(n: String) -> void:
		if state == State.PLAY:
			score += 25
			show_banner(n, "", 0.8))
	jet.died.connect(_on_jet_died)
	jet.damaged.connect(func(a: float) -> void: flash = minf(0.8, flash + 0.25 + a * 0.02))

	apply_settings("")
	jet.reset(SPAWN, 0.0)
	cam.update_cam(0.016, jet, 0.0)
	chunks.focus = cam.ground_point()
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
		elif a.begins_with("--tod="):
			Save.settings["time"] = int(a.substr(6))
			apply_settings("time")
		elif a == "--settings":
			_open_pause()
			_open_settings()
		elif a == "--touch":
			controls.touch_seen = true
		elif a == "--nofog":
			cam.fog_enabled = false
		elif a == "--nodebug":
			show_debug = false
		elif a == "--auto":
			jet.autopilot = true
		elif a.begins_with("--time="):
			daynight.t = float(a.substr(7))
		elif a.begins_with("--alt="):
			jet.position.y = float(a.substr(6))
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
	if _hitstop_until > 0 and Time.get_ticks_msec() > _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0
	for pp in popups:
		pp[2] += delta
	while not popups.is_empty() and popups[0][2] > 1.2:
		popups.pop_front()
	if state == State.PAUSE:
		return
	delta = minf(delta, 0.05)
	jet.step(delta)
	_update_pilot(delta)
	cam.update_cam(delta, jet, jet.speed_ratio())
	jet.visible = jet.alive and cam.cockpit_blend < 0.6
	cockpit.size = Vector2(pv.low)
	cockpit.alpha = cam.cockpit_blend if state != State.TITLE else 0.0
	chunks.radius = 2 if cam.mode == GameCamera.Mode.OVERHEAD else 3
	var gf := ground_focus()
	chunks.focus = gf
	traffic.focus = gf
	terrain.position = Vector3(snappedf(gf.x, 256.0), 0.0, snappedf(gf.z, 256.0))
	var over := cam.mode == GameCamera.Mode.OVERHEAD
	clouds.opacity = lerpf(clouds.opacity, 0.5 if over else 1.0, 1.0 - exp(-delta * 3.0))
	clouds.mat.set_shader_parameter("near_fade", 700.0 if over else 260.0)
	fx.clear_columns_far(cam.focus, 900.0)
	daynight.focus = gf
	clouds.focus = gf
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
		if tutorial.active():
			tutorial.process(delta)
		else:
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
		"TAP ANYWHERE TO START",
		"Touch: stick left - BOOST / FIRE right      Keys: WASD  Shift  Space  C  Esc"], 0.25, true)


func start_game() -> void:
	menu.close()
	state = State.PLAY
	get_tree().paused = false
	controls.enabled = true
	controls.reset()
	over_reason = ""
	jet.autopilot = false
	jet.reset(jet.position, jet.yaw)
	trails.clear()
	score = 0
	wave = 0
	kills = 0
	city_hp = city_max
	enemies.clear()
	combat.clear()
	missiles.clear()
	tutorial.stop()
	wingmen.reset()
	Engine.time_scale = 1.0
	wave_queue.clear()
	between_t = 3.0
	show_banner("GET READY", "Protect the city", 2.5)


# ------------------------------------------------------------------ waves

func _start_wave(n: int) -> void:
	wave = n
	wave_queue.clear()
	# later waves mix the types: swarms, fighters, interceptors, bombers
	for i in 1 + n / 2:
		wave_queue.append(SWARM)
	for i in mini(10, enemy_jets + (n - 1) / 2):
		wave_queue.append(Enemies.JET)
	if n >= 3:
		for i in mini(6, (n - 1) / 2):
			wave_queue.append(Enemies.INTERCEPTOR)
	if n >= 2:
		for i in mini(4, n / 2):
			wave_queue.append(Enemies.BOMBER)
	wave_queue.shuffle()
	if n % 5 == 0:
		wave_queue.append(Enemies.BOSS)
	if n >= 4:
		for i in mini(4, n - 3):
			wave_queue.push_front(Enemies.AAGUN)
	spawn_cd = 1.0
	var sub := "Enemies inbound"
	if n == 4:
		sub = "Rooftop anti-air guns detected!"
	if n % 5 == 0:
		sub = "BOSS BOMBER APPROACHING"
	show_banner("WAVE %d" % n, sub, 2.5)
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
			var p := chunks.roof_spot(jet.position, 120.0, 520.0, rng)
			if p != Vector3.INF:
				ok = enemies.spawn(t, p + Vector3(0, 0.3, 0))
			else:
				_aa_fail += 1
				if _aa_fail > 20:
					_aa_fail = 0
					wave_queue.pop_front() # no towers around (over the ocean): skip
		else:
			var a := rng.randf() * TAU
			var p := jet.position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(800.0, 1000.0)
			p.y = clampf(jet.position.y + rng.randf_range(-80, 80), 80.0, 700.0)
			if t == SWARM:
				enemies.spawn_swarm(p, 5)
				ok = true
			else:
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
	var pts := value * jet.multiplier
	score += pts
	popups.append([at, "+%d" % pts, 0.0])
	if popups.size() > 12:
		popups.pop_front()
	# short hit-stop
	if Engine.time_scale >= 0.99:
		Engine.time_scale = 0.08
		_hitstop_until = Time.get_ticks_msec() + (140 if type == Enemies.BOSS else 60)
	if type == Enemies.BOSS:
		show_banner("BOSS DOWN", "+%d" % pts, 2.5)
	if at.distance_to(jet.position) < 450.0:
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


## Point on the ground the camera is looking at (for streaming).
func ground_focus() -> Vector3:
	return cam.ground_point()


# ------------------------------------------------------------------ ejection

var pilot: Node3D
var _pilot_vel := Vector3.ZERO
var _eject_t := 0.0


func _on_ejected(at: Vector3) -> void:
	pilot = Node3D.new()
	var st := SpriteStack.new()
	st.sheet = "parachute"
	pilot.add_child(st)
	world.add_child(pilot)
	pilot.position = at + Vector3(0, 6, 0)
	_pilot_vel = Vector3(0, 30, 0) + jet.forward() * 20.0
	_eject_t = 0.0
	cam.override = pilot
	show_banner("EJECTED", "Search and rescue inbound", 3.5)


func _update_pilot(delta: float) -> void:
	if pilot == null:
		return
	_eject_t += delta
	_pilot_vel = _pilot_vel.lerp(Vector3(4.0, -7.0, 2.0), 1.0 - exp(-delta * 1.5))
	pilot.position += _pilot_vel * delta
	pilot.rotation.y += delta * 0.4
	if pilot.position.y < 1.0:
		pilot.position.y = 1.0
	if _eject_t > 4.5:
		# rescued: back in a fresh jet
		var p := pilot.position
		pilot.queue_free()
		pilot = null
		cam.override = null
		if state == State.PLAY or state == State.TITLE:
			score = maxi(0, score - 300)
			jet.reset(p, jet.yaw)
			trails.clear()
			show_banner("RESCUED", "New jet  -300", 2.0)


func missiles_max() -> int:
	return missiles.max_missiles


func missiles_left() -> int:
	return 0 if missiles.reload > 0.0 else missiles.ammo


func _on_missile() -> void:
	if state == State.PLAY:
		missiles.fire_player()


func _on_intel() -> void:
	if state == State.PLAY:
		state = State.PAUSE
		get_tree().paused = true
		controls.reset()
		controls.enabled = false
		intel.open(controls.touch_seen)
	elif state == State.PAUSE and intel.visible:
		intel.visible = false
		_resume()


func _on_tutorial() -> void:
	if state != State.PLAY:
		return
	enemies.clear()
	combat.clear()
	wave_queue.clear()
	between_t = 0.0
	tutorial.start()
	show_banner("TUTORIAL", "", 1.5)


func end_tutorial() -> void:
	enemies.clear()
	between_t = 2.0


func enemies_left() -> int:
	return wave_queue.size() + enemies.count_active()


func debug_extra() -> String:
	return "VIS %s BL %.2f T %.2f N %.1f  CARS %d  FX %d  BULLETS %d  ENEMIES %d | JET %d,%d  SPD %d  NEAR %d  CAM %s FOV %d" % [jet.visible, cam.cockpit_blend, daynight.t, daynight.night, traffic.active_cars, fx.n, combat.n, enemies.count_active(), jet.position.x, jet.position.z, jet.speed, jet.near_tall, GameCamera.MODE_NAMES[cam.mode], cam.fov]


func _on_cam() -> void:
	cam.cycle_mode()
	Save.cam_mode = cam.mode
	Save.store()
	if menu.visible and state == State.PAUSE:
		_open_pause()
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
	controls.enabled = false
	Sfx.set_engine(false, 0.0)
	menu.open("PAUSED", "", [
		["RESUME", _resume],
		["SETTINGS", _open_settings],
		["INTEL", func() -> void:
			menu.close()
			intel.open(controls.touch_seen)],
		[func() -> String: return "VIEW: " + GameCamera.MODE_NAMES[cam.mode], _on_cam],
		["RESTART", start_game],
		["QUIT TO TITLE", _to_title],
	])


func _open_settings() -> void:
	menu.close()
	settings_ui.open()


## Push the settings (Save.settings) into every system. key = the one that
## changed ("" = all).
func apply_settings(key: String) -> void:
	var st: Dictionary = Save.settings
	for k in ["speed", "boost", "turn", "bank", "cruise", "ceiling", "clearance", "crashes", "cannon", "reload"]:
		jet.cfg[k] = st[k]
	jet.invert_pitch = st["invert"]
	missiles.max_missiles = int(st["missiles"])
	missiles.reload_time = st["reload"]
	missiles.slowmo_s = st["slowmo"]
	if key == "missiles" or key == "":
		missiles.ammo = missiles.max_missiles
	if key == "cannon":
		jet.ammo = float(st["cannon"])
	wingmen.count = int(st["wingmen"])
	enemy_jets = int(st["enemy_jets"])
	cam.transition = st["view_change"]
	cam.overhead_follow = st["overhead_follow"]
	cam.chase_dist = st["chase_dist"]
	cam.chase_height = st["chase_height"]
	cam.shake_mult = st["shake"]
	if key == "view" or key == "":
		cam.mode = int(st["view"]) as GameCamera.Mode
		cam._since_switch = 0.0
	daynight.cycle = st["day_cycle"]
	if key == "time" or key == "":
		daynight.t = [0.42, 0.74, 0.0][int(st["time"])]
	if key == "islands" or key == "seed":
		Stacks.rebuild_islands(int(st["seed"]), float(st["islands"]))
		chunks.reset_all()
		traffic._urban.clear()
	var cover := lerpf(0.82, 0.5, float(st["clouds"])) if float(st["clouds"]) > 0.0 else 1.1
	clouds.cover = cover
	RenderingServer.global_shader_parameter_set("cloud_cover", cover)
	RenderingServer.global_shader_parameter_set("jet_shadow_size", float(Stacks.get_sheet("jet").w) if st["jet_shadow"] else 0.0001)
	pv.set_post("bloom", float(st["glow"]) * 0.55)
	pv.set_post("contrast", st["contrast"])
	pv.set_post("vignette", st["vignette"])
	pv.set_post("grain", st["grain"])
	Save.apply()
	fx.realistic_flames = int(st["flames"]) == 1
	fx.burner_mult = st["afterburner"]
	fx.spray_mult = st["spray"]
	fx.sparks_mult = st["sparks"]
	trails.visible = st["trails"]
	jet.trails = trails if st["trails"] else null
	controls.helper_buttons = st["helper_buttons"]
	controls.show_indicator = st["stick_indicator"]
	show_debug = st["debug"]
	AudioServer.set_bus_mute(0, not st["sound"])
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(st["volume"]))))


func touch_buttons_visible() -> bool:
	match int(Save.settings.get("touch_buttons", 0)):
		1:
			return true
		2:
			return false
	return controls.touch_seen


func _resume() -> void:
	menu.close()
	controls.reset()
	controls.enabled = true
	state = State.PLAY
	get_tree().paused = false


func _toggle_cycle() -> void:
	daynight.cycle = not daynight.cycle
	if not daynight.cycle:
		daynight.t = 0.42
	Save.day_cycle = daynight.cycle
	Save.store()


func _toggle_invert() -> void:
	jet.invert_pitch = not jet.invert_pitch
	Save.invert_pitch = jet.invert_pitch
	Save.store()


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
	# --- wave 5 brings a boss bomber; swarms spawn as groups of drones
	_start_wave(5)
	if not wave_queue.has(Enemies.BOSS) or not wave_queue.has(SWARM):
		errs.append("wave 5 has no boss / swarm")
	enemies.clear()
	var n0 := enemies.count_active()
	enemies.spawn_swarm(jet.position + Vector3(400, 0, 0), 5)
	if enemies.count_active() - n0 != 5:
		errs.append("swarm did not spawn 5 drones")
	enemies.spawn(Enemies.BOSS, jet.position + Vector3(0, 0, -600))
	if enemies.boss == null:
		errs.append("boss not tracked")
	wave_queue.clear()
	# --- combat: lock-on + missile kill (wingman held back so it can't steal the kill)
	wingmen.process_mode = Node.PROCESS_MODE_DISABLED
	wave_queue.clear()
	tutorial.step = 99 # pause the wave director while testing
	enemies.clear()
	jet.autopilot = false
	jet.position.y = 320.0
	jet.pitch = 0.0
	jet.turn_rate = 0.0
	jet.man = Jet.M_NONE
	jet.roll_extra = 0.0
	missiles.clear()
	enemies.spawn(Enemies.BOMBER, jet.position + jet.forward() * 300.0)
	for e in enemies.pool:
		if e.active:
			e.speed = jet.speed
			e.yaw = jet.yaw
			e.hp = 3.0
	await t.get_tree().create_timer(1.2).timeout
	if not missiles.locked:
		errs.append("no missile lock on an enemy straight ahead (lock_t %.2f)" % missiles.lock_t)
	var k0 := kills
	missiles.fire_player()
	await t.get_tree().create_timer(3.0).timeout
	if kills <= k0:
		errs.append("locked missile did not kill the target")
	# --- enemy missile: roll as the rings meet -> dodge, counter volley armed
	enemies.clear()
	var d0 := missiles.dodges
	missiles.fire_enemy(jet.position - jet.forward() * 200.0)
	var rolled := false
	for i in 900:
		await t.get_tree().process_frame
		if not rolled and missiles.incoming_t < 0.35:
			jet.barrel_roll()
			rolled = true
		if missiles.dodges > d0:
			break
	if missiles.dodges <= d0 or missiles.counter_t <= 0.0:
		errs.append("rolling as the rings meet did not dodge the missile")
	Engine.time_scale = 1.0
	wingmen.process_mode = Node.PROCESS_MODE_INHERIT
	await t.get_tree().process_frame
	if wingmen.pos.size() != wingmen.count:
		errs.append("wingman missing")
	tutorial.step = -1
	# --- INTEL pauses, tap outside resumes
	_on_intel()
	await t.get_tree().process_frame
	if not (intel.visible and get_tree().paused):
		errs.append("INTEL did not open paused")
	var ev := InputEventScreenTouch.new()
	ev.position = Vector2(4, 4)
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	if intel.visible or get_tree().paused:
		errs.append("tap outside INTEL did not resume")
	# --- tutorial first step advances when turning
	_on_tutorial()
	jet.turn_rate = 1.2
	for i in 120:
		tutorial.process(0.016)
		jet.turn_rate = 1.2
	if tutorial.step < 1:
		errs.append("tutorial did not advance after turning")
	tutorial.stop()
	# --- settings apply live (and defaults match the spec)
	var d := SettingsScreen.defaults()
	if d["speed"] != 130.0 or d["cruise"] != 220.0 or d["missiles"] != 6.0 or d["islands"] != 0.33 or d["glow"] != 0.8:
		errs.append("settings defaults differ from the spec")
	settings_ui.set_value("speed", 150.0)
	if float(jet.cfg["speed"]) != 150.0:
		errs.append("speed setting not applied")
	settings_ui.set_value("time", 2)
	await t.get_tree().create_timer(0.3).timeout
	if daynight.night < 0.9:
		errs.append("night setting not applied (night %.2f)" % daynight.night)
	settings_ui.set_value("islands", 0.5)
	if CityGen.island_h(3000.0, 3000.0) == CityGen.island_h(3000.0, 3000.0) and chunks.chunks.size() > 30:
		errs.append("islands change did not reset the streamed chunks")
	for k in ["speed", "time", "islands"]:
		settings_ui.set_value(k, d[k])
	# cockpit view: camera locks into the canopy, jet hidden, overlay shown
	cam.mode = GameCamera.Mode.COCKPIT
	cam._since_switch = 0.0
	await t.get_tree().create_timer(2.5).timeout
	if jet.visible or cam.cockpit_blend < 0.9:
		errs.append("cockpit view did not engage (blend %.2f, jet visible %s)" % [cam.cockpit_blend, jet.visible])
	cam.mode = GameCamera.Mode.CHASE
	# eject -> parachute close-up -> rescued in a new jet
	jet._eject()
	await t.get_tree().create_timer(0.5).timeout
	if pilot == null or cam.override == null:
		errs.append("eject did not spawn the pilot close-up")
	await t.get_tree().create_timer(4.6).timeout
	if not jet.alive or pilot != null:
		errs.append("pilot was not rescued into a new jet")
	print("    enemies=%d cars=%d fx=%d score=%d" % [enemies.count_active(), traffic.active_cars, fx.n, score])
	return errs
