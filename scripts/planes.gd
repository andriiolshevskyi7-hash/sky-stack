class_name Planes
## The aircraft tree: 3 branches x 4 tiers of ORIGINAL planes (invented names,
## no real-world designs), their stats, prices, rank requirements, upgrade
## costs and skins. The sprite stacks are built by PlaneArt.

enum { LIGHT, HEAVY, ATTACK }
const BRANCH_NAMES := ["LIGHT FIGHTERS", "HEAVY FIGHTERS", "ATTACKERS"]
const UPGRADES := ["engine", "armor", "guns", "missiles", "flares"]
const UPGRADE_NAMES := ["ENGINE", "ARMOR", "GUNS", "MISSILES", "FLARES"]
const MAX_LEVEL := 5

## The look of every plane (fuselage, wings, tails, intakes, stores...) is
## described in PlaneArt.ART under the same id.
const LIST := [
	{"id": "wren", "name": "WREN", "code": "LF-1", "branch": LIGHT, "tier": 1, "price": 0, "rank": 0,
		"speed": 0.95, "turn": 1.12, "hp": 0.85, "gun": 0.9, "missiles": 4, "flares": 2},
	{"id": "vireo", "name": "VIREO", "code": "LF-2", "branch": LIGHT, "tier": 2, "price": 1500, "rank": 2,
		"speed": 1.02, "turn": 1.18, "hp": 0.9, "gun": 0.95, "missiles": 4, "flares": 3},
	{"id": "skylark", "name": "SKYLARK", "code": "LF-3", "branch": LIGHT, "tier": 3, "price": 4500, "rank": 5,
		"speed": 1.08, "turn": 1.26, "hp": 0.95, "gun": 1.0, "missiles": 5, "flares": 3},
	{"id": "zephyr", "name": "ZEPHYR", "code": "LF-4", "branch": LIGHT, "tier": 4, "price": 11000, "rank": 9,
		"speed": 1.14, "turn": 1.34, "hp": 1.0, "gun": 1.05, "missiles": 6, "flares": 4},
	{"id": "bastion", "name": "BASTION", "code": "HF-1", "branch": HEAVY, "tier": 1, "price": 600, "rank": 1,
		"speed": 1.04, "turn": 0.98, "hp": 1.15, "gun": 1.0, "missiles": 6, "flares": 3},
	{"id": "rampart", "name": "RAMPART", "code": "HF-2", "branch": HEAVY, "tier": 2, "price": 2400, "rank": 3,
		"speed": 1.1, "turn": 1.0, "hp": 1.2, "gun": 1.05, "missiles": 7, "flares": 3},
	{"id": "warden", "name": "WARDEN", "code": "HF-3", "branch": HEAVY, "tier": 3, "price": 6500, "rank": 6,
		"speed": 1.18, "turn": 1.02, "hp": 1.25, "gun": 1.1, "missiles": 8, "flares": 4},
	{"id": "monolith", "name": "MONOLITH", "code": "HF-4", "branch": HEAVY, "tier": 4, "price": 14000, "rank": 10,
		"speed": 1.22, "turn": 1.08, "hp": 1.35, "gun": 1.15, "missiles": 9, "flares": 5},
	{"id": "mattock", "name": "MATTOCK", "code": "AT-1", "branch": ATTACK, "tier": 1, "price": 600, "rank": 1,
		"speed": 0.88, "turn": 1.0, "hp": 1.35, "gun": 1.25, "missiles": 4, "flares": 3},
	{"id": "halberd", "name": "HALBERD", "code": "AT-2", "branch": ATTACK, "tier": 2, "price": 2400, "rank": 3,
		"speed": 0.94, "turn": 1.04, "hp": 1.45, "gun": 1.3, "missiles": 5, "flares": 3},
	{"id": "anvil", "name": "ANVIL", "code": "AT-3", "branch": ATTACK, "tier": 3, "price": 6500, "rank": 6,
		"speed": 0.98, "turn": 1.06, "hp": 1.6, "gun": 1.4, "missiles": 6, "flares": 4},
	{"id": "maul", "name": "MAUL", "code": "AT-4", "branch": ATTACK, "tier": 4, "price": 14000, "rank": 10,
		"speed": 1.04, "turn": 1.1, "hp": 1.75, "gun": 1.5, "missiles": 7, "flares": 5},
]

## Skins: colour presets + camo patterns. Skin 7 (AGGRESSOR) is the red team.
## body, dark, light, accent, canopy, camo colour, camo pattern (0 none,
## 1 blotches, 2 stripes), unlock: [kind, value] kind = "free" | "rank" |
## "coins" | "achievement".
const SKINS := [
	{"name": "FACTORY", "body": "", "dark": "", "light": "", "acc": "f0580e", "canopy": "1e8ca0", "camo": "", "pattern": 0, "unlock": ["free", 0]},
	{"name": "ARCTIC", "body": "d8dee6", "dark": "9aa4b0", "light": "f2f5f8", "acc": "2a7fd4", "canopy": "24506a", "camo": "b8c2ce", "pattern": 1, "unlock": ["rank", 2]},
	{"name": "DESERT CAMO", "body": "c9a46a", "dark": "7d6644", "light": "dcc08c", "acc": "6b3a1e", "canopy": "2a5a6a", "camo": "8a6a40", "pattern": 1, "unlock": ["coins", 800]},
	{"name": "JUNGLE CAMO", "body": "5b6b3c", "dark": "3a4428", "light": "7b8a52", "acc": "c8b040", "canopy": "1e6a70", "camo": "3b3a26", "pattern": 1, "unlock": ["coins", 800]},
	{"name": "MIDNIGHT", "body": "2a2a34", "dark": "141418", "light": "3e3e4c", "acc": "d02828", "canopy": "6a1414", "camo": "", "pattern": 0, "unlock": ["rank", 5]},
	{"name": "TIGER", "body": "e8902a", "dark": "a05a14", "light": "f5b25a", "acc": "1c1c1c", "canopy": "1e6a80", "camo": "1c1c1c", "pattern": 2, "unlock": ["achievement", "aces"]},
	{"name": "ACE GOLD", "body": "d4aa3a", "dark": "8a6a1c", "light": "f0d070", "acc": "1a1a1a", "canopy": "3a2a10", "camo": "", "pattern": 0, "unlock": ["rank", 15]},
	{"name": "AGGRESSOR", "body": "8a3a34", "dark": "4e2220", "light": "b0504a", "acc": "f0e0d0", "canopy": "d08a20", "camo": "", "pattern": 0, "unlock": ["none", 0]},
]
const RED_SKIN := 7
const FACTORY_BODY := [["6d7a8c", "4a5462", "8e9aac"], ["545969", "3a3e4b", "6d7386"], ["6b7050", "474a34", "8a9068"]]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return 0


static func sheet_of(i: int) -> String:
	return "plane_" + LIST[i]["id"]


static func upgrade_cost(plane: int, level: int) -> int:
	# cost of going from `level` to level + 1
	return int((120 + 90 * level) * (1.0 + 0.6 * (int(LIST[plane]["tier"]) - 1)))


## Final stats (dictionary used by Jet) for a plane at given upgrade levels.
## base: the settings dictionary (speed, turn ...).
static func stats(plane: int, lv: Dictionary) -> Dictionary:
	var p: Dictionary = LIST[plane]
	return {
		"speed_mult": float(p["speed"]) * (1.0 + 0.03 * int(lv.get("engine", 0))),
		"turn_mult": float(p["turn"]) * (1.0 + 0.015 * int(lv.get("engine", 0))),
		"hp": 100.0 * float(p["hp"]) * (1.0 + 0.08 * int(lv.get("armor", 0))),
		"gun": float(p["gun"]) * (1.0 + 0.07 * int(lv.get("guns", 0))),
		"missiles": int(p["missiles"]) + (int(lv.get("missiles", 0)) + 1) / 2,
		"lock_time": 0.8 * (1.0 - 0.06 * int(lv.get("missiles", 0))),
		"flares": int(p["flares"]) + int(lv.get("flares", 0)),
	}


## Flight-model class traits (light / heavy / attack):
##  vs     stall speed at 1 G (m/s)          vmil  top level speed, military
##  vab    top level speed, afterburner      tw    thrust/weight at military
##  max_g  structural / pilot G limit         roll  max roll rate (rad/s)
##  ind    induced-drag factor (k * CLmax): how much speed a hard turn bleeds
##  agile  control response (1/s): how fast roll / G build up (inertia)
const CLASS_PHYS := [
	{"vs": 46.0, "vmil": 150.0, "vab": 198.0, "tw": 0.62, "max_g": 9.0, "roll": 4.4, "ind": 0.10, "agile": 6.0},
	{"vs": 56.0, "vmil": 172.0, "vab": 238.0, "tw": 0.58, "max_g": 7.5, "roll": 2.9, "ind": 0.13, "agile": 3.8},
	{"vs": 42.0, "vmil": 136.0, "vab": 168.0, "tw": 0.50, "max_g": 6.5, "roll": 2.3, "ind": 0.11, "agile": 3.0},
]


## Physical flight parameters for a plane at given upgrade levels. Speed /
## turn multipliers of the plane and the engine upgrade shape them; speeds
## are scaled by `speed_scale` (debug tuning, 1 = as designed).
static func physics(plane: int, lv: Dictionary, speed_scale: float = 1.0) -> Dictionary:
	var p: Dictionary = LIST[plane]
	var c: Dictionary = CLASS_PHYS[int(p["branch"])]
	var eng := int(lv.get("engine", 0))
	var sm: float = float(p["speed"]) / float([0.95, 1.04, 0.88][int(p["branch"])]) # relative to tier 1 of the class
	var tm: float = float(p["turn"]) / float([1.12, 0.98, 1.0][int(p["branch"])])
	return {
		"vs": c["vs"] / sqrt(tm) * speed_scale,
		"vmil": c["vmil"] * sm * (1.0 + 0.02 * eng) * speed_scale,
		"vab": c["vab"] * sm * (1.0 + 0.025 * eng) * speed_scale,
		"tw": c["tw"] * (1.0 + 0.04 * eng),
		"max_g": c["max_g"] * (0.94 + 0.06 * tm),
		"roll": c["roll"] * tm,
		"ind": c["ind"],
		"agile": c["agile"] * tm,
	}


## 0..1 bars for the hangar.
static func bars(plane: int, lv: Dictionary) -> Array:
	var st := stats(plane, lv)
	return [
		clampf((st["speed_mult"] - 0.8) / 0.6, 0.0, 1.0),
		clampf((st["turn_mult"] - 0.9) / 0.55, 0.0, 1.0),
		clampf((st["hp"] - 70.0) / 170.0, 0.0, 1.0),
		clampf((st["gun"] * 0.6 + st["missiles"] / 12.0 - 0.6) / 1.0, 0.0, 1.0),
	]
