extends RefCounted
## Brandt works nights. Elapsed shift time is spent only in the dark hours, so
## when the clock reaches dawn the next minute is that evening's dusk. Slips,
## custody cards, the scanner log and tape dates all read this one clock.

const START := 3*3600 + 14*60   # 03:14 on the opening night
const DAWN := 7*3600
const DUSK := 17*3600
const DAY := 24*3600
const NIGHT := DAY - (DUSK - DAWN)

## Wall-clock seconds since the shift opened. Time before the shift (a car the
## deputies checked hours earlier) is still read straight back from 03:14.
static func wall_seconds(elapsed: float) -> float:
	var first := float(DAWN - START)
	if elapsed < first:
		return elapsed
	var later := elapsed - first
	return first + (DUSK - DAWN) + floorf(later / NIGHT) * DAY + fmod(later, NIGHT)

static func label(elapsed: float) -> String:
	var minutes := floori((START + wall_seconds(elapsed)) / 60.0)
	return "%02d:%02d" % [posmod(floori(minutes / 60.0), 24), posmod(minutes, 60)]
