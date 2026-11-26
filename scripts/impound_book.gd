extends RefCounted
## The register stays with the yard. Carbon copies outlive the available stalls.
const PER_PAGE := 3
var cards: Array[Dictionary] = []
var leaf := 0

func open(stored: Array, slips: Array, front_count: int, west_count: int) -> void:
	cards.clear()
	leaf = 0
	var by_number := {}
	for slip: Dictionary in slips:
		by_number[int(slip.get("number",0))] = slip
	for i in range(stored.size()-1,-1,-1):
		var tag := record(stored[i],i,front_count,west_count)
		if by_number.has(int(tag.get("number",-1))):
			tag.merge(by_number[int(tag.number)])
		cards.append(tag)

static func record(entry: Variant, index: int, front_count: int, west_count: int) -> Dictionary:
	var card: Dictionary = entry.duplicate() if entry is Dictionary else {"route":entry}
	if index < front_count:
		card.stall = "FRONT  %02d" % (index+1)
	elif index < front_count+west_count:
		card.stall = "WEST  W-%02d" % (index-front_count+1)
	else:
		card.stall = "COUNTY OVERFLOW"
	return card

func turn(direction: int) -> void:
	leaf = clampi(leaf+direction,0,page_count()-1)

func page_count() -> int:
	return maxi(1,ceili(float(cards.size())/PER_PAGE))

func visible_cards() -> Array:
	return cards.slice(leaf*PER_PAGE,(leaf+1)*PER_PAGE)
