class_name CityGen
extends RefCounted
## Deterministic, thread-safe procedural city. Everything is a pure function of
## world coordinates, so chunks can be generated on worker threads and the
## gameplay code (traffic, enemies) can query the same layout.
##
## Layout: streets every 64 units on both axes (16 wide, centred on multiples
## of 64), 48x48 lots between them. Chunks are 256x256 (4x4 blocks).

const BLOCK := 64.0
const HALF_ST := 8.0
const LOT := 48.0
const CHUNK := 256.0
const BPC := 4
## The city is generated in "virtual" units and every chunk is rendered at
## scale S, so the whole world (buildings, roads, props, islands) is S times
## bigger than the jet. Gameplay code works in world units (the *_w helpers).
const S := 2.0
const WBLOCK := 64.0 * S
const WCHUNK := 256.0 * S
const JET_ALT := 220.0 # world: default cruise altitude (above almost every roof)
const LOW_ALT := 150.0 # world: below this you are "low flying" between towers

## Island heightmap: 256x256 bytes tiling every 256*24 world units. 0.5 = sea
## level. Shared with the GPU (global "island_tex") so land/water always match.
const ISL_N := 256
const ISL_CELL := 24.0
const SEA := 0.5
const SAND_TOP := 0.525
const URBAN_H := 0.565
static var isl := PackedByteArray()
static var forest := PackedByteArray() # 128x128 forest/cloud noise
const FOREST_N := 128
const FOREST_SCALE := 2200.0

enum { D_DOWNTOWN, D_MIDTOWN, D_RESIDENTIAL, D_INDUSTRIAL, D_PARK, D_STADIUM, D_FOREST, D_MEADOW, D_WATER }
const DISTRICT_NAMES := ["DOWNTOWN", "MIDTOWN", "RESIDENTIAL", "PORT", "PARK", "STADIUM", "FOREST", "MEADOW", "WATER"]

# facade / roof / ground indices (mirrors Stacks constants; duplicated so this
# file never touches nodes from worker threads)
const F_GLASS := 0
const F_GLASS_DARK := 1
const F_OFFICE := 2
const F_BRICK := 3
const F_WHITE := 4
const F_WAREHOUSE := 5
const F_FACTORY := 6
const F_BEIGE := 7
const F_STADIUM := 8
const F_HANGAR := 9
const F_TERMINAL := 10
const F_WOOD := 11
const F_LUX := 12
const F_MODERN := 13
const F_RUBBLE := 14
const F_GREEN := 15
const R_GRAVEL := 0
const R_TAR := 1
const R_GREEN := 2
const R_TILES := 3
const R_METAL := 4
const R_CONCRETE := 5
const R_FIELD := 6
const R_RUBBLE := 7
const G_ASPHALT := 0
const G_DASH := 1
const G_SIDEWALK := 2
const G_GRASS := 3
const G_PLAZA := 4
const G_WATER := 5
const G_SAND := 6
const G_RUNWAY := 7
const G_CROSS := 8
const G_RAILS := 9
const G_DIRT := 10
const G_PARKING := 11
const G_FIELD := 12
const G_PATH := 13
const G_DEEP := 14
const G_SLABS := 15

enum { PK_TOWER, PK_MID, PK_HOUSE, PK_FLAT }

const LAMP_GLOW := Color(1.0, 0.8, 0.5, 0.55)


class Build:
	var g := MeshBuf.new()
	var b := MeshBuf.new()
	var p := MeshBuf.new()
	var gl := MeshBuf.new()
	var boxes := PackedFloat32Array()
	var ids := PackedInt64Array()
	var roofs := PackedFloat32Array()
	var chimneys := PackedFloat32Array()
	var sheets: Dictionary
	var destroyed: Dictionary
	var cx := 0
	var cz := 0

	func _init() -> void:
		b.use_uv2 = true


# ------------------------------------------------------------------ hashing / noise

static func hashi(x: int, z: int, s: int) -> int:
	var h: int = ((x * 73856093) ^ (z * 19349663) ^ (s * 83492791)) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	return h ^ (h >> 16)


static func hashf(x: int, z: int, s: int) -> float:
	return float(hashi(x, z, s) & 0xFFFFFF) / 16777216.0


static func vnoise(x: float, z: float, salt: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := hashf(ix, iz, salt)
	var b := hashf(ix + 1, iz, salt)
	var c := hashf(ix, iz + 1, salt)
	var d := hashf(ix + 1, iz + 1, salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


# ------------------------------------------------------------------ geography

static func set_maps(island: Image, forest_img: Image) -> void:
	var i := island.duplicate() as Image
	i.convert(Image.FORMAT_L8)
	isl = i.get_data()
	var f := forest_img.duplicate() as Image
	f.convert(Image.FORMAT_L8)
	forest = f.get_data()


## Island height at a world point (bilinear, identical to the terrain shader).
static func island_h(x: float, z: float) -> float:
	if isl.is_empty():
		return 0.8
	var u := x / ISL_CELL - 0.5
	var v := z / ISL_CELL - 0.5
	var ix := floori(u)
	var iz := floori(v)
	var fx := u - ix
	var fz := v - iz
	var x0 := posmod(ix, ISL_N)
	var x1 := posmod(ix + 1, ISL_N)
	var z0 := posmod(iz, ISL_N) * ISL_N
	var z1 := posmod(iz + 1, ISL_N) * ISL_N
	var a := lerpf(isl[z0 + x0], isl[z0 + x1], fx)
	var b := lerpf(isl[z1 + x0], isl[z1 + x1], fx)
	return lerpf(a, b, fz) / 255.0


## World-unit versions for gameplay code.
static func island_hw(x: float, z: float) -> float:
	return island_h(x / S, z / S)


static func is_water_w(x: float, z: float) -> bool:
	return island_h(x / S, z / S) < SEA


static func is_land(x: float, z: float, margin: float = 0.0) -> bool:
	return island_h(x, z) > SAND_TOP + margin


static func is_water(x: float, z: float) -> bool:
	return island_h(x, z) < SEA


static func forest_v(x: float, z: float) -> float:
	if forest.is_empty():
		return 0.0
	var u := posmod(floori(fposmod(x / FOREST_SCALE + 0.37, 1.0) * FOREST_N), FOREST_N)
	var v := posmod(floori(fposmod(z / FOREST_SCALE + 0.61, 1.0) * FOREST_N), FOREST_N)
	return forest[v * FOREST_N + u] / 255.0


## 0..1 "how much city": main city around the origin plus small towns.
static func city_val(x: float, z: float) -> float:
	var v := exp(-(x * x + z * z) / (1150.0 * 1150.0))
	var g := 2600.0
	var gx := floori(x / g)
	var gz := floori(z / g)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cx := gx + dx
			var cz := gz + dz
			if (absi(cx) <= 1 and absi(cz) <= 1) or hashf(cx, cz, 41) > 0.55:
				continue
			var tx := (cx + 0.25 + hashf(cx, cz, 42) * 0.5) * g
			var tz := (cz + 0.25 + hashf(cx, cz, 43) * 0.5) * g
			if island_h(tx, tz) < 0.62:
				continue
			var d2 := (x - tx) * (x - tx) + (z - tz) * (z - tz)
			v = maxf(v, 0.62 * exp(-d2 / (520.0 * 520.0)))
	return v


static func is_urban(bx: int, bz: int) -> bool:
	var cxw := (bx + 0.5) * BLOCK
	var czw := (bz + 0.5) * BLOCK
	var cv := city_val(cxw, czw)
	if cv < 0.22:
		return false
	# whole block incl. surrounding streets must be solid land
	var x0 := bx * BLOCK - HALF_ST
	var z0 := bz * BLOCK - HALF_ST
	var x1 := x0 + BLOCK + 2.0 * HALF_ST
	var z1 := z0 + BLOCK + 2.0 * HALF_ST
	if island_h(cxw, czw) < URBAN_H:
		return false
	for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		if island_h(p.x, p.y) < URBAN_H - 0.02:
			return false
	# sparse outskirts: leave green gaps between blocks
	if cv < 0.45 and hashf(bx, bz, 19) < 0.3:
		return false
	return true


static func district(bx: int, bz: int) -> int:
	var cxw := (bx + 0.5) * BLOCK
	var czw := (bz + 0.5) * BLOCK
	var hc := island_h(cxw, czw)
	if not is_urban(bx, bz):
		if hc < SAND_TOP + 0.01:
			return D_WATER
		return D_FOREST if forest_v(cxw, czw) > 0.55 else D_MEADOW
	var cv := city_val(cxw, czw)
	var h := hashf(bx, bz, 3)
	if cv > 0.86:
		if h < 0.22:
			return D_PARK
		if h < 0.3:
			return D_MIDTOWN
		return D_DOWNTOWN
	if cv > 0.62:
		if h < 0.16:
			return D_PARK
		if h < 0.19:
			return D_STADIUM
		return D_MIDTOWN
	if hc < 0.6 and h < 0.6:
		return D_INDUSTRIAL
	if h < 0.25:
		return D_PARK
	return D_RESIDENTIAL


## Is there a street here? along_x = car drives along X (horizontal street).
static func is_drivable(x: float, z: float, along_x: bool) -> bool:
	if along_x:
		var row := roundi(z / BLOCK)
		var bx := floori(x / BLOCK)
		return is_urban(bx, row - 1) or is_urban(bx, row)
	var col := roundi(x / BLOCK)
	var bz := floori(z / BLOCK)
	return is_urban(col - 1, bz) or is_urban(col, bz)


static func building_id(bx: int, bz: int, i: int) -> int:
	return ((bx + 1000000) * 2000000 + (bz + 1000000)) * 32 + i


# ------------------------------------------------------------------ chunk generation

static func generate_chunk(cx: int, cz: int, sheets: Dictionary, destroyed: Dictionary) -> Dictionary:
	var cb := Build.new()
	cb.sheets = sheets
	cb.destroyed = destroyed
	cb.cx = cx
	cb.cz = cz
	var urban := {}
	for bz in range(cz * BPC - 1, cz * BPC + BPC + 1):
		for bx in range(cx * BPC - 1, cx * BPC + BPC + 1):
			urban[Vector2i(bx, bz)] = is_urban(bx, bz)
	for bz in range(cz * BPC, cz * BPC + BPC):
		for bx in range(cx * BPC, cx * BPC + BPC):
			_block(cb, bx, bz, urban[Vector2i(bx, bz)])
	_markings(cb, cx, cz, urban)
	return {
		"key": Vector2i(cx, cz),
		"ground": cb.g.to_arrays() if not cb.g.is_empty() else [],
		"build": cb.b.to_arrays() if not cb.b.is_empty() else [],
		"props": cb.p.to_arrays() if not cb.p.is_empty() else [],
		"glow": cb.gl.to_arrays() if not cb.gl.is_empty() else [],
		"boxes": cb.boxes,
		"ids": cb.ids,
		"roofs": cb.roofs,
		"chimneys": cb.chimneys,
		"quads": cb.g.quad_count() + cb.b.quad_count() + cb.p.quad_count(),
	}


# ------------------------------------------------------------------ helpers

static func _facade_uv(style: int) -> Vector2:
	return Vector2(float((style % 8) * 32) / 256.0, float((style / 8) * 24) / 128.0)


static func _roof_uv(style: int) -> Vector2:
	return Vector2(float(style * 32) / 256.0, 48.0 / 128.0)


static func _stack(cb: Build, sheet: String, variant: int, pos: Vector3, yaw: float, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	cb.p.add_stack(cb.sheets[sheet], variant, pos, yaw, scale, tint, 2)


static func _glow(cb: Build, x: float, z: float, size: float, col: Color) -> void:
	var h := size * 0.5
	var y := 0.45
	cb.gl.quad(Vector3(x - h, y, z - h), Vector3(x + h, y, z - h), Vector3(x + h, y, z + h), Vector3(x - h, y, z + h),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), col)


## Free-form horizontal quad with world-tiling ground UVs.
static func _gquad(mb: MeshBuf, a: Vector2, b: Vector2, c: Vector2, d: Vector2, y: float, tile_idx: int, tint: Color = Color.WHITE) -> void:
	var col := tint
	col.a = (float(tile_idx) + 0.5) / 16.0
	mb.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y),
		a / 16.0, b / 16.0, c / 16.0, d / 16.0, col)


## Vertical quad in the ground mesh (railings, ramps sides).
static func _gwall(mb: MeshBuf, a: Vector3, b: Vector3, h: float, tile_idx: int, shade: float) -> void:
	var col := Color(shade, shade, shade, (float(tile_idx) + 0.5) / 16.0)
	var l := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	mb.quad(Vector3(a.x, a.y + h, a.z), Vector3(b.x, b.y + h, b.z), b, a,
		Vector2(0, 0), Vector2(l / 16.0, 0), Vector2(l / 16.0, h / 16.0), Vector2(0, h / 16.0), col)


static func _wall(cb: Build, a: Vector3, b: Vector3, top: float, shade: float, bot: float, fuv: Vector2, seed: float, u0: float, u1: float) -> void:
	var ct := Color(shade, shade, shade, seed)
	var cbm := Color(shade * bot, shade * bot, shade * bot, seed)
	cb.b.quad_c(Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), b, a,
		Vector2(u0 / 32.0, -top / 24.0), Vector2(u1 / 32.0, -top / 24.0), Vector2(u1 / 32.0, -a.y / 24.0), Vector2(u0 / 32.0, -a.y / 24.0),
		ct, ct, cbm, cbm, fuv)


## Collapsed stack: 4 textured walls (texture rows = slices) + roof.
static func _box(cb: Build, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, style: int, roof: int, seed: float, ground: bool) -> void:
	var fuv := _facade_uv(style)
	var bot := 0.72 if ground else 1.0
	# south (+Z, faces default camera), west (lit), east, north
	_wall(cb, Vector3(x0, y0, z1), Vector3(x1, y0, z1), y1, 0.84, bot, fuv, seed, x0, x1)
	_wall(cb, Vector3(x0, y0, z0), Vector3(x0, y0, z1), y1, 1.0, bot, fuv, seed, z0, z1)
	_wall(cb, Vector3(x1, y0, z1), Vector3(x1, y0, z0), y1, 0.66, bot, fuv, seed, z1, z0)
	_wall(cb, Vector3(x1, y0, z0), Vector3(x0, y0, z0), y1, 0.74, bot, fuv, seed, x1, x0)
	var ruv := _roof_uv(roof)
	var rim := Color(0.62, 0.62, 0.62, seed)
	cb.b.quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1),
		Vector2(x0, z0) / 32.0, Vector2(x1, z0) / 32.0, Vector2(x1, z1) / 32.0, Vector2(x0, z1) / 32.0, rim, ruv)
	if x1 - x0 > 5.0 and z1 - z0 > 5.0:
		var i := 1.2
		var y := y1 + 0.25
		var c := Color(1, 1, 1, seed)
		cb.b.quad(Vector3(x0 + i, y, z0 + i), Vector3(x1 - i, y, z0 + i), Vector3(x1 - i, y, z1 - i), Vector3(x0 + i, y, z1 - i),
			Vector2(x0 + i, z0 + i) / 32.0, Vector2(x1 - i, z0 + i) / 32.0, Vector2(x1 - i, z1 - i) / 32.0, Vector2(x0 + i, z1 - i) / 32.0, c, ruv)


static func _reg(cb: Build, id: int, x0: float, z0: float, x1: float, z1: float, h: float) -> void:
	cb.boxes.append(x0)
	cb.boxes.append(z0)
	cb.boxes.append(x1)
	cb.boxes.append(z1)
	cb.boxes.append(h)
	cb.ids.append(id)


static func _building(cb: Build, rng: RandomNumberGenerator, id: int, x0: float, z0: float, x1: float, z1: float, h: float, style: int, roof: int, kind: int) -> void:
	var seed := rng.randf()
	if cb.destroyed.has(id):
		_box(cb, x0, z0, x1, z1, 0.0, 3.0, F_RUBBLE, R_RUBBLE, seed, true)
		_reg(cb, id, x0, z0, x1, z1, 3.0)
		return
	var w := x1 - x0
	var d := z1 - z0
	var t := Rect2(x0, z0, w, d)
	if h > 95.0 and minf(w, d) >= 18.0 and rng.randf() < 0.7:
		var h1 := h * rng.randf_range(0.55, 0.75)
		_box(cb, x0, z0, x1, z1, 0.0, h1, style, roof, seed, true)
		var ins := rng.randf_range(2.5, minf(w, d) * 0.22)
		t = Rect2(x0 + ins, z0 + ins, w - ins * 2.0, d - ins * 2.0)
		_box(cb, t.position.x, t.position.y, t.end.x, t.end.y, h1, h, style, roof, seed, false)
	else:
		_box(cb, x0, z0, x1, z1, 0.0, h, style, roof, seed, true)
	_reg(cb, id, x0, z0, x1, z1, h)
	if h > LOW_ALT - 15.0:
		cb.roofs.append(t.get_center().x)
		cb.roofs.append(t.get_center().y)
		cb.roofs.append(h)
	_roof_props(cb, rng, t, h, kind)


static func _roof_props(cb: Build, rng: RandomNumberGenerator, t: Rect2, y: float, kind: int) -> void:
	var w := t.size.x
	var d := t.size.y
	var c := t.get_center()
	if kind == PK_TOWER and minf(w, d) >= 27.0 and rng.randf() < 0.45:
		_stack(cb, "helipad", 0, Vector3(c.x, y + 0.4, c.y), 0.0)
		return
	if kind == PK_TOWER and rng.randf() < 0.65:
		_stack(cb, "antenna", 0, Vector3(c.x + rng.randf_range(-w, w) * 0.2, y + 0.3, c.y + rng.randf_range(-d, d) * 0.2), 0.0)
	if kind == PK_HOUSE:
		if rng.randf() < 0.3:
			_stack(cb, "ac_unit", 0, Vector3(c.x, y + 0.3, c.y), 0.0, 0.7)
		return
	var n := rng.randi_range(0, 2 + int(w * d / 500.0))
	for i in mini(n, 5):
		var px := t.position.x + 4.0 + rng.randf() * maxf(0.0, w - 8.0)
		var pz := t.position.y + 4.0 + rng.randf() * maxf(0.0, d - 8.0)
		_stack(cb, "ac_unit", 0, Vector3(px, y + 0.3, pz), PI * 0.5 * rng.randi_range(0, 3))
	if rng.randf() < 0.3 and minf(w, d) > 12.0:
		_stack(cb, "water_tank", 0, Vector3(t.position.x + 6.0, y + 0.3, t.end.y - 6.0), 0.0)
	if rng.randf() < 0.4 and w >= 24.0 and d >= 10.0:
		var side := rng.randi_range(0, 3)
		var v := rng.randi_range(0, 2)
		match side:
			0:
				_stack(cb, "neon_sign", v, Vector3(c.x, y + 0.3, t.end.y - 2.0), PI)
			1:
				_stack(cb, "neon_sign", v, Vector3(t.position.x + 2.0, y + 0.3, c.y), -PI * 0.5)
			2:
				_stack(cb, "neon_sign", v, Vector3(t.end.x - 2.0, y + 0.3, c.y), PI * 0.5)
			_:
				_stack(cb, "neon_sign", v, Vector3(c.x, y + 0.3, t.position.y + 2.0), 0.0)


## Split a rect into 1, 2 or 4 parcels.
static func _split(rng: RandomNumberGenerator, r: Rect2, mode: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	match mode:
		0:
			out.append(r)
		1:
			var f := rng.randf_range(0.4, 0.6)
			if rng.randf() < 0.5:
				out.append(Rect2(r.position, Vector2(r.size.x * f, r.size.y)))
				out.append(Rect2(r.position + Vector2(r.size.x * f, 0), Vector2(r.size.x * (1.0 - f), r.size.y)))
			else:
				out.append(Rect2(r.position, Vector2(r.size.x, r.size.y * f)))
				out.append(Rect2(r.position + Vector2(0, r.size.y * f), Vector2(r.size.x, r.size.y * (1.0 - f))))
		_:
			var fx := rng.randf_range(0.4, 0.6)
			var fz := rng.randf_range(0.4, 0.6)
			var a := r.size.x * fx
			var b := r.size.y * fz
			out.append(Rect2(r.position, Vector2(a, b)))
			out.append(Rect2(r.position + Vector2(a, 0), Vector2(r.size.x - a, b)))
			out.append(Rect2(r.position + Vector2(0, b), Vector2(a, r.size.y - b)))
			out.append(Rect2(r.position + Vector2(a, b), Vector2(r.size.x - a, r.size.y - b)))
	return out


static func _lamps(cb: Build, lx0: float, lz0: float, lx1: float, lz1: float) -> void:
	var lamp: Object = cb.sheets["lamp"]
	for k in 2:
		var f := 12.0 + k * 24.0
		# [x, z, dir_x, dir_z]
		var spots := [
			[lx0 + f, lz0 + 1.5, 0.0, -1.0], [lx0 + f, lz1 - 1.5, 0.0, 1.0],
			[lx0 + 1.5, lz0 + f, -1.0, 0.0], [lx1 - 1.5, lz0 + f, 1.0, 0.0],
		]
		for s in spots:
			var yaw := atan2(-s[3], s[2])
			cb.p.add_stack(lamp, 0, Vector3(s[0], 0.2, s[1]), yaw, 1.0, Color.WHITE, 2)
			_glow(cb, s[0] + s[2] * 3.5, s[1] + s[3] * 3.5, 15.0, LAMP_GLOW)


static func _trees(cb: Build, rng: RandomNumberGenerator, r: Rect2, n: int, avoid: Array[Rect2], pine_bias: float = 0.25) -> void:
	for i in n:
		var x := r.position.x + rng.randf() * r.size.x
		var z := r.position.y + rng.randf() * r.size.y
		var ok := true
		for a in avoid:
			if a.grow(4.0).has_point(Vector2(x, z)):
				ok = false
				break
		if not ok or island_h(x, z) < URBAN_H - 0.03:
			continue
		var v := 1 if rng.randf() < pine_bias else (2 if rng.randf() < 0.12 else 0)
		_stack(cb, "tree", v, Vector3(x, 0.2, z), rng.randf() * TAU, rng.randf_range(0.8, 1.25))


# ------------------------------------------------------------------ blocks

static func _block(cb: Build, bx: int, bz: int, urban: bool) -> void:
	var d := district(bx, bz)
	var lx0 := bx * BLOCK + HALF_ST
	var lz0 := bz * BLOCK + HALF_ST
	var lx1 := lx0 + LOT
	var lz1 := lz0 + LOT
	var rng := RandomNumberGenerator.new()
	rng.seed = hashi(bx, bz, 11)
	if not urban:
		_nature(cb, rng, bx, bz, d)
		return
	# streets around the block (adjacent urban blocks overlap seamlessly)
	cb.g.ground_rect(bx * BLOCK - HALF_ST, bz * BLOCK - HALF_ST, (bx + 1) * BLOCK + HALF_ST, (bz + 1) * BLOCK + HALF_ST, 0.1, G_ASPHALT)
	cb.g.ground_rect(lx0, lz0, lx1, lz1, 0.2, G_SIDEWALK)
	var inner := Rect2(lx0 + 3.0, lz0 + 3.0, LOT - 6.0, LOT - 6.0)
	var tile := G_GRASS
	match d:
		D_DOWNTOWN:
			tile = G_PLAZA
		D_MIDTOWN, D_INDUSTRIAL:
			tile = G_SLABS
	cb.g.ground_rect(inner.position.x, inner.position.y, inner.end.x, inner.end.y, 0.25, tile)
	var cv := city_val((bx + 0.5) * BLOCK, (bz + 0.5) * BLOCK)
	match d:
		D_DOWNTOWN:
			# one or two towers on a plaza, heights vary a lot
			var parts := _split(rng, inner, 0 if rng.randf() < 0.55 else 1)
			for i in parts.size():
				var r: Rect2 = parts[i].grow(-rng.randf_range(4.0, 8.0))
				if i == 1 and rng.randf() < 0.4:
					_trees(cb, rng, parts[i], rng.randi_range(2, 4), [])
					continue
				var h := 22.0 + pow(rng.randf(), 2.2) * 135.0 * clampf((cv - 0.8) * 4.0, 0.4, 1.0)
				var styles := [F_GLASS, F_GLASS_DARK, F_OFFICE, F_LUX, F_MODERN, F_GREEN]
				var roofs := [R_TAR, R_GRAVEL, R_METAL]
				_building(cb, rng, building_id(bx, bz, i), r.position.x, r.position.y, r.end.x, r.end.y, h,
					styles[rng.randi() % styles.size()], roofs[rng.randi() % roofs.size()], PK_TOWER)
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_MIDTOWN:
			var parts := _split(rng, inner, rng.randi_range(0, 1))
			for i in parts.size():
				var r: Rect2 = parts[i].grow(-rng.randf_range(2.0, 5.0))
				var h := 14.0 + rng.randf() * 36.0
				var styles := [F_OFFICE, F_BRICK, F_BEIGE, F_MODERN, F_WHITE]
				var roofs := [R_GRAVEL, R_TAR, R_GREEN]
				_building(cb, rng, building_id(bx, bz, i), r.position.x, r.position.y, r.end.x, r.end.y, h,
					styles[rng.randi() % styles.size()], roofs[rng.randi() % roofs.size()], PK_MID)
			_trees(cb, rng, inner, rng.randi_range(0, 3), [])
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_RESIDENTIAL:
			var houses: Array[Rect2] = []
			var n := rng.randi_range(2, 4)
			var cells := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
			cells.shuffle()
			var cw := inner.size.x / 2.0
			for i in n:
				var c: Vector2 = cells[i]
				var hw := rng.randf_range(9.0, 14.0)
				var hd := rng.randf_range(9.0, 13.0)
				var hx := inner.position.x + c.x * cw + rng.randf_range(1.5, cw - hw - 1.5)
				var hz := inner.position.y + c.y * cw + rng.randf_range(1.5, cw - hd - 1.5)
				var r := Rect2(hx, hz, hw, hd)
				houses.append(r)
				var styles := [F_WHITE, F_WOOD, F_BRICK, F_BEIGE]
				var roofs := [R_TILES, R_TILES, R_GREEN, R_TILES]
				_building(cb, rng, building_id(bx, bz, i), r.position.x, r.position.y, r.end.x, r.end.y,
					rng.randf_range(6.0, 11.0), styles[rng.randi() % styles.size()], roofs[rng.randi() % roofs.size()], PK_HOUSE)
			_trees(cb, rng, inner, rng.randi_range(4, 8), houses)
		D_INDUSTRIAL:
			_building(cb, rng, building_id(bx, bz, 0), inner.position.x + 1.0, inner.position.y + 1.0, inner.end.x - 1.0, inner.position.y + 18.0,
				rng.randf_range(10.0, 16.0), F_WAREHOUSE, R_METAL, PK_FLAT)
			for row in 2:
				for k in 3:
					if rng.randf() < 0.3:
						continue
					var p := Vector3(inner.position.x + 6.0 + k * 13.0, 0.25, inner.position.y + 27.0 + row * 9.0)
					_stack(cb, "container", rng.randi() % 4, p, PI * 0.5)
			if rng.randf() < 0.35:
				_stack(cb, "crane", 0, Vector3(inner.end.x - 8.0, 0.25, inner.end.y - 8.0), rng.randf() * TAU)
			elif rng.randf() < 0.4:
				var chx := inner.end.x - 6.0
				var chz := inner.end.y - 6.0
				_stack(cb, "chimney", 0, Vector3(chx, 0.25, chz), 0.0)
				cb.chimneys.append(chx)
				cb.chimneys.append(36.0)
				cb.chimneys.append(chz)
		D_PARK:
			var avoid: Array[Rect2] = []
			var c := inner.get_center()
			cb.g.ground_rect(c.x - 2.0, inner.position.y, c.x + 2.0, inner.end.y, 0.28, G_PATH)
			cb.g.ground_rect(inner.position.x, c.y - 2.0, inner.end.x, c.y + 2.0, 0.28, G_PATH)
			avoid.append(Rect2(c.x - 2.0, inner.position.y, 4.0, inner.size.y))
			avoid.append(Rect2(inner.position.x, c.y - 2.0, inner.size.x, 4.0))
			if rng.randf() < 0.6:
				_stack(cb, "fountain", 0, Vector3(c.x, 0.3, c.y), 0.0)
				avoid.append(Rect2(c.x - 9.0, c.y - 9.0, 18.0, 18.0))
			_trees(cb, rng, inner, rng.randi_range(7, 12), avoid, 0.2)
			for k in rng.randi_range(2, 5):
				var p := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
				_stack(cb, "bush", rng.randi() % 2, Vector3(p.x, 0.25, p.y), rng.randf() * TAU)
		D_STADIUM:
			_stadium(cb, inner)


## Forests, meadows and beaches outside the city (no roads).
static func _nature(cb: Build, rng: RandomNumberGenerator, bx: int, bz: int, d: int) -> void:
	if d == D_WATER:
		return
	var r := Rect2(bx * BLOCK, bz * BLOCK, BLOCK, BLOCK)
	var n := 0
	match d:
		D_FOREST:
			n = rng.randi_range(9, 15)
		D_MEADOW:
			n = rng.randi_range(0, 3)
	for i in n:
		var x := r.position.x + rng.randf() * BLOCK
		var z := r.position.y + rng.randf() * BLOCK
		if island_h(x, z) < SAND_TOP + 0.012:
			continue
		var v := 1 if (d == D_FOREST and rng.randf() < 0.55) else 0
		_stack(cb, "tree", v, Vector3(x, 0.0, z), rng.randf() * TAU, rng.randf_range(0.9, 1.4))
	if d == D_MEADOW:
		for i in rng.randi_range(0, 3):
			var x := r.position.x + rng.randf() * BLOCK
			var z := r.position.y + rng.randf() * BLOCK
			if island_h(x, z) > SAND_TOP + 0.01:
				_stack(cb, "bush", rng.randi() % 2, Vector3(x, 0.0, z), rng.randf() * TAU)


static func _stadium(cb: Build, r: Rect2) -> void:
	var c := r.get_center()
	cb.g.ground_rect(c.x - 13.0, c.y - 10.0, c.x + 13.0, c.y + 10.0, 0.26, G_FIELD, Color.WHITE, 16.0, true)
	var n := 20
	var ro := Vector2(r.size.x * 0.5 - 0.5, r.size.y * 0.5 - 1.5)
	var ri := ro - Vector2(8.0, 7.0)
	var fuv := _facade_uv(F_STADIUM)
	var ruv := _roof_uv(R_CONCRETE)
	var seed := 0.5
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := c + Vector2(cos(a0), sin(a0)) * ro
		var o1 := c + Vector2(cos(a1), sin(a1)) * ro
		var i0 := c + Vector2(cos(a0), sin(a0)) * ri
		var i1 := c + Vector2(cos(a1), sin(a1)) * ri
		var nrm := Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5))
		var shade := 0.75 + 0.25 * clampf(-nrm.x * 0.6 + nrm.y * 0.4, -1.0, 1.0)
		var u0 := float(i) * 12.0
		_wall(cb, Vector3(o0.x, 0.0, o0.y), Vector3(o1.x, 0.0, o1.y), 13.0, shade, 0.75, fuv, seed, u0, u0 + o0.distance_to(o1))
		_wall(cb, Vector3(i1.x, 0.0, i1.y), Vector3(i0.x, 0.0, i0.y), 4.0, 0.7, 1.0, fuv, seed, u0, u0 + i0.distance_to(i1))
		var col := Color(0.9, 0.9, 0.9, seed)
		cb.b.quad(Vector3(o0.x, 13.0, o0.y), Vector3(o1.x, 13.0, o1.y), Vector3(i1.x, 4.0, i1.y), Vector3(i0.x, 4.0, i0.y),
			o0 / 32.0, o1 / 32.0, i1 / 32.0, i0 / 32.0, col, ruv)
	_reg(cb, building_id(floori(c.x / BLOCK), floori(c.y / BLOCK), 0), r.position.x, r.position.y, r.end.x, r.end.y, 13.0)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var p := c + Vector2(cos(a), sin(a)) * (ro + Vector2(1.0, 1.0))
		_stack(cb, "lamp", 0, Vector3(p.x, 0.2, p.y), atan2(sin(a), -cos(a)), 2.0)


# ------------------------------------------------------------------ roads, river, sea

static func _markings(cb: Build, cx: int, cz: int, urban: Dictionary) -> void:
	# horizontal streets (run along X) at z = row * 64
	for row in range(cz * BPC, cz * BPC + BPC):
		var z := row * BLOCK
		for bx in range(cx * BPC, cx * BPC + BPC):
			if not (urban[Vector2i(bx, row - 1)] or urban[Vector2i(bx, row)]):
				continue
			var sx := bx * BLOCK + HALF_ST
			cb.g.ground_rect(sx + 5.0, z - 0.75, sx + LOT - 5.0, z + 0.75, 0.15, G_DASH)
			cb.g.ground_rect(sx + 1.0, z - 7.0, sx + 4.0, z + 7.0, 0.15, G_CROSS, Color.WHITE, 16.0, true)
			cb.g.ground_rect(sx + LOT - 4.0, z - 7.0, sx + LOT - 1.0, z + 7.0, 0.15, G_CROSS, Color.WHITE, 16.0, true)
	# vertical streets (run along Z) at x = col * 64
	for col in range(cx * BPC, cx * BPC + BPC):
		var x := col * BLOCK
		for bz in range(cz * BPC, cz * BPC + BPC):
			if not (urban[Vector2i(col - 1, bz)] or urban[Vector2i(col, bz)]):
				continue
			var sz := bz * BLOCK + HALF_ST
			cb.g.ground_rect(x - 0.75, sz + 5.0, x + 0.75, sz + LOT - 5.0, 0.15, G_DASH, Color.WHITE, 16.0, true)
			cb.g.ground_rect(x - 7.0, sz + 1.0, x + 7.0, sz + 4.0, 0.15, G_CROSS)
			cb.g.ground_rect(x - 7.0, sz + LOT - 4.0, x + 7.0, sz + LOT - 1.0, 0.15, G_CROSS)
