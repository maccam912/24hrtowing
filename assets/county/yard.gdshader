shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D asphalt : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D windpack : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 coordinates;
void vertex() { coordinates=(MODEL_MATRIX*vec4(VERTEX,1.)).xz; }
void fragment() {
	vec2 p=coordinates;
	vec3 packed=texture(windpack,p*.22).rgb;
	vec3 salt=texture(asphalt,p*vec2(.15,.145)).rgb;
	float breakup=texture(windpack,p*vec2(.024,.030)).r;
	float granular=texture(asphalt,p*.077).r;
	float lanes=exp(-abs(abs(p.y+64.+sin(p.x*.062)*1.4)-1.14)*.71);
	float snow_cover=clamp(.58 + breakup*.83+granular*.08 - lanes*.37, .35,.94);
	ALBEDO=mix(salt*vec3(.75,.79,.85),packed*vec3(.91,.94,.99),snow_cover);
	ROUGHNESS=.96;
}
