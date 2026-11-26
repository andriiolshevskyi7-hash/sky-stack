extends Node
## Game root: builds the pixel view, world, HUD and runs the game state machine.

enum State { TITLE, PLAY, PAUSE, OVER, LOBBY, RESULTS }

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
## Terrain plane sits below every flat ground layer (see CityGen.Y_ROAD...).
const TERRAIN_Y := -0.5
var world_map: WorldMap
var border_t := 0.0 # seconds outside the warning line
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
var cockpit3d: Cockpit3D
var quality := 2 # graphics quality 0 low, 1 medium, 2 high
var plane_shadows: PlaneShadows
var menu_stage: MenuStage
var music: Music
var sound: SoundScape
var _stage_a := 0.0
var trails: Trails
var missiles: Missiles
var fleet: Fleet
var match_rules: Match
var bases: Bases
var screens: Screens
var _player_respawn := -1.0
var _last_results := {}
var kill_feed: Array = [] # [text, age, color]
var intel: Intel
var tutorial: Tutorial
var settings_ui: SettingsScreen
var enemy_jets := 3
var wingmen_count := 1

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
const BOT_PAIR := 101
const BOT_INTERCEPTOR := 102
const BOT_ATTACKER := 103
var popups: Array = [] # [world pos, text, age]
var _hitstop_until := 0
var _aa_fail := 0
var rng := RandomNumberGenerator.new()
# --shot=<file.png> --frames=<n> [--play] [--cam=1..2] [--time=0..1]: debug screenshots
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
	fleet = Fleet.new()
	fleet.name = "Fleet"
	plane_shadows = PlaneShadows.new()
	plane_shadows.name = "PlaneShadows"
	world.add_child(fleet)
	bases = Bases.new()
	bases.name = "Bases"
	world.add_child(bases)
	match_rules = Match.new()
	match_rules.game = self
	add_child(match_rules)
	traffic = Traffic.new()
	traffic.name = "Traffic"
	world.add_child(traffic)
	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	world_map.game = self
	world.add_child(world_map)

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
	plane_shadows.fleet = fleet
	plane_shadows.player = jet
	plane_shadows.daynight = daynight
	world.add_child(plane_shadows)
	sound = SoundScape.new()
	sound.name = "SoundScape"
	sound.game = self
	add_child(sound)
	combat.sound = sound
	music = Music.new()
	music.name = "Music"
	add_child(music)
	menu_stage = MenuStage.new()
	menu_stage.name = "MenuStage"
	menu_stage.game = self
	add_child(menu_stage)
	pv.post_mat.set_shader_parameter("stage_tex", menu_stage.texture())
	cockpit3d = Cockpit3D.new()
	cockpit3d.name = "Cockpit3D"
	cockpit3d.game = self
	add_child(cockpit3d)
	pv.post_mat.set_shader_parameter("cockpit_tex", cockpit3d.texture())
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
	fleet.game = self
	fleet.chunks = chunks
	fleet.combat = combat
	fleet.fx = fx
	fleet.enemies = enemies
	fleet.missiles = missiles
	fleet.clouds = clouds
	fleet.cam = cam
	fleet.add_player(jet)
	fleet.spawn_point = func(team: int) -> Array:
		var a := rng.randf() * TAU
		var base := jet.position if team == 0 else jet.position + Vector3(cos(a), 0, sin(a)) * 1400.0
		return [Vector3(base.x + rng.randf_range(-200, 200), world_map.spawn_alt(), base.z + rng.randf_range(-200, 200)), rng.randf() * TAU]
	fleet.plane_killed.connect(_on_plane_killed)
	fleet.plane_killed.connect(func(v: Jet, k: Jet, _a: Jet) -> void: match_rules.on_kill(v, k))
	combat.fleet = fleet
	combat.bases = bases
	bases.game = self
	bases.fleet = fleet
	bases.combat = combat
	bases.fx = fx
	missiles.fleet = fleet
	missiles.clouds = clouds
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
	screens = Screens.new()
	layer.add_child(screens)
	settings_ui = SettingsScreen.new()
	layer.add_child(settings_ui)
	settings_ui.changed.connect(func(k: String) -> void: apply_settings(k))
	settings_ui.closed.connect(_open_pause)
	intel.closed.connect(func() -> void:
		if state == State.PAUSE and not menu.visible:
			_resume())

	controls.cam_pressed.connect(_on_cam)
	controls.pause_pressed.connect(_on_pause)
	controls.flares_pressed.connect(func() -> void:
		if state == State.PLAY and jet.alive and not jet.release_flares() and jet.flares <= 0:
			show_banner("NO FLARES", "", 0.6))
	controls.loop_pressed.connect(func() -> void: jet.loop(false))
	controls.missile_pressed.connect(_on_missile)
	controls.intel_pressed.connect(_on_intel)
	controls.tutorial_pressed.connect(_on_tutorial)
	jet.ejected.connect(_on_ejected)
	jet.trick.connect(func(n: String) -> void:
		if state == State.PLAY:
			Profile.track("loop")
			score += 25
			show_banner(n, "", 0.8))
	jet.died.connect(_on_jet_died)
	jet.damaged.connect(func(a: float) -> void:
		flash = minf(0.8, flash + 0.25 + a * 0.02)
		Controls.haptic(35 + int(minf(a, 30.0) * 2.0), 0.7))

	world_map.apply(int(Save.settings.get("map", 0)), true)
	apply_settings("")
	apply_player_plane()
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
		elif a == "--botprobe":
			_bot_probe.call_deferred()
		elif a == "--crash":
			_crash_test = true
		elif a == "--stickdemo":
			_stick_demo = true
		elif a == "--fight":
			_fight_test = true
		elif a.begins_with("--chase="):
			Save.settings["chase_dist"] = float(a.substr(8))
			apply_settings("")
		elif a == "--aimdemo":
			_aim_demo = true
		elif a == "--splitdemo":
			_split_demo = true
		elif a.begins_with("--team="):
			Save.settings["team_size"] = int(a.substr(7))
		elif a == "--hangar":
			_open_hangar()
		elif a == "--missions":
			_open_missions()
		elif a == "--achievements":
			_open_missions()
			screens.mtab = 1
		elif a == "--profile":
			_open_profile()
		elif a == "--skins":
			_open_hangar()
			screens.page = "skins"
		elif a.begins_with("--lang="):
			Save.settings["lang"] = Save.LANGS.find(a.substr(7))
			Save.apply_language()
		elif a.begins_with("--map="):
			world_map.apply(int(a.substr(6)))
			apply_settings("")
			chunks.load_all_now()
		elif a.begins_with("--at="):
			var v := a.substr(5).split(",")
			jet.position = Vector3(float(v[0]), float(v[2]) if v.size() > 2 else jet.position.y, float(v[1]))
			chunks.focus = Vector3(jet.position.x, 0, jet.position.z)
			chunks.load_all_now()
		elif a.begins_with("--mode="):
			_open_lobby(int(a.substr(7)))
			if not OS.get_cmdline_user_args().has("--lobby"):
				start_match()
				match_rules.countdown = 0.0
		elif a == "--end":
			match_rules.time_left = 0.5
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
		elif a.begins_with("--gallery"):
			_gallery.call_deferred(int(a.substr(10)) if a.length() > 10 else 0)
		elif a.begins_with("--plane="):
			var pv := a.substr(8).split(",")
			_debug_plane = int(pv[0])
			_debug_skin = int(pv[1]) if pv.size() > 1 else 0
			apply_player_plane()
		elif a.begins_with("--look="):
			var lv := a.substr(7).split(",")
			controls.debug_look = Vector2(float(lv[0]), float(lv[1]) if lv.size() > 1 else 0.0)
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


## --botprobe: two bots dogfight, log every second (tuning the bot AI).
func _bot_probe() -> void:
	start_game()
	tutorial.step = 99
	wave_queue.clear()
	enemies.clear()
	fleet.clear_bots()
	jet.position.y = 2000.0
	jet.invuln = 999.0
	jet.autopilot = true
	var aces := fleet.spawn_pair(0, 0.95, BotBrain.DOGFIGHTER, Vector3(0, 300, 0), PI)
	var rooks := fleet.spawn_pair(1, 0.1, BotBrain.DOGFIGHTER, Vector3(0, 400, -900), 0.0)
	var a: Jet = aces[0]
	var b: Jet = rooks[0]
	for i in 100:
		if i % 10 == 9:
			print("PAIRS t=%d aces dmg=%.0f k=%d alive=%s,%s | rooks dmg=%.0f k=%d alive=%s,%s" % [i, aces[0].damage_dealt + aces[1].damage_dealt, aces[0].kills + aces[1].kills, aces[0].alive, aces[1].alive, rooks[0].damage_dealt + rooks[1].damage_dealt, rooks[0].kills + rooks[1].kills, rooks[0].alive, rooks[1].alive])
		await get_tree().create_timer(1.0).timeout
		for j in [a, b]:
			var o: Jet = b if j == a else a
			var to: Vector3 = o.position - j.position
			print("PROBE t=%d %s y=%.0f v=%.0f g=%.1f dist=%.0f off=%.2f roll=%.0f pitch=%.0f st=%d dmg=%.0f stick=%s" % [i, "ACE" if j == a else "ROOK", j.position.y, j.speed, j.g_load, to.length(), j.forward3().angle_to(to), rad_to_deg(j.roll), rad_to_deg(j.pitch), j.brain.state, j.damage_dealt, j.in_stick])
	get_tree().quit()


var _fight_test := false
var _crash_test := false
var _stick_demo := false
var _stall_warn := 0.0
var _was_locked := false
var _aim_demo := false
var _split_demo := false


## --fight (screenshots only): sit behind an enemy and shoot, so combat
## effects and HUD markers show up in review captures.
func _fight_tick() -> void:
	if not _fight_test or state != State.PLAY:
		return
	jet.invuln = 999.0
	if _frame == _shot_frames / 3 or _frame == _shot_frames * 2 / 3:
		for pl in fleet.planes:
			if pl.alive and pl.team == 1:
				jet.position = pl.position - pl.forward3() * 110.0 + Vector3(0, 6, 0)
				jet.set_attitude(pl.yaw, pl.pitch)
				break
	controls.fire = _frame > _shot_frames * 2 / 3


func _shot_tick() -> void:
	if _shot_path == "":
		return
	_fight_tick()
	if _stick_demo:
		var vs := get_viewport().get_visible_rect().size
		controls.dragging = true
		controls.drag_start = Vector2(vs.x * 0.2, vs.y * 0.62)
		controls.drag_pos = controls.drag_start + Vector2(0.55, 0.35) * controls.drag_radius
		controls.pressed["fire"] = true
	if _split_demo and _frame == _shot_frames - 150 and state == State.PLAY:
		# mid split-S at the shot: aim straight down and back
		jet.position.y = 1500.0
		jet.invuln = 999.0
		controls.set_aim((Vector3.DOWN - jet.forward3() * 0.25).normalized())
	if _aim_demo and _frame == _shot_frames - 25 and state == State.PLAY:
		controls.turn_aim(-0.8, 0.2) # aim off to the right: both reticles show
	if _crash_test and _frame == 30 and state == State.PLAY:
		jet.position.y = 320.0
		jet.crash()
	_frame += 1
	if _frame == _shot_frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("screenshot saved: ", _shot_path)
		print("REVIEW draws=%d objects=%d prims=%dk planes=%d mem=%dMB" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			fleet.planes.size(), OS.get_static_memory_usage() / 1048576])
		get_tree().quit()


func _process(delta: float) -> void:
	_shot_tick()
	if _hitstop_until > 0 and Time.get_ticks_msec() > _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0
	for pp in popups:
		pp[2] += delta
	for kf in kill_feed:
		kf[1] += delta
	while not kill_feed.is_empty() and kill_feed[0][1] > 6.0:
		kill_feed.pop_front()
	while not popups.is_empty() and popups[0][2] > 1.2:
		popups.pop_front()
	if state == State.PAUSE:
		return
	delta = minf(delta, 0.05)
	var frozen := state == State.PLAY and match_rules.countdown > 0.0
	if not frozen:
		jet.step(delta)
	_update_pilot(delta)
	if (state == State.PLAY or state == State.TITLE or state == State.OVER or state == State.RESULTS) and not frozen:
		fleet.step(delta)
	if state == State.PLAY:
		_update_border(delta)
		_track_live(delta)
		_stall_warn -= delta
		if jet.alive and jet.stalling and _stall_warn <= 0.0:
			_stall_warn = 0.35
			Controls.haptic(25, 0.4) # the stall horn is a loop (SoundScape)
		if missiles.locked and not _was_locked:
			Controls.haptic(20, 0.3)
		_was_locked = missiles.locked
		match_rules.update(delta)
		if _player_respawn > 0.0:
			_player_respawn -= delta
			if _player_respawn <= 0.0:
				_respawn_player()
	cam.aim_dir = controls.aim_dir if (jet.alive and jet.aim_mode() and state == State.PLAY) else Vector3.INF
	cam.aim_up = controls.aim_up
	cam.update_cam(delta, jet, jet.speed_ratio())
	# in the cockpit the own plane stays hidden (the 3D cockpit replaces it)
	cam.look_target = controls.look
	jet.visible = jet.alive and cam.cockpit_blend < 0.6
	cockpit.px_k = float(pv.ui_k)
	cockpit.scale = Vector2(pv.ui_k, pv.ui_k)
	cockpit.size = Vector2(pv.low) / float(pv.ui_k)
	cockpit.alpha = cam.cockpit_blend if state != State.TITLE else 0.0
	cockpit3d.set_size(pv.low)
	cockpit3d.update(delta, cockpit.alpha)
	music.set_mode("battle" if state == State.PLAY or state == State.PAUSE or state == State.OVER else "menu")
	# main menu: the plane in the hangar replaces the world behind the menu
	var stage_on := state == State.TITLE and menu.visible and menu.status_bar and not screens.visible
	_stage_a = move_toward(_stage_a, 1.0 if stage_on else 0.0, delta * 2.5)
	menu_stage.set_size(pv.low)
	menu_stage.update(delta, _stage_a > 0.0)
	pv.post_mat.set_shader_parameter("stage_alpha", _stage_a)
	pv.world_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if _stage_a >= 1.0 else SubViewport.UPDATE_ALWAYS
	pv.post_mat.set_shader_parameter("cockpit_alpha", cockpit.alpha if cockpit3d.active else 0.0)
	chunks.radius = 2 if quality == 0 else 3
	var gf := ground_focus()
	chunks.focus = gf
	traffic.focus = gf
	terrain.position = Vector3(snappedf(gf.x, 256.0), TERRAIN_Y, snappedf(gf.z, 256.0))
	clouds.opacity = lerpf(clouds.opacity, 1.0, 1.0 - exp(-delta * 3.0))
	clouds.mat.set_shader_parameter("near_fade", 260.0)
	fx.clear_columns_far(cam.focus, 900.0)
	daynight.focus = gf
	daynight.cam_alt = cam.global_position.y
	match str(world_map.current()["id"]):
		"desert":
			daynight.ground_albedo = Vector3(0.36, 0.24, 0.14)
		"snow":
			daynight.ground_albedo = Vector3(0.5, 0.55, 0.62)
		_:
			daynight.ground_albedo = Vector3(0.05, 0.16, 0.3)
	clouds.focus = gf
	_chim_t -= delta
	if _chim_t <= 0.0:
		_chim_t = 1.0
		chunks.chimney_tops(cam.focus, 450.0, fx.chimneys)
	# post effects: cloud fog, hit flash, speed lines
	pv.set_post("fog", clouds.fog_at(jet.position, delta) if jet.alive else 0.0)
	# god rays towards the sun (high quality, by day, strongest low sun)
	var sp: Vector3 = cam.global_position + daynight.sun_dir() * 10000.0
	var ray_k := 0.0
	if quality >= 2 and not cam.is_position_behind(sp) and daynight.night < 0.9:
		var suv: Vector2 = cam.unproject_position(sp) / Vector2(pv.low)
		pv.set_post("sun_uv", suv)
		var low_sun := 1.0 - clampf(daynight.sun_dir().y / 0.6, 0.0, 1.0)
		ray_k = (1.0 - daynight.night) * (0.18 + 0.42 * low_sun)
		pv.set_post("ray_col", Vector3(daynight.sun_col.r, daynight.sun_col.g, daynight.sun_col.b))
	pv.set_post("rays", ray_k)
	flash = maxf(0.0, flash - delta * 2.0)
	pv.set_post("flash", flash)
	pv.set_post("gblack", jet.gloc if jet.alive and state == State.PLAY else 0.0)
	pv.set_post("gred", jet.redout if jet.alive and state == State.PLAY else 0.0)
	speed_lines.size = Vector2(pv.low)
	speed_lines.strength = lerpf(speed_lines.strength, 1.0 if jet.boosting else 0.0, 1.0 - exp(-delta * 6.0))
	if state == State.PLAY and match_rules.mode == Match.CITY:
		if tutorial.active():
			tutorial.process(delta)
		else:
			_update_waves(delta)
	RenderingServer.global_shader_parameter_set("jet_pos", jet.global_position if jet.alive else Vector3(0, -1000, 0))
	RenderingServer.global_shader_parameter_set("jet_yaw", jet.yaw)
	banner_time -= delta
	Sfx.set_engine(state == State.PLAY and jet.alive, jet.speed_ratio())
	if state == State.PLAY and jet.alive and match_rules.mode == Match.CITY:
		_score_acc += delta * (2.0 + 6.0 * (jet.multiplier - 1))
		if _score_acc >= 1.0:
			score += int(_score_acc)
			_score_acc -= int(_score_acc)
	if state == State.OVER:
		_over_t += delta
		if _over_t > EJECT_TIME + 0.3 and not menu.visible:
			_open_game_over()


## Battle-area boundary: warning inside the edge, then the plane is turned
## back automatically after 4 s outside (or at once far outside).
func _update_border(delta: float) -> void:
	if not jet.alive:
		jet.steer_home = false
		return
	var o := world_map.outside(jet.position)
	if o > -WorldMap.BORDER_WARN:
		border_t += delta
	else:
		border_t = 0.0
	if (o > 0.0 and border_t > 4.0) or o > 500.0:
		if not jet.steer_home:
			Sfx.play("warn", -6.0)
		jet.steer_home = true
	elif o < -WorldMap.BORDER_WARN - 200.0:
		jet.steer_home = false


# ------------------------------------------------------------------ states

## Debug: every plane in a grid close to the camera (--gallery[=skin],
## --gallery=-1 cycles the skins per plane).
func _gallery(skin: int) -> void:
	menu.close()
	jet.visible = false
	var root := Node3D.new()
	add_child(root)
	root.global_position = jet.global_position + Vector3(0, 300, 0)
	for i in Planes.LIST.size():
		var st := SpriteStack.new()
		st.sheet = Planes.sheet_of(i)
		st.variant = i % Planes.SKINS.size() if skin < 0 else skin
		root.add_child(st)
		st.position = Vector3((i % 4 - 1.5) * 46.0, 0, (i / 4 - 1.0) * 40.0)
		st.rotation = Vector3(0, deg_to_rad(-35.0 if i % 2 == 0 else 35.0), 0)
	cam.override = root
	cam.override_offset = Vector3(0, 95, 62)
	cam.override_look = Vector3(0, 0, 8)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gview="):
			var v := a.substr(8).split(",")
			cam.override_offset = Vector3(float(v[0]), float(v[1]), float(v[2]))


func _to_title() -> void:
	state = State.TITLE
	get_tree().paused = false
	jet.autopilot = true
	controls.enabled = false
	screens.close()
	fleet.clear_bots()
	bases.clear()
	match_rules.running = false
	match_rules.mode = Match.CITY
	menu.open("SKY STACK", "Offline air combat",
		[["PLAY", _open_mode_menu], ["HANGAR", _open_hangar, func() -> bool: return Profile.has_new_plane() or Profile.has_new_skin()],
		["MISSIONS", _open_missions, Profile.has_claimable], ["PROFILE", _open_profile], ["SETTINGS", _open_settings_from_title]],
		[], 0.25, false, true)
	Profile.flush()


func _open_skins() -> void:
	_open_hangar()
	screens.skin_sel = Profile.skin_of(screens.sel)
	screens.page = "skins"


func _open_missions() -> void:
	menu.close()
	screens.show_page("missions", {"on_back": _to_title})


func _open_profile() -> void:
	menu.close()
	screens.show_page("profile", {"on_back": _to_title})


func _open_hangar() -> void:
	menu.close()
	screens.open_hangar(func() -> void:
		apply_player_plane()
		_to_title())


func _open_settings_from_title() -> void:
	menu.close()
	settings_ui.open()


func _open_mode_menu() -> void:
	state = State.TITLE
	screens.close()
	var items: Array = []
	if Save.settings.has("last_mode"):
		var lm := int(Save.settings["last_mode"])
		var ld := float(Save.settings.get("last_duel", 0.5))
		items.append([func() -> String: return tr("QUICK PLAY") + ": " + tr(Match.MODE_NAMES[lm]) + " - " + tr(world_map.current()["name"]),
			func() -> void: _open_lobby(lm, ld)])
	menu.open("CHOOSE MODE", "Bots fly the same planes you do", items + [
		["TEAM DOGFIGHT", func() -> void: _open_map_menu(Match.DOGFIGHT)],
		["BASE STRIKE", func() -> void: _open_map_menu(Match.BASE)],
		["CITY DEFENCE", func() -> void: _open_map_menu(Match.CITY)],
		["DUEL", _open_duel_menu],
		["BACK", _to_title],
	], [], 0.35)


func _open_duel_menu() -> void:
	menu.open("DUEL", "Choose your opponent", [
		["ROOKIE", func() -> void: _open_map_menu(Match.DUEL, 0.15)],
		["REGULAR", func() -> void: _open_map_menu(Match.DUEL, 0.45)],
		["VETERAN", func() -> void: _open_map_menu(Match.DUEL, 0.7)],
		["ACE", func() -> void: _open_map_menu(Match.DUEL, 0.95)],
		["BACK", _open_mode_menu],
	], [], 0.35)


## Map choice for a mode (city defence needs a city: no ocean map).
func _open_map_menu(mode: int, duel_skill: float = 0.5) -> void:
	var items: Array = []
	for i in Maps.LIST.size():
		var m: Dictionary = Maps.LIST[i]
		if mode == Match.CITY and float(m["city"]) <= 0.0:
			continue
		var idx := i
		items.append([m["name"], func() -> void: _choose_map(idx, mode, duel_skill)])
	items.append(["BACK", _open_mode_menu])
	menu.open("CHOOSE MAP", Match.MODE_NAMES[mode], items, [], 0.35)


func _choose_map(i: int, mode: int, duel_skill: float) -> void:
	Save.settings["map"] = i
	Save.store()
	world_map.apply(i)
	apply_settings("time")
	_open_lobby(mode, duel_skill)


## Bot skill centre matched to the player's rank (Bronze III ~0.2 .. Ace ~0.9).
func rank_skill() -> float:
	return clampf(0.2 + Profile.rank() / 15.0 * 0.7, 0.2, 0.9)


## Missiles per load for the hangar plane: its rack (with upgrades) scaled
## by the settings slider (6 = as designed).
func plane_missiles() -> int:
	var p := Profile.plane_index()
	var st := Planes.stats(p, Profile.levels(p))
	return maxi(1, roundi(float(st["missiles"]) * float(Save.settings["missiles"]) / 6.0))


## Put the player in the plane chosen in the hangar (stats, skin, missiles).
## Debug (--plane=i[,skin]): fly this plane without touching the profile.
var _debug_plane := -1
var _debug_skin := 0


func apply_player_plane() -> void:
	var p := Profile.plane_index() if _debug_plane < 0 else _debug_plane
	var lv := Profile.levels(p)
	jet.apply_plane(p, lv, Profile.skin_of(p) if _debug_plane < 0 else _debug_skin)
	var st := Planes.stats(p, lv)
	missiles.max_missiles = plane_missiles()
	missiles.ammo = missiles.max_missiles
	missiles.lock_time = st["lock_time"]
	Stacks.set_player_shadow(p)


var _lobby_mode := Match.DOGFIGHT
var _lobby_duel := 0.5


func _open_lobby(mode: int, duel_skill: float = 0.5) -> void:
	Save.settings["last_mode"] = mode
	Save.settings["last_duel"] = duel_skill
	_lobby_mode = mode
	_lobby_duel = duel_skill
	menu.close()
	state = State.LOBBY
	match_rules.configure(mode, int(Save.settings.get("team_size", 4)), rank_skill(), duel_skill)
	screens.show_page("lobby", {
		"mode_name": Match.MODE_NAMES[mode], "mode_info": Match.MODE_INFO[mode], "map_name": world_map.current()["name"], "map_info": world_map.current()["info"],
		"roster": match_rules.roster, "on_start": start_match, "on_back": _open_mode_menu,
	})


func start_game() -> void:
	match_rules.configure(Match.CITY, 4, rank_skill())
	start_match()


func start_match() -> void:
	screens.close()
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
	Engine.time_scale = 1.0
	wave_queue.clear()
	_player_respawn = -1.0
	fleet.clear_bots()
	bases.clear()
	jet.kills = 0
	jet.deaths = 0
	jet.assists = 0
	jet.damage_dealt = 0.0
	jet.base_damage = 0.0
	jet.ground_kills = 0
	jet.shots_fired = 0
	jet.shots_hit = 0
	kill_feed.clear()
	_clear_pilot()
	jet.pilot = Profile.player_name()
	_life_kills = 0
	_low_acc = 0.0
	_dodges_seen = missiles.dodges
	_match_achievements.clear()
	Profile.toasts.clear()
	apply_player_plane()
	jet.health = jet.max_health
	jet.flares = jet.max_flares
	border_t = 0.0
	jet.steer_home = false
	daynight.t = world_map.time_of_day()
	fleet.bound_half = world_map.half
	if world_map.current()["carriers"]:
		# two carrier fleets on the open sea, in every mode
		bases.build_naval(0, Vector3(0, 0, 3000), 0.0)
		bases.build_naval(1, Vector3(0, 0, -3000), PI)
	match_rules.start()
	if match_rules.mode == Match.CITY:
		fleet.respawn_delay = [12.0, -1.0]
		fleet.spawn_point = _city_spawn
		fleet.extra_targets = Callable()
		_spawn_wingmen()
		between_t = 3.0
		show_banner("GET READY", "Protect the city", 2.5)
		return
	# team modes
	between_t = 0.0
	tutorial.step = -1
	var military: bool = world_map.current().get("military", false)
	if military:
		# desert / snow: airfields + outposts in every team mode; targets in
		# BASE STRIKE, quiet scenery otherwise
		bases.build(0, Bases.find_land(Vector3(0, 0, 3200)), 0.0, true)
		bases.build(1, Bases.find_land(Vector3(0, 0, -3200)), PI, true)
		for t in 2:
			for p in bases.outpost_spots(t, 3, int(world_map.current()["seed"])):
				bases.build_outpost(t, p)
		bases.passive = match_rules.mode != Match.BASE
	if match_rules.mode == Match.BASE:
		if not bases.naval and not military:
			bases.build(0, Bases.find_land(Vector3(0, 0, 3200)), 0.0)
			bases.build(1, Bases.find_land(Vector3(0, 0, -3200)), PI)
		fleet.extra_targets = func(team: int) -> Array: return bases.alive_targets(1 - team)
	else:
		fleet.extra_targets = Callable()
	fleet.respawn_delay = [match_rules.respawn_delay(0), match_rules.respawn_delay(1)]
	fleet.spawn_point = match_rules.spawn_point
	var sp: Array = match_rules.spawn_point(0)
	jet.reset(sp[0], sp[1])
	jet.position = sp[0]
	for t in 2:
		var bots: Array = match_rules.roster[t].filter(func(e: Dictionary) -> bool: return not e.get("player", false))
		var prev: Jet = null
		for i in bots.size():
			var e: Dictionary = bots[i]
			var p: Array = match_rules.spawn_point(t)
			var b := fleet.spawn_bot(t, e["skill"], e["role"], p[0], p[1])
			b.pilot = e["name"]
			if e["role"] == BotBrain.ATTACKER:
				b.brain.ground_targets = bases.target_for
			if prev != null and prev.brain.partner == null:
				prev.brain.partner = b
				b.brain.partner = prev
				b.brain.leader = false
				if b.brain.role == BotBrain.ESCORT:
					b.brain.escort_of = prev
				prev = null
			else:
				prev = b
	show_banner(Match.MODE_NAMES[match_rules.mode], Match.MODE_INFO[match_rules.mode], 3.0)


func _city_spawn(team: int) -> Array:
	var a := rng.randf() * TAU
	var base := jet.position if team == 0 else jet.position + Vector3(cos(a), 0, sin(a)) * 1400.0
	return [Vector3(base.x + rng.randf_range(-200, 200), world_map.spawn_alt(), base.z + rng.randf_range(-200, 200)), rng.randf() * TAU]


func _respawn_player() -> void:
	_clear_pilot()
	var sp: Array = match_rules.spawn_point(0)
	jet.reset(sp[0], sp[1])
	jet.position = sp[0]
	trails.clear()
	controls.enabled = true
	show_banner("BACK IN THE FIGHT", "", 1.2)


func on_structure_destroyed(s: Object, src: Object) -> void:
	var who: String = src.pilot if src != null and is_instance_valid(src) and "pilot" in src else "Crash"
	var col := Color(0.5, 0.8, 1.0) if s.team == 1 else Color(1.0, 0.45, 0.4)
	kill_feed.append(["%s  >  %s %s" % [tr(who), tr("RED" if s.team == 1 else "BLUE"), tr(bases.kind_name(s.kind))], 0.0, col])
	if src == jet:
		score += 200
		popups.append([s.pos, "+200", 0.0])
		if state == State.PLAY:
			Profile.track("structure")
			if s.kind == Bases.AA:
				Profile.track("aa_kill")
			if bases.naval and s.kind == Bases.AIRFIELD:
				Profile.track("carrier_kill")


func on_match_finished() -> void:
	state = State.RESULTS
	controls.enabled = false
	controls.reset()
	Sfx.set_engine(false, 0.0)
	var res := match_rules.results(fleet.planes)
	_finish_profile(res, Match.MODE_KEYS[match_rules.mode])
	Sfx.play("clear" if res["won"] else "gameover")
	res["on_again"] = func() -> void: _open_lobby(_lobby_mode, _lobby_duel)
	res["on_menu"] = _to_title
	_last_results = res
	screens.show_page("results", res)


var _life_kills := 0
var _low_acc := 0.0
var _dodges_seen := 0


## Live mission / achievement counters (low flying, dodges) + toasts.
func _track_live(delta: float) -> void:
	if jet.alive and match_rules.countdown <= 0.0 and jet.position.y < CityGen.LOW_ALT:
		_low_acc += delta
		if _low_acc >= 1.0:
			_low_acc -= 1.0
			Profile.track("low_seconds", 1.0)
	if missiles.dodges > _dodges_seen:
		Profile.track("dodge", missiles.dodges - _dodges_seen)
		_dodges_seen = missiles.dodges
	while not Profile.toasts.is_empty():
		var t: Array = Profile.toasts.pop_front()
		hud.toast(t[0], t[1])
		_match_achievements.append(t)


var _match_achievements: Array = []


func _finish_profile(res: Dictionary, mode_key: String) -> void:
	# missions / achievements: battle results
	Profile.track("battle")
	if res.get("won", false):
		Profile.track("win")
		if mode_key in ["dogfight", "base", "duel"]:
			Profile.track("win_" + mode_key)
	if res.get("me_mvp", false):
		Profile.track("mvp")
	Profile.track("map_" + str(world_map.current()["id"]))
	while not Profile.toasts.is_empty():
		_match_achievements.append(Profile.toasts.pop_front())
	res["achievements"] = _match_achievements.duplicate()
	var xp0 := Profile.xp()
	var rank0 := Profile.rank()
	Profile.record_match({
		"mode": mode_key, "won": res.get("won", false), "kills": jet.kills, "deaths": jet.deaths, "assists": jet.assists,
		"shots": jet.shots_fired, "hits": jet.shots_hit, "damage": jet.damage_dealt, "base_damage": jet.base_damage,
		"ground_kills": jet.ground_kills, "mvp": res.get("me_mvp", false), "score": res.get("my_score", score),
		"plane": Planes.LIST[maxi(0, jet.plane)]["id"], "time": match_rules.elapsed, "xp": res.get("xp", 0), "coins": res.get("coins", 0),
		"missile_dodges": missiles.dodges,
	})
	res["rank_from"] = Profile.rank_float(xp0)
	res["rank_to"] = Profile.rank_float(Profile.xp())
	var rk := Profile.rank_of(Profile.xp())
	res["rank_text"] = tr("%s   %d / %d XP") % [tr(Profile.RANKS[rk[0]]), rk[1], rk[2]] if rk[2] > 0 else tr(Profile.RANKS[rk[0]])
	if Profile.rank() > rank0:
		res["rank_text"] = tr("RANK UP!") + "   " + res["rank_text"]
		res["rank_up"] = true



# ------------------------------------------------------------------ waves

func _start_wave(n: int) -> void:
	wave = n
	wave_queue.clear()
	# later waves mix the types: swarms, fighters, interceptors, bombers
	for i in 1 + n / 2:
		wave_queue.append(SWARM)
	# enemy fighters are real bots (same flight model as you), flying in pairs
	for i in mini(5, (enemy_jets + (n - 1) / 2 + 1) / 2):
		wave_queue.append(BOT_PAIR)
	if n >= 3:
		for i in mini(3, (n - 1) / 2):
			wave_queue.append(BOT_INTERCEPTOR)
	if n >= 2:
		for i in mini(3, n / 3):
			wave_queue.append(BOT_ATTACKER)
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
	show_banner(tr("WAVE %d") % n, sub, 2.5)
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
			var yaw := atan2(-(jet.position.x - p.x), -(jet.position.z - p.z))
			var sk := bot_skill()
			ok = true
			match t:
				SWARM:
					enemies.spawn_swarm(p, 5)
				BOT_PAIR:
					fleet.spawn_pair(1, sk, BotBrain.DOGFIGHTER, p, yaw)
				BOT_INTERCEPTOR:
					fleet.spawn_bot(1, sk, BotBrain.INTERCEPTOR, p, yaw)
				BOT_ATTACKER:
					var a_bot := fleet.spawn_bot(1, sk, BotBrain.ATTACKER, p, yaw)
					a_bot.brain.ground_targets = _city_target
				_:
					ok = enemies.spawn(t, p)
		if ok:
			wave_queue.pop_front()
		spawn_cd = rng.randf_range(0.6, 1.4)
	if wave_queue.is_empty() and enemies.count_active() == 0 and fleet.count_alive(1) == 0:
		var bonus := 500 * wave + int(city_hp / city_max * 500.0)
		score += bonus
		jet.health = minf(jet.max_health, jet.health + 20.0)
		Profile.track("wave")
		show_banner(tr("WAVE %d CLEAR") % wave, tr("+%d bonus   +20 HP") % bonus, 3.0)
		Sfx.play("clear")
		between_t = 4.0


# ------------------------------------------------------------------ bots

## Bot skill for the current wave (later: matched to the player's rank).
func bot_skill() -> float:
	return clampf(0.2 + 0.07 * wave + rng.randf_range(-0.1, 0.1), 0.05, 0.95)


func _spawn_wingmen() -> void:
	fleet.clear_bots()
	for i in wingmen_count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var p := jet.position + jet.right() * side * 90.0 * (i / 2 + 1) - jet.forward() * 60.0
		var w := fleet.spawn_bot(0, 0.6, BotBrain.ESCORT if i == 0 else BotBrain.DOGFIGHTER, p, jet.yaw)
		w.brain.escort_of = jet
		w.brain.partner = jet


## Building target for enemy attacker bots (strafing the city).
class CityTarget:
	var pos := Vector3.ZERO
	var active := true
	var kind := 1
	var id := -1


func _city_target(plane: Jet) -> Object:
	var b := chunks.random_building(plane.position, 1200.0, 30.0, rng)
	if b.is_empty():
		return null
	var t := CityTarget.new()
	t.pos = b["pos"] + Vector3(0, 10, 0)
	t.id = b["id"]
	return t


func _on_plane_killed(victim: Jet, killer: Jet, assist: Jet) -> void:
	var kn := killer.pilot if killer != null else tr("Crash")
	var col := Color(0.5, 0.8, 1.0) if (killer != null and killer.team == 0) else Color(1.0, 0.45, 0.4)
	kill_feed.append(["%s  >  %s" % [kn, victim.pilot], 0.0, col])
	if kill_feed.size() > 5:
		kill_feed.pop_front()
	if victim == jet:
		_life_kills = 0
	if killer == jet and victim != jet:
		on_enemy_killed(Enemies.JET, victim.position, 300)
		if state == State.PLAY:
			Profile.track("missile_kill" if victim.last_hit_missile else "gun_kill")
			if victim.brain != null and victim.brain.skill >= 0.8:
				Profile.track("ace_kill")
			if jet.plane >= 0:
				Profile.track("kill_" + ["light", "heavy", "attack"][int(Planes.LIST[jet.plane]["branch"])])
	elif assist == jet:
		Profile.track("assist")
		score += 100
		popups.append([victim.position, "ASSIST +100", 0.0])


func on_enemy_killed(type: int, at: Vector3, value: int) -> void:
	kills += 1
	if state == State.PLAY:
		_life_kills += 1
		Profile.track("kill")
		Profile.track("streak", _life_kills)
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
		Sfx.play_at("big_explode", at, 2.0)
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


var _pilot_stack: SpriteStack
var _ej := {} # ejection cinematic parts: seat, chute, canopy, wreck + velocities
const EJECT_TIME := 2.6


## Every death: a cinematic ejection (2.6 s, tap skips): short slow motion,
## the canopy spins away, the rocket seat fires up out of the burning wreck
## with flame and smoke, the seat falls away, the chute unfolds and swings;
## the wreck falls separately, burning, and explodes on impact.
func _on_ejected(at: Vector3) -> void:
	_clear_pilot()
	Controls.haptic(260, 1.0)
	var up: Vector3 = jet.orient.y if jet.orient.y.y > -0.2 else Vector3.UP
	var fwd: Vector3 = jet.forward3()
	var vel: Vector3 = fwd * jet.speed
	pilot = Node3D.new() # the pilot (+ chute later); camera follows it
	world.add_child(pilot)
	pilot.position = at + up * 3.0
	_pilot_stack = SpriteStack.new()
	_pilot_stack.sheet = "pilot"
	_pilot_stack.visible = false
	pilot.add_child(_pilot_stack)
	var seat := SpriteStack.new()
	seat.sheet = "eseat"
	pilot.add_child(seat)
	var chute := Node3D.new()
	chute.position = Vector3(0, 2.0, 0)
	chute.scale = Vector3(0.05, 0.2, 0.05)
	chute.visible = false
	var cs := SpriteStack.new()
	cs.sheet = "chute"
	chute.add_child(cs)
	pilot.add_child(chute)
	var canopy := Node3D.new()
	var cn := SpriteStack.new()
	cn.sheet = "canopy"
	canopy.add_child(cn)
	world.add_child(canopy)
	canopy.global_transform = Transform3D(jet.orient, at + up * 2.0)
	var wreck := Node3D.new()
	var wk := SpriteStack.new()
	wk.sheet = jet.sheet_name
	wk.variant = jet.skin
	wreck.add_child(wk)
	world.add_child(wreck)
	wreck.global_transform = Transform3D(jet.visual_basis(), at)
	_ej = {
		"seat": seat, "chute": chute, "canopy": canopy, "wreck": wreck,
		"seat_v": Vector3.ZERO, "canopy_v": vel * 0.6 + up * 45.0 - fwd * 20.0,
		"canopy_spin": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 9.0,
		"wreck_v": vel * 0.85, "wreck_spin": Vector3(randf_range(-0.5, 0.5), randf_range(-1, 1), randf_range(-2.5, 2.5)),
		"wreck_alive": true, "seat_sep": false,
	}
	_pilot_vel = vel * 0.4 + up * 70.0
	_eject_t = 0.0
	fx.eject(at, up, vel * 0.3)
	Sfx.play("boost", -2.0, 1.2)
	# short slow-motion moment
	Engine.time_scale = 0.3
	_hitstop_until = Time.get_ticks_msec() + 450
	cam.override = pilot
	cam.override_offset = -fwd * 60.0 + Vector3(0, -14, 0) + jet.right() * 30.0
	cam.override_look = Vector3(0, 6, 0)


func _clear_pilot() -> void:
	for k in ["canopy", "wreck", "seat_node"]:
		if _ej.has(k) and is_instance_valid(_ej[k]):
			_ej[k].queue_free()
	_ej.clear()
	if pilot != null and is_instance_valid(pilot):
		pilot.queue_free()
	pilot = null
	_pilot_stack = null
	cam.override = null
	cam.override_offset = Vector3(26.0, 10.0, 26.0)
	cam.override_look = Vector3(0, 4, 0)


## Tap during the ejection: jump to the end (chute open, wreck gone).
func skip_eject() -> void:
	if pilot == null or _eject_t >= EJECT_TIME:
		return
	Engine.time_scale = 1.0
	_hitstop_until = 0
	while _eject_t < EJECT_TIME:
		_update_pilot(0.05)
	if state == State.OVER:
		_over_t = 99.0


func _update_pilot(delta: float) -> void:
	if pilot == null:
		return
	_eject_t += delta
	var t := _eject_t
	var chute: Node3D = _ej["chute"]
	# --- canopy: spins away and falls
	var canopy: Variant = _ej.get("canopy")
	if canopy != null and is_instance_valid(canopy):
		_ej["canopy_v"] += Vector3(0, -30.0, 0) * delta
		_ej["canopy_v"] *= 1.0 - 0.6 * delta
		canopy.position += _ej["canopy_v"] * delta
		var sp: Vector3 = _ej["canopy_spin"]
		canopy.basis = canopy.basis.rotated(sp.normalized(), sp.length() * delta)
		if canopy.position.y < 1.0 or t > 6.0:
			canopy.queue_free()
			_ej.erase("canopy")
	# --- wreck: burning, tumbling, falls and explodes on impact
	var wreck: Variant = _ej.get("wreck")
	if wreck != null and is_instance_valid(wreck):
		_ej["wreck_v"] += Vector3(0, -G_WRECK, 0) * delta
		_ej["wreck_v"] *= 1.0 - 0.25 * delta
		wreck.position += _ej["wreck_v"] * delta
		var wsp: Vector3 = _ej["wreck_spin"]
		wreck.basis = (wreck.basis * Basis.from_euler(wsp * delta)).orthonormalized()
		fx.spawn(wreck.position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), Vector3(0, 6, 0), randf_range(0.3, 0.6), randf_range(2.0, 3.5), Fx.FIRE)
		fx.spawn(wreck.position, Vector3(0, 10, 0), randf_range(1.2, 2.2), randf_range(2.5, 4.0), Fx.SMOKE)
		if wreck.position.y < 3.0 or (chunks.collide(wreck.position.x, wreck.position.z, 4.0, wreck.position.y) != Vector2.ZERO):
			fx.explosion(wreck.position, 2.0)
			fx.add_column(Vector3(wreck.position.x, maxf(1.0, wreck.position.y), wreck.position.z), 0.6)
			Sfx.play_at("big_explode", wreck.position, 0.0)
			wreck.queue_free()
			_ej.erase("wreck")
	# --- seat phase: rocket climb with flame + smoke trail
	if t < 0.8:
		var back := -_pilot_vel.normalized()
		fx.spawn(pilot.position + back * 2.5, back * 25.0 + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 0.25, 2.6, Fx.FIRE)
		fx.spawn(pilot.position + back * 3.5, back * 8.0, randf_range(0.8, 1.4), randf_range(1.6, 2.6), Fx.SMOKE)
		_pilot_vel = _pilot_vel.lerp(Vector3(_pilot_vel.x * 0.5, 15.0, _pilot_vel.z * 0.5), 1.0 - exp(-delta * 2.0))
		var seat0: Node3D = _ej["seat"]
		seat0.basis = Basis(Vector3.RIGHT, sin(t * 6.0) * 0.15)
	else:
		if not _ej["seat_sep"]:
			# seat separation: the seat tumbles away, the pilot hangs free
			_ej["seat_sep"] = true
			var seat: Node3D = _ej["seat"]
			_ej.erase("seat")
			var sp_world := seat.global_transform
			pilot.remove_child(seat)
			world.add_child(seat)
			seat.global_transform = sp_world
			_ej["seat_node"] = seat
			_ej["seat_v"] = _pilot_vel * 0.6 + Vector3(randf_range(-6, 6), -4, randf_range(-6, 6))
			_pilot_stack.visible = true
			chute.visible = true
			# camera: below and to the side, looking up at the chute
			cam.override_offset = Vector3(62.0, -16.0, 48.0)
			cam.override_look = Vector3(0, 10, 0)
		# chute unfolds over 0.7 s with a small overshoot, then breathes
		var k := clampf((t - 0.8) / 0.7, 0.0, 1.0)
		var e := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0) # ease-out-back
		var w := lerpf(0.05, 1.0, e) * (1.0 + 0.03 * sin(t * 3.0))
		chute.scale = Vector3(w, lerpf(0.2, 1.0, minf(1.0, k * 1.4)), w)
		# swinging under the canopy
		pilot.basis = Basis.from_euler(Vector3(sin(t * 1.7) * 0.18 * k, t * 0.25, cos(t * 1.3) * 0.12 * k))
		_pilot_vel = _pilot_vel.lerp(Vector3(4.0, -6.0, 2.0), 1.0 - exp(-delta * 2.2 * maxf(k, 0.2)))
		var sn: Variant = _ej.get("seat_node")
		if sn != null and is_instance_valid(sn):
			_ej["seat_v"] += Vector3(0, -30.0, 0) * delta
			sn.position += _ej["seat_v"] * delta
			sn.basis = sn.basis.rotated(Vector3(1, 0.3, 0.2).normalized(), 5.0 * delta)
			if sn.position.y < 1.0 or t > 5.0:
				sn.queue_free()
				_ej.erase("seat_node")
	pilot.position += _pilot_vel * delta
	if pilot.position.y < 1.0:
		pilot.position.y = 1.0
	if state == State.TITLE and _eject_t > 3.0:
		# attract mode crashed into something: just start a new flight
		_clear_pilot()
		jet.reset(SPAWN, 0.0)
		jet.autopilot = true


const G_WRECK := 22.0


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
	return wave_queue.size() + enemies.count_active() + fleet.count_alive(1)


func debug_extra() -> String:
	return "VIS %s BL %.2f T %.2f N %.1f  CARS %d  FX %d  BULLETS %d  ENEMIES %d | JET %d,%d  SPD %d  NEAR %d  CAM %s FOV %d" % [jet.visible, cam.cockpit_blend, daynight.t, daynight.night, traffic.active_cars, fx.n, combat.n, enemies.count_active(), jet.position.x, jet.position.z, jet.speed, jet.near_tall, GameCamera.MODE_NAMES[cam.mode], cam.fov]


func _on_cam() -> void:
	cam.cycle_mode()
	Save.cam_mode = cam.mode
	Save.store()
	if menu.visible and state == State.PAUSE:
		_open_pause()
	Sfx.play("ui")


func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION)
	if tap and pilot != null and _eject_t < EJECT_TIME and (state == State.PLAY or state == State.OVER) and not menu.visible:
		skip_eject()


## Android back gesture / button and app switching.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		# leaving the app: keep progress and pause a running battle
		Profile.flush()
		Save.store()
		if state == State.PLAY:
			_open_pause()


## Back = one step back: closes overlays, pauses a battle, returns from
## screens to the title; on the title it saves and quits.
func _go_back() -> void:
	if settings_ui.visible:
		settings_ui.visible = false
		Save.store()
		if state == State.PAUSE:
			_open_pause()
		else:
			_to_title()
	elif intel.visible:
		intel.visible = false
		_open_pause()
	elif state == State.PLAY:
		_open_pause()
	elif state == State.PAUSE:
		_resume()
	elif screens.visible and screens.page == "skins":
		screens.page = "hangar"
	elif screens.visible or state == State.LOBBY or state == State.RESULTS or state == State.OVER:
		_to_title()
	elif menu.visible and menu.title != "SKY STACK":
		_to_title()
	else:
		Profile.flush()
		Save.store()
		get_tree().quit()


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
		[func() -> String: return tr("VIEW: ") + tr(GameCamera.MODE_NAMES[cam.mode]), _on_cam],
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
	for k in ["speed", "boost", "turn", "bank", "cruise", "ceiling", "clearance", "crashes", "cannon", "reload", "assist", "g_tol", "bleed"]:
		jet.cfg[k] = st[k]
	jet.invert_pitch = st["invert"]
	missiles.max_missiles = plane_missiles()
	missiles.reload_time = st["reload"]
	var sc := int(st["scheme"])
	controls.scheme = Controls.STICK if sc == 2 else Controls.AIM
	controls.aim_joy = sc == 0
	controls.aim_speed = float(st["aim_speed"])
	controls.aim_sens = float(st["aim_sens"])
	if key == "missiles" or key == "":
		missiles.ammo = missiles.max_missiles
	if key == "cannon":
		jet.ammo = float(st["cannon"])
	wingmen_count = int(st["wingmen"])
	for k in ["speed", "boost", "turn", "bank", "cruise", "ceiling", "clearance", "cannon", "reload", "assist", "g_tol", "bleed"]:
		fleet.plane_cfg[k] = st[k]
	enemy_jets = int(st["enemy_jets"])
	cam.transition = st["view_change"]
	cam.chase_dist = st["chase_dist"]
	cam.chase_height = st["chase_height"]
	cam.shake_mult = st["shake"]
	if key == "view" or key == "":
		cam.mode = int(st.get("view", 1)) as GameCamera.Mode
		cam._since_switch = 0.0
	daynight.cycle = st["day_cycle"]
	if key == "lang" or key == "":
		Save.apply_language()
	if key == "traffic" or key == "":
		traffic.set_level(int(st["traffic"]))
	if key == "time" or key == "":
		daynight.t = world_map.time_of_day()
	if (key == "islands" or key == "seed") and world_map.index == 0:
		world_map.apply(0, true)
	if world_map.current()["feature"] != CityGen.FEAT_NONE:
		jet.cfg["cruise"] = maxf(float(st["cruise"]), world_map.spawn_alt())
		fleet.plane_cfg["cruise"] = jet.cfg["cruise"]
	var camt := world_map.cloud_amount()
	var cover := lerpf(0.82, 0.5, camt) if camt > 0.0 else 1.1
	clouds.cover = cover
	clouds.set_layer(float(world_map.current().get("cloud_base", 650.0)), 500.0)
	# the GPU clouds and their shadows use the volumetric threshold
	RenderingServer.global_shader_parameter_set("cloud_cover", cover - Clouds.VOL_OFFSET if int(st.get("quality", 2)) >= 1 else cover)
	RenderingServer.global_shader_parameter_set("jet_shadow_size", float(Stacks.get_sheet("jet").w) if st["jet_shadow"] else 0.0001)
	# graphics quality: low = no sun shadows / bloom / soft effects,
	# medium = shadows + bloom, high = soft shadows, richer smoke and water
	quality = int(st.get("quality", 2))
	pv.set_quality(quality)
	clouds.set_quality(quality)
	chunks.set_shadows(quality >= 1)
	plane_shadows.enabled = quality >= 1
	Stacks.shadow_mat.set_shader_parameter("soft", 1.0 if quality >= 2 else 0.0)
	RenderingServer.global_shader_parameter_set("gfx_quality", float(quality))
	fx.quality = quality
	pv.set_post("bloom", float(st["glow"]) * 0.55 if quality >= 1 else 0.0)
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
	if match_rules.is_team_mode():
		_player_respawn = match_rules.respawn_delay(0)
		# the HUD shows the RESPAWN countdown; the banner only says what happened
		show_banner("SHOT DOWN", "", 1.4)
		return
	state = State.OVER
	_over_t = 0.0
	if over_reason == "":
		over_reason = "YOUR JET WAS SHOT DOWN" 
	controls.enabled = false
	Sfx.play("gameover")


func _open_game_over() -> void:
	var record := Save.submit_score(score)
	var res := {"won": false, "my_score": score, "xp": 50 + score / 20 + kills * 30, "coins": 20 + score / 40 + kills * 15}
	_finish_profile(res, "city")
	menu.open("GAME OVER", tr(over_reason) + (("   -   " + tr("NEW HIGH SCORE!")) if record else ""), [
		["RETRY", start_game],
		["TITLE", _to_title],
	], [tr("KILLS  %d      WAVES  %d") % [kills, wave], tr("SCORE  %d      BEST  %d") % [score, Save.high_score],
		tr("+%d XP     +%d COINS") % [int(res["xp"]), int(res["coins"])], res.get("rank_text", ""), "TAP ANYWHERE TO RETRY"], 0.55, true)


## Extra checks for the headless launch test (tests/run_tests.gd).
func test_hook(t: Node) -> Array:
	var errs: Array = []
	# the touch tests fly the jet for real (it may have crashed): fresh start
	start_game()
	jet.position.y = 420.0
	jet.invuln = 3.0
	_start_wave(4)
	between_t = 0.0
	for i in 30:
		spawn_cd = 0.0
		_update_waves(0.016)
	await t.get_tree().create_timer(1.5).timeout
	if enemies.count_active() == 0:
		errs.append("no enemies spawned in wave 4")
	if traffic.active_cars < Traffic.LEVEL_CARS[traffic.level] / 3:
		errs.append("too few cars (%d of %d)" % [traffic.active_cars, Traffic.LEVEL_CARS[traffic.level]])
	# shoot: guaranteed kill of one enemy through the combat path
	var before := kills
	for e in enemies.pool:
		if e.active and e.type != Enemies.AAGUN:
			e.hp = 0.5
			enemies.hit_test(e.pos, 1.0)
			break
	if kills != before + 1:
		errs.append("enemy kill not registered")
	# --- team dogfight 4v4: lobby roster, countdown, kills, results, profile
	_open_lobby(Match.DOGFIGHT)
	if match_rules.roster[0].size() != 4 or match_rules.roster[1].size() != 4:
		errs.append("lobby roster is not 4v4")
	start_match()
	if fleet.planes.size() != 8:
		errs.append("dogfight did not spawn 8 planes (%d)" % fleet.planes.size())
	var froze := jet.position
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	if jet.position.distance_to(froze) > 1.0:
		errs.append("planes move during the countdown")
	match_rules.countdown = 0.0
	var victim: Jet = fleet.enemy_planes(0)[0]
	victim.damage(999.0, jet)
	await t.get_tree().process_frame
	if match_rules.score[0] != 1 or jet.kills != 1:
		errs.append("kill not credited to the player / team score (score %s kills %d)" % [match_rules.score, jet.kills])
	var b0 := Profile.stat("battles")
	match_rules.time_left = 0.01
	await t.get_tree().create_timer(0.3).timeout
	if state != State.RESULTS or not screens.visible:
		errs.append("results screen not shown at the end of the match")
	if Profile.stat("battles") != b0 + 1:
		errs.append("match not recorded in the profile")
	# --- base strike: destroying the enemy base wins
	_open_lobby(Match.BASE)
	start_match()
	match_rules.countdown = 0.0
	if bases.structures.size() != 22:
		errs.append("base strike should build 2 x 11 structures (%d)" % bases.structures.size())
	for st in bases.alive_targets(1):
		st.take_damage(999.0, jet)
	await t.get_tree().create_timer(0.3).timeout
	if state != State.RESULTS or match_rules.winner != 0:
		errs.append("destroying the enemy base did not win the match")
	if jet.base_damage <= 0.0:
		errs.append("base damage not credited")
	state = State.PLAY
	start_game()
	# --- bots: aces vs rookies, same flight model as the player
	wave_queue.clear()
	tutorial.step = 99
	enemies.clear()
	fleet.clear_bots()
	jet.invuln = 999.0
	jet.position.y = 400.0
	var c0 := jet.position + Vector3(0, 0, -900)
	var aces := fleet.spawn_pair(0, 0.95, BotBrain.DOGFIGHTER, jet.position + Vector3(0, -100, -200), PI)
	var rookies := fleet.spawn_pair(1, 0.1, BotBrain.DOGFIGHTER, c0, 0.0)
	if float(aces[0].cfg["turn"]) != float(jet.cfg["turn"]) or float(rookies[0].cfg["speed"]) != float(jet.cfg["speed"]):
		errs.append("bots do not share the player's flight model")
	var low := 0
	var dmg_a := 0.0
	var dmg_r := 0.0
	# A single 15 s fight is noisy (an ace can whiff a pass); keep fighting
	# up to 45 s total and judge the cumulative damage.
	# a realistic turning fight takes ~30-60 s from the merge to first hits
	for attempt in 4:
		for i in 100:
			await t.get_tree().create_timer(0.25).timeout
			for b in aces + rookies:
				if b.alive and b.position.y < 25.0:
					low += 1
		dmg_a = aces[0].damage_dealt + aces[1].damage_dealt
		dmg_r = rookies[0].damage_dealt + rookies[1].damage_dealt
		if dmg_a > dmg_r and dmg_a > 0.0:
			break
	print("    bots: aces dmg %.0f kills %d | rookies dmg %.0f kills %d | low %d" % [dmg_a, aces[0].kills + aces[1].kills, dmg_r, rookies[0].kills + rookies[1].kills, low])
	if dmg_a + dmg_r <= 0.0:
		errs.append("bots never hit each other")
	if dmg_a < dmg_r:
		errs.append("aces did less damage than rookies")
	if low > 12:
		errs.append("bots keep flying into the ground")
	fleet.clear_bots()
	# the long fight may have killed the test jet (mid-air collisions are
	# fatal): start the next checks from a clean flight
	if not jet.alive or state != State.PLAY:
		start_game()
		between_t = 0.0
	tutorial.step = 99
	wave_queue.clear()
	jet.position.y = 420.0
	jet.invuln = 0.0
	tutorial.step = -1
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
	fleet.process_mode = Node.PROCESS_MODE_DISABLED
	fleet.clear_bots()
	wave_queue.clear()
	tutorial.step = 99 # pause the wave director while testing
	enemies.clear()
	jet.autopilot = false
	jet.position.y = 320.0
	jet.set_attitude(jet.yaw)
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

	# --- enemy missile: flares released 1-2 s before impact decoy it
	enemies.clear()
	missiles.clear()
	jet.invuln = 0.0
	jet.flares = maxi(jet.flares, 3)
	jet.flares_active = 0.0
	missiles.flare_luck = 1.0
	var dc0 := missiles.decoys
	var fl0 := jet.flares
	var hp0 := jet.health
	missiles.fire_enemy(jet.position - jet.forward() * 300.0)
	var flared := false
	for i in 900:
		await t.get_tree().process_frame
		if not flared and missiles.incoming_t < 1.5:
			flared = jet.release_flares()
		if missiles.decoys > dc0:
			break
	for i in 60:
		await t.get_tree().process_frame
	missiles.flare_luck = -1.0
	if missiles.decoys <= dc0 or jet.flares != fl0 - 1:
		errs.append("flares did not decoy the missile (decoys %d, flares %d -> %d)" % [missiles.decoys - dc0, fl0, jet.flares])
	if jet.health < hp0:
		errs.append("a decoyed missile still hit the plane")
	# --- out-maneuvered: target outside the seeker's view / missile out of energy
	missiles.clear()
	var dg0 := missiles.dodges
	var m1 = missiles._spawn(true, jet.position + jet.right() * 500.0, -jet.forward3() * 300.0, jet)
	var m2 = missiles._spawn(true, jet.position - jet.forward3() * 900.0, jet.forward3() * 150.0, jet)
	m2.burn = 0.0
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	if missiles.dodges < dg0 + 2 or m1 == null:
		errs.append("missiles that lost the target / their energy were not evaded (%d)" % (missiles.dodges - dg0))
	missiles.clear()
	# --- instructor: aim 90 degrees to the right, the nose follows it
	var sch0 := controls.scheme
	controls.scheme = Controls.AIM
	jet.position.y = 600.0
	jet.set_attitude(jet.yaw)
	jet.speed = jet.base_speed()
	var goal_dir: Vector3 = Basis(Vector3.UP, -PI * 0.5) * jet.forward3()
	goal_dir.y = 0.0
	controls.set_aim(goal_dir)
	var y_before := jet.position.y
	for i in 480:
		await t.get_tree().process_frame
		if jet.forward3().angle_to(controls.aim_dir) < 0.12:
			break
	var nerr := jet.forward3().angle_to(controls.aim_dir)
	print("    instructor: nose error %.2f rad, alt %.0f -> %.0f" % [nerr, y_before, jet.position.y])
	if nerr > 0.25:
		errs.append("instructor did not bring the nose onto the aim (error %.2f rad)" % nerr)
	# --- 3D maneuvers: aim below and behind -> split-S (rolls inverted,
	# pulls through, ends lower flying the other way); aim up and back ->
	# Immelmann (half loop, rolls upright on top, ends higher)
	jet.position.y = 1500.0
	jet.set_attitude(jet.yaw)
	jet.speed = jet.base_speed()
	var h0: Vector3 = jet.forward3()
	controls.set_aim((Vector3.DOWN - h0 * 0.25).normalized())
	var inverted := false
	var stage := 0
	for i in 900:
		await t.get_tree().process_frame
		inverted = inverted or jet.orient.y.y < -0.7
		if stage == 0 and jet.forward3().y < -0.8:
			stage = 1
			controls.set_aim(-Vector3(h0.x, 0.0, h0.z).normalized())
		if stage == 1 and jet.forward3().dot(-h0) > 0.97:
			break
	print("    split-S: inverted %s, heading %.2f, alt 1500 -> %.0f" % [inverted, jet.forward3().dot(h0), jet.position.y])
	if not inverted or jet.forward3().dot(h0) > -0.9 or jet.position.y > 1450.0:
		errs.append("split-S not flown (inverted %s, heading %.2f, alt %.0f)" % [inverted, jet.forward3().dot(h0), jet.position.y])
	var h1: Vector3 = jet.forward3()
	var y1 := jet.position.y
	controls.set_aim((Vector3.UP - h1 * 0.25).normalized())
	stage = 0
	var over_top := false
	for i in 1200:
		await t.get_tree().process_frame
		over_top = over_top or (jet.orient.y.y < -0.7 and jet.forward3().dot(h1) < 0.0)
		if stage == 0 and jet.forward3().y > 0.8:
			stage = 1
			controls.set_aim(-Vector3(h1.x, 0.0, h1.z).normalized())
		if stage == 1 and jet.orient.y.y > 0.9 and jet.forward3().dot(-h1) > 0.95:
			break
	print("    Immelmann: over the top %s, upright %.2f, heading %.2f, alt %.0f -> %.0f" % [over_top, jet.orient.y.y, jet.forward3().dot(h1), y1, jet.position.y])
	if not over_top or jet.orient.y.y < 0.8 or jet.forward3().dot(h1) > -0.9 or jet.position.y < y1 + 100.0:
		errs.append("Immelmann not flown (over top %s, upright %.2f, heading %.2f, alt %.0f -> %.0f)" % [over_top, jet.orient.y.y, jet.forward3().dot(h1), y1, jet.position.y])
	# the aim lives on the full sphere: straight down and over the top
	controls.set_aim(jet.forward3())
	controls.turn_aim(0.0, PI * 0.5)
	var straight_up := controls.aim_dir.y > 0.99
	controls.turn_aim(0.0, PI * 0.5)
	if not straight_up or controls.aim_dir.dot(jet.forward3()) > -0.95:
		errs.append("the aim does not go straight up and over the top (%s)" % controls.aim_dir)
	controls.set_aim(jet.forward3())
	# --- instructor ground protection: aim straight down low over the ground
	jet.position.y = 140.0
	jet.speed = jet.base_speed()
	jet.set_attitude(jet.yaw, -0.5) # diving at the ground, aim along the dive
	controls.set_aim(jet.forward3())
	var min_y := 999.0
	var warned := false
	for i in 240:
		await t.get_tree().process_frame
		min_y = minf(min_y, jet.position.y)
		warned = warned or Instructor.warning == "PULL UP"
	if not jet.alive or min_y < 8.0 or not warned:
		errs.append("instructor did not pull up from the ground (min alt %.0f, warned %s)" % [min_y, warned])
	controls.set_aim(jet.forward3())
	controls.scheme = sch0
	jet.position.y = 400.0
	jet.invuln = 0.0
	Engine.time_scale = 1.0
	fleet.process_mode = Node.PROCESS_MODE_INHERIT
	_spawn_wingmen()
	await t.get_tree().process_frame
	if fleet.count_alive(0) != 1 + wingmen_count:
		errs.append("wingman bot missing")
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
	if d["speed"] != 130.0 or d["cruise"] != 220.0 or d["missiles"] != 6.0 or d["islands"] != 0.33 or d["glow"] != 0.6 or d["contrast"] != 0.05 or d["traffic"] != 1:
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
	# RESET TO DEFAULTS restores every value and re-applies it
	settings_ui.set_value("speed", 200.0)
	settings_ui.set_value("traffic", 2)
	settings_ui.reset_to_defaults()
	if float(jet.cfg["speed"]) != float(d["speed"]) or traffic.level != int(d["traffic"]) or Save.settings.size() < d.size():
		errs.append("reset to defaults did not restore settings")
	# cockpit view: camera locks into the canopy, jet hidden, overlay shown
	# (level flight, the aim on the nose: no G head motion)
	jet.position.y = maxf(jet.position.y, 400.0)
	jet.set_attitude(jet.yaw)
	cam.mode = GameCamera.Mode.COCKPIT
	cam._since_switch = 0.0
	await t.get_tree().create_timer(2.5).timeout
	if jet.visible or cam.cockpit_blend < 0.9:
		errs.append("cockpit view did not engage (blend %.2f, jet visible %s)" % [cam.cockpit_blend, jet.visible])
	# Phase E: player settings page, debug page, no SKINS on the main menu
	settings_ui.debug_page = false
	var pk: Array = []
	for r in settings_ui.page_rows():
		pk.append(r[1])
	if pk != ["lang", "quality", "volume", "music", "scheme", "aim_speed", "aim_sens", "invert", "stick_indicator", "vibration"]:
		errs.append("player settings page shows %s" % [pk])
	settings_ui.debug_page = true
	if settings_ui.page_rows().size() < 30:
		errs.append("debug settings page is missing tuning rows")
	settings_ui.debug_page = false
	var pcm := Music.render("battle")
	var mpeak := 0
	for i in range(0, pcm.size(), 64):
		mpeak = maxi(mpeak, absi(pcm.decode_s16(i)))
	if pcm.size() < Music.RATE * 2 * 8 or mpeak < 3000:
		errs.append("music did not render (%d bytes, peak %d)" % [pcm.size(), mpeak])
	# Phase F: flight sound loops are clean (no clipping, seamless) and
	# follow the plane: engine + burner at full throttle, stall horn, lock tone
	var wait := 0
	while not Sfx.loops_ready and wait < 60:
		await t.get_tree().process_frame
		wait += 1
	for ln in SoundScape.LOOPS:
		var ws: AudioStreamWAV = Sfx.streams.get(ln)
		if ws == null:
			errs.append("sound loop %s missing" % ln)
			continue
		var dd := ws.data
		var lpk := 0
		for i in range(0, dd.size(), 8):
			lpk = maxi(lpk, absi(dd.decode_s16(i)))
		var seam := absi(dd.decode_s16(0) - dd.decode_s16(dd.size() - 2))
		if lpk < 1500 or lpk > 32000 or seam > 9000:
			errs.append("sound loop %s: peak %d, seam jump %d" % [ln, lpk, seam])
	controls.throttle = 1.0
	await t.get_tree().create_timer(0.8).timeout
	if not sound._p["eng_rumble"].playing or not sound._p["burner"].playing or not sound._p["wind"].playing:
		errs.append("engine / afterburner / wind sound not playing at full throttle")
	controls.throttle = Jet.THR_MIL
	# a few slow vessels on the water
	var fast := 0.0
	for bt in traffic.river_boats + traffic.sea_boats:
		fast = maxf(fast, bt.w)
	if traffic.river_boats.size() != 3 or traffic.sea_boats.size() != 1 or fast > 21.0:
		errs.append("too many / too fast vessels (%d + %d, top %.0f)" % [traffic.river_boats.size(), traffic.sea_boats.size(), fast])
	# graphics quality: low turns the sun shadows off, high back on
	settings_ui.set_value("quality", 0)
	if chunks.shadows or quality != 0:
		errs.append("low quality did not switch shadows off")
	settings_ui.set_value("quality", 2)
	# volumetric clouds: dense spots in the layer, nothing above it; a plane
	# inside one is hidden from missiles; flying in turns the view white
	if not clouds.volumetric:
		errs.append("high quality should use the volumetric clouds")
	var dense := Vector3.INF
	var cy: float = clouds.base + clouds.thick * 0.25
	for gz in range(-20, 21):
		for gx in range(-20, 21):
			var cp := Vector3(jet.position.x + gx * 120.0, cy, jet.position.z + gz * 120.0)
			if clouds.density(cp) > 0.5:
				dense = cp
				break
		if dense != Vector3.INF:
			break
	if dense == Vector3.INF:
		errs.append("no dense cloud within 2.4 km of the cloud layer")
	else:
		if not missiles.target_hidden(dense):
			errs.append("a plane inside a cloud is not hidden from missiles")
		if clouds.density(dense + Vector3(0, clouds.thick + 50.0, 0)) > 0.0:
			errs.append("cloud density above the layer")
		clouds.fog = 0.0
		var wf := 0.0
		for k in 6:
			wf = clouds.fog_at(dense, 0.2)
		if wf < 0.3:
			errs.append("no white-out inside a cloud (%.2f)" % wf)
		clouds.fog = 0.0
	# 3D cockpit: rendered, small HUD combiner in the upper middle, panel
	# below the centre, the stick follows the input
	var hs: Array = cockpit3d.hud_screen()
	var hr: Rect2 = hs[0]
	if not cockpit3d.active or cockpit3d._body.mesh == null or cockpit3d._body.mesh.get_surface_count() == 0:
		errs.append("3D cockpit not active / no geometry")
	elif hr.size.x <= 0.0 or hr.size.x > pv.low.x * 0.2 or absf(hr.get_center().x - pv.low.x * 0.5) > 4.0:
		errs.append("HUD combiner wrong size / place (%s of %s; roll %.2f rr %.2f look %s home %s err %.2f)" % [hr, pv.low, jet.roll, jet._roll_rate, cam.look, jet.steer_home, jet.forward3().angle_to(controls.aim_dir)])
	elif cockpit3d.lip_y() < pv.low.y * 0.55:
		errs.append("glareshield too high (%.0f of %d)" % [cockpit3d.lip_y(), pv.low.y])
	controls.debug_look = Vector2(0, 0)
	jet.stick_override = Vector2(1, 0)
	await t.get_tree().create_timer(0.2).timeout
	if absf(cockpit3d._stick.rotation.z) < 0.05:
		errs.append("cockpit stick does not follow the input")
	jet.stick_override = Vector2.INF
	controls.debug_look = Vector2.INF
	cam.mode = GameCamera.Mode.CHASE
	# a crash is fatal: the pilot ejects (close-up), city defence ends
	jet.position.y = float(jet.cfg["clearance"]) - 1.0
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	if jet.alive or pilot == null or cam.override == null or state != State.OVER:
		errs.append("hitting the ground should kill and eject the pilot (alive %s, pilot %s)" % [jet.alive, pilot != null])
	await t.get_tree().create_timer(2.2).timeout
	if not _ej.has("chute") or not _ej["chute"].visible or _ej["chute"].scale.x < 0.9:
		errs.append("parachute did not open")
	if not _ej.get("seat_sep", false):
		errs.append("ejection seat did not separate")
	start_game()
	jet.position.y = 320.0
	jet.crash()
	skip_eject()
	if _eject_t < EJECT_TIME or _over_t < 50.0:
		errs.append("tap should skip the ejection")
	start_game()
	if pilot != null or cam.override != null:
		errs.append("pilot close-up not cleared on restart")
	# --- flight physics: energy, G, stall, class differences
	start_game()
	between_t = 99.0
	tutorial.step = 99
	wave_queue.clear()
	fleet.process_mode = Node.PROCESS_MODE_DISABLED
	jet.position = Vector3(0, 2500, 0)
	jet.set_attitude(0.0)
	jet.speed = jet.base_speed()
	jet.invuln = 99.0
	controls.reset()
	jet.stick_override = Vector2(0, 1) # full pull, wings level
	var v0 := jet.speed
	var gmax := 0.0
	for i in 60:
		await t.get_tree().physics_frame
		gmax = maxf(gmax, jet.g_load)
	if gmax < float(jet.phys["max_g"]) * 0.8:
		errs.append("full pull should reach high G (%.1f)" % gmax)
	jet.stick_override = Vector2(1, 1) # hard banked turn
	for i in 180:
		await t.get_tree().physics_frame
	if jet.speed > v0 - 15.0:
		errs.append("a hard turn should bleed speed (%.0f -> %.0f)" % [v0, jet.speed])
	if jet.gloc <= 0.0 and float(jet.phys["max_g"]) > float(jet.cfg["g_tol"]):
		errs.append("sustained G above the tolerance should start a grey-out")
	if jet.gloc > 0.46:
		errs.append("grey-out must never become a full blackout")
	# dive gains speed, climb loses it
	jet.stick_override = Vector2.ZERO
	jet.set_attitude(0.0, -0.8)
	var vd := jet.speed
	for i in 90:
		await t.get_tree().physics_frame
	if jet.speed <= vd:
		errs.append("diving should gain speed (%.0f -> %.0f)" % [vd, jet.speed])
	jet.position.y = 2500.0
	jet.set_attitude(0.0, 1.2)
	var vc := jet.speed
	for i in 90:
		await t.get_tree().physics_frame
	if jet.speed >= vc:
		errs.append("climbing should lose speed (%.0f -> %.0f)" % [vc, jet.speed])
	# slow + nose up = stall
	jet.position.y = 2500.0
	jet.set_attitude(0.0, 0.3)
	jet.speed = float(jet.phys["vs"]) * 0.6
	jet.stick_override = Vector2(0, 1)
	var stalled := false
	for i in 40:
		await t.get_tree().physics_frame
		stalled = stalled or jet.stalling
	if not stalled:
		errs.append("flying below stall speed with the stick back should stall")
	jet.stick_override = Vector2.INF
	var lt := Planes.physics(Planes.index_of("wren"), {})
	var at := Planes.physics(Planes.index_of("mattock"), {})
	var ht := Planes.physics(Planes.index_of("bastion"), {})
	if not (lt["roll"] > ht["roll"] and lt["roll"] > at["roll"] and ht["vab"] > lt["vab"] and at["vs"] < ht["vs"]):
		errs.append("plane classes should fly differently")
	fleet.process_mode = Node.PROCESS_MODE_INHERIT
	start_game()
	# --- maps: relief, carriers, borders
	world_map.apply(1)
	var relief := 0
	for bz in range(-40, 40, 2):
		for bx in range(-40, 40, 2):
			if CityGen.relief_h(bx, bz) > 0.0:
				relief += 1
	if relief < 40:
		errs.append("desert has too few mesas (%d)" % relief)
	if CityGen.relief_hw(0.0, 2400.0) > 0.0:
		errs.append("desert relief on the spawn point")
	var urban := 0
	for bz in range(-20, 20):
		for bx in range(-20, 20):
			if CityGen.is_urban(bx * 4, bz * 4):
				urban += 1
	if urban > 0:
		errs.append("desert canyon still has city blocks (%d)" % urban)
	_open_lobby(Match.BASE)
	start_match()
	match_rules.countdown = 0.0
	var fuel := bases.structures.filter(func(st: Bases.Structure) -> bool: return st.kind == Bases.FUEL).size()
	if bases.passive or bases.structures.size() < 2 * 14 + 8 or fuel < 6:
		errs.append("desert base strike: bases/outposts missing (%d structures, %d fuel)" % [bases.structures.size(), fuel])
	_open_lobby(Match.DOGFIGHT)
	start_match()
	if not bases.passive or bases.structures.is_empty():
		errs.append("desert dogfight: bases should be quiet scenery")
	world_map.apply(2)
	var peak := 0.0
	for bz in range(-40, 40):
		for bx in range(-40, 40):
			peak = maxf(peak, CityGen.relief_h(bx, bz))
	if peak < 150.0:
		errs.append("snow mountains too low (%.0f)" % peak)
	world_map.apply(4)
	_open_lobby(Match.BASE)
	start_match()
	match_rules.countdown = 0.0
	if not bases.naval or bases.structures.size() != 22:
		errs.append("ocean carrier fleets not built (%d)" % bases.structures.size())
	var own_d := Vector2(jet.position.x - bases.centers[0].x, jet.position.z - bases.centers[0].z).length()
	if own_d < 800.0:
		errs.append("player spawns on top of own carrier group (%.0f units)" % own_d)
	if world_map.outside(jet.position) > -WorldMap.BORDER_WARN:
		errs.append("ocean spawn is near the battle-area edge")
	jet.apply_plane(0, {}, 0) # the same plane whatever the local profile holds
	jet.position = Vector3(world_map.half + 700.0, 600.0, 0.0)
	jet.set_attitude(-PI * 0.5) # flying +X, away from the area
	jet.invuln = 99.0
	await t.get_tree().create_timer(0.3).timeout
	if not jet.steer_home:
		errs.append("leaving the battle area did not turn the plane back")
	var off0 := absf(wrapf(jet.yaw - atan2(jet.position.x, jet.position.z), -PI, PI))
	await t.get_tree().create_timer(4.0).timeout
	var off1 := absf(wrapf(jet.yaw - atan2(jet.position.x, jet.position.z), -PI, PI))
	if off1 > off0 - 0.6:
		errs.append("plane not turning home (%.2f -> %.2f rad)" % [off0, off1])
	world_map.apply(0)
	# --- hangar: buy, select, upgrade, skins; the plane is used in battle
	var backup: Dictionary = Profile.data.duplicate(true)
	Profile.data["coins"] = 50000
	Profile.data["xp"] = 4000 # SILVER III
	_to_title()
	_open_hangar()
	screens.sel = Planes.index_of("vireo")
	if Profile.plane_lock_reason(screens.sel) != "":
		errs.append("vireo should be buyable at silver (%s)" % Profile.plane_lock_reason(screens.sel))
	if not Profile.buy_plane(screens.sel) or not Profile.owns(screens.sel):
		errs.append("buying a plane failed")
	Profile.select_plane(screens.sel)
	for k in 3:
		Profile.upgrade(screens.sel, "engine")
	if Profile.levels(screens.sel)["engine"] != 3:
		errs.append("engine upgrades not stored")
	if Profile.buy_plane(Planes.index_of("zephyr")):
		errs.append("tier 4 bought without tier 3 / rank")
	if not Profile.unlock_skin(2):
		errs.append("coin skin not bought")
	Profile.equip_skin(screens.sel, 2)
	Profile.set_tail(42)
	_open_lobby(Match.DOGFIGHT)
	start_match()
	var want: float = Planes.physics(screens.sel, Profile.levels(screens.sel), float(Save.settings["speed"]) / 130.0)["vmil"]
	if jet.plane != screens.sel or jet.skin != 2 or absf(jet.base_speed() - want) > 0.01 or Profile.tail() != 42:
		errs.append("hangar plane / skin / upgrades not used in battle (plane %d skin %d)" % [jet.plane, jet.skin])
	var red_skin := fleet.planes.filter(func(pl: Jet) -> bool: return pl.team == 1 and pl.skin == Planes.RED_SKIN).size()
	if red_skin < 4:
		errs.append("red team should fly the aggressor scheme (%d)" % red_skin)
	if Profile.rank_of(0)[0] != 0 or Profile.rank_of(999999)[0] != Profile.RANKS.size() - 1:
		errs.append("rank table wrong")
	# --- Android back: pause / resume a battle, step back from screens
	start_game()
	_go_back()
	var paused_ok := state == State.PAUSE
	_go_back()
	if not paused_ok or state != State.PLAY:
		errs.append("back gesture should pause and resume a battle")
	_to_title()
	_open_missions()
	_go_back()
	if screens.visible or state != State.TITLE:
		errs.append("back from a screen should return to the title")
	# --- missions, weekly challenges, achievements
	Profile.data["missions"]["day"] = "1999-01-01" # yesterday's list
	var dl: Array = Profile.daily()
	if dl.size() != 3 or Profile.data["missions"]["day"] != Missions.day_key():
		errs.append("daily missions not refreshed for a new day")
	if Profile.weekly().size() != 3:
		errs.append("weekly challenges missing")
	var mev: String = Missions.daily_def(dl[0]["id"])[2]
	var goal := float(Missions.daily_def(dl[0]["id"])[3])
	var coins0 := Profile.coins()
	Profile.track(mev, goal)
	if not Profile.mission_done(dl[0], false) or not Profile.has_claimable():
		errs.append("mission progress not tracked (%s)" % mev)
	if not Profile.claim_mission(0, false) or Profile.coins() <= coins0 or Profile.claim_mission(0, false):
		errs.append("mission claim failed or claimed twice")
	var old_id: String = Profile.daily()[1]["id"]
	if not Profile.reroll(1) or Profile.daily()[1]["id"] == old_id or Profile.reroll(2):
		errs.append("free daily reroll wrong")
	Profile.data["skins"].erase(Missions.TIGER_SKIN)
	Profile.data["skins"].erase(float(Missions.TIGER_SKIN))
	Profile.data["ach_seen"].erase("aces")
	Profile.data["counters"]["ace_kill"] = 0
	Profile.toasts.clear()
	Profile.track("ace_kill")
	if Profile.ach_reached("aces") != 0 or Profile.toasts.is_empty() or not Profile.has_skin(Missions.TIGER_SKIN):
		errs.append("achievement tier / toast / Tiger skin unlock failed")
	if not Profile.claim_achievement("aces") or Profile.claim_achievement("aces"):
		errs.append("achievement claim wrong")
	Profile.track("streak", 4)
	Profile.track("streak", 2)
	if Profile.counter("streak") < 4.0:
		errs.append("best streak should keep the maximum")
	Profile.set_player_name("  Viper  ")
	if Profile.player_name() != "Viper":
		errs.append("profile name not saved")
	# battle events feed missions: a structure kill by the player
	_open_lobby(Match.BASE)
	start_match()
	match_rules.countdown = 0.0
	var st0 := Profile.counter("structure")
	for st in bases.alive_targets(1):
		if st.kind == Bases.AA:
			st.take_damage(999.0, jet)
			break
	if Profile.counter("structure") != st0 + 1.0 or Profile.counter("aa_kill") < 1.0:
		errs.append("structure kills not tracked")
	Profile.data = backup
	Profile.save()
	_to_title()
	print("    enemies=%d cars=%d fx=%d score=%d relief=%d peak=%.0f" % [enemies.count_active(), traffic.active_cars, fx.n, score, relief, peak])
	return errs
