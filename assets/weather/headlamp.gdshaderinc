// The snow catches the same two low beams that skim the road surface.
global uniform vec3 headlamp_left;
global uniform vec3 headlamp_right;
global uniform vec3 headlamp_direction;
global uniform float headlamp_power;

float beam_scatter(vec3 offset) {
	float ahead = dot(offset, headlamp_direction);
	float radius = .15 + max(0.0, ahead) * .445; // tan(24 degrees)
	float off_axis = length(offset - ahead * headlamp_direction);
	return smoothstep(0.0, .6, ahead) * (1.0 - smoothstep(radius * .36, radius, off_axis))
		* (1.0 - smoothstep(12.0, 50.0, ahead));
}

float headlamp_scatter(vec3 world_position) {
	return headlamp_power * max(beam_scatter(world_position - headlamp_left), beam_scatter(world_position - headlamp_right));
}
