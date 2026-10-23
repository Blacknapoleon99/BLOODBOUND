// Background world (DEC-055): merged low-poly silhouettes (cathedral, towers, islands, ribs,
// chains, cages). Vertex COLOR.rgb tints the stone; COLOR.a < 0.5 marks glowing parts (windows,
// the rose window, eyes) that flicker. Applies its own distance haze toward `haze_color`
// (fog_disabled), so far layers stay readable whatever the scene fog does; the horizon syncs
// `haze_color` to the environment's fog colour at runtime. Works in Compatibility and Forward+.
shader_type spatial;
render_mode cull_disabled, fog_disabled, specular_disabled;

uniform vec4 stone_color : source_color = vec4(0.11, 0.10, 0.12, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.16, 0.07, 1.0);
uniform float glow_energy = 3.0;
uniform vec4 haze_color : source_color = vec4(0.12, 0.06, 0.08, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.16, 0.14, 1.0);
uniform float rim_strength = 0.6;
uniform float haze_start = 40.0;
uniform float haze_end = 1100.0;
uniform float haze_max = 0.82;
uniform float self_light = 0.18;

varying vec3 wpos;
varying vec4 vcol;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	float d = length(wpos - CAMERA_POSITION_WORLD);
	float h = smoothstep(haze_start, haze_end, d) * haze_max;
	float glow = 1.0 - step(0.5, vcol.a);
	// Weathered stone: two octaves of world-space noise, darker toward the abyss.
	float n = vnoise(wpos * 0.21) * 0.6 + vnoise(wpos * 0.9) * 0.4;
	vec3 base = stone_color.rgb * vcol.rgb * (0.7 + 0.6 * n);
	base *= mix(0.35, 1.0, smoothstep(-90.0, 30.0, wpos.y));
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	// Flicker: each window cell (2 m) breathes on its own.
	float cell = hash3(floor(wpos * 0.5));
	float flick = 0.72 + 0.18 * sin(TIME * (1.7 + cell * 3.1) + cell * 40.0) + 0.1 * sin(TIME * 9.0 + cell * 13.0);
	vec3 glow_rgb = glow_color.rgb * vcol.rgb * glow_energy * flick * (1.0 - h * 0.55);
	ALBEDO = base * (1.0 - glow) * (1.0 - h);
	ROUGHNESS = 0.95;
	EMISSION = mix(base * self_light + rim_color.rgb * fres * rim_strength * (1.0 - h), glow_rgb, glow) + haze_color.rgb * h;
}
