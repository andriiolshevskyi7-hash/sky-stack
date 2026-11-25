class_name Bases
extends Node3D
## Team bases for BASE STRIKE: airfield, AA guns, radar, bunkers and hangars.
## Every structure is a target (pos/active + take_damage). AA guns fire flak at
## enemy planes; while a team's radar stands, that team sees enemies on the
## minimap. Built from the same collapsed stacks as the city.

enum { AIRFIELD, AA, RADAR, BUNKER, HANGAR }
const KIND_NAMES := ["AIRFIELD", "AA GUN", "RADAR", "BUNKER", "HANGAR"]
const HP := [90.0, 30.0, 50.0, 40.0, 60.0]

class Structure:
	var kind := 0
	var team := 0
	var pos := Vector3.ZERO # world, roof centre (aim point)
	var box := AABB() # world bounds
	var hp := 10.0
	var max_hp := 10.0
	var active := true
	var node: MeshInstance3D
	var rubble: MeshInstance3D
	var fire_cd := 1.0
	var bases: Node

	func take_damage(d: float, src: Object) -> void:
		if not active:
			return
		hp -= d
		if src != null and is_instance_valid(src) and "base_damage" in src:
			src.base_damage += d
		if hp <= 0.0:
			active = false
			bases.destroyed(self, src)

var structures: Array[Structure] = []
var centers := [Vector3.ZERO, Vector3.ZERO]
var game: Node
var fleet: Fleet
var combat: Combat
var fx: Fx
var rng := RandomNumberGenerator.new()


func clear() -> void:
	for s in structures:
		if is_instance_valid(s.node):
			s.node.queue_free()
		if is_instance_valid(s.rubble):
			s.rubble.queue_free()
	structures.clear()


## Find solid land near p (bases look odd in the sea); falls back to p.
static func find_land(p: Vector3) -> Vector3:
	for r in [0.0, 400.0, 800.0, 1200.0, 1600.0]:
		for k in 8:
			var a := TAU * k / 8.0
			var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * r
			if CityGen.island_hw(q.x, q.z) > 0.56 and not CityGen.is_urban(floori(q.x / CityGen.WBLOCK), floori(q.z / CityGen.WBLOCK)):
				return Vector3(q.x, 0, q.z)
	return Vector3(p.x, 0, p.z)


func build(team: int, center: Vector3, facing: float) -> void:
	centers[team] = center
	var S := CityGen.S
	var c := Vector2(center.x, center.z) / S
	var f := Vector2(-sin(facing), -cos(facing)) # towards the enemy
	var r := Vector2(f.y, -f.x)
	var team_col := Color(0.55, 0.75, 1.0) if team == 0 else Color(1.0, 0.55, 0.5)
	# airfield: tinted pad + runway (ground mesh)
	var g := CityGen.Build.new()
	g.sheets = Stacks.sheets
	var pad := 170.0
	g.g.ground_rect(c.x - pad, c.y - pad, c.x + pad, c.y + pad, 0.3, CityGen.G_SLABS, team_col)
	if absf(f.x) > absf(f.y):
		g.g.ground_rect(c.x - 150, c.y - 14, c.x + 150, c.y + 14, 0.4, CityGen.G_RUNWAY)
	else:
		g.g.ground_rect(c.x - 14, c.y - 150, c.x + 14, c.y + 150, 0.4, CityGen.G_RUNWAY, Color.WHITE, 16.0, true)
	var gm := MeshInstance3D.new()
	gm.mesh = g.g.commit()
	gm.material_override = Stacks.ground_mat
	gm.scale = Vector3.ONE * S
	add_child(gm)
	var air := _add(team, AIRFIELD, Vector3(c.x, 0.5, c.y), Vector3(300, 4, 28), null)
	air.node = gm
	# hangars, bunkers, radar, AA guns
	for k in 2:
		var p := c + r * (90.0 if k == 0 else -90.0) - f * 70.0
		_add_box(team, HANGAR, p, Vector2(44, 30), 18.0, CityGen.F_HANGAR, CityGen.R_METAL)
	for k in 3:
		var p := c - f * 120.0 + r * (k - 1) * 50.0
		_add_box(team, BUNKER, p, Vector2(16, 16), 7.0, CityGen.F_WAREHOUSE, CityGen.R_CONCRETE)
	var rp := c - f * 40.0 + r * 130.0
	var radar := _add_box(team, RADAR, rp, Vector2(10, 10), 34.0, CityGen.F_OFFICE, CityGen.R_TAR)
	radar.pos.y += 20.0
	for k in 4:
		var sx := 1.0 if k % 2 == 0 else -1.0
		var sz := 1.0 if k < 2 else -1.0
		var p := c + r * sx * 150.0 + f * sz * 150.0
		_add_box(team, AA, p, Vector2(12, 12), 5.0, CityGen.F_WAREHOUSE, CityGen.R_CONCRETE, "aagun")


func _add(team: int, kind: int, vpos: Vector3, vsize: Vector3, node: MeshInstance3D) -> Structure:
	var s := Structure.new()
	s.kind = kind
	s.team = team
	s.bases = self
	s.hp = HP[kind]
	s.max_hp = HP[kind]
	var S := CityGen.S
	s.pos = Vector3(vpos.x * S, vsize.y * S, vpos.z * S)
	s.box = AABB(Vector3(vpos.x - vsize.x * 0.5, 0, vpos.z - vsize.z * 0.5) * S, vsize * S)
	s.node = node
	s.fire_cd = rng.randf_range(0.5, 2.0)
	structures.append(s)
	return s


func _add_box(team: int, kind: int, p: Vector2, sz: Vector2, h: float, style: int, roof: int, stack: String = "") -> Structure:
	var cb := CityGen.Build.new()
	cb.sheets = Stacks.sheets
	CityGen._box(cb, p.x - sz.x * 0.5, p.y - sz.y * 0.5, p.x + sz.x * 0.5, p.y + sz.y * 0.5, 0.0, h, style, roof, rng.randf(), true)
	if kind == RADAR:
		cb.p.add_stack(Stacks.get_sheet("antenna"), 0, Vector3(p.x, h + 0.3, p.y), 0.0, 1.4, Color.WHITE, 2)
		cb.p.add_stack(Stacks.get_sheet("helipad"), 0, Vector3(p.x, h + 12.0, p.y), 0.0, 0.5, Color.WHITE, 1)
	if stack != "":
		cb.p.add_stack(Stacks.get_sheet(stack), 0, Vector3(p.x, h + 0.3, p.y), rng.randf() * TAU, 1.2, Color.WHITE, 2)
	var node := MeshInstance3D.new()
	var m := cb.b.commit()
	if not cb.p.is_empty():
		var arr := cb.p.to_arrays()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(1, Stacks.static_mat)
	m.surface_set_material(0, Stacks.building_mat)
	node.mesh = m
	node.scale = Vector3.ONE * CityGen.S
	add_child(node)
	return _add(team, kind, Vector3(p.x, 0, p.y), Vector3(sz.x, h, sz.y), node)


func destroyed(s: Structure, src: Object) -> void:
	fx.explosion(s.pos, 2.5 if s.kind != AA else 1.5)
	fx.debris(s.pos, 18)
	fx.add_column(s.pos, 0.8)
	Sfx.play("big_explode", -4.0)
	if s.kind != AIRFIELD and is_instance_valid(s.node):
		s.node.scale.y = CityGen.S * 0.18 # flattened into rubble
	if src != null and is_instance_valid(src) and "ground_kills" in src:
		src.ground_kills += 1
	if game != null:
		game.on_structure_destroyed(s, src)


# ------------------------------------------------------------------ queries

func alive_targets(team: int) -> Array:
	var out: Array = []
	for s in structures:
		if s.active and s.team == team:
			out.append(s)
	return out


## Team base health 0..1 (sum of structure hp).
func health(team: int) -> float:
	var hp := 0.0
	var mx := 0.0
	for s in structures:
		if s.team == team:
			hp += maxf(0.0, s.hp)
			mx += s.max_hp
	return hp / mx if mx > 0.0 else 0.0


func radar_up(team: int) -> bool:
	for s in structures:
		if s.team == team and s.kind == RADAR and s.active:
			return true
	return false


## Nearest enemy structure for an attacker of `team`.
func target_for(plane: Jet) -> Object:
	var best: Structure = null
	var bd := 1e9
	for s in structures:
		if s.active and s.team != plane.team:
			var d := s.pos.distance_to(plane.position)
			# AA first, then the rest
			if s.kind == AA:
				d *= 0.6
			if d < bd:
				bd = d
				best = s
	return best


## Bullet hits on enemy structures.
func hit_test(p: Vector3, team: int, dmg: float, src: Object) -> bool:
	for s in structures:
		if s.active and s.team != team and s.box.grow(3.0).has_point(p):
			s.take_damage(dmg, src)
			return true
	return false


func _process(delta: float) -> void:
	if fleet == null:
		return
	for s in structures:
		if not s.active or s.kind != AA:
			continue
		s.fire_cd -= delta
		if s.fire_cd > 0.0:
			continue
		var best: Jet = null
		var bd := 1100.0
		for j in fleet.planes:
			if j.alive and j.team != s.team and j.position.y < 1100.0:
				var d := j.position.distance_to(s.pos)
				if d < bd:
					bd = d
					best = j
		if best == null:
			s.fire_cd = 0.5
			continue
		s.fire_cd = rng.randf_range(1.4, 2.2)
		var predict := best.position + best.forward3() * best.speed * (bd / 360.0) + Vector3(rng.randf_range(-25, 25), rng.randf_range(-15, 15), rng.randf_range(-25, 25))
		combat.lob(s.pos + Vector3(0, 10, 0), predict, 360.0, 8.0, Combat.FLAK, -1, s.team)
