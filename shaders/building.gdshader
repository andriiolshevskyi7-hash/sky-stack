// "Collapsed" sprite stacks for tall buildings: instead of hundreds of
// identical slices, the walls are quads whose texture rows ARE the slices
// (facade tiles repeat per floor), plus a roof quad. UV2 = tile origin in the
// facade atlas, UV = position in tile units, COLOR.rgb = face shade,
// COLOR.a = per-building random seed (window light pattern).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D facade_tex : source_color, filter_nearest_mipmap;
uniform sampler2D facade_emit : filter_nearest_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Sample the atlas with derivatives of the continuous UV (no seams at the
// tile wrap). The mip level is capped so tiles don't bleed into neighbours.
vec4 atlas(sampler2D t, vec2 uv, vec2 g) {
	vec2 dx = dFdx(g);
	vec2 dy = dFdy(g);
	float m = max(length(dx), length(dy)) * 512.0;
	float k = m > 6.0 ? 6.0 / m : 1.0; // lod <= ~2.6
	return textureGrad(t, uv, dx * k, dy * k);
}

void fragment() {
	if (fade_hides(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) discard;
	// facades: rows 0-96 and 160-208 px; roofs: 96-160 (64 tall) and 208-256 (48 tall)
	bool roof = (UV2.y > 0.37 && UV2.y < 0.6) || UV2.y > 0.8;
	vec2 tile = roof ? vec2(32.0 / 256.0, UV2.y > 0.8 ? 24.0 / 128.0 : 32.0 / 128.0) : vec2(32.0 / 256.0, 24.0 / 128.0);
	vec2 uv = UV2 + fract(UV) * tile;
	vec2 g = UV * tile;
	vec3 base = atlas(facade_tex, uv, g).rgb * COLOR.rgb;
	vec3 col = lit(base, wpos);
	float d = distance(wpos, cam_pos);
	if (!roof && night > 0.02) {
		vec4 em = atlas(facade_emit, uv, g);
		// neon strips: subtle
		if (em.g > 0.3) col = mix(col, base * 1.15, night * 0.6 * em.g);
		// warm, dim windows; ~30% lit up close, a soft average glow far away
		vec3 warm = vec3(1.0, 0.72, 0.4) * 0.8;
		vec2 cell = floor(UV * 4.0);
		float h = hash12(cell + vec2(COLOR.a * 311.0, COLOR.a * 97.0));
		float win = textureLod(facade_emit, uv, 0.0).r; // exact window mask
		float near_l = step(h, 0.3) * step(0.5, win) * 0.75;
		float far_l = min(em.r * 0.3 * 1.6, 0.35); // average of ~30% lit windows
		float far = smoothstep(350.0, 1100.0, d);
		col = mix(col, warm, mix(near_l, far_l, far) * night);
	}
	// distance haze: far buildings soften, desaturate and blend into the air
	float hz = smoothstep(300.0, 2400.0, d);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.5, 0.2))), hz * 0.35);
	col = mix(col, fog_color, hz * 0.4);
	ALBEDO = fogged(col, wpos);
}
