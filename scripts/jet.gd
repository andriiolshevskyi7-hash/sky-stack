class_name Jet
extends Node3D
## Player fighter jet. Cruises high above the city; dive down to thread
## between skyscrapers for a score multiplier (hitting one costs health).
## Steering: OVERHEAD = joystick points the heading (CLIMB/DIVE buttons or
## Q/E change altitude). CHASE/COCKPIT = joystick X turns (bank), Y pitches.

signal hit_building(amount: float)
signal died
signal damaged(amount: float)

const ALT := CityGen.JET_ALT
const BASE_SPEED := 95.0
const BOOST_SPEED := 175.0
const MIN_ALT := 8.0
const MAX_ALT := 230.0
const MAX_PITCH := 0.6
const MAX_AMMO := 300.0
const RADIUS := 6.0
const FIRE_INTERVAL := 1.0 / 12.0

var yaw := 0.0
var pitch := 0.0 # + = nose up
var roll := 0.0 # visual bank, + = left wing down
var flight_mode := false # true: stick X turns, stick Y pitches (chase/cockpit)
var invert_pitch := false
var ammo := MAX_AMMO
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


## Nose direction including pitch.
func forward3() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func visual_basis() -> Basis:
	var y := yaw
	if Save.sprite_snap:
		var st := TAU / 64.0
		y = round(y / st) * st
	return Basis.from_euler(Vector3(pitch, y, roll))


func reset(pos: Vector3, p_yaw: float) -> void:
	position = Vector3(pos.x, ALT, pos.z)
	yaw = p_yaw
	pitch = 0.0
	roll = 0.0
	ammo = MAX_AMMO
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
	# ---- steering
	var desired := yaw
	var steer := false
	var max_turn := 1.6 if boosting else 2.3
	var target_rate := 0.0
	var pitch_in := 0.0
	var stick := controls.stick if controls != null else Vector2.ZERO
	if autopilot:
		desired = _autopilot_heading(delta)
		steer = true
		pitch_in = clampf((ALT - position.y) * 0.02, -1.0, 1.0)
	elif flight_mode:
		target_rate = -stick.x * max_turn
		pitch_in = -stick.y * (-1.0 if invert_pitch else 1.0)
		if absf(stick.y) < 0.15:
			pitch_in = 0.0
	else:
		if stick.length() > 0.2 and cam != null:
			var dir := cam.screen_right() * stick.x + cam.screen_up() * (-stick.y)
			desired = atan2(-dir.x, -dir.z)
			steer = true
		if controls != null:
			pitch_in = controls.alt_axis
	if controls != null and controls.alt_axis != 0.0 and not autopilot:
		pitch_in = controls.alt_axis
	if steer:
		target_rate = clampf(wrapf(desired - yaw, -PI, PI) * 4.0, -max_turn, max_turn)
	turn_rate = lerpf(turn_rate, target_rate, 1.0 - exp(-delta * 6.0))
	yaw = wrapf(yaw + turn_rate * delta, -PI, PI)
	pitch = lerpf(pitch, pitch_in * MAX_PITCH, 1.0 - exp(-delta * 3.0))
	roll = lerpf(roll, clampf(turn_rate * 0.38, -0.95, 0.95), 1.0 - exp(-delta * 5.0))
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
	position += forward3() * speed * delta
	if position.y > MAX_ALT:
		position.y = MAX_ALT
		pitch = minf(pitch, 0.0)
	if position.y < MIN_ALT:
		# hit the ground / water
		position.y = MIN_ALT + 2.0
		pitch = 0.35
		if invuln <= 0.0:
			invuln = 1.0
			damage(15.0)
			if fx != null:
				fx.sparks(position, 24)
	# ---- buildings: collision + low-flying multiplier
	if chunks != null:
		var push := chunks.collide(position.x, position.z, RADIUS, position.y - 2.0)
		if push != Vector2.ZERO:
			position.x += push.x
			position.z += push.y
			if invuln <= 0.0:
				invuln = 0.8
				speed *= 0.55
				var n := push.normalized()
				var away := atan2(-n.x, -n.y)
				yaw = lerp_angle(yaw, away, 0.5)
				damage(12.0)
				hit_building.emit(12.0)
				if fx != null:
					fx.sparks(position - Vector3(n.x, 0, n.y) * RADIUS, 20)
		near_tall = chunks.nearest_tall(position.x, position.z, position.y - 6.0, 60.0)
		if position.y < CityGen.LOW_ALT and near_tall < 26.0:
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
	ammo = minf(MAX_AMMO, ammo + 5.0 * delta)
	if want_fire and fire_cd <= 0.0 and combat != null and ammo >= 1.0:
		ammo -= 1.0
		fire_cd = FIRE_INTERVAL
		gun_side = -gun_side
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var muzzle := position + forward() * 14.0 + right * (4.0 * gun_side)
		combat.player_shoot(muzzle, forward3(), speed)
	# ---- smoke when damaged
	if fx != null:
		smoke_cd -= delta
		if health < 40.0 and smoke_cd <= 0.0:
			smoke_cd = 0.06
			fx.smoke(position - forward() * 12.0, 1)
		var vb := visual_basis()
		fx.contrail(position + vb * Vector3(-14.0, 3.0, 8.0))
		fx.contrail(position + vb * Vector3(14.0, 3.0, 8.0))
		fx.afterburner(position + vb * Vector3(0.0, 2.5, 16.0), forward3(), boosting)
	# ---- visual
	stack.basis = visual_basis()
	stack.bank = 0.0
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
	damaged.emit(amount)
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
