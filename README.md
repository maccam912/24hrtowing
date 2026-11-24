# 24 HR Towing

You run Brandt Towing & Recovery in Esker, Wisconsin. The county is under a tow ban. When Arlene calls, take the heavy wrecker out, find the car by its road and landmarks, and bring the paperwork home.

**[Download the Android APK](https://github.com/maccam912/24hrtowing/releases/latest/download/24HRTowing-Android.apk)** · [All desktop builds and checksums](https://github.com/maccam912/24hrtowing/releases/latest)

## Your first call

Start the engine and answer the county radio. Angie Kraemer is in the west ditch on County K, just past St. Hedwig’s. Turn right out of the yard, cross Main, and watch for the twin steeples. Arlene can repeat the directions. The plat book and clipboard are available from the cab.

Pull over within cable reach and stop before getting out. Stand near the casualty to place a flare. The controls are on the **driver’s side toward the back of the wrecker**. Take the cable there, carry it to the bumper that faces the wrecker, and return to the panel. Hold the winch control and watch the needle. Let off when it climbs toward red. A straight pull is easier than a broadside one.

Ditch customers drive away after the pull. For a hazard tow, bring the axle up to the underlift, strap it, and haul to the storage pad. The loaded truck needs more braking room. Lower the vehicle at the destination. File the slip at the fax outside the yard office, then call for another job.

## Controls

| | Android, landscape | Desktop |
| --- | --- | --- |
| Drive | Hold the left or right side of the wheel to steer. Hold the narrow gas pedal, wide brake pedal, or REV lever | WASD or arrows, Space or Shift to brake |
| Switch driving view | Tap **CAB VIEW** or **CHASE VIEW** beside pause | Press **C** |
| Look | Drag the open part of the screen | Mouse |
| Walk | Left thumb pad | WASD or arrows |
| Step out, enter, or handle equipment | EXIT CAB, ENTER CAB, or USE | E |
| Operate the winch at its panel | Hold WINCH | Hold Space or F |
| Accept a call or ask directions | RADIO, then the appropriate key | R to answer, T for directions |
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

For Android development, configure the SDK and JDK 17 in Godot, then use the Android preset. The release pipeline uses a dedicated signing key. Set the repository's encrypted Actions secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` when setting up a separate release repository.

Every pushed revision is tested and receives its own full release. Android version codes increase with the workflow run and commit position. The workflow checks the signed ARM APK, launches the Linux, Windows and universal macOS packages on their respective operating systems, and publishes SHA-256 sums. macOS downloads are ad-hoc signed.

## Assets

The game uses the bundled OFL copies of Overpass, IBM Plex Mono, Caveat, Architects Daughter, Public Sans and DSEG Classic. Licenses ship in `assets/ui/fonts/`. The material textures, touch-control artwork, evergreen sprite, Brandt sign, title art and launcher illustration were made with ImageGen. The wrecker, vehicles, objects and township are built in Godot. The dash and gauges use original instrument artwork.

The effects and spoken lines are local audio files. To generate missing cues, run `python3 tools/generate_audio.py` with an ElevenLabs API key in the environment or a private `~/.config/24hrtowing/elevenlabs.key` file. The tool also recognizes the existing Home Twenty key location. Generation uses API credits. The installed game plays offline.
