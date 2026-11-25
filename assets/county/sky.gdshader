shader_type sky;

uniform float opening;
uniform float glow;
uniform float passage;

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
	vec3 moving = normalize(vec3(mix(-.95,.95,passage),.48,-.25));
	COLOR += vec3(.48,.66,.58) * glow * pow(max(0.,dot(d,moving)), 9.) * (.45 + clouds);
	float rim = smoothstep(.65, .76, up + .13 * (clouds-.5));
	vec2 star_cell = d.xz / max(.23,up) * 166.;
	float star = step(.983, hash(floor(star_cell))) * (1.-smoothstep(.08,.27,length(fract(star_cell)-.5)));
	COLOR = mix(COLOR,vec3(.008,.013,.027) + star * vec3(.78,.88,1.),opening*rim);
}
