#!/usr/bin/env bash
# Build AnyPS5 (relinker + system libraries) in the Ubuntu 24.04 container.
#   releases/build.sh            configure (first time) and build
# Source: ../upstream (with the port patches). Output: releases/build/ (never the source tree's build/).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../upstream" && pwd)"
IMAGE=anyps5-build:ubuntu24.04

podman image exists "$IMAGE" || podman build -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"

GIT_COMMON="$(cd "$SRC" && cd "$(git rev-parse --git-common-dir)" && pwd)"

podman run --rm --userns=keep-id \
    -v "$SRC:$SRC:Z" -v "$HERE:/out:Z" -v "$GIT_COMMON:$GIT_COMMON:ro,z" -e HOME=/tmp -e SRC="$SRC" \
    "$IMAGE" bash -c '
        set -euo pipefail
        git config --global --add safe.directory "*"
        git -C "$SRC/3rdparty/ffmpeg-core" rev-parse --short=12 HEAD > /dev/null || { echo "git cannot read the source tree inside the container"; exit 1; }
        [ -f /out/build/build.ninja ] || cmake -S "$SRC" -B /out/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
        cmake --build /out/build --parallel
        cmake --build /out/build --target libs --parallel
        echo "built: $(ls /out/build/core/libs/libs/*.prx | wc -l) libraries, relinker $(ls -la /out/build/core/relinker/relinker | awk "{print \$5}") bytes"
        echo "compiler: $(g++ --version | head -1)"
    '
