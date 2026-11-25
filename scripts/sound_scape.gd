class_name SoundScape
extends Node
## Continuous flight sound, mixed every frame from the plane's state:
##  engine   - core rumble + turbine whine; RPM spools up / down with lag
##             behind the throttle, pitch and level follow it
##  burner   - afterburner roar fading in / out with the flame
##  wind     - grows with speed squared, buffeting under high G / stall
##  stall    - two-tone horn while stalling
##  pilot    - breathing that speeds up and gets heavier with G, a straining
##             grunt above ~6.5 G (in the cockpit)
##  gun      - cannon burst loop while firing, a tail when it stops
##  seeker   - growl while a missile is searching (rising as it locks), a
##             steady tone when locked
##  flyby    - a whoosh when another plane flashes past close
## Cockpit vs outside: in the cockpit the World bus is low-passed (outside
## sounds muffled), the whine, instruments and the pilot are louder;
## outside, the burner and wind are louder and the pilot is silent.

var game: Node
var _p := {} # name -> AudioStreamPlayer
var _rpm := 0.0
var _ab := 0.0
var _gun_t := 0.0
var _gun_was := false
var _grunt_cd := 0.0
var _g_hi := false
var _flyby_cd := {}

const LOOPS := {
	"eng_rumble": "World", "eng_whine": "Cockpit", "burner": "World", "wind": "World",
	"breath": "Cockpit", "gun": "World", "seek": "Cockpit", "lock": "Cockpit", "stall": "Cockpit",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in LOOPS:
		var p := AudioStreamPlayer.new()
		p.bus = LOOPS[k]
		p.volume_db = -80.0
		add_child(p)
		_p[k] = p


## The player's cannon fired a round (keeps the burst loop going).
func gun_shot() -> void:
	_gun_t = 0.09


func _mix(k: String, lin: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _p[k]
	if p.stream == null:
		if Sfx.streams.has(k):
			p.stream = Sfx.streams[k]
		else:
			return
	var on := lin > 0.004 and not Sfx.muted
	if on and not p.playing:
		p.play(randf() * maxf(0.0, p.stream.get_length() - 0.1))
	elif not on and p.playing:
		p.stop()
	if on:
		p.volume_db = linear_to_db(lin)
		p.pitch_scale = clampf(pitch, 0.3, 3.0)


func _process(delta: float) -> void:
	if game == null or not Sfx.loops_ready:
		return
	var jet: Jet = game.jet
	var playing: bool = game.state == game.State.PLAY and jet != null and jet.alive and not game.get_tree().paused
	var k: float = game.cam.cockpit_blend
	Sfx.set_cockpit(k)
	Sfx.listener = game.cam.global_position
	if not playing:
		for n in LOOPS:
			_mix(n, 0.0)
		_gun_was = false
		return
	# engine: RPM lags the throttle (spool-up ~1 s)
	_rpm = move_toward(_rpm, clampf(jet.throttle, 0.05, 1.0), delta * 0.9)
	_ab = move_toward(_ab, 1.0 if jet.boosting else 0.0, delta * (3.0 if jet.boosting else 1.6))
	var spd := clampf(jet.speed / maxf(1.0, jet.boost_speed()), 0.0, 1.3)
	_mix("eng_rumble", (0.16 + 0.36 * _rpm + 0.12 * _ab) * (1.0 - 0.35 * k), 0.72 + 0.55 * _rpm)
	_mix("eng_whine", (0.03 + 0.12 * _rpm) * (0.55 + 0.75 * k), 0.75 + 0.5 * _rpm)
	_mix("burner", _ab * (0.62 - 0.27 * k), 0.92 + 0.12 * _rpm)
	# wind ~ speed^2, buffet under high G or a stall
	var buffet := clampf((jet.g_load - 5.0) / 4.0, 0.0, 1.0) * 0.3 + (0.35 if jet.stalling else 0.0)
	_mix("wind", (spd * spd * 0.42 + buffet) * (1.0 - 0.35 * k), 0.7 + 0.55 * spd + buffet * 0.3)
	_mix("stall", 0.32 if jet.stalling else 0.0)
	# pilot: breathing in the cockpit, faster and heavier with G
	var gk := clampf((jet.g_load - 1.0) / 7.0, 0.0, 1.0)
	_mix("breath", (0.05 + gk * 0.42) * smoothstep(0.3, 0.8, k), 0.85 + gk * 0.8)
	_grunt_cd -= delta
	var hi := jet.g_load > 6.5
	if hi and not _g_hi and _grunt_cd <= 0.0 and k > 0.3:
		Sfx.play("grunt", -6.0)
		_grunt_cd = 2.2
	_g_hi = hi
	# cannon burst + tail
	_gun_t -= delta
	var firing := _gun_t > 0.0
	_mix("gun", 0.55 if firing else 0.0, 1.0)
	if _gun_was and not firing:
		Sfx.play("gun_tail", -4.0)
	_gun_was = firing
	# missile seeker tones
	var m: Missiles = game.missiles
	var tracking: bool = m.lock_target != null
	var lk := clampf(m.lock_t / maxf(0.05, m.lock_time), 0.0, 1.0)
	_mix("seek", (0.2 + 0.15 * k) if tracking and not m.locked else 0.0, 0.85 + 0.4 * lk)
	_mix("lock", (0.22 + 0.15 * k) if m.locked else 0.0)
	# flybys of other planes close to the camera
	for pl in game.fleet.planes:
		if pl == jet or not pl.alive:
			continue
		var d: float = pl.position.distance_to(Sfx.listener)
		var id: int = pl.get_instance_id()
		var cd: float = _flyby_cd.get(id, 0.0) - delta
		_flyby_cd[id] = cd
		if d < 130.0 and cd <= 0.0:
			Sfx.play_at("flyby", pl.position, -2.0, randf_range(0.9, 1.15))
			_flyby_cd[id] = 3.5
