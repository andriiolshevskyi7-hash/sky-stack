class_name Jet
extends Node3D
## Player fighter jet. Flies at a fixed low altitude: skyscrapers taller than
## the jet are obstacles (hitting one costs health), and threading between
## them builds a score multiplier.

signal hit_building(amount: float)
signal died

const ALT := CityGen.JET_ALT
const BASE_SPEED := 88.0
const BOOST_SPEED := 170.0
const RADIUS := 6.0
const FIRE_INTERVAL := 1.0 / 12.0

var yaw := 0.0
var speed := BASE_SPEED
var turn_rate := 0.0
var health := 100.0
var max_health := 100.0
var boost_energy := 100.0
var boosting := false
var alive := true
var invuln := 0.0
var autopilot := false

var lowfly_time := 0.0
var lowfly_grace := 0.0
var multiplier := 1
var near_tall := 999.0

var fire_cd := 0.0
var gun_side := 1
var smoke_cd := 0.0
var _t := 0.0

var stack: SpriteStack
var controls: Controls
var cam: GameCamera
var chunks: ChunkManager
var combat: Node # Combat (step 2)
var fx: Node # Fx (step 3)


func _ready() -> void:
	stack = SpriteStack.new()
	stack.sheet = "jet"
	add_child(stack)
	position.y = ALT


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func reset(pos: Vector3, p_yaw: float) -> void:
	position = Vector3(pos.x, ALT, pos.z)
	yaw = p_yaw
	speed = BASE_SPEED
	health = max_health
	boost_energy = 100.0
	alive = true
	visible = true
	invuln = 1.5
	multiplier = 1
	lowfly_time = 0.0
	turn_rate = 0.0


func speed_ratio() -> float:
	return clampf((speed - BASE_SPEED) / (BOOST_SPEED - BASE_SPEED), 0.0, 1.0)


func step(delta: float) -> void:
	_t += delta
	if not alive:
		return
	invuln = maxf(0.0, invuln - delta)
	# ---- steering (screen-relative joystick -> desired heading)
	var desired := yaw
	var steer := false
	if autopilot:
		desired = _autopilot_heading(delta)
		steer = true
	elif controls != null and controls.stick.length() > 0.2 and cam != null:
		var s := controls.stick
		var dir := cam.screen_right() * s.x + cam.screen_up() * (-s.y)
		desired = atan2(-dir.x, -dir.z)
		steer = true
	var max_turn := 1.7 if boosting else 2.5
	var target_rate := 0.0
	if steer:
		target_rate = clampf(wrapf(desired - yaw, -PI, PI) * 4.0, -max_turn, max_turn)
	turn_rate = lerpf(turn_rate, target_rate, 1.0 - exp(-delta * 7.0))
	yaw = wrapf(yaw + turn_rate * delta, -PI, PI)
	# ---- boost
	var want_boost := controls != null and controls.boost and not autopilot
	if want_boost and (boosting or boost_energy > 12.0) and boost_energy > 0.0:
		if not boosting:
			Sfx.play("boost", -4.0)
		boosting = true
		boost_energy = maxf(0.0, boost_energy - 28.0 * delta)
	else:
		boosting = false
		boost_energy = minf(100.0, boost_energy + 16.0 * delta)
	speed = lerpf(speed, BOOST_SPEED if boosting else BASE_SPEED, 1.0 - exp(-delta * 2.2))
	position += forward() * speed * delta
	position.y = ALT + sin(_t * 1.7) * 0.8
	# ---- buildings: collision + low-flying multiplier
	if chunks != null:
		var push := chunks.collide(position.x, position.z, RADIUS, ALT - 6.0)
		if push != Vector2.ZERO:
			position.x += push.x
			position.z += push.y
			if invuln <= 0.0:
				invuln = 0.8
				speed *= 0.55
				var n := push.normalized()
				# bounce heading away from the wall
				var away := atan2(-n.x, -n.y)
				yaw = lerp_angle(yaw, away, 0.5)
				damage(12.0)
				hit_building.emit(12.0)
				if fx != null:
					fx.sparks(position - Vector3(n.x, 0, n.y) * RADIUS, 20)
		near_tall = chunks.nearest_tall(position.x, position.z, ALT - 4.0, 60.0)
		if near_tall < 24.0:
			lowfly_time += delta
			lowfly_grace = 1.2
		else:
			lowfly_grace -= delta
			if lowfly_grace <= 0.0:
				lowfly_time = maxf(0.0, lowfly_time - delta * 3.0)
		multiplier = 1 + mini(3, int(lowfly_time / 1.2))
	# ---- guns
	fire_cd -= delta
	var want_fire := controls != null and controls.fire and not autopilot
	if want_fire and fire_cd <= 0.0 and combat != null:
		fire_cd = FIRE_INTERVAL
		gun_side = -gun_side
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var muzzle := position + forward() * 14.0 + right * (4.0 * gun_side)
		combat.player_shoot(muzzle, forward(), speed)
	# ---- smoke when damaged
	if fx != null:
		smoke_cd -= delta
		if health < 40.0 and smoke_cd <= 0.0:
			smoke_cd = 0.06
			fx.smoke(position - forward() * 12.0, 1)
		if boosting:
			fx.afterburner(position - forward() * 16.0, forward())
	# ---- visual
	stack.rotation.y = yaw
	stack.bank = -turn_rate * 0.14
	stack.flash = 1.0 if (invuln > 0.0 and int(_t * 20.0) % 2 == 0 and invuln < 0.8) else 0.0


var _ap_axis := 0.0
var _ap_cd := 0.0
var _ap_rng := RandomNumberGenerator.new()


## Attract-mode / test autopilot: follow the street grid, sometimes turn.
func _autopilot_heading(delta: float) -> float:
	_ap_cd -= delta
	var q := PI * 0.5
	if absf(wrapf(yaw - _ap_axis, -PI, PI)) > q * 1.5:
		_ap_axis = round(yaw / q) * q
	var along_z := absi(roundi(_ap_axis / q)) % 2 == 0
	var gx := fposmod(position.x + 32.0, 64.0) - 32.0
	var gz := fposmod(position.z + 32.0, 64.0) - 32.0
	if _ap_cd <= 0.0 and absf(gx) < 6.0 and absf(gz) < 6.0:
		_ap_cd = 1.5
		var r := _ap_rng.randf()
		if r < 0.25:
			_ap_axis += q
		elif r < 0.5:
			_ap_axis -= q
		along_z = absi(roundi(_ap_axis / q)) % 2 == 0
	var right := Vector2(cos(_ap_axis), -sin(_ap_axis))
	var off := Vector2(gx, 0.0) if along_z else Vector2(0.0, gz)
	var lateral := off.dot(right)
	return _ap_axis + clampf(lateral * 0.04, -0.6, 0.6)


func damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	Sfx.play("hurt", -2.0)
	if cam != null:
		cam.add_shake(4.0 + amount * 0.25)
	if health <= 0.0:
		health = 0.0
		alive = false
		visible = false
		if fx != null:
			fx.explosion(position, 2.2)
		Sfx.play("big_explode")
		died.emit()
