class_name Missions
## Definitions for daily missions, weekly challenges and achievements.
## Progress lives in Profile (counters + per-day / per-week state); this file
## only describes WHAT to count and the rewards.
##
## Events (Profile.track(event, amount)):
##   kill, gun_kill, missile_kill, ace_kill, kill_light/heavy/attack,
##   assist, structure, aa_kill, carrier_kill, dodge, flare_save, loop,
##   low_seconds, battle, win, win_dogfight, win_base, win_duel, win_city,
##   mvp, map_tropical/desert/snow/night/ocean, streak (max, not summed)

## Daily pool: [id, text (%d = goal), event, goal, coins, xp]
const DAILY := [
	["aa", "Destroy %d AA guns", "aa_kill", 5, 250, 150],
	["df_wins", "Win %d Team Dogfights", "win_dogfight", 2, 300, 200],
	["missile", "Get %d missile kills", "missile_kill", 3, 250, 150],
	["low", "Fly %d min below 150 m", "low_seconds", 120, 200, 120],
	["gun", "Shoot down %d planes with the cannon", "gun_kill", 6, 250, 150],
	["assist", "Get %d assists", "assist", 4, 200, 120],
	["dodge", "Evade %d missiles by maneuvering", "dodge", 3, 250, 150],
	["flare", "Decoy %d missiles with flares", "flare_save", 3, 250, 150],
	["base_win", "Win %d Base Strike", "win_base", 1, 300, 200],
	["battles", "Play %d battles", "battle", 3, 200, 150],
	["ground", "Destroy %d ground targets", "structure", 8, 250, 150],
	["duel", "Win %d Duel", "win_duel", 1, 250, 150],
	["kills", "Shoot down %d planes", "kill", 10, 300, 200],
	["desert", "Play %d battles on Desert Canyon", "map_desert", 2, 200, 120],
	["snow", "Play %d battles on Snow Mountains", "map_snow", 2, 200, 120],
	["ocean", "Play %d battles on Ocean Carrier", "map_ocean", 2, 200, 120],
]

## Weekly pool: bigger goals, bigger rewards.
const WEEKLY := [
	["w_wins", "Win %d battles", "win", 10, 2000, 1200],
	["w_carriers", "Destroy %d carriers", "carrier_kill", 2, 1800, 1000],
	["w_kills", "Shoot down %d planes", "kill", 60, 2000, 1200],
	["w_mvp", "Be MVP %d times", "mvp", 3, 1500, 900],
	["w_structures", "Destroy %d ground targets", "structure", 40, 1800, 1000],
	["w_missiles", "Get %d missile kills", "missile_kill", 20, 1800, 1000],
	["w_battles", "Play %d battles", "battle", 20, 1500, 900],
]

## Achievements: [id, name, text (%d = goal), event, [bronze, silver, gold], unlock]
## unlock: "" or a skin index unlocked at bronze.
const ACHIEVEMENTS := [
	["kills", "SKY HUNTER", "Shoot down %d planes", "kill", [10, 100, 500]],
	["wins", "VICTOR", "Win %d battles", "win", [5, 25, 100]],
	["dodges", "MATADOR", "Evade %d missiles by maneuvering", "dodge", [5, 25, 100]],
	["flares", "DECOY", "Save yourself with flares %d times", "flare_save", [5, 25, 100]],
	["loops", "AEROBAT", "Fly %d loops", "loop", [3, 20, 100]],
	["structures", "DEMOLISHER", "Destroy %d ground targets", "structure", [10, 50, 200]],
	["carriers", "SINK THE FLEET", "Destroy %d carriers", "carrier_kill", [1, 5, 20]],
	["missiles", "LOCK AND LAUNCH", "Get %d missile kills", "missile_kill", [10, 50, 200]],
	["guns", "GUNSLINGER", "Get %d cannon kills", "gun_kill", [25, 150, 500]],
	["aces", "ACE HUNTER", "Shoot down %d ace pilots", "ace_kill", [1, 10, 50]],
	["mvp", "MOST VALUABLE", "Be MVP %d times", "mvp", [1, 10, 50]],
	["battles", "VETERAN", "Play %d battles", "battle", [10, 50, 250]],
	["low", "NAP OF THE EARTH", "Fly %d min below 150 m", "low_seconds", [300, 1800, 7200]],
	["streak", "ON A ROLL", "Get %d kills in one life", "streak", [3, 5, 10]],
	["duels", "DUELLIST", "Win %d duels", "win_duel", [1, 10, 50]],
	["bases", "BASE BREAKER", "Win %d Base Strikes", "win_base", [1, 10, 50]],
	["dogfights", "DOGFIGHTER", "Win %d Team Dogfights", "win_dogfight", [1, 10, 50]],
	["city", "GUARDIAN", "Survive %d city waves", "wave", [5, 25, 100]],
	["m_tropical", "ISLAND HOPPER", "Play %d battles on Tropical Islands", "map_tropical", [1, 10, 30]],
	["m_desert", "DUST DEVIL", "Play %d battles on Desert Canyon", "map_desert", [1, 10, 30]],
	["m_snow", "ICE COLD", "Play %d battles on Snow Mountains", "map_snow", [1, 10, 30]],
	["m_night", "NIGHT OWL", "Play %d battles on Night City", "map_night", [1, 10, 30]],
	["m_ocean", "BLUE WATER", "Play %d battles on Ocean Carrier", "map_ocean", [1, 10, 30]],
	["b_light", "LIGHTWEIGHT", "Shoot down %d planes in light fighters", "kill_light", [10, 50, 200]],
	["b_heavy", "HEAVYWEIGHT", "Shoot down %d planes in heavy fighters", "kill_heavy", [10, 50, 200]],
	["b_attack", "MUD MOVER", "Shoot down %d planes in attackers", "kill_attack", [10, 50, 200]],
]
const TIER_NAMES := ["BRONZE", "SILVER", "GOLD"]
const TIER_COLORS := [Color("c98a4b"), Color("c9d2dc"), Color("f2c84b")]
const TIER_COINS := [150, 400, 1000]
const TIER_XP := [100, 250, 600]
## Achievement whose bronze tier unlocks the TIGER skin.
const TIGER_ACHIEVEMENT := "aces"
const TIGER_SKIN := 5
## Events that store the best value instead of a sum.
const MAX_EVENTS := ["streak"]


static func daily_def(id: String) -> Array:
	for d in DAILY:
		if d[0] == id:
			return d
	return []


static func weekly_def(id: String) -> Array:
	for d in WEEKLY:
		if d[0] == id:
			return d
	return []


static func ach_def(id: String) -> Array:
	for d in ACHIEVEMENTS:
		if d[0] == id:
			return d
	return []


## Goal shown to the player (low_seconds counts seconds, shown in minutes).
static func shown(event: String, v: float) -> int:
	return int(v / 60.0) if event == "low_seconds" else int(v)


## Local calendar keys: refresh at local midnight / on Monday.
static func day_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func week_key() -> String:
	var unix := Time.get_unix_time_from_datetime_dict(Time.get_date_dict_from_system())
	var days := int(unix / 86400)
	# 1970-01-01 was a Thursday: shift so weeks start on Monday
	return "W%d" % int((days + 3) / 7)


## Deterministic pick of n distinct ids from a pool for a key (day / week).
static func pick(pool: Array, key: String, n: int, exclude: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var ids: Array = []
	for d in pool:
		if not exclude.has(d[0]):
			ids.append(d[0])
	var out: Array = []
	while out.size() < n and not ids.is_empty():
		var i := rng.randi() % ids.size()
		out.append(ids[i])
		ids.remove_at(i)
	return out
