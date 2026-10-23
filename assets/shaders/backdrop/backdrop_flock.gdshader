// Background world (DEC-055): crows/bats (MultiMesh). INSTANCE_CUSTOM.x is each bird's flap
// phase; wings flap by bending vertices with their distance from the body.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 body_color : source_color = vec4(0.02, 0.015, 0.02, 1.0);
uniform vec4 haze_color : source_color = vec4(0.12, 0.06, 0.08, 1.0);
uniform float flap_speed = 11.0;

varying vec3 wpos;

void vertex() {
	float s = sin(TIME * flap_speed + INSTANCE_CUSTOM.x * 6.2831);
	VERTEX.y += s * abs(VERTEX.x) * 0.75;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(wpos - CAMERA_POSITION_WORLD);
	ALBEDO = mix(body_color.rgb, haze_color.rgb, smoothstep(40.0, 700.0, d) * 0.8);
}
