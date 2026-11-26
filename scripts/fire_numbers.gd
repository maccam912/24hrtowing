extends RefCounted
## The county plat measures one mile in 400 world units. A rural address advances every twenty feet.
const NUMBERS_PER_MILE := 264.0
const WORLD_MILE := 400.0
const SIGN_HEIGHT := 1.84
const PER_LEAF := 7
# Entries follow each road in driving order, with the physical roadside post as the survey station.
const PARCELS := {
	"frames":{"road":"County K","owner":"Duda Ginseng","at":Vector2(7.1,-213)},
	"brandt":{"road":"County K","owner":"Brandt Towing","at":Vector2(-7.1,-69)},
	"church":{"road":"County K","owner":"St. Hedwig’s","at":Vector2(7.1,65)},
	"angie":{"road":"County K","owner":"Parish cemetery","at":Vector2(-7.2,131)},
	"farm":{"road":"Kolpack Rd","owner":"Lindquist farm","at":Vector2(407.1,234)},
	"hoffmann":{"road":"Kolpack Rd","owner":"Hoffmann farm","at":Vector2(407.1,330)},
	"south_farm":{"road":"Kolpack Rd","owner":"Zielinski farm","at":Vector2(392.6,618)},
	"river_lanes":{"road":"Highway 64","owner":"River Lanes","at":Vector2(-562,7.2)},
	"bridge":{"road":"Highway 64","owner":"Dam landing","at":Vector2(-423,-7.1)},
	"coop":{"road":"Highway 64","owner":"Esker Co-op","at":Vector2(59,-7.1)},
	"county_seat":{"road":"Highway 64","owner":"County offices","at":Vector2(875,-7.1)},
	"dairy":{"road":"Hendricks Rd","owner":"Brzezinski Dairy","at":Vector2(105,407)},
	"ff_barn":{"road":"County FF","owner":"Witkowski Dairy","at":Vector2(792.9,339)},
	"alder":{"road":"Alder Cut Rd","owner":"Angie Kraemer","at":Vector2(448,-469)},
}

static func north_south(road: String) -> bool:
	return road in ["County K","Kolpack Rd","County FF","Alder Cut Rd"]

static func number(id: String) -> String:
	var row: Dictionary = PARCELS[id]
	var at: Vector2 = row.at
	var vertical := north_south(row.road)
	# Alder Cut keeps the township's existing N5420 assignment at the Kraemer lane.
	var origin := 5110.46 if row.road == "Alder Cut Rd" else (5322.0 if vertical else 1193.0)
	var station := at.y if vertical else at.x
	return "%s%04d" % ["N" if vertical else "W",roundi(origin-station*NUMBERS_PER_MILE/WORLD_MILE)]

static func post(county, id: String) -> Vector3:
	var at: Vector2 = PARCELS[id].at
	return Vector3(at.x,county.ground_height(at.x,at.y)+SIGN_HEIGHT,at.y)

static func lit_by(lamp: SpotLight3D, point: Vector3, reach: float) -> bool:
	if not lamp or not lamp.is_visible_in_tree() or lamp.light_energy < .65:
		return false
	var beam := point-lamp.global_position
	return beam.length() <= reach and beam.normalized().dot(-lamp.global_basis.z) > cos(deg_to_rad(lamp.spot_angle))

static func readable(rig, county) -> String:
	if rig.in_cab and not rig.is_stopped():
		return ""
	var eye: Camera3D = rig.get_camera()
	var player: Vector3 = rig.get_player_position()
	for id: String in PARCELS:
		var at: Vector2 = PARCELS[id].at
		if at.distance_squared_to(Vector2(player.x,player.z)) > 36.0*36.0:
			continue
		var plate := post(county,id)
		var sight := plate-eye.global_position
		if sight.length_squared() < .01 or sight.normalized().dot(-eye.global_basis.z) < .963:
			continue
		var normal := Vector3.BACK if north_south(PARCELS[id].road) else Vector3.RIGHT
		if absf(sight.normalized().dot(normal)) < .22:
			continue
		var distance := player.distance_to(plate)
		var visible := distance <= (10.0 if rig.in_cab else 7.0)
		if rig.in_cab and not visible:
			visible = lit_by(rig.body.search_beam,plate,36.0)
			if not visible:
				for lamp: SpotLight3D in rig.body.headlamps:
					if lit_by(lamp,plate,15.0):
						visible = true
						break
		if visible and rig._ray(eye.global_position,plate).is_empty():
			return id
	return ""
