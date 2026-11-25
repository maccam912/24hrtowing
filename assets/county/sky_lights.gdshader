shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(.77,1.,.89,1.);
void vertex() {
	// Face every camera independently, including the truck's live mirror cameras.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz),0.),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz),0.),
		vec4(INV_VIEW_MATRIX[2].xyz,0.),MODEL_MATRIX[3]);
}
void fragment() {
	float radius = length((UV-.5)*2.);
	float core = 1.-smoothstep(.07,.15,radius);
	float halo = exp(-5.3*radius) * (1.-smoothstep(.70,1.,radius));
	ALBEDO = mix(tint.rgb,vec3(1.),core*.84);
	ALPHA = min(1.,core+halo*.74)*tint.a;
}
