class_name Jet
extends Node3D
## Player fighter jet. Cruises above the city; dive down to thread between
## skyscrapers for a score multiplier (hitting one costs hull).
## Flight (all views): stick X turns with a visible bank, stick Y pitches
## (+ = climb). Tricks: barrel roll (tap), loop (LOOP button), back flip
## (full climb + boost held), front flip (full dive + boost held, needs
## height), eject (hold a dive into the ground with boost off).

signal hit_building(amount: float)
signal died
signal damaged(amount: float)
signal ejected(pos: Vector3)
signal trick(name: String)

enum { M_NONE, M_ROLL, M_LOOP, M_FRONT }

const ALT := CityGen.JET_ALT
const MIN_ALT := 6.0
const MAX_ALT := 1500.0
const MAX_PITCH := 0.62
const MAX_AMMO := 300.0
const RADIUS := 7.0
const FIRE_INTERVAL := 1.0 / 12.0
const BASE_SPEED := 92.0
const BOOST_SPEED := BASE_SPEED * 1.8

## tunables (pause-menu settings)
var cfg := {
	"speed": 130.0, "boost": 1.8, "turn": 1.25, "bank": 52.0, "cruise": 220.0,
	"ceiling": 3000.0, "clearance": 14.0, "crashes": true, "cannon": 300, "reload": 5.0,
}

var yaw := 0.0
var pitch := 0.0 # + = nose up (can go past 90 deg during loops)
var roll := 0.0 # visual bank, + = left wing down
var roll_extra := 0.0 # barrel roll
var flight_mode := true
var invert_pitch := false
var ammo := MAX_AMMO
var reloading := 0.0
var speed := BASE_SPEED
var turn_rate := 0.0
var health := 100.0
var max_health := 100.0
var boost_energy := 100.0
var boosting := false
var alive := true
var invuln := 0.0
var autopilot := false
var man := M_NONE
var man_t := 0.0
var man_dur := 1.0
var man_dir := 1.0
var _pitch0 := 0.0
var _flip_hold := 0.0
var _eject_hold := 0.0
## > 0 while a barrel roll is in its "dodge" phase (combat checks this)
var dodge_window := 0.0

var lowfly_time := 0.0
var lowfly_grace := 0.0
var multiplier := 1
var near_tall := 999.0

var fire_cd := 0.0
var gun_side := 1
var smoke_cd := 0.0
var _t := 0.0

## --- identity / team (player and bots share this class and flight model)
var team := 0
var pilot := "YOU"
var is_player := true
var brain: Object = null # BotBrain for bots
var sheet_name := "jet"
var tint := Color.WHITE
## virtual inputs (bots write these; the player's come from Controls)
var in_stick := Vector2.ZERO
var in_boost := false
var in_fire := false
## per-plane combat stats (match results)
var kills := 0
var deaths := 0
var assists := 0
var damage_dealt := 0.0
var shots_fired := 0
var shots_hit := 0
var last_hit_by: Object = null
var hits := {} # attacker Jet -> time of last hit (assists)
var respawn_t := -1.0
var flares_active := 0.0 # > 0: flares out, incoming missiles are decoyed
var flares := 0

var stack: SpriteStack
var controls: Controls
var cam: GameCamera
var chunks: ChunkManager
var combat: Node
var fx: Node
var trails: Trails


func _ready() -> void:
	stack = SpriteStack.new()
	stack.sheet = sheet_name
	stack.tint = tint
	add_child(stack)
	position.y = ALT


func base_speed() -> float:
	return float(cfg["speed"])


func boost_speed() -> float:
	return float(cfg["speed"]) * float(cfg["boost"])


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Nose direction including pitch.
func forward3() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func visual_basis() -> Basis:
	var y := yaw
	if Save.sprite_snap:
		var st := TAU / 64.0
		y = round(y / st) * st
	return Basis.from_euler(Vector3(pitch, y, roll + roll_extra))


func reset(pos: Vector3, p_yaw: float) -> void:
	position = Vector3(pos.x, float(cfg["cruise"]), pos.z)
	yaw = p_yaw
	pitch = 0.0
	roll = 0.0
	roll_extra = 0.0
	man = M_NONE
	ammo = float(cfg["cannon"])
	reloading = 0.0
	speed = base_speed()
	health = max_health
	boost_energy = 100.0
	alive = true
	visible = true
	invuln = 1.5
	multiplier = 1
	lowfly_time = 0.0
	turn_rate = 0.0
	hits.clear()
	last_hit_by = null
	respawn_t = -1.0


func speed_ratio() -> float:
	return clampf((speed - base_speed()) / maxf(1.0, boost_speed() - base_speed()), 0.0, 1.0)


func in_maneuver() -> bool:
	return man != M_NONE


# ------------------------------------------------------------------ tricks

func barrel_roll() -> void:
	if not alive or man == M_LOOP or man == M_FRONT:
		return
	man = M_ROLL
	man_t = 0.0
	man_dur = 0.6
	man_dir = -1.0 if _stick().x > 0.2 else 1.0
	dodge_window = 0.8
	if is_player:
		Sfx.play("boost", -10.0, 1.6)
	trick.emit("ROLL")


func loop(front: bool = false) -> void:
	if not alive or man == M_LOOP or man == M_FRONT:
		return
	if front and position.y < 200.0:
		return
	man = M_FRONT if front else M_LOOP
	man_t = 0.0
	man_dur = 2.4
	_pitch0 = clampf(pitch, -0.3, 0.3)
	if is_player:
		Sfx.play("boost", -6.0, 0.8)
	trick.emit("FRONT FLIP" if front else "LOOP")


# ------------------------------------------------------------------ flight

func _stick() -> Vector2:
	if brain != null:
		return in_stick
	return controls.stick if controls != null else Vector2.ZERO


func step(delta: float) -> void:
	_t += delta
	if not alive:
		return
	invuln = maxf(0.0, invuln - delta)
	dodge_window = maxf(0.0, dodge_window - delta)
	flares_active = maxf(0.0, flares_active - delta)
	var stick := _stick()
	var turn_max := float(cfg["turn"]) * (0.8 if boosting else 1.0)
	# ---- boost
	var want_boost := (in_boost if brain != null else (controls != null and controls.boost)) and not autopilot
	if want_boost and (boosting or boost_energy > 12.0) and boost_energy > 0.0:
		if not boosting and is_player:
			Sfx.play("boost", -4.0)
		boosting = true
		boost_energy = maxf(0.0, boost_energy - 22.0 * delta)
	else:
		boosting = false
		boost_energy = minf(100.0, boost_energy + 16.0 * delta)
	speed = lerpf(speed, boost_speed() if boosting else base_speed(), 1.0 - exp(-delta * 2.2))
	# ---- maneuvers
	if man == M_LOOP or man == M_FRONT:
		man_t += delta
		var k := clampf(man_t / man_dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		pitch = _pitch0 + (TAU if man == M_LOOP else -TAU) * e
		turn_rate = lerpf(turn_rate, 0.0, 1.0 - exp(-delta * 4.0))
		if k >= 1.0:
			man = M_NONE
			pitch = wrapf(pitch, -PI, PI)
	else:
		if man == M_ROLL:
			man_t += delta
			var k := clampf(man_t / man_dur, 0.0, 1.0)
			roll_extra = man_dir * TAU * (k * k * (3.0 - 2.0 * k))
			position += right() * (-man_dir) * sin(k * PI) * 30.0 * delta
			if k >= 1.0:
				man = M_NONE
				roll_extra = 0.0
		var target_rate := 0.0
		var pitch_in := 0.0
		if autopilot:
			var desired := _autopilot_heading(delta)
			target_rate = clampf(wrapf(desired - yaw, -PI, PI) * 4.0, -turn_max, turn_max)
			pitch_in = clampf((float(cfg["cruise"]) - position.y) * 0.02, -1.0, 1.0)
		else:
			target_rate = -stick.x * turn_max
			pitch_in = stick.y * (-1.0 if invert_pitch else 1.0)
			if absf(pitch_in) < 0.12:
				pitch_in = 0.0
		turn_rate = lerpf(turn_rate, target_rate, 1.0 - exp(-delta * 4.5))
		pitch = lerpf(pitch, pitch_in * MAX_PITCH, 1.0 - exp(-delta * 2.6))
		# back flip: full climb + boost held; front flip: full dive + boost held
		if not autopilot and brain == null and boosting and absf(pitch_in) > 0.9:
			_flip_hold += delta
			if _flip_hold > 0.35:
				_flip_hold = 0.0
				loop(pitch_in < 0.0)
		else:
			_flip_hold = 0.0
		# eject: hold a dive into the ground with boost off
		if not autopilot and is_player and bool(cfg["crashes"]) and not boosting and pitch_in < -0.85 and position.y < 60.0:
			_eject_hold += delta
			if _eject_hold > 0.45:
				_eject_hold = 0.0
				_eject()
				return
		else:
			_eject_hold = 0.0
	yaw = wrapf(yaw + turn_rate * delta, -PI, PI)
	var bank := deg_to_rad(float(cfg["bank"]))
	# smooth banking: roll leads into the turn and eases back out
	var want_roll := clampf(turn_rate / maxf(0.1, float(cfg["turn"])), -1.0, 1.0) * bank
	roll = lerpf(roll, want_roll, 1.0 - exp(-delta * 3.4))
	position += forward3() * speed * delta
	var ceiling := float(cfg["ceiling"])
	if position.y > ceiling:
		position.y = ceiling
		if man == M_NONE:
			pitch = minf(pitch, 0.0)
	var floor_y := float(cfg["clearance"])
	if position.y < floor_y:
		# skim / scrape the ground or the sea
		position.y = floor_y + 1.5
		if man == M_NONE:
			pitch = maxf(pitch, 0.25)
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
				yaw = lerp_angle(yaw, atan2(-n.x, -n.y), 0.5)
				damage(12.0)
				hit_building.emit(12.0)
				if fx != null:
					fx.sparks(position - Vector3(n.x, 0, n.y) * RADIUS, 20)
		near_tall = chunks.nearest_tall(position.x, position.z, position.y - 6.0, 90.0)
		if position.y < CityGen.LOW_ALT and near_tall < 44.0:
			lowfly_time += delta
			lowfly_grace = 1.2
		else:
			lowfly_grace -= delta
			if lowfly_grace <= 0.0:
				lowfly_time = maxf(0.0, lowfly_time - delta * 3.0)
		multiplier = 1 + mini(3, int(lowfly_time / 1.2))
	# ---- guns (300 rounds, then a reload)
	fire_cd -= delta
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			ammo = float(cfg["cannon"])
	var want_fire := (in_fire if brain != null else (controls != null and controls.fire)) and not autopilot
	if want_fire and fire_cd <= 0.0 and combat != null and reloading <= 0.0 and ammo >= 1.0:
		ammo -= 1.0
		if ammo < 1.0:
			reloading = float(cfg["reload"])
		fire_cd = FIRE_INTERVAL
		gun_side = -gun_side
		var muzzle := position + forward3() * 16.0 + right() * (4.0 * gun_side)
		shots_fired += 1
		combat.shoot(self, muzzle, forward3(), speed)
	# ---- effects
	if fx != null:
		smoke_cd -= delta
		if health < 40.0 and smoke_cd <= 0.0:
			smoke_cd = 0.06
			fx.smoke(position - forward3() * 14.0, 1)
		var vb := visual_basis()
		if trails != null:
			trails.add(0, position + vb * Vector3(-17.0, 3.0, 9.0))
			trails.add(1, position + vb * Vector3(17.0, 3.0, 9.0))
		if is_player or cam == null or position.distance_squared_to(cam.global_position) < 2500.0 * 2500.0:
			fx.afterburner(position + vb * Vector3(0.0, 2.5, 20.0), forward3(), boosting)
		# sea spray when skimming the water
		if position.y < 45.0 and CityGen.is_water_w(position.x, position.z):
			fx.spray(Vector3(position.x, 0.5, position.z) - forward() * 10.0, 1.0 - position.y / 45.0)
	# ---- visual
	stack.basis = visual_basis()
	stack.bank = 0.0
	stack.flash = 1.0 if (invuln > 0.0 and int(_t * 20.0) % 2 == 0 and invuln < 0.8) else 0.0


func _eject() -> void:
	alive = false
	visible = false
	if fx != null:
		fx.explosion(position + forward3() * 30.0, 1.6)
	Sfx.play("big_explode")
	ejected.emit(position)


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
	var rgt := Vector2(cos(_ap_axis), -sin(_ap_axis))
	var off := Vector2(gx, 0.0) if along_z else Vector2(0.0, gz)
	return _ap_axis + clampf(off.dot(rgt) * 0.04, -0.6, 0.6)


func damage(amount: float, attacker: Object = null) -> void:
	if not alive:
		return
	health -= amount
	if attacker != null and attacker != self:
		last_hit_by = attacker
		hits[attacker] = Time.get_ticks_msec()
		if "damage_dealt" in attacker:
			attacker.damage_dealt += amount
	damaged.emit(amount)
	if is_player:
		Sfx.play("hurt", -2.0)
		if cam != null:
			cam.add_shake(4.0 + amount * 0.25)
	if health <= 0.0:
		health = 0.0
		alive = false
		visible = false
		if fx != null:
			fx.explosion(position, 2.2)
			fx.debris(position, 14)
		Sfx.play("big_explode", 0.0 if is_player else -6.0)
		died.emit()
