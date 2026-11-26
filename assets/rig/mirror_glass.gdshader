shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D rear_view : source_color, filter_linear;
uniform float frost : hint_range(0.0, 1.0);

void fragment() {
	vec3 reflection = texture(rear_view, vec2(1.0 - UV.x, UV.y)).rgb;
	vec2 gasket = min(UV, 1.0 - UV);
	float edge = min(gasket.x, gasket.y * 1.65);
	vec2 bits = floor(UV * vec2(73.0, 117.0));
	float grain = fract(sin(dot(bits, vec2(27.1, 113.5))) * 14263.31);
	float crystal = abs(sin(bits.y * 0.21 + 2.8 * sin(bits.x * 0.18)));
	float crust = frost * (1.0 - smoothstep(0.0, 0.001 + 0.25 * frost,
		edge + 0.023 * crystal + 0.02 * grain));
	vec3 salt = mix(vec3(0.36, 0.42, 0.46), vec3(0.76, 0.78, 0.75), grain * crystal);
	ALBEDO = mix(reflection, salt, 0.84 * crust);
}
