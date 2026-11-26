uniform vec4 roof_strip;
uniform vec2 roof_span; // half-length and strength

float falling_snow_at(vec2 at) {
	if (roof_span.y <= 0.) return 1.;
	vec2 offset = at - roof_strip.xy;
	float cross_lane = abs(dot(offset, vec2(-roof_strip.w, roof_strip.z)));
	float along = abs(dot(offset, roof_strip.zw));
	float covered = (1. - smoothstep(8., 10., cross_lane)) * (1. - smoothstep(roof_span.x - 3., roof_span.x, along));
	return 1. - covered * roof_span.y;
}
