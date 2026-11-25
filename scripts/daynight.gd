class_name DayNight
extends Node3D
## Day/night cycle: drives the global lighting uniforms (ambient tint, night
## factor for windows/street lights/neon, shadow length, cloud drift) and the
## sweeping searchlights at night.

const CYCLE := 360.0 # seconds per full day
const DAY := Color(1.0, 1.0, 1.0)
const DUSK := Color(1.0, 0.72, 0.58)
const NIGHT := Color(0.2, 0.23, 0.42)
const SKY_DAY := Color("6a9fd8")
const SKY_NIGHT := Color("1a1c2c")

var t := 0.42
## Day/night cycle is optional (pause menu); the game starts in full day.
var cycle := false
var night := 0.0
var paused := false
var focus := Vector3.ZERO
var env: Environment
var sky_mat: ShaderMaterial
const TOP_SUNSET := Color("6b4a8a")
const HORIZON_SUNSET := Color("ffb37a")
const HORIZON_DAY := Color("9fcdf2")
const HORIZON_NIGHT := Color("2a2f4e")
const TOP_DAY := Color("2f74d6")
const TOP_NIGHT := Color("0a0a14")
var cloud_offset := Vector2.ZERO
const WIND := Vector2(18.0, 8.0)

var beams: Array[MeshInstance3D] = []
var _bt := 0.0
var beam_count := 5 # Night City sweeps 9 searchlights


func _ready() -> void:
	var m := _beam_mesh()
	for i in 9:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = Stacks.beam_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		beams.append(mi)


func _beam_mesh() -> ArrayMesh:
	# two crossed tapered quads, origin at the bottom, pointing +Y
	var mb := MeshBuf.new()
	var h := 600.0
	for k in 2:
		var ax := Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)
		var w0 := 3.0
		var w1 := 52.0
		mb.quad(ax * -w1 + Vector3(0, h, 0), ax * w1 + Vector3(0, h, 0), ax * w0, ax * -w0,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE)
	return mb.commit()


func sun_elevation() -> float:
	return sin((t - 0.25) * TAU)


func _process(delta: float) -> void:
	if cycle and not paused:
		t = fposmod(t + delta / CYCLE, 1.0)
	var e := sun_elevation()
	night = 1.0 - smoothstep(-0.15, 0.1, e)
	var dusk := clampf(1.0 - absf(e) / 0.35, 0.0, 1.0) * (1.0 - night)
	var amb := DAY.lerp(DUSK, dusk).lerp(NIGHT, night)
	RenderingServer.global_shader_parameter_set("night", night)
	RenderingServer.global_shader_parameter_set("ambient", Vector3(amb.r, amb.g, amb.b))
	# lower sun -> longer shadows (direction fixed, top-left light)
	var length := clampf(0.55 + (1.0 - clampf(e, 0.0, 1.0)) * 0.9, 0.55, 1.45)
	RenderingServer.global_shader_parameter_set("sun_shift", Vector2(0.55, 0.8).normalized() * length)
	cloud_offset += WIND * delta
	RenderingServer.global_shader_parameter_set("cloud_offset", cloud_offset)
	RenderingServer.global_shader_parameter_set("cloud_shadow", 0.32 * (1.0 - night))
	var hz := HORIZON_DAY.lerp(HORIZON_SUNSET, dusk).lerp(HORIZON_NIGHT, night)
	var top := TOP_DAY.lerp(TOP_SUNSET, dusk).lerp(TOP_NIGHT, night)
	if sky_mat != null:
		sky_mat.set_shader_parameter("horizon_color", Vector3(hz.r, hz.g, hz.b))
		sky_mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
		var gc := Color("1f5fbf").lerp(Color("0d1430"), night)
		sky_mat.set_shader_parameter("ground_color", Vector3(gc.r, gc.g, gc.b))
		sky_mat.set_shader_parameter("night", night)
		sky_mat.set_shader_parameter("sun_amount", clampf(1.0 - night * 1.5, 0.0, 1.0))
		sky_mat.set_shader_parameter("sun_dir", Vector3(-0.55, maxf(e, -0.2) * 0.9 + 0.05, -0.8))
	RenderingServer.global_shader_parameter_set("fog_color", Vector3(hz.r, hz.g, hz.b))
	if env != null:
		env.background_color = SKY_DAY.lerp(SKY_NIGHT, night)
	_update_beams(delta)


func sun_shift() -> Vector2:
	var e := sun_elevation()
	var length := clampf(0.55 + (1.0 - clampf(e, 0.0, 1.0)) * 0.9, 0.55, 1.45)
	return Vector2(0.55, 0.8).normalized() * length


func _update_beams(delta: float) -> void:
	_bt += delta
	var on := night > 0.05
	var grid := 640.0
	var gx := roundf(focus.x / grid) * grid
	var gz := roundf(focus.z / grid) * grid
	var offs := [Vector2(0, 0), Vector2(grid, 0), Vector2(-grid, 0), Vector2(0, grid), Vector2(0, -grid),
		Vector2(grid, grid) * 0.5, Vector2(-grid, grid) * 0.5, Vector2(grid, -grid) * 0.5, Vector2(-grid, -grid) * 0.5]
	for i in beams.size():
		var b := beams[i]
		b.visible = on and i < beam_count
		if not b.visible:
			continue
		var o: Vector2 = offs[i]
		var bx := gx + o.x + CityGen.hashf(int(gx + o.x), int(gz + o.y), 5) * 200.0 - 100.0
		var bz := gz + o.y + CityGen.hashf(int(gx + o.x), int(gz + o.y), 6) * 200.0 - 100.0
		var sweep := _bt * (0.5 + 0.13 * i) + i * 1.7
		var tilt := 0.35 + 0.2 * sin(_bt * 0.7 + i)
		b.global_transform = Transform3D(Basis.from_euler(Vector3(tilt, sweep, 0.0)), Vector3(bx, 0.5, bz))
