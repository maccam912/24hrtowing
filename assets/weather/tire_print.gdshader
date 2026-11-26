shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;
varying vec2 snow_at;
void vertex() {
	snow_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
}
void fragment() {
	float edge = abs(UV.x*2.0-1.0);
	float buffeted = sin(dot(snow_at,vec2(5.0,2.8))) * sin(dot(snow_at,vec2(2.4,-3.1)));
	float shoulder = 1.0-smoothstep(.71,1.00,edge+buffeted*.07);
	float overlap = smoothstep(0.0,.085,UV.y)*smoothstep(0.0,.085,1.0-UV.y);
	// Broken oblique tread blocks expose snow between the impressions.
	float tread = smoothstep(.23,.64,abs(sin((UV.y*7.0-edge*.55)*3.14159)));
	float groove = smoothstep(.38,.53,edge)*(1.0-smoothstep(.54,.70,edge));
	ALBEDO = mix(vec3(.16,.20,.24),vec3(.23,.27,.30),1.0-tread);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = shoulder*overlap*(.20+.24*tread+.16*groove+.05*buffeted);
}
