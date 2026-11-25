class_name Planes
## The aircraft tree: 3 branches x 4 tiers of ORIGINAL planes (invented names,
## no real-world designs), their stats, prices, rank requirements, upgrade
## costs, skins, and the parametric slice painter that gives each one its own
## silhouette (wing plan, tails, canards, engines, booms, pods).

enum { LIGHT, HEAVY, ATTACK }
const BRANCH_NAMES := ["LIGHT FIGHTERS", "HEAVY FIGHTERS", "ATTACKERS"]
const UPGRADES := ["engine", "armor", "guns", "missiles", "flares"]
const UPGRADE_NAMES := ["ENGINE", "ARMOR", "GUNS", "MISSILES", "FLARES"]
const MAX_LEVEL := 5
const SHEET_W := 40
const SLICES := 11

## Shape keys: nose/tail = fuselage y range, hw = half width,
## wing/tailp/canard = [root_front, root_back, tip_x, tip_front, tip_back],
## fins: "single" | "twin" | "v" | "boom", eng: 1/2, pods: under-wing stores.
const LIST := [
	{"id": "wren", "name": "WREN", "code": "LF-1", "branch": LIGHT, "tier": 1, "price": 0, "rank": 0,
		"speed": 0.95, "turn": 1.12, "hp": 0.85, "gun": 0.9, "missiles": 4, "flares": 2,
		"nose": 6, "tail": 34, "hw": 2, "wing": [17, 23, 5, 19, 22], "tailp": [29, 33, 13, 31, 34], "canard": [], "fins": "single", "eng": 1, "pods": 0},
	{"id": "vireo", "name": "VIREO", "code": "LF-2", "branch": LIGHT, "tier": 2, "price": 1500, "rank": 2,
		"speed": 1.02, "turn": 1.18, "hp": 0.9, "gun": 0.95, "missiles": 4, "flares": 3,
		"nose": 4, "tail": 35, "hw": 2, "wing": [14, 24, 4, 23, 26], "tailp": [29, 34, 11, 32, 35], "canard": [], "fins": "single", "eng": 1, "pods": 0},
	{"id": "skylark", "name": "SKYLARK", "code": "LF-3", "branch": LIGHT, "tier": 3, "price": 4500, "rank": 5,
		"speed": 1.08, "turn": 1.26, "hp": 0.95, "gun": 1.0, "missiles": 5, "flares": 3,
		"nose": 2, "tail": 36, "hw": 3, "wing": [14, 30, 3, 28, 31], "tailp": [], "canard": [9, 13, 12, 12, 14], "fins": "single", "eng": 1, "pods": 0},
	{"id": "zephyr", "name": "ZEPHYR", "code": "LF-4", "branch": LIGHT, "tier": 4, "price": 11000, "rank": 9,
		"speed": 1.14, "turn": 1.34, "hp": 1.0, "gun": 1.05, "missiles": 6, "flares": 4,
		"nose": 1, "tail": 37, "hw": 3, "wing": [18, 26, 3, 13, 17], "tailp": [31, 36, 11, 34, 37], "canard": [9, 12, 10, 10, 13], "fins": "twin", "eng": 2, "pods": 0},
	{"id": "bastion", "name": "BASTION", "code": "HF-1", "branch": HEAVY, "tier": 1, "price": 600, "rank": 1,
		"speed": 1.04, "turn": 0.98, "hp": 1.15, "gun": 1.0, "missiles": 6, "flares": 3,
		"nose": 3, "tail": 37, "hw": 4, "wing": [15, 27, 3, 26, 29], "tailp": [31, 36, 9, 34, 37], "canard": [], "fins": "twin", "eng": 2, "pods": 0},
	{"id": "rampart", "name": "RAMPART", "code": "HF-2", "branch": HEAVY, "tier": 2, "price": 2400, "rank": 3,
		"speed": 1.1, "turn": 1.0, "hp": 1.2, "gun": 1.05, "missiles": 7, "flares": 3,
		"nose": 1, "tail": 38, "hw": 4, "wing": [13, 25, 5, 27, 29], "tailp": [31, 37, 8, 35, 38], "canard": [], "fins": "twin", "eng": 2, "pods": 0},
	{"id": "warden", "name": "WARDEN", "code": "HF-3", "branch": HEAVY, "tier": 3, "price": 6500, "rank": 6,
		"speed": 1.18, "turn": 1.02, "hp": 1.25, "gun": 1.1, "missiles": 8, "flares": 4,
		"nose": 0, "tail": 38, "hw": 4, "wing": [12, 34, 2, 33, 36], "tailp": [], "canard": [], "fins": "single", "eng": 2, "pods": 0},
	{"id": "monolith", "name": "MONOLITH", "code": "HF-4", "branch": HEAVY, "tier": 4, "price": 14000, "rank": 10,
		"speed": 1.22, "turn": 1.08, "hp": 1.35, "gun": 1.15, "missiles": 9, "flares": 5,
		"nose": 1, "tail": 36, "hw": 5, "wing": [10, 30, 1, 28, 31], "tailp": [30, 36, 7, 34, 37], "canard": [], "fins": "v", "eng": 2, "pods": 0},
	{"id": "mattock", "name": "MATTOCK", "code": "AT-1", "branch": ATTACK, "tier": 1, "price": 600, "rank": 1,
		"speed": 0.88, "turn": 1.0, "hp": 1.35, "gun": 1.25, "missiles": 4, "flares": 3,
		"nose": 4, "tail": 36, "hw": 3, "wing": [16, 23, 1, 17, 22], "tailp": [30, 34, 10, 30, 34], "canard": [], "fins": "twin", "eng": 2, "pods": 2},
	{"id": "halberd", "name": "HALBERD", "code": "AT-2", "branch": ATTACK, "tier": 2, "price": 2400, "rank": 3,
		"speed": 0.94, "turn": 1.04, "hp": 1.45, "gun": 1.3, "missiles": 5, "flares": 3,
		"nose": 3, "tail": 36, "hw": 3, "wing": [15, 24, 2, 21, 25], "tailp": [30, 35, 10, 33, 36], "canard": [], "fins": "single", "eng": 1, "pods": 2},
	{"id": "anvil", "name": "ANVIL", "code": "AT-3", "branch": ATTACK, "tier": 3, "price": 6500, "rank": 6,
		"speed": 0.98, "turn": 1.06, "hp": 1.6, "gun": 1.4, "missiles": 6, "flares": 4,
		"nose": 6, "tail": 30, "hw": 3, "wing": [15, 22, 1, 16, 21], "tailp": [], "canard": [], "fins": "boom", "eng": 1, "pods": 3},
	{"id": "maul", "name": "MAUL", "code": "AT-4", "branch": ATTACK, "tier": 4, "price": 14000, "rank": 10,
		"speed": 1.04, "turn": 1.1, "hp": 1.75, "gun": 1.5, "missiles": 7, "flares": 5,
		"nose": 1, "tail": 38, "hw": 4, "wing": [14, 31, 2, 29, 33], "tailp": [], "canard": [9, 13, 9, 11, 14], "fins": "twin", "eng": 2, "pods": 3},
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
	{"name": "TIGER", "body": "e8902a", "dark": "a05a14", "light": "f5b25a", "acc": "1c1c1c", "canopy": "1e6a80", "camo": "1c1c1c", "pattern": 2, "unlock": ["achievement", "ace_10"]},
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


## 0..1 bars for the hangar.
static func bars(plane: int, lv: Dictionary) -> Array:
	var st := stats(plane, lv)
	return [
		clampf((st["speed_mult"] - 0.8) / 0.6, 0.0, 1.0),
		clampf((st["turn_mult"] - 0.9) / 0.55, 0.0, 1.0),
		clampf((st["hp"] - 70.0) / 170.0, 0.0, 1.0),
		clampf((st["gun"] * 0.6 + st["missiles"] / 12.0 - 0.6) / 1.0, 0.0, 1.0),
	]


# ------------------------------------------------------------------ painter

static func _c(hex: String, fallback: Color) -> Color:
	return Color(hex) if hex != "" else fallback


## Paint slice s of plane `pi` in skin `si`.
static func paint(p: Painter, s: int, pi: int, si: int) -> void:
	var d: Dictionary = LIST[pi]
	var sk: Dictionary = SKINS[si]
	var fb: Array = FACTORY_BODY[int(d["branch"])]
	var body := _c(sk["body"], Color(fb[0]))
	var dark := _c(sk["dark"], Color(fb[1]))
	var light := _c(sk["light"], Color(fb[2]))
	var acc := Color(sk["acc"])
	var canopy := Color(sk["canopy"])
	var nose: int = d["nose"]
	var tail: int = d["tail"]
	var hw: int = d["hw"]
	var wing: Array = d["wing"]
	var tp: Array = d["tailp"]
	var cn: Array = d["canard"]
	var fins: String = d["fins"]
	var boom := fins == "boom"
	var cx := SHEET_W / 2
	match s:
		0:
			p.srect(maxi(1, hw - 1), nose + 5, tail - 1, dark.darkened(0.2))
		1:
			p.srect(hw, nose + 2, tail, dark)
			for k in int(d["pods"]):
				# under-wing stores
				var x := cx - hw - 3 - k * 3
				p.rect(x, wing[0] + 1, 1, 5, dark.darkened(0.3))
				p.rect(SHEET_W - x - 1, wing[0] + 1, 1, 5, dark.darkened(0.3))
			if boom:
				p.rect(cx - 9, wing[0], 2, 37 - wing[0], dark)
				p.rect(cx + 7, wing[0], 2, 37 - wing[0], dark)
		2:
			p.srect(hw, nose + 1, tail, body)
			p.srect(maxi(1, hw - 1), nose, nose + 2, body)
			if int(d["eng"]) == 1:
				p.rect(cx - 1, tail, 2, 2, dark)
				p.erect(cx - 1, tail + 1, 2, 1, Color("ffb43c"), Painter.EM_ALWAYS)
			else:
				for sx: int in [-1, 1]:
					var x := cx + sx * maxi(1, hw - 1) - (1 if sx < 0 else 0) - (1 if sx > 0 else 0)
					p.rect(x, tail, 2, 2, dark)
					p.erect(x, tail + 1, 2, 1, Color("ffb43c"), Painter.EM_ALWAYS)
			if boom:
				p.rect(cx - 9, wing[0], 2, 37 - wing[0], body)
				p.rect(cx + 7, wing[0], 2, 37 - wing[0], body)
				p.rect(cx - 9, 34, 18, 2, body) # boom tailplane
		3:
			p.mpoly(_wpoly(wing), body)
			if not tp.is_empty():
				p.mpoly(_wpoly(tp), body)
			if not cn.is_empty():
				p.mpoly(_wpoly(cn), body)
			p.srect(hw, nose + 2, tail - 1, body)
			# wing-tip accents
			p.rect(wing[2], wing[3], 2, maxi(1, wing[4] - wing[3]), acc)
			p.rect(SHEET_W - wing[2] - 2, wing[3], 2, maxi(1, wing[4] - wing[3]), acc)
			_camo(p, s, body, sk, pi)
		4:
			var hl := [wing[0] + 1, wing[0] + (wing[1] - wing[0]) / 2, wing[2] + 3, wing[3] + 1, wing[3] + maxi(1, (wing[4] - wing[3]) / 2)]
			p.mpoly(_wpoly(hl), light)
			p.srect(maxi(1, hw - 1), nose + 1, tail - 2, light)
			p.srect(1, nose, nose + 3, acc)
			_camo(p, s, light, sk, pi)
		5:
			p.srect(maxi(1, hw - 1), nose + 2, tail - 4, body)
			p.srect(1, nose + 12, tail - 6, light)
			if boom:
				p.rect(cx - 9, 33, 2, 4, body)
				p.rect(cx + 7, 33, 2, 4, body)
			_camo(p, s, body, sk, pi)
		6, 7, 8, 9, 10:
			if s == 6:
				p.srect(mini(2, hw), nose + 4, nose + 10, canopy)
				p.srect(1, nose + 10, tail - 4, body)
			elif s == 7:
				p.srect(1, nose + 5, nose + 9, canopy.lightened(0.35))
			_fins(p, s, d, body, acc)


static func _wpoly(w: Array) -> PackedVector2Array:
	var cx := float(SHEET_W) * 0.5
	return PackedVector2Array([Vector2(cx, w[0]), Vector2(w[2], w[3]), Vector2(w[2], w[4]), Vector2(cx, w[1])])


static func _fins(p: Painter, s: int, d: Dictionary, body: Color, acc: Color) -> void:
	var k := s - 6 # 0..4 going up
	var tail: int = d["tail"]
	var hw: int = d["hw"]
	var cx := SHEET_W / 2
	var col := acc if s == 10 else body
	var y0 := tail - 9 + k * 2
	var y1 := tail - 1
	if y1 - y0 < 1:
		return
	match d["fins"]:
		"single":
			p.rect(cx - 1, y0, 2, y1 - y0, col)
		"twin":
			var fx := hw + 2
			p.rect(cx - fx - 1, y0, 2, y1 - y0, col)
			p.rect(cx + fx - 1, y0, 2, y1 - y0, col)
		"v":
			var fx := hw + 1 + k
			p.rect(cx - fx - 1, y0, 2, y1 - y0, col)
			p.rect(cx + fx - 1, y0, 2, y1 - y0, col)
		"boom":
			p.rect(cx - 9, 30 + k, 2, 6 - k, col)
			p.rect(cx + 7, 30 + k, 2, 6 - k, col)


## Camo blotches / stripes: recolour body pixels of the wing slices.
static func _camo(p: Painter, s: int, base: Color, sk: Dictionary, pi: int) -> void:
	var pat: int = sk["pattern"]
	if pat == 0:
		return
	var alt := Color(sk["camo"])
	for y in p.h:
		for x in p.w:
			var c := p.img.get_pixel(p.ox + x, y)
			if c.a < 0.5 or not c.is_equal_approx(base):
				continue
			var on := false
			if pat == 1:
				on = CityGen.vnoise(x * 0.28 + pi * 3.1, y * 0.28 + s * 0.7, 91) > 0.58
			else:
				on = int(floor(x * 0.5 + y * 0.35 + sin(y * 0.6) * 1.5)) % 4 == 0
			if on:
				p.img.set_pixel(p.ox + x, y, alt)
