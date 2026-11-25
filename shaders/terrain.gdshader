// Infinite terrain plane: ocean (deep -> shallow turquoise), animated foam,
// sandy beaches, grass and darker forest patches, all derived per pixel from
// the shared island heightmap. Flat bright colours, no noise or dithering.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

// per-map palette (set by WorldMap)
uniform vec3 DEEPEST = vec3(0.07, 0.30, 0.66);
uniform vec3 DEEP = vec3(0.12, 0.45, 0.85);
uniform vec3 SHALLOW = vec3(0.25, 0.78, 0.92);
const vec3 FOAM = vec3(0.96, 0.99, 1.0);
uniform vec3 SAND = vec3(0.96, 0.87, 0.62);
uniform vec3 SAND_WET = vec3(0.86, 0.76, 0.52);
uniform vec3 GRASS = vec3(0.39, 0.76, 0.31);
uniform vec3 GRASS_LIGHT = vec3(0.55, 0.84, 0.36);
uniform vec3 FOREST = vec3(0.22, 0.56, 0.24);
uniform bool frozen = false; // water is ice (snow map)
uniform float bound_half = 0.0; // battle area half size (world), 0 = none

varying vec3 wpos;

// The terrain plane is the bottom layer under every chunk's ground mesh: it
// sits 0.5 below y = 0 (main.gd) and is pushed slightly away from the camera
// so roads, lots and pads drawn above it never z-fight with it.
const float TERRAIN_PUSH = 0.0004; // fraction of view distance

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vp.xyz *= 1.0 + TERRAIN_PUSH;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	vec2 p = floor(wpos.xz) + 0.5; // one terrain sample per world unit = crisp pixels
	float h = island_h(p * 0.5); // map is in virtual units (world scale 2)
	vec3 col;
	if (h < 0.5 && frozen) {
		// frozen lake: pale ice, snow drifts and dark cracks
		float depth = 0.5 - h;
		col = mix(SHALLOW, DEEP, smoothstep(0.0, 0.12, depth));
		float n = hash12(floor(p / 6.0));
		if (n > 0.85) col = mix(col, vec3(0.95, 0.97, 1.0), 0.6);
		vec2 c = abs(fract(p / vec2(97.0, 61.0) + vec2(sin(p.y * 0.02) * 0.1, 0.0)) - 0.5);
		if (min(c.x, c.y) < 0.006) col *= 0.82;
		if (depth < 0.008) col = vec3(0.95, 0.97, 1.0);
	} else if (h < 0.5) {
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
		if (depth > 0.02) col = water_light(col, wpos, p);
	} else if (h < 0.525) {
		col = h < 0.506 ? SAND_WET : SAND;
	} else {
		float f = texture(cloud_tex, fract(p / 4400.0 + vec2(0.37, 0.61))).r;
		col = f > 0.55 ? FOREST : (h < 0.535 ? GRASS_LIGHT : GRASS);
	}
	if (bound_half > 0.0) {
		// battle area: outside is dimmed and tinted red, edge = dashed red line
		float e = max(abs(p.x), abs(p.y)) - bound_half;
		if (e > 0.0) col = mix(col * 0.6, vec3(0.6, 0.1, 0.1), 0.25);
		if (abs(e) < 6.0 && fract((p.x + p.y) / 80.0) < 0.6) col = vec3(1.0, 0.18, 0.12);
	}
	ALBEDO = fogged(lit(col, wpos), wpos);
}
