// Wakes on the water (Wakes): UV.x across the wake (0..1), UV.y = age
// (0 new .. 1 gone), COLOR.a = strength. A churned white trail in the middle
// (narrowing and breaking up as it ages) and the two Kelvin arms along the
// edges with their little cusp waves; broken up by the foam noise.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float age = UV.y;
	float fn = texture(water_nrm, wpos.xz / 14.0 + vec2(TIME * 0.01, 0.0)).b;
	float fn2 = texture(water_nrm, wpos.xz / 5.0 - vec2(0.0, TIME * 0.02)).b;
	float foamn = fn * 0.6 + fn2 * 0.4;
	// the churned centre: wide and solid at the stern, thin and torn later
	float cw = mix(0.35, 0.12, sqrt(age));
	float centre = 1.0 - smoothstep(cw * 0.5, cw, x);
	centre *= smoothstep(0.25 + age * 0.5, 0.55 + age * 0.3, foamn + (1.0 - x / max(cw, 0.01)) * 0.35);
	centre *= pow(1.0 - age, 1.4);
	// Kelvin arms: bright lines near the edges with cusp waves along them
	float cusp = 0.6 + 0.4 * sin(dot(wpos.xz, vec2(0.37, 0.29)) * 0.8);
	float arm = smoothstep(0.82, 0.94, x) * (1.0 - smoothstep(0.955, 1.0, x));
	arm *= cusp * mix(0.55, 1.0, smoothstep(0.3, 0.6, foamn)) * pow(1.0 - age, 0.8) * 0.85;
	// short diagonal crests feathering in from the arms
	float feather = smoothstep(0.6, 0.85, x) * (1.0 - smoothstep(0.9, 0.97, x));
	feather *= step(0.72, fract(dot(wpos.xz, vec2(0.11, 0.07)) + x * 2.0)) * (1.0 - age) * 0.3;
	arm = max(arm, feather * smoothstep(0.4, 0.6, foamn));
	float a = max(centre, arm) * COLOR.a;
	if (a < 0.01) discard;
	vec3 col = vec3(0.95, 0.98, 1.0) * max(ambient, vec3(0.3)) + sun_col * 0.08 * (1.0 - night);
	ALBEDO = fogged(col, wpos);
	ALPHA = clamp(a, 0.0, 0.95);
}
