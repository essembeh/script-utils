#!/bin/bash
set -eu

YTDL=${YTDL:-youtube-dl}

display_usage() {
	echo "$0 [--after|-A 20201212] [--last|-l] folder [folder...]"
	echo "  folder should contain a .url file containing one or more youtube url"
}

YTDL_ARGS=( "--continue" "--ignore-errors" "--no-overwrites" "-f" "bestvideo[ext=mp4]+bestaudio[ext=m4a]" )
while [ -n "$1" ]; do
	case "$1" in
		-A|--after)
			shift
			if ! echo "$1" | grep -Eq "^[0-9]{8}$"; then 
				echo "Error, invalid date: $1"
				exit 1
			fi
			YTDL_ARGS+=( "--dateafter" "$1" )
			shift
			;;
		-l|--last)
			shift
			YTDL_ARGS+=( "--playlist-end" "10" )
			;;
		-q|--quiet)
			shift
			YTDL_ARGS+=( "--quiet" )
			;;
		--*)
			display_usage
			exit 1
			;;
		*)
			break
			;;
	esac
done

for FOLDER in "$@"; do
	if test -d "$FOLDER" -a -f "$FOLDER/.url"; then
		grep -E "^https://" "$FOLDER/.url" | while read -r YOUTUBE_URL; do 
			echo "Synchronize $YOUTUBE_URL --> $FOLDER"
			$YTDL "${YTDL_ARGS[@]}" -o "$FOLDER/%(upload_date)s %(title)s.%(ext)s" "$YOUTUBE_URL"
		done
	fi
done

