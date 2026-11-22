class_name Traffic
extends Node3D
## Ground life around the camera: cars/buses on the street grid (right-hand
## traffic, turning at intersections, crossing bridges), trains on rail rows,
## boats on the river, ships and tugs along the coast. Pooled + instanced.

const CARS := 150
const RADIUS := 430.0
const LANE := 4.0

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

# trains
var train_x := [0.0, 0.0]
var train_row := 99999
var train_batch: StackBatch

# boats: Vector4(x, z_offset, dir, speed) for river; ships along the coast
var river_boats: Array[Vector4] = []
var sea_boats: Array[Vector4] = [] # (x_offset_from_coast, z, dir, speed)
var boat_batch: StackBatch
var ship_batch: StackBatch
var active_cars := 0


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
	train_batch = StackBatch.new().setup("train", 16)
	boat_batch = StackBatch.new().setup("boat", 16)
	ship_batch = StackBatch.new().setup("ship", 6)
	for b in [car_batch, bus_batch, train_batch, boat_batch, ship_batch]:
		add_child(b)
	for i in CARS:
		_respawn_car(i)
	for i in 6:
		river_boats.append(Vector4(0, 0, 0, -1))
	for i in 6:
		sea_boats.append(Vector4(0, 0, 0, -1))


func _yaw(axis: int, dir: float) -> float:
	if axis == 0:
		return -PI * 0.5 if dir > 0.0 else PI * 0.5
	return PI if dir > 0.0 else 0.0


func _respawn_car(i: int) -> void:
	for attempt in 8:
		var axis := rng.randi() % 2
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		var along := rng.randf_range(-RADIUS, RADIUS)
		var across := rng.randf_range(-RADIUS, RADIUS)
		var p: Vector3
		if axis == 0:
			var row := roundi((focus.z + across) / CityGen.BLOCK)
			p = Vector3(focus.x + along, 0.0, row * CityGen.BLOCK + LANE * dir)
		else:
			var col := roundi((focus.x + across) / CityGen.BLOCK)
			p = Vector3(col * CityGen.BLOCK - LANE * dir, 0.0, focus.z + along)
		if not CityGen.is_drivable(p.x, p.z, axis == 0):
			continue
		c_pos[i] = p
		c_axis[i] = axis
		c_dir[i] = dir
		c_bus[i] = 1 if rng.randf() < 0.12 else 0
		c_speed[i] = rng.randf_range(16.0, 30.0) * (0.75 if c_bus[i] == 1 else 1.0)
		c_var[i] = rng.randi() % (2 if c_bus[i] == 1 else 6)
		var a := p.x if axis == 0 else p.z
		c_next[i] = (floorf(a / CityGen.BLOCK) + (1.0 if dir > 0.0 else 0.0)) * CityGen.BLOCK
		return
	c_speed[i] = 0.0
	c_pos[i] = Vector3(0, -999, 0)


func _process(delta: float) -> void:
	_cars(delta)
	_trains(delta)
	_boats(delta)


func _cars(delta: float) -> void:
	car_batch.begin()
	bus_batch.begin()
	active_cars = 0
	for i in CARS:
		var p := c_pos[i]
		if c_speed[i] <= 0.0 or Vector2(p.x - focus.x, p.z - focus.z).length() > RADIUS + 90.0:
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
			c_next[i] += CityGen.BLOCK * dir
			var r := rng.randf()
			if r < 0.3:
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
				if CityGen.is_drivable(np.x + (new_dir * 12.0 if new_axis == 0 else 0.0), np.z + (new_dir * 12.0 if new_axis == 1 else 0.0), new_axis == 0):
					c_axis[i] = new_axis
					c_dir[i] = new_dir
					p = np
					var aa := p.x if new_axis == 0 else p.z
					c_next[i] = (floorf(aa / CityGen.BLOCK) + (1.0 if new_dir > 0.0 else 0.0)) * CityGen.BLOCK
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
		if not CityGen.is_drivable(ahead.x, ahead.z, axis == 0):
			dir = -dir
			c_dir[i] = dir
			if axis == 0:
				p.z += LANE * 2.0 * dir
			else:
				p.x -= LANE * 2.0 * dir
			var a2 := p.x if axis == 0 else p.z
			c_next[i] = (floorf(a2 / CityGen.BLOCK) + (1.0 if dir > 0.0 else 0.0)) * CityGen.BLOCK
		# bridges
		var y := 0.3
		if axis == 1 and CityGen.in_river(p.x, p.z, 8.0):
			y = 1.9
		p.y = y
		c_pos[i] = p
		active_cars += 1
		if c_bus[i] == 1:
			bus_batch.push(p, _yaw(axis, dir), c_var[i])
		else:
			car_batch.push(p, _yaw(axis, dir), c_var[i])
	car_batch.end()
	bus_batch.end()


func _trains(delta: float) -> void:
	train_batch.begin()
	var row := roundi(focus.z / CityGen.BLOCK)
	var best := 99999
	for r in range(row - 8, row + 9):
		if CityGen.is_rail_row(r) and absi(r - row) < absi(best - row):
			best = r
	if best != train_row:
		train_row = best
		train_x[0] = focus.x - 500.0
		train_x[1] = focus.x + 500.0
	if absi(best - row) <= 8:
		var z := train_row * CityGen.BLOCK
		for t in 2:
			var dir := 1.0 if t == 0 else -1.0
			train_x[t] += dir * 38.0 * delta
			if (train_x[t] - focus.x) * dir > 650.0:
				train_x[t] = focus.x - dir * 600.0
			for k in 5:
				var x: float = train_x[t] - dir * k * 45.0
				var y := 0.4
				if CityGen.in_river(x, z, 6.0):
					y = 1.9
				train_batch.push(Vector3(x, y, z + (-3.0 if t == 0 else 3.0)), _yaw(0, dir), 0 if k == 0 else 1)
	train_batch.end()


func _boats(delta: float) -> void:
	boat_batch.begin()
	ship_batch.begin()
	var near_river := absf(CityGen.river_z(focus.x) - focus.z) < 520.0
	for i in river_boats.size():
		var b := river_boats[i]
		if b.w < 0.0 or absf(b.x - focus.x) > 520.0:
			if not near_river:
				river_boats[i] = Vector4(0, 0, 0, -1)
				continue
			b = Vector4(focus.x + rng.randf_range(-480, 480), rng.randf_range(-18, 18), 1.0 if rng.randf() < 0.5 else -1.0, rng.randf_range(10, 22))
		b.x += b.z * b.w * delta
		river_boats[i] = b
		var z := CityGen.river_z(b.x) + b.y
		var dz := CityGen.river_dz(b.x)
		var fwd := Vector2(b.z, dz * b.z).normalized()
		boat_batch.push(Vector3(b.x, 0.6, z), atan2(-fwd.x, -fwd.y), i % 2)
	var coast := CityGen.coast_x(focus.z)
	var near_sea := coast - focus.x < 650.0
	for i in sea_boats.size():
		var b := sea_boats[i]
		if b.w < 0.0 or absf(b.y - focus.z) > 560.0:
			if not near_sea:
				sea_boats[i] = Vector4(0, 0, 0, -1)
				continue
			b = Vector4(rng.randf_range(40, 380), focus.z + rng.randf_range(-500, 500), 1.0 if rng.randf() < 0.5 else -1.0, rng.randf_range(8, 18))
		b.y += b.z * b.w * delta
		sea_boats[i] = b
		var x := CityGen.coast_x(b.y) + b.x
		var yaw := PI if b.z > 0.0 else 0.0
		if i < 2:
			ship_batch.push(Vector3(x + 60.0, 0.6, b.y), yaw, 0)
		else:
			boat_batch.push(Vector3(x, 0.6, b.y), yaw, i % 2)
	boat_batch.end()
	ship_batch.end()
