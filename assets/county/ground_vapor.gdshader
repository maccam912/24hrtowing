shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;
uniform float seed = 0.;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz,0.),
		vec4(0.,1.,0.,0.),vec4(INV_VIEW_MATRIX[2].xyz,0.),MODEL_MATRIX[3]);
}
void fragment() {
	float lift = fract(TIME*.18+seed);
	vec2 p = UV * 2. - 1.;
	p.y += (lift-.5)*1.05;
	p.x += .24*sin(UV.y * 8.+seed*17.+TIME*.73);
	float wisps = .45+.55*pow(.5+.5*sin(p.x*21.+p.y*5.+TIME*.65),2.);
	float body = max(0.,1.-dot(p,p))*sin(lift*PI);
	ALBEDO = vec3(.67,.74,.73);
	ALPHA = body*body*wisps*.23;
}
