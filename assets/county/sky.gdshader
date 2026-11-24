shader_type sky;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2d(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
	vec3 d = EYEDIR;
	float up = max(0.,d.y);
	vec2 plane = d.xz / (up + .20);
	float clouds = .63 * noise2d(plane * vec2(1.2,2.7)) + .37 * noise2d(plane * 4.5);
	float bank = 1. - smoothstep(.07, .46, up);
	float town = pow(max(0.,dot(d,normalize(vec3(-1.,.06,.35)))),8.) +
		.55 * pow(max(0.,dot(d,normalize(vec3(1.,.06,.05)))),12.);
	vec3 overcast = mix(vec3(.017,.020,.026), vec3(.318,.332,.377), bank);
	COLOR = overcast + (clouds-.5) * vec3(.063,.066,.071) * (1. - .93 * bank) + vec3(.052,.023,.007) * bank * town;
}
