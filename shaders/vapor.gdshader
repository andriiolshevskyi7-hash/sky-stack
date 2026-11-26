// Condensation: the vapour cone around the fuselage near top speed and the
// vapour sheets over the wings in hard pulls. Thin meshes (VaporFX) with a
// rolling 3D noise, brighter at the rim, fading towards the back; coloured
// by the sky / sun, hazed with distance.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float k = 0.0;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform float flow = 3.0;
uniform bool cone = false;

varying vec3 wpos;
varying vec3 lpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
}

void fragment() {
	if (k < 0.005) discard;
	float n = texture(noise3d, lpos * 0.11 + vec3(0.0, 0.0, TIME * flow)).r;
	float n2 = texture(noise3d, lpos * 0.27 + vec3(0.3, TIME * flow * 1.7, 0.1)).r;
	float shape = smoothstep(0.18, 0.62, n * 0.65 + n2 * 0.35);
	// UV.y: 0 at the front edge, 1 at the back
	// wing sheets fade towards the trailing edge; the cone (a bell behind
	// the shock) is densest towards its back rim, then ends abruptly
	float fade = cone ? smoothstep(0.0, 0.6, UV.y) * smoothstep(1.0, 0.82, UV.y)
		: smoothstep(0.0, 0.18, UV.y) * pow(1.0 - UV.y, 1.3);
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = k * shape * fade * (0.55 + 0.75 * rim) * 1.7;
	if (a < 0.01) discard;
	// condensation is bright: white in sunlight, tinted by the sky
	float day = 1.0 - night;
	vec3 col = mix(fog_color, vec3(1.0), 0.75) * max(ambient, vec3(0.45)) * 0.8 + sun_col * 0.35 * day;
	ALBEDO = fogged(col, wpos);
	ALPHA = clamp(a, 0.0, 0.85);
}
