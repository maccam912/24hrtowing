extends SceneTree

const County := preload("res://scripts/county.gd")
const Directions := preload("res://scripts/road_directions.gd")

var failed := false

func check(words: String, expected: Array) -> void:
	for part: String in expected:
		if not words.to_lower().contains(part.to_lower()):
			failed = true
			printerr("Missing ‘", part, "’ in talk-in: ", words)

func _initialize() -> void:
	var county := County.new()
	county.add_child(county.drop_guide)
	var nav := Directions.new()
	var bridge := Vector2(-435, 6)
	nav.build(county.map_roads())
	check(nav.cue(Directions.DRIVEWAY, 90, bridge, "river bridge").instruction, ["yard gate", "right", "County K"])
	check(nav.cue(Directions.DRIVEWAY, 90, Vector2(314,-409), "Section 3").instruction, ["left", "north"])
	check(nav.cue(Vector2(0,-20), 180, bridge, "river bridge").instruction, ["right", "co-op", "Highway 64", "west"])
	check(nav.cue(Vector2(0,32), 180, bridge, "river bridge").instruction, ["turn around", "north"])
	check(nav.cue(Vector2(-480,0), 90, bridge, "river bridge").instruction, ["right shoulder"])
	check(nav.cue(Vector2(-160,50), 270, bridge, "river bridge").instruction, ["Highway 64", "north", "back to the road"])
	check(nav.cue(Vector2(10.54,-64), 90, bridge, "river bridge").instruction, ["County K", "west", "back to the road"])
	check(nav.cue(Vector2(0,-30), 0, Directions.DRIVEWAY, "Brandt yard").instruction, ["left", "Brandt sign"])
	check(nav.cue(Vector2(0,-95), 180, Directions.DRIVEWAY, "Brandt yard").instruction, ["right", "Brandt sign"])
	check(nav.driven_road(Vector2(423,336)), ["Hoffmann lane"])
	check(nav.driven_road(Vector2(441,-463)), ["Alder Cut"])
	if nav.driven_road(Vector2(441,-535)) != "":
		failed = true
		printerr("The old logging road beyond N5420 should stay off the modern map.")
	if nav.cue(Vector2(0,-20), 180, bridge, "river bridge").maneuver != "right" or nav.cue(Vector2(0,32), 180, bridge, "river bridge").maneuver != "around":
		failed = true
		printerr("Pencil arrows should match the spoken turn and turnaround.")
	check(nav.driven_road(Vector2(180,401)), ["Hendricks Rd"])
	county.free()
	if not failed:
		print("CHECKS PASSED — route notes at the gate, junctions, missed turns, shoulders and unprinted land")
	quit(int(failed))
