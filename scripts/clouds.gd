class_name Clouds
extends Node3D
## Big fluffy sprite-stacked clouds floating BELOW the jet's cruise altitude.
## Each puff is a cluster of 14-slice stacks. Puffs are placed on the peaks of
## the shared cloud-noise field, which is also what casts the blue cloud
## shadows on the water/ground, so clouds and shadows drift together.
## Dive through one -> white-out fog.

const COUNT := 22
const RANGE := 900.0
const BASE_Y := 62.0
const SCALE := 2.6
const PUFF_R := 70.0

var focus := Vector3.ZERO
var daynight: DayNight
var rng := RandomNumberGenerator.new()
var anchors: Array[Vector2] = [] # anchored in noise space (moves with the wind)
var variants := PackedInt32Array()
var batch: StackBatch
var fog := 0.0
var _img: Image


func _ready() -> void:
	rng.seed = 77
	_img = Stacks.cloud_img
	var m: ShaderMaterial = Stacks.batch_material("cloud").duplicate()
	m.set_shader_parameter("receive_shadow", false)
	m.set_shader_parameter("fadeable", true)
	batch = StackBatch.new().setup("cloud", COUNT * 3, m)
	add_child(batch)
	for i in COUNT:
		anchors.append(Vector2(INF, 0))
		variants.append(rng.randi() % 3)


func _noise(x: float, z: float, off: Vector2) -> float:
	if _img == null:
		return 0.0
	var u := fposmod((x + off.x) / 1400.0, 1.0)
	var v := fposmod((z + off.y) / 1400.0, 1.0)
	return _img.get_pixel(int(u * 128.0) % 128, int(v * 128.0) % 128).r


func world_pos(i: int) -> Vector3:
	var off := daynight.cloud_offset if daynight != null else Vector2.ZERO
	var q := anchors[i]
	return Vector3(q.x - off.x, BASE_Y, q.y - off.y)


func _process(_delta: float) -> void:
	var off := daynight.cloud_offset if daynight != null else Vector2.ZERO
	batch.begin()
	for i in COUNT:
		var q := anchors[i]
		var p := Vector2(q.x - off.x, q.y - off.y)
		if q.x == INF or p.distance_to(Vector2(focus.x, focus.z)) > RANGE + 150.0:
			anchors[i] = Vector2(INF, 0)
			for attempt in 24:
				var a := rng.randf() * TAU
				var c := Vector2(focus.x, focus.z) + Vector2(cos(a), sin(a)) * rng.randf_range(60.0, RANGE)
				if _noise(c.x, c.y, off) > 0.68:
					anchors[i] = c + off
					p = c
					break
			if anchors[i].x == INF:
				continue
		var v := variants[i]
		var pos := Vector3(p.x, BASE_Y, p.y)
		batch.push_scaled(pos, 0.0, v, Color.WHITE, SCALE, SCALE)
		batch.push_scaled(pos + Vector3(60, -4, 26), 1.2, (v + 1) % 3, Color.WHITE, SCALE * 0.75, SCALE * 0.7)
		batch.push_scaled(pos + Vector3(-52, -2, -34), 2.5, (v + 2) % 3, Color.WHITE, SCALE * 0.7, SCALE * 0.65)
	batch.end()


## Fog amount for the jet at pos (0..1).
func fog_at(pos: Vector3, delta: float) -> float:
	var inside := false
	if pos.y > BASE_Y and pos.y < BASE_Y + 14.0 * SCALE:
		for i in COUNT:
			if anchors[i].x == INF:
				continue
			var w := world_pos(i)
			if Vector2(w.x - pos.x, w.z - pos.z).length() < PUFF_R:
				inside = true
				break
	fog = minf(0.7, fog + delta * 2.5) if inside else maxf(0.0, fog - delta * 1.5)
	return fog
