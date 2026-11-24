"""Generate missing offline ElevenLabs effects and radio lines. Credentials stay on the build host."""
import argparse
import json
import os
from pathlib import Path
import stat
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets/audio"
EFFECTS = {
    "sodium": (4, True, "Field recording up close beneath one old orange high-pressure sodium street lamp. Low grainy electrical ballast buzz steady around 120 Hz, slightly rattly with very soft upper harmonics, no wind, voices or other sounds."),
    "mercury": (4, True, "Quiet isolated electrical hum of an old mercury-vapor yard light ballast, a precise narrow slightly higher resonant ringing hum with a faint mains undertone, completely steady. No voices, music or environmental sounds."),
    "diesel": (6, True, "Steady low idle in the cab of a 1990s American class eight diesel tow truck. Soft deep six cylinder vibration and individually audible diesel knocks. No acceleration, voices or music."),
    "wind": (9, True, "Field recording of dry snow hissing across a windy empty Wisconsin road. Open air blizzard with a gentle ebb and swell. No whistling, music or speech."),
    "heater": (5, True, "Steady warm air from a truck dashboard heater, close fan bearings and a soft rush through a plastic grille. Isolated."),
    "winch": (5, True, "A hydraulic industrial tow truck winch hauling a cable under tension. Soft low PTO pump under a strained variable steel cable whirr. No other sounds."),
    "ratchet": (1.1, False, "Close cold steel recovery hook snapping onto a tow eye, two heavy chain clinks, brief quiet tail."),
    "fax": (2.5, False, "A 1990s office fax machine answering with a brief electronic handshake, thermal roller drawing out a short page. No speech."),
    "radio": (0.65, False, "An old county dispatch radio abruptly unkeying in a parked truck. One short squelch of analog static, cuts to quiet."),
    "door": (1, False, "Heavy metal truck cab door shut, a rubbery bass thump followed by a straight metal latch click."),
    "air_brake": (1.2, False, "One heavy truck air brake valve releasing outdoors in cold air, clean sharp pneumatic hiss."),
    "footstep": (0.65, False, "Single heavy insulated boot crunching packed cold snow. Quiet short squeak at the end."),
    "lift": (1.4, False, "A tow truck underlift hydraulic cylinder moving a short distance then a mechanical clunk at its stop."),
    "reverse": (0.55, False, "One isolated plain industrial reversing beep of a 1990s commercial truck.")
}
LINES = json.loads((AUDIO / "lines.json").read_text())
VOICES = {"DISPATCH": "EXAVITQu4vr4xnSDxMaL", "ANGIE": "XrExE9yKIg1WjnnlVkGX",
          "KOWALSKI": "Xb7hH8MSUJpSbSDYk0k2", "COUNTY PLOW": "onwK4e9ZLuTAKqWW03F9",
          "GARY": "nPczCjzI2devNBz1zQrb", "DRIVER": "TX3LPaxmHKxFdv7VOQHJ"}

def read_key():
    if os.getenv("ELEVENLABS_API_KEY"):
        return os.environ["ELEVENLABS_API_KEY"]
    for folder in ("24hrtowing", "home-twenty"):
        path = Path.home() / ".config" / folder / "elevenlabs.key"
        if path.exists():
            metadata = path.stat()
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid() or metadata.st_mode & 0o077:
                raise RuntimeError("Expected a private, owner-only ElevenLabs key file")
            return path.read_text().strip()
    raise RuntimeError("Set ELEVENLABS_API_KEY or configure a private elevenlabs.key")

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def generate(name, key):
    dst = AUDIO / (name + ".mp3")
    if dst.exists():
        return
    if name in EFFECTS:
        seconds, loop, prompt = EFFECTS[name]
        endpoint = "sound-generation"
        body = dict(text=prompt, duration_seconds=seconds, loop=loop, model_id="eleven_text_to_sound_v2")
    else:
        speaker, line = LINES[name]
        endpoint = "text-to-speech/" + VOICES[speaker]
        body = dict(text=line, model_id="eleven_multilingual_v2", voice_settings={"stability": 0.65, "similarity_boost": 0.75})
    url = "https://api.elevenlabs.io/v1/" + endpoint + "?output_format=mp3_44100_128"
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.build_opener(NoRedirect()).open(req, timeout=120) as reply:
        audio = reply.read()
        if len(audio) < 512 or not (audio.startswith(b"ID3") or audio[0] == 255):
            raise ValueError("Invalid audio for " + name)
    tmp = dst.with_suffix(".part")
    tmp.write_bytes(audio)
    tmp.replace(dst)
    print("Generated", name, flush=True)

if __name__ == "__main__":
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("names", nargs="*")
    names = args.parse_args().names or list(EFFECTS) + list(LINES)
    key = read_key()
    for name in names:
        try:
            generate(name, key)
        except urllib.error.HTTPError as error:
            raise SystemExit(f"{name}: ElevenLabs returned HTTP {error.code}")
