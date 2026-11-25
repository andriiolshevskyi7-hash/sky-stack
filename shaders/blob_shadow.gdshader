// Ground shadows of the other planes: flat quads (one per plane, MultiMesh)
// with an elongated soft ellipse, multiplied onto the ground like the
// building shadows; COLOR.a = strength (fades with altitude).
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled;

#include "res://shaders/common.gdshaderinc"

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vp.xyz *= 1.0 - 6.0 * 0.00018;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	// plane-like shape: a long body and a wide wing band in the middle
	float body = step(abs(d.x), 0.16) * step(abs(d.y), 0.95);
	float wing = step(abs(d.y + 0.1), 0.22) * step(abs(d.x), 0.95 - abs(d.y + 0.1));
	float tail = step(abs(d.y - 0.78), 0.1) * step(abs(d.x), 0.4);
	float m = max(body, max(wing, tail));
	if (m < 0.5) discard;
	float k = COLOR.a * (1.0 - night * 0.85);
	ALBEDO = mix(vec3(1.0), vec3(0.42, 0.5, 0.78), k);
}
