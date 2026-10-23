// Background world (DEC-055): the sea of blood-mist far below the courses, with ember glints.
// World-space UVs, so the plane can follow the camera without sliding.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 deep_color : source_color = vec4(0.05, 0.02, 0.03, 1.0);
uniform vec4 top_color : source_color = vec4(0.28, 0.08, 0.08, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.32, 0.08, 1.0);
uniform vec4 haze_color : source_color = vec4(0.12, 0.06, 0.08, 1.0);
uniform float scale = 0.0035;
uniform float drift = 0.006;
uniform float ember_amount = 1.0;
uniform float haze_end = 1600.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float a = texture(noise_tex, p * scale + vec2(TIME * drift, TIME * drift * 0.4)).r;
	float b = texture(noise_tex, p * scale * 3.1 - vec2(TIME * drift * 1.7, -TIME * drift)).r;
	float c = a * 0.65 + b * 0.35;
	vec3 col = mix(deep_color.rgb, top_color.rgb, smoothstep(0.35, 0.85, c));
	// Embers: small hot spots in the billows that pulse.
	float e = texture(noise_tex, p * scale * 9.0 + vec2(0.0, TIME * drift * 2.0)).r;
	float ember = smoothstep(0.74, 0.88, e) * smoothstep(0.4, 0.7, c);
	ember *= 0.6 + 0.4 * sin(TIME * 2.3 + p.x * 0.05 + p.y * 0.031);
	col += ember_color.rgb * ember * 2.4 * ember_amount;
	float d = length(wpos - CAMERA_POSITION_WORLD);
	col = mix(col, haze_color.rgb, smoothstep(150.0, haze_end, d) * 0.85);
	ALBEDO = col;
}
