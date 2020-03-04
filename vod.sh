#!/bin/bash
set -eu

YOUTUBEDL_BIN=${YOUTUBEDL_BIN:-youtube-dl}
YOUTUBEDL_ARGS=${YOUTUBEDL_ARGS:--q}
DB_FILE="$HOME/.cache/vod.db"

BASE_URL="$1"
PATH_PATTERN="$2"
INPUT_URL="$3"

if [[ $INPUT_URL != $BASE_URL* ]]; then
    echo "\$3 must start \$1: $1"
    exit 1
fi

pytput "{0:purple,bold} {1:yellow}" "Sync" "$INPUT_URL"
INPUT_PATH=${INPUT_URL#$BASE_URL}
EP_PATHS=$(wget -q "$INPUT_URL" -O - | grep -E -o "$PATH_PATTERN" | grep "^$INPUT_PATH")
pytput "     found {0:bold} episode(s)" "$(echo "$EP_PATHS" | wc -l)"
for EP_PATH in $EP_PATHS; do
    EP_URL="$BASE_URL$EP_PATH"
    if test -f "$DB_FILE" && grep -q "^$EP_URL$" "$DB_FILE"; then
        pytput "{0:cyan,bold} {1:yellow}" "Skip" "$EP_URL"
        continue
    fi
    pytput "{0:purple,bold} {1:yellow}" "Downloading" "$EP_URL"
    pytput "            in {0:blue,bold} with command {1:dim}" "$(pwd)" "$YOUTUBEDL_BIN $YOUTUBEDL_ARGS"
    if "$YOUTUBEDL_BIN" $YOUTUBEDL_ARGS "$EP_URL"; then
        pytput "{0:green,bold} {1:yellow}" "Finished" "$EP_URL"
        if test -n "$DB_FILE"; then
            echo "$EP_URL" >> "$DB_FILE"
        fi
    fi
done