// Soft camera-facing ribbons: wingtip vortices and engine contrails.
// UV.x runs across the ribbon (0..1) for a soft round profile, UV.y is the
// age along it; COLOR.a carries the fade. Contrails (puff > 0) break up into
// lumpy, slowly spreading vapour with a rolling 3D noise. Lit by the sky
// ambient and the sun colour (pink at dusk), hazed with distance.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float puff = 0.0;
uniform float brightness = 1.0;
uniform sampler3D noise3d : filter_linear, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float prof = 1.0 - x * x;
	float a = COLOR.a * prof;
	if (puff > 0.0) {
		float n = texture(noise3d, wpos / 38.0).r * 0.6 + texture(noise3d, wpos / 13.0 + vec3(0.4)).r * 0.4;
		// young trail: dense and even; older: lumpy, torn
		float age = UV.y;
		a *= mix(1.0, smoothstep(0.25, 0.75, n + (1.0 - abs(x)) * 0.25), clamp(age * puff, 0.0, 1.0));
	}
	if (a < 0.01) discard;
	float day = 1.0 - night;
	vec3 col = mix(fog_color, vec3(1.0), 0.55) * max(ambient, vec3(0.4)) + sun_col * 0.25 * day;
	col = mix(col, vec3(0.16, 0.18, 0.26), night * 0.7) * brightness;
	ALBEDO = fogged(col, wpos);
	ALPHA = clamp(a, 0.0, 0.9);
}
