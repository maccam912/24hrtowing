shader_type spatial;
uniform sampler2D palette : source_color, repeat_disable, filter_nearest;
uniform vec4 coat : source_color = vec4(0.22,0.36,0.41,1.0);
varying vec3 garment;
void vertex() {
	garment = VERTEX;
}
void fragment() {
	vec3 cloth = texture(palette,UV).rgb;
	float band = smoothstep(0.188,0.196,garment.y)*(1.0-smoothstep(0.227,0.235,garment.y));
	float piping = smoothstep(0.160,0.164,garment.y)*(1.0-smoothstep(0.173,0.179,garment.y));
	float tint = 0.77+0.33*cloth.r;
	ALBEDO = mix(coat.rgb*tint,vec3(0.68,0.73,0.69),band);
	ALBEDO = mix(ALBEDO,vec3(0.61,0.32,0.19),piping);
	ROUGHNESS = 0.89;
}
