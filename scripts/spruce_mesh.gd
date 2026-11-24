extends RefCounted
## One shared, root-centred spruce. Each strip follows a bough in the original
## 256 x 512 artwork. The three values are the row at the trunk, the row in
## the gap out by the tips, and the reach of the bough below that cut, in pixels.
const LEFT := [
	Vector3i(0,0,12), Vector3i(32,39,26), Vector3i(53,61,33),
	Vector3i(78,87,26), Vector3i(116,128,43), Vector3i(143,163,50),
	Vector3i(166,184,67), Vector3i(197,216,49), Vector3i(218,242,62),
	Vector3i(246,260,79), Vector3i(273,301,57), Vector3i(305,328,81),
	Vector3i(340,370,52), Vector3i(377,396,66), Vector3i(405,428,46),
	Vector3i(433,455,30), Vector3i(464,479,9), Vector3i(512,512,0),
]
const RIGHT := [
	Vector3i(0,0,15), Vector3i(36,45,22), Vector3i(63,81,45),
	Vector3i(96,113,30), Vector3i(118,129,49), Vector3i(145,163,46),
	Vector3i(173,195,32), Vector3i(200,214,58), Vector3i(227,245,53),
	Vector3i(251,268,51), Vector3i(278,296,86), Vector3i(314,349,52),
	Vector3i(345,361,78), Vector3i(376,398,47), Vector3i(412,430,43),
	Vector3i(441,455,32), Vector3i(465,480,9), Vector3i(512,512,0),
]

static func build(material: Material) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_material(material)
	var first := 0
	for arm in 4:
		var side := 1.0 if arm < 2 else -1.0
		var cuts := RIGHT if arm < 2 else LEFT
		var winding := [0, 2, 1, 1, 2, 3] if side > 0 else [0, 1, 2, 1, 3, 2]
		for tier in range(cuts.size() - 1):
			var top: Vector3i = cuts[tier]
			var bottom: Vector3i = cuts[tier + 1]
			var hinge := 1.0 - (top.x + bottom.x) * .5 / 512.0
			# Offset the tiers around the leader so adjoining sprays occupy different planes.
			var azimuth := arm * PI * .5 + .24 * sin(tier * 2.4 + arm)
			var outward := Vector3(cos(azimuth), 0, sin(azimuth))
			var normal := outward.cross(Vector3.UP) * side
			for reach: float in [0.0, top.z * .32, top.z * .68, top.z + 7.0]:
				var along := minf(reach / top.z, 1.0)
				for cut: Vector3i in [top, bottom]:
					# Use the same cut on adjoining boughs where they meet the trunk.
					var row := lerpf(cut.x, cut.y, minf(reach / 54.0, 1.0))
					var uv := Vector2((128.0 + side * reach) / 256.0, row / 512.0)
					var flex := smoothstep(.04, .96, along) * smoothstep(.04, .15, 1.0 - uv.y)
					mesh.set_uv(uv)
					mesh.set_uv2(Vector2(hinge, flex))
					mesh.set_normal(normal)
					mesh.add_vertex(outward * (reach * .48 / 256.0) + Vector3.UP * (1.0 - uv.y))
			for segment in 3:
				var corner := first + segment * 2
				for offset: int in winding:
					mesh.add_index(corner + offset)
			first += 8
	return mesh.commit()
