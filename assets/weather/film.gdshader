shader_type canvas_item;
render_mode unshaded;

uniform float operator_frost : hint_range(0.0, 1.0) = 0.0;

float sample_ice(vec2 p) {
	vec3 h = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float rime(vec2 p) {
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec2 i = floor(p);
	return mix(mix(sample_ice(i), sample_ice(i + vec2(1.,0.)), f.x),
			mix(sample_ice(i + vec2(0.,1.)), sample_ice(i + vec2(1.)), f.x), f.y);
}

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
	if (operator_frost > 0.001) {
		vec2 margins = min(UV, 1.0 - UV);
		float rim = min(margins.x * 1.6, margins.y);
		if (rim < .09) {
			float patch = rime(grain_pixel * .035);
			float spurs = rime(grain_pixel * .19 + patch * 2.);
			float reach = (.011 + .061 * patch * patch + .014 * spurs) * operator_frost;
			float fringe = (1. - smoothstep(reach*.2, reach, rim)) * operator_frost;
			vec2 slant = vec2(grain_pixel.x*.79 + grain_pixel.y*.43, grain_pixel.y*.82 - grain_pixel.x*.51);
			float flecks = rime(slant * vec2(.24,.62));
			float ice = fringe * (.23 + .45 * smoothstep(.24,.78,flecks) + .12 * spurs);
			scene = mix(scene, vec3(.68, .76, .79), ice);
		}
	}
	COLOR = vec4(scene * (1.0 - 0.085 * edge) + grain * 0.012, 1.0);
}
