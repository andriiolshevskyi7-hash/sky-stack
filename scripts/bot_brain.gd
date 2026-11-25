class_name BotBrain
extends RefCounted
## AI pilot. Flies a normal Jet through the same virtual stick / boost / fire
## inputs the player uses (same flight model, same guns and missiles).
##
## skill 0 (rookie) .. 1 (ace) scales: reaction time, aim error, energy
## management, missile dodging, use of clouds/terrain and how often the bot
## makes human-like mistakes.
## Roles: DOGFIGHTER, INTERCEPTOR (hunts bombers/attackers), ATTACKER (ground
## targets), ESCORT (protects a friendly attacker/bomber).
## Team play: pairs (leader + wingman share the target = focus fire, the
## wingman flanks), retreat when damaged, chase the most dangerous enemy.

enum { DOGFIGHTER, INTERCEPTOR, ATTACKER, ESCORT }
const ROLE_NAMES := ["DOGFIGHTER", "INTERCEPTOR", "ATTACKER", "ESCORT"]
enum { S_ENGAGE, S_RETREAT, S_EVADE, S_PATROL }

var plane: Jet
var fleet: Node
var skill := 0.5
var role := DOGFIGHTER
var partner: Jet = null # pair partner
var leader := true
var escort_of: Jet = null
var target: Object = null
var state := S_PATROL
var state_t := 0.0
var rng := RandomNumberGenerator.new()
var flank := 0.0
var missiles := 4
var missile_reload := 0.0
var missile_cd := 3.0
var lock_t := 0.0
var _react := 0.0
var _mistake := 0.0 # > 0: currently making a mistake
var _mistake_kind := 0
var _rolled_for := 0.0
var _wobble := Vector2.ZERO
var _home := Vector3.ZERO
## ground target picker (attackers): Callable(plane) -> Object with pos/active
var ground_targets: Callable


func _init(p: Jet, f: Node, p_skill: float, p_role: int, seed: int) -> void:
	plane = p
	fleet = f
	skill = clampf(p_skill, 0.0, 1.0)
	role = p_role
	rng.seed = seed
	flank = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.3, 0.9)
	missiles = 2 + int(skill * 3.0)


## Cannon spread for this pilot (radians-ish), used by Combat.shoot.
func aim_error() -> float:
	var e := lerpf(0.09, 0.012, skill)
	if _mistake > 0.0 and _mistake_kind == 1:
		e *= 3.0
	return e


static func pos_of(o: Object) -> Vector3:
	return Missiles.tpos(o)


static func vel_of(o: Object) -> Vector3:
	if o is Jet:
		return o.forward3() * o.speed
	if o != null and "yaw" in o and "speed" in o:
		return Vector3(-sin(o.yaw), 0.0, -cos(o.yaw)) * o.speed
	return Vector3.ZERO


func _threat(o: Object) -> float:
	# how dangerous a candidate is to us
	var p := pos_of(o)
	var d := p.distance_to(plane.position)
	var s := -d / 900.0
	if o is Jet:
		var j: Jet = o
		var to_me := (plane.position - j.position) / maxf(d, 1.0)
		if j.forward3().dot(to_me) > 0.9 and d < 700.0:
			s += 1.6 # it is pointing at us
		if j.brain != null and j.brain.target == plane:
			s += 0.8
		if j.is_player:
			s += 0.3
		s += float(j.kills) * 0.15
	return s


func _role_bonus(o: Object) -> float:
	var b := 0.0
	var is_heavy: bool = not (o is Jet) and "type" in o and (o.type == 2 or o.type == 5) # bomber / boss
	match role:
		INTERCEPTOR:
			if is_heavy:
				b += 2.5
			if o is Jet and o.brain != null and o.brain.role == ATTACKER:
				b += 2.0
		ESCORT:
			if escort_of != null and escort_of.alive and o is Jet and o.brain != null and o.brain.target == escort_of:
				b += 2.5
			if escort_of != null and escort_of.alive and o is Jet and o.is_player:
				b += 0.5
		DOGFIGHTER:
			if o is Jet:
				b += 0.6
	if partner != null and partner.alive and partner.brain != null and partner.brain.target == o:
		b += 0.6 + skill # focus fire with the pair
	return b


func _pick_target() -> void:
	var best: Object = null
	var best_s := -1e9
	for o in fleet.enemy_targets(plane.team):
		var p := pos_of(o)
		if p == Vector3.INF:
			continue
		if p.distance_to(plane.position) > 3500.0:
			continue
		var sc := _threat(o) + _role_bonus(o) + rng.randf_range(-1.0, 1.0) * (1.0 - skill)
		if o == target:
			sc += 0.4 # some commitment
		if sc > best_s:
			best_s = sc
			best = o
	# wingmen follow the leader's choice (focus fire) most of the time
	if not leader and partner != null and partner.alive and partner.brain != null and partner.brain.target != null and rng.randf() < 0.5 + skill * 0.4:
		if pos_of(partner.brain.target) != Vector3.INF:
			best = partner.brain.target
	if role == ATTACKER and ground_targets.is_valid():
		var gt: Object = ground_targets.call(plane)
		if gt != null and (best == null or _threat(best) < 0.8):
			best = gt
	target = best


func think(delta: float) -> void:
	state_t += delta
	_react -= delta
	missile_cd -= delta
	if missile_reload > 0.0:
		missile_reload -= delta
		if missile_reload <= 0.0:
			missiles = 2 + int(skill * 3.0)
	# human-like mistakes: rookies more often
	if _mistake > 0.0:
		_mistake -= delta
	elif rng.randf() < delta * lerpf(0.12, 0.015, skill):
		_mistake = rng.randf_range(0.5, 1.6)
		_mistake_kind = rng.randi() % 3 # 0 late reaction, 1 bad aim, 2 overshoot
	if _react <= 0.0:
		_react = lerpf(0.9, 0.15, skill) * rng.randf_range(0.7, 1.3)
		if _mistake > 0.0 and _mistake_kind == 0:
			_react += 0.8
		_decide()
	_dodge_missiles()
	match state:
		S_RETREAT:
			_fly_retreat()
		S_EVADE:
			_fly_evade()
		S_PATROL:
			_fly_patrol()
		_:
			_fly_engage(delta)
	_avoid_ground()
	_keep_in_bounds()


## Stay inside the battle area like a human would (turn back at the edge).
func _keep_in_bounds() -> void:
	var h: float = fleet.bound_half
	if h <= 0.0:
		return
	var p := plane.position
	if maxf(absf(p.x), absf(p.z)) > h - 450.0:
		var y := plane.in_stick.y
		_steer_to(Vector3(p.x * 0.3, p.y, p.z * 0.3), 1.5)
		plane.in_stick.y = maxf(y, plane.in_stick.y) if p.y < 200.0 else plane.in_stick.y


func _decide() -> void:
	var hp := plane.health / plane.max_health
	if state == S_RETREAT:
		if hp > 0.6 or state_t > 9.0 + skill * 4.0:
			state = S_PATROL
			state_t = 0.0
		return
	if state == S_EVADE and state_t < 1.4:
		return
	if hp < 0.3 and rng.randf() < 0.3 + skill * 0.6:
		state = S_RETREAT
		state_t = 0.0
		return
	_pick_target()
	# someone sitting on our six? skilled pilots break hard
	for o in fleet.enemy_planes(plane.team):
		var d: float = o.position.distance_to(plane.position)
		if d < 450.0 and o.forward3().dot((plane.position - o.position) / maxf(d, 1.0)) > 0.94:
			if plane.forward3().dot((o.position - plane.position) / maxf(d, 1.0)) < -0.3 and rng.randf() < 0.25 + skill * 0.6:
				state = S_EVADE
				state_t = 0.0
				if skill > 0.7 and rng.randf() < 0.35:
					plane.loop(false) # reversal
				return
	state = S_ENGAGE if target != null else S_PATROL
	if state == S_ENGAGE:
		state_t = 0.0 if state != S_ENGAGE else state_t


# ------------------------------------------------------------------ steering

## Steer the virtual stick towards a world point (same inputs as the player).
func _steer_to(p: Vector3, urgency: float = 1.0) -> float:
	var to := p - plane.position
	var desired_yaw := atan2(-to.x, -to.z)
	var diff := wrapf(desired_yaw - plane.yaw, -PI, PI)
	var flat := Vector2(to.x, to.z).length()
	var desired_pitch := clampf(atan2(to.y, maxf(flat, 1.0)), -Jet.MAX_PITCH, Jet.MAX_PITCH)
	var sx := clampf(-diff * lerpf(1.4, 2.6, skill) * urgency, -1.0, 1.0)
	var sy := clampf(desired_pitch / Jet.MAX_PITCH, -1.0, 1.0)
	if _mistake > 0.0 and _mistake_kind == 2:
		sx *= 0.4 # overshoot: lazy turn
	_wobble = _wobble.lerp(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (1.0 - skill) * 0.25, 0.05)
	plane.in_stick = Vector2(sx, sy) + _wobble
	return diff


func _fly_engage(delta: float) -> void:
	var tp := pos_of(target)
	if tp == Vector3.INF:
		target = null
		state = S_PATROL
		return
	var d := tp.distance_to(plane.position)
	var tv := vel_of(target)
	var t_flight := d / (Combat.PLAYER_SPEED + plane.speed)
	var lead := tp + tv * t_flight
	var aim := lead
	# wingman flanks while closing in
	if not leader and d > 500.0:
		aim += plane.right() * flank * minf(400.0, d * 0.4)
	var diff := _steer_to(aim, 1.0)
	# energy management: boost to close/extend, don't bleed speed in the turn
	var is_ground: bool = not (target is Jet) and "kind" in target
	plane.in_boost = (d > 700.0 and skill > 0.2) or (absf(diff) < 0.25 and d > 400.0) or (plane.speed < plane.base_speed() * 0.9 and skill > 0.6)
	if _mistake > 0.0 and _mistake_kind == 2:
		plane.in_boost = true
	# guns
	var tol := lerpf(0.16, 0.06, skill)
	var to_lead := (lead - plane.position).normalized()
	var facing := plane.forward3().dot(to_lead)
	plane.in_fire = d < (700.0 if is_ground else 560.0) and facing > cos(tol) and not (_mistake > 0.0 and _mistake_kind == 0)
	# missiles with the same lock-on rule as the player (0.8 s in the cone)
	var to_t := (tp - plane.position) / maxf(d, 1.0)
	if d < Missiles.LOCK_RANGE and plane.forward3().dot(to_t) > cos(Missiles.LOCK_CONE) and not fleet.hidden(tp):
		lock_t += delta
	else:
		lock_t = 0.0
	if lock_t > Missiles.LOCK_TIME + (1.0 - skill) * 0.8 and missiles > 0 and missile_cd <= 0.0 and fleet.missiles != null:
		fleet.missiles.fire_from(plane, target)
		missiles -= 1
		missile_cd = lerpf(9.0, 3.5, skill)
		lock_t = 0.0
		if missiles <= 0:
			missile_reload = 12.0


func _fly_evade() -> void:
	# hard break turn + altitude change
	var dir := 1.0 if flank > 0.0 else -1.0
	plane.in_stick = Vector2(dir, -0.6 if plane.position.y > 300.0 else 0.8)
	plane.in_boost = true
	plane.in_fire = false
	if state_t > 1.4:
		state = S_ENGAGE
		state_t = 0.0


func _fly_retreat() -> void:
	plane.in_fire = false
	plane.in_boost = true
	var away := plane.position
	var n := 0
	for o in fleet.enemy_planes(plane.team):
		if o.position.distance_to(plane.position) < 1500.0:
			away += (plane.position - o.position).normalized() * 800.0
			n += 1
	if n == 0:
		away = _home
	var goal := away
	if skill > 0.65 and fleet.clouds != null:
		goal.y = fleet.clouds.BASE_Y + 40.0 # hide in the clouds
	elif skill > 0.35:
		goal.y = 110.0 # duck low over the rooftops
	else:
		goal.y = 300.0
	_steer_to(goal, 0.8)
	# repair slowly while out of the fight
	if n == 0:
		plane.health = minf(plane.max_health, plane.health + 6.0 * (1.0 / 60.0))


func _fly_patrol() -> void:
	plane.in_fire = false
	plane.in_boost = false
	var goal := _home
	if partner != null and partner.alive and not leader:
		goal = partner.position - partner.forward() * 70.0 + partner.right() * flank * 60.0
	elif escort_of != null and escort_of.alive:
		goal = escort_of.position + escort_of.right() * flank * 120.0 + Vector3(0, 40, 0)
	if goal.distance_to(plane.position) < 80.0:
		goal = plane.position + plane.forward() * 300.0 + plane.right() * 200.0
	goal.y = clampf(goal.y, 150.0, 900.0)
	_steer_to(goal, 0.6)


func _dodge_missiles() -> void:
	if fleet.missiles == null:
		return
	var t: float = fleet.missiles.incoming_for(plane)
	if t > 3.0:
		_rolled_for = 0.0
		return
	# skilled pilots roll right as the missile arrives; rookies guess
	var when := 0.4 + rng.randf_range(-0.5, 0.5) * (1.0 - skill)
	if _rolled_for <= 0.0 and t < when:
		_rolled_for = 1.0
		if rng.randf() < 0.15 + skill * 0.8:
			plane.barrel_roll()
		if plane.flares > 0 and rng.randf() < skill:
			plane.flares -= 1
			plane.flares_active = 1.5


func _avoid_ground() -> void:
	# keep clear of the ground/sea and of tall buildings ahead
	var y := plane.position.y
	var min_y := 60.0 if skill > 0.5 else 110.0
	if y < min_y and plane.in_stick.y < 0.5:
		plane.in_stick.y = 0.8
	if fleet.chunks != null:
		var ahead := plane.position + plane.forward() * 160.0
		if fleet.chunks.nearest_tall(ahead.x, ahead.z, y - 10.0, 60.0) < 30.0:
			plane.in_stick.y = 1.0
		# mountains / mesas further ahead: start climbing early
		var far := plane.position + plane.forward() * 340.0
		if CityGen.feature != CityGen.FEAT_NONE and CityGen.relief_hw(far.x, far.z) > y - 40.0:
			plane.in_stick.y = 1.0
