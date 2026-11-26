class_name Instructor
## "Mouse aim" instructor (War Thunder style): flies the player's plane so
## the NOSE chases the AIM direction, with the plane's real physics (it only
## produces a stick input). It is a rate controller: the wanted turn and
## climb rates grow with the error (capped) and shrink as the nose arrives;
## the bank and G follow from the acceleration they need (lift vector
## along it), so hard turns stay level and the nose settles on the aim
## without swinging past it. It protects the pilot:
##  - stall: limits the pull when slow (energy still bleeds in hard turns)
##  - ground: looks 1-4 s ahead along the flight path; if the path meets the
##    ground, a building or a mountain at low altitude it rolls wings level
##    and pulls up, and raises the PULL UP warning
## Bots don't use it (they have their own pilots, BotBrain).

## Last warning for the HUD ("" or "PULL UP").
static var warning := ""


static func stick_for(p: Jet, aim: Vector3) -> Vector2:
	warning = ""
	var to := aim.normalized() * 1000.0
	var V := maxf(p.speed, 30.0)
	var assist := float(p.cfg.get("assist", 0.7))
	var turn_k := 1.0 + 0.5 * assist
	var max_g: float = float(p.phys.get("max_g", 7.0))
	var f := p.forward3()
	var cos_g := sqrt(maxf(0.0, 1.0 - f.y * f.y))
	var bank_lim := maxf(Jet.MAX_BANK, acos(1.0 / maxf(p._n, 1.0)) + 0.06)
	var cb := maxf(cos(p.roll), 0.2)
	var n_level := cos_g / (cb * turn_k) if absf(p.roll) < PI * 0.5 else 0.0
	# errors in the level (heading) frame
	var level: Vector3 = Basis(Vector3.UP, p.yaw).inverse() * to
	var side_err := atan2(level.x, -level.z) # + = aim to the right
	var flat := Vector2(level.x, level.z).length()
	var vert_err := atan2(level.y, maxf(flat, 1.0)) - asin(clampf(f.y, -1.0, 1.0))
	# wanted turn / climb rates: grow with the error, capped, shrink as
	# the nose arrives
	var r_des := clampf(side_err * 2.6, -1.5, 1.5)
	var q_des := clampf(vert_err * 1.6, -1.0, 1.5)
	# acceleration that needs across the flight path: sideways for the
	# turn, up for the climb rate plus holding against gravity
	var a_h := r_des * V
	var a_v := q_des * V + Jet.G * cos_g
	# in a real turn, finish the turn before diving (blended, no switching)
	a_v = lerpf(a_v, maxf(a_v, Jet.G * 0.4), smoothstep(Jet.G * 1.0, Jet.G * 2.5, absf(a_h)))
	var bank := 0.0
	var n_des := 0.0
	if a_v >= Jet.G * 0.3:
		# lift vector along the wanted acceleration: bank and G for it
		bank = atan2(a_h, maxf(a_v, Jet.G))
		n_des = Vector2(a_h, a_v).length() / (Jet.G * turn_k)
	else:
		# down faster than gravity: push, with the wings near level
		bank = atan2(a_h, Jet.G) * clampf(a_v / (Jet.G * 0.3), 0.0, 1.0)
		n_des = a_v / (Jet.G * turn_k * cb) * cb * cb
	bank = clampf(bank, -bank_lim, bank_lim)
	# turn-rate damping for the last few degrees only
	var damp := p.turn_rate * 0.2 * (1.0 - smoothstep(0.1, 0.4, absf(side_err)))
	# the stick commands a bank angle (sx = 1: bank_lim to the right)
	var sx := clampf(bank / bank_lim + damp, -1.0, 1.0)
	# pull only once the wings are near the wanted bank
	var roll_ok := maxf(0.0, cos(wrapf(-bank - p.roll, -PI, PI)))
	if n_des > n_level:
		n_des = n_level + (n_des - n_level) * roll_ok * roll_ok
	var sy := (n_des - n_level) / maxf(max_g - n_level, 0.5) if n_des >= n_level else (n_des - n_level) / (n_level + 2.5)
	sy = clampf(sy, -1.0, 1.0)
	# stall protection: ease the pull when slow (energy still bleeds)
	var vs: float = float(p.phys.get("vs", 55.0))
	if p.speed < vs * 1.35:
		sy = minf(sy, lerpf(0.0, 0.6, clampf((p.speed / vs - 1.0) / 0.35, 0.0, 1.0)))
	# ground protection
	if _ground_ahead(p):
		warning = "PULL UP"
		sx = 0.0 # wings level
		sy = 1.0 if absf(p.roll) < 1.2 else 0.3
	return Vector2(sx, sy)


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
