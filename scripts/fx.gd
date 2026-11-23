class_name Fx
extends Node3D
## Pooled pixel particles: explosions, smoke trails, sparks, muzzle flashes,
## afterburner. Structure-of-arrays, swap-remove, zero per-frame allocations.

enum { FIRE, SMOKE, SPARK, FLASH, BURNER, DEBRIS, TRAIL, SPARK_W }
const MAX := 1400

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var life := PackedFloat32Array()
var maxlife := PackedFloat32Array()
var size := PackedFloat32Array()
var kind := PackedInt32Array()
var n := 0
var batch: PointBatch
var rng := RandomNumberGenerator.new()
# persistent smoke columns (burning buildings / chimneys): Vector4(x,y,z,rate)
var columns: Array[Vector4] = []
var chimneys := PackedVector3Array()
var sparks_mult := 0.6
var burner_mult := 0.75
var spray_mult := 1.0
var realistic_flames := false
var _col_t := 0.0

const C_YELLOW := Color(1.0, 0.95, 0.55)
const C_ORANGE := Color(1.0, 0.6, 0.2)
const C_RED := Color(0.85, 0.22, 0.12)
const C_SMOKE := Color(0.45, 0.45, 0.5)
const C_DARK := Color(0.2, 0.2, 0.24)


func _ready() -> void:
	pos.resize(MAX)
	vel.resize(MAX)
	life.resize(MAX)
	maxlife.resize(MAX)
	size.resize(MAX)
	kind.resize(MAX)
	batch = PointBatch.new().setup(MAX)
	batch.name = "FxBatch"
	add_child(batch)


func spawn(p: Vector3, v: Vector3, l: float, s: float, k: int) -> void:
	if n >= MAX:
		return
	pos[n] = p
	vel[n] = v
	life[n] = l
	maxlife[n] = l
	size[n] = s
	kind[n] = k
	n += 1


func _rv(m: float) -> Vector3:
	return Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf() * m


func explosion(p: Vector3, scale: float = 1.0) -> void:
	var sm := sparks_mult / 0.6
	if sparks_mult > 0.0:
		spawn(p, Vector3.ZERO, 0.12, 14.0 * scale * minf(1.5, sm), FLASH)
		for i in int(8 * scale * sm):
			spawn(p, _rv(110.0) + Vector3(0, 30, 0), rng.randf_range(0.2, 0.5), 1.0, SPARK)
	for i in int(26 * scale):
		spawn(p + _rv(3.0 * scale), _rv(60.0 * scale), rng.randf_range(0.3, 0.8), rng.randf_range(1.5, 3.5) * scale, FIRE)
	for i in int(14 * scale):
		spawn(p + _rv(4.0 * scale), _rv(18.0) + Vector3(0, 8, 0), rng.randf_range(0.8, 1.8), rng.randf_range(2.0, 4.0) * scale, SMOKE)
	for i in int(10 * scale):
		spawn(p, _rv(90.0) + Vector3(0, 30, 0), rng.randf_range(0.5, 1.0), 1.0, DEBRIS)


func sparks(p: Vector3, count: int = 10) -> void:
	for i in count:
		spawn(p, _rv(80.0) + Vector3(0, 20, 0), rng.randf_range(0.15, 0.45), 1.0, SPARK)


func hit(p: Vector3) -> void:
	spawn(p, Vector3.ZERO, 0.05, 4.0, FLASH)
	sparks(p, 4)


func smoke(p: Vector3, count: int = 1) -> void:
	for i in count:
		spawn(p + _rv(2.0), Vector3(0, 6, 0) + _rv(4.0), rng.randf_range(0.6, 1.2), rng.randf_range(1.5, 2.5), SMOKE)


func muzzle(p: Vector3) -> void:
	spawn(p, Vector3.ZERO, 0.04, 3.0, FLASH)


func afterburner(p: Vector3, fwd: Vector3, boost: bool = false) -> void:
	if burner_mult <= 0.0:
		return
	var bm := burner_mult / 0.75
	if realistic_flames:
		for i in 3:
			spawn(p + _rv(0.8), -fwd * rng.randf_range(20.0, 45.0) * bm + _rv(3.0), rng.randf_range(0.06, 0.14) * bm, rng.randf_range(2.5, 4.0), BURNER)
		if boost:
			for i in 4:
				spawn(p + _rv(1.2), -fwd * rng.randf_range(50.0, 80.0) * bm + _rv(5.0), rng.randf_range(0.1, 0.22) * bm, rng.randf_range(3.0, 5.0), BURNER)
		return
	spawn(p + _rv(0.6), -fwd * 30.0 * bm + _rv(4.0), rng.randf_range(0.05, 0.1) * bm, 2.0, BURNER)
	if boost:
		spawn(p + _rv(1.0), -fwd * 55.0 + _rv(6.0), rng.randf_range(0.1, 0.2), 3.0, BURNER)
		spawn(p + _rv(1.0), -fwd * 45.0 + _rv(6.0), rng.randf_range(0.08, 0.16), 2.5, BURNER)


## Burning wreckage that tumbles down to the ground trailing smoke.
func debris(p: Vector3, count: int) -> void:
	for i in count:
		spawn(p + _rv(4.0), _rv(70.0) + Vector3(0, 25, 0), rng.randf_range(1.6, 3.0), rng.randf_range(1.5, 3.0), DEBRIS)


## Sea spray / wake when the jet skims the water.
func spray(p: Vector3, k: float) -> void:
	k *= spray_mult
	if k <= 0.0:
		return
	for i in int(1 + k * 3.0):
		spawn(p + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), Vector3(rng.randf_range(-8, 8), rng.randf_range(10, 30) * k, rng.randf_range(-8, 8)), rng.randf_range(0.3, 0.7), rng.randf_range(1.5, 2.5), SPARK_W)
	spawn(p, Vector3.ZERO, 1.4, 2.5, TRAIL)


## White foam wake behind boats.
func wake(p: Vector3) -> void:
	spawn(p + _rv(1.5), Vector3.ZERO, 1.6, 2.0, TRAIL)


## White wingtip vapour trail (one puff per frame per wingtip).
func contrail(p: Vector3) -> void:
	spawn(p, Vector3.ZERO, 1.1, 2.0, TRAIL)


func add_column(p: Vector3, rate: float) -> void:
	if columns.size() >= 16:
		columns.pop_front()
	columns.append(Vector4(p.x, p.y, p.z, rate))


func clear_columns_far(c: Vector3, r: float) -> void:
	for i in range(columns.size() - 1, -1, -1):
		var q := columns[i]
		if Vector2(q.x - c.x, q.z - c.z).length() > r:
			columns.remove_at(i)


func _process(delta: float) -> void:
	_col_t += delta
	if _col_t > 0.12:
		_col_t = 0.0
		for c in chimneys:
			if rng.randf() < 0.35:
				spawn(c + _rv(1.5), Vector3(5, 12, 3) + _rv(2.0), rng.randf_range(1.8, 3.0), rng.randf_range(2.0, 3.0), SMOKE)
		for q in columns:
			if rng.randf() < q.w:
				spawn(Vector3(q.x, q.y, q.z) + _rv(3.0), Vector3(6, 14, 4) + _rv(3.0), rng.randf_range(1.5, 2.6), rng.randf_range(2.0, 3.5), SMOKE)
				if rng.randf() < 0.3:
					spawn(Vector3(q.x, q.y, q.z) + _rv(3.0), Vector3(0, 10, 0) + _rv(6.0), 0.4, 2.0, FIRE)
	var i := 0
	batch.begin()
	while i < n:
		life[i] -= delta
		if life[i] <= 0.0:
			n -= 1
			pos[i] = pos[n]
			vel[i] = vel[n]
			life[i] = life[n]
			maxlife[i] = maxlife[n]
			size[i] = size[n]
			kind[i] = kind[n]
			continue
		var k := kind[i]
		var t := 1.0 - life[i] / maxlife[i]
		var v := vel[i]
		var col: Color
		var s := size[i]
		match k:
			FIRE:
				v *= 1.0 - 3.0 * delta
				col = C_YELLOW.lerp(C_ORANGE, minf(1.0, t * 2.0)) if t < 0.5 else C_RED.lerp(C_DARK, (t - 0.5) * 2.0)
				col.a = 1.0 - t * 0.5
			SMOKE:
				v *= 1.0 - 1.0 * delta
				col = C_SMOKE.lerp(C_DARK, t)
				col.a = 0.85 * (1.0 - t)
				s *= 1.0 + t * 1.5
			SPARK:
				v.y -= 140.0 * delta
				col = C_YELLOW
			SPARK_W:
				v.y -= 60.0 * delta
				col = Color(0.95, 0.98, 1.0, 1.0 - t)
			FLASH:
				col = Color(1, 1, 0.9)
				s *= 1.0 - t * 0.5
			BURNER:
				col = Color(1.0, 0.95, 0.6).lerp(Color(1.0, 0.45, 0.1), minf(1.0, t * 1.6))
				col.a = 1.0 - t * 0.6
				s *= 1.0 - t * 0.5
			TRAIL:
				col = Color(1, 1, 1, 1.0 if t < 0.6 else (1.0 - t) * 2.5)
				s *= 1.0 + t * 0.8
			_:
				# debris: falls, smokes, stops on the ground
				v.y -= 90.0 * delta
				v *= 1.0 - 0.4 * delta
				col = C_DARK if t > 0.15 else C_ORANGE
				if pos[i].y < 1.0:
					pos[i].y = 1.0
					v = Vector3.ZERO
				elif rng.randf() < 0.25:
					spawn(pos[i], Vector3(0, 4, 0), rng.randf_range(0.5, 1.0), rng.randf_range(1.5, 2.5), SMOKE)
		vel[i] = v
		pos[i] += v * delta
		batch.push(pos[i], s, col)
		i += 1
	batch.end()
