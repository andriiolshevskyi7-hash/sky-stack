// Physical sky: single-scattering atmosphere (Rayleigh + Mie, Nishita style)
// around a small "game" planet, so the horizon visibly dips and curves at
// 3-5 km. Blue by day, orange-violet at dawn / dusk (the sun light itself
// reddens through the long path), a glowing sun with a Mie halo; below the
// horizon the far sea / land seen through the haze. At night: moon, twinkling
// stars and the Milky Way. The same model runs on the CPU (DayNight) for the
// fog colours, so the world haze matches the sky.
shader_type sky;

uniform float night = 0.0;
uniform float sun_amount = 1.0;
uniform vec3 sun_dir = vec3(-0.5, 0.5, -0.7);
uniform vec3 moon_dir = vec3(0.45, 0.45, -0.75);
uniform float exposure = 3.0;
uniform float haze = 1.0; // Mie amount (weather)
uniform vec3 ground_albedo = vec3(0.05, 0.16, 0.3); // far sea / land below the horizon
uniform float overcast = 0.0; // weather: greys the sky
uniform vec3 sun_ground = vec3(1.0); // sunlight colour at the surface (CPU, Atmo)

const float RE = 600000.0;      // planet radius (game scale)
const float RA = RE + 60000.0;  // top of the atmosphere
const float HR = 7994.0;        // Rayleigh scale height
const float HM = 1200.0;        // Mie scale height
const vec3 BR = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const vec3 BO = vec3(0.65e-6, 1.88e-6, 0.085e-6) * 4.5; // ozone: blue horizon, violet twilight
const float BM = 4.5e-6;
const float G = 0.82;

vec2 sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float d = b * b - c;
	if (d < 0.0) return vec2(1e9, -1e9);
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

// Inscattered light along rd from ro; .rgb colour, `trans` = transmittance.
vec3 atmosphere(vec3 ro, vec3 rd, vec3 sd, out vec3 trans, out bool ground) {
	vec2 ta = sphere(ro, rd, RA);
	vec2 te = sphere(ro, rd, RE);
	float t1 = ta.y;
	ground = te.x > 0.0 && te.x < 1e8;
	if (ground) t1 = te.x;
	float ds = t1 / 10.0;
	float mu = dot(rd, sd);
	float pr = 3.0 / (16.0 * 3.14159) * (1.0 + mu * mu);
	float pm = 3.0 / (8.0 * 3.14159) * ((1.0 - G * G) * (1.0 + mu * mu)) / ((2.0 + G * G) * pow(max(1.0 + G * G - 2.0 * G * mu, 1e-4), 1.5));
	vec3 sr = vec3(0.0);
	vec3 sm = vec3(0.0);
	float odr = 0.0;
	float odm = 0.0;
	for (int i = 0; i < 10; i++) {
		vec3 p = ro + rd * (ds * (float(i) + 0.5));
		float h = length(p) - RE;
		float hr = exp(-h / HR) * ds;
		float hm = exp(-h / HM) * ds;
		odr += hr;
		odm += hm;
		// light path to the sun
		vec2 tl = sphere(p, sd, RA);
		vec2 tg = sphere(p, sd, RE);
		if (tg.x > 0.0 && tg.x < 1e8) continue; // in the planet's shadow
		float dl = tl.y / 3.0;
		float lr = 0.0;
		float lm = 0.0;
		for (int j = 0; j < 3; j++) {
			vec3 q = p + sd * (dl * (float(j) + 0.5));
			float hq = max(length(q) - RE, 0.0);
			lr += exp(-hq / HR) * dl;
			lm += exp(-hq / HM) * dl;
		}
		vec3 att = exp(-((BR + BO) * (odr + lr) + BM * haze * 1.1 * (odm + lm)));
		sr += att * hr;
		sm += att * hm;
	}
	trans = exp(-((BR + BO) * odr + BM * haze * 1.1 * odm));
	return sr * BR * pr + sm * BM * haze * pm;
}

float h3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 sd = normalize(sun_dir);
	vec3 ro = vec3(0.0, RE + max(POSITION.y, 2.0), 0.0);
	vec3 trans;
	bool ground;
	vec3 sun_i = vec3(1.0) * sun_amount;
	vec3 c = atmosphere(ro, d, sd, trans, ground) * 20.0 * sun_amount;
	if (ground) {
		// the far sea / land below the horizon, lit by the sun through the air
		vec3 gp = ro + d * sphere(ro, d, RE).x;
		vec3 n = normalize(gp);
		float lit = max(dot(n, sd), 0.0) * 0.8 + 0.2;
		c += ground_albedo * trans * sun_ground * lit * 1.6 * sun_amount;
	} else {
		// sun disc (reddened by the air it shines through) + glow
		float sdot = dot(d, sd);
		c += trans * vec3(1.0, 0.92, 0.8) * smoothstep(0.99955, 0.9998, sdot) * 40.0 * sun_amount;
	}
	// exposure tone map, mostly hue-preserving (a sunset stays orange
	// instead of burning to white)
	vec3 tc = vec3(1.0) - exp(-c * exposure);
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 hc = min(c * ((1.0 - exp(-lum * exposure)) / max(lum, 1e-6)), vec3(1.0));
	c = mix(tc, hc, 0.85);
	// night sky floor: deep blue, lighter towards the horizon
	c = max(c, mix(vec3(0.07, 0.08, 0.16), vec3(0.016, 0.02, 0.05), clamp(d.y * 1.6, 0.0, 1.0)) * night);
	// overcast weather: grey, flat
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(l) * vec3(0.92, 0.95, 1.0), overcast);
	// ---- night: Milky Way, stars, moon (fade in as the sky darkens)
	float dark = night * (1.0 - overcast);
	if (dark > 0.01 && d.y > -0.05) {
		vec3 c0 = c;
		// Milky Way: a band across the sky with dark dust lanes
		vec3 gal_n = normalize(vec3(0.35, 0.55, 0.76));
		float band = exp(-pow(dot(d, gal_n) / 0.16, 2.0));
		float dust = n3(d * 9.0) * 0.6 + n3(d * 23.0) * 0.4;
		float glow = band * (0.55 + 0.6 * dust) * smoothstep(0.38, 0.62, dust + band * 0.3);
		c += vec3(0.32, 0.34, 0.45) * glow * 0.32 * dark;
		// stars: two layers, more stars inside the band, tinted, twinkling
		for (int k = 0; k < 2; k++) {
			float sc = k == 0 ? 220.0 : 420.0;
			vec3 q = floor(d * sc);
			float hs = h3(q + float(k) * 13.1);
			float thr = (k == 0 ? 0.9975 : 0.9965) - band * 0.004;
			if (hs > thr) {
				float tw = 0.6 + 0.4 * sin(TIME * (2.0 + hs * 9.0) + hs * 80.0);
				vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.86, 0.7), fract(hs * 57.0));
				c += tint * (k == 0 ? 1.0 : 0.55) * tw * dark * smoothstep(-0.02, 0.15, d.y);
			}
		}
		// moon with a soft halo
		float m = dot(d, normalize(moon_dir));
		c += vec3(0.55, 0.65, 0.9) * pow(max(m, 0.0), 200.0) * dark * 0.8;
		if (m > 0.9988) {
			float md = (m - 0.9988) / 0.0012;
			c = mix(c, vec3(0.94, 0.95, 1.0) * (0.85 + 0.15 * n3(d * 900.0)), dark * smoothstep(0.0, 0.25, md));
		}
		c = max(c, c0);
	}
	COLOR = c;
}
