extends RefCounted
## The radio label describes what Brandt saw. Arlene gives the disposition.
## For a recoverable vehicle, dispatch appends the actual ticket or equipment status.
const CATALOG := {
	"road_lights": ["Lights over the road", "Copy the lights over your road, Brandt. I'll log them. Leave them be."],
	"swamp_lights": ["Lights over the swamp", "Three over the swamp. I've got them in the log, Brandt. No action."],
	"pacing_lights": ["Lights pacing the truck", "Copy, lights keeping pace. Hold your course, Brandt."],
	"moving_moon": ["Glow behind the clouds", "Copy the glow moving across the clouds. Stay on your road."],
	"far_landing": ["Lights dropping into the trees", "Lights down beyond the treeline. I've marked it. Leave it there."],
	"mirror_follow": ["Lights in the mirror", "Copy the lights behind your load. Keep your eyes on the road ahead."],
	"streetlights_out": ["Streetlights going out", "One lamp after another on Main. I'll let the village know. Keep going."],
	"the_lift": ["Car lifting out of the ditch", "Copy, the taped car left the ditch. Leave the tape where it fell."],
	"yard_visit": ["Lights over the tow yard", "Lights over your storage stalls. I've got the time. Leave the cars where they are."],
	"snow_column": ["Column of light in the snow", "Copy the column out in the field. Stay on the road."],
	"overhead": ["Lights over the cab", "Right over the cab? I hear you, Brandt. Let them pass."],
	"angie_lights": ["Lights near Alder Cut", "Copy the lights up the cut. Leave them be, Brandt."],
	"set_down": ["Car being set down", "Copy, they put a car on the shoulder. Give it room to settle. Wait for its tow slip."],

	"woods_car": ["Car driving into the trees", "A car went straight into the timber. I've got the spot for the deputy. Stay on the road."],
	"empty_oncoming": ["Oncoming car", "A car passed you with nobody at the wheel. Copy, Brandt. Let it go."],
	"departing_car": ["Car driving away", "That's one of your ditch customers, Brandt. They're clear to drive home."],
	"released_pickup": ["County pickup driving away", "That's Tou in Thirty-eight. I've got his release here. He's clear to go."],
	"deer_line": ["Deer standing in a line", "Copy the line of deer. Give them room to clear."],
	"plow_stopped": ["Stopped county plow", "That's Duane. He's giving you room to go around. Leave him be."],
	"power_lines": ["Humming power lines", "Copy the wires humming. I'll pass it to the co-op. Stay clear of the poles."],
	"walker": ["Person walking off the road", "I'll give the deputy their last location. Keep the wrecker on the road."],
	"dry_road": ["Bare stretch of pavement", "Wet pavement in the snow, copy. Take it easy where the ice starts again."],
	"snow_roof": ["Gap in the snowfall", "Dry road under falling snow. I've marked the stretch. Watch the far end for ice."],

	"field_car": ["Upside-down car", "Copy, a car upside down out in the field."],
	"nose_car": ["Car standing on its nose", "A sedan balanced on its front bumper. I've got the spot."],
	"roof_car": ["Car on the co-op roof", "Copy, a car on the co-op roof."],
	"ice_car": ["Car out on the ice", "Copy, headlights out on the flowage. Keep the wrecker on shore."],
	"tree_car": ["Car up in the trees", "A car in the tamaracks. I've got that on the sheet."],
	"gate_car": ["Car at the yard gate", "A running car at your gate. That's not one of mine."],
	"shoulder_car": ["Running car on the shoulder", "Copy, the sedan they set down on the shoulder."],
	"walker_car": ["Abandoned shoulder car", "Copy the car the driver walked away from."],
	"roadside_tape": ["Taped roadside car", "That tape means a deputy checked it. Leave it until there's a tow order."],
	"green_circle": ["Circle of green grass", "Green grass in a snowfield. I've marked the spot, Brandt. Leave it alone."],
	"bare_ring": ["Bare ring in the snow", "Copy the ring of wet ground. Leave it undisturbed."],
	"survey_ring": ["Bare ring at the survey corner", "Bare ground at the Section Three corner. I've marked it. Keep the wrecker off that patch."],
	"farm_ring": ["Bare ring in the farm drive", "A bare circle in the Hoffmanns' drive. Copy. Leave it as you found it."],
	"tou_ring": ["Bare ring beyond the stakes", "Bare ground at the end of Alder Cut. Copy, Brandt. Leave the ring be."],
	"cow_ring": ["Cows standing in a circle", "Those are the Lindquists' heifers. Bev knows. Leave them be."],
	"empty_ditch": ["Empty ditch with tow tape", "Copy, the car's gone and the tape is still there. Leave it for the deputy."],
	"pressed_lines": ["Straight lines in the snow", "Copy the grooves across the field. Keep your tracks off them."],
	"yard_turned": ["Cars turned in the yard", "All your storage cars facing north. I've got it in the log. Leave them that way."],
	"woods_tracks": ["Tire tracks in the trees", "Tire tracks through that narrow gap. I'll give the deputy the location. Stay out of the timber."],
	"hoofprints": ["Straight line of hoofprints", "Copy the hoofprints. Let the snow cover them, Brandt."],
	"bootprints": ["Bootprints into the field", "Copy the tracks leaving the shoulder. Leave them for the deputy."],

	"the_calm": ["Wind suddenly stopping", "Wind quit all at once. I've got the time. Carry on, Brandt."],
	"green_flash": ["Green flash in the clouds", "Green flash, no thunder. Logged. You're clear to keep driving."],
	"warm_air": ["Sudden warm air", "Warm enough to thaw the windshield? Copy. Watch for ice when it chills again."],
	"thaw_glaze": ["Mirrors thawing and icing over", "Meltwater freezing on the truck. Copy. Take it slow on that stretch."],
	"snow_up": ["Snow rising from the field", "Snow going up. I heard you, Brandt. Leave the field alone."],
	"hanging_snow": ["Snow hanging in the air", "Flakes hanging still. I've got it written down. Ease through when you can see."],
	"storm_hole": ["Hole in the storm", "Copy the opening in the clouds. Stay on your route while it lasts."],
	"electrics_fade": ["Headlights and dash fading", "Copy the dim lights. Ease off until you can see the road again."],
	"compass_turns": ["Compass turning away from north", "Copy the compass swing. Use your road signs until it settles."],
	"radio_pulse": ["Pulse on the radio", "I hear you through the pulse, Brandt. Stay on this channel."],
	"missing_time": ["Missing time on the clock", "I've got the gap in my log too, Brandt. You're back on the air. Carry on."],
}

const FIELD_NOTES := {
	"field_car": "It's resting on the roof. I can see all four tires. No tracks in the snow leading up to it.",
	"nose_car": "I can see the whole underside. Only the front bumper touches the ground.",
	"roof_car": "I can see a set of headlights above the eaves. The car's sitting level on the co-op roof.",
	"ice_car": "From here I can see the headlights shining across the ice. I can't find any tracks from shore.",
	"tree_car": "I've got branches under all four wheels. The car's sitting level up there.",
	"gate_car": "It's square to my gate, lights on. I can't see anybody inside.",
	"shoulder_car": "It's sitting square on the shoulder. I can see its lights on the snow.",
	"walker_car": "The lights are still on. I can see right through the driver's window. Seat's empty.",
	"roadside_tape": "I can see the deputy's yellow tape on the car.",
	"green_circle": "I can see green grass and dandelions. Snow right up to the edge.",
	"bare_ring": "I can see steam coming off the wet ground. The snow stops in a circle all the way around.",
	"survey_ring": "There's wet ground around the survey cap. I can see a little rim of meltwater where the snow starts.",
	"farm_ring": "There's a round patch of wet earth in the drive. I can't see any tire marks going into it.",
	"tou_ring": "I've come past the last pair of stakes. The snow's melted in a circle here too.",
	"cow_ring": "I'm looking at the whole herd. Every heifer's standing with her nose toward the middle.",
	"empty_ditch": "I can see yellow tape lying on the ground. Bare patch where the car was.",
	"pressed_lines": "I count five straight grooves. Same distance between them all the way across.",
	"woods_tracks": "I can follow tire tracks between those trunks. I couldn't fit a car through the gap.",
	"hoofprints": "I can follow that line of hoofprints straight across the snow.",
	"bootprints": "I can make out bootprints heading away from the shoulder. They stop in the field.",
	"dry_road": "I can see bare pavement under my light. There's ice again past the end of this patch.",
	"snow_roof": "I can see snow sticking to the road at either end. This whole stretch between them is dry.",
	"yard_turned": "I'm looking down the row. Every car in my yard has its nose pointed north.",
}

static func label(kind: String) -> String:
	return CATALOG[kind][0]

static func reply(kind: String, stage: int) -> String:
	if stage >= 4 and kind in ["pacing_lights", "mirror_follow"]:
		return "Copy. They stay with your truck, Brandt. Keep driving."
	return CATALOG[kind][1]

static func inspection(kind: String) -> String:
	return FIELD_NOTES.get(kind, "")
