class_name Enemies
extends Node3D
## Enemy aircraft and rooftop anti-air guns (pooled, GPU-instanced per type).

enum { DRONE, JET, BOMBER, AAGUN }
const SHEETS := ["drone", "enemy_jet", "bomber", "aagun"]
const HP := [2.0, 4.0, 16.0, 6.0]
const SPEED := [55.0, 118.0, 40.0, 0.0]
const SCORE := [50, 150, 400, 200]
const RADIUS := [10.0, 13.0, 24.0, 10.0]
const MAX := 48

class E:
	var active := false
	var type := 0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var speed := 0.0
	var hp := 1.0
	var flash := 0.0
	var fire_cd := 1.0
	var burst := 0
	var target_id := -1
	var target_pos := Vector3.ZERO
	var orbit := 0.0
	var mode := 0
	var t := 0.0
	var smoke_cd := 0.0
	var bank := 0.0

var pool: Array[E] = []
var batches: Array[StackBatch] = []
var rng := RandomNumberGenerator.new()
var game: Node
var jet: Jet
var chunks: ChunkManager
var combat: Combat
var fx: Fx


func _ready() -> void:
	rng.randomize()
	for i in MAX:
		pool.append(E.new())
	for s in SHEETS:
		var b := StackBatch.new().setup(s, MAX)
		add_child(b)
		batches.append(b)


func clear() -> void:
	for e in pool:
		e.active = false


func count_active(include_aa: bool = true) -> int:
	var c := 0
	for e in pool:
		if e.active and (include_aa or e.type != AAGUN):
			c += 1
	return c


func spawn(type: int, p: Vector3) -> bool:
	for e in pool:
		if not e.active:
			e.active = true
			e.type = type
			e.pos = p
			e.hp = HP[type] * (1.0 + 0.08 * maxf(0.0, game.wave - 1) if game != null else 1.0)
			e.speed = SPEED[type]
			e.yaw = atan2(-(jet.position.x - p.x), -(jet.position.z - p.z))
			e.fire_cd = rng.randf_range(1.0, 2.5)
			e.burst = 0
			e.target_id = -1
			e.mode = 0
			e.t = 0.0
			e.flash = 0.0
			e.orbit = rng.randf() * TAU
			if type == BOMBER:
				_bomber_target(e)
			return true
	return false


func _forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _steer(e: E, to: Vector3, turn: float, delta: float) -> void:
	var desired := atan2(-(to.x - e.pos.x), -(to.z - e.pos.z))
	var diff := wrapf(desired - e.yaw, -PI, PI)
	var rate := clampf(diff * 3.0, -turn, turn)
	e.yaw = wrapf(e.yaw + rate * delta, -PI, PI)
	e.bank = lerpf(e.bank, -rate * 0.12, 1.0 - exp(-delta * 6.0))


func _pick_building(e: E, min_h: float) -> void:
	var b := chunks.random_building(jet.position, 420.0, min_h, rng)
	if b.is_empty():
		e.target_id = -1
		return
	e.target_id = b["id"]
	e.target_pos = b["pos"]


func _bomber_target(e: E) -> void:
	_pick_building(e, 8.0)
	var to := e.target_pos if e.target_id >= 0 else jet.position
	e.yaw = atan2(-(to.x - e.pos.x), -(to.z - e.pos.z))


func _process(delta: float) -> void:
	for b in batches:
		b.begin()
	if jet == null:
		return
	var jp := jet.position
	for e in pool:
		if not e.active:
			continue
		e.t += delta
		e.flash = maxf(0.0, e.flash - delta * 6.0)
		e.fire_cd -= delta
		var to_jet := Vector3(jp.x - e.pos.x, 0.0, jp.z - e.pos.z)
		var dj := to_jet.length()
		match e.type:
			DRONE:
				if e.target_id < 0 or chunks.destroyed.has(e.target_id):
					_pick_building(e, 10.0)
				var goal := jp
				if e.target_id >= 0:
					e.orbit += delta * 0.9
					goal = e.target_pos + Vector3(cos(e.orbit), 0, sin(e.orbit)) * 34.0
				_steer(e, goal, 2.2, delta)
				e.pos += _forward(e.yaw) * e.speed * delta
				if e.fire_cd <= 0.0:
					e.fire_cd = rng.randf_range(1.2, 1.8)
					if dj < 110.0 and jet.alive:
						combat.enemy_bullet(e.pos, jp - e.pos, 160.0, 4.0)
					elif e.target_id >= 0 and Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length() < 60.0:
						combat.lob(e.pos, e.target_pos + Vector3(rng.randf_range(-4, 4), -rng.randf_range(0, 8), rng.randf_range(-4, 4)), 150.0, 2.0, Combat.BLD_SHOT, e.target_id)
			JET:
				if e.mode == 0:
					# dogfight: lead the player
					var lead := jp + jet.forward() * jet.speed * clampf(dj / 300.0, 0.0, 0.8)
					_steer(e, lead, 2.0, delta)
					if e.t > 9.0 and rng.randf() < 0.004:
						e.mode = 1
						e.t = 0.0
						_pick_building(e, 20.0)
					var fwd := _forward(e.yaw)
					if jet.alive and dj < 260.0 and fwd.dot(to_jet / maxf(dj, 0.01)) > 0.96 and e.fire_cd <= 0.0:
						combat.enemy_bullet(e.pos + fwd * 12.0, (fwd * dj + Vector3(0, jp.y - e.pos.y, 0)), 260.0, 5.0)
						e.burst += 1
						e.fire_cd = 0.16
						if e.burst >= 4:
							e.burst = 0
							e.fire_cd = rng.randf_range(1.2, 2.0)
				else:
					# strafing run on a building
					if e.target_id < 0 or chunks.destroyed.has(e.target_id) or e.t > 8.0:
						e.mode = 0
						e.t = 0.0
					else:
						_steer(e, e.target_pos, 2.0, delta)
						var dd := Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length()
						if dd < 140.0 and e.fire_cd <= 0.0:
							e.fire_cd = 0.25
							combat.lob(e.pos, e.target_pos + Vector3(rng.randf_range(-5, 5), -rng.randf_range(0, 10), rng.randf_range(-5, 5)), 260.0, 1.5, Combat.BLD_SHOT, e.target_id)
						if dd < 25.0:
							e.mode = 0
							e.t = 0.0
				e.pos += _forward(e.yaw) * e.speed * delta
			BOMBER:
				e.pos += _forward(e.yaw) * e.speed * delta
				if e.target_id >= 0 and Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length() < 70.0 and e.fire_cd <= 0.0:
					e.fire_cd = 0.9
					var b := chunks.random_building(e.pos, 70.0, 6.0, rng)
					if not b.is_empty():
						combat.lob(e.pos, b["pos"], 70.0, 6.0, Combat.BOMB, b["id"])
				if e.target_id >= 0 and Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length() > 520.0 and e.t > 6.0:
					e.t = 0.0
					_bomber_target(e)
				if dj > 900.0:
					# wandered off: come back towards the player
					e.yaw = atan2(-to_jet.x, -to_jet.z)
			AAGUN:
				e.yaw = lerp_angle(e.yaw, atan2(-to_jet.x, -to_jet.z), 1.0 - exp(-delta * 3.0))
				if dj > 750.0:
					var p := chunks.roof_spot(jp, 180.0, 420.0, rng)
					if p != Vector3.INF:
						e.pos = p + Vector3(0, 0.3, 0)
				elif jet.alive and dj < 330.0 and e.fire_cd <= 0.0:
					e.fire_cd = rng.randf_range(1.5, 2.2)
					var predict := jp + jet.forward() * jet.speed * (dj / 170.0)
					predict.y = jp.y
					combat.lob(e.pos + Vector3(0, 7, 0), predict, 170.0, 9.0, Combat.FLAK)
		if e.type != AAGUN:
			e.pos.y = lerpf(e.pos.y, _alt(e), 1.0 - exp(-delta))
		# damaged smoke
		if e.hp < HP[e.type] * 0.5:
			e.smoke_cd -= delta
			if e.smoke_cd <= 0.0:
				e.smoke_cd = 0.08
				fx.smoke(e.pos, 1)
		batches[e.type].push(e.pos, e.yaw, 0, Color.WHITE, e.bank, e.flash)
	for b in batches:
		b.end()


func _alt(e: E) -> float:
	match e.type:
		BOMBER:
			return 160.0
		DRONE:
			var base := e.target_pos.y + 14.0 if e.target_id >= 0 else jet.position.y
			return clampf(base, 25.0, 190.0) + sin(e.t * 2.0 + e.orbit) * 3.0
	# fighters follow the player's altitude
	return clampf(jet.position.y + sin(e.t * 0.7) * 10.0, 20.0, 210.0)




func hit_test(p: Vector3, d: float) -> bool:
	for e in pool:
		if not e.active:
			continue
		var r: float = RADIUS[e.type]
		if absf(p.x - e.pos.x) < r and absf(p.z - e.pos.z) < r and absf(p.y - e.pos.y) < r + 14.0 and Vector2(p.x - e.pos.x, p.z - e.pos.z).length() < r:
			e.hp -= d
			e.flash = 1.0
			Sfx.play("hit", -10.0)
			if e.hp <= 0.0:
				_kill(e)
			return true
	return false


func _kill(e: E) -> void:
	e.active = false
	var big := 2.0 if e.type == BOMBER else 1.0
	fx.explosion(e.pos, big)
	Sfx.play("big_explode" if e.type == BOMBER else "explode", -2.0)
	if game != null:
		game.on_enemy_killed(e.type, e.pos, SCORE[e.type])


## Nearest enemy inside a cone in front of p (for aim assist). INF if none.
func aim_target(p: Vector3, dir: Vector3, cone: float, max_range: float) -> Vector3:
	var best := Vector3.INF
	var best_d := max_range
	var cos_c := cos(cone)
	for e in pool:
		if not e.active:
			continue
		var v := Vector3(e.pos.x - p.x, 0.0, e.pos.z - p.z)
		var d := v.length()
		if d < best_d and d > 1.0 and v.dot(dir) / d > cos_c:
			best_d = d
			best = e.pos
	return best
