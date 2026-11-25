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
uniform float dither_amount = 0.02;
uniform float contrast = 0.15;
uniform float vignette = 0.3;
uniform float grain = 0.25;
uniform float gblack = 0.0; // G-LOC: vision tunnels and greys out
uniform float gred = 0.0; // negative G: red-out
uniform sampler2D cockpit_tex : filter_nearest; // 3D cockpit (premultiplied alpha)
uniform float cockpit_alpha = 0.0;
uniform sampler2D stage_tex : filter_nearest; // main-menu 3D background
uniform float stage_alpha = 0.0;

vec3 bright(vec2 uv) {
	vec3 c = texture(src_lin, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	// warm saturated pixels (fire, engines, explosions) bloom a bit earlier
	float warm = clamp((c.r - c.b) * 1.6, 0.0, 1.0) * step(0.55, c.g);
	return c * max(smoothstep(threshold, 1.0, l), smoothstep(threshold - 0.1, 1.0, l) * warm);
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
	if (stage_alpha > 0.0) {
		c = mix(c, texture(stage_tex, UV).rgb, stage_alpha);
	}
	if (cockpit_alpha > 0.0) {
		vec4 k = texture(cockpit_tex, UV);
		c = c * (1.0 - k.a * cockpit_alpha) + k.rgb * cockpit_alpha;
	}
	if (flash > 0.0) {
		vec2 q = UV * 2.0 - 1.0;
		float vig = clamp(dot(q, q) * 0.7, 0.0, 1.0);
		c = mix(c, vec3(0.85, 0.12, 0.1), flash * vig);
	}
	// colour depth / contrast, darkened corners, film grain
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, 1.0 + contrast);
	c = (c - 0.5) * (1.0 + contrast * 0.8) + 0.5;
	vec2 vq = UV * 2.0 - 1.0;
	c *= 1.0 - vignette * 0.55 * smoothstep(0.35, 1.6, dot(vq, vq));
	c += (hash12(FRAGCOORD.xy + fract(TIME * 7.13) * vec2(91.7, 53.3)) - 0.5) * grain * 0.1;
	if (gblack > 0.0) {
		// grey-out first, then the tunnel closes in
		float r2 = dot(vq, vq);
		c = mix(c, vec3(dot(c, vec3(0.3, 0.5, 0.2))), clamp(gblack * 1.6, 0.0, 1.0));
		c *= 1.0 - smoothstep(1.6 - gblack * 1.9, 2.0 - gblack * 1.9, r2) * clamp(gblack * 1.2, 0.0, 1.0);
		c *= 1.0 - gblack * gblack * 0.85;
	}
	if (gred > 0.0) {
		c = mix(c, vec3(0.55, 0.04, 0.03) * (0.4 + dot(c, vec3(0.33))), clamp(gred * 0.9, 0.0, 0.9));
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
