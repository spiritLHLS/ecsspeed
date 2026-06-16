#!/usr/bin/env sh
# by spiritlhl
# from https://github.com/spiritLHLS/ecsspeed

ECSSPEED_MODE=net
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
LIB_FILE="$SCRIPT_DIR/ecsspeed-lib.sh"

if [ -r "$LIB_FILE" ]; then
    # shellcheck source=script/ecsspeed-lib.sh
    # shellcheck disable=SC1091
    . "$LIB_FILE"
else
    TMP_LIB="${TMPDIR:-/tmp}/ecsspeed-lib.$$"
    LIB_URL="${ECSSPEED_LIB_URL:-https://raw.githubusercontent.com/spiritLHLS/ecsspeed/main/script/ecsspeed-lib.sh}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 8 --max-time 30 "$LIB_URL" -o "$TMP_LIB" || exit 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$TMP_LIB" "$LIB_URL" || exit 1
    else
        printf '%s\n' "Error: curl or wget is required to load ecsspeed-lib.sh" >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    . "$TMP_LIB"
    rm -f "$TMP_LIB"
fi

ecsspeed_main "$ECSSPEED_MODE" "$@"
