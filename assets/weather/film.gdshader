shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec3 scene = texture(TEXTURE, UV).rgb;
	vec2 center = UV * 2.0 - 1.0;
	float edge = smoothstep(0.43, 1.65, dot(center, center));
	vec2 grain_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float grain = fract(sin(dot(mod(grain_pixel, 173.0) + mod(floor(TIME * 15.0), 83.0), vec2(12.9898, 78.233))) * 4375.5453) - 0.5;
	COLOR = vec4(scene * (1.0 - 0.085 * edge) + grain * 0.012, 1.0);
}
