shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

global uniform float storm_time;
global uniform float storm_gust;
uniform sampler2D needles : source_color, filter_linear_mipmap, repeat_disable;

void vertex() {
	vec2 wind = normalize(vec2(1., .26));
	vec3 root = MODEL_MATRIX[3].xyz;
	float height = length(MODEL_MATRIX[1].xyz);
	float phase = dot(root.xz, wind) * .15;
	float h = 1. - UV.y;
	float hinge = UV2.x;
	float flex = UV2.y;
	vec2 radial = VERTEX.xz - root.xz;
	float radius = length(radial);
	vec2 outward = radial / max(radius, .0001);
	vec2 tangent = vec2(-outward.y, outward.x);

	// Each bough turns downwind about its own attachment to the trunk.
	// The outer needles spring up and settle as the pressure fluctuates.
	float gust = storm_gust;
	float beat = storm_time * 2.7 - phase + 18. * hinge + dot(outward, vec2(2.4,1.6));
	float recoil = sin(beat) + .28 * sin(beat * 1.66 + hinge * 9.);
	float pitch = flex * ((.20 + .48 * gust) * recoil + .11 * gust);
	float yaw = flex * dot(tangent, wind) * (.26 + .43 * gust + (.19 + .32 * gust) * sin(beat - .75));
	float dy = VERTEX.y - (root.y + hinge * height);
	float cy = cos(yaw), sy = sin(yaw);
	vec2 swept = cy * outward + sy * tangent;
	NORMAL.xz = cy * NORMAL.xz + sy * vec2(-NORMAL.z, NORMAL.x);
	VERTEX.xz = root.xz + swept * (radius * cos(pitch) - dy * sin(pitch));
	VERTEX.y += radius * sin(pitch) + dy * (cos(pitch) - 1.);

	// Attached ends follow the leader; bough tips travel with their hinge.
	float attachment = mix(h, hinge, flex);
	float sway = sin(storm_time * 1.85 - phase - .64 * attachment);
	float lean = .07 + .20 * gust + (.054 + .116 * gust) * sway;
	float lever = height * attachment * attachment;
	VERTEX.xz += wind * lever * lean;
	VERTEX.y -= lever * lean * lean * .50;
}

void fragment() {
	vec4 foliage = texture(needles, UV);
	ALBEDO = foliage.rgb * vec3(0.87, 0.90, 0.92);
	ROUGHNESS = 0.94;
	ALPHA = foliage.a;
	ALPHA_SCISSOR_THRESHOLD = 0.43;
}
