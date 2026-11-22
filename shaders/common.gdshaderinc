// Shared world-shader helpers: global lighting uniforms, jet/cloud shadows,
// ordered dithering and the "building hides the jet" dither fade.

global uniform float night;
global uniform vec3 ambient;
global uniform vec2 sun_shift;      // horizontal shadow offset per unit of height
global uniform vec3 jet_pos;
global uniform float jet_yaw;
global uniform float jet_shadow_size;
global uniform sampler2D jet_shadow_tex;
global uniform sampler2D cloud_tex;
global uniform vec2 cloud_offset;
global uniform float cloud_shadow;
global uniform float sprite_snap;
global uniform float fade_radius;
global uniform sampler2D island_tex;
global uniform vec3 cam_pos;
global uniform float fog_far;
global uniform vec3 fog_color;

const vec3 SHADOW_TINT = vec3(0.42, 0.55, 0.88);

const float CLOUD_SHADOW_H = 300.0;

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
		vec2 cp = (w.xz - sun_shift * (CLOUD_SHADOW_H - w.y) + cloud_offset) / 1400.0;
		float n = texture(cloud_tex, fract(cp)).r;
		s = max(s, cloud_shadow * step(0.62, n));
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

// Distance fog towards the horizon colour (perspective views).
vec3 fogged(vec3 col, vec3 w) {
	if (fog_far <= 0.0) return col;
	float d = distance(w, cam_pos);
	return mix(col, fog_color, 0.9 * smoothstep(fog_far * 0.3, fog_far, d));
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
