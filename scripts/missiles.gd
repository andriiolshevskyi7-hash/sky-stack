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
	var enemy := false
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var target: Object = null
	var life := 0.0
	var smoke_cd := 0.0
	var dodged := false

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


func _spawn(enemy: bool, p: Vector3, v: Vector3, target: Object) -> M:
	for m in pool:
		if not m.active:
			m.active = true
			m.enemy = enemy
			m.pos = p
			m.vel = v
			m.target = target
			m.life = 5.0
			m.dodged = false
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
		_spawn(false, p, jet.forward3() * (jet.speed + 40.0) + jet.right() * side * 25.0, tgt)
	Sfx.play("boost", -2.0, 1.4)
	if ammo <= 0:
		reload = reload_time
	if volley:
		game.show_banner("COUNTER!", "", 0.8)


func fire_enemy(from: Vector3) -> void:
	var active := 0
	for m in pool:
		if m.active and m.enemy:
			active += 1
	if active >= 2:
		return
	_spawn(true, from, (jet.position - from).normalized() * 120.0, jet)
	Sfx.play("alarm", -14.0, 1.6)


func _enemy_pos(o: Object) -> Vector3:
	return o.pos if o != null and o.active else Vector3.INF


func _update_lock(delta: float) -> void:
	var best: Object = null
	var best_d := LOCK_RANGE
	var f := jet.forward3()
	for e in enemies.pool:
		if not e.active:
			continue
		var v: Vector3 = e.pos - jet.position
		var d := v.length()
		if d < best_d and d > 20.0 and v.dot(f) / d > cos(LOCK_CONE):
			best_d = d
			best = e
	if best != null and best == lock_target:
		lock_t += delta
	else:
		lock_target = best
		lock_t = 0.0
	locked = lock_target != null and lock_t >= LOCK_TIME


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
		var tp := jet.position if m.enemy else _enemy_pos(m.target)
		var spd := minf(m.vel.length() + 160.0 * delta, 260.0 if not m.enemy else 190.0)
		if tp != Vector3.INF and not m.dodged:
			var want := (tp - m.pos).normalized() * spd
			m.vel = m.vel.lerp(want, 1.0 - exp(-delta * (5.0 if not m.enemy else 2.6)))
		m.vel = m.vel.normalized() * spd
		m.pos += m.vel * delta
		m.smoke_cd -= delta
		if m.smoke_cd <= 0.0:
			m.smoke_cd = 0.03
			fx.spawn(m.pos, Vector3(0, 3, 0), 1.2, 2.2, Fx.SMOKE)
			fx.spawn(m.pos, Vector3.ZERO, 0.08, 2.0, Fx.BURNER)
		var done := m.life <= 0.0 or m.pos.y < 0.0
		if m.enemy and jet.alive and not m.dodged:
			var d := m.pos.distance_to(jet.position)
			var closing := maxf(30.0, (m.vel - jet.forward3() * jet.speed).dot((jet.position - m.pos).normalized()))
			var t := maxf(0.0, d - 18.0) / closing
			if t < incoming_t:
				incoming_t = t
				incoming_pos = m.pos
			if d < 18.0:
				if jet.dodge_window > 0.0:
					m.dodged = true
					dodges += 1
					counter_t = 2.5
					game.show_banner("DODGED!", "Fire a MISSILE now: free volley of 3", 1.5)
					if slowmo_s > 0.0:
						Engine.time_scale = 0.35
						_slowmo_until = Time.get_ticks_msec() + int(slowmo_s * 1000.0)
				else:
					hits_taken += 1
					jet.damage(25.0)
					fx.explosion(m.pos, 0.8)
					done = true
		elif not m.enemy:
			if enemies.hit_test(m.pos, 8.0):
				fx.explosion(m.pos, 1.0)
				done = true
		if done:
			if m.life <= 0.0:
				fx.explosion(m.pos, 0.5)
			m.active = false
			continue
		batch.push(m.pos, 2.5, Color(1, 0.4, 0.3) if m.enemy else Color(1, 1, 0.9))
	batch.end()
