class_name PlaneArt
extends RefCounted
## Detailed pixel-art sprite stacks for the 12 planes of the aircraft tree.
##
## Every plane is built as a voxel model (HD: 128 x 128 px, 32 slices; nose
## at the top of the slice, slice 0 = belly) from parametric parts: shaped
## fuselage stations, bubble canopy with frame bows and the pilot's helmet,
## wings with dihedral, leading-edge highlight, spar / rib panel lines,
## rivets, flaps and ailerons, roundels and wing-tip colour, canards, tails,
## fins with rudders and a strobe, intakes with lips and dark ducts,
## nacelles, booms, nozzles with petals and a glowing core, pylons with
## missiles / tanks / bombs / rocket pods, gun ports, airbrake outline,
## antennas, stencils, nav lights, exhaust soot and panel-to-panel weathering.
##
## The slices store MATERIAL indices, not colours: R = material, G = shade
## (128 = 1.0), B = flags (bits 0-1 camo masks, 4-5 emission class, 6-7 plane
## class), A = coverage. The stack shader looks the colour up in a small
## palette texture (row = skin * 3 + class), so all skins cost no extra
## texture memory and new skins are one palette row.

## HD voxel: the art parameters below are authored on a 64 px / 16 slice
## grid and scaled by K at build time; fine details (panel lines, rivets,
## edges) stay one voxel, so they come out twice as fine.
const K := 2
const W := 64 * K # slice size (px)
const D := 16 * K # slices
const CX := W / 2
## World length of a plane (units); slices are scaled from W to this.
const WORLD := 40.0
const VERSION := 4

# materials (palette columns)
enum {
	NONE, BODY, BELLY, LIGHT, ACC, GLASS, GLASS_HI, FRAME, METAL, METAL_D,
	BURN, GLOW, INTAKE, RADOME, ANTIGLARE, MSL, MSL_D, MSL_BAND, TANK, BOMB,
	ROUNDEL_O, ROUNDEL_I, NAV_R, NAV_G, STROBE, PILOT, STENCIL, RED, CAMO,
	PATTERN, POD, MATS,
}
# emission classes (flags bits 4-5)
const EM_ALWAYS := 1
const EM_NIGHT := 2
const EM_BLINK := 3

## Per-plane art parameters (pixels; y grows from nose to tail, z from belly
## up). fus: [y, half width, half height, centre z] stations; sec: section
## exponent (2 round, 3 boxy, <1.5 faceted); canopy: [y0, y1, half width,
## height, frame bows, pilot y]; wing / htail / canard / lerx: [root front,
## root back, span, tip front, tip back, z, dihedral (px at tip), thickness];
## fins: [x, cant (px per slice), z0, height, root front, root back, tip
## front, tip back]; intake: [kind, y0, y1, width, half height, centre z];
## eng: [x, z, radius] nozzles over noz [y0, y1]; nacelles: [x, z, r, y0, y1];
## booms: [x, z, r, y0, y1]; stores: [kind, x, y0, z] (mirrored unless x = 0);
## gun: [x, y0, length, z]; panels: fuselage panel-line stations.
const ART := {
	"wren": {"sec": 2.0, "radome": 11, "soot": 50,
		"fus": [[7, 0.5, 0.5, 7.0], [9, 1.4, 1.3, 7.0], [12, 2.4, 2.2, 7.2], [16, 3.0, 2.8, 7.4], [22, 3.4, 3.0, 7.4], [30, 3.6, 3.0, 7.2], [42, 3.2, 2.8, 7.0], [50, 2.6, 2.4, 7.0], [56, 2.1, 2.0, 7.0]],
		"canopy": [15, 27, 2.4, 2.8, [18, 23], 21],
		"wing": [27, 38, 19, 34, 38, 6, 1, 2], "htail": [48, 55, 10, 52, 56, 7, 0, 1],
		"fins": [[0, 0.0, 9, 6, 42, 55, 50, 56]],
		"intake": ["half", 21, 33, 2, 2.0, 7.0], "eng": [[0, 7.0, 2.0]], "noz": [55, 58],
		"stores": [["tip", 19, 30, 6], ["aam", 11, 27, 4]], "gun": [-3, 11, 3, 6],
		"panels": [12, 20, 30, 38, 46]},
	"vireo": {"sec": 2.0, "radome": 9, "soot": 51,
		"fus": [[4, 0.5, 0.5, 7.0], [7, 1.3, 1.2, 7.0], [11, 2.3, 2.1, 7.2], [16, 3.0, 2.8, 7.4], [24, 3.4, 3.0, 7.4], [34, 3.6, 3.0, 7.2], [46, 3.2, 2.8, 7.0], [54, 2.6, 2.4, 7.0], [57, 2.2, 2.1, 7.0]],
		"canopy": [14, 25, 2.4, 2.8, [17, 22], 20],
		"wing": [24, 40, 19, 37, 41, 6, 0, 2], "htail": [49, 56, 10, 54, 58, 7, -1, 1],
		"fins": [[0, 0.0, 9, 7, 41, 56, 51, 57]],
		"intake": ["half", 19, 34, 2, 2.2, 6.8], "eng": [[0, 7.0, 2.1]], "noz": [56, 59],
		"stores": [["tip", 19, 33, 6], ["aam", 12, 29, 4]], "gun": [-3, 9, 3, 6],
		"panels": [11, 18, 28, 38, 48]},
	"skylark": {"sec": 2.0, "radome": 8, "soot": 52,
		"fus": [[3, 0.5, 0.5, 7.0], [6, 1.3, 1.2, 7.0], [10, 2.4, 2.2, 7.2], [15, 3.0, 2.8, 7.4], [24, 3.6, 3.0, 7.4], [36, 3.8, 3.0, 7.2], [48, 3.4, 2.8, 7.0], [56, 2.6, 2.4, 7.0], [58, 2.3, 2.2, 7.0]],
		"canopy": [12, 23, 2.4, 2.9, [15, 20], 18],
		"wing": [22, 54, 21, 48, 54, 6, 0, 2], "canard": [17, 23, 8, 20, 23, 8, 1, 1],
		"fins": [[0, 0.0, 9, 8, 40, 57, 52, 58]],
		"intake": ["chin", 15, 30, 3, 1.6, 4.2], "eng": [[0, 7.0, 2.2]], "noz": [57, 60],
		"stores": [["tip", 21, 44, 6], ["aam", 14, 36, 4], ["aam", 8, 33, 4]], "gun": [3, 12, 3, 6],
		"panels": [10, 18, 28, 40, 50]},
	"zephyr": {"sec": 2.6, "radome": 7, "soot": 50,
		"fus": [[2, 0.5, 0.5, 7.2], [5, 1.4, 1.3, 7.2], [9, 2.4, 2.2, 7.4], [14, 3.1, 2.8, 7.6], [22, 4.0, 3.0, 7.6], [34, 4.8, 2.9, 7.4], [46, 5.0, 2.7, 7.2], [54, 4.6, 2.4, 7.0], [57, 4.2, 2.2, 7.0]],
		"canopy": [11, 22, 2.5, 2.9, [14, 19], 17],
		"wing": [28, 46, 20, 40, 45, 6, 0, 2], "htail": [48, 56, 13, 54, 58, 6, 0, 1], "canard": [16, 22, 8, 20, 22, 8, 0, 1],
		"fins": [[4, 0.35, 9, 6, 42, 55, 50, 56]],
		"intake": ["box", 18, 36, 3, 2.2, 6.4], "eng": [[2, 7.0, 1.9]], "noz": [56, 59],
		"stores": [["tip", 20, 37, 6], ["aam", 13, 32, 4], ["aam", 8, 34, 4]], "gun": [-4, 14, 3, 7],
		"panels": [9, 16, 26, 36, 46]},
	"bastion": {"sec": 3.0, "radome": 10, "soot": 50,
		"fus": [[4, 0.6, 0.6, 7.2], [7, 1.6, 1.5, 7.2], [11, 2.8, 2.5, 7.4], [16, 3.6, 3.0, 7.8], [24, 5.0, 3.1, 7.6], [34, 5.6, 3.0, 7.4], [46, 5.6, 2.8, 7.2], [54, 5.2, 2.5, 7.0], [57, 4.8, 2.3, 7.0]],
		"canopy": [13, 24, 2.6, 2.8, [16, 21], 19],
		"wing": [25, 44, 21, 39, 44, 6, -1, 2], "htail": [46, 56, 13, 53, 57, 6, 0, 1],
		"fins": [[4, 0.0, 9, 7, 40, 55, 50, 56]],
		"intake": ["box", 17, 36, 4, 2.6, 6.6], "eng": [[3, 7.0, 2.2]], "noz": [56, 59],
		"stores": [["aam", 14, 30, 4], ["aam", 9, 32, 4], ["aam", 4, 34, 3]], "gun": [-5, 15, 3, 7],
		"panels": [10, 18, 26, 34, 44, 52]},
	"rampart": {"sec": 3.0, "radome": 9, "soot": 51,
		"fus": [[2, 0.6, 0.6, 7.2], [5, 1.6, 1.5, 7.2], [10, 2.9, 2.6, 7.4], [16, 3.8, 3.0, 7.8], [24, 5.2, 3.1, 7.6], [36, 5.8, 3.0, 7.4], [48, 5.8, 2.8, 7.2], [56, 5.2, 2.5, 7.0], [58, 5.0, 2.4, 7.0]],
		"canopy": [12, 23, 2.6, 2.9, [15, 20], 18],
		"wing": [28, 46, 22, 42, 46, 6, -1, 2], "lerx": [16, 30, 7, 28, 30, 7, 0, 1], "htail": [48, 57, 14, 54, 59, 6, -1, 1],
		"fins": [[5, 0.45, 9, 7, 42, 56, 51, 57]],
		"intake": ["box", 19, 38, 4, 2.6, 6.6], "eng": [[3, 7.0, 2.3]], "noz": [57, 60],
		"stores": [["aam", 15, 33, 4], ["aam", 10, 34, 4], ["aam", 4, 32, 3], ["tank", 0, 26, 2]], "gun": [-5, 14, 3, 7],
		"panels": [9, 17, 26, 36, 46, 54]},
	"warden": {"sec": 3.0, "radome": 8, "soot": 51,
		"fus": [[1, 0.6, 0.6, 7.2], [4, 1.6, 1.5, 7.2], [9, 2.8, 2.6, 7.4], [15, 3.6, 3.0, 7.8], [24, 4.6, 3.1, 7.6], [36, 5.2, 3.0, 7.4], [48, 5.2, 2.8, 7.2], [56, 4.6, 2.5, 7.0], [58, 4.4, 2.4, 7.0]],
		"canopy": [11, 22, 2.6, 2.9, [14, 19], 17],
		"wing": [20, 56, 24, 52, 57, 6, -1, 2],
		"fins": [[0, 0.0, 9, 8, 38, 57, 52, 58]],
		"intake": ["box", 16, 34, 4, 2.4, 6.6], "eng": [[2, 7.0, 2.1]], "noz": [57, 60],
		"stores": [["aam", 17, 46, 4], ["aam", 12, 40, 4], ["aam", 7, 36, 4], ["aam", 3, 26, 3]], "gun": [-4, 13, 3, 7],
		"panels": [8, 16, 26, 36, 46, 54]},
	"monolith": {"sec": 1.35, "radome": 7, "soot": 52, "flat": true,
		"fus": [[2, 0.6, 0.5, 7.0], [5, 2.0, 1.2, 7.0], [10, 3.6, 1.9, 7.2], [16, 4.8, 2.4, 7.4], [24, 6.0, 2.6, 7.4], [36, 6.6, 2.6, 7.2], [48, 6.4, 2.4, 7.0], [56, 5.4, 2.0, 7.0], [58, 5.0, 1.8, 7.0]],
		"canopy": [11, 21, 2.4, 2.4, [14, 19], 16],
		"wing": [26, 48, 23, 44, 49, 6, 0, 2], "htail": [50, 57, 13, 55, 59, 6, 0, 1],
		"fins": [[5, 0.9, 8, 6, 44, 56, 52, 58]],
		"intake": ["box", 16, 34, 3, 1.8, 7.6], "eng": [[3, 7.0, 1.8]], "noz": [56, 59],
		"stores": [], "bays": true,
		"panels": [10, 18, 28, 38, 48]},
	"mattock": {"sec": 2.4, "radome": 0, "soot": 46,
		"fus": [[6, 0.6, 0.6, 6.6], [8, 1.8, 1.7, 6.6], [12, 2.8, 2.6, 6.8], [18, 3.4, 3.2, 7.2], [28, 3.6, 3.2, 7.2], [40, 3.2, 2.8, 7.0], [50, 2.4, 2.2, 7.0], [56, 1.8, 1.8, 7.0]],
		"canopy": [13, 23, 2.5, 3.0, [16, 20], 18],
		"wing": [27, 37, 24, 30, 36, 5, 0, 2], "htail": [49, 56, 11, 50, 56, 7, 0, 1],
		"fins": [[10, 0.0, 6, 7, 48, 56, 50, 56]],
		"nacelles": [[5, 10.0, 2.2, 36, 48]],
		"stores": [["bomb", 19, 28, 3], ["rocket", 14, 28, 3], ["bomb", 8, 29, 3]], "gun": [0, 3, 4, 6],
		"panels": [12, 20, 28, 36, 44]},
	"halberd": {"sec": 2.4, "radome": 9, "soot": 50,
		"fus": [[4, 0.5, 0.5, 7.0], [7, 1.6, 1.5, 7.0], [11, 2.7, 2.5, 7.2], [17, 3.4, 3.0, 7.4], [26, 3.8, 3.0, 7.4], [38, 3.8, 3.0, 7.2], [50, 3.0, 2.6, 7.0], [56, 2.4, 2.3, 7.0]],
		"canopy": [13, 24, 2.5, 3.0, [16, 21], 19],
		"wing": [26, 38, 22, 34, 38, 5, 0, 2], "htail": [48, 55, 11, 52, 56, 7, 0, 1],
		"fins": [[0, 0.0, 9, 7, 41, 55, 50, 56]],
		"intake": ["half", 20, 34, 2, 2.4, 7.0], "eng": [[0, 7.0, 2.2]], "noz": [55, 58],
		"stores": [["tip", 22, 30, 5], ["bomb", 16, 28, 3], ["rocket", 10, 27, 3]], "gun": [3, 9, 3, 6],
		"panels": [11, 19, 28, 38, 48]},
	"anvil": {"sec": 2.4, "radome": 0, "soot": 34,
		"fus": [[6, 0.6, 0.6, 7.0], [9, 2.0, 1.8, 7.0], [13, 3.2, 2.8, 7.2], [20, 3.8, 3.2, 7.4], [28, 3.8, 3.0, 7.2], [34, 3.2, 2.6, 7.0], [38, 2.4, 2.2, 7.0]],
		"canopy": [13, 23, 2.6, 3.0, [16, 20], 18],
		"wing": [24, 34, 25, 27, 33, 6, 0, 2], "htail": [52, 56, 11, 52, 56, 7, 0, 1],
		"booms": [10, 7.0, 1.6, 22, 56],
		"fins": [[10, 0.0, 8, 6, 46, 56, 51, 56]],
		"intake": ["half", 20, 30, 2, 2.0, 8.0], "eng": [[0, 7.0, 2.0]], "noz": [38, 41],
		"stores": [["bomb", 21, 24, 4], ["rocket", 16, 25, 4], ["bomb", 6, 25, 3]], "gun": [0, 3, 4, 6],
		"panels": [12, 20, 28, 34]},
	"maul": {"sec": 2.6, "radome": 8, "soot": 52,
		"fus": [[2, 0.6, 0.6, 7.2], [5, 1.7, 1.6, 7.2], [10, 2.9, 2.7, 7.4], [16, 3.8, 3.0, 7.8], [26, 5.0, 3.1, 7.6], [38, 5.4, 3.0, 7.4], [50, 5.2, 2.8, 7.2], [57, 4.6, 2.4, 7.0], [59, 4.4, 2.3, 7.0]],
		"canopy": [11, 23, 2.6, 3.0, [14, 18, 21], 17],
		"wing": [24, 56, 23, 50, 56, 6, 0, 2], "canard": [17, 23, 9, 20, 23, 8, 0, 1],
		"fins": [[4, 0.25, 9, 7, 42, 57, 52, 58]],
		"intake": ["box", 18, 36, 4, 2.4, 6.4], "eng": [[3, 7.0, 2.2]], "noz": [58, 61],
		"stores": [["tip", 23, 46, 6], ["bomb", 18, 40, 3], ["bomb", 13, 36, 3], ["rocket", 8, 34, 3]], "gun": [-4, 13, 3, 7],
		"panels": [9, 17, 26, 36, 46, 54]},
}

var mat := PackedByteArray()
var shd := PackedByteArray()
var flg := PackedByteArray()
var _cls := 0
var _pi := 0
var _art: Dictionary


func _init() -> void:
	mat.resize(W * W * D)
	shd.resize(W * W * D)
	flg.resize(W * W * D)


static func _i(x: int, y: int, z: int) -> int:
	return (z * W + y) * W + x


func clear() -> void:
	mat.fill(0)
	shd.fill(0)
	flg.fill(0)


func occupied(x: int, y: int, z: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= W or z < 0 or z >= D:
		return false
	return mat[_i(x, y, z)] != 0


func get_mat(x: int, y: int, z: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= W or z < 0 or z >= D:
		return 0
	return mat[_i(x, y, z)]


## Write one voxel. Paint (BODY / BELLY / LIGHT / TANK) gets a subtle
## per-pixel grain and panel-to-panel tone variation, and camo masks.
func put(x: int, y: int, z: int, m: int, shade: float = 1.0, em: int = 0, over: bool = true) -> void:
	if x < 0 or x >= W or y < 0 or y >= W or z < 0 or z >= D:
		return
	var i := _i(x, y, z)
	if not over and mat[i] != 0:
		return
	var f := (_cls << 6) | (em << 4)
	if m == BODY or m == BELLY or m == LIGHT or m == TANK or m == RADOME:
		var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
		var p := ((x / (4 * K)) * 7919 + (y / (4 * K)) * 104729 + _pi * 31) * 2654435761
		shade *= 0.965 + float((h >> 5) & 255) / 255.0 * 0.06 + float((p >> 9) & 255) / 255.0 * 0.03 - 0.015
		if m == BODY:
			var gx := float(x) / K
			var gy := float(y) / K
			if CityGen.vnoise(gx * 0.17 + _pi * 3.1, gy * 0.17 + z * 0.45 / K, 91) > 0.58:
				f |= 1
			if int(floor(gx * 0.3125 + gy * 0.219 + sin(gy * 0.375) * 1.5)) % 4 == 0:
				f |= 2
	mat[i] = m
	shd[i] = clampi(int(round(shade * 128.0)), 0, 255)
	flg[i] = f


## Mirror pair around the centre line (x and 63 - x).
func putm(x: int, y: int, z: int, m: int, shade: float = 1.0, em: int = 0, over: bool = true) -> void:
	put(x, y, z, m, shade, em, over)
	put(W - 1 - x, y, z, m, shade, em, over)


func set_shade(x: int, y: int, z: int, k: float) -> void:
	if occupied(x, y, z):
		var i := _i(x, y, z)
		shd[i] = clampi(int(round(shd[i] * k)), 0, 255)


func top_z(x: int, y: int) -> int:
	for z in range(D - 1, -1, -1):
		if mat[_i(x, y, z)] != 0:
			return z
	return -1


# ------------------------------------------------------------------ build

## Build plane `pi`; returns nothing, the voxels are in mat / shd / flg.
func build(pi: int) -> void:
	clear()
	_pi = pi
	var d: Dictionary = Planes.LIST[pi]
	_cls = int(d["branch"])
	_art = scale_art(ART[d["id"]])
	var a := _art
	if a.has("booms"):
		var b: Array = a["booms"]
		for sx: int in [-1, 1]:
			_cyl(CX + sx * int(b[0]) - (1 if sx < 0 else 0), float(b[1]), float(b[2]), int(b[3]), int(b[4]), true)
	if a.has("nacelles"):
		for n: Array in a["nacelles"]:
			for sx: int in [-1, 1]:
				var xc := float(CX) + sx * float(n[0])
				_nacelle(xc, float(n[1]), float(n[2]), int(n[3]), int(n[4]))
	_fuselage(a["fus"], float(a["sec"]), int(a["radome"]))
	if a.has("intake"):
		_intake(a["intake"])
	_wing(a["wing"], true)
	if a.has("lerx"):
		_wing(a["lerx"], false)
	if a.has("htail"):
		_wing(a["htail"], false)
	if a.has("canard"):
		_wing(a["canard"], false)
	if a.has("booms"):
		_boom_tails(a["booms"])
	for f: Array in a["fins"]:
		_fin(f)
	_canopy(a["canopy"])
	_spine_details()
	if a.has("eng"):
		var nz: Array = a["noz"]
		for e: Array in a["eng"]:
			if int(e[0]) == 0:
				_nozzle(float(CX), float(e[1]), float(e[2]), int(nz[0]), int(nz[1]), a.get("flat", false))
			else:
				for sx: int in [-1, 1]:
					_nozzle(float(CX) + sx * float(e[0]), float(e[1]), float(e[2]), int(nz[0]), int(nz[1]), a.get("flat", false))
	for s: Array in a["stores"]:
		_store(s)
	if a.has("gun"):
		_gun(a["gun"])
	if a.get("bays", false):
		_bays()
	_soot(int(a["soot"]))


## Local point of the plane model (relative to the plane node, nose
## towards -z) from art pixels on the 64 grid: x across, y nose->tail, z up.
static func art_local(x: float, y: float, z: float) -> Vector3:
	var u := WORLD / 64.0
	return Vector3(x * u, z * u, (y - 32.0) * u)


## Right wing tip (local), for vortices.
static func wingtip(pi: int) -> Vector3:
	var w: Array = ART[Planes.LIST[pi]["id"]]["wing"]
	return art_local(float(w[2]), (float(w[3]) + float(w[4])) * 0.5, float(w[5]) + float(w[6]) + 1.0)


## Engine nozzle exits (local).
static func nozzles(pi: int) -> Array[Vector3]:
	var a: Dictionary = ART[Planes.LIST[pi]["id"]]
	var out: Array[Vector3] = []
	var nz: Array = a.get("noz", [56, 58])
	for e: Array in a.get("eng", []):
		if float(e[0]) == 0.0:
			out.append(art_local(0.0, float(nz[1]), float(e[1])))
		else:
			out.append(art_local(float(e[0]), float(nz[1]), float(e[1])))
			out.append(art_local(-float(e[0]), float(nz[1]), float(e[1])))
	if a.has("nacelles"):
		for n: Array in a["nacelles"]:
			out.append(art_local(float(n[0]), float(n[4]) + 2.0, float(n[1])))
			out.append(art_local(-float(n[0]), float(n[4]) + 2.0, float(n[1])))
	if out.is_empty():
		out.append(art_local(0.0, 58.0, 7.0))
	return out


## Art parameters from the 64 px grid to the HD grid (fin cant is pixels
## per slice: unchanged; "sec" is an exponent).
static func scale_art(a: Dictionary) -> Dictionary:
	var o := {}
	for k in a:
		if k == "sec":
			o[k] = a[k]
		elif k == "fins":
			var fl: Array = []
			for f: Array in a[k]:
				var g: Array = _sc(f)
				g[1] = f[1]
				fl.append(g)
			o[k] = fl
		else:
			o[k] = _sc(a[k])
	return o


static func _sc(v: Variant) -> Variant:
	if v is int:
		return int(v) * K
	if v is float:
		return float(v) * K
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_sc(e))
		return out
	return v


## Fuselage station interpolation: [hw, hh, cz] at y (0 outside).
func _station(st: Array, y: float) -> Vector3:
	if y < float(st[0][0]) or y > float(st[st.size() - 1][0]):
		return Vector3.ZERO
	for k in range(1, st.size()):
		var a: Array = st[k - 1]
		var b: Array = st[k]
		if y <= float(b[0]):
			var t := (y - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t) * 0.5 + t * 0.5
			return Vector3(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
	return Vector3.ZERO


## Shade from a surface normal: bright on top, darker on the flanks, a
## specular streak along the spine.
static func _nshade(nx: float, nz: float) -> float:
	var s := 0.74 + 0.32 * maxf(nz, 0.0) - 0.12 * maxf(-nz, 0.0)
	if nz > 0.93:
		s += 0.08
	if absf(nx) > 0.85:
		s -= 0.04
	return s


func _fuselage(st: Array, p: float, radome: int) -> void:
	var y0 := int(st[0][0])
	var y1 := int(st[st.size() - 1][0])
	var panels: Array = _art["panels"]
	var cy0: int = _art["canopy"][0]
	for y in range(y0, y1):
		var v := _station(st, y + 0.5)
		var hw := v.x
		var hh := v.y
		var cz := v.z
		if hw <= 0.2:
			continue
		var panel := panels.has(y)
		for z in range(maxi(0, floori(cz - hh)), mini(D, ceili(cz + hh) + 1)):
			var dz := (z + 0.5 - cz) / hh
			if absf(dz) > 1.0:
				continue
			var xr := hw * pow(1.0 - pow(absf(dz), p), 1.0 / p)
			var n := int(round(xr))
			for k in n:
				var dx := (k + 0.5) / hw
				var gx := pow(minf(dx, 1.0), p - 1.0) / hw
				var gz := signf(dz) * pow(absf(dz), p - 1.0) / hh
				var nl := Vector2(gx, gz).normalized()
				var sh := _nshade(nl.x, nl.y)
				var m := BODY if nl.y > -0.3 else BELLY
				if y < radome:
					m = RADOME
					sh *= 1.05
				elif y == radome:
					sh *= 0.72
				elif y < cy0 and nl.y > 0.75 and k < 2 * K:
					m = ANTIGLARE
				if panel and nl.y > -0.6:
					sh *= 0.82
				elif panels.has(y - 1) and k % 2 == 0 and nl.y > 0.5:
					sh *= 1.06
				putm(CX + k, y, z, m, sh)


## Wing-like surface: [rf, rb, span, tf, tb, z, dihedral, thickness].
## main = the main wing (roundels, nav lights, tip colour, flaps).
func _wing(wd: Array, main: bool) -> void:
	var rf := float(wd[0])
	var rb := float(wd[1])
	var span := int(wd[2])
	var tf := float(wd[3])
	var tb := float(wd[4])
	var wz := int(wd[5])
	var dih := float(wd[6])
	var thick := int(wd[7])
	var tip_store := false
	for s: Array in _art["stores"]:
		if s[0] == "tip":
			tip_store = true
	var rnd_s := 0.7
	var rnd_x := int(round(rnd_s * span))
	var rnd_yc := lerpf(rf, tf, rnd_s) + (lerpf(rb, tb, rnd_s) - lerpf(rf, tf, rnd_s)) * 0.5
	var rnd_ok := main and (lerpf(rb, tb, rnd_s) - lerpf(rf, tf, rnd_s)) >= 6.0 * K
	var fus_hw := 0.0
	for k in span:
		var s := (k + 0.5) / span
		var yf := lerpf(rf, tf, s)
		var yb := lerpf(rb, tb, s)
		var ya := int(round(yf))
		var yz := int(round(yb))
		if yz <= ya:
			continue
		var z := wz + int(round(dih * s))
		var th := thick if s < 0.55 else K
		var x := CX + k
		var tip := k >= span - K
		if fus_hw == 0.0 and not occupied(x, ya + (yz - ya) / 2, z):
			fus_hw = float(k)
		for y in range(ya, yz):
			var t := (y + 0.5 - yf) / maxf(1.0, yb - yf)
			for j in th:
				var zz := z + j
				if j < th - 1:
					putm(x, y, zz, BELLY, 0.82, 0, false)
					continue
				var m := BODY
				var sh := 1.0
				if y == ya:
					sh = 1.16
					if main and CityGen.hashf(k, y, 17 + _pi) < 0.07:
						m = METAL
				elif y == yz - 1:
					sh = 0.84
				if main:
					var hinge := int(round(yf + (yb - yf) * 0.74))
					if y == hinge:
						sh *= 0.76
					elif y > hinge:
						sh *= 0.93
						if k == int(span * 0.5):
							sh *= 0.8
					elif y == int(round(yf + (yb - yf) * 0.42)) and not tip:
						sh *= 0.86
					elif y == int(round(yf + (yb - yf) * 0.42)) - 1 and k % 2 == 0:
						sh *= 1.06
					if k == int(span * 0.34) and y < hinge and y > ya:
						sh *= 0.88
					if tip:
						m = METAL_D if tip_store else ACC
					if rnd_ok:
						var dd := Vector2(k - rnd_x, (y + 0.5) - rnd_yc).length()
						if dd < 2.2 * K:
							m = ACC if dd < 0.8 * K else (ROUNDEL_I if dd < 1.6 * K else ROUNDEL_O)
							sh = 1.0
					if k == int(fus_hw) + K and t > 0.15 and t < 0.6 and (y / K) % 3 == 0:
						m = STENCIL
				elif tip and k > 2 * K:
					sh *= 0.9
				putm(x, y, zz, m, sh, 0, false)
		if main and k == span - 1 and not tip_store:
			for a in K:
				for b in K:
					put(x - a, ya + b, z + th - 1, NAV_G, 1.0, EM_NIGHT)
					put(W - 1 - x + a, ya + b, z + th - 1, NAV_R, 1.0, EM_NIGHT)


## Fin: [x, cant, z0, height, rf, rb, tf, tb]. x = 0: one fin on the centre
## line (2 px thick), else a mirrored pair.
func _fin(fd: Array) -> void:
	var fx := int(fd[0])
	var cant := float(fd[1])
	var z0 := int(fd[2])
	var h := int(fd[3])
	for k in h:
		var s := float(k) / maxf(1.0, h - 1)
		var yf := lerpf(float(fd[4]), float(fd[6]), s)
		var yb := lerpf(float(fd[5]), float(fd[7]), s)
		var ya := int(round(yf))
		var yz := int(round(yb))
		var z := z0 + k
		var xo := fx + int(round(cant * k))
		for y in range(ya, yz):
			var t := (y + 0.5 - yf) / maxf(1.0, yb - yf)
			var m := ACC if k >= h - K else BODY
			var sh := 1.0
			if y == ya:
				sh = 1.14
			if t > 0.68:
				sh *= 0.9
				if y == int(round(yf + (yb - yf) * 0.68)):
					sh *= 0.8
			if k == h - 3 * K and t < 0.68:
				sh *= 0.86
			for a in K:
				if fx == 0:
					put(CX - 1 - a, y, z, m, sh * 0.94)
					put(CX + a, y, z, m, sh)
				else:
					put(CX + xo + a, y, z, m, sh)
					put(CX - 1 - xo - a, y, z, m, sh * 0.94)
		if k >= h - K and yz > ya:
			for b in K:
				if fx == 0:
					putm(CX, yz - 1 - b, z, STROBE, 1.0, EM_BLINK)
				else:
					put(CX + xo, yz - 1 - b, z, STROBE, 1.0, EM_BLINK)
					put(CX - 1 - xo, yz - 1 - b, z, STROBE, 1.0, EM_BLINK)


## Bubble canopy: glass with a highlight, frame bows, sill, the pilot's
## helmet and the head rest seen through the glass.
func _canopy(cd: Array) -> void:
	var y0 := float(cd[0])
	var y1 := float(cd[1])
	var cw := float(cd[2])
	var ch := float(cd[3])
	var bows: Array = cd[4]
	var py := int(cd[5])
	var ym := (y0 + y1) * 0.5
	var ry := (y1 - y0) * 0.5
	var st: Array = _art["fus"]
	for y in range(int(y0), int(y1)):
		var v := _station(st, y + 0.5)
		var base := v.z + v.y - 1.2 * K
		var sy := (y + 0.5 - ym) / ry
		# steeper windscreen at the front, long taper at the back
		var prof := sqrt(maxf(0.0, 1.0 - sy * sy)) if sy > -0.4 else sqrt(maxf(0.0, 1.0 - pow((sy + 0.4) / 0.6, 2.0))) * 0.92
		if prof <= 0.05:
			continue
		var hgt := ch * prof
		for z in range(maxi(0, floori(base)), mini(D, ceili(base + hgt) + 1)):
			var dz := (z + 0.5 - base) / hgt
			if dz > 1.0 or dz < 0.0:
				continue
			var half := cw * prof * sqrt(maxf(0.0, 1.0 - dz * dz))
			var n := maxi(1, int(round(half)))
			for k in n:
				var m := GLASS
				var sh := 0.86 + 0.24 * dz
				var edge := k == n - 1
				if bows.has(y) or (K > 1 and bows.has(y - 1)):
					m = FRAME
					sh = 0.9 + 0.3 * dz
				elif z == floori(base) and edge:
					m = FRAME
				elif dz > 0.55 and sy < 0.1 and k < K:
					m = GLASS_HI
				elif sy < -0.25 and dz > 0.3 and k >= K and k < 2 * K:
					m = GLASS_HI
				if m == GLASS and absi(y - py) <= K and k < 2 * K and dz > 0.6:
					# helmet: round, lit from above
					m = PILOT
					sh = 0.62 + (0.12 if y < py else 0.0) - (0.1 if k >= K else 0.0) + 0.08 * dz
				elif m == GLASS and y >= py + 2 * K and y < py + 3 * K and k < 2 * K and dz > 0.5:
					m = FRAME
					sh = 0.7
				putm(CX + k, y, z, m, sh)


## Airbrake outline and a blade antenna on the spine behind the canopy, a
## dark seam where the radome meets the body.
func _spine_details() -> void:
	var c1 := int(_art["canopy"][1])
	for y in range(c1 + 2 * K, c1 + 8 * K):
		for x in [CX - 2 * K, CX + 2 * K - 1]:
			var z := top_z(x, y)
			if z >= 0:
				set_shade(x, y, z, 0.82)
	for x in range(CX - 2 * K, CX + 2 * K):
		for y in [c1 + 2 * K, c1 + 8 * K - 1]:
			var z := top_z(x, y)
			if z >= 0:
				set_shade(x, y, z, 0.82)
	# rivets along the airbrake outline (every other voxel)
	for y in range(c1 + 2 * K, c1 + 8 * K, 2):
		for x in [CX - 2 * K + 1, CX + 2 * K - 2]:
			var z := top_z(x, y)
			if z >= 0:
				set_shade(x, y, z, 1.08)
	var ay := c1 + 10 * K
	var az := top_z(CX, ay)
	if az >= 0 and az < D - K - 1:
		for h in K + 1:
			putm(CX, ay + h / 2, az + 1 + h, METAL_D, 0.9 - 0.05 * h)
			putm(CX, ay + 1 + h / 2, az + 1 + h, METAL_D, 0.75)


## Engine intake: "box" (rectangular side box), "half" (half-round side),
## "chin" (under the nose). Dark duct with a metal lip; warning chevron.
func _intake(idf: Array) -> void:
	var kind: String = idf[0]
	var y0 := int(idf[1])
	var y1 := int(idf[2])
	var w := int(idf[3])
	var hh := float(idf[4])
	var zc := float(idf[5])
	var st: Array = _art["fus"]
	for y in range(y0, y1):
		var v := _station(st, y + 0.5)
		var taper := clampf(float(y1 - y) / (5.0 * K), 0.3, 1.0)
		var front := y - y0
		if kind == "chin":
			var cwid := w * taper
			for z in range(maxi(0, floori(zc - hh)), ceili(zc + hh)):
				for k in int(round(cwid)):
					var m := BELLY
					var sh := 0.8
					if front < 2 * K:
						m = INTAKE if (k < int(round(cwid)) - K and z > floori(zc - hh) + K - 1) else METAL
						sh = 1.0
					putm(CX + k, y, z, m, sh, 0, front < 2 * K)
			continue
		var xin := int(floor(v.x)) - K
		var ww := maxi(1, int(round(w * taper)))
		for z in range(maxi(0, floori(zc - hh * taper)), mini(D, ceili(zc + hh * taper))):
			var dz := (z + 0.5 - zc) / (hh * taper)
			for k in ww:
				var dx := (k + 0.5) / ww
				if kind == "half" and dx * dx + dz * dz > 1.15:
					continue
				var m := BODY if dz > -0.2 else BELLY
				var sh := 0.78 + 0.3 * clampf(dz, 0.0, 1.0)
				if k >= ww - K:
					sh *= 0.86
				if front < 2 * K:
					var lip := k >= ww - K or absf(dz) > 0.7 or front < K and k < K
					m = METAL if lip else INTAKE
					sh = 1.05 if lip else 1.0
				elif front >= 3 * K and front < 4 * K and k >= ww - K and dz > 0.0:
					m = RED
					sh = 1.0
				putm(CX + xin + k, y, z, m, sh)


## Round body along y (booms, also used for nacelles).
func _cyl(xc: int, zc: float, r: float, y0: int, y1: int, paint: bool) -> void:
	for y in range(y0, y1):
		var rr := r * clampf(float(y - y0 + 1) / (2.0 * K), 0.5, 1.0)
		for z in range(maxi(0, floori(zc - rr)), mini(D, ceili(zc + rr))):
			for x in range(floori(xc - rr), ceili(xc + rr) + 1):
				var d := Vector2(x + 0.5 - (xc + 0.5), z + 0.5 - zc) / rr
				if d.length_squared() > 1.0:
					continue
				var m := (BODY if d.y > -0.3 else BELLY) if paint else METAL
				put(x, y, z, m, _nshade(d.x, d.y), 0, false)


## Podded engine: round nacelle, dark intake with a lip at the front,
## petals + glow at the back.
func _nacelle(xc: float, zc: float, r: float, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		for z in range(maxi(0, floori(zc - r)), mini(D, ceili(zc + r))):
			for x in range(floori(xc - r), ceili(xc + r)):
				var d := Vector2(x + 0.5 - xc, z + 0.5 - zc) / r
				var l := d.length()
				if l > 1.0:
					continue
				var m := BODY if d.y > -0.3 else BELLY
				var sh := _nshade(d.x, d.y)
				if y - y0 < 2 * K:
					m = METAL if l > 0.62 else INTAKE
					sh = 1.05 if l > 0.62 else 1.0
				elif y == y0 + 4 * K or y == y1 - 4 * K:
					sh *= 0.82
				put(x, y, z, m, sh)
	_nozzle(xc, zc, r * 0.85, y1, y1 + 2 * K, false)
	# pylon to the fuselage
	for y in range(y0 + 3 * K, y1 - 2 * K):
		var dir := 1 if xc < CX else -1
		var xx := int(xc) + dir
		while (xx < CX if dir > 0 else xx > CX - 1):
			if occupied(xx, y, int(zc - r * 0.5)):
				break
			put(xx, y, int(zc - r * 0.5), BODY, 0.8, 0, false)
			xx += dir


## Twin-boom tail: fins sit on the booms (handled by _fin), here the
## boom ends get a rounded cap.
func _boom_tails(b: Array) -> void:
	var y1 := int(b[4])
	for sx: int in [-1, 1]:
		var x := CX + sx * int(b[0]) - (1 if sx < 0 else 0)
		for a in K:
			for c in K:
				put(x + (a if sx > 0 else -a), y1 + c, int(b[1]), BODY, 0.8)


## Nozzle: ring of petals (alternate shades, heat-blued), dark inside, a
## glowing core on the last row (visible from behind). flat = rectangular.
func _nozzle(xc: float, zc: float, r: float, y0: int, y1: int, flat: bool) -> void:
	for y in range(y0, y1):
		var rr := r * (1.0 - 0.06 * float(y - y0) / K)
		for z in range(maxi(0, floori(zc - rr - 0.5)), mini(D, ceili(zc + rr + 0.5))):
			for x in range(floori(xc - rr - 1.0), ceili(xc + rr + 1.0)):
				var d := Vector2(x + 0.5 - xc, z + 0.5 - zc)
				var l := d.length()
				if flat:
					l = maxf(absf(d.x) * 0.7, absf(d.y) * 1.6)
				if l > rr:
					continue
				var inner := l < maxf(rr - K, 0.86 * K)
				var m := BURN if (y - y0) >= K else METAL
				var sh := _nshade(d.x / rr, d.y / rr)
				if not inner:
					var ang := atan2(d.y, d.x)
					sh *= 0.86 if int(floor((ang + PI) / TAU * 16.0)) % 2 == 0 else 1.06
					put(x, y, z, m, sh)
				elif y >= y1 - K:
					put(x, y, z, GLOW, 1.0 - 0.25 * (l / rr), EM_ALWAYS)
				else:
					put(x, y, z, METAL_D, 0.8)


## Stores: [kind, x, y0, z]: "aam" missile on a pylon, "tip" wing-tip
## missile on a rail, "tank" drop tank, "bomb", "rocket" pod. Round bodies
## of radius ~K voxels so they read as cylinders on the HD grid.
func _store(sd: Array) -> void:
	var kind: String = sd[0]
	var xo := int(sd[1])
	var y0 := int(sd[2])
	var z := int(sd[3])
	var xs: Array = [CX + xo, W - 1 - (CX + xo)] if xo != 0 else [CX - 1]
	for x: int in xs:
		var xc := float(x) + 0.5 if xo != 0 else float(CX)
		match kind:
			"aam", "tip":
				var l := 11 * K
				var r := 0.55 * K + 0.1
				for k in l:
					var m := MSL
					var sh := 1.0
					var rk := r
					if k < K:
						m = MSL_D # seeker head
						rk = r * (0.55 + 0.45 * float(k) / K)
					elif k < 2 * K:
						sh = 0.92
					elif k >= 3 * K and k < 4 * K:
						m = MSL_BAND
					elif k >= l - 3 * K:
						sh = 0.9
					_disc(xc, float(z) + 0.5, rk, y0 + k, m, sh)
					if kind == "aam" and k >= 3 * K and k < l - 3 * K:
						for h in K:
							_sp(xo, int(xc), y0 + k, z + K + h, METAL_D, 0.8, 0, false) # pylon
				# canard and tail fins: a cross of thin plates
				for k0 in [K, l - 2 * K]:
					for k in K:
						for f in range(1, K + 2):
							_sp(xo, int(xc) - f, y0 + k0 + k, z, MSL_D, 0.9)
							_sp(xo, int(xc) + f, y0 + k0 + k, z, MSL_D, 0.9)
							_sp(xo, int(xc), y0 + k0 + k, z - f, MSL_D, 0.8)
				if kind == "aam" and z + 2 * K < D:
					for k in range(4 * K, l - 4 * K):
						_sp(xo, int(xc), y0 + k, z + 2 * K, BELLY, 0.7, 0, false)
			"tank":
				var l := 13 * K
				for k in l:
					var r := (1.6 * sin(PI * clampf((k + 0.7 * K) / l, 0.0, 1.0)) + 0.3) * K
					_disc(xc, float(z) + 0.5, r, y0 + k, TANK, 1.0)
				for k in K:
					_disc(xc, float(z) + 0.5, 0.6 * K, y0 + l - 1 - k, ACC, 1.0)
				for k in range(3 * K, l - 3 * K):
					for h in K:
						_sp(xo, int(xc), y0 + k, z + 2 * K + h, BELLY, 0.7, 0, false)
			"bomb":
				var l := 9 * K
				for k in l:
					var r := 1.25 * K if (k >= K and k < l - 3 * K) else 0.7 * K
					_disc(xc, float(z) + 0.5, r, y0 + k, BOMB, 1.0)
				for k in K:
					_sp(xo, int(xc), y0 + 2 * K + k, z + K, STENCIL, 1.0)
				for k in K:
					for f in range(1, K + 2):
						_sp(xo, int(xc) - f, y0 + l - 1 - k, z, MSL_D, 0.85)
						_sp(xo, int(xc) + f, y0 + l - 1 - k, z, MSL_D, 0.85)
						_sp(xo, int(xc), y0 + l - 1 - k, z + f, MSL_D, 0.85)
				for k in [3 * K, 5 * K]:
					for h in K:
						_sp(xo, int(xc), y0 + k, z + 2 * K + h, METAL_D, 0.8, 0, false)
			"rocket":
				var l := 8 * K
				var r := 1.5 * K
				for k in l:
					_disc(xc, float(z) + 0.5, r, y0 + k, POD, 1.08 if k >= K and k < 2 * K else 1.0)
				# tube mouths on the front face
				for dz in range(-K, K + 1, K):
					for dx in range(-K, K + 1, K):
						_sp(xo, int(xc) + dx, y0, z + dz, INTAKE, 1.0)
				for h in K:
					_sp(xo, int(xc), y0 + 4 * K, z + 2 * K + h, METAL_D, 0.8, 0, false)


## Store voxel: centre-line stores (xo = 0) are drawn as a mirrored pair.
func _sp(xo: int, x: int, y: int, z: int, m: int, sh: float = 1.0, em: int = 0, over: bool = true) -> void:
	if xo == 0:
		putm(x, y, z, m, sh, em, over)
	else:
		put(x, y, z, m, sh, em, over)


## One round cross-section (x-z disc) at row y, shaded like a cylinder.
func _disc(xc: float, zc: float, r: float, y: int, m: int, sh: float) -> void:
	for zz in range(floori(zc - r), ceili(zc + r)):
		for xx in range(floori(xc - r), ceili(xc + r)):
			var d := Vector2(xx + 0.5 - xc, zz + 0.5 - zc) / maxf(r, 0.01)
			if d.length_squared() > 1.0:
				continue
			put(xx, y, zz, m, _nshade(d.x, d.y) * sh)


func _gun(gd: Array) -> void:
	var xo := int(gd[0])
	var y0 := int(gd[1])
	var l := int(gd[2])
	var z := int(gd[3])
	var x := CX + xo if xo >= 0 else CX - 1 + xo
	if xo == 0:
		# long nose cannon of the attackers
		for k in l:
			_disc(float(CX), float(z) + 0.5, 0.8 * K, y0 + k, METAL_D, 0.85)
		_disc(float(CX), float(z) + 0.5, 0.4 * K, y0, INTAKE, 1.0)
		return
	for k in l:
		var zz := z
		var xx := x
		# sit on the fuselage surface
		while xx != CX and not occupied(xx, y0 + k, zz):
			xx += 1 if xo < 0 else -1
		# paint over the skin only (a one-sided gun keeps the shape symmetric)
		for h in K:
			if occupied(xx, y0 + k, zz + h):
				put(xx, y0 + k, zz + h, METAL_D, (0.85 if k >= K else 0.6) - 0.08 * h)


## Stealth plane: internal bay door outlines (zig-zag) on the belly and the
## top, no external stores.
func _bays() -> void:
	for y in range(20 * K, 44 * K):
		for x in range(CX - 4 * K, CX + 4 * K):
			if (x - CX + y) % (6 * K) == 0:
				var z := top_z(x, y)
				if z >= 0:
					set_shade(x, y, z, 0.86)
	for y in [22 * K, 42 * K]:
		for x in range(CX - 4 * K, CX + 4 * K):
			var z := top_z(x, y)
			if z >= 0:
				set_shade(x, y, z, 0.8)


## Exhaust soot on the top surfaces near the nozzles.
func _soot(y0: int) -> void:
	for y in range(y0, W):
		var k := 1.0 - 0.22 * float(y - y0 + 1) / maxf(1.0, float(W - y0) * 0.5)
		k = clampf(k, 0.7, 1.0)
		for x in range(CX - 12 * K, CX + 12 * K):
			var z := top_z(x, y)
			if z < 0:
				continue
			var m := get_mat(x, y, z)
			if m == BODY or m == BELLY:
				set_shade(x, y, z, k * (0.94 + 0.12 * CityGen.hashf(x / K, y / K, 5)))


# ------------------------------------------------------------------ atlas

## Copy the voxels of plane `pi` into the index atlas (row pi, slice s at
## column s).
func write_into(data: PackedByteArray, aw: int, pi: int) -> void:
	for z in D:
		for y in W:
			var row := ((pi * W + y) * aw + z * W) * 4
			var vi := _i(0, y, z)
			for x in W:
				var m := mat[vi + x]
				if m == 0:
					continue
				var o := row + x * 4
				data[o] = m
				data[o + 1] = shd[vi + x]
				data[o + 2] = flg[vi + x]
				data[o + 3] = 255


## Index atlas for all planes (built once, cached in user://cache).
static func build_atlas(aw: int, ah: int) -> Image:
	var key := "%d_%d" % [VERSION, absi(hash(var_to_str(ART)) + hash(var_to_str(Planes.LIST)))]
	var path := "user://cache/planes_%s.png" % key
	var use_cache := not OS.get_cmdline_user_args().has("--no-plane-cache")
	if use_cache and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and img.get_width() == aw and img.get_height() == ah:
			img.convert(Image.FORMAT_RGBA8)
			return img
	var data := PackedByteArray()
	data.resize(aw * ah * 4)
	data.fill(0)
	var b := PlaneArt.new()
	for pi in Planes.LIST.size():
		b.build(pi)
		b.write_into(data, aw, pi)
	var out := Image.create_from_data(aw, ah, false, Image.FORMAT_RGBA8, data)
	if use_cache:
		DirAccess.make_dir_recursive_absolute("user://cache")
		var dir := DirAccess.open("user://cache")
		if dir != null:
			for f in dir.get_files():
				if f.begins_with("planes_"):
					dir.remove(f)
		out.save_png(path)
	return out


## Palette: MATS columns x (skins * 3 classes) rows.
static func palette_image() -> Image:
	var rows := Planes.SKINS.size() * 3
	var img := Image.create(MATS, rows, false, Image.FORMAT_RGBA8)
	for si in Planes.SKINS.size():
		var sk: Dictionary = Planes.SKINS[si]
		for c in 3:
			var fb: Array = Planes.FACTORY_BODY[c]
			var body := Color(sk["body"]) if sk["body"] != "" else Color(fb[0])
			var dark := Color(sk["dark"]) if sk["dark"] != "" else Color(fb[1])
			var light := Color(sk["light"]) if sk["light"] != "" else Color(fb[2])
			var acc := Color(sk["acc"])
			var canopy := Color(sk["canopy"])
			var col := {
				BODY: body, BELLY: light.lerp(body, 0.25), LIGHT: light, ACC: acc,
				GLASS: canopy.darkened(0.1), GLASS_HI: canopy.lightened(0.55), FRAME: dark.darkened(0.3),
				METAL: Color("9ea4ad"), METAL_D: Color("3c3f47"), BURN: Color("6e5c6a"), GLOW: Color("ffb43c"),
				INTAKE: Color("111216"), RADOME: body.darkened(0.16).lerp(Color("5a5e66"), 0.3),
				ANTIGLARE: dark.darkened(0.45), MSL: Color("e4e7ec"), MSL_D: Color("33363e"), MSL_BAND: Color("e2b33c"),
				TANK: body.lightened(0.05), BOMB: Color("4f5b3d"), ROUNDEL_O: Color("1d2740"), ROUNDEL_I: Color("f2f1ea"),
				NAV_R: Color("ff3a30"), NAV_G: Color("3aff6a"), STROBE: Color("ffffff"), PILOT: Color("e9e5da"),
				STENCIL: Color("e8c84a"), RED: Color("c8302a"), POD: Color("41454d"),
				CAMO: Color(sk["camo"]) if sk["camo"] != "" else body,
				PATTERN: Color(0, 0, 0, float(sk["pattern"]) / 255.0), # alpha: not colour-converted
			}
			for m in col:
				img.set_pixel(m, si * 3 + c, col[m])
	return img
