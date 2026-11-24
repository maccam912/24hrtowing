shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying float falloff;
uniform vec3 eye;
void vertex() {
	vec3 volume=vec3(33.,14.,33.);
	vec3 drift=vec3(-1.75,-3.8,.87)*(TIME+INSTANCE_CUSTOM.a*68.);
	vec3 pos=mod(INSTANCE_CUSTOM.rgb*volume+drift-eye+volume*.5,volume)-volume*.5;
	float distance_to_eye=length(pos);
	falloff=smoothstep(2.0,5.0,distance_to_eye)*(1.-smoothstep(13.,18.,distance_to_eye));
	vec3 center=eye+pos;
	vec3 right=INV_VIEW_MATRIX[0].xyz;
	vec3 tail=normalize(vec3(.38,1.,-.22));
	VERTEX=(VIEW_MATRIX*vec4(center + right*VERTEX.x + tail*VERTEX.y,1.)).xyz;
	POSITION=PROJECTION_MATRIX*vec4(VERTEX,1.);
}
void fragment() {
	float width=1.-abs(UV.x*2.-1.);
	float tip=1.-abs(UV.y*2.-1.);
	ALBEDO=vec3(.71,.76,.82);
	ALPHA=falloff*width*tip*.80;
}
