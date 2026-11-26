shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;
void fragment() {
	vec2 d = (UV - .5) * 2.;
	float radial = max(0.,1. - dot(d,d));
	// Looking at the nose or along the flank cannot reveal a tail lamp.
	vec3 rear = normalize((VIEW_MATRIX * vec4(MODEL_MATRIX[2].xyz,0.)).xyz);
	float angle = smoothstep(.02,.44,dot(rear,VIEW));
	ALBEDO = mix(vec3(.68,.055,.04),vec3(1.,.29,.11),pow(radial,10.));
	ALPHA = radial*radial*radial*.70*angle;
}
