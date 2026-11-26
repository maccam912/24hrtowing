shader_type spatial;

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 cloth_position;

void vertex() {
	cloth_position = VERTEX;
}

void fragment() {
	vec3 original = texture(palette, UV).rgb;
	// Leave the folded mittens and scarf in their original fabric.
	float jacket = smoothstep(-0.05, 0.02, cloth_position.y) * (1.0 - smoothstep(0.51, 0.57, cloth_position.y));
	float warp = smoothstep(0.42, 0.48, fract((cloth_position.x + cloth_position.z * 0.55) * 15.0));
	float weft = smoothstep(0.42, 0.48, fract(cloth_position.y * 15.0));
	vec3 wool = mix(vec3(0.050, 0.036, 0.024), vec3(0.34, 0.105, 0.054), (warp + weft) * 0.5);
	ALBEDO = mix(original, wool * (0.7 + original.r), jacket);
	ROUGHNESS = 0.98;
}
