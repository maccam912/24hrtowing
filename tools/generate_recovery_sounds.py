"""Render the truck's recovery gear in mono using only the Python standard library."""
from array import array
import math
from pathlib import Path
import random
import sys
import wave

DEST = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 24000
TAU = math.tau


def sine(hz, t):
    return math.sin(hz * t * TAU)


def strike(t, at, decay):
    return math.exp(-(t - at) / decay) if at <= t else 0


def payout(t, low, band, bright):
    # A free spool breathes between the regularly passing strands.
    rotation = (.5 + .5 * sine(1.25, t)) ** 2
    teeth = max(0, sine(17.5, t + .0018 * sine(2.5, t))) ** 6
    return .18 * low + band * (.28 + .72 * rotation) + bright * (.06 + .55 * teeth) + .035 * sine(315, t)


def loaded_drum(t, low, band, bright):
    # Reduction gear, motor armature and high rope creaks as one layer tightens.
    gear = sine(51.5, t + .00043 * sine(1.5, t))
    teeth = sine(515, t + .00012 * sine(8.5, t))
    pinch = (.5 + .5 * sine(2.5, t)) ** 6
    strand = sine(803, t + .00016 * sine(17.5, t))
    return .21 * gear + .10 * sine(103, t) + .053 * teeth + .33 * low + band * (.24 + .49 * pinch) + pinch * (.052 * strand + .14 * bright)


def hydraulic(t, low, band, bright):
    # Low pump pulses under the higher whine of oil crossing the spool valve.
    pump = sine(67.5, t) + .54 * sine(135, t) + .24 * sine(270, t)
    valve = sine(1080, t + .000065 * sine(5, t))
    pressure = .85 + .15 * sine(1.25, t)
    return .19 * pump + pressure * (.037 * valve + .32 * band) + .57 * low + .065 * bright


def flare_burn(t, low, band, bright):
    sputter = (.5 + .5 * sine(6, t)) * (.5 + .5 * sine(17, t))
    return low * .15 + band * .80 + bright * (.36 + .57 * sputter)


def flare_strike(t, low, band, bright):
    scrape = strike(t, .018, .046) + .63 * strike(t, .085, .032)
    catch = max(0, min(1, (t - .123) * 45)) * math.exp(-max(0, t - .15) / .48)
    return scrape * (1.18 * bright + .26 * band) + catch * (.52 * low + .95 * band + .8 * bright)


def rope_slip(t, low, band, bright):
    scrape = strike(t, .012, .096) + .82 * strike(t, .087, .10)
    # The tight length of cable oscillates in several inharmonic modes.
    twang = strike(t, .072, .16)
    ring = sine(234, t) + .36 * sine(571, t) + .18 * sine(1021, t)
    return scrape * (.70 * band + .66 * bright) + twang * (.30 * ring + .41 * low)


def ratchet(t, low, band, bright):
    teeth = sum(strike(t, point, .010) for point in (.02, .054, .094, .139, .188, .239))
    click = strike(t, .315, .056)
    pawl = sine(1440, t) + .45 * sine(2420, t)
    return teeth * (.80 * bright + .16 * pawl) + click * (.68 * band + .33 * sine(410, t) + .26 * bright)


def shackle(t, low, band, bright):
    pin = strike(t, .016, .06)
    gate = strike(t, .127, .095)
    return pin * (.76 * bright + .35 * sine(1130, t)) + gate * (.47 * band + .33 * sine(624, t) + .15 * sine(1544, t))


def clutch(t, low, band, bright):
    return (strike(t, .01, .035) * (.92 * bright + .56 * low)
            + strike(t, .048, .08) * (.52 * sine(178, t) + .25 * sine(384, t) + .48 * band))


def valve(t, low, band, bright):
    clack = strike(t, .018, .035)
    oil = strike(t, .061, .19)
    return clack * (.74 * band + .56 * bright + .34 * sine(513, t)) + oil * (.58 * low + .32 * band + .21 * sine(227, t))


def bake(name, render, duration, loop, seed):
    rng = random.Random(seed)
    n = round(RATE * duration)
    samples = []
    lower = upper = 0.
    # Render extra for a wraparound crossfade on sustained machinery.
    count = n + (int(RATE*.055) if loop else 0)
    for i in range(count):
        white = rng.uniform(-1, 1)
        lower += .047 * (white - lower)
        upper += .285 * (white - upper)
        samples.append(render(i/RATE, lower, upper-lower, white-upper))
    if loop:
        overlap = count - n
        for i in range(overlap):
            mix = i / overlap
            samples[i] = samples[n+i] * (1-mix) + samples[i] * mix
    else:
        for i in range(n):
            samples[i] *= min(1., i / 50, (n-1-i) / (RATE * .055))
    samples = samples[:n]
    peak = max(abs(x) for x in samples)
    pcm = array("h", (round(x / peak * 27000) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(DEST / (name + ".wav")), "wb") as stream:
        stream.setparams((1, 2, RATE, n, "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())


if __name__ == "__main__":
    for i, (name, render, seconds, loop) in enumerate([
        ("rope_payout", payout, 2.4, True), ("drum_under_load", loaded_drum, 2., True),
        ("hydraulic_pump", hydraulic, 2.4, True), ("flare_burn", flare_burn, 2., True),
        ("flare_strike", flare_strike, 1.62, False), ("rope_slip", rope_slip, .83, False),
        ("strap_ratchet", ratchet, .63, False), ("shackle_pin", shackle, .68, False),
        ("drum_clutch", clutch, .40, False), ("hydraulic_valve", valve, .69, False),
    ]):
        bake(name, render, seconds, loop, 4112 + i * 799)
