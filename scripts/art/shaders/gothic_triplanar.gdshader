shader_type spatial;
// BLOODBOUND triplanar stone/iron for irregular meshes (DEC-054): the rubble under floating
// platforms, broken columns, iron fence spikes. World-space (or local) blended triplanar with
// UDN-blended normal maps; darkens toward the object's lowest point (`fade_*`, local Y).
// Plain GLSL only: works in Compatibility and Forward+.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 2.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_bias = 0.0;
uniform float fade_top = 0.0;      // local Y where the darkening starts
uniform float fade_bottom = -4.0;  // local Y where it is darkest
uniform float fade_dark = 0.15;
uniform float sharpness = 4.0;
uniform bool local_space = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 v_pos;
varying vec3 v_wn;
varying float v_y;

void vertex() {
	v_pos = local_space ? VERTEX : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = local_space ? NORMAL : normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_y = VERTEX.y;
}

void fragment() {
	vec3 wn = normalize(v_wn);
	vec3 w = pow(abs(wn), vec3(sharpness));
	w /= (w.x + w.y + w.z);
	vec3 p = v_pos / tex_scale;
	vec2 uvx = vec2(p.z, -p.y);
	vec2 uvy = vec2(p.x, -p.z);
	vec2 uvz = vec2(p.x, -p.y);
	vec3 alb = texture(albedo_tex, uvx).rgb * w.x + texture(albedo_tex, uvy).rgb * w.y + texture(albedo_tex, uvz).rgb * w.z;
	vec3 arm = texture(arm_tex, uvx).rgb * w.x + texture(arm_tex, uvy).rgb * w.y + texture(arm_tex, uvz).rgb * w.z;
	vec2 nx = (texture(normal_tex, uvx).xy * 2.0 - 1.0) * normal_strength;
	vec2 ny = (texture(normal_tex, uvy).xy * 2.0 - 1.0) * normal_strength;
	vec2 nz = (texture(normal_tex, uvz).xy * 2.0 - 1.0) * normal_strength;
	// UDN blend: each projection's tangent-space xy added along that plane's axes.
	vec3 pn = normalize(wn
			+ w.x * vec3(0.0, nx.y, nx.x)
			+ w.y * vec3(ny.x, 0.0, ny.y)
			+ w.z * vec3(nz.x, nz.y, 0.0));
	float fade = smoothstep(fade_top, fade_bottom, v_y);
	alb *= tint.rgb * mix(1.0, fade_dark, fade);
	ALBEDO = alb;
	ROUGHNESS = clamp(arm.g + roughness_bias, 0.04, 1.0);
	METALLIC = arm.b;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.35;
	vec3 vn = local_space ? (MODEL_MATRIX * vec4(pn, 0.0)).xyz : pn;
	NORMAL = normalize((VIEW_MATRIX * vec4(vn, 0.0)).xyz);
	EMISSION = emission_color.rgb;
}
