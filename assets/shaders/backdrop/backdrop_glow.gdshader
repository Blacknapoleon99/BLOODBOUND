// Background world (DEC-055): the glow of the blood sea on the horizon, a ring behind the
// mountains that backlights every far silhouette (additive, so it only brightens whatever sky
// the environment draws). Strongest toward the cathedral (+X).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, blend_add;

uniform vec4 glow_color : source_color = vec4(0.5, 0.09, 0.06, 1.0);
uniform float intensity = 1.0;
uniform float base_y = -140.0;
uniform float top_y = 520.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float t = clamp((lpos.y - base_y) / (top_y - base_y), 0.0, 1.0);
	float band = pow(1.0 - t, 2.6) * smoothstep(0.0, 0.06, t);
	vec2 dir = normalize(lpos.xz);
	float toward = 0.65 + 0.55 * max(dir.x, 0.0) + 0.12 * sin(atan(dir.y, dir.x) * 5.0 + TIME * 0.05);
	ALBEDO = glow_color.rgb * band * toward * intensity;
}
