class_name Fleet
extends Node3D
## Every plane in the battle (the player + bots of both teams). Steps the
## bots, resolves bullet/missile hits between teams, credits kills/assists
## and respawns planes according to the mode's rules.

signal plane_killed(victim: Jet, killer: Jet, assist: Jet)

const HIT_RADIUS := 11.0

var planes: Array[Jet] = []
var player: Jet
var game: Node
var chunks: ChunkManager
var combat: Combat
var fx: Fx
var enemies: Node
var missiles: Missiles
var clouds: Node
var cam: Camera3D
var rng := RandomNumberGenerator.new()
## seconds until a dead plane of team t respawns (-1 = never)
var respawn_delay := [12.0, -1.0]
## Callable(team) -> [pos, yaw]
var spawn_point: Callable
## extra non-plane targets per team: Callable(team) -> Array of objects (pos/active)
var extra_targets: Callable
var bound_half := 0.0 # battle area half size (0 = unlimited)
var plane_cfg := {}


func _ready() -> void:
	rng.randomize()


func add_player(j: Jet) -> void:
	player = j
	j.is_player = true
	planes.append(j)
	j.died.connect(_on_died.bind(j))


func spawn_bot(team: int, skill: float, role: int, pos: Vector3, yaw: float, model: String = "") -> Jet:
	var j := Jet.new()
	j.is_player = false
	j.team = team
	j.pilot = BotNames.make(rng)
	for k in plane_cfg:
		j.cfg[k] = plane_cfg[k]
	# a plane of the aircraft tree matching role and skill; red team flies
	# the aggressor scheme, blue the factory scheme
	var pi := pick_plane(role, skill)
	var lv := {}
	for k in Planes.UPGRADES:
		lv[k] = clampi(int(skill * 5.0 + rng.randf_range(-1.0, 1.0)), 0, Planes.MAX_LEVEL)
	j.apply_plane(pi, lv, Planes.RED_SKIN if team == 1 else 0)
	if model != "":
		j.sheet_name = model
	j.chunks = chunks
	j.combat = combat
	j.fx = fx
	j.cam = cam
	j.brain = BotBrain.new(j, self, skill, role, rng.randi())
	j.brain._home = pos
	j.name = "Bot_" + j.pilot.validate_node_name()
	add_child(j)
	j.reset(pos, yaw)
	j.position = pos
	j.invuln = 1.0
	planes.append(j)
	j.died.connect(_on_died.bind(j))
	return j


## Plane for a bot: branch from its role, tier from its skill.
func pick_plane(role: int, skill: float) -> int:
	var branch := Planes.LIGHT
	match role:
		BotBrain.ATTACKER:
			branch = Planes.ATTACK
		BotBrain.INTERCEPTOR:
			branch = Planes.HEAVY
		BotBrain.ESCORT:
			branch = Planes.HEAVY if rng.randf() < 0.6 else Planes.LIGHT
		_:
			branch = Planes.LIGHT if rng.randf() < 0.6 else Planes.HEAVY
	var tier := clampi(1 + int(skill * 4.0 + rng.randf_range(-0.6, 0.6)), 1, 4)
	for i in Planes.LIST.size():
		if Planes.LIST[i]["branch"] == branch and int(Planes.LIST[i]["tier"]) == tier:
			return i
	return 0


## Spawn a pair (leader + wingman) that fight together.
func spawn_pair(team: int, skill: float, role: int, pos: Vector3, yaw: float) -> Array[Jet]:
	var a := spawn_bot(team, skill, role, pos, yaw)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var b := spawn_bot(team, clampf(skill + rng.randf_range(-0.15, 0.1), 0.0, 1.0), role, pos + right * 60.0 + Vector3(0, 10, 0), yaw)
	a.brain.partner = b
	b.brain.partner = a
	b.brain.leader = false
	return [a, b]


## Take a plane out of the battle. Bots are only hidden here (other objects
## may still reference them); they are freed by clear_bots() between matches.
var _graveyard: Array[Jet] = []


func remove(j: Jet) -> void:
	planes.erase(j)
	if is_instance_valid(j) and j != player:
		j.alive = false
		j.visible = false
		j.respawn_t = -1.0
		_graveyard.append(j)


func clear_bots() -> void:
	for j in planes.duplicate():
		if j != player:
			remove(j)
	for j in _graveyard:
		if is_instance_valid(j):
			j.queue_free()
	_graveyard.clear()
	BotNames.reset()


func step(delta: float) -> void:
	for j in planes.duplicate():
		if j == player:
			continue
		if not j.alive:
			if j.respawn_t > 0.0:
				j.respawn_t -= delta
				if j.respawn_t <= 0.0:
					_respawn(j)
			continue
		j.brain.think(delta)
		j.step(delta)


func _respawn(j: Jet) -> void:
	var sp: Array = spawn_point.call(j.team) if spawn_point.is_valid() else [Vector3(0, 220, 0), 0.0]
	j.reset(sp[0], sp[1])
	j.position = sp[0]
	j.brain.state = BotBrain.S_PATROL
	j.brain._home = sp[0]


func _on_died(j: Jet) -> void:
	j.deaths += 1
	var killer: Jet = null
	if is_instance_valid(j.last_hit_by) and j.last_hit_by is Jet:
		killer = j.last_hit_by
	var assist: Jet = null
	var now := Time.get_ticks_msec()
	for a in j.hits:
		if is_instance_valid(a) and a != killer and a is Jet and now - int(j.hits[a]) < 8000 and a.team != j.team:
			assist = a
	if killer != null and is_instance_valid(killer) and killer.team != j.team:
		killer.kills += 1
	else:
		killer = null
	if assist != null:
		assist.assists += 1
	plane_killed.emit(j, killer, assist)
	if j != player:
		var d: float = respawn_delay[j.team]
		if d >= 0.0:
			j.respawn_t = d
		else:
			call_deferred("remove", j)


# ------------------------------------------------------------------ queries

func enemy_planes(team: int) -> Array[Jet]:
	var out: Array[Jet] = []
	for j in planes:
		if j.alive and j.team != team:
			out.append(j)
	return out


func team_planes(team: int) -> Array[Jet]:
	var out: Array[Jet] = []
	for j in planes:
		if j.team == team:
			out.append(j)
	return out


func count_alive(team: int) -> int:
	var c := 0
	for j in planes:
		if j.alive and j.team == team:
			c += 1
	return c


## Everything a bot of `team` may attack: enemy planes, (for the player's
## team) the city-defence enemy units, plus mode-specific ground targets.
func enemy_targets(team: int) -> Array:
	var out: Array = []
	for j in planes:
		if j.alive and j.team != team:
			out.append(j)
	if team == 0 and enemies != null:
		for e in enemies.pool:
			if e.active:
				out.append(e)
	if extra_targets.is_valid():
		out.append_array(extra_targets.call(team))
	return out


func hidden(p: Vector3) -> bool:
	return clouds != null and clouds.inside(p)


## Bullet / missile hit test against planes NOT on `team`.
func hit_test(p: Vector3, team: int, dmg: float, src: Object, radius: float = HIT_RADIUS) -> bool:
	for j in planes:
		if not j.alive or j.team == team or j.invuln > 0.0:
			continue
		var d := j.position - p
		if absf(d.y) < radius and absf(d.x) < radius and absf(d.z) < radius and Vector2(d.x, d.z).length() < radius:
			j.last_hit_missile = false
			j.damage(dmg, src)
			return true
	return false


## Area damage (flak) to planes of `victim_team`.
func splash(p: Vector3, r: float, victim_team: int, dmg: float, src: Object) -> void:
	for j in planes:
		if j.alive and j.team == victim_team and j.invuln <= 0.0 and j.position.distance_to(p) < r:
			j.damage(dmg, src)


## Aim assist: nearest enemy plane in a cone. INF if none.
func aim_target(p: Vector3, flat_dir: Vector3, team: int, cone: float, max_range: float) -> Vector3:
	var best := Vector3.INF
	var best_d := max_range
	var cc := cos(cone)
	for j in planes:
		if not j.alive or j.team == team:
			continue
		var v := Vector3(j.position.x - p.x, 0.0, j.position.z - p.z)
		var d := v.length()
		if d < best_d and d > 1.0 and v.dot(flat_dir) / d > cc:
			best_d = d
			best = j.position
	return best
