// Post-process INSIDE the low-res view: bloom of bright pixels, cloud fog,
// hit flash, then snapping to the shared 32-colour palette with ordered dither.
shader_type canvas_item;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D src : filter_nearest;
uniform sampler2D src_lin : filter_linear;
uniform sampler2D palette : filter_nearest;
uniform int palette_size = 32;
uniform float palette_mix = 1.0;
uniform float bloom = 0.9;
uniform float threshold = 0.8;
uniform float fog = 0.0;
uniform float flash = 0.0;
uniform float dither_amount = 0.035;

vec3 bright(vec2 uv) {
	vec3 c = texture(src_lin, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(threshold, 1.0, l);
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(src, 0));
	vec3 c = texture(src, UV).rgb;
	vec3 b = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 d = vec2(cos(a), sin(a));
		b += bright(UV + d * 1.5 * px) * 0.10;
		b += bright(UV + d.yx * vec2(1.0, -1.0) * 3.5 * px) * 0.06;
		b += bright(UV + d * 6.0 * px) * 0.035;
	}
	c += b * bloom;
	float bay = bayer4(FRAGCOORD.xy);
	if (fog > 0.0) {
		c = mix(c, vec3(0.95, 0.97, 1.0) * max(ambient, vec3(0.35)), clamp(fog, 0.0, 1.0));
	}
	if (flash > 0.0) {
		vec2 q = UV * 2.0 - 1.0;
		float vig = clamp(dot(q, q) * 0.7, 0.0, 1.0);
		c = mix(c, vec3(0.85, 0.12, 0.1), flash * vig);
	}
	if (palette_mix > 0.0) {
		vec3 cq = c + (bay - 0.5) * dither_amount;
		vec3 best = vec3(0.0);
		float bd = 1e9;
		for (int i = 0; i < palette_size; i++) {
			vec3 p = texelFetch(palette, ivec2(i, 0), 0).rgb;
			vec3 d = (cq - p) * vec3(0.30, 0.59, 0.11);
			float dd = dot(d, d) + dot(cq - p, cq - p) * 0.15;
			if (dd < bd) {
				bd = dd;
				best = p;
			}
		}
		c = mix(c, best, palette_mix);
	}
	COLOR = vec4(c, 1.0);
}
