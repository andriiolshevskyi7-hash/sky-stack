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

const float CLOUD_SHADOW_H = 110.0;

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

// Shadow factor (1 = lit) for a world-space point: jet silhouette projected
// along the sun direction + drifting cloud shadows.
float shadow_at(vec3 w) {
	float s = 1.0;
	float dh = jet_pos.y - w.y;
	if (dh > 0.0) {
		vec2 p = w.xz - (jet_pos.xz + sun_shift * dh);
		float c = cos(jet_yaw);
		float sn = sin(jet_yaw);
		vec2 l = vec2(c * p.x - sn * p.y, sn * p.x + c * p.y);
		vec2 uv = l / jet_shadow_size + 0.5;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			s *= 1.0 - 0.5 * texture(jet_shadow_tex, uv).a;
		}
	}
	vec2 cp = (w.xz + sun_shift * (CLOUD_SHADOW_H - w.y) + cloud_offset) / 1400.0;
	float n = texture(cloud_tex, fract(cp)).r;
	s *= 1.0 - cloud_shadow * step(0.62, n);
	return s;
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
