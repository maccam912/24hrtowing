// Rectangle of the open-front part of the shop, supplied in world XZ.
uniform vec4 fuel_store_bounds;

bool inside_fuel_store(vec2 point) {
	return all(greaterThan(point, fuel_store_bounds.xy)) && all(lessThan(point, fuel_store_bounds.zw));
}
