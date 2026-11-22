class_name MeshBuf
extends RefCounted
## Accumulates quads into packed arrays and commits them as one ArrayMesh
## surface. Used to batch a whole chunk's buildings / props into one draw call.

var verts := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var use_uv2 := false


func quad_count() -> int:
	return verts.size() / 4


func is_empty() -> bool:
	return verts.is_empty()


## a,b,c,d in order around the quad; ua..ud matching UVs.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color, uv2: Vector2 = Vector2.ZERO) -> void:
	var base := verts.size()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(d)
	uvs.append(ua)
	uvs.append(ub)
	uvs.append(uc)
	uvs.append(ud)
	cols.append(col)
	cols.append(col)
	cols.append(col)
	cols.append(col)
	if use_uv2:
		uv2s.append(uv2)
		uv2s.append(uv2)
		uv2s.append(uv2)
		uv2s.append(uv2)
	idx.append(base)
	idx.append(base + 1)
	idx.append(base + 2)
	idx.append(base)
	idx.append(base + 2)
	idx.append(base + 3)


## Same but with per-vertex colours (for vertical gradients on walls).
func quad_c(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, ca: Color, cb: Color, cc: Color, cd: Color, uv2: Vector2) -> void:
	quad(a, b, c, d, ua, ub, uc, ud, ca, uv2)
	var n := cols.size()
	cols[n - 3] = cb
	cols[n - 2] = cc
	cols[n - 1] = cd


## Horizontal ground-type quad with world-tiling UVs (1 tile = `tile` units).
## Tile index encoded into colour alpha for the ground shader.
func ground_rect(x0: float, z0: float, x1: float, z1: float, y: float, tile_idx: int, tint: Color = Color.WHITE, tile: float = 16.0, rotate_uv: bool = false) -> void:
	var c := tint
	c.a = (float(tile_idx) + 0.5) / 16.0
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var cc := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	if rotate_uv:
		quad(a, b, cc, d, Vector2(z0, x0) / tile, Vector2(z0, x1) / tile, Vector2(z1, x1) / tile, Vector2(z1, x0) / tile, c)
	else:
		quad(a, b, cc, d, Vector2(x0, z0) / tile, Vector2(x1, z0) / tile, Vector2(x1, z1) / tile, Vector2(x0, z1) / tile, c)


## Append one sprite stack (all slices) at pos, rotated by yaw (Godot Y-rotation
## convention), uniformly scaled. Slice 0 is the bottom one.
func add_stack(sh, variant: int, pos: Vector3, yaw: float, scale: float, tint: Color, copies: int = 1) -> void:
	var cy := cos(yaw)
	var sy := sin(yaw)
	var hw: float = sh.w * 0.5 * scale
	var hh: float = sh.h * 0.5 * scale
	# local corners (x, z): front-left, front-right, back-right, back-left
	var lx := [-hw, hw, hw, -hw]
	var lz := [-hh, -hh, hh, hh]
	var wc: Array[Vector2] = []
	for i in 4:
		wc.append(Vector2(cy * lx[i] + sy * lz[i], -sy * lx[i] + cy * lz[i]))
	var denom: float = maxf(1.0, float(sh.n - 1))
	for s in sh.n:
		var r: Rect2 = sh.uv(s, variant)
		var y: float = pos.y + s * sh.spacing * scale
		var shade := 0.72 + 0.28 * float(s) / denom
		var col := Color(tint.r * shade, tint.g * shade, tint.b * shade, tint.a)
		for c in range(1, copies):
			var yc: float = y + sh.spacing * scale * float(c) / copies
			quad(Vector3(pos.x + wc[0].x, yc, pos.z + wc[0].y), Vector3(pos.x + wc[1].x, yc, pos.z + wc[1].y),
				Vector3(pos.x + wc[2].x, yc, pos.z + wc[2].y), Vector3(pos.x + wc[3].x, yc, pos.z + wc[3].y),
				r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)
		quad(Vector3(pos.x + wc[0].x, y, pos.z + wc[0].y), Vector3(pos.x + wc[1].x, y, pos.z + wc[1].y),
			Vector3(pos.x + wc[2].x, y, pos.z + wc[2].y), Vector3(pos.x + wc[3].x, y, pos.z + wc[3].y),
			r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


func to_arrays() -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if use_uv2:
		arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, to_arrays())
	return mesh
