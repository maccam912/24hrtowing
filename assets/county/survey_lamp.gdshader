shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

// The mercury arc is still a pin of light when the gate beneath it has
// disappeared in the ground fog. Trees still occlude the light.
void fragment() {
	float radius = length(UV - 0.5) * 2.0;
	float core = exp(-radius * radius * 48.0);
	float mist = exp(-radius * 5.0) * (1.0 - smoothstep(0.62, 1.0, radius));
	float reach = 1.0 - smoothstep(80.0, 130.0, length(VERTEX));
	ALBEDO = vec3(0.53, 0.90, 0.80);
	ALPHA = (0.81 * core + 0.22 * mist) * reach;
}
