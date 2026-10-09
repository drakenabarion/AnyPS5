#!/usr/bin/env bash
# Assemble releases/build/ into an AppImage: releases/out/AnyPS5-<source>-<date>-x86_64.AppImage
# Run releases/build.sh first. The launcher is taken from releases/anyps5-launch.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../upstream" && pwd)"
IMAGE=anyps5-build:ubuntu24.04
[ -x "$HERE/build/core/relinker/relinker" ] || { echo "run build.sh first"; exit 1; }
[ -f "$HERE/anyps5-launch.sh" ] || { echo "anyps5-launch.sh missing in $HERE"; exit 1; }
[ -f "$HERE/VERSION" ] || { echo "releases/VERSION missing (e.g. 0.1.0)"; exit 1; }
RELEASE="$(tr -d '[:space:]' < "$HERE/VERSION")"
TARGET="$HERE/out/AnyPS5-$RELEASE-x86_64.AppImage"
[ ! -e "$TARGET" ] || { echo "out/AnyPS5-$RELEASE-x86_64.AppImage exists: raise the number in releases/VERSION (or delete that file to rebuild it)"; exit 1; }
VERSION="$RELEASE (upstream $(git -C "$SRC" rev-parse --short=8 HEAD)$(git -C "$SRC" diff --quiet || echo ' + port patches'), built $(date +%Y-%m-%d))"
GIT_COMMON="$(cd "$SRC" && cd "$(git rev-parse --git-common-dir)" && pwd)"

podman run --rm --userns=keep-id \
    -v "$SRC:$SRC:ro,Z" -v "$HERE:/out:Z" -v "$GIT_COMMON:$GIT_COMMON:ro,z" -e HOME=/tmp -e SRC="$SRC" -e VERSION="$VERSION" -e RELEASE="$RELEASE" \
    "$IMAGE" bash -c '
        set -euo pipefail
        tool=/out/tools/appimagetool-x86_64.AppImage
        if [ ! -x "$tool" ]; then
            mkdir -p /out/tools
            curl -sSfL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
            chmod +x "$tool"
        fi
        app=/out/AppDir
        rm -rf "$app" && mkdir -p "$app/bin" "$app/libs" "$app/usr/share/licenses"
        install -m 755 /out/anyps5-launch.sh "$app/AppRun"
        install -m 755 /out/build/core/relinker/relinker "$app/bin/relinker"
        install -m 644 /out/build/core/libs/libs/*.prx "$app/libs/"
        for f in "$SRC"/LICENSE* "$SRC"/COPYING*; do [ -f "$f" ] && install -m 644 "$f" "$app/usr/share/licenses/AnyPS5-$(basename "$f")"; done
        find "$SRC/3rdparty" -maxdepth 3 -type f \( -iname "LICENSE*" -o -iname "COPYING*" -o -iname "LICENCE*" \) | while read -r f; do
            rel="${f#$SRC/3rdparty/}"; install -m 644 "$f" "$app/usr/share/licenses/$(echo "$rel" | tr / _)"
        done
        find /out/build/externals -maxdepth 4 -type f \( -iname "LICENSE*" -o -iname "COPYING*" \) 2>/dev/null | while read -r f; do install -m 644 "$f" "$app/usr/share/licenses/ffmpeg_$(basename "$f")"; done
        cat > "$app/anyps5.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=AnyPS5
Comment=Run your own PS5 application dumps on Linux
Exec=AnyPS5
Icon=anyps5
Categories=Game;Emulator;
Terminal=false
DESKTOP
        cat > "$app/anyps5.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><rect width="256" height="256" rx="48" fill="#1d2a44"/><path d="M64 176 L128 64 L192 176 Z" fill="none" stroke="#7fb4ff" stroke-width="14" stroke-linejoin="round"/><circle cx="128" cy="142" r="18" fill="#7fb4ff"/></svg>
SVG
        ln -sf anyps5.svg "$app/.DirIcon"
        echo "$VERSION" > "$app/VERSION"
        mkdir -p /out/out
        cd /out/out
        APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 VERSION="$RELEASE" "$tool" --no-appstream "$app" "AnyPS5-$RELEASE-x86_64.AppImage" > /out/out/appimagetool.log 2>&1 || { tail -20 /out/out/appimagetool.log; exit 1; }
        echo "AppImage: out/AnyPS5-$RELEASE-x86_64.AppImage ($(du -h "AnyPS5-$RELEASE-x86_64.AppImage" | cut -f1)), $VERSION, licences: $(ls "$app/usr/share/licenses" | wc -l) files"
    '
