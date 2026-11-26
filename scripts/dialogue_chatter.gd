extends RefCounted

const MIX_RATE := 16000
const SPEAKER_HZ := {
	"DISPATCH": 420.0, "COUNTY PLOW": 245.0, "ANGIE": 365.0,
	"TOU": 223.0, "MAI": 395.0, "BEV": 296.0, "GARY": 195.0, "KOWALSKI": 285.0, "DRIVER": 325.0,
	"HIGHWAY BASE": 308.0, "COUNTY GARAGE": 205.0, "CAR FOUR": 375.0,
}

static func render(speaker: String, text: String) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var base_hz: float = SPEAKER_HZ.get(speaker, 320.0)
	var words := text.split(" ", false)
	for i in words.size():
		var word := words[i]
		var hz := base_hz * (0.92 + 0.035 * (word.hash() % 6))
		var duration := 0.038 + 0.005 * mini(word.length(), 8)
		# Long words break into two pulses. Punctuation leaves a breath between groups.
		if word.length() >= 6:
			_append_pulse(pcm, hz, duration * 0.70)
			pcm.resize(pcm.size() + 2 * roundi(0.014 * MIX_RATE))
		if word.ends_with("?"):
			hz *= 1.18
		elif word.ends_with("."):
			hz *= 0.86
		_append_pulse(pcm, hz, duration)
		if i < words.size() - 1:
			var gap := 0.105 if word.right(1) in [",", ".", "?", "!"] else 0.026
			pcm.resize(pcm.size() + 2 * roundi(gap * MIX_RATE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = pcm
	return stream

static func _append_pulse(pcm: PackedByteArray, hz: float, seconds: float) -> void:
	var start := pcm.size()
	var frames := roundi(seconds * MIX_RATE)
	pcm.resize(start + frames * 2)
	for i in frames:
		var phase := fmod(i * hz / MIX_RATE, 1.0)
		# A clipped triangle gives the square wave softer edges on a small speaker.
		var wave := clampf((1.0 - 4.0 * absf(phase - 0.5)) * 2.4, -1.0, 1.0)
		var envelope := minf(1.0, minf(i / (0.005 * MIX_RATE), (frames - 1 - i) / (0.012 * MIX_RATE)))
		pcm.encode_s16(start + i * 2, roundi(16000 * wave * envelope))

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
