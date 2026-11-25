// Decode a plane slice pixel (PlaneArt): R = material, G = shade (0.5 = 1.0),
// B = flags (bits 0-1 camo masks, 4-5 emission class, 6-7 plane class).
// Palette row = skin * 3 + class; column 28 = camo colour, 29 alpha = camo
// pattern (0 none, 1 blotches, 2 stripes). Returns the colour, emission in e
// (rgb + class alpha as used by emission_strength / 0.66 always).
vec3 plane_color(vec4 a, int skin_i, sampler2D pal, out vec4 e) {
	int m = int(round(a.r * 255.0));
	int f = int(round(a.b * 255.0));
	int row = skin_i * 3 + ((f >> 6) & 3);
	vec3 c = texelFetch(pal, ivec2(m, row), 0).rgb;
	int pat = int(round(texelFetch(pal, ivec2(29, row), 0).a * 255.0));
	if (pat > 0 && ((f >> (pat - 1)) & 1) == 1) {
		c = texelFetch(pal, ivec2(28, row), 0).rgb;
	}
	int em = (f >> 4) & 3;
	e = vec4(0.0);
	if (em > 0) {
		e.rgb = c;
		e.a = em == 1 ? 0.66 : (em == 2 ? 1.0 : 0.33);
		c *= 0.7;
	}
	return c * a.g * 2.0;
}
