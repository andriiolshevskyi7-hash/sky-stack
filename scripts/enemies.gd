class_name Enemies
extends Node3D
## Enemy aircraft, rooftop anti-air guns and the boss bomber (pooled,
## GPU-instanced per type).
##  DRONE       - small, come in swarms, peck at buildings
##  JET         - fighter: dogfights the player (gets on your tail, breaks
##                away when you're on its six, changes altitude), sometimes
##                strafes the city
##  BOMBER      - slow and tanky, bombs districts
##  AAGUN       - rooftop flak (wave 4+)
##  INTERCEPTOR - very fast, lightly armoured dogfighter (wave 3+)
##  BOSS        - huge bomber every 5 waves: turrets + missiles + bombs

enum { DRONE, JET, BOMBER, AAGUN, INTERCEPTOR, BOSS }
const SHEETS := ["drone", "enemy_jet", "bomber", "aagun", "enemy_jet", "bomber"]
const TINT := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color(1.25, 1.1, 0.55), Color(0.8, 0.8, 0.9)]
const SCALE := [1.4, 1.0, 1.6, 2.0, 0.9, 4.0]
const HP := [2.0, 6.0, 22.0, 6.0, 4.0, 160.0]
const SPEED := [110.0, 150.0, 70.0, 0.0, 205.0, 60.0]
const SCORE := [50, 150, 400, 200, 250, 3000]
const RADIUS := [13.0, 15.0, 40.0, 14.0, 14.0, 105.0]
const MAX := 64

enum { M_PURSUE, M_BREAK, M_STRAFE }

class E:
	var active := false
	var type := 0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var speed := 0.0
	var hp := 1.0
	var max_hp := 1.0
	var flash := 0.0
	var fire_cd := 1.0
	var burst := 0
	var target_id := -1
	var target_pos := Vector3.ZERO
	var orbit := 0.0
	var mode := 0
	var mode_t := 0.0
	var t := 0.0
	var smoke_cd := 0.0
	var bank := 0.0
	var mcd := 8.0
	var tail_t := 0.0 # how long the player has been on our six
	var break_dir := 1.0
	var want_y := 200.0
	var leader: E = null

var pool: Array[E] = []
var batches: Array[StackBatch] = []
var rng := RandomNumberGenerator.new()
var game: Node
var jet: Jet
var chunks: ChunkManager
var combat: Combat
var fx: Fx
var missiles: Node
var boss: E = null


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
	boss = null


func count_active(include_aa: bool = true) -> int:
	var c := 0
	for e in pool:
		if e.active and (include_aa or e.type != AAGUN):
			c += 1
	return c


func spawn(type: int, p: Vector3) -> bool:
	return _spawn(type, p) != null


func _spawn(type: int, p: Vector3) -> E:
	for e in pool:
		if not e.active:
			e.active = true
			e.type = type
			e.pos = p
			var w: float = game.wave if game != null else 1.0
			e.hp = HP[type] * (1.0 + 0.08 * maxf(0.0, w - 1.0))
			e.max_hp = e.hp
			e.speed = SPEED[type]
			e.yaw = atan2(-(jet.position.x - p.x), -(jet.position.z - p.z))
			e.pitch = 0.0
			e.fire_cd = rng.randf_range(1.0, 2.5)
			e.burst = 0
			e.target_id = -1
			e.mode = M_PURSUE
			e.mode_t = 0.0
			e.t = 0.0
			e.flash = 0.0
			e.tail_t = 0.0
			e.orbit = rng.randf() * TAU
			e.mcd = rng.randf_range(6.0, 11.0)
			e.want_y = p.y
			e.leader = null
			if type == BOMBER or type == BOSS:
				_bomber_target(e)
			if type == BOSS:
				boss = e
			return e
	return null


## A swarm of drones following a leader.
func spawn_swarm(p: Vector3, n: int) -> void:
	var lead := _spawn(DRONE, p)
	if lead == null:
		return
	for i in n - 1:
		var d := _spawn(DRONE, p + Vector3(rng.randf_range(-40, 40), rng.randf_range(-15, 15), rng.randf_range(-40, 40)))
		if d != null:
			d.leader = lead
			d.orbit = TAU * i / maxf(1.0, n - 1)


func _forward(yaw: float, pitch: float = 0.0) -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func _steer(e: E, to: Vector3, turn: float, delta: float) -> float:
	var desired := atan2(-(to.x - e.pos.x), -(to.z - e.pos.z))
	var diff := wrapf(desired - e.yaw, -PI, PI)
	var rate := clampf(diff * 3.0, -turn, turn)
	e.yaw = wrapf(e.yaw + rate * delta, -PI, PI)
	e.bank = lerpf(e.bank, -rate * 0.16, 1.0 - exp(-delta * 6.0))
	return diff


func _pick_building(e: E, min_h: float) -> void:
	var b := chunks.random_building(jet.position, 800.0, min_h, rng)
	if b.is_empty():
		e.target_id = -1
		return
	e.target_id = b["id"]
	e.target_pos = b["pos"]


func _bomber_target(e: E) -> void:
	_pick_building(e, 16.0)
	var to := e.target_pos if e.target_id >= 0 else jet.position
	e.yaw = atan2(-(to.x - e.pos.x), -(to.z - e.pos.z))


## Dogfight brain for fighters and interceptors.
func _dogfight(e: E, delta: float, jp: Vector3, to_jet: Vector3, dj: float) -> void:
	var turn := 1.9 if e.type == JET else 1.5
	e.mode_t += delta
	# is the player sitting on our tail?
	var jf := jet.forward3()
	var on_six: bool = dj < 380.0 and jf.dot((e.pos - jp) / maxf(dj, 0.01)) > 0.93
	e.tail_t = e.tail_t + delta if on_six else maxf(0.0, e.tail_t - delta * 2.0)
	match e.mode:
		M_PURSUE:
			# aim for a point behind the player, then lead the shot when close
			var behind := jp - jet.forward() * 120.0
			var lead := jp + jet.forward3() * jet.speed * clampf(dj / 400.0, 0.0, 0.7)
			var goal := lead if dj < 450.0 else behind
			var diff := _steer(e, goal, turn, delta)
			e.want_y = goal.y
			var fwd := _forward(e.yaw, e.pitch)
			if jet.alive and dj < 480.0 and absf(diff) < 0.14 and e.fire_cd <= 0.0:
				combat.enemy_bullet(e.pos + fwd * 16.0, (lead - e.pos), 320.0, 4.0)
				e.burst += 1
				e.fire_cd = 0.11
				if e.burst >= 5:
					e.burst = 0
					e.fire_cd = rng.randf_range(1.0, 1.8)
			e.mcd -= delta
			if missiles != null and jet.alive and dj < 800.0 and dj > 200.0 and e.mcd <= 0.0 and absf(diff) < 0.6:
				e.mcd = rng.randf_range(10.0, 16.0)
				missiles.fire_enemy(e.pos + fwd * 16.0)
			if e.tail_t > 1.2:
				e.mode = M_BREAK
				e.mode_t = 0.0
				e.break_dir = 1.0 if rng.randf() < 0.5 else -1.0
				e.want_y = clampf(e.pos.y + rng.randf_range(-160, 160), 60.0, 900.0)
			elif e.type == JET and e.mode_t > 12.0 and rng.randf() < 0.003:
				e.mode = M_STRAFE
				e.mode_t = 0.0
				_pick_building(e, 30.0)
		M_BREAK:
			# hard break turn + altitude change to shake the player off
			e.yaw = wrapf(e.yaw + e.break_dir * 2.6 * delta, -PI, PI)
			e.bank = lerpf(e.bank, -e.break_dir * 0.45, 1.0 - exp(-delta * 6.0))
			if e.mode_t > rng.randf_range(1.6, 2.6):
				e.mode = M_PURSUE
				e.mode_t = 0.0
				e.tail_t = 0.0
		M_STRAFE:
			if e.target_id < 0 or chunks.destroyed.has(e.target_id) or e.mode_t > 9.0:
				e.mode = M_PURSUE
				e.mode_t = 0.0
			else:
				_steer(e, e.target_pos, turn, delta)
				e.want_y = e.target_pos.y + 40.0
				var dd := Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length()
				if dd < 260.0 and e.fire_cd <= 0.0:
					e.fire_cd = 0.22
					combat.lob(e.pos, e.target_pos + Vector3(rng.randf_range(-8, 8), -rng.randf_range(0, 16), rng.randf_range(-8, 8)), 420.0, 1.5, Combat.BLD_SHOT, e.target_id)
				if dd < 50.0:
					e.mode = M_PURSUE
					e.mode_t = 0.0


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
		var dj := e.pos.distance_to(jp)
		match e.type:
			DRONE:
				if e.leader != null and e.leader.active:
					var slot := e.leader.pos + Vector3(cos(e.orbit + e.t * 0.6), 0.2, sin(e.orbit + e.t * 0.6)) * 34.0
					_steer(e, slot, 3.0, delta)
					e.want_y = e.leader.pos.y + sin(e.t * 2.0 + e.orbit) * 8.0
					e.speed = SPEED[DRONE] * (1.25 if e.pos.distance_to(slot) > 40.0 else 0.95)
				else:
					e.leader = null
					if e.target_id < 0 or chunks.destroyed.has(e.target_id):
						_pick_building(e, 20.0)
					var goal := jp
					if e.target_id >= 0:
						e.orbit += delta * 0.6
						goal = e.target_pos + Vector3(cos(e.orbit), 0, sin(e.orbit)) * 90.0
					_steer(e, goal, 2.2, delta)
					e.want_y = (e.target_pos.y + 30.0) if e.target_id >= 0 else jp.y
				if e.fire_cd <= 0.0:
					e.fire_cd = rng.randf_range(1.3, 2.0)
					if dj < 220.0 and jet.alive:
						combat.enemy_bullet(e.pos, jp - e.pos, 260.0, 3.0)
					elif e.target_id >= 0 and Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length() < 150.0:
						combat.lob(e.pos, e.target_pos + Vector3(rng.randf_range(-8, 8), -rng.randf_range(0, 16), rng.randf_range(-8, 8)), 300.0, 2.0, Combat.BLD_SHOT, e.target_id)
			JET, INTERCEPTOR:
				_dogfight(e, delta, jp, to_jet, dj)
			BOMBER, BOSS:
				e.want_y = 380.0 if e.type == BOSS else 320.0
				if e.target_id >= 0 and Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length() < 140.0 and e.fire_cd <= 0.0:
					e.fire_cd = 0.8 if e.type == BOMBER else 0.35
					var b := chunks.random_building(e.pos, 160.0, 12.0, rng)
					if not b.is_empty():
						combat.lob(e.pos, b["pos"], 140.0, 6.0 if e.type == BOMBER else 9.0, Combat.BOMB, b["id"])
				if e.target_id >= 0 and Vector2(e.pos.x - e.target_pos.x, e.pos.z - e.target_pos.z).length() > 900.0 and e.t > 6.0:
					e.t = 0.0
					_bomber_target(e)
				if Vector2(to_jet.x, to_jet.z).length() > 1800.0:
					e.yaw = atan2(-to_jet.x, -to_jet.z)
				if e.type == BOSS:
					# turrets
					e.mcd -= delta
					if jet.alive and dj < 700.0 and int(e.t * 10.0) % 4 == 0 and e.burst <= 0:
						combat.enemy_bullet(e.pos + Vector3(0, 10, 0), jp - e.pos + Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 300.0, 3.0)
						e.burst = 2
					e.burst -= 1
					if missiles != null and jet.alive and dj < 900.0 and e.mcd <= 0.0:
						e.mcd = rng.randf_range(7.0, 10.0)
						missiles.fire_enemy(e.pos + Vector3(0, 20, 0))
			AAGUN:
				e.yaw = lerp_angle(e.yaw, atan2(-to_jet.x, -to_jet.z), 1.0 - exp(-delta * 3.0))
				if Vector2(to_jet.x, to_jet.z).length() > 1500.0:
					var p := chunks.roof_spot(jp, 300.0, 900.0, rng)
					if p != Vector3.INF:
						e.pos = p + Vector3(0, 0.6, 0)
				elif jet.alive and dj < 650.0 and e.fire_cd <= 0.0:
					e.fire_cd = rng.randf_range(1.5, 2.2)
					var predict := jp + jet.forward3() * jet.speed * (dj / 340.0)
					combat.lob(e.pos + Vector3(0, 14, 0), predict, 340.0, 9.0, Combat.FLAK)
		if e.type != AAGUN:
			# move in 3D, climbing/diving towards the wanted altitude
			e.pitch = lerpf(e.pitch, clampf((e.want_y - e.pos.y) * 0.01, -0.5, 0.5), 1.0 - exp(-delta * 2.0))
			var f := _forward(e.yaw, e.pitch)
			e.pos += f * e.speed * delta
			e.pos.y = maxf(e.pos.y, 30.0)
		# damaged: trail of smoke (and fire when badly hurt)
		if e.hp < e.max_hp * 0.6:
			e.smoke_cd -= delta
			if e.smoke_cd <= 0.0:
				e.smoke_cd = 0.05
				fx.smoke(e.pos, 1)
				if e.hp < e.max_hp * 0.3:
					fx.spawn(e.pos, Vector3(0, 6, 0), 0.25, 2.5, Fx.FIRE)
		var sc: float = SCALE[e.type]
		var basis := Basis.from_euler(Vector3(e.pitch, e.yaw, -e.bank * 2.9)).scaled(Vector3.ONE * sc)
		batches[e.type].push_basis(e.pos, basis, 0, TINT[e.type], e.flash)
	for b in batches:
		b.end()


func hit_test(p: Vector3, d: float) -> bool:
	for e in pool:
		if not e.active:
			continue
		var r: float = RADIUS[e.type]
		if absf(p.x - e.pos.x) < r and absf(p.z - e.pos.z) < r and absf(p.y - e.pos.y) < r + 14.0 and Vector2(p.x - e.pos.x, p.z - e.pos.z).length() < r:
			e.hp -= d
			e.flash = 1.0
			Sfx.play("hit", -10.0)
			if fx != null:
				fx.sparks(p, 6)
			if e.hp <= 0.0:
				_kill(e)
			return true
	return false


func _kill(e: E) -> void:
	e.active = false
	var big := 3.0 if e.type == BOSS else (2.0 if e.type == BOMBER else 1.2)
	fx.explosion(e.pos, big)
	fx.debris(e.pos, int(10 * big))
	Sfx.play("big_explode" if big > 1.5 else "explode", -2.0)
	if e == boss:
		boss = null
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
