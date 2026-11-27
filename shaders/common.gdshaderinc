// Shared world-shader helpers: global lighting uniforms, jet/cloud shadows,
// ordered dithering and the "building hides the jet" dither fade.

global uniform float night;
global uniform float gfx_quality;   // 0 low, 1 medium, 2 high
global uniform vec3 ambient;
global uniform vec2 sun_shift;      // horizontal shadow offset per unit of height
global uniform vec3 jet_pos;
global uniform float jet_yaw;
global uniform float jet_shadow_size;
global uniform sampler2D jet_shadow_tex;
global uniform sampler2D cloud_tex;
global uniform sampler2D cloud_cov_tex : filter_linear, repeat_enable;
global uniform vec2 cloud_offset;
global uniform float cloud_shadow;
global uniform float cloud_cover;
global uniform float cloud_base;
global uniform float sprite_snap;
global uniform float fade_radius;
global uniform sampler2D island_tex;
global uniform vec3 cam_pos;
global uniform float fog_far;
global uniform vec3 fog_color;
global uniform vec3 fog_low;
global uniform vec3 fog_sun;
global uniform vec3 sun_dir;
global uniform vec3 sun_col;
global uniform float haze_k;
global uniform sampler2D sky_lut : filter_linear, repeat_disable;
global uniform sampler2D water_nrm : filter_linear_mipmap, repeat_enable;
global uniform float cloud_thick;

const vec3 SHADOW_TINT = vec3(0.42, 0.55, 0.88);


float bayer2(vec2 a) {
	a = floor(a);
	return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Shadow amount (0 = lit, 1 = full shadow) for a world-space point: jet
// silhouette projected along the sun direction + drifting cloud shadows.
float shadow_amount(vec3 w) {
	float s = 0.0;
	float dh = jet_pos.y - w.y;
	if (dh > 0.0) {
		vec2 p = w.xz - (jet_pos.xz + sun_shift * dh);
		float c = cos(jet_yaw);
		float sn = sin(jet_yaw);
		vec2 l = vec2(c * p.x - sn * p.y, sn * p.x + c * p.y);
		vec2 uv = l / jet_shadow_size + 0.5;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			s = 0.8 * texture(jet_shadow_tex, uv).a;
		}
	}
	// cloud shadows: the same coverage field as the clouds, projected from
	// the middle of the cloud layer along the sun, soft-edged
	float csh = cloud_base + 180.0;
	if (w.y < csh - 10.0) {
		vec2 cp = (w.xz - sun_shift * (csh - w.y) + cloud_offset) / 4200.0;
		float n = texture(cloud_cov_tex, cp).r;
		s = max(s, cloud_shadow * smoothstep(cloud_cover + 0.04, cloud_cover + 0.16, n));
	}
	return s;
}

float shadow_at(vec3 w) {
	return 1.0 - shadow_amount(w) * 0.5;
}

// Lighting: ambient tint + blue-tinted shadows.
vec3 lit(vec3 col, vec3 w) {
	return mix(col, col * SHADOW_TINT, shadow_amount(w)) * ambient;
}

// Aerial perspective: exponential height haze (dense near the ground, thin
// up high, so the far islands turn blue and the view from altitude is
// clearer), coloured like the sky in that direction (horizon, looking down,
// towards the sun). The world's edge always fades out.
vec3 fogged(vec3 col, vec3 w) {
	if (fog_far <= 0.0) return col;
	vec3 dv = w - cam_pos;
	float d = length(dv);
	vec3 v = dv / max(d, 0.001);
	const float H = 1400.0;
	float b0 = 2.6 / fog_far * haze_k;
	float hc = max(cam_pos.y, 0.0);
	float hp = max(w.y, 0.0);
	float dh = hp - hc;
	float od = abs(dh) < 1.0 ? b0 * exp(-hc / H) * d : b0 * H * d / dh * (exp(-hc / H) - exp(-hp / H));
	float a = 1.0 - exp(-od);
	a = max(a, smoothstep(fog_far * 0.8, fog_far, d));
	// looking down, the haze turns into the colour of the far surface seen
	// at the world's edge angle (so the edge melts into the sky below the
	// dipped horizon at altitude)
	float edge = max(cam_pos.y, 1.0) / length(vec2(fog_far, max(cam_pos.y, 1.0)));
	vec3 fc = mix(fog_color, fog_low, clamp(-v.y / max(edge, 0.06), 0.0, 1.0));
	vec2 sf = normalize(sun_dir.xz + vec2(1e-5));
	vec2 vf = normalize(v.xz + vec2(1e-5));
	float sunw = pow(max(dot(vf, sf), 0.0), 6.0) * (1.0 - clamp(-v.y * 2.0, 0.0, 1.0));
	fc = mix(fc, fog_sun, sunw * 0.8);
	return mix(col, fc, clamp(a, 0.0, 0.97));
}

// Island height (manual bilinear, matches CityGen.island_h on the CPU).
float island_h(vec2 xz) {
	vec2 u = xz / 24.0 - 0.5;
	vec2 i = floor(u);
	vec2 f = u - i;
	ivec2 a = ivec2(mod(i, 256.0));
	ivec2 b = ivec2(mod(i + 1.0, 256.0));
	float h00 = texelFetch(island_tex, ivec2(a.x, a.y), 0).r;
	float h10 = texelFetch(island_tex, ivec2(b.x, a.y), 0).r;
	float h01 = texelFetch(island_tex, ivec2(a.x, b.y), 0).r;
	float h11 = texelFetch(island_tex, ivec2(b.x, b.y), 0).r;
	return mix(mix(h00, h10, f.x), mix(h01, h11, f.x), f.y);
}

// Emission strength from the emission-alpha class (see Painter.gd).
float emission_strength(float cls, float t, vec3 w) {
	if (cls > 0.83) return night;
	if (cls > 0.5) return 1.0;
	if (cls > 0.16) return step(0.55, fract(t * 0.9 + (w.x + w.z) * 0.013));
	return 0.0;
}

// True when this fragment sits between the camera and the jet, close to the
// jet on screen -> caller discards with an ordered-dither pattern.
bool fade_hides(vec3 view_pos, mat4 view_m, vec2 frag) {
	vec3 jv = (view_m * vec4(jet_pos, 1.0)).xyz;
	if (view_pos.z < jv.z + 3.0) return false;
	float d = length(view_pos.xy - jv.xy);
	if (d > fade_radius) return false;
	float f = 1.0 - smoothstep(fade_radius * 0.55, fade_radius, d);
	return bayer4(frag) < f * 0.8;
}


// ---- Water -------------------------------------------------------------
// The sky seen in a reflection: DayNight's table of the physical sky by
// elevation and azimuth from the sun (mirror-symmetric about the sun).
vec3 sky_refl(vec3 r) {
	vec2 sf = normalize(sun_dir.xz + vec2(1e-5));
	vec2 rf = normalize(r.xz + vec2(1e-5));
	float az = acos(clamp(dot(rf, sf), -1.0, 1.0)) / 3.14159265;
	float v = sqrt(clamp(r.y, 0.0, 1.0));
	vec2 uv = (vec2(az, v) * vec2(15.0, 7.0) + 0.5) / vec2(16.0, 8.0);
	return texture(sky_lut, uv).rgb;
}

// Wave normal at a water point: two long swells plus three octaves of
// drifting ripples (water_nrm: tileable slopes), calmer with distance so the
// far sea doesn't shimmer; `rough` scales the waves (weather, sheltered
// water).
vec3 water_normal(vec2 xz, float dist, float rough) {
	float t = TIME;
	vec2 s = vec2(0.0);
	// swell: long, slow, from the open sea
	vec2 d1 = vec2(0.80, 0.60);
	vec2 d2 = vec2(-0.35, 0.94);
	s += d1 * cos(dot(xz, d1) * 0.045 - t * 0.9) * 0.10;
	s += d2 * cos(dot(xz, d2) * 0.071 - t * 1.15) * 0.07;
	vec2 n1 = texture(water_nrm, xz / 61.0 + t * vec2(0.012, 0.008)).rg * 2.0 - 1.0;
	vec2 n2 = texture(water_nrm, xz / 23.0 + t * vec2(-0.021, 0.017)).rg * 2.0 - 1.0;
	s += n1 * 0.34 + n2 * 0.24;
	if (dist < 900.0) {
		vec2 n3 = texture(water_nrm, xz / 7.3 + t * vec2(0.043, -0.035)).rg * 2.0 - 1.0;
		s += n3 * 0.16 * (1.0 - dist / 900.0);
	}
	s *= rough / (1.0 + dist / 1100.0);
	return normalize(vec3(-s.x, 1.0, -s.y));
}

// Shade open water: body colour (`body`, already lit) under a Fresnel
// reflection of the sky and the clouds above (where the reflected ray meets
// the cloud layer), the sun's path of glints and sheen (dimmed in cloud and
// plane shadows), the moon's path at night.
vec3 water_shade(vec3 body, vec3 w, float rough) {
	vec3 dv = w - cam_pos;
	float d = length(dv);
	vec3 v = -dv / max(d, 0.001);
	vec3 n = water_normal(w.xz, d, rough);
	float ndv = max(dot(n, v), 0.0);
	float F = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 r = reflect(-v, n);
	r.y = abs(r.y) + 0.004;
	vec3 sky = sky_refl(r);
	float day = 1.0 - night;
	// clouds in the reflection: their bases, lit by the sky and the sun
	float hc = cloud_base + cloud_thick * 0.3;
	if (gfx_quality > 0.5 && w.y < hc) {
		float tc = (hc - w.y) / r.y;
		vec2 cp = w.xz + r.xz * tc;
		float cov = texture(cloud_cov_tex, (cp + cloud_offset) / 4200.0).r;
		float ca = smoothstep(cloud_cover, cloud_cover + 0.2, cov) * (1.0 - smoothstep(5000.0, 14000.0, tc));
		vec3 cc = mix(fog_color, vec3(1.0), 0.45) * 0.8 + sun_col * 0.22;
		cc = mix(cc, vec3(0.07, 0.08, 0.13), night * 0.85);
		sky = mix(sky, cc, ca * 0.92);
	}
	vec3 col = mix(body, sky, F);
	// the sun's path: sharp glints from the wave facets + a broad sheen
	float lit_k = 1.0 - shadow_amount(w);
	vec3 sd = normalize(sun_dir);
	float rs = max(dot(r, sd), 0.0);
	col += sun_col * (pow(rs, 1100.0) * 22.0 + pow(rs, 160.0) * 0.9 + pow(rs, 14.0) * 0.07) * day * lit_k;
	// the moon's path at night
	float rm = max(dot(r, normalize(vec3(0.45, 0.45, -0.75))), 0.0);
	col += vec3(0.65, 0.75, 1.0) * (pow(rm, 600.0) * 4.0 + pow(rm, 60.0) * 0.12) * night;
	return col;
}

// Older look (low quality): Fresnel tint and twinkling sun glints.
vec3 water_light(vec3 col, vec3 w, vec2 p) {
	if (gfx_quality < 0.5) return col;
	if (gfx_quality > 0.5) return water_shade(col, w, 1.0);
	vec3 v = normalize(cam_pos - w);
	float fres = pow(1.0 - clamp(v.y, 0.0, 1.0), 4.0);
	col = mix(col, fog_color * 1.05, fres * 0.5 * (1.0 - night * 0.5));
	vec3 sd = normalize(vec3(-sun_shift.x, 1.0, -sun_shift.y));
	vec3 r = vec3(-v.x, v.y, -v.z);
	float spec = pow(max(dot(r, sd), 0.0), 70.0);
	float tw = step(0.7, hash12(floor(p / 3.0) + floor(TIME * 5.0)));
	col += vec3(1.0, 0.94, 0.8) * spec * tw * (1.0 - night) * 2.0;
	// broad soft sheen around the reflection
	col += vec3(1.0, 0.9, 0.75) * pow(max(dot(r, sd), 0.0), 12.0) * 0.12 * (1.0 - night);
	return col;
}
