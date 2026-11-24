shader_type spatial;
render_mode cull_disabled;

global uniform float storm_time;
global uniform float storm_gust;
uniform sampler2D needles : source_color, filter_linear_mipmap, repeat_disable;

void vertex() {
	// The crossed cards are baked in county coordinates. A gust progresses from
	// the upwind edge of a grove through its neighbours; each trunk stays rooted.
	float along_wind = dot(VERTEX.xz, vec2(0.968, 0.252));
	float wave = sin(storm_time * 1.9 - along_wind * 0.16);
	float tremor = sin(storm_time * 4.7 - along_wind * 0.34 + VERTEX.y * 0.45);
	float height_on_tree = 1.0 - UV.y;
	float flex = height_on_tree * max(VERTEX.y, 0.0);
	float bend = flex * (0.030 + 0.018 * wave + storm_gust * (0.095 + 0.045 * wave + 0.012 * tremor));
	VERTEX.xz += vec2(0.968, 0.252) * bend;
	VERTEX.y -= abs(bend) * height_on_tree * 0.11;
}

void fragment() {
	vec4 foliage = texture(needles, UV);
	ALBEDO = foliage.rgb * vec3(0.87, 0.90, 0.92);
	ROUGHNESS = 0.94;
	ALPHA = foliage.a;
	ALPHA_SCISSOR_THRESHOLD = 0.43;
}
