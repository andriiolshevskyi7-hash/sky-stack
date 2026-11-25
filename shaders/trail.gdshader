// Thin wingtip vapour trails (camera-facing ribbons, alpha via ordered dither).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (bayer4(FRAGCOORD.xy) > COLOR.a) discard;
	ALBEDO = fogged(COLOR.rgb * max(ambient, vec3(0.45)), wpos);
}
