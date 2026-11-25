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

## --- flight model state (see step): full 3D orientation, speed along the
## nose, throttle, afterburner heat, G load, blackout
const G := 9.8
const MAX_BANK := 1.4 # rad (80 deg)
const THR_MIL := 0.85 # throttle 0..0.85 = idle..military
const THR_AB := 0.92 # above this = afterburner
const AB_HEAT := 13.0 # %/s while burning
const AB_COOL := 9.0
var orient := Basis.IDENTITY
var phys := {}
var throttle := THR_MIL
var in_throttle := THR_MIL # bots
var g_load := 1.0
var gloc := 0.0 # 0..1 blackout
var redout := 0.0
var heat := 0.0
var overheated := false
var stalling := false
var aoa := 0.0
var _n := 1.0
var _roll_rate := 0.0
var _ki := 4000.0
var _cd := 0.0001
var _t_mil := 6.0
var _t_ab := 9.0
var _loop_state := 0
var _loop_t0 := 0.0
var _loop_turned := 0.0
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
## Battle-area boundary: the plane is turned back towards the centre.
var steer_home := false
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
## Aircraft tree: which plane / skin this is and its multipliers.
var plane := -1
var skin := 0
var speed_mult := 1.0
var turn_mult := 1.0
var max_flares := 0
## Was the last hit a missile (for missile / cannon kill stats)?
var last_hit_missile := false
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
var base_damage := 0.0
var ground_kills := 0
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
	if phys.is_empty():
		set_physics(Planes.physics(0, {}, float(cfg["speed"]) / 130.0))
	stack = SpriteStack.new()
	stack.sheet = sheet_name
	stack.variant = skin
	stack.tint = tint
	add_child(stack)
	position.y = ALT


## Top level speed at military power / with afterburner (HUD, bots, camera).
func base_speed() -> float:
	return float(phys.get("vmil", 150.0))


func boost_speed() -> float:
	return float(phys.get("vab", 200.0))


## Fly plane `p` of the aircraft tree with upgrade levels `lv` and a skin.
func apply_plane(p: int, lv: Dictionary, p_skin: int) -> void:
	plane = p
	skin = p_skin
	var st := Planes.stats(p, lv)
	speed_mult = st["speed_mult"]
	turn_mult = st["turn_mult"]
	max_health = st["hp"]
	health = minf(health, max_health) if health > 0.0 else max_health
	cfg["gun_dmg"] = st["gun"]
	max_flares = st["flares"]
	flares = max_flares
	set_physics(Planes.physics(p, lv, float(cfg["speed"]) / 130.0))
	sheet_name = Planes.sheet_of(p)
	tint = Color.WHITE
	if stack != null:
		stack.set_sheet(sheet_name, p_skin)
		stack.tint = tint


## Derive the drag polar and thrust from the plane's traits so that the
## plane really tops out at vmil (military) / vab (afterburner) in level
## flight: D/m = cd*V^2 + ki*n^2/V^2,  T_mil/m = tw*g.
func set_physics(ph: Dictionary) -> void:
	phys = ph
	var vs: float = ph["vs"]
	var vmil: float = ph["vmil"]
	var vab: float = ph["vab"]
	_ki = G * float(ph["ind"]) * vs * vs
	_t_mil = float(ph["tw"]) * G
	_cd = maxf(1e-6, (_t_mil - _ki / (vmil * vmil)) / (vmil * vmil))
	_t_ab = _cd * vab * vab + _ki / (vab * vab)


func forward() -> Vector3:
	var f := forward3()
	var h := Vector2(f.x, f.z)
	if h.length() < 0.05:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))
	h = h.normalized()
	return Vector3(h.x, 0.0, h.y)


## Nose / flight-path direction (full 3D).
func forward3() -> Vector3:
	return -orient.z


func right() -> Vector3:
	var f := forward()
	return Vector3(-f.z, 0.0, f.x)


func visual_basis() -> Basis:
	var b := orient
	# angle of attack: the nose rides above the flight path as G builds
	if aoa > 0.001:
		b = b.rotated(b.x, aoa)
	if roll_extra != 0.0:
		b = b.rotated(-b.z, -roll_extra)
	return b


## Point the plane: heading yaw (0 = -Z), flight-path angle, wings level.
func set_attitude(p_yaw: float, p_pitch: float = 0.0) -> void:
	orient = Basis.from_euler(Vector3(p_pitch, p_yaw, 0.0))
	_derive_angles()


func reset(pos: Vector3, p_yaw: float) -> void:
	position = Vector3(pos.x, float(cfg["cruise"]), pos.z)
	set_attitude(p_yaw)
	roll_extra = 0.0
	aoa = 0.0
	man = M_NONE
	ammo = float(cfg["cannon"])
	reloading = 0.0
	speed = base_speed() * 0.9
	throttle = THR_MIL
	g_load = 1.0
	_n = 1.0
	_roll_rate = 0.0
	gloc = 0.0
	redout = 0.0
	heat = 0.0
	overheated = false
	stalling = false
	health = max_health
	flares = max_flares
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
	_loop_state = 0


func speed_ratio() -> float:
	return clampf((speed - base_speed()) / maxf(1.0, boost_speed() - base_speed()), 0.0, 1.0)


func in_maneuver() -> bool:
	return man != M_NONE


# ------------------------------------------------------------------ tricks

## Barrel roll: a fast 360 deg roll around the flight path (dodges missiles
## in its first part). Works while the stick is held with another finger.
func barrel_roll() -> void:
	if not alive or man == M_LOOP or man == M_FRONT or man == M_ROLL:
		return
	man = M_ROLL
	man_t = 0.0
	man_dur = clampf(TAU / (float(phys.get("roll", 3.0)) * 1.6), 0.55, 1.2)
	man_dir = -1.0 if _stick().x > 0.2 else 1.0
	dodge_window = 0.8
	if is_player:
		Sfx.play("boost", -10.0, 1.6)
	trick.emit("ROLL")


## Loop: wings level, maximum pull until the nose has come all the way
## round. Real physics: slow down too much at the top and it stalls.
func loop(front: bool = false) -> void:
	if not alive or man == M_LOOP or man == M_FRONT:
		return
	man = M_LOOP
	man_t = 0.0
	man_dur = 12.0
	_loop_turned = 0.0
	if is_player:
		Sfx.play("boost", -6.0, 0.8)
	trick.emit("LOOP")


# ------------------------------------------------------------------ flight

## Tests / scripted moments: forces the stick (Vector2.INF = off).
var stick_override := Vector2.INF


func _stick() -> Vector2:
	if stick_override != Vector2.INF:
		return stick_override
	if brain != null:
		return in_stick
	return controls.stick if controls != null else Vector2.ZERO


## yaw / pitch / roll from the orientation (HUD, camera, bots, cockpit).
func _derive_angles() -> void:
	var f := -orient.z
	pitch = asin(clampf(f.y, -1.0, 1.0))
	if Vector2(f.x, f.z).length() > 0.05:
		yaw = atan2(-f.x, -f.z)
	# bank: + = left wing down (same convention as before)
	roll = atan2(orient.x.y, orient.y.y)


## Pilot inputs -> stick (x = bank/turn, y = pull) and throttle.
func _inputs(delta: float) -> Vector2:
	var stick := _stick()
	if autopilot:
		var desired := _autopilot_heading(delta)
		stick.x = clampf(-wrapf(desired - yaw, -PI, PI) * 2.5, -1.0, 1.0)
		stick.y = clampf((float(cfg["cruise"]) - position.y) * 0.01 - forward3().y * 2.0, -0.6, 0.6)
	elif brain == null:
		stick.y *= -1.0 if invert_pitch else 1.0
		if absf(stick.y) < 0.08:
			stick.y = 0.0
	if steer_home:
		var home := atan2(position.x, position.z) # heading towards the origin
		stick.x = clampf(-wrapf(home - yaw, -PI, PI) * 2.0, -1.0, 1.0)
	# G-LOC: a blacked-out pilot loses control
	if gloc > 0.75:
		stick *= clampf(1.0 - (gloc - 0.75) * 4.0, 0.0, 1.0)
	return stick


func step(delta: float) -> void:
	_t += delta
	if not alive:
		return
	invuln = maxf(0.0, invuln - delta)
	dodge_window = maxf(0.0, dodge_window - delta)
	flares_active = maxf(0.0, flares_active - delta)
	var stick := _inputs(delta)
	# ---- throttle + afterburner (heat: overheats, then cools before reuse)
	var thr: float = throttle
	if brain != null:
		thr = in_throttle
	elif controls != null and "throttle" in controls and controls.throttle >= 0.0:
		thr = controls.throttle
	var want_ab := thr >= THR_AB or (in_boost if brain != null else (controls != null and controls.boost))
	if autopilot:
		want_ab = false
		thr = THR_MIL
	if overheated and heat < 40.0:
		overheated = false
	var ab := want_ab and not overheated
	if ab:
		if not boosting and is_player:
			Sfx.play("boost", -4.0)
		heat = minf(100.0, heat + AB_HEAT * delta)
		if heat >= 100.0:
			overheated = true
	else:
		heat = maxf(0.0, heat - AB_COOL * delta)
	boosting = ab
	boost_energy = 100.0 - heat
	var thrust := _t_ab if ab else _t_mil * (0.06 + 0.94 * clampf(minf(thr, THR_MIL) / THR_MIL, 0.0, 1.0))
	# ---- aerodynamics
	var V := maxf(speed, 6.0)
	var f := -orient.z
	var vs: float = phys.get("vs", 55.0)
	var max_g: float = phys.get("max_g", 7.0)
	var agile: float = phys.get("agile", 4.0)
	var n_avail := (V / vs) * (V / vs)
	var soft := clampf((V / vs - 0.7) / 0.6, 0.15, 1.0) # controls go soft near the stall
	var cos_g := sqrt(maxf(0.0, 1.0 - f.y * f.y))
	var bank := atan2(orient.x.y, orient.y.y)
	var roll_cmd := 0.0
	var n_cmd := 1.0
	match man:
		M_LOOP:
			man_t += delta
			# roll wings level relative to the loop plane, then full pull
			roll_cmd = 0.0
			n_cmd = max_g
			if _loop_turned >= TAU * 0.97 or man_t > man_dur:
				man = M_NONE
		M_ROLL:
			man_t += delta
			var k := clampf(man_t / man_dur, 0.0, 1.0)
			roll_extra = man_dir * TAU * (k * k * (3.0 - 2.0 * k))
			position += right() * (-man_dir) * sin(k * PI) * 30.0 * delta
			n_cmd = cos_g / maxf(cos(bank), 0.35) if absf(bank) < PI * 0.5 else 1.0
			if k >= 1.0:
				man = M_NONE
				roll_extra = 0.0
		_:
			# bank-to-turn: the stick commands a bank angle, the pilot pulls
			# enough G for a level turn, and stick Y adds / removes G
			if absf(f.y) < 0.96:
				# the harder you pull, the more bank a level turn needs
				# (acos 1/n): full stick + full pull = hard, slightly
				# descending turn instead of a climbing spiral
				var bank_lim := maxf(MAX_BANK, acos(1.0 / maxf(_n, 1.0)) + 0.06)
				var target_bank := -stick.x * bank_lim
				roll_cmd = clampf(wrapf(target_bank - bank, -PI, PI) * 4.0, -1.0, 1.0)
			else:
				roll_cmd = -stick.x # near vertical: plain roll
			var n_level := cos_g / maxf(cos(bank), 0.35) if absf(bank) < PI * 0.5 else 0.0
			if stick.y >= 0.0:
				n_cmd = n_level + stick.y * (max_g - n_level)
			else:
				n_cmd = n_level + stick.y * (n_level + 2.5)
	# roll with inertia
	var roll_max: float = phys.get("roll", 3.0) * soft
	_roll_rate = lerpf(_roll_rate, roll_cmd * roll_max, 1.0 - exp(-delta * agile * 1.6))
	if man != M_ROLL:
		orient = orient.rotated(f, -_roll_rate * delta) # positive rate rolls left wing down
	# G with inertia, limited by lift available at this speed and by the airframe
	var n_lim := minf(max_g, n_avail)
	stalling = n_cmd > n_avail * 0.97 and V < vs * 1.25
	if stalling:
		n_lim = n_avail * 0.6 # past the critical angle: lift collapses
	n_cmd = clampf(n_cmd, -minf(max_g * 0.45, n_avail * 0.6), n_lim)
	if man == M_ROLL:
		n_cmd = 0.0 # unloaded roll: the path stays straight
	_n = lerpf(_n, n_cmd, 1.0 - exp(-delta * agile * 1.3))
	g_load = _n
	# visual angle of attack
	aoa = lerpf(aoa, clampf(_n / maxf(n_avail, 0.2), -0.3, 1.2) * 0.22, 1.0 - exp(-delta * 6.0))
	# forces per unit mass
	var drag := _cd * V * V + _ki * _n * _n / (V * V)
	var up := orient.y
	var grav := Vector3(0, -G, 0)
	if man == M_ROLL:
		grav = Vector3.ZERO # (unloaded roll ignores the gravity turn)
	var a_par := thrust - drag + grav.dot(f)
	var a_perp := up * (_n * G) + (grav - f * grav.dot(f))
	speed = maxf(4.0, speed + a_par * delta)
	# turn the flight path (and the plane with it) by the perpendicular accel
	var w := f.cross(a_perp) / V
	var wl := w.length()
	if wl > 1e-5:
		orient = orient.rotated(w / wl, wl * delta).orthonormalized()
		if man == M_LOOP:
			_loop_turned += absf(w.dot(orient.x)) * delta
	turn_rate = w.y
	_derive_angles()
	position += forward3() * speed * delta
	_track_loop()
	# ---- G-LOC (blackout) / redout
	if g_load > 6.5:
		gloc = minf(1.0, gloc + (g_load - 6.5) * 0.18 * delta)
	else:
		gloc = maxf(0.0, gloc - 0.35 * delta)
	if g_load < -1.8:
		redout = minf(1.0, redout + (-1.8 - g_load) * 0.4 * delta)
	else:
		redout = maxf(0.0, redout - 0.5 * delta)
	# ---- ceiling
	var ceiling := float(cfg["ceiling"])
	if position.y > ceiling:
		position.y = ceiling
		if f.y > 0.0:
			orient = orient.rotated(orient.x, -f.y * 2.0 * delta)
	# ---- collisions: the ground, the sea, buildings, cliffs = death
	var floor_y := float(cfg["clearance"])
	if position.y < floor_y:
		if bool(cfg["crashes"]):
			crash()
			return
		position.y = floor_y + 1.0
		if f.y < 0.0:
			orient = orient.rotated(orient.x, -f.y)
	if chunks != null:
		var push := chunks.collide(position.x, position.z, RADIUS * 0.6, position.y - 1.0)
		if push != Vector2.ZERO:
			if bool(cfg["crashes"]):
				crash()
				return
			position.x += push.x
			position.z += push.y
		near_tall = chunks.nearest_tall(position.x, position.z, position.y - 6.0, 90.0)
		if position.y < CityGen.LOW_ALT and near_tall < 44.0:
			lowfly_time += delta
			lowfly_grace = 1.2
		else:
			lowfly_grace -= delta
			if lowfly_grace <= 0.0:
				lowfly_time = maxf(0.0, lowfly_time - delta * 3.0)
		multiplier = 1 + mini(3, int(lowfly_time / 1.2))
	_guns_and_effects(delta)


## Natural loops / flips (for tricks, missions): nose up past vertical, over
## the top inverted, down, and back to level within 14 s.
func _track_loop() -> void:
	var f := forward3()
	match _loop_state:
		0:
			if f.y > 0.85:
				_loop_state = 1
				_loop_t0 = _t
		1:
			if orient.y.y < -0.3:
				_loop_state = 2
		2:
			if f.y < -0.4:
				_loop_state = 3
		3:
			if absf(f.y) < 0.35 and orient.y.y > 0.5:
				_loop_state = 0
				if man != M_LOOP:
					trick.emit("LOOP")
	if _loop_state != 0 and _t - _loop_t0 > 14.0:
		_loop_state = 0


## Hitting anything is fatal.
func crash() -> void:
	if not alive:
		return
	# whoever was shooting at you in the last 6 s gets the kill
	if last_hit_by != null and Time.get_ticks_msec() - int(hits.get(last_hit_by, 0)) > 6000:
		last_hit_by = null
	health = 0.0
	_die(2.6)


func _guns_and_effects(delta: float) -> void:
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
		if health < max_health * 0.4 and smoke_cd <= 0.0:
			smoke_cd = 0.09
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


## Destroyed (shot down or crashed): explosion, debris; the pilot ejects.
func _die(big: float = 2.2) -> void:
	health = 0.0
	alive = false
	visible = false
	if fx != null:
		fx.explosion(position, big)
		fx.debris(position, 14)
	Sfx.play("big_explode", 0.0 if is_player else -6.0)
	ejected.emit(position)
	died.emit()


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
		_die()
