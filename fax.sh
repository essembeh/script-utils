#!/bin/bash
set -eu

for FILE in "$@"; do
	echo "----------[$FILE]----------"
	if test -f "$FILE"; then
		# Create a uniq target folder for extraction
		TARGET=${FILE%.*}
		if test -e "$TARGET"; then
			TARGET="$TARGET.$RANDOM"
		fi
		mkdir -v "$TARGET"
		# Extract file using tar or 7z
		case "$(basename "$FILE")" in
			*.tar|*.tar.*|*.tgz)
				tar -C "$TARGET" -xavf "$FILE"
				;;
			*)
				7z x -o"$TARGET" "$FILE"
				;;
		esac
		# Check if archive only contains one folder/file
		FILES=$(ls -A1 "$TARGET" 2>/dev/null)
		if test $(echo "$FILES" | wc -l) -eq 1; then
			NEWTARGET="$(dirname "$FILE")/$FILES"
			if ! test -e "$NEWTARGET"; then
				mv -nv "$TARGET/$FILES" "$NEWTARGET"
				rmdir -v "$TARGET"
			fi
		fi
	fi
	echo ""
done

