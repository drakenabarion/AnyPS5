#!/usr/bin/env bash
# AnyPS5 launcher: run a PS5 application from the user's own dump.
#   anyps5-launch.sh [--data-dir DIR] [--reconvert] [DUMP_DIR [game arguments...]]
# Without DUMP_DIR, a game next to the AppImage (its own folder, or the single game folder beside
# it) starts directly, then the game chosen last time; only when neither exists does a folder picker
# ask for the game folder. This release is made for Quake (PPSA01881); other games get a warning.
#   anyps5-launch.sh --set-data-dir DIR
# DUMP_DIR is the folder containing eboot.bin, sce_module/, prx/ and sce_sys/param.json.
# Nothing is written into the dump. Per-game files live in <data dir>/<title ID>/.
set -euo pipefail

ROOT="${APPDIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
RELINKER="${ANYPS5_RELINKER:-$ROOT/bin/relinker}"
LIBS="${ANYPS5_LIBS:-$ROOT/libs}"
BESIDE="$(dirname "$(readlink -f "${APPIMAGE:-$0}")")"
PORTABLE="$BESIDE/AnyPS5 data"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/AnyPS5"
[ -d "$PORTABLE" ] && CONFIG_DIR="$PORTABLE"
CONFIG="$CONFIG_DIR/settings.conf"

fail() {
    echo "AnyPS5: $*" >&2
    if [ ! -t 2 ]; then
        if command -v kdialog > /dev/null; then kdialog --title AnyPS5 --error "$*" 2> /dev/null
        elif command -v zenity > /dev/null; then zenity --error --title AnyPS5 --text "$*" 2> /dev/null
        elif command -v notify-send > /dev/null; then notify-send AnyPS5 "$*"
        fi
    fi
    exit 1
}

trap 'fail "Unexpected error in the launcher (line $LINENO). Please report this together with the files in the game data folder."' ERR
gui() {
    if command -v kdialog > /dev/null; then echo kdialog
    elif command -v zenity > /dev/null; then echo zenity
    fi
}
ask_folder() {
    local title="$1" start="$2"
    case "$(gui)" in
        kdialog) kdialog --title AnyPS5 --getexistingdirectory "$start" 2> /dev/null ;;
        zenity) zenity --file-selection --directory --title "AnyPS5: $title" --filename "$start/" 2> /dev/null ;;
        *) [ -t 0 ] || return 1; read -r -p "$title [$start]: " answer; echo "${answer:-$start}" ;;
    esac
}
ask_ok_cancel() {
    case "$(gui)" in
        kdialog) kdialog --title AnyPS5 --yesno "$1" --yes-label OK --no-label Cancel 2> /dev/null ;;
        zenity) zenity --question --title AnyPS5 --text "$1" --ok-label OK --cancel-label Cancel 2> /dev/null ;;
        *) [ -t 0 ] || return 1; read -r -p "$1 [Enter to continue, n to cancel] " answer; [ "${answer,,}" != n ] ;;
    esac
}
ask_yes_no() {
    case "$(gui)" in
        kdialog) kdialog --title AnyPS5 --yesno "$1" 2> /dev/null ;;
        zenity) zenity --question --title AnyPS5 --text "$1" 2> /dev/null ;;
        *) [ -t 0 ] || return 0; read -r -p "$1 [Y/n] " answer; [ "${answer,,}" != n ] ;;
    esac
}
tell() {
    case "$(gui)" in
        kdialog) kdialog --title AnyPS5 --sorry "$1" 2> /dev/null ;;
        zenity) zenity --warning --title AnyPS5 --text "$1" 2> /dev/null ;;
        *) echo "AnyPS5: $1" >&2 ;;
    esac
}
save_setting() {
    mkdir -p "$CONFIG_DIR"
    { [ -f "$CONFIG" ] && grep -v "^$1=" "$CONFIG" || true; echo "$1=$2"; } > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
}

pick_dump() {
    local start="${1:-$HOME}" folder
    while true; do
        folder="$(ask_folder "Choose your game folder (the one containing eboot.bin)" "$start")" || return 0
        [ -n "$folder" ] || return 0
        if is_dump "$folder"; then (cd "$folder" && pwd); return 0; fi
        tell "That folder is not a PS5 game dump: it needs eboot.bin and sce_sys/param.json. Choose the game's top folder."
        start="$folder"
    done
}
setting() { [ -f "$CONFIG" ] && sed -n "s/^$1=//p" "$CONFIG" | tail -1 || true; }

SUPPORTED_ID=PPSA01881
DATA_DIR=""
RECONVERT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --data-dir) [ $# -ge 2 ] || fail "--data-dir needs a folder"; DATA_DIR="$2"; shift 2 ;;
        --set-data-dir)
            [ $# -ge 2 ] || fail "--set-data-dir needs a folder"
            mkdir -p "$2" "$CONFIG_DIR"
            target="$(cd "$2" && pwd)"
            { [ -f "$CONFIG" ] && grep -v '^data_dir=' "$CONFIG" || true; echo "data_dir=$target"; } > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
            echo "AnyPS5: games will be kept in $target"
            exit 0 ;;
        --reconvert) RECONVERT=1; shift ;;
        --version) echo "AnyPS5 $(cat "$ROOT/VERSION" 2> /dev/null || echo "(development, not packaged)")"; exit 0 ;;
        --) shift; break ;;
        -*) fail "unknown option $1" ;;
        *) break ;;
    esac
done
is_dump() { [ -f "$1/eboot.bin" ] && [ -f "$1/sce_sys/param.json" ]; }
DEFAULT_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/AnyPS5"
if [ $# -ge 1 ]; then
    DUMP="$(cd "$1" 2>/dev/null && pwd)" || fail "dump folder not found: $1"
    shift
else
    found=()
    if is_dump "$BESIDE"; then found=("$BESIDE"); else
        for candidate in "$BESIDE"/*/; do is_dump "${candidate%/}" && found+=("${candidate%/}"); done
    fi
    last="$(setting last_dump)"
    if [ ${#found[@]} -eq 1 ]; then
        DUMP="${found[0]}"
    elif [ -n "$last" ] && is_dump "$last"; then
        DUMP="$last"
    else
        start="$BESIDE"
        [ -n "$last" ] && [ -d "$(dirname "$last")" ] && start="$(dirname "$last")"
        ask_ok_cancel "Please select the game folder (the folder containing eboot.bin)." || exit 0
        DUMP="$(pick_dump "$start")"
        [ -n "$DUMP" ] || exit 0
        picked_id="$(sed -n 's/.*"titleId"[[:space:]]*:[[:space:]]*"\([A-Z0-9]*\)".*/\1/p' "$DUMP/sce_sys/param.json" | head -1)"
        if [ "$picked_id" != "$SUPPORTED_ID" ]; then
            picked_name="$(sed -n 's/.*"titleName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$DUMP/sce_sys/param.json" | head -1)"
            ask_ok_cancel "This AnyPS5 release is made and tested for Quake ($SUPPORTED_ID) only.

${picked_name:-This game} (${picked_id:-unknown}) will probably not work. Start it anyway?" || exit 0
        fi
        if [ -z "$DATA_DIR" ] && [ ! -d "$PORTABLE" ] && [ -z "$(setting data_dir)" ]; then
            if ask_yes_no "Store converted games and saves next to AnyPS5 instead of in your home folder?

Home folder (default): $DEFAULT_DATA
Next to AnyPS5: $PORTABLE"; then
                mkdir -p "$PORTABLE"
                CONFIG_DIR="$PORTABLE"
                CONFIG="$CONFIG_DIR/settings.conf"
            else
                save_setting data_dir "$DEFAULT_DATA"
            fi
        fi
        save_setting last_dump "$DUMP"
    fi
fi

[ -f "$DUMP/eboot.bin" ] || fail "no eboot.bin in $DUMP"
[ -f "$DUMP/sce_sys/param.json" ] || fail "no sce_sys/param.json in $DUMP"
[ -x "$RELINKER" ] || fail "relinker not found at $RELINKER"
[ -f "$LIBS/libc.prx" ] || fail "system libraries not found in $LIBS"

TITLE_ID="$(sed -n 's/.*"titleId"[[:space:]]*:[[:space:]]*"\([A-Z0-9]*\)".*/\1/p' "$DUMP/sce_sys/param.json" | head -1)"
[ -n "$TITLE_ID" ] || fail "no titleId in param.json"
TITLE_NAME="$(sed -n 's/.*"titleName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$DUMP/sce_sys/param.json" | head -1)"

[ -n "$DATA_DIR" ] || { [ -d "$PORTABLE" ] && DATA_DIR="$PORTABLE"; } || DATA_DIR="$(setting data_dir)"
[ -n "$DATA_DIR" ] || DATA_DIR="$DEFAULT_DATA"
GAME="$DATA_DIR/$TITLE_ID"
mkdir -p "$GAME/app0"
echo "AnyPS5: ${TITLE_NAME:-$TITLE_ID} ($TITLE_ID), files in $GAME"

ln -sfn "$LIBS" "$GAME/libs"

# Only file contents (and module names relative to the dump) go into the stamp: the AppImage mounts at
# a new path on every run, and a moved dump is still the same game.
stamp="$( { sha256sum < "$DUMP/eboot.bin"; ( cd "$DUMP" && find sce_module sce_modules prx -maxdepth 1 -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum ); sha256sum < "$RELINKER"; if grep -q GenuineIntel /proc/cpuinfo; then echo intel; else echo other; fi; } | sha256sum | cut -d' ' -f1)"
EXE="$GAME/$TITLE_ID.elf"
if [ "$RECONVERT" = 1 ] || [ ! -x "$EXE" ] || [ "$(cat "$GAME/.conversion" 2>/dev/null)" != "$stamp" ]; then
    echo "AnyPS5: converting (only needed once per game and AnyPS5 version)..."
    rm -rf "$GAME/app0/sce_module" "$GAME/app0/sce_modules" "$GAME/app0/prx"
    args=(--rpath '$ORIGIN/libs')
    if grep -q GenuineIntel /proc/cpuinfo; then args=(--to-intel "${args[@]}"); fi
    "$RELINKER" "${args[@]}" "$DUMP/eboot.bin" "$EXE" > "$GAME/conversion.log" 2>&1 || fail "conversion failed, see $GAME/conversion.log"
    echo "$stamp" > "$GAME/.conversion"
fi

if [ "$(cat "$GAME/.dump" 2>/dev/null)" != "$DUMP" ]; then
    find "$GAME/app0" -type l -delete
    echo "$DUMP" > "$GAME/.dump"
fi
( cd "$DUMP" && find . -type f ! -path './eboot.bin' ! -path './stderr.txt' ! -path './sce_module/*' ! -path './sce_modules/*' ! -path './prx/*' ! -iname '*.AppImage' -print0 ) |
    while IFS= read -r -d '' file; do
        link="$GAME/app0/${file#./}"
        [ -e "$link" ] || [ -L "$link" ] && continue
        mkdir -p "$(dirname "$link")"
        ln -s "$DUMP/${file#./}" "$link"
    done

if [ -z "${ANYPS5_FULLSCREEN:-}" ]; then
    fullscreen="$(setting fullscreen)"
    if [ -z "$fullscreen" ]; then
        if ask_yes_no "Play in fullscreen?

You can switch at any time with F11, or LB+RB+L3+R3 on a controller."; then fullscreen=1; else fullscreen=0; fi
        save_setting fullscreen "$fullscreen"
    fi
    export ANYPS5_FULLSCREEN="$fullscreen"
fi

cd "$GAME"
echo "AnyPS5: starting, log in $GAME/run.log"
exec "$EXE" "$@" > "$GAME/run.log" 2>&1
