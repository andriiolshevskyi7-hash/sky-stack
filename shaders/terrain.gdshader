// Infinite terrain plane: ocean (deep -> shallow turquoise), animated foam,
// sandy beaches, grass and darker forest patches, all derived per pixel from
// the shared island heightmap. Flat bright colours, no noise or dithering.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

const vec3 DEEPEST = vec3(0.07, 0.30, 0.66);
const vec3 DEEP = vec3(0.12, 0.45, 0.85);
const vec3 SHALLOW = vec3(0.25, 0.78, 0.92);
const vec3 FOAM = vec3(0.96, 0.99, 1.0);
const vec3 SAND = vec3(0.96, 0.87, 0.62);
const vec3 SAND_WET = vec3(0.86, 0.76, 0.52);
const vec3 GRASS = vec3(0.39, 0.76, 0.31);
const vec3 GRASS_LIGHT = vec3(0.55, 0.84, 0.36);
const vec3 FOREST = vec3(0.22, 0.56, 0.24);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = floor(wpos.xz) + 0.5; // one terrain sample per world unit = crisp pixels
	float h = island_h(p);
	vec3 col;
	if (h < 0.5) {
		float depth = 0.5 - h;
		col = mix(SHALLOW, DEEP, smoothstep(0.0, 0.07, depth));
		col = mix(col, DEEPEST, smoothstep(0.12, 0.35, depth));
		// animated surf band along the shore
		float wave = 0.010 + 0.005 * sin(TIME * 1.6 + (p.x + p.y) * 0.035);
		if (depth < wave) col = FOAM;
		else if (depth < wave + 0.006 && fract((p.x * 0.7 + p.y * 0.3) * 0.05 + TIME * 0.2) < 0.5) col = mix(col, FOAM, 0.6);
		// sparse moving wave glints on open water
		// small horizontal wave glints (3x1 px) drifting slowly
		vec2 q = p + vec2(TIME * 3.0, TIME * 1.0);
		vec2 cell = floor(q / vec2(9.0, 5.0));
		vec2 local = q - cell * vec2(9.0, 5.0);
		if (depth > 0.03 && hash12(cell) > 0.93 && local.y < 1.0 && local.x < 3.0) col = mix(col, FOAM, 0.55);
	} else if (h < 0.525) {
		col = h < 0.506 ? SAND_WET : SAND;
	} else {
		float f = texture(cloud_tex, fract(p / 2200.0 + vec2(0.37, 0.61))).r;
		col = f > 0.55 ? FOREST : (h < 0.535 ? GRASS_LIGHT : GRASS);
	}
	ALBEDO = fogged(lit(col, wpos), wpos);
}
