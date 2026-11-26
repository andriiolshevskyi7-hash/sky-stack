class_name Trails
extends MeshInstance3D
## Continuous thin white wingtip trails: a ring buffer of points per wingtip,
## rebuilt every frame as camera-facing ribbons in one ImmediateMesh (1 draw call).

const N := 80
const COUNT := 2
var width := 1.6
var cam: Camera3D
var _pts: Array[PackedVector3Array] = []
var _head := PackedInt32Array()
var _len := PackedInt32Array()
var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/trail.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e6, -500, -1e6), Vector3(2e6, 4000, 2e6))
	for i in COUNT:
		var a := PackedVector3Array()
		a.resize(N)
		_pts.append(a)
		_head.append(0)
		_len.append(0)


func clear() -> void:
	for i in COUNT:
		_len[i] = 0


func add(i: int, p: Vector3) -> void:
	_head[i] = (_head[i] + 1) % N
	_pts[i][_head[i]] = p
	_len[i] = mini(_len[i] + 1, N)


func _process(_d: float) -> void:
	_im.clear_surfaces()
	if cam == null:
		return
	var cp := cam.global_position
	var any := false
	for i in COUNT:
		if _len[i] >= 2:
			any = true
	if not any:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in COUNT:
		var n := _len[i]
		var pts := _pts[i]
		for k in n - 1:
			var ia := posmod(_head[i] - k, N)
			var ib := posmod(_head[i] - k - 1, N)
			var a := pts[ia]
			var b := pts[ib]
			var dir := b - a
			if dir.length_squared() < 0.0001:
				continue
			var side := dir.cross(cp - a).normalized() * width * 0.5
			# fade near the camera: the close chase camera sits right in the
			# trails' path and they would fill the screen
			var aa := (1.0 - float(k) / n) * clampf((a.distance_to(cp) - 30.0) / 70.0, 0.0, 1.0)
			var ab := (1.0 - float(k + 1) / n) * clampf((b.distance_to(cp) - 30.0) / 70.0, 0.0, 1.0)
			if aa <= 0.0 and ab <= 0.0:
				continue
			var ca := Color(1, 1, 1, aa * 1.2)
			var cb := Color(1, 1, 1, ab * 1.2)
			_im.surface_set_color(ca)
			_im.surface_add_vertex(a - side)
			_im.surface_add_vertex(a + side)
			_im.surface_set_color(cb)
			_im.surface_add_vertex(b + side)
			_im.surface_set_color(ca)
			_im.surface_add_vertex(a - side)
			_im.surface_set_color(cb)
			_im.surface_add_vertex(b + side)
			_im.surface_add_vertex(b - side)
	_im.surface_end()
