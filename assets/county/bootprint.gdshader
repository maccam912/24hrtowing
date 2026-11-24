shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_mix, depth_draw_never;

void fragment() {
	vec2 toe = (UV - vec2(0.5, 0.35)) / vec2(0.40, 0.34);
	vec2 heel = (UV - vec2(0.5, 0.80)) / vec2(0.32, 0.18);
	float edge = min(length(toe), length(heel));
	float sole = 1.0 - smoothstep(0.71, 1.10, edge);
	float tread = 0.92 + 0.08 * cos(UV.y * 40.0);
	ALBEDO = vec3(0.11, 0.14, 0.17);
	ALPHA = 0.63 * sole * tread;
	ROUGHNESS = 1.0;
}
