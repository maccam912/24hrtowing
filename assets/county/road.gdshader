shader_type spatial;
render_mode cull_disabled;
uniform sampler2D asphalt : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D windpack : source_color, repeat_enable, filter_linear_mipmap;

uniform vec4 dry_road_strip;
uniform float dry_road_half;
uniform float dry_road_freeze;
uniform vec4 snow_roof_strip;
uniform float snow_roof_half;
uniform float snow_roof_freeze;
varying vec2 county_at;

void vertex() {
	county_at = (MODEL_MATRIX * vec4(VERTEX,1.)).xz;
}

void thaw_strip(vec4 strip, float half_length, float freeze, vec3 asphalt_color, float grit, inout vec3 albedo, inout float roughness, inout float specular) {
	vec2 offset = county_at - strip.xy;
	float across = abs(dot(offset,vec2(-strip.w,strip.z)));
	float along = abs(dot(offset,strip.zw));
	float edge = 1. - smoothstep(3.8,4.6,across + (grit-.4)*.65);
	float mask = edge * (1. - smoothstep(half_length-3.,half_length,along));
	float ice = max(freeze,smoothstep(half_length-12.,half_length-3.,along));
	vec3 wet = asphalt_color * vec3(.40,.48,.55);
	vec3 glazed = mix(wet,vec3(.26,.34,.40),.47 + .37*grit);
	vec3 worn = mix(wet,glazed,ice);
	worn = mix(worn,albedo,smoothstep(.75,1.,freeze)*(.52+.25*grit));
	albedo = mix(albedo,worn,mask);
	roughness = mix(roughness,mix(.28,.19,ice),mask);
	specular = max(specular,mask*mix(.37,.52,ice));
}

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
	SPECULAR=0.;
	if (dry_road_half>0.) thaw_strip(dry_road_strip,dry_road_half,dry_road_freeze,pavement,band,ALBEDO,ROUGHNESS,SPECULAR);
	if (snow_roof_half>0.) thaw_strip(snow_roof_strip,snow_roof_half,snow_roof_freeze,pavement,band,ALBEDO,ROUGHNESS,SPECULAR);
}
