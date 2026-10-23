shader_type spatial;
// BLOODBOUND level blocks (DEC-054): axis-aligned BoxMesh platforms, pillars and walls.
// - Planar mapping per face in world (or local, for movers) metres, so any box size tiles.
// - Walkable top uses the TOP texture set (flagstone / cobble), the sides the SIDE set (masonry).
// - Fake bevel: normals tilt and the albedo brightens along the top rim and vertical corners.
// - Sides fade to near-black with depth below the top (floating ruins over the void), with
//   moss and blood drips near the rim; tops get creeping moss, blood pools and wet patches.
// - Per-block hue/brightness variation plus large-scale noise to break tiling.
// The box half-size is read from the corner vertices (a BoxMesh with no subdivisions has only
// corner vertices), so one shared material works for every block size.
// Plain GLSL only: works in Compatibility (GL3.3) and Forward+.

uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float top_scale = 2.6;   // metres per texture tile
uniform float side_scale = 3.5;
uniform vec4 top_tint : source_color = vec4(1.0);
uniform vec4 side_tint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_bias = 0.0;  // < 0: wetter
uniform float side_fade = 5.0;       // metres below the top to fade to dark
uniform float side_dark = 0.12;
uniform float edge_width = 0.16;
uniform float edge_light = 0.35;
uniform float moss = 0.35;
uniform vec4 moss_color : source_color = vec4(0.13, 0.16, 0.08, 1.0);
uniform float blood = 0.0;
uniform vec4 blood_color : source_color = vec4(0.22, 0.015, 0.01, 1.0);
uniform float variation = 0.22;
uniform bool local_space = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_rim = 0.0;    // glow along the top rim (movers read as moving)
uniform float emission_cracks = 0.0; // glow in the crevices (breakable / cracked)
uniform vec4 flash : source_color = vec4(0.6, 0.15, 0.1, 0.0); // a = mix amount (collapse warning)

varying vec3 v_local;
varying vec3 v_half;
varying vec3 v_pos;
varying float v_seed;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float g = hash13(i + vec3(1.0, 0.0, 1.0));
	float h = hash13(i + vec3(0.0, 1.0, 1.0));
	float k = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.13) * 0.3 + vnoise(p * 4.7) * 0.15;
}

void vertex() {
	v_local = VERTEX;
	v_half = abs(VERTEX);
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_pos = local_space ? VERTEX : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_seed = local_space ? 0.37 : hash13(floor(origin * 3.0) + 17.0);
}

void fragment() {
	// Face normal in object space (boxes are never rotated).
	vec3 n = vec3(0.0);
	vec3 rel = v_local / max(v_half, vec3(0.001));
	vec3 ar = abs(rel);
	// The face this fragment lies on: the axis where |local| reaches the half size.
	if (ar.y >= ar.x && ar.y >= ar.z) {
		n = vec3(0.0, sign(rel.y), 0.0);
	} else if (ar.x >= ar.z) {
		n = vec3(sign(rel.x), 0.0, 0.0);
	} else {
		n = vec3(0.0, 0.0, sign(rel.z));
	}
	bool is_top = n.y > 0.5;
	bool is_bottom = n.y < -0.5;

	vec2 uv;
	vec3 T;
	vec3 B;
	if (abs(n.y) > 0.5) {
		uv = vec2(v_pos.x, -v_pos.z) / top_scale;
		T = vec3(1.0, 0.0, 0.0);
		B = vec3(0.0, 0.0, 1.0);
	} else if (abs(n.x) > 0.5) {
		uv = vec2(v_pos.z, -v_pos.y) / side_scale;
		T = vec3(0.0, 0.0, 1.0);
		B = vec3(0.0, 1.0, 0.0);
	} else {
		uv = vec2(v_pos.x, -v_pos.y) / side_scale;
		T = vec3(1.0, 0.0, 0.0);
		B = vec3(0.0, 1.0, 0.0);
	}

	vec3 alb;
	vec3 arm;
	vec2 tn;
	if (is_top) {
		alb = texture(top_albedo, uv).rgb * top_tint.rgb;
		arm = texture(top_arm, uv).rgb;
		tn = texture(top_normal, uv).xy * 2.0 - 1.0;
	} else {
		alb = texture(side_albedo, uv).rgb * side_tint.rgb;
		arm = texture(side_arm, uv).rgb;
		tn = texture(side_normal, uv).xy * 2.0 - 1.0;
	}
	tn *= normal_strength;
	vec3 pn = normalize(T * tn.x + B * tn.y + n * sqrt(max(0.05, 1.0 - dot(tn, tn))));
	float rough = clamp(arm.g + roughness_bias, 0.04, 1.0);
	float ao = arm.r;

	// Large-scale variation (breaks tiling) and a per-block tone.
	float macro = fbm(v_pos * 0.23 + v_seed * 13.0);
	alb *= 1.0 + variation * (macro * 2.0 - 1.0);
	alb *= mix(vec3(1.0), vec3(1.07, 0.96, 0.92), v_seed * variation * 3.0);

	float below = v_half.y - v_local.y; // metres below the top surface
	float rim = 0.0;
	if (is_top) {
		float ex = v_half.x - abs(v_local.x);
		float ez = v_half.z - abs(v_local.z);
		float e = min(ex, ez);
		rim = 1.0 - smoothstep(0.0, edge_width, e);
		vec3 out_dir = ex < ez ? vec3(sign(v_local.x), 0.0, 0.0) : vec3(0.0, 0.0, sign(v_local.z));
		pn = normalize(mix(pn, normalize(n + out_dir * 1.1), rim * 0.85));
		alb *= 1.0 + edge_light * rim;
		// Grime gathers just inside the worn rim.
		float grime = smoothstep(edge_width, edge_width * 4.0, e);
		alb *= mix(0.78, 1.0, grime);
		// Moss creeping in from the edges.
		float m = moss * smoothstep(0.52, 0.72, fbm(v_pos * 0.9 + 3.1)) * (1.0 - smoothstep(0.0, 1.4, e));
		alb = mix(alb, moss_color.rgb * (0.7 + 0.6 * arm.r), clamp(m * 1.4, 0.0, 0.9));
		rough = mix(rough, 0.95, m);
		// Blood pools, darker and wet in the middle.
		float bp = fbm(vec3(v_pos.xz * 0.32, v_seed * 5.0));
		float b = blood * smoothstep(0.58, 0.66, bp) * (0.6 + 0.4 * ao);
		alb = mix(alb, blood_color.rgb * (0.6 + 0.8 * smoothstep(0.66, 0.8, bp)), clamp(b, 0.0, 0.92));
		rough = mix(rough, 0.12, b);
		// Puddled water in the low parts of the stone (wet look).
		rough = mix(rough, rough * 0.55, (1.0 - ao) * clamp(-roughness_bias * 3.0, 0.0, 1.0));
	} else if (!is_bottom) {
		float side_e = abs(n.x) > 0.5 ? v_half.z - abs(v_local.z) : v_half.x - abs(v_local.x);
		vec3 side_out = abs(n.x) > 0.5 ? vec3(0.0, 0.0, sign(v_local.z)) : vec3(sign(v_local.x), 0.0, 0.0);
		float top_rim = 1.0 - smoothstep(0.0, edge_width, below);
		float corner = 1.0 - smoothstep(0.0, edge_width, side_e);
		pn = normalize(mix(pn, normalize(n + vec3(0.0, 1.1, 0.0)), top_rim * 0.85));
		pn = normalize(mix(pn, normalize(n + side_out * 1.1), corner * 0.6));
		rim = max(top_rim, corner * 0.6);
		alb *= 1.0 + edge_light * rim * 0.8;
		// Moss and blood drip down from the rim.
		float streak = vnoise(vec3(v_pos.x * 3.1 + v_pos.z * 3.1, v_pos.y * 0.35, v_seed * 7.0));
		float m = moss * smoothstep(0.45, 0.8, streak) * (1.0 - smoothstep(0.1, 1.2 + streak, below));
		alb = mix(alb, moss_color.rgb * (0.6 + 0.6 * arm.r), clamp(m, 0.0, 0.85));
		float bd = blood * smoothstep(0.62, 0.75, vnoise(vec3((v_pos.x + v_pos.z) * 2.3, v_seed * 9.0, 1.0)))
				* (1.0 - smoothstep(0.0, 0.6 + 1.6 * streak, below));
		alb = mix(alb, blood_color.rgb, clamp(bd * 0.9, 0.0, 0.9));
		rough = mix(rough, 0.2, bd);
		// Sink into the dark below.
		float fade = smoothstep(0.25, side_fade, below);
		alb *= mix(1.0, side_dark, fade);
		ao *= mix(1.0, 0.6, fade);
	} else {
		alb *= side_dark * 0.7;
	}

	// Collapse warning flash (collapsing slab).
	alb = mix(alb, flash.rgb, flash.a);

	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = arm.b;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(pn, 0.0)).xyz);
	vec3 glow = emission_color.rgb * (emission_rim * rim + emission_cracks * smoothstep(0.42, 0.12, ao));
	EMISSION = glow + flash.rgb * flash.a * 0.4;
}
