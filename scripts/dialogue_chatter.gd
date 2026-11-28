extends RefCounted

const MIX_RATE := 16000
const SPEAKER_HZ := {
	"DISPATCH": 420.0, "COUNTY PLOW": 245.0, "ANGIE": 365.0,
	"TOU": 223.0, "MAI": 395.0, "BEV": 296.0, "GARY": 195.0, "KOWALSKI": 285.0, "DRIVER": 325.0,
	"HIGHWAY BASE": 308.0, "COUNTY GARAGE": 205.0, "CAR FOUR": 375.0,
	"DUANE": 245.0, "DEPUTY PELZ": 263.0, "DEPUTY RUIZ": 337.0, "FREIGHT DRIVER": 214.0,
}
const RADIO_SPEAKERS := ["DISPATCH", "COUNTY PLOW", "HIGHWAY BASE", "COUNTY GARAGE", "CAR FOUR"]

static func render(speaker: String, text: String, on_radio := false) -> AudioStreamWAV:
	var radio := on_radio or speaker in RADIO_SPEAKERS
	var words := text.split(" ", false)
	var noise := RandomNumberGenerator.new()
	noise.seed = posmod(speaker.hash() * 31 + text.length() * 17, 100000) + 7
	var pcm := PackedByteArray()
	if radio:
		# Subtle VHF push-to-talk key-up click followed by a brief quiet carrier bed
		# so the squelch tail lands cleanly after a beat without musical beeps.
		var click_frames := roundi(0.036 * MIX_RATE)
		var carrier_seconds := clampf(0.42 + words.size() * 0.035, 0.50, 1.15)
		var total_frames := click_frames + roundi(carrier_seconds * MIX_RATE)
		pcm.resize(total_frames * 2)
		var lp := 0.0
		var click_hz: float = lerpf(920.0, 1340.0, clampf((float(SPEAKER_HZ.get(speaker, 320.0)) - 195.0) / 225.0, 0.0, 1.0))
		for i in total_frames:
			var t := float(i) / MIX_RATE
			var sample := 0.0
			var raw := noise.randf_range(-1.0, 1.0)
			lp = lerpf(lp, raw, 0.28)
			if i < click_frames:
				var env := exp(-t * 140.0)
				var switch_pop := sin(t * TAU * click_hz) * exp(-t * 210.0) * 0.55
				var hiss := (raw - lp) * env * 0.42
				sample = (switch_pop + hiss) * 0.52
			else:
				var ct := float(i - click_frames) / MIX_RATE
				var fade := minf(1.0, minf(ct / 0.04, (carrier_seconds - ct) / 0.06))
				sample = lp * 0.018 * maxf(0.0, fade)
			pcm.encode_s16(i * 2, clampi(roundi(sample * 16000.0), -32000, 32000))
	else:
		# In-person lines stay quiet and unobtrusive: a soft single low cue.
		var frames := roundi(0.055 * MIX_RATE)
		pcm.resize(frames * 2)
		var lp := 0.0
		for i in frames:
			var t := float(i) / MIX_RATE
			lp = lerpf(lp, noise.randf_range(-1.0, 1.0), 0.14)
			var env := sin(PI * float(i) / maxf(1.0, float(frames - 1)))
			pcm.encode_s16(i * 2, clampi(roundi(lp * env * 2200.0), -32000, 32000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = pcm
	return stream

static func radio_pulse() -> AudioStreamWAV:
	# Low, even pulses in the receiver. The lights themselves have no sound.
	var pcm := PackedByteArray()
	var frames := roundi(2.4*MIX_RATE)
	var noise := RandomNumberGenerator.new()
	noise.seed = 38
	pcm.resize(frames*2)
	for i in frames:
		var t := float(i)/MIX_RATE
		var beat := pow(maxf(0,sin(t*TAU/1.2)),4)
		var wave := sin(t*TAU*176.0)*.38+sin(t*TAU*352.0)*.12+noise.randf_range(-.16,.16)
		pcm.encode_s16(i*2, roundi(15000.0*beat*wave))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream
