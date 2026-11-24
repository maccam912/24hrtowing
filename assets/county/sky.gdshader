shader_type sky;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2d(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
	vec3 d=EYEDIR;
	float up=max(0.,d.y);
	vec2 plane=d.xz/(up+0.18);
	float clouds=.58*noise2d(plane*1.6)+.28*noise2d(plane*3.3)+.14*noise2d(plane*7.1);
	float bank=exp(-7.*up);
	float glow=pow(max(0.,dot(d,normalize(vec3(-1.,.06,.35)))),5.)+
		.65*pow(max(0.,dot(d,normalize(vec3(1.,.06,.05)))),8.);
	vec3 night=mix(vec3(.018,.028,.053),vec3(.085,.107,.151),bank);
	COLOR=night+vec3(.15,.064,.017)*bank*glow*(.55+clouds)+vec3(.041,.045,.048)*(clouds-.18);
}
