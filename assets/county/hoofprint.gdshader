shader_type spatial;
render_mode cull_disabled, blend_mix, shadows_disabled, depth_draw_never;

void fragment() {
	// The two toes converge at the front of the print. A little pushed-up snow
	// catches the light around the depression when the operator looks down.
	vec2 p = (UV - 0.5) * 2.0;
	vec2 toe = vec2((abs(p.x) - 0.32 + p.y * 0.13) / 0.26, p.y / 0.78);
	float edge = length(toe);
	float rim = 1.0 - smoothstep(0.83, 1.22, edge);
	float cut = 1.0 - smoothstep(0.58, 0.92, edge);
	ALBEDO = mix(vec3(0.57,0.61,0.64),vec3(0.14,0.17,0.19),cut);
	ALPHA = rim * 0.94;
	ROUGHNESS = 1.0;
}
