shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float cold : hint_range(0, 1) = 0.0;

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.13, 311.75))) * 4375.545);
}

void fragment() {
	// Wind carries crystals into the windshield gasket, beyond the wiper sweep.
	float edge = min(min(UV.x, 1.0 - UV.x) * 1.75, min(UV.y, 1.0 - UV.y));
	vec2 crystal = UV * vec2(330., 206.);
	float dust = grain(floor(crystal));
	float ridge = pow(abs(sin(crystal.y * 1.4 + sin(crystal.x * .5))), 5.0);
	float irregular = .012 * sin(UV.x * 33.0) + .009 * sin(UV.y * 39.0);
	float frost = 1.0 - smoothstep(0., .026 + .075 * cold, edge + irregular);
	ALBEDO = mix(vec3(.23, .31, .34), vec3(.76, .81, .84), dust);
	ALPHA = .015 + frost * (.16 + .33 * dust + .15 * ridge);
}
