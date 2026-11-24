# 24 HR Towing

You run Brandt Towing & Recovery in Esker, Wisconsin. The county is under a tow ban. When Arlene calls, take the heavy wrecker out, find the car by its road and landmarks, and bring the paperwork home.

**[Download the Android APK](https://github.com/maccam912/24hrtowing/releases/latest/download/24HRTowing-Android.apk)** · [SHA-256 checksums](https://github.com/maccam912/24hrtowing/releases/latest/download/SHA256SUMS.txt) · [Past releases and desktop downloads](https://github.com/maccam912/24hrtowing/releases)

## Your first call

Start the engine. Tap **RADIO**, then **Take contract**, or press **R** on desktop. Arlene starts you with a nearby ditch pull. Listen for the road, the landmark and the side the car went off. Your first call might take you past St. Hedwig’s, the co-op or the ginseng frames.

The dash compass reads the direction the truck faces in both driving views. The paper route slip names the next turn and the road to take. If you pass a turn, it updates from the road you’re on. Tap **RADIO → Ask for directions** or press **T** to hear Arlene’s talk-in. Past the edge of her map, use the plat, fire numbers and your own pencil marks.

Pull over within cable reach and stop before getting out. Stand near the casualty to place a flare. The controls are on the **driver’s side toward the back of the wrecker**. Take the cable there, carry it to the bumper that faces the wrecker, and return to the panel. Hold the winch control and watch the needle. Let off when it climbs toward red. A straight pull is easier than a broadside one.

Ditch customers walk back to their cars and drive away after the pull. For a hazard tow, bring the axle up to the underlift and strap it. In the cab, look in a side mirror for the amber ends of the light bar on the towed car’s roof. The loaded truck needs more braking room.

Amber lights mark your drop on every haul. Inside the yard gate, ordinary tows go right to **STORAGE**. For the surveyor’s pickup, bear left toward the office and back the pickup into **EVIDENCE HOLD**. Stop and unhook at the wrecker’s left rear panel. Pull the wrecker clear, then lock the corner chain from the yard side.

To turn in either job, walk to the fax under the **OFFICE / FAX** sign and tap **USE** or press **E**. The receipt shows the slip number and filing status. Stow it and get back in the cab to take the next contract on the radio.

## Controls

| | Android, landscape | Desktop |
| --- | --- | --- |
| Drive | Hold either side of the wheel to steer. Hold the gas to accelerate or the brake to stop. To reverse, start a fresh press on the brake while stopped and hold it to back up. | WASD or arrows, Space or Shift to brake |
| Switch driving view | Tap **CAB VIEW** or **CHASE VIEW** beside pause | Press **C** |
| Look | Drag the open part of the screen | Mouse |
| Walk | Left thumb pad | WASD or arrows |
| Step out, enter, or handle equipment | EXIT CAB appears at a full stop. On foot, tap ENTER CAB or USE. | E |
| Operate the winch at its panel | Hold WINCH | Hold Space or F |
| Accept a call, contact dispatch, or ask directions | RADIO, then choose a response | R to answer or choose a case contact, T for directions |
| Plat book and current slip | PLAT or SLIP | M or J |
| Set down paper or pause | Stow or pause button, Android Back | Escape |

The first drive starts in chase view. Your chosen view returns when you get back in the truck or continue a saved route. Pull over for the full-size plat. Opening it while moving gives a small lap view. The truck and operator save automatically, including a line that's already attached. The operator guide and 30/60 fps setting are in the truck log.

## The county rotation

Arlene draws ditch pulls and checked hazards from seven sites. Every third slip settles the outstanding balance. Old slips and county faxes stay on the clipboard. The yard office sells tire chains and winch service.

There’s a white county pickup in the Section 3 turnout on Swamp Road. It stays there between calls. If something catches your eye, park, walk over and use **E** or **USE** to examine it. Your observations go in the plat book’s pencil notes. When you have something to report, the cab radio offers a response. **Keep me on rotation** accepts a paying job and leaves the case contact available.

<details>
<summary>Following the survey case</summary>

Read Unit 38’s door and follow the boot prints to the rod case inside the gate. Report both to Arlene. You can finish your current call, work other slips, or take Kowalski’s hold the next time you’re free. Sign her card and stow the tripod before rigging. Fit the dollies, tow the pickup to the evidence bay, and lock the chain before filing.

After custody is filed, unlock the bay, read Tou’s field book and copy his sketch to the plat. You can also leaf through the filed slips and choose **Clip for radio** on two carbon copies from the same Kolpack shoulder with different loaded mileage. Ask about the junction to arrange a look-see at N5104. Read the house number and the sedan’s windshield VIN, radio them in, then file the report at the yard. There’s a brass survey cap beyond the house. Ordinary work continues after the look-see.

</details>

## Build

Use Godot 4.7.2 and matching export templates. Install Git LFS before cloning, or run `git lfs pull` in an existing checkout. Open `project.godot` and run the project, or launch `godot --path .`.

```sh
python3 tools/run_tests.py --godot godot
mkdir -p build
godot --headless --export-release Linux build/24HRTowing.x86_64
```

For a local Android build, configure the Android SDK and JDK 17 in Godot, then run `godot --headless --export-debug Android build/24HRTowing-Android-debug.apk`. The project also includes Linux, Windows and macOS export presets.

## Releases

GitHub Actions tests each pushed revision. By default, each passing revision gets an Android release with a signed ARM APK and its SHA-256 checksum. Android version codes increase with the workflow run and commit position. When setting up a separate release repository, configure the encrypted Actions secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` for signing.

To include desktop downloads in future releases, set the GitHub Actions repository variable `ENABLE_DESKTOP_BUILDS` to `true` before pushing the next revision. The workflow then also exports Linux and Windows x86-64 packages and a universal, ad-hoc-signed macOS app, and checks that each launches on its own operating system. Earlier desktop packages are available in the [release history](https://github.com/maccam912/24hrtowing/releases).

## Assets

The game uses the bundled OFL copies of Overpass, IBM Plex Mono, Caveat, Architects Daughter, Public Sans and DSEG Classic. Licenses ship in `assets/ui/fonts/`. The material textures, touch-control artwork, evergreen sprite and Brandt sign were made with ImageGen. The title camera moves around the playable wrecker in the live county scene. The launcher icon is a still taken in Godot. The wrecker, vehicles, objects and township are built in Godot. The dash and gauges use original instrument artwork.

Dialogue appears as speaker-tagged subtitles with short electronic pulses synthesized in Godot. The sound effects are local audio files. To generate missing effects, run `python3 tools/generate_audio.py` with an ElevenLabs API key in the environment or a private `~/.config/24hrtowing/elevenlabs.key` file. The tool also recognizes the existing Home Twenty key location. ElevenLabs generation uses API credits. The reverse alarm and the rattle of loose street signs are synthesized locally and encoded with FFmpeg. The installed game plays offline.
