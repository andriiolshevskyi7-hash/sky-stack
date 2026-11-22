// "Collapsed" sprite stacks for tall buildings: instead of hundreds of
// identical slices, the walls are quads whose texture rows ARE the slices
// (facade tiles repeat per floor), plus a roof quad. UV2 = tile origin in the
// facade atlas, UV = position in tile units, COLOR.rgb = face shade,
// COLOR.a = per-building random seed (window light pattern).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D facade_tex : source_color, filter_nearest;
uniform sampler2D facade_emit : filter_nearest;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade_hides(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) discard;
	bool roof = UV2.y > 0.37;
	vec2 tile = roof ? vec2(32.0 / 256.0, 32.0 / 128.0) : vec2(32.0 / 256.0, 24.0 / 128.0);
	vec2 uv = UV2 + fract(UV) * tile;
	vec3 col = texture(facade_tex, uv).rgb * COLOR.rgb * ambient * shadow_at(wpos);
	if (!roof && night > 0.02) {
		float win = texture(facade_emit, uv).r;
		if (win > 0.5) {
			vec2 cell = floor(UV * 4.0);
			float h = hash12(cell + vec2(COLOR.a * 311.0, COLOR.a * 97.0));
			float lit = step(h, night * 0.62);
			vec3 wc = mix(vec3(1.0, 0.84, 0.5), vec3(0.7, 0.9, 1.0), step(0.78, fract(h * 17.3)));
			col = mix(col, wc, lit);
		}
	}
	ALBEDO = col;
}
