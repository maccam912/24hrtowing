shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec3 scene = texture(TEXTURE, UV).rgb;
	// Bright details trail slightly along the tube's horizontal sweep.
	vec3 previous = texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).rgb;
	scene += max(previous - scene, vec3(0.0)) * 0.12;

	// A scanline follows a row of source texels. Fade the pattern when the
	// output cannot resolve it so small windows don't develop moire bands.
	float rows_per_pixel = SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.y;
	float scan_strength = 1.0 - smoothstep(0.40, 0.65, rows_per_pixel);
	float row = UV.y / TEXTURE_PIXEL_SIZE.y;
	float luma = dot(scene, vec3(0.299, 0.587, 0.114));
	float beam = -cos(row * TAU) * mix(0.15, 0.07, luma);
	scene *= 1.0 + beam * scan_strength;

	vec2 center = UV * 2.0 - 1.0;
	float edge = smoothstep(0.43, 1.65, dot(center, center));
	vec2 grain_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float grain = fract(sin(dot(mod(grain_pixel, 173.0) + mod(floor(TIME * 15.0), 83.0), vec2(12.9898, 78.233))) * 4375.5453) - 0.5;
	COLOR = vec4(scene * (1.0 - 0.085 * edge) + grain * 0.012, 1.0);
}
