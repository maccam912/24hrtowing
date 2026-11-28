"""Test each pushed checkout and package successful builds separately."""
import json
import os
import re
import subprocess
import sys
import tarfile
import zipfile
from hashlib import sha256
from pathlib import Path


def run(args, cwd):
    subprocess.run([str(x) for x in args], cwd=cwd, check=True)


def android_version_code(index):
    run_number = int(os.environ["GITHUB_RUN_NUMBER"])
    code = run_number * 4096 + index
    if not 0 <= index < 4096 or not 0 < code <= 2_100_000_000:
        raise ValueError(f"Android version code out of range: {code}")
    return code


def stamp_android_version(presets, preset, code, version):
    # Keep original Godot serialization intact, including all other export presets.
    settings = presets.read_text()
    sections = re.split(r"(?m)^(\[preset\.\d+(?:\.options)?\])$", settings)
    for header, body in zip(sections[1::2], sections[2::2]):
        if not re.search(rf'(?m)^name="{re.escape(preset)}"$', body):
            continue
        options = sections.index(header[:-1] + ".options]") + 1
        body = sections[options]
        body, codes = re.subn(r"(?m)^version/code=\d+$", f"version/code={code}", body)
        body, names = re.subn(r'(?m)^version/name="([^"]*)"$',
                              lambda _: f'version/name="{version}"', body)
        if codes != 1 or names != 1:
            raise ValueError("Missing or duplicate version fields in the Android export preset")
        sections[options] = body
        presets.write_text("".join(sections))
        return
    raise ValueError(f"Missing {preset} export preset")


def export_release(checkout, preset, file, *options):
    run([os.environ["GODOT_BIN"], "--headless", *options, "--export-release", preset, file], checkout)
    if not file.exists() or file.stat().st_size < 100_000:
        raise ValueError(f"Incomplete {preset} export")


def package_desktops(checkout, binary_dir, output, version):
    presets = checkout / "export_presets.cfg"
    presets.write_text(re.sub(r'(?m)^application/(short_version|version)="[^"]+"$',
                              lambda m: f'application/{m[1]}="{version}"', presets.read_text()))
    linux = binary_dir / "24HRTowing.x86_64"
    windows = binary_dir / "24HRTowing.exe"
    mac = output / "24HRTowing-macOS.zip"
    for preset, file in [("Linux", linux), ("Windows", windows), ("macOS", mac)]:
        export_release(checkout, preset, file)
    linux.chmod(0o755)
    launched = subprocess.run([linux, "--headless", "--quit-after", "10"], cwd=binary_dir,
                              check=True, capture_output=True, text=True, timeout=90)
    log = launched.stdout + launched.stderr
    if "24 HR Towing | dispatch ready" not in log or re.search(r"^(SCRIPT ERROR|SHADER ERROR|ERROR|FATAL):", log, re.M):
        raise ValueError("Packaged Linux game failed to initialize: " + log)
    with zipfile.ZipFile(mac) as bundle:
        if not any(".app/Contents/MacOS/" in n and not n.endswith("/") for n in bundle.namelist()) or bundle.testzip():
            raise ValueError("Invalid macOS app bundle")
    with zipfile.ZipFile(output / "24HRTowing-Windows-x64.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        bundle.write(windows, windows.name)
    with tarfile.open(output / "24HRTowing-Linux-x64.tar.gz", "w:gz", compresslevel=6) as bundle:
        bundle.add(linux, arcname=linux.name)


def package(checkout, output, sha, index):
    output.mkdir(parents=True)
    # Keep the APK upgradeable and expose its source revision in Android settings.
    code = android_version_code(index)
    version = f"0.1.{code}"
    stamp_android_version(checkout / "export_presets.cfg", "Android", code, version)
    project = checkout / "project.godot"
    project.write_text(re.sub(r'(?m)^config/version="[^"]+"$', f'config/version="{version}"', project.read_text()))
    binary_dir = output.parent / f"{sha}-binaries"
    binary_dir.mkdir()
    apk = binary_dir / "24HRTowing-Android.apk"
    export_release(checkout, "Android", apk)
    tools = Path(os.environ["ANDROID_HOME"]) / "build-tools" / "36.0.0"
    run([tools / "apksigner", "verify", "--verbose", apk], checkout)
    metadata = subprocess.check_output([tools / "aapt", "dump", "badging", apk], text=True)
    if "dev.maccam912.towing24hr" not in metadata or f"versionCode='{code}'" not in metadata or "application-debuggable" in metadata:
        raise ValueError("Unexpected APK package, version code or debuggable flag")
    apk.rename(output / apk.name)
    if os.environ.get("ENABLE_DESKTOP_BUILDS") == "true":
        package_desktops(checkout, binary_dir, output, version)
        # Full releases historically include the signer's optional v4 sidecar.
        sidecar = apk.with_suffix(".apk.idsig")
        if sidecar.is_file():
            sidecar.rename(output / sidecar.name)
    write_checksums(output)


def package_bundle(checkout, output, index):
    output.mkdir(parents=True)
    code = android_version_code(index)
    project = (checkout / "project.godot").read_text()
    project_version = re.search(r'(?m)^config/version="([^"]+)"$', project)
    if project_version is None:
        raise ValueError("Missing config/version in project.godot")
    version = project_version[1]
    stamp_android_version(checkout / "export_presets.cfg", "Google Play", code, version)
    bundle = output / "24HRTowing-Android.aab"
    export_release(checkout, "Google Play", bundle, "--install-android-build-template")
    java = Path(os.environ["JAVA_HOME"]) / "bin"
    verification = subprocess.check_output([
        java / "jarsigner", "-J-Duser.language=en", "-J-Duser.country=US", "-verify", bundle,
    ], text=True)
    if not re.search(r"(?m)^jar verified\.$", verification):
        raise ValueError("Android App Bundle signature did not verify")

    bundletool = [java / "java", "-jar", os.environ["BUNDLETOOL_JAR"]]
    bundle_arg = f"--bundle={bundle}"
    subprocess.run([*bundletool, "validate", bundle_arg], check=True, stdout=subprocess.DEVNULL)
    config = subprocess.check_output([*bundletool, "dump", "config", bundle_arg], text=True)
    if "PAGE_ALIGNMENT_16K" not in config:
        raise ValueError("Android App Bundle does not declare 16 KB page alignment")
    manifest = [*bundletool, "dump", "manifest", bundle_arg, "--module=base"]
    for attribute, expected in {
        "/manifest/@package": "dev.maccam912.towing24hr",
        "/manifest/@android:versionCode": str(code),
        "/manifest/@android:versionName": version,
        "/manifest/uses-sdk/@android:targetSdkVersion": "36",
    }.items():
        actual = subprocess.check_output([*manifest, f"--xpath={attribute}"], text=True).strip()
        if actual != expected:
            raise ValueError(f"Android App Bundle {attribute}: expected {expected}, got {actual!r}")
    if subprocess.check_output([*manifest, "--xpath=/manifest/application/@android:debuggable"], text=True).strip() == "true":
        raise ValueError("Android App Bundle is debuggable")
    write_checksums(output)


def write_checksums(output):
    records = []
    for file in sorted(output.iterdir()):
        with file.open("rb") as asset:
            digest = sha256()
            for block in iter(lambda: asset.read(1024 * 1024), b""):
                digest.update(block)
        records.append(f"{digest.hexdigest()}  {file.name}")
    (output / "SHA256SUMS.txt").write_text("\n".join(records) + "\n")


def main():
    phase = sys.argv[1]
    workspace = Path.cwd()
    staging = Path(os.environ["RUNNER_TEMP"]) / "commit-builds"
    staging.mkdir(exist_ok=True)
    verified = staging / "tested"
    verified.mkdir(exist_ok=True)
    failed = []
    for commit in json.loads(os.environ["COMMIT_BATCH"]):
        sha = commit["sha"]
        checkout = staging / sha
        print(f"::group::{phase} {sha}", flush=True)
        try:
            if phase == "test":
                # Hydrate the detached revision too: some media may only exist
                # in intermediate commits of a multi-commit push.
                subprocess.run(["git", "worktree", "add", "--detach", checkout, sha],
                               cwd=workspace, env={**os.environ, "GIT_LFS_SKIP_SMUDGE": "1"}, check=True)
                run(["git", "lfs", "pull", "--include=", "--exclude=", "origin"], checkout)
                run(["git", "lfs", "fsck", sha], checkout)
                run([sys.executable, "tools/run_tests.py"], checkout)
                (verified / sha).touch()
            elif phase == "bundle" and (verified / sha).exists():
                package_bundle(checkout, workspace / "build" / "play-bundle", commit["index"])
            elif phase == "export" and (verified / sha).exists():
                output = staging / "packages" / sha
                package(checkout, output, sha, commit["index"])
                releases = workspace / "build" / "ci-releases"
                releases.mkdir(exist_ok=True, parents=True)
                output.rename(releases / sha)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(f"::error::{phase} failed for {sha}: {error}", flush=True)
            failed.append(sha)
        finally:
            print("::endgroup::", flush=True)
    return int(bool(failed))


if __name__ == "__main__":
    sys.exit(main())
