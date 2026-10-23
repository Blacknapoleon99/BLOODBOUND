shader_type spatial;
// BLOODBOUND modular gothic kit (DEC-056): modelled stones, mouldings, piers, grates
// (assets/models/kit/gothic_kit.glb) textured with the CC0 PBR scans by world-space triplanar
// mapping, so any non-uniform scale a piece gets from GothicKit still tiles at true metres.
// - Upward faces within `top_band` m of the block's top use the TOP set (flagstone / cobble),
//   everything else the SIDE set (masonry).
// - The block's top height and a random seed come per instance from MultiMesh custom data
//   (INSTANCE_CUSTOM.r / .g; .b = blood amount, so blood-soaked floors share the floor batch); single meshes (movers, slabs) use `top_local` instead.
// - Vertex colour (from Blender): r = cavity (mortar joints, recesses), g = glow mask (crack
//   cores, iron rims), b = bone mask (handholds), a = paving (1) or dressed trim (0: coping,
//   abacus, quoins keep the side stone even facing up).
// - Sides sink into darkness below the top; moss in crevices, blood pools on tops.
// Plain GLSL only: works in Compatibility (GL3.3) and Forward+.

uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float top_scale = 4.5;   // metres per texture tile (large: the modelled joints carry the pattern)
uniform float side_scale = 6.0;
uniform vec4 top_tint : source_color = vec4(1.0);
uniform vec4 side_tint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_bias = 0.0;
uniform float top_band = 0.3;
uniform float side_fade = 8.0;
uniform float side_dark = 0.2;
uniform float cavity_dark = 0.55;
uniform float moss = 0.35;
uniform vec4 moss_color : source_color = vec4(0.13, 0.16, 0.08, 1.0);
uniform float blood = 0.0;
uniform vec4 blood_color : source_color = vec4(0.22, 0.015, 0.01, 1.0);
uniform float variation = 0.22;
uniform vec4 bone_color : source_color = vec4(0.8, 0.74, 0.62, 1.0);
uniform bool use_custom = true;
uniform bool local_space = false;
uniform float top_local = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_glow = 0.0;
uniform float metal = 0.0;
uniform vec4 flash : source_color = vec4(0.6, 0.15, 0.1, 0.0);

varying vec3 v_pos;
varying vec3 v_wpos;
varying vec3 v_n;
varying float v_top;
varying float v_seed;
varying float v_blood;
varying vec4 v_col;

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
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wpos = w;
	v_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_pos = local_space ? w - origin : w;
	if (use_custom) {
		v_top = INSTANCE_CUSTOM.r;
		v_seed = INSTANCE_CUSTOM.g;
		v_blood = max(blood, INSTANCE_CUSTOM.b);
	} else {
		v_blood = blood;
		v_top = (MODEL_MATRIX * vec4(0.0, top_local, 0.0, 1.0)).y;
		v_seed = local_space ? 0.37 : hash13(floor(origin * 3.0) + 17.0);
	}
	v_col = COLOR;
}

void fragment() {
	vec3 n = normalize(v_n);
	vec3 wgt = pow(abs(n), vec3(6.0));
	wgt /= max(0.0001, wgt.x + wgt.y + wgt.z);
	float below = v_top - v_wpos.y;
	bool top_face = n.y > 0.55 && below < top_band && v_col.a > 0.5;

	vec2 uv_x = vec2(v_pos.z, -v_pos.y) / side_scale;
	vec2 uv_z = vec2(v_pos.x, -v_pos.y) / side_scale;
	vec2 uv_y = vec2(v_pos.x, -v_pos.z) / (top_face ? top_scale : side_scale);

	vec3 ax = texture(side_albedo, uv_x).rgb;
	vec3 az = texture(side_albedo, uv_z).rgb;
	vec3 rx = texture(side_arm, uv_x).rgb;
	vec3 rz = texture(side_arm, uv_z).rgb;
	vec2 nx = texture(side_normal, uv_x).xy * 2.0 - 1.0;
	vec2 nz = texture(side_normal, uv_z).xy * 2.0 - 1.0;
	vec3 ay;
	vec3 ry;
	vec2 ny;
	if (top_face) {
		ay = texture(top_albedo, uv_y).rgb * top_tint.rgb;
		ry = texture(top_arm, uv_y).rgb;
		ny = texture(top_normal, uv_y).xy * 2.0 - 1.0;
	} else {
		ay = texture(side_albedo, uv_y).rgb * side_tint.rgb;
		ry = texture(side_arm, uv_y).rgb;
		ny = texture(side_normal, uv_y).xy * 2.0 - 1.0;
	}
	ax *= side_tint.rgb;
	az *= side_tint.rgb;
	vec3 alb = ax * wgt.x + ay * wgt.y + az * wgt.z;
	vec3 arm = rx * wgt.x + ry * wgt.y + rz * wgt.z;
	// UDN-style triplanar normal blend.
	nx *= normal_strength;
	ny *= normal_strength;
	nz *= normal_strength;
	vec3 pn = normalize(n + vec3(0.0, nx.y, nx.x) * wgt.x + vec3(ny.x, 0.0, ny.y) * wgt.y + vec3(nz.x, nz.y, 0.0) * wgt.z);

	float rough = clamp(arm.g + roughness_bias, 0.04, 1.0);
	float ao = arm.r;
	float cav = clamp(v_col.r, 0.0, 1.0);

	// Large-scale variation and a per-block tone.
	float macro = fbm(v_wpos * 0.23 + v_seed * 13.0);
	alb *= 1.0 + variation * (macro * 2.0 - 1.0);
	alb *= mix(vec3(1.0), vec3(1.07, 0.96, 0.92), v_seed * variation * 3.0);
	// Mortar joints and recesses read darker.
	alb *= mix(cavity_dark, 1.0, cav);
	ao *= mix(0.5, 1.0, cav);

	if (top_face) {
		float m = moss * smoothstep(0.5, 0.72, fbm(v_wpos * 0.9 + 3.1)) * (1.15 - cav * 0.6);
		alb = mix(alb, moss_color.rgb * (0.7 + 0.6 * arm.r), clamp(m * 1.3, 0.0, 0.85));
		rough = mix(rough, 0.95, m);
		float bp = fbm(vec3(v_wpos.xz * 0.32, v_seed * 5.0));
		float b = v_blood * smoothstep(0.58, 0.66, bp) * (0.6 + 0.4 * ao);
		alb = mix(alb, blood_color.rgb * (0.6 + 0.8 * smoothstep(0.66, 0.8, bp)), clamp(b, 0.0, 0.92));
		rough = mix(rough, 0.12, b);
		rough = mix(rough, rough * 0.55, (1.0 - ao) * clamp(-roughness_bias * 3.0, 0.0, 1.0));
	} else {
		// Moss on ledges and in joints, blood drips from the top.
		float streak = vnoise(vec3(v_wpos.x * 3.1 + v_wpos.z * 3.1, v_wpos.y * 0.35, v_seed * 7.0));
		float m = moss * smoothstep(0.45, 0.8, streak) * (1.0 - smoothstep(0.1, 1.4 + streak, below));
		m = max(m, moss * smoothstep(0.3, 0.9, n.y) * smoothstep(0.45, 0.7, fbm(v_wpos * 1.3)));
		alb = mix(alb, moss_color.rgb * (0.6 + 0.6 * arm.r), clamp(m, 0.0, 0.85));
		float bd = v_blood * smoothstep(0.62, 0.75, vnoise(vec3((v_wpos.x + v_wpos.z) * 2.3, v_seed * 9.0, 1.0)))
				* (1.0 - smoothstep(0.0, 0.6 + 1.6 * streak, below));
		alb = mix(alb, blood_color.rgb, clamp(bd * 0.9, 0.0, 0.9));
		rough = mix(rough, 0.2, bd);
	}
	// Sink into the dark below the top (floating ruins over the void).
	float fade = smoothstep(0.3, side_fade, below);
	alb *= mix(1.0, side_dark, fade);
	ao *= mix(1.0, 0.6, fade);
	if (n.y < -0.5) {
		alb *= 0.6;
	}
	// Carved bone (handholds).
	float bone = clamp(v_col.b, 0.0, 1.0);
	float lum = dot(alb, vec3(0.3, 0.59, 0.11));
	alb = mix(alb, bone_color.rgb * (0.55 + 0.9 * lum / max(0.05, dot(side_tint.rgb, vec3(0.3, 0.59, 0.11)))), bone);

	alb = mix(alb, flash.rgb, flash.a);

	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal * arm.b;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	float glow = clamp(v_col.g, 0.0, 1.0);
	EMISSION = emission_color.rgb * emission_glow * glow + bone_color.rgb * bone * 0.05 + flash.rgb * flash.a * 0.4;
}
