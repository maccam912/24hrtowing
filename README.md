# 24 HR Towing

You run Brandt Towing & Recovery in Esker, Wisconsin. The county is under a tow ban. When Arlene calls, take the heavy wrecker out, find the car by its road and landmarks, and bring the paperwork home.

**[Download the Android APK](https://github.com/maccam912/24hrtowing/releases/latest/download/24HRTowing-Android.apk)** · [SHA-256 checksums](https://github.com/maccam912/24hrtowing/releases/latest/download/SHA256SUMS.txt) · [Past releases and desktop downloads](https://github.com/maccam912/24hrtowing/releases)

## Your first call

Start the engine. Arlene has a contract waiting on the cab radio. Tap **RADIO**, then **Take contract**, or press **R** on desktop. Angie Kraemer is in the west ditch on County K, just past St. Hedwig’s. Turn right out of the yard, cross Main, and watch for the twin steeples. Arlene can repeat the directions. The plat book and clipboard are available from the cab.

Pull over within cable reach and stop before getting out. Stand near the casualty to place a flare. The controls are on the **driver’s side toward the back of the wrecker**. Take the cable there, carry it to the bumper that faces the wrecker, and return to the panel. Hold the winch control and watch the needle. Let off when it climbs toward red. A straight pull is easier than a broadside one.

Ditch customers walk back to their cars and drive away after the pull. For a hazard tow, bring the axle up to the underlift, strap it, and haul to the storage pad. In the cab, look in a side mirror for the amber ends of the light bar on the towed car’s roof. The loaded truck needs more braking room. On your first haul, amber lights mark the **TOW DROP** lane in the yard. Stop there and use the wrecker’s left rear panel to lower the car.

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
| Accept a call or ask directions | RADIO, then Take contract or Ask for directions | R to accept, T for directions |
| Plat book and current slip | PLAT or SLIP | M or J |
| Set down paper or pause | Stow or pause button, Android Back | Escape |

The first drive starts in chase view. Your chosen view returns when you get back in the truck or continue a saved route. Pull over for the full-size plat. Opening it while moving gives a small lap view. The truck and operator save automatically, including a line that's already attached. The operator guide and 30/60 fps setting are in the truck log.

## This release

The opening covers four ordinary recoveries and the first Act I evidence hold. The county includes the Brandt yard, Highway 64 and the bridge, the dairy grid, and the Swamp Road section corner. Survey evidence and older faxes can be inspected at your own pace. Ordinary calls continue after the hold. The account settles in batches. Tire chains and winch service can be ordered from the yard office.

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
