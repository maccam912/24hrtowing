#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
failed=0
apk=24HRTowing-Android.apk
for directory in releases/*; do
    commit=$(basename "$directory")
    assets=("$directory/$apk" "$directory/SHA256SUMS.txt")
    platforms="Android (ARM)"
    if [[ ${ENABLE_DESKTOP_BUILDS:-false} == true ]]; then
        for os in macos windows; do
            receipt="$PWD/native-passes/$commit/$os.sha256"
            if [[ ! -s "$receipt" ]] || ! (cd "$directory" && sha256sum --strict --check "$receipt"); then
                echo "::error::Missing or mismatched $os startup verification for $commit"
                failed=1
                continue 2
            fi
        done
        assets=("$directory"/*)
        platforms="Android (ARM), Linux and Windows (x86-64), and macOS (Universal)"
    elif ! (cd "$directory" && sha256sum "$apk" | cmp -s - SHA256SUMS.txt); then
        echo "::error::Android APK checksum mismatch for $commit"
        failed=1
        continue
    fi
    index=$(jq -er --arg sha "$commit" '.[] | select(.sha == $sha) | .index' <<< "$COMMIT_BATCH")
    title="24 HR Towing · Build $GITHUB_RUN_NUMBER.$((index + 1))"
    tag="build-$commit"
    notes="Playable build of commit $commit for $platforms."
    # Keep one release per source commit, including on a later workflow dispatch.
    if details=$(gh release view "$tag" --json isDraft,assets); then
        if [[ $(jq -r '.isDraft' <<< "$details") == false ]]; then
            continue
        fi
        # A rerun can resume an unpublished draft created with desktop exports enabled.
        if [[ ${ENABLE_DESKTOP_BUILDS:-false} != true ]]; then
            while IFS= read -r asset; do
                case "$asset" in
                    24HRTowing-Linux-x64.tar.gz|24HRTowing-Windows-x64.zip|24HRTowing-macOS.zip|24HRTowing-Android.apk.idsig)
                        gh release delete-asset "$tag" "$asset" --yes ;;
                esac
            done < <(jq -r '.assets[].name' <<< "$details")
        fi
    else
        gh release create "$tag" --target "$commit" --draft --title "$title" --notes "$notes"
    fi
    gh release upload "$tag" "${assets[@]}" --clobber
    gh release edit "$tag" --title "$title" --notes "$notes" --draft=false --prerelease=false --latest=false
done
exit "$failed"
