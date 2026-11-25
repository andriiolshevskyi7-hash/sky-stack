class_name Combat
extends Node3D
## Pooled projectiles: player cannon, enemy bullets, flak shells, bombs and
## enemy shots aimed at buildings. One draw call for all of them.

enum { BULLET, FLAK, BOMB, BLD_SHOT }
const MAX := 400
const PLAYER_SPEED := 430.0

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var life := PackedFloat32Array()
var dmg := PackedFloat32Array()
var owner_enemy := PackedByteArray()
var kind := PackedInt32Array()
var target := PackedInt64Array()
var src: Array = [] # shooter (Jet) or null
var n := 0
var batch: PointBatch

var game: Node
var jet: Jet
var enemies: Node
var chunks: ChunkManager
var fx: Fx
var fleet: Node # Fleet: all planes (player + bots)
var sound: Node # SoundScape (cannon burst loop)
var bases: Node # Bases (base strike)


func _ready() -> void:
	for a in [pos, vel]:
		a.resize(MAX)
	life.resize(MAX)
	dmg.resize(MAX)
	owner_enemy.resize(MAX)
	kind.resize(MAX)
	target.resize(MAX)
	src.resize(MAX)
	batch = PointBatch.new().setup(MAX * 3)
	batch.name = "BulletBatch"
	add_child(batch)


func clear() -> void:
	n = 0


func _spawn(p: Vector3, v: Vector3, l: float, d: float, enemy: bool, k: int, t: int = -1, shooter: Object = null) -> void:
	if n >= MAX:
		return
	src[n] = shooter
	pos[n] = p
	vel[n] = v
	life[n] = l
	dmg[n] = d
	owner_enemy[n] = 1 if enemy else 0
	kind[n] = k
	target[n] = t
	n += 1


## Cannon shot from any plane (player or bot). Same light aim assist for
## everyone; bots add their own aim error (skill).
func shoot(shooter: Jet, p: Vector3, dir: Vector3, base_speed: float) -> void:
	var d := dir
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var aim := Vector3.INF
	if fleet != null:
		aim = fleet.aim_target(p, flat, shooter.team, 0.22, 480.0)
	if aim == Vector3.INF and shooter.team == 0 and enemies != null:
		aim = enemies.aim_target(p, flat, 0.22, 480.0)
	if aim != Vector3.INF:
		d = (aim - p).normalized()
	if shooter.brain != null:
		var err: float = shooter.brain.aim_error()
		d = (d + Vector3(randf_range(-err, err), randf_range(-err, err) * 0.6, randf_range(-err, err))).normalized()
	var dmg_shot: float = float(shooter.cfg.get("gun_dmg", 1.0))
	_spawn(p, d * (PLAYER_SPEED + base_speed), 0.95, dmg_shot, shooter.team == 1, BULLET, -1, shooter)
	if fx != null:
		fx.muzzle(p)
	if shooter.is_player:
		if sound != null:
			sound.gun_shot()
		else:
			Sfx.play("shot", -8.0)
	else:
		Sfx.play_at("enemy_shot", p, -6.0)


func player_shoot(p: Vector3, dir: Vector3, base_speed: float) -> void:
	shoot(jet, p, dir, base_speed)


func enemy_bullet(p: Vector3, dir: Vector3, speed: float, d: float) -> void:
	_spawn(p, dir.normalized() * speed, 1.8, d, true, BULLET)
	Sfx.play("enemy_shot", -10.0)


## Projectile that flies to `at` and triggers there (flak burst / building hit).
func lob(p: Vector3, at: Vector3, speed: float, d: float, k: int, building_id: int = -1, team: int = 1) -> void:
	var dist := p.distance_to(at)
	var t := maxf(0.05, dist / speed)
	_spawn(p, (at - p) / t, t, d, team == 1, k, building_id)
	if k == FLAK:
		Sfx.play_at("flak", p, -6.0, 1.3)
	elif k == BOMB:
		Sfx.play("bomb", -8.0)


func _trigger(i: int) -> void:
	var p := pos[i]
	match kind[i]:
		FLAK:
			fx.explosion(p, 0.45)
			Sfx.play_at("flak", p, 0.0)
			if fleet != null:
				fleet.splash(p, 24.0, 0 if owner_enemy[i] == 1 else 1, dmg[i], null)
			elif jet.alive and p.distance_to(jet.position) < 20.0 and jet.invuln <= 0.0:
				jet.damage(dmg[i])
		BOMB, BLD_SHOT:
			if kind[i] == BOMB:
				fx.explosion(p, 0.8)
				Sfx.play_at("explode", p, 0.0)
			else:
				fx.hit(p)
			if target[i] >= 0 and game != null:
				game.damage_building(target[i], dmg[i], p)


func _process(delta: float) -> void:
	var i := 0
	batch.begin()
	while i < n:
		life[i] -= delta
		var remove := false
		pos[i] += vel[i] * delta
		var p := pos[i]
		if life[i] <= 0.0:
			if owner_enemy[i] == 1 or kind[i] == FLAK:
				_trigger(i)
			remove = true
		elif kind[i] == BULLET:
			var team := int(owner_enemy[i])
			var s: Object = src[i] if is_instance_valid(src[i]) else null
			if team == 0 and enemies != null and enemies.hit_test(p, dmg[i]):
				fx.hit(p)
				remove = true
				if s != null and "shots_hit" in s:
					s.shots_hit += 1
			elif bases != null and bases.hit_test(p, team, dmg[i], s):
				fx.sparks(p, 4)
				remove = true
				if s != null and "shots_hit" in s:
					s.shots_hit += 1
			elif fleet != null and fleet.hit_test(p, team, dmg[i], s):
				fx.hit(p)
				remove = true
				if s != null and "shots_hit" in s:
					s.shots_hit += 1
			elif fleet == null and team == 1 and jet.alive and absf(p.y - jet.position.y) < 10.0 and Vector2(p.x - jet.position.x, p.z - jet.position.z).length() < 7.0:
				if jet.invuln <= 0.0:
					jet.damage(dmg[i])
				fx.hit(p)
				remove = true
			elif p.y < 640.0 and chunks.collide(p.x, p.z, 0.5, p.y) != Vector2.ZERO:
				fx.sparks(p, 3)
				remove = true
				# enemy attackers strafing the city damage the building they hit
				if team == 1 and game != null and chunks.last_hit_id >= 0:
					game.damage_building(chunks.last_hit_id, dmg[i] * 0.6, p)
		if remove:
			n -= 1
			pos[i] = pos[n]
			vel[i] = vel[n]
			life[i] = life[n]
			dmg[i] = dmg[n]
			owner_enemy[i] = owner_enemy[n]
			kind[i] = kind[n]
			target[i] = target[n]
			src[i] = src[n]
			src[n] = null
			continue
		match kind[i]:
			BULLET:
				if owner_enemy[i] == 0:
					# tracer streak
					batch.push(p, 2.2, Color(1.0, 1.0, 0.7))
					batch.push(p - vel[i] * 0.006, 1.8, Color(1.0, 0.85, 0.35))
					batch.push(p - vel[i] * 0.012, 1.4, Color(1.0, 0.6, 0.2))
				else:
					batch.push(p, 2.5, Color(1.0, 0.25, 0.3))
			FLAK:
				batch.push(p, 2.5, Color(1.0, 0.6, 0.2))
			BOMB:
				batch.push(p, 3.0, Color(0.15, 0.15, 0.18))
			_:
				batch.push(p, 2.0, Color(1.0, 0.35, 0.9))
		i += 1
	batch.end()
