shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, cull_disabled;
void fragment() {
	vec2 d = (UV - .5) * 2.;
	float radial = max(0., 1. - dot(d,d));
	vec3 nose = normalize((VIEW_MATRIX * vec4(MODEL_MATRIX[2].xyz,0.)).xyz);
	float face = smoothstep(.05,.69,dot(nose,VIEW));
	ALBEDO = mix(vec3(1.,.76,.43),vec3(1.,.96,.80),pow(radial,8.));
	ALPHA = face*pow(radial,3.)*.62;
}
