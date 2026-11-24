shader_type spatial;
render_mode cull_disabled, shadows_disabled;
void fragment() {
	vec2 p=UV;
	float a=abs(fract((p.x+p.y)*3.4)-.5);
	float b=abs(fract((p.x-p.y)*3.4)-.5);
	float wire=1.-smoothstep(.028,.074,min(a,b));
	ALBEDO=vec3(.30,.32,.34);
	ROUGHNESS=0.85;
	ALPHA=wire*.65;
}
