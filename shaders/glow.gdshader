// Additive light pools (street lamps, headlights) - only visible at night.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

#include "res://shaders/common.gdshaderinc"

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = 1.0 - dot(d, d);
	if (r <= 0.0) discard;
	float a = floor(r * r * 4.0) / 4.0 * night * COLOR.a;
	ALBEDO = COLOR.rgb * a;
}
