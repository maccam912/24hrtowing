shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;
varying float fade;
uniform vec3 eye;
void vertex() {
	vec2 extent=vec2(50.,46.);
	vec2 speed=vec2(-2.8,.92)*(.6+INSTANCE_CUSTOM.b);
	vec2 pos=mod(INSTANCE_CUSTOM.rg*extent+speed*TIME-eye.xz+extent*.5,extent)-extent*.5;
	float phase=sin(TIME*.59+INSTANCE_CUSTOM.a*50.)*.5+.5;
	fade=smoothstep(4.,9.,length(pos))*(1.-smoothstep(16.,27.,length(pos)))*phase;
	vec3 center=vec3(eye.x+pos.x,.33+INSTANCE_CUSTOM.b*.35,eye.z+pos.y);
	vec3 drift=normalize(vec3(-1.,0.,.33));
	// The two ends taper and break as the surface gust passes.
	vec3 pt=center+drift*(VERTEX.x*(.55+INSTANCE_CUSTOM.a)) + vec3(0.,VERTEX.y,0.);
	POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(pt,1.);
}
void fragment() {
	vec2 oval=(UV-vec2(.5,.48))*vec2(1.9,2.0);
	float cloud=max(0.,1.-dot(oval,oval));
	float streak=.55+.45*sin(13.*UV.x+sin(8.*UV.y+UV.x*5.));
	ALBEDO=vec3(.70,.75,.82);
	ALPHA=fade*cloud*cloud*streak*.085;
}
