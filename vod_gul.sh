#!/bin/bash
set -eu

VOD_BIN=$(dirname "$(readlink -f "$0")")/vod.sh
PATTERN="/[a-zA-Z0-9/_-]+/VOD[0-9]+"

export YOUTUBEDL_ARGS="-q --output %(title)s.%(ext)s"

if [[ $1 = "https://replay.gulli.fr"* ]]; then
    "$VOD_BIN" "https://replay.gulli.fr" "$PATTERN" "$1"
elif [[ $1 = "https://svod.gulli.fr"* ]]; then
    "$VOD_BIN" "https://svod.gulli.fr" "$PATTERN" "$1"
else
    echo "URL not supported: $1"
fi