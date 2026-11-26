extends RefCounted

# The printed plat omits articles. Arlene uses them when she reads the location.
static func landmark(label: String) -> String:
	if label in ["ginseng frames","Lindquist place","river bridge","east road closure","River Lanes truck stop","west-side dairy barn","Tamarack county offices"]:
		return "the "+label
	return label

static func occupation(label: String) -> String:
	var article := "An " if label.left(1).to_lower() in ["a","e","i","o","u"] else "A "
	return article+label.to_lower()

# Expand printed road abbreviations for system voices. Keep the dispatch log as written.
static func read_aloud(words: String) -> String:
	return words.replace(" Rd"," Road").replace("St. Hedwig","Saint Hedwig").replace("County FF","County F F")

const PAGE_LENGTH := 112
var pages := PackedStringArray()
var ends_at := PackedFloat32Array()
var duration := 0.0

# Prefer a complete sentence or clause that fits two to three lines on the cab HUD.
func prepare(words: String) -> float:
	pages.clear()
	ends_at.clear()
	duration = 0.
	var rest := words.strip_edges()
	while rest.length() > PAGE_LENGTH:
		var cut := rest.rfind(" ",PAGE_LENGTH)
		if cut < 1: break
		var clause := 0
		var sentence := 0
		for i in range(1,cut+1):
			if rest[i] != " ": continue
			var mark := rest[i-1]
			if mark in [",",";"]: clause = i
			if mark in [".","?","!"] and not rest.substr(0,i).ends_with("St."):
				sentence = i
		if sentence >= 35: cut = sentence
		elif clause >= 45: cut = clause
		_append_page(rest.left(cut))
		rest = rest.substr(cut+1)
	if not rest.is_empty(): _append_page(rest)
	return duration

func _append_page(words: String) -> void:
	pages.append(words)
	duration += maxf(4.,1.0+words.length()/17.0)
	ends_at.append(duration)

func current(remaining: float) -> String:
	if remaining <= 0 or pages.is_empty(): return ""
	var elapsed := duration - remaining
	for page in range(pages.size()-1):
		if elapsed < ends_at[page]: return pages[page]
	return pages[-1]
