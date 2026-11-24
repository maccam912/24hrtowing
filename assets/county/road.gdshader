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
	// Windpacks feather out across the crown. Traffic still cuts two dark ruts.
	float packed = smoothstep(.24, .53, wind + band * .12);
	float bank_edge = sin(UV.y * .37 + UV.x * .52 + 2.6 * sin(UV.y * .11));
	float tongue = smoothstep(.42, 1.0, bank_edge) * (.18 + packed * .17);
	float powder=clamp(.17 + verge*.78+grit+crown+packed*.36+tongue-ruts*(.31-.50*tongue),0.,1.);
	ALBEDO=mix(pavement*vec3(.75,.80,.88),snow*vec3(.82,.87,.93),powder);
	ROUGHNESS=.94;
}
