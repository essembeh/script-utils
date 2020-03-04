#!/bin/bash
set -eu

VOD_BIN=$(dirname "$(readlink -f "$0")")/vod.sh

export YOUTUBEDL_ARGS="-q --output %(title)s.%(ext)s --hls-prefer-ffmpeg"
"$VOD_BIN" "https://www.france.tv" "/[a-zA-Z0-9/_-]+\.html" "$1"