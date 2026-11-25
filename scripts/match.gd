class_name Match
extends Node
## Match rules for every mode:
##  CITY      - city defence waves (endless, game over when you or the city fall)
##  DOGFIGHT  - team deathmatch: first to N kills or most kills at the timer
##  BASE      - destroy the enemy base (AA, radar, bunkers, hangars, airfield)
##  DUEL      - 1v1 against a bot of chosen skill, first to 5 kills
## Holds the lobby roster, timer, team score, respawn rules and builds the
## results (per-pilot stats, MVP, XP and coins).

enum { CITY, DOGFIGHT, BASE, DUEL }
const MODE_NAMES := ["CITY DEFENCE", "TEAM DOGFIGHT", "BASE STRIKE", "DUEL"]
const MODE_KEYS := ["city", "dogfight", "base", "duel"]
const MODE_INFO := [
	"Defend the city from endless waves.",
	"First team to the kill target wins.",
	"Destroy the enemy base, defend yours.",
	"One on one against a bot.",
]
const SPAWN_DIST := 2400.0

var mode := CITY
var team_size := 4
var duel_skill := 0.5
var skill_center := 0.4
var duration := 240.0
var time_left := 0.0
var elapsed := 0.0
var kill_target := 16
var score := [0, 0]
var running := false
var countdown := 0.0
var winner := -1
var roster := [[], []] # per team: [{name, skill, role, player}]
var rng := RandomNumberGenerator.new()
var game: Node


func is_team_mode() -> bool:
	return mode != CITY


## Respawn delay (seconds) for team t in this mode (-1 = no respawn).
func respawn_delay(t: int) -> float:
	match mode:
		DOGFIGHT:
			return 5.0
		BASE:
			return 8.0
		DUEL:
			return 3.0
	return 12.0 if t == 0 else -1.0


static func skill_label(sk: float) -> String:
	if sk < 0.3:
		return "ROOKIE"
	if sk < 0.55:
		return "REGULAR"
	if sk < 0.8:
		return "VETERAN"
	return "ACE"


## Build the lobby roster for a mode.
func configure(p_mode: int, p_team_size: int, p_skill_center: float, p_duel_skill: float = 0.5) -> void:
	rng.randomize()
	mode = p_mode
	team_size = clampi(p_team_size, 2, 8)
	skill_center = p_skill_center
	duel_skill = p_duel_skill
	BotNames.reset()
	roster = [[], []]
	if mode == CITY:
		return
	var n := 1 if mode == DUEL else team_size
	for t in 2:
		for i in n:
			if t == 0 and i == 0:
				roster[0].append({"name": Profile.data.get("name", "YOU"), "skill": 1.0, "role": BotBrain.DOGFIGHTER, "player": true})
				continue
			var sk := duel_skill if mode == DUEL else clampf(skill_center + rng.randf_range(-0.18, 0.18), 0.05, 0.98)
			roster[t].append({"name": BotNames.make(rng), "skill": sk, "role": _role_for(i, n), "player": false})
	match mode:
		DOGFIGHT:
			duration = 240.0
			kill_target = team_size * 4
		BASE:
			duration = 300.0
			kill_target = 999
		DUEL:
			duration = 180.0
			kill_target = 5


func _role_for(i: int, n: int) -> int:
	if mode == BASE:
		var roles := [BotBrain.ATTACKER, BotBrain.ESCORT, BotBrain.INTERCEPTOR, BotBrain.DOGFIGHTER, BotBrain.ATTACKER, BotBrain.DOGFIGHTER, BotBrain.INTERCEPTOR, BotBrain.ESCORT]
		return roles[i % roles.size()]
	if mode == DOGFIGHT and i == n - 1:
		return BotBrain.INTERCEPTOR
	return BotBrain.DOGFIGHTER


func spawn_point(team: int) -> Array:
	var z := SPAWN_DIST if team == 0 else -SPAWN_DIST
	var yaw := 0.0 if team == 0 else PI
	var base: Vector3 = Vector3(0, 0, z)
	if mode == BASE and game != null:
		base = game.bases.centers[team]
	var alt: float = game.world_map.spawn_alt() if game != null else 360.0
	var p := Vector3(base.x + rng.randf_range(-250, 250), alt + rng.randf_range(-60.0, 60.0), base.z + rng.randf_range(-150, 150))
	return [p, yaw]


func start() -> void:
	score = [0, 0]
	winner = -1
	elapsed = 0.0
	time_left = duration
	countdown = 3.0 if mode != CITY else 0.0
	running = true


func update(delta: float) -> void:
	if not running:
		return
	if countdown > 0.0:
		var before := ceili(countdown)
		countdown -= delta
		if ceili(countdown) != before and countdown > 0.0:
			Sfx.play("beep", -6.0, 1.0)
		if countdown <= 0.0:
			Sfx.play("tone", -6.0)
			game.show_banner("FIGHT!", MODE_INFO[mode], 1.5)
		return
	elapsed += delta
	if mode == CITY:
		return
	time_left -= delta
	if mode == BASE:
		score = [int(round((1.0 - game.bases.health(1)) * 100.0)), int(round((1.0 - game.bases.health(0)) * 100.0))]
		if game.bases.alive_targets(1).is_empty():
			finish(0)
		elif game.bases.alive_targets(0).is_empty():
			finish(1)
	if score[0] >= kill_target and mode != BASE:
		finish(0)
	elif score[1] >= kill_target and mode != BASE:
		finish(1)
	elif time_left <= 0.0:
		finish(0 if score[0] > score[1] else (1 if score[1] > score[0] else -1))


func on_kill(victim: Jet, killer: Jet) -> void:
	if not running or mode == CITY:
		return
	if killer != null and killer.team != victim.team:
		if mode != BASE:
			score[killer.team] += 1
	elif victim != null and mode != BASE:
		score[1 - victim.team] += 1 # crashes count for the other team


func finish(w: int) -> void:
	if not running:
		return
	running = false
	winner = w
	game.on_match_finished()


static func plane_score(j: Jet) -> int:
	return j.kills * 100 + j.assists * 50 + int(j.damage_dealt * 2.0) + int(j.base_damage * 3.0) + j.ground_kills * 60


## Results for the results screen + profile.
func results(planes: Array) -> Dictionary:
	var rows: Array = []
	var mvp: Jet = null
	var best := -1
	for j in planes:
		var sc := plane_score(j)
		rows.append({"name": j.pilot, "team": j.team, "k": j.kills, "a": j.assists, "d": j.deaths, "dmg": int(j.damage_dealt), "base": int(j.base_damage), "score": sc, "player": j.is_player})
		var bonus := 1 if j.team == winner else 0
		if sc > 0 and sc + bonus * 50 > best:
			best = sc + bonus * 50
			mvp = j
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var me: Jet = game.jet
	var won := winner == me.team
	var my_score := plane_score(me)
	var xp := 100 + my_score / 4 + (200 if won else (60 if winner == -1 else 0)) + (100 if mvp == me else 0)
	var coins := int(xp * 0.6)
	return {
		"rows": rows, "mvp": mvp.pilot if mvp != null else "", "won": won, "draw": winner == -1, "winner": winner,
		"score": score.duplicate(), "xp": xp, "coins": coins, "my_score": my_score, "me_mvp": mvp == me,
	}
