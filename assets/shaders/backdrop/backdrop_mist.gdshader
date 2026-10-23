// Background world (DEC-055): a thin, translucent, drifting mist layer between the courses and
// the blood sea (parallax between the two sells the depth of the abyss).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 mist_color : source_color = vec4(0.32, 0.12, 0.13, 1.0);
uniform float density = 0.4;
uniform float scale = 0.006;
uniform float drift = 0.01;
uniform float near_fade = 25.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float a = texture(noise_tex, p * scale + vec2(TIME * drift, 0.0)).r;
	float b = texture(noise_tex, p * scale * 2.3 + vec2(-TIME * drift * 0.6, TIME * drift * 0.5)).r;
	float m = smoothstep(0.42, 0.85, a * 0.6 + b * 0.4);
	float d = length(wpos - CAMERA_POSITION_WORLD);
	ALBEDO = mist_color.rgb * (0.7 + 0.5 * b);
	ALPHA = m * density * smoothstep(near_fade * 0.4, near_fade, d) * (1.0 - smoothstep(900.0, 1500.0, d));
}
