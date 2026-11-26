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
global uniform vec2 cloud_offset;
global uniform float cloud_shadow;
global uniform float cloud_cover;
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

const vec3 SHADOW_TINT = vec3(0.42, 0.55, 0.88);

const float CLOUD_SHADOW_H = 600.0;

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
	if (w.y < CLOUD_SHADOW_H - 10.0) {
		vec2 cp = (w.xz - sun_shift * (CLOUD_SHADOW_H - w.y) + cloud_offset) / 2800.0;
		float n = texture(cloud_tex, fract(cp)).r;
		s = max(s, cloud_shadow * step(cloud_cover, n));
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


// Water: sky reflection growing towards the horizon (Fresnel) and twinkling
// sun glints where the sun reflects towards the camera (medium+ quality).
vec3 water_light(vec3 col, vec3 w, vec2 p) {
	if (gfx_quality < 0.5) return col;
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
