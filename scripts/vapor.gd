class_name VaporFX
extends Node3D
## Condensation on one plane (shaders/vapor.gdshader): the vapour cone that
## forms around the fuselage close to top speed and the vapour sheets over
## the wings in hard pulls. Shapes follow the plane's art (canopy, wing
## planform). Jet drives the two intensities every frame.

var cone: MeshInstance3D
var wings: MeshInstance3D
var _mc: ShaderMaterial
var _mw: ShaderMaterial
var _kc := 0.0
var _kw := 0.0


func setup(pi: int) -> void:
	for c in get_children():
		c.queue_free()
	var a: Dictionary = PlaneArt.ART[Planes.LIST[pi]["id"]]
	var shader: Shader = preload("res://shaders/vapor.gdshader")
	_mc = ShaderMaterial.new()
	_mc.shader = shader
	_mc.set_shader_parameter("noise3d", Stacks.cloud_noise3d)
	_mc.set_shader_parameter("flow", 4.0)
	_mw = _mc.duplicate()
	_mw.set_shader_parameter("flow", 2.5)
	_mc.set_shader_parameter("cone", true)
	# cone: from the canopy back to behind the wing, around the fuselage
	var can: Array = a["canopy"]
	var w: Array = a["wing"]
	var fus: Array = a["fus"]
	var cz := float(fus[fus.size() / 2][3])
	var hw := 0.0
	for st: Array in fus:
		hw = maxf(hw, float(st[1]))
	var y0 := float(can[0]) + (float(can[1]) - float(can[0])) * 0.4
	var y1 := float(w[1]) + 4.0
	var p0 := PlaneArt.art_local(0.0, y0, cz)
	var p1 := PlaneArt.art_local(0.0, y1, cz)
	var r0 := hw * PlaneArt.WORLD / 64.0 * 1.25
	var r1 := float(w[2]) * PlaneArt.WORLD / 64.0 * 0.55
	cone = _mesh_node(_cone(p0, p1, r0, r1), _mc)
	# wing sheets: just above both wings, root to 85 % span, trailing a bit
	wings = _mesh_node(_wing_sheet(w, hw), _mw)
	set_k(0.0, 0.0)


func _mesh_node(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func _cone(p0: Vector3, p1: Vector3, r0: float, r1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 20
	var rows := 4
	for j in rows:
		for i in seg:
			var quad: Array[Vector2] = [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			var pts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			var nrm: Array[Vector3] = []
			for q in quad:
				var t := q.y / rows
				var ang := q.x / seg * TAU
				# a bell, not a straight cone: it swells, then hugs the body
				var r := lerpf(r0, r1, sqrt(t))
				var c := p0.lerp(p1, t)
				var dir := Vector3(cos(ang), sin(ang) * 0.8, 0.0)
				pts.append(c + dir * r)
				uvs.append(Vector2(q.x / seg, t))
				nrm.append(dir.normalized())
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nrm[idx])
				st.set_uv(uvs[idx])
				st.add_vertex(pts[idx])
	return st.commit()


func _wing_sheet(w: Array, hw: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := float(w[2])
	var zt := float(w[5]) + float(w[7]) + 0.8
	for side in [-1.0, 1.0]:
		var cols := 6
		for i in cols:
			for j in 3:
				var corners: Array[Vector2] = [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
				var pts: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for q in corners:
					var s := lerpf(hw / span + 0.05, 0.85, q.x / cols)
					var yf := lerpf(float(w[0]), float(w[3]), s)
					var yb := lerpf(float(w[1]), float(w[4]), s) + 6.0
					var t := q.y / 3.0
					var y := lerpf(yf, yb, t)
					var z := zt + float(w[6]) * s + t * 0.8
					pts.append(PlaneArt.art_local(side * span * s, y, z))
					uvs.append(Vector2(s, t))
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(Vector3.UP)
					st.set_uv(uvs[idx])
					st.add_vertex(pts[idx])
	return st.commit()


## Cone (near top speed) and wing vapour (hard pull) intensities 0..1.
func set_k(kc: float, kw: float) -> void:
	_kc = lerpf(_kc, kc, 0.15)
	_kw = lerpf(_kw, kw, 0.2)
	if cone == null:
		return
	cone.visible = _kc > 0.01
	wings.visible = _kw > 0.01
	_mc.set_shader_parameter("k", _kc)
	_mw.set_shader_parameter("k", _kw)
