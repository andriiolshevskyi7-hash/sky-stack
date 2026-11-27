class_name Wakes
extends MeshInstance3D
## Wakes on the water (shaders/wake.gdshader): ships and boats leave a
## churned white trail behind the stern inside a widening Kelvin V (the two
## arms spread at ~20 deg), lasting tens of seconds; planes skimming the sea
## drag a short line of spray on the surface. One ImmediateMesh, flat
## ribbons just above the water.

const Y := 0.35
const SEG := 7.0 # metres between points

var cam: Camera3D
var _t := 0.0
var _bufs := {} # key -> Buf
var _seen := {} # source id -> [segment, last time]
var _im := ImmediateMesh.new()


class Buf:
	var pts: Array[Vector4] = [] # x, z, birth time, half width
	var spread := 3.0
	var life := 30.0
	var strength := 1.0
	var last := 0.0


func _ready() -> void:
	mesh = _im
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/wake.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e6, -10, -1e6), Vector3(2e6, 20, 2e6))


func clear() -> void:
	_bufs.clear()
	_seen.clear()


## Feed a source every frame while it makes a wake: `pos` = stern on the
## water, `half_w` = width at the stern, `spread` = how fast the V widens
## (m/s per side), `life` = seconds, `strength` 0..1.
func track(id: int, pos: Vector3, half_w: float, spread: float, life: float, strength: float) -> void:
	var seen: Array = _seen.get(id, [0, -99.0])
	if _t - float(seen[1]) > 1.0:
		seen[0] = int(seen[0]) + 1 # a gap (left the water): start a new trail
	seen[1] = _t
	_seen[id] = seen
	var key := id * 64 + int(seen[0]) % 64
	var b: Buf = _bufs.get(key)
	if b == null:
		b = Buf.new()
		_bufs[key] = b
	b.spread = spread
	b.life = life
	b.strength = strength
	b.last = _t
	var p := Vector4(pos.x, pos.z, _t, half_w)
	if b.pts.is_empty():
		b.pts.append(p)
		b.pts.append(p)
		return
	# the newest point follows the stern; a new one is laid every SEG metres
	b.pts[b.pts.size() - 1] = p
	var prev := b.pts[b.pts.size() - 2]
	if Vector2(p.x - prev.x, p.y - prev.y).length() >= SEG:
		b.pts.append(p)


func _process(delta: float) -> void:
	_t += delta
	_im.clear_surfaces()
	if cam == null:
		return
	var cp := cam.global_position
	var any := false
	var dead: Array = []
	for key in _bufs:
		var b: Buf = _bufs[key]
		# drop expired points from the tail
		while b.pts.size() > 2 and _t - b.pts[0].z > b.life:
			b.pts.remove_at(0)
		if _t - b.last > b.life:
			dead.append(key)
			continue
		var n := b.pts.size()
		if n < 2:
			continue
		var head: Vector4 = b.pts[n - 1]
		if Vector2(head.x - cp.x, head.y - cp.z).length() > 5000.0 + b.spread * b.life:
			continue
		for i in range(n - 1, 0, -1):
			var a: Vector4 = b.pts[i]
			var c: Vector4 = b.pts[i - 1]
			var d := Vector2(c.x - a.x, c.y - a.y)
			if d.length_squared() < 0.01:
				continue
			var side := Vector2(-d.y, d.x).normalized()
			var age_a := _t - a.z
			var age_c := _t - c.z
			var wa := a.w + age_a * b.spread
			var wc := c.w + age_c * b.spread
			var fa := clampf(1.0 - age_a / b.life, 0.0, 1.0) * b.strength
			var fc := clampf(1.0 - age_c / b.life, 0.0, 1.0) * b.strength
			if not any:
				_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				any = true
			var ua := age_a / b.life
			var uc := age_c / b.life
			var a0 := Vector3(a.x - side.x * wa, Y, a.y - side.y * wa)
			var a1 := Vector3(a.x + side.x * wa, Y, a.y + side.y * wa)
			var c0 := Vector3(c.x - side.x * wc, Y, c.y - side.y * wc)
			var c1 := Vector3(c.x + side.x * wc, Y, c.y + side.y * wc)
			_v(fa, Vector2(0, ua), a0)
			_v(fa, Vector2(1, ua), a1)
			_v(fc, Vector2(1, uc), c1)
			_v(fa, Vector2(0, ua), a0)
			_v(fc, Vector2(1, uc), c1)
			_v(fc, Vector2(0, uc), c0)
	if any:
		_im.surface_end()
	for key in dead:
		_bufs.erase(key)


func _v(a: float, uv: Vector2, p: Vector3) -> void:
	_im.surface_set_color(Color(1, 1, 1, a))
	_im.surface_set_uv(uv)
	_im.surface_add_vertex(p)
