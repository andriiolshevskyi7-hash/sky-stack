// Sky: vertical gradient (day / sunset / night colours set by DayNight),
// pixel stars and a glowing moon at night, a soft sun disc by day.
shader_type sky;

uniform vec3 top_color = vec3(0.18, 0.45, 0.84);
uniform vec3 horizon_color = vec3(0.62, 0.80, 0.95);
uniform vec3 ground_color = vec3(0.12, 0.37, 0.75);
uniform float night = 0.0;
uniform float sun_amount = 1.0;
uniform vec3 sun_dir = vec3(-0.5, 0.5, -0.7);
uniform vec3 moon_dir = vec3(0.45, 0.45, -0.75);

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 c;
	if (y > 0.0) {
		c = mix(horizon_color, top_color, pow(clamp(y, 0.0, 1.0), 0.45));
	} else {
		c = mix(horizon_color, ground_color, clamp(-y * 8.0, 0.0, 1.0));
	}
	if (night > 0.01 && y > 0.0) {
		vec3 q = floor(d * 260.0);
		float h = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		if (h > 0.9965) c += vec3(1.0) * night * smoothstep(0.0, 0.2, y);
	}
	float m = dot(d, normalize(moon_dir));
	c += vec3(0.55, 0.65, 0.9) * pow(max(m, 0.0), 220.0) * night * 0.9;
	if (m > 0.9988) c = mix(c, vec3(0.96, 0.97, 1.0), night);
	float sd = dot(d, normalize(sun_dir));
	c += vec3(1.0, 0.75, 0.45) * pow(max(sd, 0.0), 120.0) * sun_amount * 0.6;
	if (sd > 0.9993) c = mix(c, vec3(1.0, 0.95, 0.8), sun_amount);
	COLOR = c;
}
