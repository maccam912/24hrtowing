shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D asphalt : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D windpack : source_color, repeat_enable, filter_linear_mipmap;

void fragment() {
	// UV is measured in metres across and along the carriageway.
	float crosslane=abs(UV.x);
	vec3 pavement=texture(asphalt,UV*vec2(.20,.12)).rgb;
	vec3 snow=texture(windpack,UV*.18).rgb;
	float wind=texture(windpack,vec2(UV.x*.032+UV.y*.011, UV.y*.046)).r;
	float band=texture(windpack,UV*vec2(.42,.013)).r;
	float verge=smoothstep(3.25,5.05,crosslane+(band-.33)*1.7);
	float grit=smoothstep(.22,.54,wind)*.23 + .038;
	float crown=(1.-smoothstep(.15,1.1,crosslane))*(.1+grit*.3);
	float ruts=1.-smoothstep(.14,.48, min(abs(crosslane-1.15),abs(crosslane-2.72)));
	float powder=clamp(verge*.90+grit+crown-ruts*.13,0.,1.);
	ALBEDO=mix(pavement*vec3(.75,.80,.88),snow*vec3(.82,.87,.93),powder);
	ROUGHNESS=.94;
}
