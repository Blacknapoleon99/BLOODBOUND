shader_type sky;
// BLOODBOUND gothic night sky (DEC-053), fully procedural: a huge blood-red moon in the moonlight's
// azimuth, drifting storm clouds lit from the moon side, stars through the gaps, a
// faint crimson horizon glow and a dark abyss below the horizon (the courses float in the void).
// The radiance (cubemap) pass takes a cheaper path: fewer cloud octaves, no stars, no moon craters.

uniform vec3 zenith_color : source_color = vec3(0.012, 0.012, 0.028);
uniform vec3 horizon_color : source_color = vec3(0.22, 0.05, 0.05);
uniform vec3 abyss_color : source_color = vec3(0.012, 0.006, 0.011);
uniform vec3 abyss_glow_color : source_color = vec3(0.10, 0.018, 0.012);
uniform vec3 moon_color : source_color = vec3(1.0, 0.05, 0.02);
uniform float moon_energy = 1.15;
uniform float moon_size = 0.085;          // angular radius (radians): a huge moon
uniform float halo_energy = 0.75;
uniform vec3 cloud_dark : source_color = vec3(0.03, 0.026, 0.036);
uniform vec3 cloud_lit : source_color = vec3(0.62, 0.17, 0.14);
uniform float cloud_coverage = 0.58;      // 0 = clear, 1 = overcast
uniform float cloud_speed = 0.006;
uniform float star_density = 0.0045;
uniform float star_energy = 2.2;
// The visible moon sits lower than the moonlight that lights the courses (set by GothicEnvironment),
// so it stays in frame behind the play camera while the ground still gets a readable key angle.
uniform vec3 moon_dir_uniform = vec3(0.86, 0.2, -0.46);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 moon_dir = normalize(moon_dir_uniform);
	bool cheap = AT_CUBEMAP_PASS;
	float h = dir.y;

	// --- base gradient: zenith -> crimson horizon band -> abyss below ---
	float up = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.38));
	float band = exp(-abs(h) * 14.0);
	col += horizon_color * band * 0.6;
	if (h < 0.0) {
		float down = clamp(-h, 0.0, 1.0);
		vec3 below = mix(horizon_color * 0.55, abyss_color, pow(down, 0.3));
		below += abyss_glow_color * pow(down, 3.0) * 0.6; // faint ember glow from the depths
		col = below;
	}

	// --- moon ---
	float cos_m = dot(dir, moon_dir);
	float ang = acos(clamp(cos_m, -1.0, 1.0));
	float halo = exp(-ang * 10.0) * 0.6 + exp(-ang * 3.2) * 0.07;
	col += moon_color * halo * halo_energy * (h > -0.05 ? 1.0 : 0.35);

	float disc = 1.0 - smoothstep(moon_size * 0.97, moon_size, ang);
	vec3 moon_rgb = vec3(0.0);
	if (disc > 0.0) {
		float r = ang / moon_size;
		float limb = sqrt(max(1.0 - r * r, 0.0));
		float maria = 1.0;
		if (!cheap) {
			vec3 q = (dir - moon_dir) / moon_size * 2.4;
			maria = 0.5 + 0.5 * smoothstep(0.3, 0.7, fbm(q * 1.6 + 3.0, 4));
			maria *= 0.85 + 0.15 * vnoise(q * 9.0);
		}
		moon_rgb = moon_color * moon_energy * mix(0.45, 1.0, limb) * maria;
	}

	// --- clouds (sky dome above the horizon, thinning into a haze below it) ---
	float cloud = 0.0;
	vec3 cloud_rgb = vec3(0.0);
	float hz = max(h, 0.0) + 0.16;
	vec2 uv = dir.xz / hz * 0.9;
	vec3 drift = vec3(TIME * cloud_speed * 6.0, TIME * cloud_speed * 0.6, TIME * cloud_speed * 2.0);
	int oct = cheap ? 3 : 5;
	float n = fbm(vec3(uv, 0.0) + drift, oct);
	// broad storm fronts modulate the detail
	float fronts = vnoise(vec3(uv * 0.25, 0.0) + drift * 0.3);
	float cov = cloud_coverage + (fronts - 0.5) * 0.45;
	cloud = smoothstep(1.0 - cov - 0.12, 1.0 - cov + 0.22, n);
	cloud *= smoothstep(-0.18, 0.06, h); // clouds die out under the horizon
	if (cloud > 0.001) {
		// light from the moon side: a second tap shifted toward the moon reads as lit rims
		vec2 to_moon = normalize(moon_dir.xz / (max(moon_dir.y, 0.0) + 0.16) - uv + 1e-4) * 0.06;
		float n2 = fbm(vec3(uv + to_moon, 0.0) + drift, oct);
		float rim = clamp((n - n2) * 6.0 + 0.35, 0.0, 1.0);
		float near_moon = exp(-ang * 2.2);
		vec3 lit = cloud_lit * (rim * (0.12 + near_moon * 1.6) + near_moon * 0.25);
		// cloud bellies near the horizon pick up the crimson glow from below
		lit += horizon_color * exp(-max(h, 0.0) * 7.0) * 0.9;
		cloud_rgb = cloud_dark + lit;
	}

	// --- stars through the gaps ---
	vec3 stars = vec3(0.0);
	if (!cheap && h > 0.02) {
		vec3 sp = dir * 260.0;
		vec3 cell = floor(sp);
		float s = hash13(cell);
		if (s < star_density * 60.0 * 0.06) {
			vec3 center = cell + vec3(hash13(cell + 7.1), hash13(cell + 3.3), hash13(cell + 5.9));
			float d = length(sp - center);
			float tw = 0.65 + 0.35 * sin(TIME * (1.5 + s * 40.0) + s * 100.0);
			float b = smoothstep(0.42, 0.0, d) * tw * star_energy;
			stars = mix(vec3(0.75, 0.8, 1.0), vec3(1.0, 0.7, 0.6), hash13(cell + 1.9)) * b;
		}
		stars *= smoothstep(0.02, 0.25, h) * (1.0 - smoothstep(0.0, 0.45, cloud));
		stars *= 1.0 - clamp(halo * 2.0, 0.0, 1.0);
	}

	col += stars;
	col += moon_rgb * disc;
	// clouds pass in front of the moon (thin ones let it glow through)
	col = mix(col, cloud_rgb + moon_rgb * disc * 0.18, cloud * 0.9);
	COLOR = col;
}
