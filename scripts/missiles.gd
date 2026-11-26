class_name Missiles
extends Node3D
## Lock-on + heat-seeking missiles with real limits:
##  motor  - burns BURN_T seconds (accelerating), then coasts and slows down
##           (drag, gravity); too slow = no longer a threat
##  turn   - limited by its G (turn rate = G * 9.8 / speed): a sharp break
##           turn at the right moment, or turning across / into it, beats it
##  seeker - a limited field of view: if the target goes past the gimbal
##           limit the missile loses it and flies on (evaded by maneuver)
##  flares - a salvo can decoy each missile chasing the plane with a chance
##           that depends on timing (best ~0.6-2.5 s before impact) and
##           aspect (best from behind), plus a bonus for a hard turn
## Warning: incoming time / direction for the player (HUD arrow + tone).

const MAX := 40
const LOCK_TIME := 0.8
## Player lock-on time (missile upgrades shorten it).
var lock_time := LOCK_TIME
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
	var dodged := false # lost the target (maneuver / flare / too slow)
	var burn := 0.0 # motor time left
	var max_g := 28.0
	var decoy := Vector3.INF # flare it chases instead
	var decoy_vel := Vector3.ZERO

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
## Tests: forces the flare decoy roll (-1 = random).
var flare_luck := -1.0
static var instance: Missiles
const BURN_T := 2.6
const BURN_ACC := 260.0
const TOP_SPEED := 560.0
const DRAG_K := 0.00012
const GIMBAL := 0.95 # seeker field of view (rad off the missile's path)
const MIN_SPEED := 170.0
const FUSE := 15.0
var lock_target: Object = null
var lock_t := 0.0
var locked := false
var incoming_t := 99.0 # seconds until the nearest enemy missile hits
var incoming_pos := Vector3.ZERO
var dodges := 0 # missiles the player beat by maneuvering
var decoys := 0 # missiles the player decoyed with flares
var hits_taken := 0
var fleet: Node
var clouds: Node
var _beep_t := 0.0
var _warn_t := 0.0


func _ready() -> void:
	instance = self
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
			m.life = 9.0
			m.dodged = false
			m.burn = BURN_T
			m.max_g = 20.0 if (enemy and shooter == null) else 28.0
			m.decoy = Vector3.INF
			return m
	return null


func fire_player() -> void:
	if not jet.alive or reload > 0.0:
		return
	ammo -= 1
	var tgt: Object = lock_target if locked else null
	var p := jet.position - Vector3(0, 3, 0)
	_spawn(jet.team == 1, p, jet.forward3() * (jet.speed + 30.0), tgt, jet)
	Sfx.play("launch", 0.0)
	if ammo <= 0:
		reload = reload_time


## Missile from any plane (bots use this after their own lock-on).
func fire_from(plane: Jet, target: Object) -> void:
	_spawn(plane.team == 1, plane.position - Vector3(0, 3, 0), plane.forward3() * (plane.speed + 30.0), target, plane)
	Sfx.play_at("launch", plane.position, -2.0)


## Missile from an enemy unit (boss / fighters of city defence) at the player.
func fire_enemy(from: Vector3) -> void:
	var active := 0
	for m in pool:
		if m.active and m.enemy and m.target == jet:
			active += 1
	if active >= 2:
		return
	_spawn(true, from, (jet.position - from).normalized() * 160.0, jet)
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
	locked = lock_target != null and lock_t >= lock_time


## A plane released flares: every missile chasing it may take the decoy.
func flare_release(plane: Jet) -> void:
	for m in pool:
		if not m.active or m.dodged or m.target != plane:
			continue
		var tp := plane.position
		var d := m.pos.distance_to(tp)
		if d > 2600.0:
			continue
		var closing := maxf(40.0, (m.vel - plane.forward3() * plane.speed).dot((tp - m.pos).normalized()))
		var t_go := d / closing
		var chance := 0.2
		if t_go < 0.5:
			chance = 0.3
		elif t_go < 2.6:
			chance = 0.75
		elif t_go < 4.0:
			chance = 0.45
		var aspect := plane.forward3().dot((m.pos - tp).normalized()) # -1 = from behind
		if aspect < -0.5:
			chance += 0.15
		elif aspect > 0.5:
			chance -= 0.1
		if plane.g_load > 5.0:
			chance += 0.1
		chance = clampf(chance, 0.05, 0.95)
		var roll := randf() if flare_luck < 0.0 else 1.0 - flare_luck
		if roll < chance:
			m.decoy = tp - plane.forward3() * 12.0
			m.decoy_vel = plane.forward3() * plane.speed * 0.25 + Vector3(0, -12, 0)
			m.dodged = true
			if plane == jet:
				decoys += 1
				Profile.track("flare_save")


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


## Where the nearest missile aimed at `plane` is (INF = none).
func threat_pos(plane: Object) -> Vector3:
	var best := INF
	var out := Vector3.INF
	for m in pool:
		if m.active and not m.dodged and m.target == plane:
			var d := m.pos.distance_squared_to(tpos(plane))
			if d < best:
				best = d
				out = m.pos
	return out


func _process(delta: float) -> void:
	if reload > 0.0:
		reload -= delta
		if reload <= 0.0:
			ammo = max_missiles
	if jet == null:
		return
	if jet.alive:
		_update_lock(delta)
	# lock-on audio: seeker growl / lock tone are continuous (SoundScape)
	# incoming missile warning: faster beeps as it closes in
	_warn_t -= delta
	if incoming_t < 5.0 and _warn_t <= 0.0:
		Sfx.play("warn", -8.0)
		_warn_t = clampf(incoming_t * 0.12, 0.08, 0.5)
	incoming_t = 99.0
	batch.begin()
	for m in pool:
		if not m.active:
			continue
		m.life -= delta
		var tp := tpos(m.target)
		# motor: accelerate while burning, then coast (drag + gravity)
		var spd := m.vel.length()
		var dir := m.vel / maxf(spd, 1.0)
		if m.burn > 0.0:
			m.burn -= delta
			spd = minf(spd + BURN_ACC * delta, TOP_SPEED if m.shooter != null or not m.enemy else 420.0)
		else:
			spd = maxf(0.0, spd - (DRAG_K * spd * spd + 9.8 * dir.y) * delta)
		# guidance: lead pursuit, turn rate limited by the missile's G
		var aim := Vector3.INF
		if m.decoy != Vector3.INF:
			m.decoy_vel.y -= 9.8 * delta
			m.decoy += m.decoy_vel * delta
			aim = m.decoy
		elif tp != Vector3.INF and not m.dodged:
			var tv := Vector3.ZERO
			if m.target is Jet:
				tv = (m.target as Jet).forward3() * (m.target as Jet).speed
			elif "vel" in m.target:
				tv = m.target.vel
			var d0 := m.pos.distance_to(tp)
			var t_go := d0 / maxf(80.0, spd)
			aim = tp + tv * t_go * 0.85
			# seeker field of view: past the gimbal limit the lock is lost
			var los := (tp - m.pos) / maxf(d0, 1.0)
			if m.target is Jet and dir.dot(los) < cos(GIMBAL) and d0 > FUSE * 2.0:
				m.dodged = true
				aim = Vector3.INF
				if m.target == jet:
					dodges += 1
					game.show_banner("EVADED", "", 0.9)
			# a target deep in a cloud: the seeker loses it (~70 % a second)
			elif m.target is Jet and d0 > FUSE * 3.0 and target_hidden(tp) and randf() < 1.2 * delta:
				m.dodged = true
				aim = Vector3.INF
				if m.target == jet:
					dodges += 1
					game.show_banner("LOST IN CLOUD", "", 0.9)
		if aim != Vector3.INF:
			var want := (aim - m.pos).normalized()
			var ang := dir.angle_to(want)
			var max_turn := m.max_g * 9.8 / maxf(spd, 60.0) * delta
			if ang > 1e-4:
				var ax := dir.cross(want)
				if ax.length_squared() > 1e-8:
					dir = dir.rotated(ax.normalized(), minf(ang, max_turn))
		m.vel = dir * spd
		m.pos += m.vel * delta
		m.smoke_cd -= delta
		if m.smoke_cd <= 0.0:
			m.smoke_cd = 0.03
			fx.spawn(m.pos, Vector3(0, 3, 0), 1.6 if m.burn > 0.0 else 0.9, 2.2 if m.burn > 0.0 else 1.4, Fx.SMOKE)
			if m.burn > 0.0:
				fx.spawn(m.pos, Vector3.ZERO, 0.08, 2.0, Fx.BURNER)
		var done := m.life <= 0.0 or m.pos.y < 0.0
		# out of energy: no longer a threat
		if spd < MIN_SPEED and m.burn <= 0.0 and not m.dodged and m.target is Jet:
			m.dodged = true
			if m.target == jet:
				dodges += 1
				game.show_banner("EVADED", "", 0.9)
		if m.target is Jet and tp != Vector3.INF and not m.dodged:
			var tj: Jet = m.target
			var d := m.pos.distance_to(tp)
			var closing := maxf(30.0, (m.vel - tj.forward3() * tj.speed).dot((tp - m.pos).normalized()))
			var t := maxf(0.0, d - FUSE) / closing
			if tj == jet and t < incoming_t:
				incoming_t = t
				incoming_pos = m.pos
			if d < FUSE:
				if tj.invuln > 0.0:
					m.dodged = true # spawn protection
				else:
					if tj == jet:
						hits_taken += 1
					tj.last_hit_missile = true
					# ~4-5 missiles kill any plane, light or armoured
					tj.damage(maxf(25.0, tj.max_health * 0.22), m.shooter)
					fx.explosion(m.pos, 0.8)
					done = true
		elif m.decoy != Vector3.INF and m.pos.distance_to(m.decoy) < 12.0:
			fx.explosion(m.pos, 0.6) # detonates on the flare
			done = true
		elif m.target != null and not (m.target is Jet) and m.target.has_method("take_damage") and tp != Vector3.INF:
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
