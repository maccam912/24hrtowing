shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, skip_vertex_transform;
#include "res://assets/weather/headlamp.gdshaderinc"
#include "res://assets/weather/fuel_store.gdshaderinc"

uniform float storm_time;
uniform float storm_gust;
uniform float storm_travel;
uniform vec3 eye;
uniform float calm;
uniform float hanging;
varying float opacity;
varying vec3 snow_color;

void vertex() {
	float grain = INSTANCE_CUSTOM.a;
	float strength = mix(.55, 1., storm_gust);
	// Small nearby grains and a deeper field of powder share one draw call.
	float outer = step(.54, grain);
	vec3 volume = mix(vec3(24., 10., 24.), vec3(60., 21., 60.), outer);
	float speed = .82 + .38 * INSTANCE_CUSTOM.b;
	float swirl = storm_time * 1.7 + grain * 47.;
	vec3 drift = vec3(storm_travel, -storm_time * (1.25 + grain), .26 * storm_travel) * speed;
	drift.yz += vec2(.15 * sin(swirl), .29 * cos(swirl * .72)) * (1. - calm);
	vec3 local = mod((INSTANCE_CUSTOM.rgb - .5) * volume + drift - eye + volume * .5, volume) - volume * .5;
	vec3 center = eye + local;
	float dist = length(local);
	float falloff = smoothstep(1.7, 3.5, dist) * (1.0 - smoothstep(.35, .49, dist / volume.x));
	falloff *= 1. - smoothstep(.40, .50, abs(local.y) / volume.y);
	bool bay = center.x > -60. && center.x < -42. && center.z > -51. && center.z < -38.3 && center.y < 5.18;
	bool pump = center.x > -76.6 && center.x < -65.4 && center.z > 12.5 && center.z < 19.5 && center.y < 4.45;
	bool kitchen = center.x > 440.8 && center.x < 449.2 && center.z > 321.0 && center.z < 331.1 && center.y < 5.;
	float light = headlamp_scatter(center);
	snow_color = mix(vec3(.62,.65,.70), vec3(1.,.95,.83), light);
	bool store = center.y < 4.2 && inside_fuel_store(center.xz);
	opacity = (bay || pump || kitchen || store) ? 0.0 : falloff * (.31 + .22 * strength + .47 * light);

	vec3 wind = normalize(mix(vec3(1., -.20 + .055 * sin(swirl), .26 + .08 * cos(swirl)), vec3(.001,-1.,0.), calm));
	vec3 sight = normalize(CAMERA_POSITION_WORLD - center + vec3(.0001));
	vec3 side = cross(wind, sight);
	side /= max(.025, length(side));
	float width = (.023 + .028 * INSTANCE_CUSTOM.g) * (1.0 + .65 * outer);
	float streak = (.14 + .27 * INSTANCE_CUSTOM.r) * (.6 + .65 * strength + .3 * light);
	streak = mix(streak, width * 1.3, hanging);
	vec3 point = center + side * VERTEX.x * width + wind * VERTEX.y * streak;
	VERTEX = (VIEW_MATRIX * vec4(point, 1.)).xyz;
}

void fragment() {
	vec2 p = (UV - .5) * 2.;
	float flake = max(0., 1. - p.x * p.x) * (1. - abs(p.y));
	ALBEDO = snow_color;
	ALPHA = opacity * flake;
}
