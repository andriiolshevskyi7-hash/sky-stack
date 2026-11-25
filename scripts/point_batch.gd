class_name PointBatch
extends MultiMeshInstance3D
## One-draw-call renderer for camera-facing pixel squares (particles, bullets).

const STRIDE := 20
var capacity := 0
var count := 0
var buf := PackedFloat32Array()


func setup(p_capacity: int) -> PointBatch:
	capacity = p_capacity
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = Stacks.fx_mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e6, -500, -1e6), Vector3(2e6, 2000, 2e6))
	buf.resize(capacity * STRIDE)
	buf.fill(0.0)
	# identity basis once; only origin/colour/size change per frame
	for i in capacity:
		var o := i * STRIDE
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
	return self


func begin() -> void:
	count = 0


func push(p: Vector3, size: float, c: Color, style: float = 0.0) -> void:
	if count >= capacity:
		return
	var o := count * STRIDE
	buf[o + 3] = p.x
	buf[o + 7] = p.y
	buf[o + 11] = p.z
	buf[o + 12] = c.r
	buf[o + 13] = c.g
	buf[o + 14] = c.b
	buf[o + 15] = c.a
	buf[o + 16] = size
	buf[o + 17] = style
	count += 1


func end() -> void:
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buf)
	multimesh.visible_instance_count = count
