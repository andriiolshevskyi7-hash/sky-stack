// Pixel particles / bullets: camera-facing squares from a MultiMesh.
// INSTANCE_CUSTOM.x = size in world units, .y = style: 0 square, 1 smoke
// ball (round, lit from the sun side, soft dithered edge), 2 fire ball (hot
// white-yellow core that blooms). COLOR.a < 1 is rendered with ordered
// dithering (no sorting needed).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

varying float style;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= INSTANCE_CUSTOM.x;
	style = INSTANCE_CUSTOM.y;
}

void fragment() {
	float a = COLOR.a;
	vec3 col = COLOR.rgb;
	if (style > 0.5) {
		vec2 d = UV * 2.0 - 1.0;
		float r2 = dot(d, d);
		if (r2 > 1.0) discard;
		vec3 n = vec3(d.x, -d.y, sqrt(1.0 - r2));
		if (style < 1.5) {
			// smoke: lit from above / the sun side, darker underneath, soft rim
			float l = 0.62 + 0.45 * dot(n, normalize(vec3(-0.35, 0.75, 0.55)));
			col *= mix(vec3(0.75, 0.8, 0.95), vec3(1.08, 1.04, 0.98), clamp(l, 0.0, 1.0)) * l;
			a *= 1.0 - r2 * r2 * 0.8;
		} else {
			// fire: white-yellow core, orange edge
			col = mix(vec3(1.0, 0.97, 0.78), col, smoothstep(0.0, 0.7, r2));
			a *= 1.0 - r2 * 0.4;
		}
	}
	if (bayer4(FRAGCOORD.xy) > a) discard;
	ALBEDO = col;
}
