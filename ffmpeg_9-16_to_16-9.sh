#!/bin/bash
set -eux

for FILE in "$@"; do
	test -f "$FILE"
	FILE_OUT="$FILE.$RANDOM.mp4"
	if ! test -e "$FILE_OUT"; then
		ffmpeg -i "$FILE" \
			-filter_complex '[0:v]scale=ih*16/9:-1,boxblur=luma_radius=min(h\,w)/20:luma_power=1:chroma_radius=min(cw\,ch)/20:chroma_power=1[bg];[bg][0:v]overlay=(W-w)/2:(H-h)/2,crop=h=iw*9/16' \
			"$FILE_OUT"
	fi
done
