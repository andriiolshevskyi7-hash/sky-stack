// Searchlight beam: additive vertical gradient, sweeping at night.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

#include "res://shaders/common.gdshaderinc"

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = 1.0 - UV.y;
	float a = across * across * (0.25 + 0.75 * along) * night * 0.55;
	a = floor(a * 6.0) / 6.0;
	ALBEDO = vec3(0.85, 0.9, 1.0) * a;
}
