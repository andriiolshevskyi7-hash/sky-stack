class_name ChunkManager
extends Node3D
## Streams the infinite city in 256x256 chunks around a focus point.
## Chunk geometry is generated on WorkerThreadPool threads (pure data), then
## turned into 4 meshes on the main thread: ground, buildings (collapsed
## stacks), props (static sprite stacks batched into one mesh) and night glow.
## => ~4 draw calls per chunk regardless of how many objects it contains.

signal chunk_loaded(key: Vector2i)

var radius := 2
var max_chunks := -1 # -1 = infinite streaming; >=0 limits (used by step-1 / tests)
var use_threads := true
var focus := Vector3.ZERO

var chunks := {} # Vector2i -> Dictionary {node, data}
var _pending := {} # Vector2i -> task id
var _results := {}
var _mutex := Mutex.new()
var destroyed := {} # building id -> true
var building_hp := {} # building id -> hp left
var _regen := {} # keys to regenerate after destruction


func _key_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CityGen.WCHUNK), floori(z / CityGen.WCHUNK))


func wanted_keys() -> Array[Vector2i]:
	var c := _key_at(focus.x, focus.z)
	var out: Array[Vector2i] = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			out.append(c + Vector2i(dx, dz))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
	if max_chunks >= 0:
		out.resize(mini(out.size(), max_chunks))
	return out


## Synchronously generate everything around the focus (loading screen / tests).
func load_all_now() -> void:
	for k in wanted_keys():
		if not chunks.has(k):
			_finish(CityGen.generate_chunk(k.x, k.y, Stacks.sheets, destroyed.duplicate()))


func _process(_delta: float) -> void:
	var wanted := wanted_keys()
	var started := 0
	for k in wanted:
		var need := (not chunks.has(k)) or _regen.has(k)
		if need and not _pending.has(k) and started < 2:
			_regen.erase(k)
			_start(k)
			started += 1
	# collect results
	var done: Array = []
	_mutex.lock()
	for k in _results:
		done.append(_results[k])
	_results.clear()
	_mutex.unlock()
	for data in done:
		var k: Vector2i = data["key"]
		if _pending.has(k):
			if _pending[k] >= 0:
				WorkerThreadPool.wait_for_task_completion(_pending[k])
			_pending.erase(k)
		_finish(data)
	# unload far chunks
	var c := _key_at(focus.x, focus.z)
	var drop: Array[Vector2i] = []
	for k in chunks:
		var d: Vector2i = k - c
		if absi(d.x) > radius + 1 or absi(d.y) > radius + 1:
			drop.append(k)
	for k in drop:
		chunks[k]["node"].queue_free()
		chunks.erase(k)


func _start(k: Vector2i) -> void:
	var snapshot := destroyed.duplicate()
	if use_threads:
		_pending[k] = WorkerThreadPool.add_task(_task.bind(k, snapshot), false, "chunk")
	else:
		_pending[k] = -1
		_task(k, snapshot)


func _task(k: Vector2i, snapshot: Dictionary) -> void:
	var data := CityGen.generate_chunk(k.x, k.y, Stacks.sheets, snapshot)
	_mutex.lock()
	_results[k] = data
	_mutex.unlock()


func _mesh_node(arrays: Array, mat: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _finish(data: Dictionary) -> void:
	var k: Vector2i = data["key"]
	# geometry is in virtual units: render the chunk at world scale and convert
	# the gameplay data (boxes, roofs, chimneys) to world units
	for arr_name in ["boxes", "roofs", "chimneys"]:
		var a: PackedFloat32Array = data[arr_name]
		for i in a.size():
			a[i] *= CityGen.S
		data[arr_name] = a
	var node := Node3D.new()
	node.scale = Vector3.ONE * CityGen.S
	node.name = "Chunk_%d_%d" % [k.x, k.y]
	if not data["ground"].is_empty():
		node.add_child(_mesh_node(data["ground"], Stacks.ground_mat, "Ground"))
	if not data["build"].is_empty():
		node.add_child(_mesh_node(data["build"], Stacks.building_mat, "Buildings"))
	if not data["props"].is_empty():
		node.add_child(_mesh_node(data["props"], Stacks.static_mat, "Props"))
	if not data["glow"].is_empty():
		node.add_child(_mesh_node(data["glow"], Stacks.glow_mat, "Glow"))
	add_child(node)
	if chunks.has(k):
		chunks[k]["node"].queue_free()
	chunks[k] = {"node": node, "data": data}
	chunk_loaded.emit(k)


# ------------------------------------------------------------------ gameplay queries

## Circle vs building footprints taller than min_h. Returns push-out vector
## (Vector2.ZERO = no hit). Sets last_hit_id.
var last_hit_id := -1


func collide(x: float, z: float, r: float, min_h: float) -> Vector2:
	var k := _key_at(x, z)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var kk := k + Vector2i(dx, dz)
			if not chunks.has(kk):
				continue
			var cx0 := kk.x * CityGen.WCHUNK
			var cz0 := kk.y * CityGen.WCHUNK
			if x + r + 2.0 < cx0 or x - r - 2.0 > cx0 + CityGen.WCHUNK or z + r + 2.0 < cz0 or z - r - 2.0 > cz0 + CityGen.WCHUNK:
				continue
			var b: PackedFloat32Array = chunks[kk]["data"]["boxes"]
			var ids: PackedInt64Array = chunks[kk]["data"]["ids"]
			var n := b.size() / 5
			for i in n:
				var o := i * 5
				if b[o + 4] < min_h:
					continue
				var nx := clampf(x, b[o], b[o + 2])
				var nz := clampf(z, b[o + 1], b[o + 3])
				var ddx := x - nx
				var ddz := z - nz
				var d2 := ddx * ddx + ddz * ddz
				if d2 < r * r:
					last_hit_id = ids[i]
					if d2 < 0.0001:
						# centre inside the box: push out along the shallowest axis
						var l := x - b[o]
						var rr := b[o + 2] - x
						var t := z - b[o + 1]
						var bb := b[o + 3] - z
						var m := minf(minf(l, rr), minf(t, bb))
						if m == l:
							return Vector2(-(l + r), 0)
						if m == rr:
							return Vector2(rr + r, 0)
						if m == t:
							return Vector2(0, -(t + r))
						return Vector2(0, bb + r)
					var d := sqrt(d2)
					return Vector2(ddx, ddz) / d * (r - d)
	return Vector2.ZERO


## Distance to the nearest building at least min_h tall (capped at max_d).
func nearest_tall(x: float, z: float, min_h: float, max_d: float) -> float:
	var best := max_d
	var k := _key_at(x, z)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var kk := k + Vector2i(dx, dz)
			if not chunks.has(kk):
				continue
			var b: PackedFloat32Array = chunks[kk]["data"]["boxes"]
			var n := b.size() / 5
			for i in n:
				var o := i * 5
				if b[o + 4] < min_h:
					continue
				var ddx := x - clampf(x, b[o], b[o + 2])
				var ddz := z - clampf(z, b[o + 1], b[o + 3])
				var d := sqrt(ddx * ddx + ddz * ddz)
				if d < best:
					best = d
	return best


## Random intact building near pos (within radius). Returns {} if none.
## Result: {id, pos: Vector3 (roof centre), h}
func random_building(pos: Vector3, radius_w: float, min_h: float, rng: RandomNumberGenerator) -> Dictionary:
	var keys := chunks.keys()
	if keys.is_empty():
		return {}
	for attempt in 12:
		var kk: Vector2i = keys[rng.randi() % keys.size()]
		var b: PackedFloat32Array = chunks[kk]["data"]["boxes"]
		var ids: PackedInt64Array = chunks[kk]["data"]["ids"]
		var n := b.size() / 5
		if n == 0:
			continue
		var i := rng.randi() % n
		var o := i * 5
		if b[o + 4] < min_h or destroyed.has(ids[i]):
			continue
		var c := Vector3((b[o] + b[o + 2]) * 0.5, b[o + 4], (b[o + 1] + b[o + 3]) * 0.5)
		if Vector2(c.x - pos.x, c.z - pos.z).length() > radius_w:
			continue
		return {"id": ids[i], "pos": c, "h": b[o + 4], "size": Vector2(b[o + 2] - b[o], b[o + 3] - b[o + 1])}
	return {}


## Roof spots for anti-air guns (tall buildings near pos).
func roof_spot(pos: Vector3, min_r: float, max_r: float, rng: RandomNumberGenerator) -> Vector3:
	var keys := chunks.keys()
	for attempt in 20:
		var kk: Vector2i = keys[rng.randi() % keys.size()]
		var r: PackedFloat32Array = chunks[kk]["data"]["roofs"]
		var n := r.size() / 3
		if n == 0:
			continue
		var i := rng.randi() % n
		var p := Vector3(r[i * 3], r[i * 3 + 2], r[i * 3 + 1])
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d >= min_r and d <= max_r:
			return p
	return Vector3.INF


func chimney_tops(pos: Vector3, max_r: float, out: PackedVector3Array) -> void:
	out.clear()
	for kk in chunks:
		var c: PackedFloat32Array = chunks[kk]["data"]["chimneys"]
		for i in c.size() / 3:
			var p := Vector3(c[i * 3], c[i * 3 + 1], c[i * 3 + 2])
			if Vector2(p.x - pos.x, p.z - pos.z).length() < max_r:
				out.append(p)


func building_box(id: int) -> Dictionary:
	for kk in chunks:
		var ids: PackedInt64Array = chunks[kk]["data"]["ids"]
		var i := ids.find(id)
		if i >= 0:
			var b: PackedFloat32Array = chunks[kk]["data"]["boxes"]
			var o := i * 5
			return {"key": kk, "pos": Vector3((b[o] + b[o + 2]) * 0.5, b[o + 4], (b[o + 1] + b[o + 3]) * 0.5), "h": b[o + 4]}
	return {}


## Apply damage; returns true if the building was destroyed by this hit.
func damage_building(id: int, amount: float) -> bool:
	if destroyed.has(id):
		return false
	var info := building_box(id)
	if info.is_empty():
		return false
	var hp: float = building_hp.get(id, clampf(info["h"] * 0.5, 10.0, 60.0))
	hp -= amount
	building_hp[id] = hp
	if hp <= 0.0:
		destroyed[id] = true
		_regen[info["key"]] = true
		return true
	return false


## Drop every chunk (world was regenerated); they stream back in.
func reset_all() -> void:
	for k in chunks:
		chunks[k]["node"].queue_free()
	chunks.clear()
	for k in _pending:
		_regen[k] = true


func total_quads() -> int:
	var q := 0
	for k in chunks:
		q += chunks[k]["data"]["quads"]
	return q


func _exit_tree() -> void:
	for k in _pending:
		if _pending[k] >= 0:
			WorkerThreadPool.wait_for_task_completion(_pending[k])
	_pending.clear()
