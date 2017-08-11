#!/bin/bash
set -e

for FILE in "$@"; do 
	test -f "$FILE"
	OUTPUT="${FILE%.*}"
	test -d "$OUTPUT" && OUTPUT="${OUTPUT}.$RANDOM"
	7z x -o"$OUTPUT" "$FILE"
	rm -iv "$FILE"
done

