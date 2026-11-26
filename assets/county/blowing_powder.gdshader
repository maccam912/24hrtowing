shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/weather/headlamp.gdshaderinc"
#include "res://assets/weather/fuel_store.gdshaderinc"

uniform float storm_time;
uniform float storm_gust;
uniform float storm_travel;
uniform vec3 eye;
varying vec3 world_point;
varying float fade;
varying float seed;

float hash(vec2 p) {
	vec3 q = fract(p.xyx * vec3(.1031,.1030,.0973));
	q += dot(q, q.yzx + 19.19);
	return fract((q.x + q.y) * q.z);
}
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.), vec2(1.), fract(p));
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1)), f.x), f.y);
}

void vertex() {
	// Loose crystals travel in uneven clouds. A cloud intersects the beams in
	// world space, so the bright patch stays ahead of a turning or parked truck.
	vec3 volume = vec3(52.,15.,52.);
	seed = INSTANCE_CUSTOM.a;
	float travel = storm_travel * (.68 + .26 * seed);
	vec3 drift = vec3(travel, .48 * sin(storm_time * .54 + seed * 41.), .26 * travel);
	vec3 local = mod(INSTANCE_CUSTOM.rgb * volume + drift - eye + .5 * volume, volume) - .5 * volume;
	vec3 center = eye + local;
	float dist = length(local);
	fade = smoothstep(3.0, 6.0, dist) * (1. - smoothstep(17., 25., dist));
	// Let clouds dissolve before wrapping vertically when the operator moves.
	fade *= 1. - smoothstep(5.5, 7.5, abs(local.y));
	world_point = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x * (7. + 6. * seed)
		+ INV_VIEW_MATRIX[1].xyz * VERTEX.y * (1.9 + 1.8 * INSTANCE_CUSTOM.g);
	VERTEX = (VIEW_MATRIX * vec4(world_point,1.)).xyz;
}

void fragment() {
	vec2 p = UV * 2. - 1.;
	float soft_edge = max(0., 1. - dot(p,p));
	float noise = noise2d(UV * vec2(4.,2.) + vec2(seed * 63., storm_time*.18));
	float strands = noise2d(UV * vec2(10.,5.) + seed*31.);
	float plume = soft_edge * soft_edge * (.32 + .68 * noise) * (.65 + .35 * strands);
	bool sheltered = world_point.x > -60. && world_point.x < -42. && world_point.z > -51.
		&& world_point.z < -38.3 && world_point.y < 5.18;
	sheltered = sheltered || (world_point.x > 440.8 && world_point.x < 449.2 && world_point.z > 321.0 && world_point.z < 331.1 && world_point.y < 5.);
	sheltered = sheltered || (world_point.y < 4.2 && inside_fuel_store(world_point.xz));
	float light = headlamp_scatter(world_point);
	ALBEDO = mix(vec3(.59,.61,.66), vec3(.96,.92,.83), light);
	ALPHA = sheltered ? 0. : fade * plume * (.09 + .20 * storm_gust + light * (.36 + .29 * storm_gust));
}
