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
		# hangar
		"plane": "wren",
		"owned": ["wren"],
		"upgrades": {}, # plane id -> {engine, armor, guns, missiles, flares}
		"skins": [0], # unlocked skin indices
		"skin_of": {}, # plane id -> equipped skin
		"tail": 7, # tail number 1..99
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


# ------------------------------------------------------------------ ranks

## Bronze III .. Diamond I (15 levels) and Ace on top.
const RANKS := ["BRONZE III", "BRONZE II", "BRONZE I", "SILVER III", "SILVER II", "SILVER I",
	"GOLD III", "GOLD II", "GOLD I", "PLATINUM III", "PLATINUM II", "PLATINUM I",
	"DIAMOND III", "DIAMOND II", "DIAMOND I", "ACE"]
const RANK_COLORS := [Color("c98a4b"), Color("c9d2dc"), Color("f2c84b"), Color("7fe0d6"), Color("8fb8ff"), Color("ff6a4a")]


## XP needed to go from rank i to i + 1.
static func rank_step(i: int) -> int:
	return 800 + 350 * i


## [rank index, xp into this rank, xp needed for the next] for an XP total.
static func rank_of(total_xp: int) -> Array:
	var i := 0
	var left := total_xp
	while i < RANKS.size() - 1 and left >= rank_step(i):
		left -= rank_step(i)
		i += 1
	return [i, left, rank_step(i) if i < RANKS.size() - 1 else 0]


func rank() -> int:
	return rank_of(xp())[0]


## Fractional rank (index + progress) for progress bars.
static func rank_float(total_xp: int) -> float:
	var r := rank_of(total_xp)
	return float(r[0]) + (float(r[1]) / float(r[2]) if r[2] > 0 else 0.0)


static func rank_color(i: int) -> Color:
	return RANK_COLORS[mini(i / 3, RANK_COLORS.size() - 1)]


# ------------------------------------------------------------------ hangar

func plane_index() -> int:
	return Planes.index_of(str(data["plane"]))


func owns(plane: int) -> bool:
	return data["owned"].has(Planes.LIST[plane]["id"])


func levels(plane: int) -> Dictionary:
	var id: String = Planes.LIST[plane]["id"]
	var lv: Dictionary = data["upgrades"].get(id, {})
	var out := {}
	for k in Planes.UPGRADES:
		out[k] = int(lv.get(k, 0))
	return out


func skin_of(plane: int) -> int:
	return int(data["skin_of"].get(Planes.LIST[plane]["id"], 0))


func has_skin(i: int) -> bool:
	return data["skins"].has(i) or data["skins"].has(float(i))


## Can this plane be bought now? "" if yes, else the reason (for the UI).
func plane_lock_reason(plane: int) -> String:
	var p: Dictionary = Planes.LIST[plane]
	if rank() < int(p["rank"]):
		return tr("RANK %s") % tr(RANKS[int(p["rank"])])
	# the previous tier of the same branch must be owned
	if int(p["tier"]) > 1:
		for q in Planes.LIST.size():
			var o: Dictionary = Planes.LIST[q]
			if o["branch"] == p["branch"] and int(o["tier"]) == int(p["tier"]) - 1 and not owns(q):
				return tr("NEEDS %s") % o["name"]
	return ""


func buy_plane(plane: int) -> bool:
	if owns(plane) or plane_lock_reason(plane) != "":
		return false
	if not spend_coins(int(Planes.LIST[plane]["price"])):
		return false
	data["owned"].append(Planes.LIST[plane]["id"])
	save()
	return true


func select_plane(plane: int) -> void:
	if owns(plane):
		data["plane"] = Planes.LIST[plane]["id"]
		save()


func upgrade(plane: int, key: String) -> bool:
	if not owns(plane):
		return false
	var lv := levels(plane)
	if lv[key] >= Planes.MAX_LEVEL:
		return false
	if not spend_coins(Planes.upgrade_cost(plane, lv[key])):
		return false
	var id: String = Planes.LIST[plane]["id"]
	if not data["upgrades"].has(id):
		data["upgrades"][id] = {}
	data["upgrades"][id][key] = lv[key] + 1
	save()
	return true


## Skin unlock state: "" = unlocked / can be bought, else the reason.
func skin_lock_reason(i: int) -> String:
	if has_skin(i):
		return ""
	var u: Array = Planes.SKINS[i]["unlock"]
	match u[0]:
		"rank":
			if rank() < int(u[1]):
				return tr("RANK %s") % tr(RANKS[int(u[1])])
			return ""
		"kills":
			if stat("kills") < float(u[1]):
				return tr("%d KILLS") % int(u[1])
			return ""
		"coins":
			return ""
	return "LOCKED"


## Unlock (rank / kills reached are free, coin skins are bought).
func unlock_skin(i: int) -> bool:
	if has_skin(i):
		return true
	if skin_lock_reason(i) != "":
		return false
	var u: Array = Planes.SKINS[i]["unlock"]
	if u[0] == "coins" and not spend_coins(int(u[1])):
		return false
	data["skins"].append(i)
	save()
	return true


func equip_skin(plane: int, i: int) -> void:
	if has_skin(i):
		data["skin_of"][Planes.LIST[plane]["id"]] = i
		save()


func tail() -> int:
	return int(data.get("tail", 7))


func set_tail(n: int) -> void:
	data["tail"] = wrapi(n, 1, 100)
	save()


func reset_all() -> void:
	data = _defaults()
	save()
