class_name Instructor
## "Mouse aim" instructor (War Thunder style): flies a plane so its NOSE
## chases the AIM direction (anywhere on the full sphere) with the plane's
## real physics, the way a pilot would, and returns a DIRECT command for the
## flight model: x = roll rate (+ = roll right, -1..1 of the plane's roll
## rate), y = load factor (+1 = max G, -1 = -2.5 G). Roll, G and speed then
## build up with the flight model's own inertia and energy.
##  - far off the nose: roll the lift vector onto the aim, then pull. Aim
##    below -> roll inverted and pull through (split-S, ends lower, flying
##    the other way); aim up and back -> half loop, then roll upright
##    (Immelmann); aim behind -> keeps turning without stopping
##  - small errors: bank towards the side error, pitch for up / down (push
##    allowed), wings back towards upright
##  - protection only: eases the pull when slow (energy still bleeds); a dive
##    is limited by the altitude left; if the flight path meets the ground, a
##    building or a mountain it rolls upright, pulls and warns PULL UP
## Bots use it too (BotBrain) for split-S, Immelmann and high yo-yo.

## Last warning for the HUD ("" or "PULL UP").
static var warning := ""


static func stick_for(p: Jet, aim_in: Vector3) -> Vector2:
	if p.brain == null:
		warning = ""
	var aim := _safe_aim(p, aim_in.normalized())
	var V := maxf(p.speed, 30.0)
	var assist := float(p.cfg.get("assist", 0.7))
	var tk := 1.0 + 0.5 * assist
	var max_g: float = float(p.phys.get("max_g", 7.0))
	var roll_max: float = float(p.phys.get("roll", 3.0)) * (1.0 + 0.5 * assist)
	var b: Basis = p.orient
	var f := -b.z
	var up := b.y
	var bank := atan2(b.x.y, b.y.y) # 0 upright, + = left wing down, +-PI inverted
	var rate_right := -p._roll_rate / maxf(roll_max, 0.1) # current roll rate, + = right
	var local: Vector3 = b.inverse() * aim # x right, y up, -z ahead
	var ang := acos(clampf(-local.z, -1.0, 1.0))
	# aim (nearly) dead behind: turn towards a side instead of an undefined
	# roll; keep the side picked last time
	var behind := ang > 2.5
	if behind:
		# the side is taken from the heading (level), not from the wing,
		# which turns with the roll
		var ff := Vector3(f.x, 0.0, f.z)
		var side_w: Vector3 = ff.normalized().cross(Vector3.UP) if ff.length_squared() > 0.01 else b.x
		aim = (aim + side_w * p._ins_side * 0.8).normalized()
		local = b.inverse() * aim
		ang = acos(clampf(-local.z, -1.0, 1.0))
	# --- lift vector mode: roll so the aim is straight above the canopy
	var phi := atan2(local.x, local.y) # + = the aim is right of the lift vector
	if absf(phi) < 2.6:
		# remember the side, but only from the real aim and a clear side
		# (not from the shifted "behind" aim, not from noise near zero)
		if not behind and absf(phi) > 0.25:
			p._ins_side = 1.0 if phi >= 0.0 else -1.0
	elif signf(phi) != p._ins_side:
		phi -= signf(phi) * TAU # aim below: keep rolling the way we started
	var roll_l := clampf(phi * 2.2 - rate_right * 0.45, -1.0, 1.0) * smoothstep(0.02, 0.1, ang)
	var align := 1.0 - smoothstep(0.35, 1.3, absf(phi))
	var q_l := minf(ang * 2.2, 3.2) * align
	var n_l := (q_l * V + Jet.G * up.y) / (Jet.G * tk)
	# --- small errors: bank towards the side error, pitch for up / down,
	# wings back towards upright when on target
	var side := atan2(local.x, -local.z)
	var pitch_e := atan2(local.y, -local.z)
	var want_bank_r := clampf(side * 6.0, -1.1, 1.1) # + = right bank
	var roll_s := clampf(wrapf(want_bank_r + bank, -PI, PI) * 2.0 - rate_right * 0.45, -1.0, 1.0)
	var q_s := clampf(pitch_e * 3.0, -1.5, 3.0)
	var n_s := (q_s * V + Jet.G * up.y) / (Jet.G * tk)
	var w := smoothstep(0.08, 0.3, ang)
	if absf(f.y) > 0.85:
		w = 1.0 # near vertical the bank angle means nothing: lift vector only
	var roll := lerpf(roll_s, roll_l, w)
	var n := lerpf(n_s, n_l, w)
	# stall protection: ease the pull when slow (energy still bleeds)
	var vs: float = float(p.phys.get("vs", 55.0))
	if p.speed < vs * 1.35:
		n = minf(n, lerpf(1.0, max_g * 0.6, clampf((p.speed / vs - 1.0) / 0.35, 0.0, 1.0)))
	# ground protection: roll upright and pull
	if _ground_ahead(p):
		if p.brain == null:
			warning = "PULL UP"
		roll = clampf(bank * 2.0 - rate_right * 0.45, -1.0, 1.0)
		n = max_g if absf(bank) < 1.2 else 0.5
	var sy := n / max_g if n >= 0.0 else n / 2.5
	return Vector2(clampf(roll, -1.0, 1.0), clampf(sy, -1.0, 1.0))


## The aim the instructor actually flies: how steep a dive may be depends
## on the altitude left (a split-S needs room to pull out).
static func _safe_aim(p: Jet, aim: Vector3) -> Vector3:
	var y := p.position.y
	var el_min := -lerpf(0.05, PI * 0.5, clampf((y - 80.0) / 1100.0, 0.0, 1.0))
	var el := asin(clampf(aim.y, -1.0, 1.0))
	if el >= el_min:
		return aim
	var flat := Vector2(aim.x, aim.z)
	if flat.length() < 0.05:
		var f := p.forward3()
		flat = Vector2(f.x, f.z)
		if flat.length() < 0.05:
			flat = Vector2(0, -1)
	flat = flat.normalized() * cos(el_min)
	return Vector3(flat.x, sin(el_min), flat.y)


static func _ground_ahead(p: Jet) -> bool:
	var y := p.position.y
	var f := p.forward3()
	if y < 45.0 and f.y < 0.1:
		return true
	if y > 900.0:
		return false
	for t in [1.0, 2.0, 3.0, 4.0]:
		var q: Vector3 = p.position + f * p.speed * t
		if q.y < 22.0:
			return true
		if p.chunks != null and p.chunks.nearest_tall(q.x, q.z, q.y - 20.0, 40.0) < 30.0:
			return true
		if CityGen.feature != CityGen.FEAT_NONE and CityGen.relief_hw(q.x, q.z) > q.y - 35.0:
			return true
	return false
