// Reflections of planes and ships on the water: the same instanced sprite
// stacks drawn mirrored under the surface (StackBatch adds a mirrored copy
// of the batch). Each pixel finds where its view ray crosses the water,
// keeps only open water there, writes that point's depth (so anything in
// front still hides the reflection, and the plane hides its own), blends by
// the water's Fresnel and ripples with the waves.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform sampler2D emit_tex : source_color, filter_nearest;
uniform bool dynamic = true;
uniform vec2 variant_stride = vec2(0.0);
uniform bool palette_mode = false;
uniform sampler2D index_tex : filter_nearest;
uniform sampler2D palette_tex : source_color, filter_nearest;
uniform float water_y = 0.0;
// fade out the reflections of things this high above the water
uniform float max_h = 420.0;

varying vec3 wpos;
varying float flash;
varying flat float skin;

#include "res://shaders/plane_palette.gdshaderinc"

void vertex() {
	flash = 0.0;
	skin = 0.0;
	if (dynamic) {
		float yaw = INSTANCE_CUSTOM.r;
		vec3 v = VERTEX;
		v.x += INSTANCE_CUSTOM.b * v.y;
		float c = cos(yaw);
		float s = sin(yaw);
		VERTEX = vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
		UV += variant_stride * floor(INSTANCE_CUSTOM.g + 0.5);
		skin = INSTANCE_CUSTOM.g;
		flash = INSTANCE_CUSTOM.a;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// ripples sway the reflection sideways
	wpos.x += sin(TIME * 2.3 + wpos.z * 0.21 + wpos.y * 0.5) * 0.35;
	wpos.z += sin(TIME * 1.9 + wpos.x * 0.17 + wpos.y * 0.4) * 0.35;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wpos, 1.0));
}

void fragment() {
	vec4 a = palette_mode ? texture(index_tex, UV) : texture(albedo_tex, UV);
	if (a.a < 0.5) discard;
	float hgt = water_y - wpos.y; // height of the real point above the water
	vec3 rd = wpos - cam_pos;
	if (cam_pos.y <= water_y + 0.5 || rd.y >= -0.001 || hgt > max_h) discard;
	vec3 sp = cam_pos + rd * ((water_y - cam_pos.y) / rd.y);
	if (island_h(sp.xz * 0.5) > 0.497) discard;
	vec4 e;
	if (palette_mode) {
		a.rgb = plane_color(a, int(round(skin)), palette_tex, e);
	} else {
		e = texture(emit_tex, UV);
	}
	vec3 rp = vec3(wpos.x, 2.0 * water_y - wpos.y, wpos.z);
	vec3 col = lit(a.rgb * COLOR.rgb, rp) + e.rgb * emission_strength(e.a, TIME, rp);
	// what the water does to it: Fresnel strength, a cool tint, wave breakup
	vec3 v = normalize(cam_pos - sp);
	float F = 0.02 + 0.98 * pow(1.0 - clamp(v.y, 0.0, 1.0), 5.0);
	float k = clamp(0.22 + F * 1.2, 0.0, 0.8);
	vec2 wn = texture(water_nrm, sp.xz / 11.0 + TIME * vec2(0.035, -0.02)).rg;
	k *= 0.7 + 0.3 * smoothstep(0.35, 0.6, wn.x);
	k *= 1.0 - smoothstep(max_h * 0.55, max_h, hgt);
	col *= vec3(0.80, 0.88, 0.96);
	ALBEDO = fogged(col, sp);
	ALPHA = k;
	vec3 dp = sp + (cam_pos - sp) * 0.003;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(dp, 1.0);
	DEPTH = clamp(clip.z / clip.w * 0.5 + 0.5, 0.0, 1.0);
}
