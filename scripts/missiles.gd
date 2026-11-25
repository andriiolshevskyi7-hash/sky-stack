class_name Missiles
extends Node3D
## Lock-on + homing missiles for the player, enemy missiles with the
## two-ring dodge mechanic, counter-attack volleys and slow motion.

const MAX := 40
const LOCK_TIME := 0.8
const LOCK_CONE := 0.25
const LOCK_RANGE := 900.0

class M:
	var active := false
	var enemy := false # fired by team 1
	var shooter: Object = null # Jet that fired it (null = enemy ground/air unit)
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var target: Object = null # Jet, enemy unit (E) or ground target
	var life := 0.0
	var smoke_cd := 0.0
	var dodged := false
	var rolled := false

var pool: Array[M] = []
var batch: PointBatch
var game: Node
var jet: Jet
var enemies: Enemies
var fx: Fx

var max_missiles := 6
var ammo := 6
var reload := 0.0
var reload_time := 5.0
var counter_t := 0.0 # > 0: next missile fires a free volley of three
var slowmo_s := 1.3
var _slowmo_until := 0
var lock_target: Object = null
var lock_t := 0.0
var locked := false
var incoming_t := 99.0 # seconds until the nearest enemy missile hits
var incoming_pos := Vector3.ZERO
var dodges := 0
var hits_taken := 0
var fleet: Node
var clouds: Node
var _beep_t := 0.0
var _warn_t := 0.0


func _ready() -> void:
	for i in MAX:
		pool.append(M.new())
	batch = PointBatch.new().setup(MAX * 2)
	add_child(batch)


func clear() -> void:
	for m in pool:
		m.active = false
	ammo = max_missiles
	reload = 0.0
	lock_target = null
	lock_t = 0.0
	locked = false


func _spawn(enemy: bool, p: Vector3, v: Vector3, target: Object, shooter: Object = null) -> M:
	for m in pool:
		if not m.active:
			m.active = true
			m.enemy = enemy
			m.shooter = shooter
			m.pos = p
			m.vel = v
			m.target = target
			m.life = 5.0
			m.dodged = false
			m.rolled = false
			return m
	return null


func fire_player() -> void:
	if not jet.alive or reload > 0.0:
		return
	var volley := counter_t > 0.0
	var n := 3 if volley else 1
	if not volley:
		ammo -= 1
	counter_t = 0.0
	var tgt: Object = lock_target if locked else null
	for i in n:
		var side := float(i - (n - 1) * 0.5)
		var p := jet.position + jet.right() * side * 10.0 - Vector3(0, 3, 0)
		_spawn(jet.team == 1, p, jet.forward3() * (jet.speed + 40.0) + jet.right() * side * 25.0, tgt, jet)
	Sfx.play("boost", -2.0, 1.4)
	if ammo <= 0:
		reload = reload_time
	if volley:
		game.show_banner("COUNTER!", "", 0.8)


## Missile from any plane (bots use this after their own lock-on).
func fire_from(plane: Jet, target: Object) -> void:
	_spawn(plane.team == 1, plane.position - Vector3(0, 3, 0), plane.forward3() * (plane.speed + 40.0), target, plane)
	if jet != null and plane.position.distance_squared_to(jet.position) < 800.0 * 800.0:
		Sfx.play("boost", -10.0, 1.4)


## Missile from an enemy unit (boss / fighters of city defence) at the player.
func fire_enemy(from: Vector3) -> void:
	var active := 0
	for m in pool:
		if m.active and m.enemy and m.target == jet:
			active += 1
	if active >= 2:
		return
	_spawn(true, from, (jet.position - from).normalized() * 120.0, jet)
	Sfx.play("alarm", -14.0, 1.6)


static func tpos(o: Object) -> Vector3:
	if o == null or not is_instance_valid(o):
		return Vector3.INF
	if o is Jet:
		return o.position if o.alive else Vector3.INF
	return o.pos if o.active else Vector3.INF


func target_hidden(p: Vector3) -> bool:
	return clouds != null and clouds.inside(p)


## Candidates for the player's lock: enemy units + enemy-team planes.
func _update_lock(delta: float) -> void:
	var best: Object = null
	var best_d := LOCK_RANGE
	var f := jet.forward3()
	var cands: Array = []
	if enemies != null:
		for e in enemies.pool:
			if e.active:
				cands.append(e)
	if fleet != null:
		for pl in fleet.planes:
			if pl.alive and pl.team != jet.team:
				cands.append(pl)
		if fleet.extra_targets.is_valid():
			cands.append_array(fleet.extra_targets.call(jet.team))
	for c in cands:
		var cp := tpos(c)
		var v: Vector3 = cp - jet.position
		var d := v.length()
		if d < best_d and d > 20.0 and v.dot(f) / d > cos(LOCK_CONE) and not target_hidden(cp):
			best_d = d
			best = c
	if best != null and best == lock_target:
		lock_t += delta
	else:
		lock_target = best
		lock_t = 0.0
	locked = lock_target != null and lock_t >= LOCK_TIME


## Seconds until the nearest missile aimed at `plane` hits (99 = none).
func incoming_for(plane: Object) -> float:
	var best := 99.0
	for m in pool:
		if m.active and not m.dodged and m.target == plane:
			var tp := tpos(plane)
			if tp == Vector3.INF:
				continue
			var d := m.pos.distance_to(tp)
			var closing := maxf(30.0, (m.vel - plane.forward3() * plane.speed).dot((tp - m.pos).normalized()))
			best = minf(best, maxf(0.0, d - 18.0) / closing)
	return best


func _process(delta: float) -> void:
	# slow motion runs on real time
	if _slowmo_until > 0 and Time.get_ticks_msec() > _slowmo_until:
		_slowmo_until = 0
		Engine.time_scale = 1.0
	counter_t = maxf(0.0, counter_t - delta)
	if reload > 0.0:
		reload -= delta
		if reload <= 0.0:
			ammo = max_missiles
	if jet == null:
		return
	if jet.alive:
		_update_lock(delta)
	# lock-on audio: beeps speed up and rise while locking, steady tone when locked
	_beep_t -= delta
	if lock_target != null and jet.alive and _beep_t <= 0.0:
		var k := clampf(lock_t / LOCK_TIME, 0.0, 1.0)
		if locked:
			Sfx.play("tone", -12.0, 1.0)
			_beep_t = 0.18
		else:
			Sfx.play("beep", -14.0, 0.8 + k * 0.7)
			_beep_t = lerpf(0.3, 0.08, k)
	# incoming missile warning
	_warn_t -= delta
	if incoming_t < 3.0 and _warn_t <= 0.0:
		Sfx.play("warn", -8.0)
		_warn_t = clampf(incoming_t * 0.25, 0.08, 0.4)
	incoming_t = 99.0
	batch.begin()
	for m in pool:
		if not m.active:
			continue
		m.life -= delta
		var tp := tpos(m.target)
		var spd := minf(m.vel.length() + 160.0 * delta, 190.0 if m.enemy and m.shooter == null else 250.0)
		if tp != Vector3.INF and not m.dodged:
			var want := (tp - m.pos).normalized() * spd
			m.vel = m.vel.lerp(want, 1.0 - exp(-delta * (2.6 if m.target is Jet else 5.0)))
		m.vel = m.vel.normalized() * spd
		m.pos += m.vel * delta
		m.smoke_cd -= delta
		if m.smoke_cd <= 0.0:
			m.smoke_cd = 0.03
			fx.spawn(m.pos, Vector3(0, 3, 0), 1.2, 2.2, Fx.SMOKE)
			fx.spawn(m.pos, Vector3.ZERO, 0.08, 2.0, Fx.BURNER)
		var done := m.life <= 0.0 or m.pos.y < 0.0
		if m.target is Jet and tp != Vector3.INF and not m.dodged:
			var tj: Jet = m.target
			var d := m.pos.distance_to(tp)
			var closing := maxf(30.0, (m.vel - tj.forward3() * tj.speed).dot((tp - m.pos).normalized()))
			var t := maxf(0.0, d - 18.0) / closing
			if tj == jet and t < incoming_t:
				incoming_t = t
				incoming_pos = m.pos
			if d < 18.0:
				if tj.dodge_window > 0.0:
					m.dodged = true
					if tj == jet:
						dodges += 1
						counter_t = 2.5
						game.show_banner("DODGED!", "Fire a MISSILE now: free volley of 3", 1.5)
						if slowmo_s > 0.0:
							Engine.time_scale = 0.35
							_slowmo_until = Time.get_ticks_msec() + int(slowmo_s * 1000.0)
				elif tj.flares_active > 0.0:
					m.dodged = true
				else:
					if tj == jet:
						hits_taken += 1
					tj.damage(25.0, m.shooter)
					fx.explosion(m.pos, 0.8)
					done = true
		elif m.target != null and m.target.has_method("take_damage") and tp != Vector3.INF:
			if m.pos.distance_to(tp) < 26.0:
				m.target.take_damage(30.0, m.shooter)
				fx.explosion(m.pos, 1.2)
				done = true
		elif not (m.target is Jet) and not m.enemy:
			if enemies.hit_test(m.pos, 8.0):
				fx.explosion(m.pos, 1.0)
				done = true
		if not done and m.target == null and fleet != null and fleet.hit_test(m.pos, 1 if m.enemy else 0, 12.0, m.shooter, 14.0):
			fx.explosion(m.pos, 1.0)
			done = true
		if done:
			if m.life <= 0.0:
				fx.explosion(m.pos, 0.5)
			m.active = false
			continue
		batch.push(m.pos, 2.5, Color(1, 0.4, 0.3) if m.enemy else Color(1, 1, 0.9))
	batch.end()
