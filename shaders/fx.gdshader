// Pixel particles / bullets: camera-facing squares from a MultiMesh.
// INSTANCE_CUSTOM.x = size in world units (1 unit = 1 low-res pixel).
// COLOR.a < 1 is rendered with ordered dithering (no sorting needed).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= INSTANCE_CUSTOM.x;
}

void fragment() {
	if (bayer4(FRAGCOORD.xy) > COLOR.a) discard;
	ALBEDO = COLOR.rgb;
}
