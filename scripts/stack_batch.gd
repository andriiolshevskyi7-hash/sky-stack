class_name StackBatch
extends MultiMeshInstance3D
## GPU-instanced renderer for one slice sheet: ONE draw call for every
## instance of that sprite stack. Rotation, variant selection, bank shear and
## hit flash are applied in the vertex shader from per-instance custom data.
##
## Two usage styles:
##  * immediate: begin() ... push(...) ... end() every frame (managers: cars, enemies)
##  * slots:     alloc() once, set_slot() when it moves, auto-flushed (SpriteStack nodes)

const STRIDE := 20 # 12 transform + 4 colour + 4 custom

var sheet_name := ""
var capacity := 0
var count := 0
var buf := PackedFloat32Array()
var _slot_mode := false
var _free: Array[int] = []
var _used := 0
var _dirty := false

static var _shared := {}


func setup(p_sheet: String, p_capacity: int, mat: Material = null) -> StackBatch:
	sheet_name = p_sheet
	capacity = p_capacity
	name = "Batch_" + p_sheet
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Stacks.make_stack_mesh(p_sheet)
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = mat if mat != null else Stacks.batch_material(p_sheet)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# instances roam the whole world: never cull the batch as a whole
	custom_aabb = AABB(Vector3(-1e6, -500, -1e6), Vector3(2e6, 2000, 2e6))
	buf.resize(capacity * STRIDE)
	buf.fill(0.0)
	return self


## Shared slot-mode batch for SpriteStack nodes (one per sheet per world).
static func shared(p_sheet: String, host: Node) -> StackBatch:
	var key := "%s@%d" % [p_sheet, host.get_instance_id()]
	if _shared.has(key) and is_instance_valid(_shared[key]):
		return _shared[key]
	var b := StackBatch.new().setup(p_sheet, 64)
	b._slot_mode = true
	b.process_priority = 1000
	host.add_child.call_deferred(b)
	_shared[key] = b
	return b


func begin() -> void:
	count = 0


func _write(i: int, pos: Vector3, yaw: float, variant: int, tint: Color, bank: float, flash: float, scale: float) -> void:
	var o := i * STRIDE
	buf[o] = scale
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = pos.x
	buf[o + 4] = 0.0
	buf[o + 5] = scale
	buf[o + 6] = 0.0
	buf[o + 7] = pos.y
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = scale
	buf[o + 11] = pos.z
	buf[o + 12] = tint.r
	buf[o + 13] = tint.g
	buf[o + 14] = tint.b
	buf[o + 15] = tint.a
	buf[o + 16] = wrapf(yaw, -PI, PI)
	buf[o + 17] = float(variant)
	buf[o + 18] = bank
	buf[o + 19] = flash


func push(pos: Vector3, yaw: float, variant: int = 0, tint: Color = Color.WHITE, bank: float = 0.0, flash: float = 0.0, scale: float = 1.0) -> void:
	if count >= capacity:
		return
	_write(count, pos, yaw, variant, tint, bank, flash, scale)
	count += 1


## Non-uniform scale variant (used for clouds).
func push_scaled(pos: Vector3, yaw: float, variant: int, tint: Color, sx: float, sy: float) -> void:
	if count >= capacity:
		return
	_write(count, pos, yaw, variant, tint, 0.0, 0.0, sx)
	buf[count * STRIDE + 5] = sy
	count += 1


func end() -> void:
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buf)
	multimesh.visible_instance_count = count


# ---------------------------------------------------------------- slot mode

func alloc() -> int:
	var i: int
	if not _free.is_empty():
		i = _free.pop_back()
	elif _used < capacity:
		i = _used
		_used += 1
	else:
		return -1
	return i


func release(i: int) -> void:
	if i < 0:
		return
	_write(i, Vector3(0, -9999, 0), 0.0, 0, Color.WHITE, 0.0, 0.0, 0.0)
	_free.append(i)
	_dirty = true


func set_slot(i: int, pos: Vector3, yaw: float, variant: int, tint: Color, bank: float, flash: float, scale: float) -> void:
	if i < 0:
		return
	_write(i, pos, yaw, variant, tint, bank, flash, scale)
	_dirty = true


## Full rotation in the instance basis (pitch/roll), yaw in the shader = 0.
func set_slot_basis(i: int, pos: Vector3, b: Basis, variant: int, tint: Color, flash: float) -> void:
	if i < 0:
		return
	_write(i, pos, 0.0, variant, tint, 0.0, flash, 1.0)
	_set_basis(i, b)
	_dirty = true


func push_basis(pos: Vector3, b: Basis, variant: int = 0, tint: Color = Color.WHITE, flash: float = 0.0) -> void:
	if count >= capacity:
		return
	_write(count, pos, 0.0, variant, tint, 0.0, flash, 1.0)
	_set_basis(count, b)
	count += 1


func _set_basis(i: int, b: Basis) -> void:
	var o := i * STRIDE
	buf[o] = b.x.x
	buf[o + 1] = b.y.x
	buf[o + 2] = b.z.x
	buf[o + 4] = b.x.y
	buf[o + 5] = b.y.y
	buf[o + 6] = b.z.y
	buf[o + 8] = b.x.z
	buf[o + 9] = b.y.z
	buf[o + 10] = b.z.z


func _process(_delta: float) -> void:
	if _slot_mode and _dirty:
		_dirty = false
		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buf)
		multimesh.visible_instance_count = _used
