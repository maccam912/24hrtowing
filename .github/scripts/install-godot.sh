#!/usr/bin/env bash
set -euo pipefail

# The editor and selected export templates must come from the same release.
version=4.7.2
release="https://github.com/godotengine/godot-builds/releases/download/$version-stable"
cache="$HOME/.cache/24hrtowing/godot-$version"
templates="$HOME/.local/share/godot/export_templates/$version.stable"
mkdir -p "$cache" "$(dirname "$templates")"

fetch() {
    curl --fail --location --silent --show-error --retry 3 "$release/$1" -o "$RUNNER_TEMP/$1"
    echo "$2  $RUNNER_TEMP/$1" | sha256sum --check --status
}

if [[ ! -x "$cache/godot" ]]; then
    editor="Godot_v${version}-stable_linux.x86_64"
    fetch "$editor.zip" cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
    unzip -p "$RUNNER_TEMP/$editor.zip" "$editor" > "$cache/godot"
    chmod +x "$cache/godot"
fi
if [[ "${1:-}" == --export || "${1:-}" == --app-bundle ]]; then
    members=(templates/version.txt)
    if [[ "$1" == --app-bundle ]]; then
        members+=(templates/android_source.zip)
    else
        members+=(templates/android_{debug,release}.apk)
        if [[ "${ENABLE_DESKTOP_BUILDS:-}" == true ]]; then
            members+=(templates/linux_{debug,release}.x86_64 templates/windows_{debug,release}_x86_64{,_console}.exe templates/macos.zip)
        fi
    fi
    for member in "${members[@]}"; do
        [[ -s "$cache/$member" ]] && continue
        # Upstream distributes these templates together in one checksum-pinned archive.
        archive="Godot_v${version}-stable_export_templates.tpz"
        fetch "$archive" f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011
        unzip -qo "$RUNNER_TEMP/$archive" "${members[@]}" -d "$cache"
        break
    done
    ln -sfnT "$cache/templates" "$templates"
    # The hosted Linux runner is disposable. Use its installed SDK and selected JDK.
    settings="$HOME/.config/godot"
    mkdir -p "$settings"
    cat > "$settings/editor_settings-4.7.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS
fi
"$cache/godot" --version
echo "GODOT_BIN=$cache/godot" >> "$GITHUB_ENV"
