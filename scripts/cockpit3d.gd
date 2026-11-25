class_name Cockpit3D
extends Node
## The cockpit as real low-poly 3D geometry around the pilot's eye, textured
## with pixel art (CockpitArt) and rendered into its own low-res viewport
## (same size as the world view, near plane 2 cm) that the post shader lays
## over the world. True perspective: the tub is wide at the shoulders and
## narrows to the nose, side consoles run forward at an angle, the sloped
## instrument panel sits back under an overhanging glareshield, the canopy
## bow arcs overhead, the HUD combiner stands on two posts above the keypad,
## the stick moves between the pilot's knees, the throttle lever on the left
## console follows the throttle. The camera is the pilot's head: it turns
## with the head look (GameCamera.look) and moves a little with G, roll rate,
## turbulence and shake, so the cockpit shows parallax and depth.
##
## Units: metres, eye at the origin, -Z forward, +Y up, +X right.

var game: Node
var active := false
var vp: SubViewport
var cam: Camera3D
var canvas_vp: SubViewport
var art_static: CockpitArt
var art_dyn: CockpitArt
var mat: ShaderMaterial
var glass_mat: StandardMaterial3D
var _body: MeshInstance3D
var _glass: MeshInstance3D
var _stick: MeshInstance3D
var _thr: MeshInstance3D
var _root: Node3D

# style (read by CockpitArt)
var cls := -1
var tier := 1
var slots: Array = []
var pc: Array = [] # panel paint 0..4 (dimmed at night)
var ac: Array = [] # frame / glareshield metal 0..2
var suit := Color("5b6246")
var glow := Color(0.35, 1.0, 0.5)
var night_q := 0.0
var _plane := -2
var _static_key := ""
var _head := Vector3.ZERO
var _head_v := Vector3.ZERO
var _t := 0.0
## HUD combiner glass corners (cockpit space) for the overlay projection.
var hud_quad: PackedVector3Array

const CLASS := [
	{"panel": ["262a31", "6f7681", "878e99", "a3aab4", "c9ced6"], "arch": ["15171b", "2c2f36", "5a5f69"], "suit": "a68d63",
		"glow": Color(0.35, 1.0, 0.5), "wf": 0.54, "wb": 0.62, "bow": 0.035},
	{"panel": ["0d0e11", "1d1f24", "2b2e35", "3f434b", "666c78"], "arch": ["0b0c0e", "1f2125", "43474f"], "suit": "5b6246",
		"glow": Color(0.4, 1.0, 0.75), "wf": 0.58, "wb": 0.68, "bow": 0.045},
	{"panel": ["101109", "20221a", "2e3125", "454936", "6c715a"], "arch": ["0d0e0a", "23251d", "4b4f40"], "suit": "4f5a3c",
		"glow": Color(1.0, 0.72, 0.3), "wf": 0.56, "wb": 0.66, "bow": 0.055},
]

const Z_PT := -0.74
const Z_PB := -0.64
const Y_PT := -0.205
const Y_PB := -0.5
const PT_HW := 0.52
const PB_HW := 0.36
const SILL_Y := -0.19
const BOW_Z := -0.44 # front canopy bow: where it leaves the sills


func _ready() -> void:
	canvas_vp = SubViewport.new()
	canvas_vp.size = CockpitArt.SIZE
	canvas_vp.transparent_bg = true
	canvas_vp.disable_3d = true
	canvas_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	canvas_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(canvas_vp)
	art_static = CockpitArt.new()
	art_static.mode = CockpitArt.STATIC
	art_static.owner3d = self
	canvas_vp.add_child(art_static)
	art_dyn = CockpitArt.new()
	art_dyn.mode = CockpitArt.DYNAMIC
	art_dyn.owner3d = self
	canvas_vp.add_child(art_dyn)

	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.positional_shadow_atlas_size = 0
	vp.audio_listener_enable_3d = false
	add_child(vp)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 6.0
	cam.current = true
	vp.add_child(cam)
	_root = Node3D.new()
	vp.add_child(_root)

	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/cockpit.gdshader")
	mat.set_shader_parameter("tex", canvas_vp.get_texture())
	glass_mat = StandardMaterial3D.new()
	glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat.albedo_color = Color(0.45, 0.9, 0.6, 0.12)
	_body = MeshInstance3D.new()
	_body.material_override = mat
	_root.add_child(_body)
	_glass = MeshInstance3D.new()
	_glass.material_override = glass_mat
	_root.add_child(_glass)
	_stick = MeshInstance3D.new()
	_stick.material_override = mat
	_root.add_child(_stick)
	_thr = MeshInstance3D.new()
	_thr.material_override = mat
	_root.add_child(_thr)


## Resize with the low-res world view.
func set_size(s: Vector2i) -> void:
	if vp.size != s:
		vp.size = s


func texture() -> Texture2D:
	return vp.get_texture()


# ------------------------------------------------------------------ style

func _style(pi: int) -> void:
	_plane = pi
	var d: Dictionary = Planes.LIST[maxi(pi, 0)]
	cls = int(d["branch"])
	tier = int(d["tier"])
	var c: Dictionary = CLASS[cls]
	glow = c["glow"]
	suit = Color(c["suit"])
	if cls == Planes.HEAVY and tier >= 3:
		slots = ["p"]
	else:
		slots = ["l", "r", "c"]
	_build(c)
	_static_key = ""


func _paint(nq: float) -> void:
	var c: Dictionary = CLASS[maxi(cls, 0)]
	var k := lerpf(1.0, 0.4, nq)
	pc.clear()
	for h: String in c["panel"]:
		var col := Color(h) * k
		col.a = 1.0
		pc.append(col)
	ac.clear()
	for h: String in c["arch"]:
		var col := Color(h) * k
		col.a = 1.0
		ac.append(col)
	suit = Color(c["suit"]) * lerpf(1.0, 0.55, nq)
	suit.a = 1.0


# ------------------------------------------------------------------ geometry

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _uv := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()


func _begin() -> void:
	_v = PackedVector3Array()
	_n = PackedVector3Array()
	_uv = PackedVector2Array()
	_c = PackedColorArray()
	_i = PackedInt32Array()


func _commit() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_TEX_UV] = _uv
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_INDEX] = _i
	var m := ArrayMesh.new()
	if not _v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Quad a (top-left) b (top-right) c (bottom-right) d (bottom-left) mapped to
## atlas region `reg` (pixels; sub = part of it, 0..1). lit = false: emissive.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, reg: Rect2, lit: bool = true, tint: Color = Color.WHITE, sub: Rect2 = Rect2(0, 0, 1, 1)) -> void:
	var o := _v.size()
	var nrm := (d - a).cross(b - a)
	if nrm.length_squared() < 1e-12:
		nrm = (c - b).cross(a - b)
	nrm = nrm.normalized()
	var inv := Vector2(1.0 / CockpitArt.SIZE.x, 1.0 / CockpitArt.SIZE.y)
	var r0 := reg.position + reg.size * sub.position
	var r1 := reg.position + reg.size * sub.end
	var uvs := [Vector2(r0.x, r0.y), Vector2(r1.x, r0.y), Vector2(r1.x, r1.y), Vector2(r0.x, r1.y)]
	for p in [a, b, c, d]:
		_v.append(p)
		_n.append(nrm)
	for u: Vector2 in uvs:
		_uv.append(u * inv)
	var col := Color(tint.r, tint.g, tint.b, 1.0 if lit else 0.0)
	for k in 4:
		_c.append(col)
	_i.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))


## Square-section bar from p0 to p1 (w across, h along `up`).
func bar(p0: Vector3, p1: Vector3, w: float, h: float, up: Vector3, reg: Rect2, tint: Color = Color.WHITE) -> void:
	var ax := (p1 - p0).normalized()
	var side := ax.cross(up).normalized() * w * 0.5
	var u := side.cross(ax).normalized() * h * 0.5
	var corners := [u + side, u - side, -u - side, -u + side]
	for k in 4:
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		quad(p0 + c0, p0 + c1, p1 + c1, p1 + c0, reg, true, tint)


## Tube with an octagonal section along points (legs).
func tube(pts: Array, radii: Array, reg: Rect2) -> void:
	var seg := 12
	for j in range(pts.size() - 1):
		var a0: Vector3 = pts[j]
		var a1: Vector3 = pts[j + 1]
		var ax := (a1 - a0).normalized()
		var s := ax.cross(Vector3.UP)
		if s.length_squared() < 1e-6:
			s = ax.cross(Vector3.FORWARD)
		s = s.normalized()
		var u := s.cross(ax).normalized()
		for k in seg:
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var d0 := s * cos(t0) + u * sin(t0)
			var d1 := s * cos(t1) + u * sin(t1)
			var r0: float = radii[j]
			var r1: float = radii[j + 1]
			quad(a0 + d0 * r0, a0 + d1 * r0, a1 + d1 * r1, a1 + d0 * r1, reg, true, Color.WHITE,
				Rect2(float(k) / seg, float(j) / (pts.size() - 1), 1.0 / seg, 1.0 / (pts.size() - 1)))


## Point on the instrument panel face for panel-texture pixel (u, v).
func panel_pt(u: float, v: float, lift: float = 0.0) -> Vector3:
	var su := u / CockpitArt.R["panel"].size.x
	var sv := v / CockpitArt.R["panel"].size.y
	var top := Vector3(lerpf(-PT_HW, PT_HW, su), Y_PT, Z_PT)
	var bot := Vector3(lerpf(-PB_HW, PB_HW, su), Y_PB, Z_PB)
	var p := top.lerp(bot, sv)
	var nrm := Vector3(0, 0.3, 1).normalized()
	return p + nrm * lift


func _panel_rect(r: Rect2, reg: Rect2, lit: bool, lift: float) -> void:
	quad(panel_pt(r.position.x, r.position.y, lift), panel_pt(r.end.x, r.position.y, lift),
		panel_pt(r.end.x, r.end.y, lift), panel_pt(r.position.x, r.end.y, lift), reg, lit)


func _build(c: Dictionary) -> void:
	var R: Dictionary = CockpitArt.R
	var wf: float = c["wf"]
	var wb: float = c["wb"]
	var bow: float = c["bow"]
	_begin()
	# instrument panel + displays (emissive, a few mm in front)
	quad(Vector3(-PT_HW, Y_PT, Z_PT), Vector3(PT_HW, Y_PT, Z_PT), Vector3(PB_HW, Y_PB, Z_PB), Vector3(-PB_HW, Y_PB, Z_PB), R["panel"])
	for s: String in slots:
		var reg: Rect2 = R["dp"] if s == "p" else R["d" + s]
		_panel_rect(CockpitArt.SLOTS[s], reg, false, 0.003)
	# lower knee panel below the main one
	quad(Vector3(-PB_HW, Y_PB, Z_PB), Vector3(PB_HW, Y_PB, Z_PB), Vector3(0.3, -0.7, -0.58), Vector3(-0.3, -0.7, -0.58), R["knee"])
	# side panels angled from the panel edges to the tub walls
	for sx in [-1.0, 1.0]:
		var pt := Vector3(sx * PT_HW, Y_PT, Z_PT)
		var pb := Vector3(sx * PB_HW, Y_PB, Z_PB)
		var wt := Vector3(sx * wf, SILL_Y - 0.02, -0.66)
		var wbm := Vector3(sx * wf, -0.34, -0.6)
		if sx < 0:
			quad(wt, pt, pb, wbm, R["knee"], true, Color(0.9, 0.9, 0.9), Rect2(0, 0, 0.4, 1))
		else:
			quad(pt, wt, wbm, pb, R["knee"], true, Color(0.9, 0.9, 0.9), Rect2(0.6, 0, 0.4, 1))
	# glareshield hood with a front lip overhanging the displays
	var segs := 10
	var gw := PT_HW + 0.03
	for k in segs:
		var u0 := lerpf(-1.0, 1.0, float(k) / segs)
		var u1 := lerpf(-1.0, 1.0, float(k + 1) / segs)
		var f0 := Vector3(u0 * (gw + 0.02), -0.19 + 0.012 * (1.0 - u0 * u0), -0.78)
		var f1 := Vector3(u1 * (gw + 0.02), -0.19 + 0.012 * (1.0 - u1 * u1), -0.78)
		var n0 := Vector3(u0 * gw, -0.172 + 0.02 * (1.0 - u0 * u0), -0.6 - 0.04 * u0 * u0)
		var n1 := Vector3(u1 * gw, -0.172 + 0.02 * (1.0 - u1 * u1), -0.6 - 0.04 * u1 * u1)
		quad(f0, f1, n1, n0, R["glare"])
		quad(n0, n1, n1 + Vector3(0, -0.035, 0.004), n0 + Vector3(0, -0.035, 0.004), R["glare"], true, Color(0.8, 0.8, 0.8))
		# under side of the hood (dark, seen past the lip)
		quad(n0 + Vector3(0, -0.035, 0.004), n1 + Vector3(0, -0.035, 0.004), Vector3(u1 * PT_HW, Y_PT, Z_PT), Vector3(u0 * PT_HW, Y_PT, Z_PT), R["glare"], true, Color(0.5, 0.5, 0.5))
	# warning lights on the lip, left and right of the keypad
	for sx in [-1.0, 1.0]:
		var x0: float = sx * 0.11
		var x1: float = sx * 0.3
		var y0 := -0.162
		var a0 := Vector3(minf(x0, x1), y0 + 0.006, -0.598)
		var b0 := Vector3(maxf(x0, x1), y0 + 0.006, -0.598)
		quad(a0, b0, b0 + Vector3(0, -0.018, 0.002), a0 + Vector3(0, -0.018, 0.002), R["warn"], false, Color.WHITE, Rect2(0 if sx < 0 else 0.5, 0, 0.5, 1))
	# up-front keypad (UFC) standing under the HUD
	var uw := 0.095 if cls == Planes.ATTACK else 0.08
	var uh := 0.11 if cls == Planes.ATTACK else 0.09
	var ut := -0.165
	var ufl := Vector3(-uw, ut, -0.615)
	var ufr := Vector3(uw, ut, -0.615)
	quad(ufl, ufr, Vector3(uw, ut - uh, -0.63), Vector3(-uw, ut - uh, -0.63), R["ufc"], false)
	quad(Vector3(-uw, ut, -0.68), Vector3(uw, ut, -0.68), ufr, ufl, R["metal"])
	for sx in [-1.0, 1.0]:
		quad(Vector3(sx * uw, ut, -0.68), Vector3(sx * uw, ut, -0.615), Vector3(sx * uw, ut - uh, -0.63), Vector3(sx * uw, ut - uh, -0.69), R["metal"], true, Color(0.7, 0.7, 0.7))
	# HUD: projector housing, two posts, top bar, combiner glass
	var hw := 0.125
	var hb := ut + 0.008
	quad(Vector3(-hw * 0.7, hb + 0.022, -0.67), Vector3(hw * 0.7, hb + 0.022, -0.67), Vector3(hw * 0.7, hb + 0.022, -0.625), Vector3(-hw * 0.7, hb + 0.022, -0.625), R["metal"])
	quad(Vector3(-hw * 0.7, hb + 0.022, -0.625), Vector3(hw * 0.7, hb + 0.022, -0.625), Vector3(hw * 0.7, hb - 0.008, -0.62), Vector3(-hw * 0.7, hb - 0.008, -0.62), R["metal"], true, Color(0.75, 0.75, 0.75))
	var gb := hb + 0.024
	var gt := gb + 0.17
	for sx in [-1.0, 1.0]:
		bar(Vector3(sx * (hw + 0.006), hb, -0.64), Vector3(sx * (hw + 0.01), gt + 0.01, -0.675), 0.012, 0.012, Vector3(0, 0, 1), R["metal"])
	bar(Vector3(-hw - 0.01, gt + 0.008, -0.675), Vector3(hw + 0.01, gt + 0.008, -0.675), 0.01, 0.008, Vector3(0, 1, 0), R["metal"])
	hud_quad = PackedVector3Array([Vector3(-hw, gt, -0.675), Vector3(hw, gt, -0.675), Vector3(hw, gb, -0.643), Vector3(-hw, gb, -0.643)])
	# tub walls, consoles, sill rails
	for sx in [-1.0, 1.0]:
		var wfront := Vector3(sx * wf, SILL_Y, -0.7)
		var wback := Vector3(sx * wb, SILL_Y, 0.45)
		var flo := Vector3(0, -0.95 - SILL_Y, 0)
		if sx < 0:
			quad(wback, wfront, wfront + flo, wback + flo, R["wall"])
		else:
			quad(wfront, wback, wback + flo, wfront + flo, R["wall"])
		# console: top surface (u: inner -> outer, v: front -> back)
		var ci0 := Vector3(sx * 0.3, -0.325, -0.6)
		var ci1 := Vector3(sx * 0.3, -0.335, 0.35)
		var co0 := Vector3(sx * (wf - 0.015), -0.305, -0.62)
		var co1 := Vector3(sx * (wb - 0.015), -0.315, 0.35)
		var reg: Rect2 = R["cons_l"] if sx < 0 else R["cons_r"]
		quad(ci0, co0, co1, ci1, reg)
		# inner face and front face of the console
		quad(ci0, ci1, ci1 + Vector3(0, -0.6, 0), ci0 + Vector3(0, -0.6, 0), R["wall"], true, Color(0.75, 0.75, 0.75))
		quad(co0, ci0, ci0 + Vector3(0, -0.6, 0), co0 + Vector3(0, -0.6, 0), R["frame"], true, Color(0.8, 0.8, 0.8))
		# canopy rail on top of the wall: top + inner face
		var ri0 := wfront + Vector3(-sx * 0.05, 0.0, 0.0)
		var ri1 := wback + Vector3(-sx * 0.05, 0.0, 0.0)
		quad(ri0, wfront + Vector3(0, 0.012, 0), wback + Vector3(0, 0.012, 0), ri1, R["sill"], true, Color.WHITE, Rect2(0, 0, 1, 0.4))
		quad(ri1, ri0, ri0 + Vector3(0, -0.05, 0), ri1 + Vector3(0, -0.05, 0), R["sill"], true, Color(0.85, 0.85, 0.85))
	# canopy bows: the big front arc overhead, a rear bow behind the head
	_bow(wf + 0.03, SILL_Y, BOW_Z, 0.52, 0.14, bow, R["metal"])
	_bow(wb, SILL_Y, 0.42, 0.62, 0.06, bow, R["metal"])
	# rear-view mirrors on the front bow
	for k in [-1, 0, 1]:
		var th: float = PI * 0.5 + k * 0.42
		var p := _bow_pt(wf + 0.03, SILL_Y, BOW_Z, 0.52, 0.14, th) + Vector3(0, -bow * 0.6, 0.02)
		var mside := Vector3(cos(th - PI * 0.5), 0, 0) * 0.0
		var mw := 0.05
		quad(p + Vector3(-mw, 0.012, 0) + mside, p + Vector3(mw, 0.012, 0), p + Vector3(mw, -0.012, 0.004), p + Vector3(-mw, -0.012, 0.004), R["glass"], false, Color(0.5, 0.62, 0.8))
	if cls == Planes.ATTACK:
		# heavy windscreen posts from the glareshield corners up to the bow
		for sx in [-1.0, 1.0]:
			var x: float = sx * 0.3
			var th := acos(clampf(-x / (wf + 0.03), -1.0, 1.0))
			var top := _bow_pt(wf + 0.03, SILL_Y, BOW_Z, 0.52, 0.14, th)
			bar(Vector3(x * 0.85, -0.17, -0.66), top, 0.022, 0.026, Vector3(0, 0, 1), R["metal"])
	# legs: thighs to the knees, shins under the panel; kneeboard on the right
	for sx in [-1.0, 1.0]:
		var hip := Vector3(sx * 0.12, -0.6, 0.12)
		var knee := Vector3(sx * 0.15, -0.33, -0.44)
		var ankle := Vector3(sx * 0.14, -0.95, -0.55)
		tube([hip, hip.lerp(knee, 0.55), knee.lerp(hip, 0.12), knee + Vector3(0, 0.005, -0.03), knee + Vector3(0, -0.06, -0.06), ankle],
			[0.09, 0.08, 0.068, 0.058, 0.055, 0.05], R["suit"])
	var kb := Vector3(0.155, -0.27, -0.3)
	quad(kb + Vector3(-0.04, 0.012, -0.05), kb + Vector3(0.04, 0.012, -0.05), kb + Vector3(0.045, -0.02, 0.05), kb + Vector3(-0.045, -0.02, 0.05), R["board"])
	# seat headrest and sides behind the pilot
	quad(Vector3(-0.17, 0.2, 0.24), Vector3(0.17, 0.2, 0.24), Vector3(0.17, -0.25, 0.26), Vector3(-0.17, -0.25, 0.26), R["seat"])
	for sx in [-1.0, 1.0]:
		quad(Vector3(sx * 0.2, 0.12, 0.26), Vector3(sx * 0.2, 0.12, 0.2), Vector3(sx * 0.24, -0.6, 0.16), Vector3(sx * 0.24, -0.6, 0.28), R["frame"], true, Color(0.6, 0.6, 0.6))
	_body.mesh = _commit()
	# HUD combiner glass (transparent)
	_begin()
	quad(hud_quad[0], hud_quad[1], hud_quad[2], hud_quad[3], R["glass"], false)
	_glass.mesh = _commit()
	# stick (pivots at the floor; grip on top)
	_begin()
	var g0 := Vector3(0, 0.26, -0.02)
	bar(Vector3.ZERO, g0, 0.024, 0.024, Vector3(0, 0, 1), R["metal"], Color(0.7, 0.7, 0.7))
	bar(Vector3(0, 0.02, 0), Vector3(0, 0.07, 0), 0.07, 0.07, Vector3(0, 0, 1), R["suit"], Color(0.4, 0.4, 0.4)) # rubber boot
	bar(g0, g0 + Vector3(0, 0.11, -0.014), 0.05, 0.058, Vector3(0, 0, 1), R["stick"])
	bar(g0 + Vector3(0, 0.095, -0.012), g0 + Vector3(0, 0.12, -0.04), 0.03, 0.03, Vector3(0, 0, 1), R["stick"], Color(1.4, 1.4, 1.4)) # hat head
	_stick.mesh = _commit()
	_stick.position = Vector3(0, -0.62, -0.43)
	# throttle lever on the left console
	_begin()
	bar(Vector3.ZERO, Vector3(0, 0.07, 0.0), 0.02, 0.02, Vector3(0, 0, 1), R["metal"])
	bar(Vector3(0, 0.07, 0), Vector3(0, 0.1, -0.02), 0.06, 0.045, Vector3(0, 0, 1), R["thr"])
	_thr.mesh = _commit()


func _bow_pt(w: float, y0: float, z0: float, hgt: float, back: float, th: float) -> Vector3:
	return Vector3(-cos(th) * w, y0 + hgt * sin(th), z0 + back * sin(th))


## Canopy bow: an arc from one sill over the head to the other.
func _bow(w: float, y0: float, z0: float, hgt: float, back: float, t: float, reg: Rect2) -> void:
	var n := 18
	for k in n:
		var th0 := PI * k / n
		var th1 := PI * (k + 1) / n
		var p0 := _bow_pt(w, y0, z0, hgt, back, th0)
		var p1 := _bow_pt(w, y0, z0, hgt, back, th1)
		var mid := (p0 + p1) * 0.5
		var inward := Vector3(-mid.x, -(mid.y - y0), 0).normalized()
		bar(p0, p1, 0.035, t, inward, reg)


# ------------------------------------------------------------------ per frame

func update(delta: float, alpha: float) -> void:
	var was := active
	active = alpha > 0.01 and game != null and game.jet != null
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	canvas_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		return
	var jet: Jet = game.jet
	if jet.plane != _plane:
		_style(jet.plane)
	var dn = game.daynight
	var nt: float = dn.night if dn != null else 0.0
	var nq := snappedf(nt, 0.1)
	if nq != night_q or _static_key == "" or not was:
		night_q = nq
		_paint(nq)
		_static_key = "%d_%.1f" % [_plane, nq]
		art_static.queue_redraw()
	# lighting: the sun and the ambient seen from inside the plane
	var b: Basis = jet.visual_basis()
	var sw: Vector3 = dn.sun_dir() if dn != null else Vector3(0.3, 0.8, 0.3).normalized()
	mat.set_shader_parameter("sun_dir", b.inverse() * sw)
	mat.set_shader_parameter("sun_k", (1.0 - nt) * 0.85)
	var amb: Color = dn.amb_color if dn != null else Color.WHITE
	mat.set_shader_parameter("amb_col", Vector3(amb.r, amb.g, amb.b) * lerpf(0.75, 0.55, nt))
	mat.set_shader_parameter("night", nt)
	mat.set_shader_parameter("glow_col", Vector3(glow.r, glow.g, glow.b))
	mat.set_shader_parameter("flash", 0.0)
	glass_mat.albedo_color = Color(glow.r * 0.5, glow.g * 0.7, glow.b * 0.6, 0.1 + 0.06 * nt)
	# head: sinks under G, leans against the roll, shakes in turbulence
	_t += delta
	var gc: GameCamera = game.cam
	var target := Vector3(clampf(-jet._roll_rate * 0.012, -0.03, 0.03), clampf(-(jet.g_load - 1.0) * 0.006, -0.045, 0.02), 0.0)
	var turb := 0.0015 + 0.004 * clampf(jet.speed / 250.0, 0.0, 1.0) * (1.0 if jet.position.y < 300.0 else 0.4)
	target += Vector3(sin(_t * 13.1) * turb, sin(_t * 17.3 + 1.3) * turb, 0)
	target += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * gc.shake * 0.002
	_head_v += (target - _head) * 140.0 * delta
	_head_v *= exp(-delta * 16.0)
	_head += _head_v * delta
	var look: Vector2 = gc.look
	cam.transform = Transform3D(Basis(Vector3.UP, look.x) * Basis(Vector3.RIGHT, look.y), _head + Basis(Vector3.UP, look.x) * Vector3(0, 0, 0.02))
	cam.fov = gc.fov
	# stick and throttle follow the controls
	var st: Vector2 = jet._stick()
	_stick.basis = Basis(Vector3.RIGHT, -st.y * 0.22) * Basis(Vector3.BACK, -st.x * 0.28)
	_thr.position = Vector3(-0.42, -0.32, lerpf(0.05, -0.3, jet.throttle))


## Screen rect (low-res pixels) of the HUD combiner glass, and the boresight
## (the plane's nose at infinity) - for the HUD symbology overlay.
func hud_screen() -> Array:
	var pts: Array[Vector2] = []
	if hud_quad.size() < 4:
		return [Rect2(), Vector2.INF]
	for p in hud_quad:
		if cam.is_position_behind(p):
			return [Rect2(), Vector2.INF]
		pts.append(cam.unproject_position(p))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var fwd := Vector3(0, 0, -1000)
	var bs := Vector2.INF if cam.is_position_behind(fwd) else cam.unproject_position(fwd)
	return [r, bs]


## Screen y of the glareshield lip at the screen centre (helmet symbology
## is hidden below it).
func lip_y() -> float:
	var p := Vector3(0, -0.17, -0.6)
	if cam.is_position_behind(p):
		return 1e9
	return cam.unproject_position(p).y
