class_name Clouds
extends Node3D
## Clouds you can fly through.
##  Volumetric (medium / high quality): a full-screen ray-marched cumulus
##  layer (shaders/cloud_vol.gdshader) shaped by the shared coverage field
##  (Stacks.cloud_img / cloud_tex, drifting with DayNight.cloud_offset) - the
##  same field that casts the cloud shadows, so clouds and shadows move
##  together. Lit by the physical sun (pink at dusk), dark bases, silver
##  lining; inside one -> white-out.
##  Classic (low quality): sprite-stacked puffs on the peaks of that field.
## density() is the CPU twin of the shader's shape (no erosion detail): it
## drives the white-out fog, hides planes inside clouds from missiles and
## lock-on, and tells bots where to hide.

const COUNT := 26
const RANGE := 2600.0
const SCALE := 6.0
const PUFF_R := 170.0
## Size of one tile of the coverage field (world units; GPU uses the same).
const FIELD := 4200.0
## The volumetric layer covers more sky than the classic puffs: its
## threshold sits this far below `cover` (~35 % of the sky at 0.45 clouds).
const VOL_OFFSET := 0.13

var focus := Vector3.ZERO
var daynight: DayNight
var rng := RandomNumberGenerator.new()
var anchors: Array[Vector2] = [] # anchored in noise space (moves with the wind)
var variants := PackedInt32Array()
var batch: StackBatch
var mat: ShaderMaterial
## 0..1 opacity of the classic puffs (dithered)
var opacity := 1.0
## coverage threshold on the cloud noise (lower = more clouds), set from settings
var cover := 0.62
var fog := 0.0
var _img: Image
var _cov: Image
## cloud layer: base altitude and full thickness (cumulus tops)
var base := 650.0
var thick := 500.0
var volumetric := true
var vol: MeshInstance3D
var vol_mat: ShaderMaterial
## weather (G7): heavier, darker clouds; lightning flash inside them
var darkness := 0.0
var flash := 0.0

## Back-compat for code that asked for the classic layer height.
var BASE_Y: float:
	get:
		return base


func _ready() -> void:
	rng.seed = 77
	_img = Stacks.cloud_img
	_cov = Stacks.cloud_cov_img
	var m: ShaderMaterial = Stacks.batch_material("cloud").duplicate()
	m.set_shader_parameter("receive_shadow", false)
	m.set_shader_parameter("fadeable", true)
	m.set_shader_parameter("near_fade", 260.0)
	mat = m
	batch = StackBatch.new().setup("cloud", COUNT * 3, m)
	add_child(batch)
	for i in COUNT:
		anchors.append(Vector2(INF, 0))
		variants.append(rng.randi() % 3)
	# the volumetric pass: a full-screen quad drawn after the world
	vol = MeshInstance3D.new()
	vol.name = "VolumetricClouds"
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	vol.mesh = q
	vol_mat = ShaderMaterial.new()
	vol_mat.shader = preload("res://shaders/cloud_vol.gdshader")
	vol_mat.set_shader_parameter("detail_tex", Stacks.cloud_detail_tex)
	vol_mat.set_shader_parameter("noise3d", Stacks.cloud_noise3d)
	vol_mat.render_priority = 10
	vol.material_override = vol_mat
	vol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vol.extra_cull_margin = 16384.0
	vol.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	add_child(vol)
	set_quality(2)


## Graphics quality: 0 classic puffs, 1 volumetric (12 steps), 2 volumetric
## (20 steps).
func set_quality(q: int) -> void:
	volumetric = q >= 1
	vol.visible = volumetric
	batch.visible = not volumetric
	vol_mat.set_shader_parameter("steps", 20 if q >= 2 else 12)


## Cloud layer for the current map (base altitude, thickness).
func set_layer(p_base: float, p_thick: float) -> void:
	base = p_base
	thick = p_thick
	RenderingServer.global_shader_parameter_set("cloud_base", base)
	vol_mat.set_shader_parameter("thick", thick)


func _noise(x: float, z: float, off: Vector2) -> float:
	return _sample(_img, x, z, off)


func _sample(img: Image, x: float, z: float, off: Vector2) -> float:
	if img == null:
		return 0.0
	# bilinear like the GPU's linear filter on the repeating texture
	var u := fposmod((x + off.x) / FIELD, 1.0) * 128.0 - 0.5
	var v := fposmod((z + off.y) / FIELD, 1.0) * 128.0 - 0.5
	var x0 := int(floor(u))
	var y0 := int(floor(v))
	var fx := u - x0
	var fy := v - y0
	var a := img.get_pixel(posmod(x0, 128), posmod(y0, 128)).r
	var b := img.get_pixel(posmod(x0 + 1, 128), posmod(y0, 128)).r
	var c := img.get_pixel(posmod(x0, 128), posmod(y0 + 1, 128)).r
	var d := img.get_pixel(posmod(x0 + 1, 128), posmod(y0 + 1, 128)).r
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Cloud density 0..1 at a world point (the shader's shape without the
## erosion detail; the classic puffs count as dense inside their radius).
func density(pos: Vector3) -> float:
	if not volumetric:
		return 1.0 if _in_puff(pos) else 0.0
	if pos.y < base or pos.y > base + thick:
		return 0.0
	var off := daynight.cloud_offset if daynight != null else Vector2.ZERO
	var vt := cover - VOL_OFFSET
	var a := _smooth(vt, vt + 0.2, _sample(_cov, pos.x, pos.z, off))
	if a <= 0.001:
		return 0.0
	var top := thick * (0.25 + 0.75 * sqrt(a))
	var h := (pos.y - base) / top
	if h < 0.0 or h > 1.0:
		return 0.0
	var prof := _smooth(0.0, 0.05, h) * sqrt(maxf(1.0 - h * h, 0.0))
	var d := prof * (0.35 + 0.65 * a) * _smooth(0.0, 0.25 + 0.6 * h, a) - 0.5 * 0.45
	return clampf(d * 3.0, 0.0, 1.0)


func _in_puff(pos: Vector3) -> bool:
	if pos.y < base - 10.0 or pos.y > base + 14.0 * SCALE:
		return false
	for i in COUNT:
		if anchors[i].x == INF:
			continue
		var w := world_pos(i)
		if Vector2(w.x - pos.x, w.z - pos.z).length() < PUFF_R:
			return true
	return false


func world_pos(i: int) -> Vector3:
	var off := daynight.cloud_offset if daynight != null else Vector2.ZERO
	var q := anchors[i]
	return Vector3(q.x - off.x, base, q.y - off.y)


## A good hiding altitude / spot near p: the densest of a few samples in the
## middle of the layer (bots fly there to break a lock).
func hide_spot(p: Vector3) -> Vector3:
	var best := Vector3(p.x, base + thick * 0.3, p.z)
	var bd := density(best)
	for k in 8:
		var a := k * TAU / 8.0
		var c := Vector3(p.x + cos(a) * 700.0, base + thick * 0.3, p.z + sin(a) * 700.0)
		var dd := density(c)
		if dd > bd:
			bd = dd
			best = c
	return best


func _process(delta: float) -> void:
	vol_mat.set_shader_parameter("dark", darkness)
	vol_mat.set_shader_parameter("flash", flash)
	vol_mat.set_shader_parameter("density_k", 1.0 + darkness * 0.6)
	if volumetric:
		return
	var off := daynight.cloud_offset if daynight != null else Vector2.ZERO
	mat.set_shader_parameter("dither_alpha", opacity)
	batch.begin()
	for i in COUNT:
		var q := anchors[i]
		var p := Vector2(q.x - off.x, q.y - off.y)
		if q.x == INF or p.distance_to(Vector2(focus.x, focus.z)) > RANGE + 150.0:
			anchors[i] = Vector2(INF, 0)
			for attempt in 24:
				var a := rng.randf() * TAU
				var c := Vector2(focus.x, focus.z) + Vector2(cos(a), sin(a)) * rng.randf_range(60.0, RANGE)
				if _noise(c.x, c.y, off) > cover + 0.06:
					anchors[i] = c + off
					p = c
					break
			if anchors[i].x == INF:
				continue
		var v := variants[i]
		var pos := Vector3(p.x, base, p.y)
		batch.push_scaled(pos, 0.0, v, Color.WHITE, SCALE, SCALE)
		batch.push_scaled(pos + Vector3(120, -8, 52), 1.2, (v + 1) % 3, Color.WHITE, SCALE * 0.75, SCALE * 0.7)
		batch.push_scaled(pos + Vector3(-104, -4, -68), 2.5, (v + 2) % 3, Color.WHITE, SCALE * 0.7, SCALE * 0.65)
	batch.end()


## Is a point inside a cloud? (clouds block missile lock-on and seekers)
func inside(pos: Vector3) -> bool:
	return density(pos) > 0.3


## White-out amount for the camera / jet at pos (0..1).
func fog_at(pos: Vector3, delta: float) -> float:
	var want := clampf(density(pos) * 1.4, 0.0, 0.85) if volumetric else (0.7 if _in_puff(pos) else 0.0)
	fog = move_toward(fog, want, delta * (2.5 if want > fog else 1.5))
	return fog
