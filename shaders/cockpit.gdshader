// 3D cockpit (Cockpit3D): pixel-art atlas (CockpitArt canvas) on low-poly
// meshes, rendered in its own low-res viewport and composited over the world.
// COLOR.a = 1: lit surface (sun through the canopy + ambient + soft AO
// towards the floor, green / amber instrument glow at night);
// COLOR.a = 0: emissive (displays, keypad, warning lights).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex : filter_nearest;
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.3); // cockpit space, towards the sun
uniform float sun_k = 1.0;
uniform vec3 amb_col = vec3(0.6);
uniform float night = 0.0;
uniform vec3 glow_col = vec3(0.3, 0.9, 0.45);
uniform float flash = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) discard;
	vec3 n = normalize(ln);
	if (!FRONT_FACING) n = -n;
	float lam = max(dot(n, sun_dir), 0.0);
	// lower in the tub = darker (cheap ambient occlusion)
	float ao = clamp((lp.y + 0.95) / 0.75, 0.3, 1.0);
	vec3 light = amb_col * (0.55 + 0.45 * ao) + vec3(1.0, 0.95, 0.86) * lam * sun_k * (0.35 + 0.65 * ao);
	// instrument flood light at night, strongest around the panel
	float gd = length(lp - vec3(0.0, -0.32, -0.62));
	light += glow_col * night * (0.22 + 0.55 / (1.0 + gd * gd * 9.0));
	vec3 c = t.rgb * COLOR.rgb * light;
	c = mix(t.rgb * COLOR.rgb, c, COLOR.a);
	c += vec3(1.0, 0.7, 0.4) * flash * 0.25 * COLOR.a;
	ALBEDO = c;
}
