"""Bake four seamless, mono county sounds. Uses only the Python standard library."""
from array import array
import math
from pathlib import Path
import random
import sys
import wave

DEST = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 24000
DURATION = 8
TAU = math.tau


def sine(frequency, t):
    return math.sin(TAU * frequency * t)


def vacuum(t, low, mid, hiss):
    # Alternating teat-cup pulsators, with a short intake at each valve change.
    beat = t % 1
    intake = math.exp(-beat / .055) + .63 * math.exp(-((beat - .56) % 1) / .045)
    motor = .26 * sine(57.5, t) + .12 * sine(115, t) + .065 * sine(230, t)
    motor *= .88 + .12 * sine(1, t)
    return motor + low * .60 + mid * (.23 + 1.65 * intake) + hiss * (.025 + .68 * intake)


def spillway(t, low, mid, hiss):
    # Broad turbulent wash from the gates. High spray swells independently.
    swell = .82 + .11 * sine(.375, t) + .05 * sine(.625, t)
    spray = 1 + .16 * sine(.25, t) - .11 * sine(.875, t)
    return 1.95 * low * swell + .77 * mid * swell + .45 * hiss * spray


def furnace(t, low, mid, hiss):
    # Belt drive beneath the even roar of the heated bay's register.
    fan = .11 * sine(47.5, t) + .075 * sine(95, t) + .04 * sine(237.5, t)
    duct = (.93 + .07 * sine(.375, t)) * (low * 1.42 + mid * .68 + hiss * .11)
    return duct + fan


def cooler(t, low, mid, hiss):
    # Refrigerated case against the counter's back wall, faint loose fan grille.
    load = .88 + .08 * sine(.375, t) + .035 * sine(2, t)
    compressor = .20 * sine(59.5, t) + .16 * sine(119, t) + .07 * sine(178.5, t)
    grille = .038 * sine(418, t) * (.57 + .43 * sine(7, t))
    return load * (compressor + grille + low * .60 + mid * .21 + hiss * .045)


def bake(name, sound, seed):
    rng = random.Random(seed)
    sample_count = RATE * DURATION
    overlap = RATE // 2
    poles = [1 - math.exp(-TAU * cutoff / RATE) for cutoff in (100, 820, 4000)]
    bass = body = air = 0.0
    raw = array("f")
    for frame in range(sample_count + overlap):
        noise = rng.uniform(-1, 1)
        bass += (noise - bass) * poles[0]
        body += (noise - body) * poles[1]
        air += (noise - air) * poles[2]
        raw.append(sound(frame / RATE, bass, body - bass, air - body))
    # The second take at the head of the loop carries settled filter state.
    for i in range(overlap):
        fraction = i / overlap
        raw[i] = raw[i + sample_count] * (1 - fraction) + raw[i] * fraction
    del raw[sample_count:]
    rms = math.sqrt(sum(v*v for v in raw) / len(raw))
    gain = min(.23 / rms, .92 / max(abs(v) for v in raw))
    pcm = array("h", (round(v * gain * 32767) for v in raw))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(DEST / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, RATE, sample_count, "NONE", "not compressed"))
        out.writeframes(pcm.tobytes())



if __name__ == "__main__":
    for filename, generator, seed in [
        ("dairy_pump", vacuum, 431), ("dam_spillway", spillway, 99),
        ("bay_furnace", furnace, 38), ("store_cooler", cooler, 5104),
    ]:
        bake(filename, generator, seed)
