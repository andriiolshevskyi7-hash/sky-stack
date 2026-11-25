// Sun shadows of buildings / rock towers on the ground (CityGen._shadow):
// a hull whose far vertices are pushed along the sun by height (UV.x) times
// the current shadow length, so shadows lengthen towards dusk. Multiplied
// onto the ground with a cool tint, fading out at night. quality: 1 = hard
// shadow, 2 = plus a soft dithered penumbra towards the far end.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float strength = 0.42;
uniform float soft = 0.0;

varying float far_k;

void vertex() {
	VERTEX.xz += sun_shift * UV.x;
	far_k = UV.x > 0.0 ? 1.0 : 0.0;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vp.xyz *= 1.0 - 6.0 * 0.00018; // above the ground layers (see ground.gdshader)
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float k = strength * (1.0 - night * 0.85);
	if (soft > 0.0) {
		// penumbra: thins out with ordered dithering towards the far end
		float fade = smoothstep(0.55, 1.0, far_k);
		if (bayer4(FRAGCOORD.xy) < fade * 0.6) k *= 0.55;
	}
	ALBEDO = mix(vec3(1.0), vec3(0.42, 0.5, 0.78), k);
}
