class_name MenuStage
extends Node
## Main-menu background: the selected plane (in its skin) parked in a
## hangar or on a runway, rendered as a 3D scene into its own low-res
## viewport (composited by the post shader, so it gets the same pixel look),
## with a slow cinematic camera and baked lamp lighting.
## Backdrops are builder functions - add one to BACKDROPS to swap the scene.

const BACKDROPS := ["hangar", "runway"]
## The plane faces the camera three-quarters on.
const PLANE_YAW := PI - 0.55

var game: Node
var active := false
var backdrop := "hangar"
var vp: SubViewport
var cam: Camera3D
var env: Environment
var _root: Node3D
var _set: Node3D
var _batch: StackBatch
var _plane_mat: ShaderMaterial
var _sheet := ""
var _t := 0.0
var _tex := {}
var _built := ""

# lamps: [position, radius, strength] (baked into vertex colours)
var _lamps: Array = []
var _ambient := 0.42
var _warm := Color(1.0, 0.92, 0.78)


func _ready() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.positional_shadow_atlas_size = 0
	vp.audio_listener_enable_3d = false
	add_child(vp)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 3000.0
	cam.fov = 40.0
	cam.current = true
	vp.add_child(cam)
	_root = Node3D.new()
	vp.add_child(_root)
	_make_textures()


func set_size(s: Vector2i) -> void:
	if vp.size != s:
		vp.size = s


func texture() -> Texture2D:
	return vp.get_texture()


func update(delta: float, on: bool) -> void:
	active = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		return
	if _built != backdrop:
		_build()
	_t += delta
	var pi := Profile.plane_index()
	var sheet := Planes.sheet_of(pi)
	if sheet != _sheet:
		_set_plane(sheet)
	# plane on its gear, slowly breathing light; camera: a slow arc in front
	_batch.begin()
	_batch.push_basis(Vector3(0, 3.2, 0), Basis(Vector3.UP, PLANE_YAW), Profile.skin_of(pi), Color.WHITE)
	_batch.end()
	var a := sin(_t * 0.08) * 0.6 + 0.35
	var dist := 62.0 + sin(_t * 0.13) * 6.0
	var h := 27.0 + sin(_t * 0.07) * 4.0
	var p := Vector3(sin(a) * dist, h, cos(a) * dist)
	# the plane sits right of centre (the menu column is on the left)
	var right := Vector3(cos(a), 0, -sin(a))
	cam.transform = Transform3D(Basis.IDENTITY, p).looking_at(Vector3(0, 4.0, 0) - right * 13.0, Vector3.UP)


func _set_plane(sheet: String) -> void:
	_sheet = sheet
	if _batch != null:
		_batch.queue_free()
	_plane_mat = (Stacks.batch_material(sheet) as ShaderMaterial).duplicate()
	_plane_mat.set_shader_parameter("no_fog", true)
	_plane_mat.set_shader_parameter("stage_light", Vector3(1.08, 1.03, 0.96) if backdrop == "hangar" else Vector3(1.12, 1.08, 1.0))
	_batch = StackBatch.new().setup(sheet, 1, _plane_mat)
	# close-up: draw every slice 8 times so no gaps open between slices
	_batch.multimesh.mesh = Stacks.make_stack_mesh(sheet, 8)
	_root.add_child(_batch)


# ------------------------------------------------------------------ textures

func _img_tex(img: Image, repeat: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = repeat
	return m


func _noise_fill(img: Image, base: Color, amt: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	img.fill(base)
	for i in img.get_width() * img.get_height() / 3:
		var x := rng.randi() % img.get_width()
		var y := rng.randi() % img.get_height()
		img.set_pixel(x, y, base.lightened(amt) if rng.randf() < 0.5 else base.darkened(amt))


func _make_textures() -> void:
	# concrete floor tile with seams, a few stains
	var f := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	_noise_fill(f, Color(0.5, 0.52, 0.55), 0.05, 1)
	f.fill_rect(Rect2i(0, 0, 32, 1), Color(0.36, 0.37, 0.4))
	f.fill_rect(Rect2i(0, 0, 1, 32), Color(0.36, 0.37, 0.4))
	for i in 3:
		f.fill_rect(Rect2i(6 + i * 7, 12 + i * 5, 4, 3), Color(0.4, 0.41, 0.43))
	_tex["floor"] = _img_tex(f, true)
	# asphalt
	var asp := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	_noise_fill(asp, Color(0.24, 0.25, 0.27), 0.06, 2)
	_tex["asphalt"] = _img_tex(asp, true)
	# corrugated wall
	var w := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	_noise_fill(w, Color(0.42, 0.47, 0.54), 0.03, 3)
	for x in range(0, 32, 4):
		w.fill_rect(Rect2i(x, 0, 1, 32), Color(0.34, 0.38, 0.44))
		w.fill_rect(Rect2i(x + 1, 0, 1, 32), Color(0.5, 0.55, 0.62))
	w.fill_rect(Rect2i(0, 31, 32, 1), Color(0.3, 0.33, 0.38))
	_tex["wall"] = _img_tex(w, true)
	# plain (props, beams, gear) - colour comes from the vertex colour
	var p := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	_noise_fill(p, Color(0.92, 0.92, 0.92), 0.04, 4)
	p.fill_rect(Rect2i(0, 0, 8, 1), Color(1, 1, 1))
	_tex["plain"] = _img_tex(p, true)
	# sky gradient (door opening / runway horizon)
	var s := Image.create(4, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		s.fill_rect(Rect2i(0, y, 4, 1), Color("4f8fd8").lerp(Color("cfe3f2"), pow(y / 63.0, 1.6)))
	var sm := _img_tex(s, false)
	sm.vertex_color_use_as_albedo = false
	_tex["sky"] = sm
	# light pools (additive)
	var lp := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var v := floorf(clampf(1.0 - d, 0.0, 1.0) * 4.0) / 4.0
			lp.set_pixel(x, y, Color(v, v * 0.92, v * 0.78, 1))
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_texture = ImageTexture.create_from_image(lp)
	pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.no_depth_test = false
	pm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	pm.albedo_color = Color(0.35, 0.35, 0.35)
	_tex["pool"] = pm


# ------------------------------------------------------------------ building

class Geo:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, cols: Array) -> void:
		var o := v.size()
		v.append_array(PackedVector3Array([a, b, cc, d]))
		uv.append_array(PackedVector2Array([ua, ub, uc, ud]))
		for k in 4:
			c.append(cols[k])
		i.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = i
		var m := ArrayMesh.new()
		if not v.is_empty():
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


## Baked light at a point: ambient + warm lamp pools, quantised into a few
## steps for a pixel-art look.
func _light(p: Vector3, base: Color, nrm_up: float = 1.0) -> Color:
	var l := _ambient
	for lm: Array in _lamps:
		var lp: Vector3 = lm[0]
		var d := p.distance_to(lp) / float(lm[1])
		l += float(lm[2]) * clampf(1.0 - d * d, 0.0, 1.0) * lerpf(0.6, 1.0, nrm_up)
	l = floorf(l * 6.0) / 6.0
	var col := base * _warm.lerp(Color.WHITE, 0.5) * l
	col.a = 1.0
	return col


func _plane_grid(g: Geo, x0: float, z0: float, x1: float, z1: float, y: float, n: int, tile: float, base: Color) -> void:
	for j in n:
		for i in n:
			var ax := lerpf(x0, x1, float(i) / n)
			var bx := lerpf(x0, x1, float(i + 1) / n)
			var az := lerpf(z0, z1, float(j) / n)
			var bz := lerpf(z0, z1, float(j + 1) / n)
			var pts := [Vector3(ax, y, az), Vector3(bx, y, az), Vector3(bx, y, bz), Vector3(ax, y, bz)]
			var cols := []
			for q: Vector3 in pts:
				cols.append(_light(q, base))
			g.quad(pts[0], pts[1], pts[2], pts[3], Vector2(ax, az) / tile, Vector2(bx, az) / tile, Vector2(bx, bz) / tile, Vector2(ax, bz) / tile, cols)


func _wall(g: Geo, a: Vector3, b: Vector3, h: float, n: int, tile: float, base: Color) -> void:
	var len := a.distance_to(b)
	for i in n:
		for j in 4:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			var y0 := h * j / 4.0
			var y1 := h * (j + 1) / 4.0
			var pts := [p0 + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0), p1 + Vector3(0, y0, 0), p0 + Vector3(0, y0, 0)]
			var cols := []
			for q: Vector3 in pts:
				cols.append(_light(q, base, 0.4))
			var u0 := len * i / n / tile
			var u1 := len * (i + 1) / n / tile
			g.quad(pts[0], pts[1], pts[2], pts[3], Vector2(u0, -y1 / tile), Vector2(u1, -y1 / tile), Vector2(u1, -y0 / tile), Vector2(u0, -y0 / tile), cols)


## Axis-aligned box (props, beams, gear): lit top, darker sides.
func _box(g: Geo, c: Vector3, s: Vector3, base: Color) -> void:
	var h := s * 0.5
	var p := [c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z)]
	var faces := [[0, 1, 2, 3, 1.0], [3, 2, 6, 7, 0.8], [1, 0, 4, 5, 0.6], [2, 1, 5, 6, 0.7], [0, 3, 7, 4, 0.75]]
	for f: Array in faces:
		var k: float = f[4]
		var cols := []
		for idx in 4:
			cols.append(_light(p[f[idx]], base * k, k))
		g.quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), cols)


func _mesh(g: Geo, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh()
	mi.material_override = mat
	_set.add_child(mi)


func _build() -> void:
	_built = backdrop
	if _set != null:
		_set.queue_free()
	_set = Node3D.new()
	_root.add_child(_set)
	if backdrop == "runway":
		_build_runway()
	else:
		_build_hangar()
	if _plane_mat != null:
		_sheet = "" # re-create with the right light


## Hangar: concrete floor with safety lines, corrugated walls, roof trusses,
## an open door with daylight, lamps with light pools, ground equipment.
func _build_hangar() -> void:
	env.background_color = Color("10141c")
	_ambient = 0.42
	_warm = Color(1.0, 0.9, 0.74)
	_lamps = [[Vector3(0, 40, 0), 70.0, 0.75], [Vector3(-60, 40, -50), 45.0, 0.4], [Vector3(60, 40, -50), 45.0, 0.4], [Vector3(0, 20, -120), 90.0, 0.35]]
	var floor := Geo.new()
	_plane_grid(floor, -160, -150, 160, 160, 0.0, 32, 12.0, Color(1, 1, 1))
	_mesh(floor, _tex["floor"])
	var plain := Geo.new()
	# yellow safety box and lead-in line under the plane
	for k in 4:
		var a := [Vector3(-34, 0.05, -30), Vector3(34, 0.05, -30), Vector3(34, 0.05, 30), Vector3(-34, 0.05, 30)]
		var p0: Vector3 = a[k]
		var p1: Vector3 = a[(k + 1) % 4]
		var dirv := (p1 - p0).normalized()
		var side := Vector3(-dirv.z, 0, dirv.x) * 0.9
		var yl := Color(0.95, 0.78, 0.15)
		plain.quad(p0 - side, p1 - side, p1 + side, p0 + side, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [_light(p0, yl), _light(p1, yl), _light(p1, yl), _light(p0, yl)])
	for k in 8:
		var z := 34.0 + k * 12.0
		var yl := Color(0.95, 0.78, 0.15)
		plain.quad(Vector3(-0.8, 0.05, z), Vector3(0.8, 0.05, z), Vector3(0.8, 0.05, z + 6), Vector3(-0.8, 0.05, z + 6), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [_light(Vector3(0, 0, z), yl), _light(Vector3(0, 0, z), yl), _light(Vector3(0, 0, z), yl), _light(Vector3(0, 0, z), yl)])
	# walls: back wall with the open door, side walls
	var walls := Geo.new()
	var wc := Color(1, 1, 1)
	_wall(walls, Vector3(-160, 0, -150), Vector3(-70, 0, -150), 70, 8, 16.0, wc)
	_wall(walls, Vector3(70, 0, -150), Vector3(160, 0, -150), 70, 8, 16.0, wc)
	_wall(walls, Vector3(-70, 44, -150), Vector3(70, 44, -150), 26, 10, 16.0, wc)
	_wall(walls, Vector3(-160, 0, 160), Vector3(-160, 0, -150), 70, 20, 16.0, wc)
	_wall(walls, Vector3(160, 0, -150), Vector3(160, 0, 160), 70, 20, 16.0, wc)
	_mesh(walls, _tex["wall"])
	# daylight through the door: sky, a strip of runway and grass
	var sky := Geo.new()
	var white := Color.WHITE
	sky.quad(Vector3(-70, 44, -152), Vector3(70, 44, -152), Vector3(70, 0, -152), Vector3(-70, 0, -152), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [white, white, white, white])
	_mesh(sky, _tex["sky"])
	var outside := Color(0.45, 0.62, 0.32)
	plain.quad(Vector3(-70, 0.02, -151), Vector3(70, 0.02, -151), Vector3(70, 7, -151.5), Vector3(-70, 7, -151.5), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [outside, outside, outside.lightened(0.2), outside.lightened(0.2)])
	var tarmac := Color(0.32, 0.33, 0.36)
	plain.quad(Vector3(-70, 0.03, -150.8), Vector3(70, 0.03, -150.8), Vector3(70, 3, -151.3), Vector3(-70, 3, -151.3), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [tarmac, tarmac, tarmac, tarmac])
	# roof trusses and lamps
	var beam := Color(0.2, 0.22, 0.26)
	for k in 6:
		var z := -140.0 + k * 55.0
		_box(plain, Vector3(0, 66, z), Vector3(320, 3, 3), beam)
		for x in range(-150, 151, 30):
			_box(plain, Vector3(x, 60, z), Vector3(1.5, 12, 1.5), beam)
	for lm: Array in _lamps:
		var lp: Vector3 = lm[0]
		if lp.y > 30.0:
			_box(plain, lp + Vector3(0, 2, 0), Vector3(8, 2, 8), Color(0.15, 0.15, 0.17))
			plain.quad(lp + Vector3(-3, 0.9, -3), lp + Vector3(3, 0.9, -3), lp + Vector3(3, 0.9, 3), lp + Vector3(-3, 0.9, 3), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [Color(1.6, 1.5, 1.2), Color(1.6, 1.5, 1.2), Color(1.6, 1.5, 1.2), Color(1.6, 1.5, 1.2)])
	# landing gear under the plane
	_gear(plain)
	# ground equipment: crates, tool cart, missile trolley, ladder, drums
	for k in 3:
		_box(plain, Vector3(-95 + k * 0.5, 4 + k * 8, -95), Vector3(14, 8, 12), Color(0.42, 0.45, 0.3))
	_box(plain, Vector3(-80, 4, -100), Vector3(12, 8, 12), Color(0.42, 0.45, 0.3))
	_box(plain, Vector3(70, 4, -40), Vector3(10, 6, 6), Color(0.75, 0.16, 0.12)) # tool cart
	_box(plain, Vector3(70, 8, -40), Vector3(10, 1, 6), Color(0.3, 0.3, 0.32))
	_box(plain, Vector3(-48, 2, 28), Vector3(18, 2, 6), Color(0.85, 0.7, 0.2)) # missile trolley
	for k in 2:
		_box(plain, Vector3(-48, 4.2 + k * 2.2, 28), Vector3(16, 1.6, 1.6), Color(0.92, 0.93, 0.95))
	for k in 4:
		_box(plain, Vector3(40, 1 + k * 2.6, -22 + k * 1.2), Vector3(4, 0.5, 2.4), Color(0.7, 0.72, 0.75)) # ladder steps
	_box(plain, Vector3(42, 6, -18), Vector3(0.6, 12, 0.6), Color(0.7, 0.72, 0.75))
	for k in 4:
		_box(plain, Vector3(110 + (k % 2) * 7, 4, 90 + (k / 2) * 7), Vector3(6, 8, 6), Color(0.2, 0.36, 0.6)) # drums
	_mesh(plain, _tex["plain"])
	# light pools on the floor
	var pools := Geo.new()
	for lm: Array in _lamps:
		var lp: Vector3 = lm[0]
		var r: float = lm[1] * 0.7
		var pc := Color.WHITE
		pools.quad(Vector3(lp.x - r, 0.1, lp.z - r), Vector3(lp.x + r, 0.1, lp.z - r), Vector3(lp.x + r, 0.1, lp.z + r), Vector3(lp.x - r, 0.1, lp.z + r), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [pc, pc, pc, pc])
	_mesh(pools, _tex["pool"])


## Runway at golden hour: asphalt apron with markings, grass, distant
## hangars and hills against the sky.
func _build_runway() -> void:
	env.background_color = Color("e9b98a")
	_ambient = 0.85
	_warm = Color(1.0, 0.86, 0.68)
	_lamps = []
	var ground := Geo.new()
	_plane_grid(ground, -400, -600, 400, 300, 0.0, 16, 14.0, Color(1, 1, 1))
	_mesh(ground, _tex["asphalt"])
	var plain := Geo.new()
	var white := Color(0.95, 0.95, 0.92)
	for k in 30:
		var z := 200.0 - k * 30.0
		_box(plain, Vector3(-60, 0.05, z), Vector3(1.5, 0.1, 14), white)
	_box(plain, Vector3(0, 0.05, 0), Vector3(70, 0.1, 1.2), Color(0.95, 0.78, 0.15))
	var grass := Color(0.42, 0.55, 0.3)
	_box(plain, Vector3(-260, 0.02, -150), Vector3(200, 0.1, 900), grass)
	_box(plain, Vector3(260, 0.02, -150), Vector3(200, 0.1, 900), grass)
	for k in 4:
		_box(plain, Vector3(-150 + k * 100, 20, -560), Vector3(80, 40, 40), Color(0.55, 0.58, 0.62))
	for k in 7:
		_box(plain, Vector3(-600 + k * 200, 30, -900), Vector3(260, 60 + (k % 3) * 30, 60), Color(0.5, 0.48, 0.55))
	_gear(plain)
	_mesh(plain, _tex["plain"])
	var sky := Geo.new()
	var w := Color.WHITE
	sky.quad(Vector3(-2000, 700, -1000), Vector3(2000, 700, -1000), Vector3(2000, 0, -1000), Vector3(-2000, 0, -1000), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), [w, w, w, w])
	_mesh(sky, _tex["sky"])


func _gear(g: Geo) -> void:
	var dark := Color(0.16, 0.16, 0.18)
	var steel := Color(0.6, 0.62, 0.66)
	var legs := [Vector3(0, 0, -12), Vector3(-5, 0, 4), Vector3(5, 0, 4)]
	for p0: Vector3 in legs:
		var p := Basis(Vector3.UP, PLANE_YAW) * p0
		_box(g, p + Vector3(0, 2.0, 0), Vector3(0.5, 3.2, 0.5), steel)
		_box(g, p + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 2.0), dark)
