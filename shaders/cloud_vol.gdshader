// Volumetric clouds: one full-screen pass in the world view that ray-marches
// the cumulus layer (cloud_base .. cloud_base + thick). The shape comes from
// the shared coverage field (cloud_tex, drifting with cloud_offset) - the same
// field that casts the cloud shadows - with flat bases, rounded tops that are
// taller where the cover is denser, and billowy edges eroded by a cellular
// noise. Lit by the sun through the cloud (two light samples), the sun's
// colour from the physical atmosphere (white by day, pink-orange at dusk),
// a silver lining against the sun, dark blue-grey bases, aerial haze with
// distance. Writes the depth of the cloud's front, so planes in front stay
// visible while planes inside / behind are hidden; flying in, the march
// starts at the camera -> white-out.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix, fog_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float thick = 650.0;
uniform int steps = 20;
uniform sampler2D detail_tex : filter_linear, repeat_enable;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform float density_k = 1.0;
uniform float dark = 0.0; // weather: darker, heavier clouds
uniform float flash = 0.0; // lightning inside the clouds

varying vec3 ray_cam;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float cov_at(vec2 xz) {
	return texture(cloud_cov_tex, (xz + cloud_offset) / 4200.0).r;
}

// Density 0..1 at p (h = height inside the cloud 0..1, for shading);
// fine = also the small billow octave (near clouds only).
float dens(vec3 p, out float h, bool detail, bool fine) {
	h = 0.0;
	// cumulus domes: the cover value rises towards a cloud's centre, so the
	// top does too (rounded), the base stays flat
	float a = smoothstep(cloud_cover, cloud_cover + 0.2, cov_at(p.xz));
	if (a <= 0.001) return 0.0;
	float top = thick * (0.25 + 0.75 * sqrt(a));
	h = (p.y - cloud_base) / top;
	if (h < 0.0 || h > 1.0) return 0.0;
	float prof = smoothstep(0.0, 0.05, h) * sqrt(max(1.0 - h * h, 0.0));
	// sides lean inwards: higher up, more cover is needed (no vertical walls)
	float d = prof * (0.35 + 0.65 * a) * smoothstep(0.0, 0.25 + 0.6 * h, a);
	float e = 0.5;
	if (detail) {
		// pseudo-3D billows: two noise layers blended by height (no
		// height-dependent shift, which would smear streaks along the view)
		// true 3D billows (tileable 3D Worley + value noise), two octaves
		vec3 q = vec3(p.x + cloud_offset.x * 1.1, p.y, p.z + cloud_offset.y * 1.1);
		e = texture(noise3d, q / 420.0).r;
		if (fine) {
			e = e * 0.72 + texture(noise3d, q / 150.0 + vec3(0.31, 0.17, 0.53)).r * 0.28;
		}
	}
	d -= e * 0.45;
	return clamp(d * 3.0 * density_k, 0.0, 1.0);
}

void fragment() {
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	vec3 rd = normalize((INV_VIEW_MATRIX * vec4(normalize(vp.xyz / vp.w), 0.0)).xyz);
	vec3 ro = INV_VIEW_MATRIX[3].xyz;
	float top = cloud_base + thick;
	// slab intersection
	float t0;
	float t1;
	if (abs(rd.y) < 1e-4) {
		if (ro.y < cloud_base || ro.y > top) discard;
		t0 = 0.0;
		t1 = 9000.0;
	} else {
		float ta = (cloud_base - ro.y) / rd.y;
		float tb = (top - ro.y) / rd.y;
		t0 = max(min(ta, tb), 0.0);
		t1 = max(ta, tb);
	}
	if (t1 <= t0) discard;
	// march at most 5 km into the layer (steps stay <= ~250 m)
	t1 = min(t1, t0 + 5000.0);
	// the ground stops the ray
	if (rd.y < 0.0) t1 = min(t1, max(ro.y, 0.0) / -rd.y);
	if (t0 > 16000.0 || t1 <= t0) discard;
	// distant clouds need fewer steps (phones: the far layer is most of the
	// pixels when flying below it)
	int n = max(6, int(float(steps) * clamp(1.25 - t0 / 6000.0, 0.45, 1.0)));
	float dt = (t1 - t0) / float(n);
	// interleaved gradient noise: finer and less patterned than a Bayer
	// matrix at the cloud edges
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec3 sd = normalize(sun_dir);
	float mu = dot(rd, sd);
	// silver lining: forward scattering towards the sun
	float g = 0.55;
	float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5) * 0.25;
	float day = 1.0 - night;
	vec3 sunc = sun_col * mix(1.15, 0.6, dark);
	vec3 amb_lo = mix(fog_low, fog_color, 0.4) * vec3(0.62, 0.68, 0.82) * mix(1.0, 0.55, dark);
	vec3 amb_hi = fog_color * 1.05;
	vec3 nightc = vec3(0.10, 0.12, 0.2) + vec3(0.6, 0.7, 1.0) * flash;
	float trans = 1.0;
	vec3 acc = vec3(0.0);
	float t_front = -1.0;
	for (int i = 0; i < 64; i++) {
		if (i >= n || trans < 0.02) break;
		float t = t0 + (float(i) + jit) * dt;
		vec3 p = ro + rd * t;
		float h;
		float d = dens(p, h, true, t < 2500.0);
		if (d > 0.002) {
			float h2;
			float l1 = dens(p + sd * 70.0, h2, false, false);
			float l2 = dens(p + sd * 210.0, h2, false, false);
			float light = exp(-(l1 * 2.2 + l2 * 1.3) * (1.0 + dark));
			vec3 amb = mix(amb_lo, amb_hi, h);
			vec3 col = amb + sunc * light * (0.65 + hg * 0.9) * day;
			col = mix(col, nightc * (0.6 + 0.4 * h) + col * 0.25, night);
			float a = 1.0 - exp(-d * dt * 0.012);
			if (t_front < 0.0 && a > 0.0) t_front = t;
			acc += col * a * trans;
			trans *= 1.0 - a;
		}
	}
	float alpha = 1.0 - trans;
	if (alpha < 0.01) discard;
	vec3 c = acc / alpha;
	vec3 pf = ro + rd * max(t_front, 0.5);
	c = fogged(c, pf);
	ALBEDO = c;
	ALPHA = alpha;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pf, 1.0);
	DEPTH = clamp(clip.z / clip.w * 0.5 + 0.5, 0.0, 1.0);
}
