class_name WorldMap
extends Node3D
## Applies a map from Maps.LIST: island heightmap (seed, land share), relief
## (mesas / mountains), city size, neon, terrain palette, clouds, time of day,
## battle-area boundary and landmarks (built from collapsed stacks, with
## collision boxes that the chunk manager checks like buildings).

var index := -1
var def: Dictionary = {}
var half := 5600.0 # battle area half size (world units)
var landmarks: Array = [] # [{name, pos}]
var game: Node
var _nodes: Array[Node] = []

const BORDER_WARN := 350.0 # warning starts this far inside the edge


func current() -> Dictionary:
	return def if not def.is_empty() else Maps.by_index(0)


## Switch maps (no-op if already active unless force).
func apply(i: int, force: bool = false) -> void:
	i = clampi(i, 0, Maps.LIST.size() - 1)
	if i == index and not force:
		return
	index = i
	def = Maps.by_index(i)
	var st: Dictionary = Save.settings
	var seed := int(def["seed"])
	var land := float(def["land"])
	if i == 0:
		# tropical islands keep the settings' island share and seed
		seed = int(st.get("seed", seed))
		land = float(st.get("islands", land))
	CityGen.feature = int(def["feature"])
	CityGen.city_scale = float(def["city"])
	CityGen.town_scale = float(def["towns"])
	CityGen.neon = def["id"] == "night"
	half = float(def["half"])
	Traffic.boats_enabled = CityGen.feature == CityGen.FEAT_NONE
	Stacks.rebuild_islands(seed, land)
	_place_landmarks()
	# keep relief off the city, spawn lanes, bases and landmarks (virtual units)
	var spots: Array = []
	if CityGen.city_scale > 0.0:
		spots.append([Vector2.ZERO, 1150.0 * CityGen.city_scale * 0.9])
	for z in [1300.0, -1300.0]:
		spots.append([Vector2(0, z), 520.0])
	for lm in landmarks:
		spots.append([Vector2(lm["pos"].x, lm["pos"].z) / CityGen.S, 90.0])
	CityGen.clear_spots = spots
	_build_landmarks()
	_apply_palette()
	if game != null and game.daynight != null:
		game.daynight.beam_count = 4 if CityGen.neon else 3
	if game != null:
		game.chunks.reset_all()
		game.traffic._urban.clear()


func _apply_palette() -> void:
	if game == null:
		return
	var mat: ShaderMaterial = game.terrain.material_override
	var pal: Dictionary = def["pal"]
	for k in ["deepest", "deep", "shallow", "sand", "sand_wet", "grass", "grass_light", "forest"]:
		var c: Color = pal[k]
		mat.set_shader_parameter(k.to_upper(), Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("frozen", pal["frozen"])
	mat.set_shader_parameter("bound_half", half)


## Time of day for this map (tropical follows the settings).
func time_of_day() -> float:
	if index <= 0:
		return [0.42, 0.745, 0.0][int(Save.settings.get("time", 0))]
	return float(def["time"])


func spawn_alt() -> float:
	return float(def["alt"])


func cloud_amount() -> float:
	if index <= 0:
		return float(Save.settings.get("clouds", 0.45))
	return float(def["clouds"])


## How far outside the battle area (world units, <0 = inside).
func outside(p: Vector3) -> float:
	return maxf(absf(p.x), absf(p.z)) - half


# ------------------------------------------------------------------ landmarks

const LM_NAMES := {"lighthouse": "LIGHTHOUSE", "tower": "SKY TOWER", "needle": "THE NEEDLE", "arch": "STONE ARCH", "beacon": "BEACON"}


func _free_spot(p: Vector3) -> Vector3:
	for r in [0.0, 150.0, 300.0, 500.0, 800.0, 1200.0, 1700.0]:
		for k in 12:
			var a := TAU * k / 12.0
			var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * r
			if CityGen.island_hw(q.x, q.z) > CityGen.URBAN_H + 0.01 and not CityGen.is_urban(floori(q.x / CityGen.WBLOCK), floori(q.z / CityGen.WBLOCK)):
				return Vector3(q.x, 0, q.z)
	return Vector3(p.x, 0, p.z)


func _place_landmarks() -> void:
	landmarks.clear()
	# relief must not be considered while searching (it is cleared afterwards)
	var feat := CityGen.feature
	CityGen.feature = CityGen.FEAT_NONE
	for lm in def["landmarks"]:
		var kind: String = lm[0]
		landmarks.append({"kind": kind, "name": LM_NAMES.get(kind, kind.to_upper()), "pos": _free_spot(lm[1])})
	CityGen.feature = feat


func _build_landmarks() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	var boxes := PackedFloat32Array()
	for lm in landmarks:
		var cb := CityGen.Build.new()
		cb.sheets = Stacks.sheets
		var p: Vector3 = lm["pos"] / CityGen.S
		var x := p.x
		var z := p.z
		var top := 0.0
		match lm["kind"]:
			"tower":
				_b(cb, x, z, 16, 0, 10, CityGen.F_TERMINAL, CityGen.R_CONCRETE)
				_b(cb, x, z, 5, 10, 150, CityGen.F_WHITE, CityGen.R_CONCRETE)
				_b(cb, x, z, 18, 116, 132, CityGen.F_GLASS_DARK, CityGen.R_METAL)
				_b(cb, x, z, 12, 132, 138, CityGen.F_WHITE, CityGen.R_METAL)
				cb.p.add_stack(Stacks.get_sheet("antenna"), 0, Vector3(x, 150.3, z), 0.0, 2.0, Color.WHITE, 2)
				top = 160.0
				_reg(boxes, x, z, 9.0, 150.0)
			"lighthouse":
				for k in 5:
					var w := 12.0 - k * 1.2
					_b(cb, x, z, w, k * 10.0, k * 10.0 + 10.0, CityGen.F_WHITE if k % 2 == 0 else CityGen.F_FACTORY, CityGen.R_TAR)
				_b(cb, x, z, 7, 50, 56, CityGen.F_GLASS, CityGen.R_METAL)
				top = 56.0
				_reg(boxes, x, z, 6.0, 56.0)
			"needle":
				_b(cb, x, z, 30, 0, 90, CityGen.F_ROCK, CityGen.R_SAND)
				_b(cb, x + 2, z - 1, 18, 90, 150, CityGen.F_ROCK, CityGen.R_SAND)
				_b(cb, x + 1, z + 1, 9, 150, 195, CityGen.F_ROCK, CityGen.R_SAND)
				top = 195.0
				_reg(boxes, x, z, 15.0, 195.0)
			"arch":
				for sx in [-1.0, 1.0]:
					_b(cb, x + sx * 40.0, z, 18, 0, 100, CityGen.F_ROCK, CityGen.R_SAND)
					_reg(boxes, x + sx * 40.0, z, 9.0, 100.0)
				CityGen._box(cb, x - 49, z - 9, x + 49, z + 9, 100.0, 120.0, CityGen.F_ROCK, CityGen.R_SAND, 0.4, false)
				top = 120.0
			"beacon":
				_b(cb, x, z, 22, 0, 8, CityGen.F_WAREHOUSE, CityGen.R_CONCRETE)
				for k in 6:
					_b(cb, x, z, 5, 8 + k * 26.0, 34 + k * 26.0, CityGen.F_WHITE if k % 2 == 0 else CityGen.F_FACTORY, CityGen.R_METAL)
				top = 164.0
				_reg(boxes, x, z, 4.0, 164.0)
		var node := MeshInstance3D.new()
		var m := cb.b.commit()
		m.surface_set_material(0, Stacks.building_mat)
		if not cb.p.is_empty():
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cb.p.to_arrays())
			m.surface_set_material(1, Stacks.static_mat)
		node.mesh = m
		node.scale = Vector3.ONE * CityGen.S
		add_child(node)
		_nodes.append(node)
		lm["top"] = top * CityGen.S
	if game != null:
		game.chunks.extra_boxes = boxes


func _b(cb: CityGen.Build, x: float, z: float, w: float, y0: float, y1: float, style: int, roof: int) -> void:
	var h := w * 0.5
	CityGen._box(cb, x - h, z - h, x + h, z + h, y0, y1, style, roof, fposmod(x * 0.013 + z * 0.007, 1.0), y0 <= 0.0)


## Collision box (world units) for the chunk manager.
func _reg(boxes: PackedFloat32Array, x: float, z: float, hw: float, h: float) -> void:
	var S := CityGen.S
	boxes.append_array(PackedFloat32Array([(x - hw) * S, (z - hw) * S, (x + hw) * S, (z + hw) * S, h * S]))
