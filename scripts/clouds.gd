class_name Clouds
extends Node3D
## Layered sprite-stacked clouds. The high layer is placed exactly where the
## shared cloud-noise field casts its drifting shadows, so shadows match the
## clouds. The low layer sits at the jet's altitude: fly through it -> fog.

const LOW := 12
const HIGH := 16
const RANGE := 620.0
const HIGH_Y := 110.0
const LOW_Y := 38.0
const PUFF_R := 34.0

var focus := Vector3.ZERO
var daynight: DayNight
var rng := RandomNumberGenerator.new()
var low_pos: Array[Vector3] = []
var low_var := PackedInt32Array()
var high_q: Array[Vector2] = [] # anchored in noise space (moves with the wind)
var high_var := PackedInt32Array()
var low_batch: StackBatch
var high_batch: StackBatch
var fog := 0.0
var _img: Image


func _make_mat(alpha: float) -> ShaderMaterial:
	var m: ShaderMaterial = Stacks.batch_material("cloud").duplicate()
	m.set_shader_parameter("dither_alpha", alpha)
	m.set_shader_parameter("receive_shadow", false)
	m.set_shader_parameter("fadeable", true)
	return m


func _ready() -> void:
	rng.seed = 77
	_img = Stacks.cloud_img
	low_batch = StackBatch.new().setup("cloud", LOW * 3, _make_mat(0.5))
	high_batch = StackBatch.new().setup("cloud", HIGH * 3, _make_mat(0.42))
	add_child(low_batch)
	add_child(high_batch)
	for i in LOW:
		low_pos.append(Vector3(INF, 0, 0))
		low_var.append(rng.randi() % 3)
	for i in HIGH:
		high_q.append(Vector2(INF, 0))
		high_var.append(rng.randi() % 3)


func _noise(x: float, z: float, off: Vector2) -> float:
	if _img == null:
		return 0.0
	var u := fposmod((x + off.x) / 1400.0, 1.0)
	var v := fposmod((z + off.y) / 1400.0, 1.0)
	return _img.get_pixel(int(u * 128.0) % 128, int(v * 128.0) % 128).r


func _process(delta: float) -> void:
	var off := daynight.cloud_offset if daynight != null else Vector2.ZERO
	var wind := DayNight.WIND
	low_batch.begin()
	high_batch.begin()
	# high clouds: world pos = q - off (drift with the shadow field)
	for i in HIGH:
		var q := high_q[i]
		var p := Vector2(q.x - off.x, q.y - off.y)
		if q.x == INF or p.distance_to(Vector2(focus.x, focus.z)) > RANGE + 100.0:
			for attempt in 24:
				var a := rng.randf() * TAU
				var c := Vector2(focus.x, focus.z) + Vector2(cos(a), sin(a)) * rng.randf_range(80.0, RANGE)
				if _noise(c.x, c.y, off) > 0.66:
					high_q[i] = c + off
					p = c
					break
			if high_q[i].x == INF:
				continue
		_puff(high_batch, Vector3(p.x, HIGH_Y, p.y), high_var[i], 1.9)
	# low clouds drift too (no matching shadow needed, they are small)
	fog = maxf(0.0, fog - delta * 1.5)
	for i in LOW:
		var lp := low_pos[i]
		lp.x -= wind.x * delta
		lp.z -= wind.y * delta
		if lp.x == INF or Vector2(lp.x - focus.x, lp.z - focus.z).length() > RANGE + 80.0:
			var a := rng.randf() * TAU
			var r := rng.randf_range(250.0, RANGE) if lp.x != INF else rng.randf_range(60.0, RANGE)
			lp = Vector3(focus.x + cos(a) * r, LOW_Y + rng.randf_range(-3, 3), focus.z + sin(a) * r)
		low_pos[i] = lp
		_puff(low_batch, lp, low_var[i], 1.25)
	low_batch.end()
	high_batch.end()


func _puff(b: StackBatch, p: Vector3, v: int, s: float) -> void:
	b.push_scaled(p, 0.0, v, Color.WHITE, s, s * 0.9)
	b.push_scaled(p + Vector3(28, -2, 10) * s * 0.5, 1.2, (v + 1) % 3, Color.WHITE, s * 0.75, s * 0.7)
	b.push_scaled(p + Vector3(-22, 1, -14) * s * 0.5, 2.5, (v + 2) % 3, Color.WHITE, s * 0.65, s * 0.6)


## Fog amount for the jet at pos (0..1).
func fog_at(pos: Vector3, delta: float) -> float:
	var inside := false
	for lp in low_pos:
		if lp.x != INF and absf(pos.y - lp.y - 6.0) < 12.0 and Vector2(lp.x - pos.x, lp.z - pos.z).length() < PUFF_R:
			inside = true
			break
	if inside:
		fog = minf(0.55, fog + delta * 2.5)
	return fog
