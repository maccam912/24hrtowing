shader_type spatial;

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec3 skin = texture(palette, UV).rgb;
	// Only the projected face occupies the upper-right quarter of the atlas.
	float exposure = step(UV.y, .499) * smoothstep(.872, .917, UV.x);
	ALBEDO = skin * mix(vec3(1.0), vec3(1.32, .64, .61), exposure);
	ROUGHNESS = .94;
}
