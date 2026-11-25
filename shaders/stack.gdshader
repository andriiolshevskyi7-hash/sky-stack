// Sprite-stack slices. Each slice is a flat textured quad at its height; the
// orthographic camera shifts higher slices "up the screen" by height*cos(pitch)
// automatically and the depth buffer sorts everything (alpha-scissor, opaque).
// Dynamic stacks (MultiMesh instances) are rotated here on the GPU:
//   INSTANCE_CUSTOM = (yaw, variant, bank_shear, flash)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform sampler2D emit_tex : source_color, filter_nearest;
uniform bool dynamic = false;
uniform bool fadeable = true;
uniform bool receive_shadow = true;
uniform vec2 variant_stride = vec2(0.0);
uniform float dither_alpha = 1.0;
uniform float near_fade = 0.0; // dissolve when closer than this to the camera
// Planes: index_tex holds material ids (see PlaneArt), the colour comes from
// palette_tex row = skin * 3 + plane class.
uniform bool palette_mode = false;
uniform sampler2D index_tex : filter_nearest;
uniform sampler2D palette_tex : source_color, filter_nearest;

varying vec3 wpos;
varying float flash;
varying flat float skin;

#include "res://shaders/plane_palette.gdshaderinc"

void vertex() {
	flash = 0.0;
	skin = 0.0;
	if (dynamic) {
		float yaw = INSTANCE_CUSTOM.r;
		if (sprite_snap > 0.5) {
			float st = 6.2831853 / sprite_snap;
			yaw = round(yaw / st) * st;
		}
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
}

void fragment() {
	vec4 a = palette_mode ? texture(index_tex, UV) : texture(albedo_tex, UV);
	if (a.a < 0.5) discard;
	if (dither_alpha < 0.999 && bayer4(FRAGCOORD.xy) > dither_alpha) discard;
	if (near_fade > 0.0) {
		float nd = length(VERTEX);
		if (bayer4(FRAGCOORD.xy) > smoothstep(near_fade * 0.4, near_fade, nd)) discard;
	}
	if (fadeable && fade_hides(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) discard;
	vec4 e;
	if (palette_mode) {
		a.rgb = plane_color(a, int(round(skin)), palette_tex, e);
	} else {
		e = texture(emit_tex, UV);
	}
	vec3 col = receive_shadow ? lit(a.rgb * COLOR.rgb, wpos) : a.rgb * COLOR.rgb * ambient;
	col += e.rgb * emission_strength(e.a, TIME, wpos);
	col = mix(col, vec3(1.0, 0.95, 0.85), clamp(flash, 0.0, 1.0));
	ALBEDO = fogged(col, wpos);
}
