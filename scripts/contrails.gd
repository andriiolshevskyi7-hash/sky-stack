class_name Contrails
extends MeshInstance3D
## Engine contrails high up (from ~2 km): every plane leaves white trails
## from its nozzles that last ~18 s, spreading wider and fading as they age
## (and fading in a few metres behind the nozzle, where the vapour forms).
## One ImmediateMesh for all planes (camera-facing ribbons, 1 draw call).

const N := 150 # points per trail
const DT := 0.12 # seconds between points
const LIFE := 18.0
const MIN_ALT := 2000.0

var cam: Camera3D
var _t := 0.0
var _bufs := {} # key -> Buf


class Buf:
	var pts := PackedVector3Array()
	var ts := PackedFloat32Array()
	var head := 0
	var len := 0
	var acc := DT

	func _init() -> void:
		pts.resize(N)
		ts.resize(N)

	func push(p: Vector3, t: float) -> void:
		head = (head + 1) % N
		pts[head] = p
		ts[head] = t
		len = mini(len + 1, N)
var _noz := {} # plane index -> Array[Vector3] (outermost nozzles)
var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ribbon.gdshader")
	m.set_shader_parameter("puff", 1.6)
	m.set_shader_parameter("noise3d", Stacks.cloud_noise3d)
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e6, -500, -1e6), Vector3(2e6, 12000, 2e6))


func clear() -> void:
	_bufs.clear()


func _nozzles(pi: int) -> Array:
	if not _noz.has(pi):
		var all: Array[Vector3] = PlaneArt.nozzles(pi)
		var pick: Array = []
		if all.size() <= 2:
			pick = all
		else:
			# the two outermost
			var s := all.duplicate()
			s.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
			pick = [s[0], s[s.size() - 1]]
		_noz[pi] = pick
	return _noz[pi]


## Sample the planes (call once per frame) and rebuild the ribbons.
func update_planes(planes: Array, delta: float) -> void:
	_t += delta
	for p: Jet in planes:
		if p == null or not is_instance_valid(p) or not p.alive or p.position.y < MIN_ALT - 150.0:
			continue
		if cam != null and p.position.distance_squared_to(cam.global_position) > 6000.0 * 6000.0:
			continue
		var noz := _nozzles(p.plane)
		var vb := p.visual_basis()
		for ni in noz.size():
			var key := "%d_%d" % [p.get_instance_id(), ni]
			if not _bufs.has(key):
				_bufs[key] = Buf.new()
			var b: Buf = _bufs[key]
			b.acc += delta
			if b.acc >= DT:
				b.acc = 0.0
				b.push(p.position + vb * (noz[ni] as Vector3), _t)
	_draw()


func _draw() -> void:
	_im.clear_surfaces()
	if cam == null or _bufs.is_empty():
		return
	var cp := cam.global_position
	var dead: Array = []
	var any := false
	for key in _bufs:
		var b: Buf = _bufs[key]
		var n := b.len
		var ts := b.ts
		if _t - ts[b.head] > LIFE:
			dead.append(key)
			continue
		if n < 2:
			continue
		var pts := b.pts
		var head := b.head
		for k in n - 1:
			var ia := posmod(head - k, N)
			var ib := posmod(head - k - 1, N)
			var a := pts[ia]
			var c := pts[ib]
			var age_a := _t - ts[ia]
			var age_b := _t - ts[ib]
			if age_a > LIFE:
				break
			var dir := c - a
			if dir.length_squared() < 0.01:
				continue
			var wa := 3.2 + age_a * 1.3
			var wb := 3.2 + age_b * 1.3
			var sa := dir.cross(cp - a).normalized() * wa * 0.5
			var sb := dir.cross(cp - c).normalized() * wb * 0.5
			var alt_a := smoothstep(MIN_ALT - 150.0, MIN_ALT + 350.0, a.y)
			var alt_b := smoothstep(MIN_ALT - 150.0, MIN_ALT + 350.0, c.y)
			# forms a few metres behind the nozzle, fades with age
			var fa := clampf(age_a / 0.35, 0.0, 1.0) * (1.0 - age_a / LIFE) * alt_a * 0.85
			var fb := clampf(age_b / 0.35, 0.0, 1.0) * (1.0 - age_b / LIFE) * alt_b * 0.85
			fa *= clampf((a.distance_to(cp) - 30.0) / 60.0, 0.0, 1.0)
			fb *= clampf((c.distance_to(cp) - 30.0) / 60.0, 0.0, 1.0)
			if fa <= 0.0 and fb <= 0.0:
				continue
			if not any:
				_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				any = true
			var ca := Color(1, 1, 1, fa)
			var cb := Color(1, 1, 1, fb)
			_im.surface_set_color(ca)
			_im.surface_add_vertex(a - sa)
			_im.surface_add_vertex(a + sa)
			_im.surface_set_color(cb)
			_im.surface_add_vertex(c + sb)
			_im.surface_set_color(ca)
			_im.surface_add_vertex(a - sa)
			_im.surface_set_color(cb)
			_im.surface_add_vertex(c + sb)
			_im.surface_add_vertex(c - sb)
	if any:
		_im.surface_end()
	for key in dead:
		_bufs.erase(key)


func _v(c: Color, uv: Vector2, p: Vector3) -> void:
	_im.surface_set_color(c)
	_im.surface_set_uv(uv)
	_im.surface_add_vertex(p)
