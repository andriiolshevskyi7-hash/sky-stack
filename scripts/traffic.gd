class_name Traffic
extends Node3D
## Ground life around the camera: cars/buses on the city street grid
## (right-hand traffic, turning at intersections, U-turns at dead ends) and
## boats/ships cruising the ocean between the islands. Pooled + instanced.

const CARS := 150
## Settings "traffic": 0 off, 1 low (few cars, main avenues only), 2 normal.
const LEVEL_CARS := [0, 24, CARS]
const MAIN_EVERY := 4 # low traffic: only every 4th street is a main avenue
var level := 1
const RADIUS := 760.0
const LANE := 4.0 * CityGen.S

var focus := Vector3.ZERO
var rng := RandomNumberGenerator.new()

# cars: struct of arrays
var c_pos := PackedVector3Array()
var c_axis := PackedByteArray() # 0 = along X, 1 = along Z
var c_dir := PackedFloat32Array()
var c_speed := PackedFloat32Array()
var c_var := PackedInt32Array()
var c_bus := PackedByteArray()
var c_next := PackedFloat32Array() # next intersection coordinate along axis
var car_batch: StackBatch
var bus_batch: StackBatch


# boats: Vector4(x, z_offset, dir, speed) for river; ships along the coast
var river_boats: Array[Vector4] = []
var sea_boats: Array[Vector4] = [] # (x_offset_from_coast, z, dir, speed)
var boat_batch: StackBatch
var ship_batch: StackBatch
var active_cars := 0
var fx: Fx


func _ready() -> void:
	rng.seed = 2024
	c_pos.resize(CARS)
	c_axis.resize(CARS)
	c_dir.resize(CARS)
	c_speed.resize(CARS)
	c_var.resize(CARS)
	c_bus.resize(CARS)
	c_next.resize(CARS)
	car_batch = StackBatch.new().setup("car", CARS)
	bus_batch = StackBatch.new().setup("bus", CARS)
	boat_batch = StackBatch.new().setup("boat", 16)
	ship_batch = StackBatch.new().setup("ship", 6)
	for b in [car_batch, bus_batch, boat_batch, ship_batch]:
		add_child(b)
	for i in CARS:
		_respawn_car(i)
	# a few slow vessels (3x fewer than before)
	for i in 3:
		river_boats.append(Vector4(0, 0, 0, -1))
	for i in 1:
		sea_boats.append(Vector4(0, 0, 0, -1))


var _urban := {}


func _is_urban(bx: int, bz: int) -> bool:
	var k := Vector2i(bx, bz)
	if not _urban.has(k):
		if _urban.size() > 6000:
			_urban.clear()
		_urban[k] = CityGen.is_urban(bx, bz)
	return _urban[k]


## Cached version of CityGen.is_drivable (main thread only).
func _drivable(x: float, z: float, along_x: bool) -> bool:
	if along_x:
		var row := roundi(z / CityGen.WBLOCK)
		var bx := floori(x / CityGen.WBLOCK)
		return _is_urban(bx, row - 1) or _is_urban(bx, row)
	var col := roundi(x / CityGen.WBLOCK)
	var bz := floori(z / CityGen.WBLOCK)
	return _is_urban(col - 1, bz) or _is_urban(col, bz)


func _yaw(axis: int, dir: float) -> float:
	if axis == 0:
		return -PI * 0.5 if dir > 0.0 else PI * 0.5
	return PI if dir > 0.0 else 0.0


func set_level(l: int) -> void:
	level = clampi(l, 0, 2)
	for i in CARS:
		c_speed[i] = 0.0 # respawn under the new rules


func _main_ok(axis: int, p: Vector3) -> bool:
	if level != 1:
		return true
	var line := roundi((p.z if axis == 0 else p.x) / CityGen.WBLOCK)
	return posmod(line, MAIN_EVERY) == 0


func _respawn_car(i: int) -> void:
	for attempt in 8:
		var axis := rng.randi() % 2
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		var along := rng.randf_range(-RADIUS, RADIUS)
		var across := rng.randf_range(-RADIUS, RADIUS)
		var p: Vector3
		if axis == 0:
			var row := roundi((focus.z + across) / CityGen.WBLOCK)
			p = Vector3(focus.x + along, 0.0, row * CityGen.WBLOCK + LANE * dir)
		else:
			var col := roundi((focus.x + across) / CityGen.WBLOCK)
			p = Vector3(col * CityGen.WBLOCK - LANE * dir, 0.0, focus.z + along)
		if not _drivable(p.x, p.z, axis == 0) or not _main_ok(axis, p):
			continue
		c_pos[i] = p
		c_axis[i] = axis
		c_dir[i] = dir
		c_bus[i] = 1 if rng.randf() < 0.12 else 0
		c_speed[i] = rng.randf_range(32.0, 60.0) * (0.75 if c_bus[i] == 1 else 1.0)
		c_var[i] = rng.randi() % (2 if c_bus[i] == 1 else 6)
		var a := p.x if axis == 0 else p.z
		c_next[i] = (floorf(a / CityGen.WBLOCK) + (1.0 if dir > 0.0 else 0.0)) * CityGen.WBLOCK
		return
	c_speed[i] = 0.0
	c_pos[i] = Vector3(0, -999, 0)


func _process(delta: float) -> void:
	_cars(delta)
	_boats(delta)


func _cars(delta: float) -> void:
	car_batch.begin()
	bus_batch.begin()
	active_cars = 0
	var respawns := 0
	for i in LEVEL_CARS[level]:
		var p := c_pos[i]
		if c_speed[i] <= 0.0 or Vector2(p.x - focus.x, p.z - focus.z).length() > RADIUS + 90.0:
			if respawns < 10:
				respawns += 1
				_respawn_car(i)
			continue
		var axis := c_axis[i]
		var dir := c_dir[i]
		var step := c_speed[i] * delta * dir
		var a := p.x if axis == 0 else p.z
		var na := a + step
		var crossed := (dir > 0.0 and na >= c_next[i]) or (dir < 0.0 and na <= c_next[i])
		if crossed:
			var inter := c_next[i]
			c_next[i] += CityGen.WBLOCK * dir
			var r := rng.randf()
			if r < 0.3 and level == 2:
				# turn onto the crossing street (right-hand traffic lanes)
				var new_dir := 1.0 if rng.randf() < 0.5 else -1.0
				var np: Vector3
				if axis == 0:
					var col_x := inter
					np = Vector3(col_x - LANE * new_dir, 0.0, p.z)
				else:
					var row_z := inter
					np = Vector3(p.x, 0.0, row_z + LANE * new_dir)
				var new_axis := 1 - axis
				if _drivable(np.x + (new_dir * 12.0 if new_axis == 0 else 0.0), np.z + (new_dir * 12.0 if new_axis == 1 else 0.0), new_axis == 0):
					c_axis[i] = new_axis
					c_dir[i] = new_dir
					p = np
					var aa := p.x if new_axis == 0 else p.z
					c_next[i] = (floorf(aa / CityGen.WBLOCK) + (1.0 if new_dir > 0.0 else 0.0)) * CityGen.WBLOCK
					c_pos[i] = p
					axis = new_axis
					dir = new_dir
					step = 0.0
		if axis == 0:
			p.x += step
		else:
			p.z += step
		# dead end (sea, river without bridge, airport): U-turn
		var ahead := p + (Vector3(dir * 10.0, 0, 0) if axis == 0 else Vector3(0, 0, dir * 10.0))
		if not _drivable(ahead.x, ahead.z, axis == 0):
			dir = -dir
			c_dir[i] = dir
			if axis == 0:
				p.z += LANE * 2.0 * dir
			else:
				p.x -= LANE * 2.0 * dir
			var a2 := p.x if axis == 0 else p.z
			c_next[i] = (floorf(a2 / CityGen.WBLOCK) + (1.0 if dir > 0.0 else 0.0)) * CityGen.WBLOCK
		p.y = 0.7
		c_pos[i] = p
		active_cars += 1
		if c_bus[i] == 1:
			bus_batch.push(p, _yaw(axis, dir), c_var[i], Color.WHITE, 0.0, 0.0, 1.0)
		else:
			car_batch.push(p, _yaw(axis, dir), c_var[i], Color.WHITE, 0.0, 0.0, 1.0)
	car_batch.end()
	bus_batch.end()


## No boats on frozen lakes (snow) or desert oases.
static var boats_enabled := true


func _boats(delta: float) -> void:
	boat_batch.begin()
	ship_batch.begin()
	if not boats_enabled:
		boat_batch.end()
		ship_batch.end()
		return
	# boats: Vector4(x, z, yaw, speed); speed < 0 = free slot
	for i in river_boats.size() + sea_boats.size():
		var big := i >= river_boats.size()
		var arr: Array[Vector4] = sea_boats if big else river_boats
		var k := i - river_boats.size() if big else i
		var b := arr[k]
		if b.w < 0.0 or Vector2(b.x - focus.x, b.y - focus.z).length() > 1200.0:
			b.w = -1.0
			for attempt in 6:
				var a := rng.randf() * TAU
				var r := rng.randf_range(250.0, 1100.0)
				var px := focus.x + cos(a) * r
				var pz := focus.z + sin(a) * r
				if CityGen.island_hw(px, pz) < (0.42 if big else 0.47):
					b = Vector4(px, pz, rng.randf() * TAU, rng.randf_range(9.0, 14.0) if big else rng.randf_range(12.0, 20.0))
					break
			if b.w < 0.0:
				arr[k] = b
				continue
		# slow, wide turns: look far ahead, turn gently towards open water
		var fwd := Vector2(-sin(b.z), -cos(b.z))
		var look := 520.0 if big else 260.0
		var ahead := Vector2(b.x, b.y) + fwd * look
		if CityGen.island_hw(ahead.x, ahead.y) > 0.44:
			var l := Vector2(-sin(b.z + 0.5), -cos(b.z + 0.5))
			var lp := Vector2(b.x, b.y) + l * look
			var turn := 1.0 if CityGen.island_hw(lp.x, lp.y) < CityGen.island_hw(ahead.x, ahead.y) else -1.0
			b.z += turn * delta * (0.09 if big else 0.16)
		else:
			b.z += sin(Time.get_ticks_msec() / 9000.0 + k * 2.3) * delta * 0.02 # lazy wander
		b.x += fwd.x * b.w * delta
		b.y += fwd.y * b.w * delta
		arr[k] = b
		if big:
			ship_batch.push(Vector3(b.x, 0.6, b.y), b.z, 0, Color.WHITE, 0.0, 0.0, 1.0)
		else:
			boat_batch.push(Vector3(b.x, 0.6, b.y), b.z, k % 2, Color.WHITE, 0.0, 0.0, 1.0)
		# long V-shaped wake behind the stern
		if fx != null and Engine.get_process_frames() % 18 == i % 18:
			var side := Vector2(-fwd.y, fwd.x)
			var stern := Vector2(b.x, b.y) - fwd * (40.0 if big else 14.0)
			fx.wake_v(Vector3(stern.x, 0.5, stern.y), Vector3(side.x, 0, side.y), 18.0 if big else 10.0, big)
	boat_batch.end()
	ship_batch.end()
