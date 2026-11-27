class_name DayNight
extends Node3D
## Day/night cycle: drives the global lighting uniforms (ambient tint, night
## factor for windows/street lights/neon, shadow length, cloud drift), the
## physical sky (sun / moon, haze) and the world's haze colours (computed with
## the same atmosphere model as the sky, Atmo), and the sweeping searchlights
## at night.

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

## Camera altitude (the sky and haze change with height).
var cam_alt := 200.0
## Weather: Mie haze amount and overcast grey (G7 sets these).
var haze := 1.0
var overcast := 0.0
## Far sea / land seen below the horizon (per map).
var ground_albedo := Vector3(0.05, 0.16, 0.3)
const EXPOSURE := 3.0
var sun_col := Color.WHITE
var _atmo_t := 0.0
var _sun_ground := Vector3.ONE
## Sky seen in reflections (water): a small table of the physical sky's
## colour by elevation (rows) and azimuth from the sun (columns, the sky is
## mirror-symmetric about the sun's vertical plane), refreshed a few texels
## per frame so it follows the time of day and weather.
const LUT_W := 16
const LUT_H := 8
var sky_lut: ImageTexture
var _lut_img: Image
var _lut_raw := PackedColorArray()
var _lut_i := 0
var _lut_t := -1.0
var _lut_oc := 0.0
var _fog := [Color(0.62, 0.8, 0.95), Color(0.35, 0.5, 0.7), Color(0.9, 0.85, 0.8)]

var beams: Array[MeshInstance3D] = []
var _bt := 0.0
var beam_count := 3 # Night City sweeps 4 searchlights


func _ready() -> void:
	_lut_img = Image.create(LUT_W, LUT_H, false, Image.FORMAT_RGB8)
	_lut_img.fill(Color(0.55, 0.72, 0.92))
	_lut_raw.resize(LUT_W * LUT_H)
	_lut_raw.fill(Color(0.55, 0.72, 0.92))
	sky_lut = ImageTexture.create_from_image(_lut_img)
	RenderingServer.global_shader_parameter_set("sky_lut", sky_lut)
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


## Current ambient light colour (cockpit lighting reads it).
var amb_color := Color.WHITE


## World direction towards the sun.
func sun_dir() -> Vector3:
	return Vector3(-0.55, maxf(sun_elevation(), -0.25) * 0.95 + 0.01, -0.8).normalized()


func sun_elevation() -> float:
	return sin((t - 0.25) * TAU)


## Haze colours from the atmosphere model: [horizon (away from the sun),
## looking down, towards the sun], plus the sunlight colour.
func _update_atmo() -> void:
	var sd := sun_dir()
	var sa := clampf(1.0 - night * 1.5, 0.0, 1.0)
	var flat := Vector2(sd.x, sd.z).normalized()
	var away := Vector3(-flat.x, 0.0, -flat.y)
	var side := Vector3(-flat.y, 0.0, flat.x)
	var el := 0.04
	var hz := Color(0, 0, 0)
	for dv: Vector3 in [away, side, -side]:
		hz += Atmo.sky((dv + Vector3(0, el, 0)).normalized(), cam_alt, sd, sa, haze, EXPOSURE, ground_albedo)
	hz /= 3.0
	# the far surface at the world's edge angle (fog distance ~7 km)
	var edge := maxf(cam_alt, 1.0) / Vector2(7000.0, maxf(cam_alt, 1.0)).length()
	var dn := (away * sqrt(1.0 - edge * edge) - Vector3(0, maxf(edge, 0.06), 0)).normalized()
	var low := Atmo.sky(dn, cam_alt, sd, sa, haze, EXPOSURE, ground_albedo)
	var tow := Atmo.sky((Vector3(flat.x, el, flat.y)).normalized(), cam_alt, sd, sa, haze, EXPOSURE, ground_albedo)
	_fog = [hz, low, tow]
	_sun_ground = Atmo.sun_transmittance(sd, 10.0, haze)
	var tr := Atmo.sun_transmittance(sd, cam_alt, haze)
	var m := maxf(0.001, maxf(tr.x, maxf(tr.y, tr.z)))
	sun_col = Color(tr.x / m, tr.y / m, tr.z / m)


func _process(delta: float) -> void:
	if cycle and not paused:
		t = fposmod(t + delta / CYCLE, 1.0)
	var e := sun_elevation()
	night = 1.0 - smoothstep(-0.15, 0.1, e)
	var dusk := clampf(1.0 - absf(e) / 0.35, 0.0, 1.0) * (1.0 - night)
	_atmo_t -= delta
	if _atmo_t <= 0.0:
		_atmo_t = 0.1
		_update_atmo()
	# daylight follows the real colour of the sun (warm and low at dusk)
	var day := DAY.lerp(DAY * 0.55 + sun_col * 0.45, 0.6 + 0.4 * dusk)
	day.a = 1.0
	var amb := day.lerp(DUSK, dusk * 0.35).lerp(NIGHT, night)
	amb_color = amb
	RenderingServer.global_shader_parameter_set("night", night)
	RenderingServer.global_shader_parameter_set("ambient", Vector3(amb.r, amb.g, amb.b))
	# lower sun -> longer shadows (direction fixed, top-left light)
	var length := clampf(0.55 + (1.0 - clampf(e, 0.0, 1.0)) * 0.9, 0.55, 1.45)
	RenderingServer.global_shader_parameter_set("sun_shift", Vector2(0.55, 0.8).normalized() * length)
	cloud_offset += WIND * delta
	RenderingServer.global_shader_parameter_set("cloud_offset", cloud_offset)
	RenderingServer.global_shader_parameter_set("cloud_shadow", 0.32 * (1.0 - night))
	var sd := sun_dir()
	if sky_mat != null:
		sky_mat.set_shader_parameter("night", night)
		sky_mat.set_shader_parameter("sun_amount", clampf(1.0 - night * 1.5, 0.0, 1.0))
		sky_mat.set_shader_parameter("sun_dir", sd)
		sky_mat.set_shader_parameter("haze", haze)
		sky_mat.set_shader_parameter("overcast", overcast)
		sky_mat.set_shader_parameter("exposure", EXPOSURE)
		sky_mat.set_shader_parameter("ground_albedo", ground_albedo)
		sky_mat.set_shader_parameter("sun_ground", _sun_ground)
	# haze colours: the atmosphere's, deepened into the night palette
	var nt := HORIZON_NIGHT
	var hz: Color = (_fog[0] as Color).lerp(nt, night)
	var low: Color = (_fog[1] as Color).lerp(nt.darkened(0.3), night)
	var tow: Color = (_fog[2] as Color).lerp(nt, night)
	var grey := Color(0.62, 0.65, 0.7) * (1.0 - night * 0.8)
	hz = hz.lerp(grey, overcast)
	low = low.lerp(grey.darkened(0.15), overcast)
	tow = tow.lerp(grey, overcast)
	RenderingServer.global_shader_parameter_set("fog_color", Vector3(hz.r, hz.g, hz.b))
	RenderingServer.global_shader_parameter_set("fog_low", Vector3(low.r, low.g, low.b))
	RenderingServer.global_shader_parameter_set("fog_sun", Vector3(tow.r, tow.g, tow.b))
	RenderingServer.global_shader_parameter_set("sun_dir", sd)
	RenderingServer.global_shader_parameter_set("sun_col", Vector3(sun_col.r, sun_col.g, sun_col.b) * (1.0 - night))
	RenderingServer.global_shader_parameter_set("haze_k", haze * (1.0 + overcast * 0.6))
	if env != null:
		env.background_color = SKY_DAY.lerp(SKY_NIGHT, night)
	# a jump in time / weather (map start, debug): redo the whole table now
	if absf(t - _lut_t) > 0.02 or absf(overcast - _lut_oc) > 0.1:
		_lut_i = 0
		_update_lut(sd, LUT_W * LUT_H)
	else:
		_update_lut(sd, 8)
	_update_beams(delta)


## Recompute `n` texels of the reflection sky table (the whole table every
## LUT_W * LUT_H / n frames) and upload it once a full pass is done.
func _update_lut(sd: Vector3, n: int) -> void:
	var sa := clampf(1.0 - night * 1.5, 0.0, 1.0)
	var sf := Vector2(sd.x, sd.z).normalized()
	var grey := Color(0.62, 0.65, 0.7) * (1.0 - night * 0.8)
	for k in n:
		var i := _lut_i
		_lut_i = (_lut_i + 1) % (LUT_W * LUT_H)
		var x := i % LUT_W
		var y := i / LUT_W
		var az := float(x) / (LUT_W - 1) * PI
		var v := float(y) / (LUT_H - 1)
		var el := v * v # rows packed towards the horizon
		var f := sf.rotated(az)
		var h := sqrt(maxf(1.0 - el * el, 0.0))
		var dir := Vector3(f.x * h, el, f.y * h)
		var c := Atmo.sky(dir, cam_alt, sd, sa, haze, EXPOSURE, ground_albedo)
		# night: the sky shader's deep-blue floor, lighter towards the horizon
		var nf := HORIZON_NIGHT.darkened(0.35).lerp(TOP_NIGHT.lightened(0.1), clampf(el * 1.6, 0.0, 1.0))
		c = Color(maxf(c.r, nf.r * night), maxf(c.g, nf.g * night), maxf(c.b, nf.b * night))
		c = c.lerp(grey, overcast)
		_lut_raw[i] = c
		if _lut_i == 0:
			_lut_t = t
			_lut_oc = overcast
			for j in LUT_W * LUT_H:
				_lut_img.set_pixel(j % LUT_W, j / LUT_W, _lut_raw[j])
			sky_lut.update(_lut_img)


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
