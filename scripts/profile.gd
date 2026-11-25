extends Node
## Autoload "Profile": the player's persistent progression data (XP, coins,
## stats, owned planes, upgrades, skins, missions...).
##
## Data layer: all reads/writes go through `storage` (an object with
## load_data() -> Dictionary and save_data(Dictionary)). LocalStorage writes
## JSON to user://; an online backend can later implement the same two
## methods (e.g. HTTP + local cache) without touching game code.

signal changed

class LocalStorage:
	const PATH := "user://profile.json"

	func load_data() -> Dictionary:
		if not FileAccess.file_exists(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			return {}
		var d = JSON.parse_string(f.get_as_text())
		return d if d is Dictionary else {}

	func save_data(d: Dictionary) -> void:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(d, "\t"))

const VERSION := 1

var storage = LocalStorage.new()
var data := {}


func _ready() -> void:
	data = _defaults()
	var loaded: Dictionary = storage.load_data()
	_merge(data, loaded)
	data["version"] = VERSION


func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"name": "Pilot",
		"xp": 0,
		"coins": 500,
		"stats": {
			"battles": 0, "wins": 0, "losses": 0, "kills": 0, "deaths": 0, "assists": 0,
			"shots": 0, "hits": 0, "damage": 0.0, "base_damage": 0.0, "mvp": 0,
			"ground_kills": 0, "missile_dodges": 0, "best_score": 0, "play_time": 0.0,
		},
		"plane_battles": {},
		"modes": {},
	}


func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		if dst.has(k) and dst[k] is Dictionary and src[k] is Dictionary:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]


func save() -> void:
	storage.save_data(data)
	changed.emit()


func stat(k: String) -> float:
	return float(data["stats"].get(k, 0))


func add_stat(k: String, v: float) -> void:
	data["stats"][k] = float(data["stats"].get(k, 0)) + v


func coins() -> int:
	return int(data["coins"])


func add_coins(n: int) -> void:
	data["coins"] = int(data["coins"]) + n


func spend_coins(n: int) -> bool:
	if coins() < n:
		return false
	data["coins"] = coins() - n
	save()
	return true


func xp() -> int:
	return int(data["xp"])


## Record a finished match. r: {mode, won, kills, deaths, assists, shots,
## hits, damage, base_damage, mvp, score, plane, time, xp, coins}
func record_match(r: Dictionary) -> void:
	add_stat("battles", 1)
	add_stat("wins" if r.get("won", false) else "losses", 1)
	for k in ["kills", "deaths", "assists", "shots", "hits", "damage", "base_damage", "ground_kills", "missile_dodges"]:
		add_stat(k, float(r.get(k, 0)))
	if r.get("mvp", false):
		add_stat("mvp", 1)
	add_stat("play_time", float(r.get("time", 0)))
	data["stats"]["best_score"] = maxf(stat("best_score"), float(r.get("score", 0)))
	var plane: String = r.get("plane", "jet")
	data["plane_battles"][plane] = int(data["plane_battles"].get(plane, 0)) + 1
	var mode: String = r.get("mode", "")
	data["modes"][mode] = int(data["modes"].get(mode, 0)) + 1
	data["xp"] = xp() + int(r.get("xp", 0))
	add_coins(int(r.get("coins", 0)))
	save()


func reset_all() -> void:
	data = _defaults()
	save()
