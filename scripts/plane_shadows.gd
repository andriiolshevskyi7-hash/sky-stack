class_name PlaneShadows
extends MultiMeshInstance3D
## Sun shadows of the other planes on the ground (the player's own plane
## uses the detailed silhouette in the ground shaders): one flat quad per
## plane, shifted along the sun by its altitude, fading higher up.

var fleet: Node
var player: Node3D
var enabled := true
const CAP := 24


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/blob_shadow.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e6, -50, -1e6), Vector3(2e6, 200, 2e6))


func _process(_d: float) -> void:
	var n := 0
	if enabled and fleet != null:
		var shift := _sun_shift()
		for pl in fleet.planes:
			if n >= CAP:
				break
			if not pl.alive or pl == player:
				continue
			var alt: float = pl.position.y
			if alt > 1400.0:
				continue
			var p := Vector3(pl.position.x + shift.x * alt, 1.2, pl.position.z + shift.y * alt)
			var b := Basis(Vector3.UP, pl.yaw).scaled(Vector3(30.0, 1.0, 30.0))
			multimesh.set_instance_transform(n, Transform3D(b, p))
			multimesh.set_instance_color(n, Color(1, 1, 1, clampf(0.5 * (1.0 - alt / 1400.0), 0.0, 0.5)))
			n += 1
	multimesh.visible_instance_count = n


var daynight: Node


func _sun_shift() -> Vector2:
	return daynight.sun_shift() if daynight != null else Vector2(0.55, 0.8).normalized()
