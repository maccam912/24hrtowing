shader_type spatial;
render_mode cull_disabled;

global uniform float storm_time;
global uniform float storm_gust;

void vertex() {
	// UV.x runs from insulator to insulator. UV.y selects the direction across
	// this span so cables running along the wind catch less of the gust.
	float free_span = 4.0 * UV.x * (1.0 - UV.x);
	float phase = storm_time * 1.7 - dot(VERTEX.xz, vec2(0.035, 0.009));
	float bow = free_span * (0.22 + storm_gust * 0.91) * (0.62 + 0.60 * sin(phase));
	VERTEX.xz += mix(vec2(0.0, 0.32), vec2(1.0, 0.0), UV.y) * bow;
	VERTEX.y += free_span * (0.04 + 0.19 * storm_gust) * sin(phase + 1.2);
}

void fragment() {
	ALBEDO = vec3(0.10, 0.12, 0.14);
	ROUGHNESS = 0.75;
}
