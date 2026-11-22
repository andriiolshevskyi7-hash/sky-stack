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
const JET_ALT := 48.0
const RIVER_HALF := 34.0

enum { D_DOWNTOWN, D_MIDTOWN, D_RESIDENTIAL, D_INDUSTRIAL, D_PARK, D_HARBOR, D_WATER, D_AIRPORT, D_STADIUM, D_RIVERSIDE }
const DISTRICT_NAMES := ["DOWNTOWN", "MIDTOWN", "RESIDENTIAL", "INDUSTRIAL", "PARK", "HARBOR", "WATER", "AIRPORT", "STADIUM", "RIVERSIDE"]

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

static func river_z(x: float) -> float:
	return 700.0 + 240.0 * sin(x * 0.0019) + 90.0 * sin(x * 0.0043 + 1.3)


static func river_dz(x: float) -> float:
	return 240.0 * 0.0019 * cos(x * 0.0019) + 90.0 * 0.0043 * cos(x * 0.0043 + 1.3)


static func in_river(x: float, z: float, margin: float = 0.0) -> bool:
	return absf(z - river_z(x)) < RIVER_HALF + margin


static func coast_x(z: float) -> float:
	return 2000.0 + 260.0 * sin(z * 0.0011) + 90.0 * sin(z * 0.0037 + 0.7)


static func in_sea(x: float, z: float, margin: float = 0.0) -> bool:
	return x > coast_x(z) - margin


static func is_water(x: float, z: float) -> bool:
	return in_sea(x, z) or (in_river(x, z) and not is_airport(x, z))


## Airport occupies 3x2 chunks, repeating every 28 chunks. Returns the local
## chunk index inside the airport or (-1,-1).
static func airport_local(cx: int, cz: int) -> Vector2i:
	var ax := posmod(cx + 10, 28)
	var az := posmod(cz + 6, 28)
	if ax < 3 and az < 2:
		return Vector2i(ax, az)
	return Vector2i(-1, -1)


static func is_airport(x: float, z: float) -> bool:
	return airport_local(floori(x / CHUNK), floori(z / CHUNK)).x >= 0


static func is_rail_row(row: int) -> bool:
	return posmod(row, 11) == 4


static func block_hits_river(bx: int, bz: int) -> bool:
	var lx0 := bx * BLOCK + HALF_ST
	var lz0 := bz * BLOCK + HALF_ST
	for k in 4:
		var x := lx0 + LOT * k / 3.0
		var rz := river_z(x)
		if rz + RIVER_HALF + 3.0 > lz0 and rz - RIVER_HALF - 3.0 < lz0 + LOT:
			return true
	return false


static func downtown_value(x: float, z: float) -> float:
	return vnoise(x / 700.0, z / 700.0, 1) * 0.85 + 0.42 * exp(-(x * x + z * z) / (800.0 * 800.0))


static func district(bx: int, bz: int) -> int:
	var cxw := (bx + 0.5) * BLOCK
	var czw := (bz + 0.5) * BLOCK
	if is_airport(cxw, czw):
		return D_AIRPORT
	var coast := coast_x(czw)
	if cxw + 30.0 > coast:
		return D_WATER
	if block_hits_river(bx, bz):
		return D_RIVERSIDE
	if cxw > coast - 260.0:
		return D_HARBOR
	var d := downtown_value(cxw, czw)
	var ind := vnoise(cxw / 900.0 + 30.0, czw / 900.0 - 20.0, 2)
	var h := hashf(bx, bz, 3)
	if d > 0.86:
		if h < 0.07:
			return D_PARK
		return D_DOWNTOWN
	if d > 0.66:
		if h < 0.035:
			return D_STADIUM
		if h < 0.08:
			return D_PARK
		return D_MIDTOWN
	if ind > 0.64:
		return D_INDUSTRIAL
	if h < 0.09:
		return D_PARK
	if h < 0.1:
		return D_STADIUM
	return D_RESIDENTIAL


## Can a car be here? along_x = car drives along the X axis (horizontal street).
static func is_drivable(x: float, z: float, along_x: bool) -> bool:
	if x > coast_x(z) - 10.0:
		return false
	if is_airport(x, z):
		return false
	if along_x:
		if in_river(x, z, 6.0):
			return false
		if is_rail_row(roundi(z / BLOCK)):
			return false
	return true


static func building_id(bx: int, bz: int, i: int) -> int:
	return ((bx + 1000000) * 2000000 + (bz + 1000000)) * 32 + i


# ------------------------------------------------------------------ chunk generation

static func generate_chunk(cx: int, cz: int, sheets: Dictionary, destroyed: Dictionary) -> Dictionary:
	var cb := Build.new()
	cb.sheets = sheets
	cb.destroyed = destroyed
	cb.cx = cx
	cb.cz = cz
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	var ap := airport_local(cx, cz)
	if ap.x >= 0:
		_airport(cb, cx, cz, ap)
	else:
		var all_sea := in_sea(x0, z0, -4.0) and in_sea(x0, z0 + CHUNK, -4.0) and in_sea(x0, z0 + CHUNK * 0.5, -4.0)
		if not all_sea:
			cb.g.ground_rect(x0, z0, x0 + CHUNK, z0 + CHUNK, 0.0, G_ASPHALT)
			for bz in range(cz * BPC, cz * BPC + BPC):
				for bx in range(cx * BPC, cx * BPC + BPC):
					_block(cb, bx, bz)
			_markings(cb, cx, cz)
			_river(cb, cx, cz)
	_sea(cb, cx, cz)
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
	cb.p.add_stack(cb.sheets[sheet], variant, pos, yaw, scale, tint)


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
	if h > JET_ALT + 8.0:
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
			cb.p.add_stack(lamp, 0, Vector3(s[0], 0.2, s[1]), yaw, 1.0, Color.WHITE)
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
		if not ok or in_river(x, z, 6.0):
			continue
		var v := 1 if rng.randf() < pine_bias else (2 if rng.randf() < 0.12 else 0)
		_stack(cb, "tree", v, Vector3(x, 0.2, z), rng.randf() * TAU, rng.randf_range(0.8, 1.25))


# ------------------------------------------------------------------ blocks

static func _block(cb: Build, bx: int, bz: int) -> void:
	var d := district(bx, bz)
	var lx0 := bx * BLOCK + HALF_ST
	var lz0 := bz * BLOCK + HALF_ST
	var lx1 := lx0 + LOT
	var lz1 := lz0 + LOT
	var rng := RandomNumberGenerator.new()
	rng.seed = hashi(bx, bz, 11)
	if d == D_WATER:
		var coast := coast_x(lz0 + LOT * 0.5)
		if lx0 < coast:
			cb.g.ground_rect(lx0 - HALF_ST, lz0 - HALF_ST, minf(lx1 + HALF_ST, coast), lz1 + HALF_ST, 0.2, G_SLABS)
		return
	cb.g.ground_rect(lx0, lz0, lx1, lz1, 0.15, G_SIDEWALK)
	var inner := Rect2(lx0 + 3.0, lz0 + 3.0, LOT - 6.0, LOT - 6.0)
	var tile := G_GRASS
	match d:
		D_DOWNTOWN:
			tile = G_PLAZA
		D_MIDTOWN, D_HARBOR:
			tile = G_SLABS
		D_INDUSTRIAL:
			tile = G_DIRT
	cb.g.ground_rect(inner.position.x, inner.position.y, inner.end.x, inner.end.y, 0.2, tile)
	var dens := clampf(downtown_value((bx + 0.5) * BLOCK, (bz + 0.5) * BLOCK), 0.6, 1.3)
	match d:
		D_DOWNTOWN:
			var parts := _split(rng, inner, rng.randi_range(0, 2))
			for i in parts.size():
				var r: Rect2 = parts[i].grow(-rng.randf_range(1.0, 2.5))
				var h := 54.0 + pow(rng.randf(), 1.7) * 115.0 * dens
				var styles := [F_GLASS, F_GLASS_DARK, F_OFFICE, F_LUX, F_MODERN, F_GREEN]
				var roofs := [R_TAR, R_GRAVEL, R_METAL]
				_building(cb, rng, building_id(bx, bz, i), r.position.x, r.position.y, r.end.x, r.end.y, h,
					styles[rng.randi() % styles.size()], roofs[rng.randi() % roofs.size()], PK_TOWER)
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_MIDTOWN:
			var parts := _split(rng, inner, rng.randi_range(1, 2))
			for i in parts.size():
				var r: Rect2 = parts[i].grow(-rng.randf_range(1.0, 3.0))
				var h := 16.0 + rng.randf() * 40.0 * dens
				var styles := [F_OFFICE, F_BRICK, F_BEIGE, F_MODERN, F_WHITE]
				var roofs := [R_GRAVEL, R_TAR, R_GREEN]
				_building(cb, rng, building_id(bx, bz, i), r.position.x, r.position.y, r.end.x, r.end.y, h,
					styles[rng.randi() % styles.size()], roofs[rng.randi() % roofs.size()], PK_MID)
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_RESIDENTIAL:
			var nx := rng.randi_range(2, 3)
			var houses: Array[Rect2] = []
			var cw := inner.size.x / nx
			var ch := inner.size.y / 2.0
			var i := 0
			for gz in 2:
				for gx in nx:
					if rng.randf() < 0.15:
						continue
					var hw := rng.randf_range(10.0, minf(cw - 3.0, 17.0))
					var hd := rng.randf_range(10.0, ch - 5.0)
					var hx := inner.position.x + gx * cw + rng.randf_range(1.5, cw - hw - 1.5)
					var hz := inner.position.y + gz * ch + (2.0 if gz == 0 else ch - hd - 2.0)
					var r := Rect2(hx, hz, hw, hd)
					houses.append(r)
					var styles := [F_WHITE, F_WOOD, F_BRICK, F_BEIGE]
					var roofs := [R_TILES, R_TILES, R_GREEN, R_GRAVEL]
					_building(cb, rng, building_id(bx, bz, i), r.position.x, r.position.y, r.end.x, r.end.y,
						rng.randf_range(7.0, 13.0), styles[rng.randi() % styles.size()], roofs[rng.randi() % roofs.size()], PK_HOUSE)
					i += 1
			_trees(cb, rng, inner, rng.randi_range(3, 7), houses)
			for k in rng.randi_range(1, 3):
				var p := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
				var ok := true
				for hr in houses:
					if hr.grow(3.0).has_point(p):
						ok = false
				if ok:
					_stack(cb, "bush", rng.randi() % 2, Vector3(p.x, 0.2, p.y), rng.randf() * TAU)
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_INDUSTRIAL:
			var wd := rng.randf_range(16.0, 22.0)
			_building(cb, rng, building_id(bx, bz, 0), inner.position.x + 1.0, inner.position.y + 1.0, inner.end.x - 1.0, inner.position.y + wd,
				rng.randf_range(11.0, 18.0), F_WAREHOUSE, R_METAL, PK_FLAT)
			var fz0 := inner.position.y + wd + 4.0
			var fx1 := inner.position.x + rng.randf_range(18.0, 24.0)
			_building(cb, rng, building_id(bx, bz, 1), inner.position.x + 1.0, fz0, fx1, inner.end.y - 1.0,
				rng.randf_range(14.0, 24.0), F_FACTORY, R_TAR, PK_FLAT)
			var chx := inner.end.x - 7.0
			var chz := inner.end.y - 7.0
			_stack(cb, "chimney", 0, Vector3(chx, 0.2, chz), 0.0)
			cb.chimneys.append(chx)
			cb.chimneys.append(36.0)
			cb.chimneys.append(chz)
			for k in rng.randi_range(1, 4):
				var p := Vector3(rng.randf_range(fx1 + 6.0, inner.end.x - 14.0), 0.2, rng.randf_range(fz0 + 4.0, inner.end.y - 4.0))
				if p.x < fx1 + 4.0:
					continue
				_stack(cb, "container", rng.randi() % 4, p, PI * 0.5 * (rng.randi() % 2))
			if rng.randf() < 0.18:
				_stack(cb, "crane", 0, Vector3(inner.end.x - 16.0, 0.2, fz0 + 6.0), rng.randf() * TAU)
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_HARBOR:
			if rng.randf() < 0.5:
				_building(cb, rng, building_id(bx, bz, 0), inner.position.x + 1.0, inner.position.y + 1.0, inner.end.x - 1.0, inner.position.y + 18.0,
					rng.randf_range(10.0, 16.0), F_WAREHOUSE, R_METAL, PK_FLAT)
				for k in 6:
					var p := Vector3(inner.position.x + 5.0 + (k % 3) * 13.0, 0.2, inner.position.y + 26.0 + (k / 3) * 9.0)
					_stack(cb, "container", rng.randi() % 4, p, PI * 0.5)
			else:
				for row in 2:
					for k in 4:
						var p := Vector3(inner.position.x + 5.0 + k * 10.0, 0.2, inner.position.y + 10.0 + row * 22.0)
						_stack(cb, "container", rng.randi() % 4, p, 0.0)
						if rng.randf() < 0.5:
							_stack(cb, "container", rng.randi() % 4, p + Vector3(0, 8, 0), 0.0)
				if rng.randf() < 0.4:
					_stack(cb, "crane", 0, Vector3(inner.get_center().x, 0.2, inner.get_center().y), rng.randf() * TAU)
			_lamps(cb, lx0, lz0, lx1, lz1)
		D_PARK, D_RIVERSIDE:
			var avoid: Array[Rect2] = []
			if d == D_PARK:
				var c := inner.get_center()
				cb.g.ground_rect(c.x - 2.0, inner.position.y, c.x + 2.0, inner.end.y, 0.24, G_PATH)
				cb.g.ground_rect(inner.position.x, c.y - 2.0, inner.end.x, c.y + 2.0, 0.24, G_PATH)
				avoid.append(Rect2(c.x - 2.0, inner.position.y, 4.0, inner.size.y))
				avoid.append(Rect2(inner.position.x, c.y - 2.0, inner.size.x, 4.0))
				if rng.randf() < 0.5:
					_stack(cb, "fountain", 0, Vector3(c.x, 0.25, c.y), 0.0)
					avoid.append(Rect2(c.x - 9.0, c.y - 9.0, 18.0, 18.0))
			_trees(cb, rng, inner, rng.randi_range(9, 16), avoid, 0.35)
			for k in rng.randi_range(2, 5):
				var p := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
				if not in_river(p.x, p.y, 4.0):
					_stack(cb, "bush", rng.randi() % 2, Vector3(p.x, 0.2, p.y), rng.randf() * TAU)
			if d == D_PARK:
				_lamps(cb, lx0, lz0, lx1, lz1)
		D_STADIUM:
			_stadium(cb, inner)
			_lamps(cb, lx0, lz0, lx1, lz1)


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

static func _markings(cb: Build, cx: int, cz: int) -> void:
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	# horizontal streets (run along X) at z = row * 64
	for row in range(cz * BPC, cz * BPC + BPC):
		var z := row * BLOCK
		if is_rail_row(row):
			cb.g.ground_rect(x0, z - 6.0, x0 + CHUNK, z + 6.0, 0.06, G_RAILS)
			continue
		for bx in range(cx * BPC, cx * BPC + BPC):
			var sx := bx * BLOCK + HALF_ST
			var mx := sx + LOT * 0.5
			if in_sea(mx, z, 8.0) or in_river(mx, z, 4.0):
				continue
			cb.g.ground_rect(sx + 5.0, z - 0.75, sx + LOT - 5.0, z + 0.75, 0.05, G_DASH)
			cb.g.ground_rect(sx + 1.0, z - 7.0, sx + 4.0, z + 7.0, 0.05, G_CROSS, Color.WHITE, 16.0, true)
			cb.g.ground_rect(sx + LOT - 4.0, z - 7.0, sx + LOT - 1.0, z + 7.0, 0.05, G_CROSS, Color.WHITE, 16.0, true)
	# vertical streets (run along Z) at x = col * 64
	for col in range(cx * BPC, cx * BPC + BPC):
		var x := col * BLOCK
		for bz in range(cz * BPC, cz * BPC + BPC):
			var sz := bz * BLOCK + HALF_ST
			var mz := sz + LOT * 0.5
			if in_sea(x, mz, 8.0) or in_river(x, mz, 4.0):
				continue
			if is_rail_row(bz) or is_rail_row(bz + 1):
				pass
			cb.g.ground_rect(x - 0.75, sz + 5.0, x + 0.75, sz + LOT - 5.0, 0.05, G_DASH, Color.WHITE, 16.0, true)
			cb.g.ground_rect(x - 7.0, sz + 1.0, x + 7.0, sz + 4.0, 0.05, G_CROSS)
			cb.g.ground_rect(x - 7.0, sz + LOT - 4.0, x + 7.0, sz + LOT - 1.0, 0.05, G_CROSS)


static func _river(cb: Build, cx: int, cz: int) -> void:
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	var x1 := x0 + CHUNK
	var z1 := z0 + CHUNK
	var near := false
	for k in 9:
		var rz := river_z(x0 + CHUNK * k / 8.0)
		if rz + RIVER_HALF + 6.0 > z0 and rz - RIVER_HALF - 6.0 < z1:
			near = true
			break
	if not near:
		return
	var stp := 8.0
	var x := x0
	var H := RIVER_HALF
	while x < x1 - 0.01:
		var xa := x
		var xb := x + stp
		var za := river_z(xa)
		var zb := river_z(xb)
		if maxf(za, zb) + H + 6.0 > z0 and minf(za, zb) - H - 6.0 < z1:
			_gquad(cb.g, Vector2(xa, za - H), Vector2(xb, zb - H), Vector2(xb, zb + H), Vector2(xa, za + H), 0.35, G_WATER)
			_gquad(cb.g, Vector2(xa, za - H - 3.0), Vector2(xb, zb - H - 3.0), Vector2(xb, zb - H), Vector2(xa, za - H), 0.4, G_SLABS)
			_gquad(cb.g, Vector2(xa, za + H), Vector2(xb, zb + H), Vector2(xb, zb + H + 3.0), Vector2(xa, za + H + 3.0), 0.4, G_SLABS)
		x += stp
	# road bridges for streets that run along Z
	for col in range(cx * BPC, cx * BPC + BPC):
		var bxw := col * BLOCK
		var rz := river_z(bxw)
		if rz < z0 or rz >= z1:
			continue
		var za := rz - H - 6.0
		var zb := rz + H + 6.0
		var y := 1.6
		cb.g.ground_rect(bxw - 8.0, za, bxw + 8.0, zb, y, G_ASPHALT)
		cb.g.ground_rect(bxw - 0.75, za, bxw + 0.75, zb, y + 0.05, G_DASH, Color.WHITE, 16.0, true)
		cb.g.ground_rect(bxw - 8.0, za, bxw - 6.5, zb, y + 0.08, G_SIDEWALK)
		cb.g.ground_rect(bxw + 6.5, za, bxw + 8.0, zb, y + 0.08, G_SIDEWALK)
		# ramps
		_gquad(cb.g, Vector2(bxw - 8.0, za - 8.0), Vector2(bxw + 8.0, za - 8.0), Vector2(bxw + 8.0, za), Vector2(bxw - 8.0, za), 0.0, G_ASPHALT)
		cb.g.quad(Vector3(bxw - 8.0, 0.02, za - 8.0), Vector3(bxw + 8.0, 0.02, za - 8.0), Vector3(bxw + 8.0, y, za), Vector3(bxw - 8.0, y, za),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.5), Vector2(0, 0.5), Color(0.9, 0.9, 0.9, 0.5 / 16.0))
		cb.g.quad(Vector3(bxw - 8.0, y, zb), Vector3(bxw + 8.0, y, zb), Vector3(bxw + 8.0, 0.02, zb + 8.0), Vector3(bxw - 8.0, 0.02, zb + 8.0),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.5), Vector2(0, 0.5), Color(0.9, 0.9, 0.9, 0.5 / 16.0))
		_gwall(cb.g, Vector3(bxw - 8.0, y, za), Vector3(bxw - 8.0, y, zb), 1.4, G_SIDEWALK, 1.0)
		_gwall(cb.g, Vector3(bxw + 8.0, y, za), Vector3(bxw + 8.0, y, zb), 1.4, G_SIDEWALK, 0.7)
		for k in 3:
			var lz := za + 6.0 + k * (zb - za - 12.0) / 2.0
			_stack(cb, "lamp", 0, Vector3(bxw - 7.0, y, lz), PI)
			_glow(cb, bxw - 3.0, lz, 18.0, LAMP_GLOW)
	# rail bridges for rail rows crossing the river
	for row in range(cz * BPC, cz * BPC + BPC):
		if not is_rail_row(row):
			continue
		var zr := row * BLOCK
		x = x0
		while x < x1 - 0.01:
			if absf(zr - river_z(x + 4.0)) < H + 6.0:
				cb.g.ground_rect(x, zr - 7.0, x + stp, zr + 7.0, 1.6, G_RAILS)
				_gwall(cb.g, Vector3(x, 1.6, zr - 7.0), Vector3(x + stp, 1.6, zr - 7.0), 1.0, G_SIDEWALK, 0.8)
				_gwall(cb.g, Vector3(x, 1.6, zr + 7.0), Vector3(x + stp, 1.6, zr + 7.0), 1.0, G_SIDEWALK, 0.8)
			x += stp


static func _sea(cb: Build, cx: int, cz: int) -> void:
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	var x1 := x0 + CHUNK
	var z1 := z0 + CHUNK
	var minc := 1e9
	for k in 5:
		minc = minf(minc, coast_x(z0 + CHUNK * k / 4.0))
	if minc - 20.0 > x1:
		return
	var stp := 8.0
	var z := z0
	while z < z1 - 0.01:
		var ca := coast_x(z)
		var cbx := coast_x(z + stp)
		if minf(ca, cbx) < x1:
			var xa := maxf(ca, x0)
			var xb := maxf(cbx, x0)
			var deep := ca + 320.0 < x0
			_gquad(cb.g, Vector2(xa, z), Vector2(x1, z), Vector2(x1, z + stp), Vector2(xb, z + stp), 0.35, G_DEEP if deep else G_WATER)
			if ca > x0 - 3.0 and ca < x1:
				_gquad(cb.g, Vector2(ca - 4.0, z), Vector2(ca, z), Vector2(cbx, z + stp), Vector2(cbx - 4.0, z + stp), 0.42, G_SLABS)
		z += stp
	# piers
	var k0 := floori(z0 / 160.0)
	for k in range(k0, k0 + 3):
		var zp := k * 160.0 + 80.0
		if zp < z0 or zp >= z1:
			continue
		var c := coast_x(zp)
		if c < x0 or c >= x1:
			continue
		cb.g.ground_rect(c - 4.0, zp - 7.0, c + 76.0, zp + 7.0, 0.8, G_SLABS)
		_gwall(cb.g, Vector3(c, 0.35, zp + 7.0), Vector3(c + 76.0, 0.35, zp + 7.0), 0.45, G_SLABS, 0.6)
		for j in 3:
			_stack(cb, "lamp", 0, Vector3(c + 14.0 + j * 26.0, 0.8, zp - 6.0), -PI * 0.5)
			_glow(cb, c + 14.0 + j * 26.0, zp - 2.0, 16.0, LAMP_GLOW)


# ------------------------------------------------------------------ airport

static func _airport(cb: Build, cx: int, cz: int, ap: Vector2i) -> void:
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	var x1 := x0 + CHUNK
	var z1 := z0 + CHUNK
	var ax0 := (cx - ap.x) * CHUNK
	var az0 := (cz - ap.y) * CHUNK
	var chunk := Rect2(x0, z0, CHUNK, CHUNK)
	cb.g.ground_rect(x0, z0, x1, z1, 0.0, G_GRASS)
	var rz := az0 + 150.0
	_clip_rect(cb, chunk, Rect2(ax0 + 60.0, rz - 20.0, 648.0, 40.0), 0.1, G_RUNWAY)
	_clip_rect(cb, chunk, Rect2(ax0 + 60.0, rz - 18.0, 18.0, 36.0), 0.14, G_CROSS, true)
	_clip_rect(cb, chunk, Rect2(ax0 + 690.0, rz - 18.0, 18.0, 36.0), 0.14, G_CROSS, true)
	_clip_rect(cb, chunk, Rect2(ax0 + 40.0, rz + 62.0, 688.0, 18.0), 0.1, G_ASPHALT)
	_clip_rect(cb, chunk, Rect2(ax0 + 40.0, rz + 70.25, 688.0, 1.5), 0.13, G_DASH)
	for k in 4:
		_clip_rect(cb, chunk, Rect2(ax0 + 100.0 + k * 180.0, rz + 20.0, 16.0, 42.0), 0.1, G_ASPHALT)
	_clip_rect(cb, chunk, Rect2(ax0 + 40.0, az0 + 300.0, 688.0, 86.0), 0.1, G_SLABS)
	_clip_rect(cb, chunk, Rect2(ax0 + 250.0, az0 + 440.0, 300.0, 56.0), 0.1, G_PARKING)
	# runway edge lights
	var lx := ax0 + 70.0
	while lx < ax0 + 700.0:
		for sz in [-21.0, 21.0]:
			if chunk.has_point(Vector2(lx, rz + sz)):
				_glow(cb, lx, rz + sz, 7.0, Color(1.0, 1.0, 0.85, 1.0))
		lx += 30.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hashi(cx, cz, 99)
	# terminal
	_in_chunk_box(cb, rng, chunk, Rect2(ax0 + 260.0, az0 + 392.0, 260.0, 40.0), 16.0, F_TERMINAL, R_METAL, 0)
	for k in 3:
		_in_chunk_box(cb, rng, chunk, Rect2(ax0 + 50.0 + k * 62.0, az0 + 394.0, 52.0, 38.0), 18.0, F_HANGAR, R_METAL, 1 + k)
	var tw := Vector2(ax0 + 640.0, az0 + 410.0)
	if chunk.has_point(tw):
		var id := building_id(cx * BPC, cz * BPC, 9)
		_box(cb, tw.x - 5.0, tw.y - 5.0, tw.x + 5.0, tw.y + 5.0, 0.0, 34.0, F_OFFICE, R_TAR, 0.3, true)
		_box(cb, tw.x - 8.0, tw.y - 8.0, tw.x + 8.0, tw.y + 8.0, 34.0, 40.0, F_TERMINAL, R_TAR, 0.3, false)
		_reg(cb, id, tw.x - 8.0, tw.y - 8.0, tw.x + 8.0, tw.y + 8.0, 40.0)
		_stack(cb, "antenna", 0, Vector3(tw.x, 40.3, tw.y), 0.0)
	for k in 5:
		var p := Vector2(ax0 + 290.0 + k * 66.0, az0 + 345.0)
		if chunk.has_point(p):
			_stack(cb, "airliner", 0, Vector3(p.x, 0.2, p.y), 0.0)


static func _clip_rect(cb: Build, chunk: Rect2, r: Rect2, y: float, tile: int, rot: bool = false) -> void:
	var c := chunk.intersection(r)
	if c.size.x <= 0.0 or c.size.y <= 0.0:
		return
	cb.g.ground_rect(c.position.x, c.position.y, c.end.x, c.end.y, y, tile, Color.WHITE, 16.0, rot)


static func _in_chunk_box(cb: Build, rng: RandomNumberGenerator, chunk: Rect2, r: Rect2, h: float, style: int, roof: int, idx: int) -> void:
	if not chunk.has_point(r.get_center()):
		return
	_building(cb, rng, building_id(cb.cx * BPC, cb.cz * BPC, idx), r.position.x, r.position.y, r.end.x, r.end.y, h, style, roof, PK_FLAT)
