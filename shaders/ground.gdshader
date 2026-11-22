// Ground: roads, sidewalks, parks, water. COLOR.a encodes the tile index of
// the 8x2 ground atlas, UV is world-tiling.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D ground_tex : source_color, filter_nearest;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	int idx = int(COLOR.a * 16.0);
	vec2 u = UV;
	bool water = (idx == 5 || idx == 14);
	if (water) {
		u += vec2(TIME * 0.04, sin(TIME * 0.6 + UV.x * 0.8) * 0.06);
	}
	vec2 f = fract(u);
	vec2 tile = vec2(float(idx % 8), float(idx / 8));
	vec3 col = texture(ground_tex, (tile + f) * vec2(0.125, 0.5)).rgb * COLOR.rgb;
	col = lit(col, wpos);
	if (water && night > 0.1) {
		// city lights reflecting on water
		float h = hash12(floor(wpos.xz * 0.5) + floor(TIME * 3.0));
		col += vec3(1.0, 0.8, 0.5) * step(0.985, h) * night * 0.7;
	}
	ALBEDO = fogged(col, wpos);
}
