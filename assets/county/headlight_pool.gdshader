shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

// Halogen headlights spill sideways and fade across the snow ahead of each car.
void fragment() {
	float lateral = abs(UV.x * 2.0 - 1.0);
	float wings = 1.0 - smoothstep(0.18, 1.0, lateral);
	float reach = 1.0 - smoothstep(0.12, 1.0, UV.y);
	ALBEDO = vec3(0.96, 0.77, 0.48);
	ALPHA = wings * reach * 0.88;
}
