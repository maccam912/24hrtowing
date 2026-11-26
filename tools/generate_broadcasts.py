"""Render the original county radio programs with FluidSynth, FFmpeg, mido and piper-tts.

Pass a GeneralUser GS soundfont and Piper's US ljspeech-medium and bryce-medium voices.
The workstation needs these instruments and voices only when rendering new broadcasts.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import wave

from mido import Message, MetaMessage, MidiFile, MidiTrack, bpm2tempo
from piper import PiperVoice

AUDIO = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 32000
TICKS = 480


class Band:
    def __init__(self, bpm, patches):
        self.events = [(0, MetaMessage("set_tempo", tempo=bpm2tempo(bpm)))]
        for channel, (patch, volume, pan) in enumerate(patches):
            self.events.extend([
                (0, Message("program_change", channel=channel, program=patch)),
                (0, Message("control_change", channel=channel, control=7, value=volume)),
                (0, Message("control_change", channel=channel, control=10, value=pan)),
            ])

    def note(self, channel, key, start, length, velocity):
        self.events.extend([
            (round(start*TICKS), Message("note_on", channel=channel, note=key, velocity=velocity)),
            (round((start+length)*TICKS), Message("note_off", channel=channel, note=key)),
        ])

    def bend(self, channel, start, pitch):
        self.events.append((round(start*TICKS), Message("pitchwheel", channel=channel, pitch=pitch)))

    def save(self, path):
        song = MidiFile(ticks_per_beat=TICKS)
        track = MidiTrack()
        song.tracks.append(track)
        last = 0
        for tick, msg in sorted(self.events, key=lambda e: e[0]):
            track.append(msg.copy(time=tick-last))
            last = tick
        song.save(path)


# A turn around D and F sharp answers the upward leap in the first bar.
# Each row is a 2/4 bar of eighths. A zero ties the previous note.
POLKA_A = [
    ("D", [69,74,0,78]), ("D", [76,74,69,66]), ("G", [67,71,74,0]), ("A", [73,0,71,69]),
    ("D", [66,69,74,78]), ("G", [79,0,78,74]), ("A", [76,73,69,71]), ("D", [74,0,0,0]),
]
POLKA_B = [
    ("G", [79,0,83,81]), ("G", [79,74,71,74]), ("D", [78,0,81,79]), ("D", [78,74,69,0]),
    ("Em",[76,79,83,81]), ("Bm",[78,0,74,71]), ("E", [68,71,74,76]), ("A", [73,0,69,0]),
]
CHORDS = {
    "D": (38,[62,66,69]), "G": (43,[59,62,67]), "A": (45,[61,64,69]),
    "Bm": (47,[59,62,66]), "Em": (40,[59,64,67]), "E": (40,[59,64,68]),
    "C": (36,[60,64,67]), "F": (41,[57,60,65]), "Am": (45,[57,60,64]),
    "Dm": (38,[57,62,65]), "G7": (43,[59,62,65]),
}


def melody(band, channel, notes, start, step, velocity, transpose=0, legato=.90):
    index = 0
    while index < len(notes):
        key = notes[index]
        stop = index + 1
        while stop < len(notes) and notes[stop] == 0:
            stop += 1
        if key > 0:
            band.note(channel,key+transpose,start+index*step,(stop-index)*step*legato,velocity - 4*(index%2))
        index = stop


def farm_polka(path):
    # Accordion lead, tuba, reed chords and a clarinet answer on the second strain.
    band = Band(117, [(21,106,68),(58,90,52),(23,82,78),(71,89,48)])
    form = POLKA_A + POLKA_A + POLKA_B + POLKA_A + POLKA_B + POLKA_A
    for bar, (chord, notes) in enumerate(form):
        start = bar*2
        bass, triad = CHORDS[chord]
        final = bar == len(form)-1
        band.note(1,bass,start,.77 if final else .44,90)
        if not final:
            band.note(1,bass+7 if bass < 45 else bass-5,start+1,.38,78)
        for pulse in ([0] if final else [.50,1.51]):
            for k, key in enumerate(triad):
                band.note(2,key,start+pulse+k*.009,.71 if final else .19,73-3*k)
        melody(band,0,notes,start,.5,92 if bar%8 == 0 else 87)
        if 16 <= bar < 24 or 32 <= bar < 40:
            band.note(3,triad[1]+12,start+.07,.88,70)
            band.note(3,triad[0]+12,start+1.03,.81,65)
        elif bar%8 in (3,7) and not final:
            melody(band,3,[triad[1]+12,triad[2]+12],start+1,.5,66)
        if not final:
            band.note(9,36,start,.08,62)
            band.note(9,38,start+1.015,.10,57 if bar%4 < 3 else 68)
            for off in (.5,1.5):
                band.note(9,42,start+off,.05,45)
    band.save(path)


# Eighth-note grid in a slow waltz. A negative note leaves a breath.
COUNTRY_VERSE = [
    ("C", [67,0,0,0,64,67]), ("Am",[69,0,67,0,64,0]), ("F", [65,0,0,69,67,65]), ("C", [64,0,0,0,-1,60]),
    ("F", [65,0,69,0,72,0]), ("C", [67,0,0,64,62,60]), ("Dm",[62,0,65,0,69,0]), ("G7",[67,0,0,0,-1,65]),
]
COUNTRY_CHORUS = [
    ("C", [72,0,0,0,71,67]), ("G", [74,0,71,0,67,0]), ("Am",[76,0,0,72,71,69]), ("F", [69,0,0,0,65,67]),
    ("C", [72,0,67,0,64,0]), ("F", [65,0,69,0,67,65]), ("G7",[62,0,67,0,71,0]), ("C", [72,0,0,0,0,0]),
]


def river_lanes(path):
    # Clean electric pickup guitar, picked steel-string, acoustic bass, fiddle.
    band = Band(105, [(27,100,60),(25,90,76),(32,91,62),(40,77,48)])
    form = COUNTRY_VERSE + COUNTRY_CHORUS + COUNTRY_VERSE + COUNTRY_CHORUS
    for bar, (chord, notes) in enumerate(form):
        start = bar*3
        bass, triad = CHORDS[chord]
        final = bar == len(form)-1
        band.note(2,bass,start,2.55 if final else 1.52,81)
        if not final:
            band.note(2,bass+7 if bass <= 40 else bass-5,start+2.04,.67,65)
        for beat, accent in [(0,58),(1.02,69),(2.02,63)]:
            if final and beat: continue
            for k,key in enumerate(triad):
                band.note(1,key,start+beat+k*.027,1.40 if final else .48+(k*.04),accent-3*k)
        channel = 3 if 16 <= bar < 24 else 0
        if channel == 0 and bar%4 == 0:
            band.bend(0,start,-2000)
            band.bend(0,start+.075,-680)
            band.bend(0,start+.16,0)
        melody(band,channel,notes,start,.5,84,0,.96)
        if 8 <= bar < 16 or 24 <= bar < 32:
            band.note(3,triad[1]+12,start+.10,1.67,53)
            band.note(3,triad[0]+12,start+1.91,.90,50)
        elif bar%4 == 3 and not final:
            melody(band,1,[triad[0]+12,triad[1]+12],start+2,.5,63)
        if not final:
            band.note(9,36,start,.06,61)
            band.note(9,37,start+1.02,.11,63)
            band.note(9,42,start+2.03,.11,46)
    band.save(path)


FARM = [
    ("Farm report", "You're listening to seven sixty, Esker Farm Service. Good evening from the feed room."),
    ("Farm report", "Milk trucks are taking the county roads tonight. Brush the snow off your tank vent before the hauler gets there."),
    ("Dance hour", "The Thursday hall dance is on tape. Here's the Pine Row Trio with the Forty Acre Polka."),
    ("The Forty Acre Polka", None),
    ("Co-op desk", "Before we go back to the desk, the co-op has twine and salt by the west door. Bring your own shovel."),
]
COUNTRY = [
    ("Overnight country", "Ninety-nine seven. Tamarack Country. We keep the porch light on."),
    ("Sunday at River Lanes", None),
    ("Community calendar", "That's Sunday at River Lanes, by the Cedar Street Band. League bowlers, your score sheets are still at the counter."),
    ("Community calendar", "The west bridge supper is postponed. Keep the tickets. They'll take them whenever the kitchen opens again."),
]


def render_station(key, entries, writer, voice_path, soundfont, tmp, output):
    song = tmp / (key+".mid")
    writer(song)
    music = tmp / (key+"-music.wav")
    subprocess.run(["fluidsynth", "-ni", "-F", str(music), "-r", str(RATE), "-g", ".7", str(soundfont), str(song)], check=True)
    voice = PiperVoice.load(voice_path)
    mix = bytearray()
    cues = []
    for index, (label, words) in enumerate(entries):
        wav = music
        if words:
            wav = tmp / (key+"-"+str(index)+".wav")
            with wave.open(str(wav), "wb") as out:
                voice.synthesize_wav(words, out)
        # Match levels before the truck speaker's AM or FM band limit.
        eq = "highpass=f=175,lowpass=f=3700" if key == "am" else "highpass=f=100,lowpass=f=7300"
        level = -17 if words else -18.5
        pcm = subprocess.check_output(["ffmpeg","-v","error","-i",str(wav),"-af",
            f"silenceremove=start_periods=1:start_threshold=-60dB,{eq},loudnorm=I={level}:TP=-2.5:LRA=9",
            "-ac","1","-ar",str(RATE),"-f","s16le","pipe:1"])
        cues.append({"start":round(len(mix)/2/RATE,3), "label":label, "words":words or ""})
        mix.extend(pcm)
        mix.extend(bytes(2 * round(RATE * (.20 if words else .38))))
    subprocess.run(["ffmpeg","-v","error","-f","s16le","-ac","1","-ar",str(RATE),"-i","pipe:0",
                    "-c:a","libmp3lame","-b:a","64k","-y",str(output / ("broadcast_"+key+".mp3"))],input=mix,check=True)
    return {"duration":round(len(mix)/2/RATE,3),"cues":cues}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--soundfont", type=Path, required=True)
    parser.add_argument("--farm-voice", type=Path, required=True)
    parser.add_argument("--country-voice", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=AUDIO)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="county-air-") as work:
        programs = {}
        for key, entries, writer, voice in [("am",FARM,farm_polka,args.farm_voice), ("fm",COUNTRY,river_lanes,args.country_voice)]:
            programs[key] = render_station(key,entries,writer,voice,args.soundfont,Path(work),args.output)
        (args.output / "radio_programs.json").write_text(json.dumps(programs, indent=2, ensure_ascii=False)+"\n")


if __name__ == "__main__":
    main()
