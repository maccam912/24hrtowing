shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.,.5,.17,1.);
void fragment() {
	float d=length((UV-.5)*2.);
	float inner=exp(-d*24.);
	float haze=exp(-d*5.)*(1.-smoothstep(.70,1.,d));
	ALBEDO=tint.rgb;
	ALPHA=(.55*inner+.18*haze)*tint.a;
}
