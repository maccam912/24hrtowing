shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/weather/headlamp.gdshaderinc"
#include "res://assets/weather/fuel_store.gdshaderinc"
#include "res://assets/weather/snow_roof.gdshaderinc"

uniform float storm_time;
uniform float storm_gust;
uniform float storm_travel;
uniform vec3 eye;
uniform sampler2D ground_surface : filter_linear, repeat_disable;
uniform sampler2D ground_axes : filter_linear, repeat_disable;
uniform vec2 ground_origin;
varying float density;
varying float lamp;
varying float filaments;

float ground_height(vec2 point) {
	vec2 metres = (point - ground_origin + .5) / float(textureSize(ground_axes, 0).x);
	float col = textureLod(ground_axes, vec2(metres.x, .25), 0.).r;
	float row = textureLod(ground_axes, vec2(metres.y, .75), 0.).r;
	return textureLod(ground_surface, vec2(col, row), 0.).r;
}

void vertex() {
	vec2 wind = normalize(vec2(1., .26));
	vec2 side = vec2(-wind.y, wind.x);
	vec2 field = vec2(68., 64.);
	float seed = INSTANCE_CUSTOM.a * 55.;
	float travel = storm_travel * (.34 + .28 * INSTANCE_CUSTOM.b);
	vec2 offset = mod(INSTANCE_CUSTOM.rg * field + wind * travel - eye.xz + field * .5, field) - field * .5;
	float along = UV.x - .5;
	float across = UV.y * 2. - 1.;
	float curl = sin(UV.x * 5.2 + seed + storm_time * .82);
	float curl_tip = sin(UV.x * 11. - seed - storm_time * 1.3);
	float half_width = .43 + .76 * INSTANCE_CUSTOM.r + .24 * storm_gust;
	float bend = .48 * curl + .12 * curl_tip;
	vec2 point = eye.xz + offset + wind * along * (8. + 10. * INSTANCE_CUSTOM.b) + side * (across * half_width + bend);
	float crest = (1. - across * across) * (.13 + .21 * storm_gust) * (.82 + .35 * curl);
	vec3 particle = vec3(point.x, ground_height(point) + .06 + crest, point.y);
	lamp = headlamp_scatter(particle);

	float radius = length(offset);
	float fade = 1. - smoothstep(22., 31., radius);
	float pulse = .54 + .46 * sin(seed + storm_time * (.61 + .2 * INSTANCE_CUSTOM.g));
	density = fade * mix(.19, .72, storm_gust) * (.36 + .64 * pulse) * (.88 + .32 * lamp);
	// The shop's west wall shelters the hold bay from the crosswind.
	if (point.x > -60. && point.x < -42. && point.y > -51. && point.y < -38.3) {
		density = 0.;
	}
	if (point.x > 440.8 && point.x < 449.2 && point.y > 321.0 && point.y < 331.1) { density = 0.; }
	if (inside_fuel_store(point)) { density = 0.; }
	filaments = seed - storm_time * 2.4;
	density *= falling_snow_at(point);
	VERTEX = (VIEW_MATRIX * vec4(particle, 1.)).xyz;
}

void fragment() {
	float taper = sin(UV.x * PI);
	float curved = UV.y + .13 * sin(UV.x * 8. + filaments);
	float skirt = 1. - smoothstep(.14, .51, abs(UV.y - .5));
	float braid = .56 + .26 * sin(curved * 13. + filaments) + .18 * sin(curved * 24. - UV.x * 7. + filaments);
	ALBEDO = mix(vec3(.64, .67, .71), vec3(.99, .94, .83), lamp);
	ALPHA = density * skirt * taper * taper * braid;
}
