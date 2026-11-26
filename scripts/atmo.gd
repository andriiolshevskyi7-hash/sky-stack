class_name Atmo
## CPU twin of the physical sky in shaders/sky.gdshader (same planet,
## scattering coefficients, phase functions and exposure), used for the
## world's haze colours and the sunlight tint, so fog meets the sky without a
## seam. A few evaluations per update (fewer samples than the shader).

const RE := 600000.0
const RA := RE + 60000.0
const HR := 7994.0
const HM := 1200.0
const BR := Vector3(5.8e-6, 13.5e-6, 33.1e-6)
const BO := Vector3(0.65e-6 * 4.5, 1.88e-6 * 4.5, 0.085e-6 * 4.5)
const BM := 4.5e-6
const G := 0.82


static func _sphere(ro: Vector3, rd: Vector3, r: float) -> Vector2:
	var b := ro.dot(rd)
	var c := ro.dot(ro) - r * r
	var d := b * b - c
	if d < 0.0:
		return Vector2(1e9, -1e9)
	d = sqrt(d)
	return Vector2(-b - d, -b + d)


static func _exp3(v: Vector3) -> Vector3:
	return Vector3(exp(v.x), exp(v.y), exp(v.z))


## Transmittance of sunlight reaching altitude `alt` (the colour of the sun).
static func sun_transmittance(sd: Vector3, alt: float, haze: float = 1.0) -> Vector3:
	var p := Vector3(0.0, RE + maxf(alt, 2.0), 0.0)
	var tg := _sphere(p, sd, RE)
	if tg.x > 0.0 and tg.x < 1e8:
		return Vector3.ZERO
	var tl := _sphere(p, sd, RA)
	var dl := tl.y / 8.0
	var lr := 0.0
	var lm := 0.0
	for j in 8:
		var q := p + sd * (dl * (j + 0.5))
		var hq := maxf(q.length() - RE, 0.0)
		lr += exp(-hq / HR) * dl
		lm += exp(-hq / HM) * dl
	return _exp3(-((BR + BO) * lr + Vector3.ONE * BM * haze * 1.1 * lm))


## Sky colour (tone-mapped, like the shader) looking along `rd` from `alt`.
static func sky(rd: Vector3, alt: float, sd: Vector3, sun_amount: float, haze: float, exposure: float, ground_albedo: Vector3) -> Color:
	var ro := Vector3(0.0, RE + maxf(alt, 2.0), 0.0)
	var ta := _sphere(ro, rd, RA)
	var te := _sphere(ro, rd, RE)
	var t1 := ta.y
	var ground := te.x > 0.0 and te.x < 1e8
	if ground:
		t1 = te.x
	var n := 10
	var ds := t1 / n
	var mu := rd.dot(sd)
	var pr := 3.0 / (16.0 * PI) * (1.0 + mu * mu)
	var pm := 3.0 / (8.0 * PI) * ((1.0 - G * G) * (1.0 + mu * mu)) / ((2.0 + G * G) * pow(maxf(1.0 + G * G - 2.0 * G * mu, 1e-4), 1.5))
	var sr := Vector3.ZERO
	var sm := Vector3.ZERO
	var odr := 0.0
	var odm := 0.0
	for i in n:
		var p := ro + rd * (ds * (i + 0.5))
		var h := p.length() - RE
		var hr := exp(-h / HR) * ds
		var hm := exp(-h / HM) * ds
		odr += hr
		odm += hm
		var tg := _sphere(p, sd, RE)
		if tg.x > 0.0 and tg.x < 1e8:
			continue
		var tl := _sphere(p, sd, RA)
		var dl := tl.y / 3.0
		var lr := 0.0
		var lm := 0.0
		for j in 3:
			var q := p + sd * (dl * (j + 0.5))
			var hq := maxf(q.length() - RE, 0.0)
			lr += exp(-hq / HR) * dl
			lm += exp(-hq / HM) * dl
		var att := _exp3(-((BR + BO) * (odr + lr) + Vector3.ONE * BM * haze * 1.1 * (odm + lm)))
		sr += att * hr
		sm += att * hm
	var c := (sr * BR * pr + sm * BM * haze * pm) * 20.0 * sun_amount
	if ground:
		var trans := _exp3(-((BR + BO) * odr + Vector3.ONE * BM * haze * 1.1 * odm))
		var gp := ro + rd * te.x
		var gn := gp.normalized()
		var tsun := sun_transmittance(sd, 10.0, haze)
		var lit := maxf(gn.dot(sd), 0.0) * 0.8 + 0.2
		c += ground_albedo * trans * tsun * lit * 1.6 * sun_amount
	# same tone map as the shader (mostly hue-preserving)
	var tc := Vector3(1.0 - exp(-c.x * exposure), 1.0 - exp(-c.y * exposure), 1.0 - exp(-c.z * exposure))
	var lum := c.dot(Vector3(0.2126, 0.7152, 0.0722))
	var k := (1.0 - exp(-lum * exposure)) / maxf(lum, 1e-6)
	var hc := Vector3(minf(c.x * k, 1.0), minf(c.y * k, 1.0), minf(c.z * k, 1.0))
	var o := tc.lerp(hc, 0.85)
	return Color(o.x, o.y, o.z)
