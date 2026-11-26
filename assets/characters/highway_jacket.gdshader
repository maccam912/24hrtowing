shader_type spatial;

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 coat_position;

void vertex() {
	coat_position = VERTEX;
}

void fragment() {
	vec3 cloth = texture(palette, UV).rgb;
	float torso = (1.0 - smoothstep(0.195, 0.218, abs(coat_position.x))) *
		step(0.04, coat_position.y) * (1.0 - smoothstep(0.50, 0.55, coat_position.y));
	float band = step(0.155, coat_position.y) * (1.0 - step(0.19, coat_position.y));
	float braces = 1.0 - smoothstep(0.016, 0.022, abs(abs(coat_position.x) - 0.12));
	vec3 vest = mix(vec3(0.78, 0.205, 0.031), vec3(0.76, 0.78, 0.60), max(band, braces));
	ALBEDO = mix(cloth, vest * (0.66 + cloth.r * 0.5), torso);
	ROUGHNESS = 0.93;
}
