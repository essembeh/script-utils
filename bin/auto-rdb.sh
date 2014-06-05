#!/bin/bash

set -e

FOLDER_EXT=".rdiff-backup"

RDIFFBACKUP="rdiff-backup"
if ! "$RDIFFBACKUP" --version > /dev/null 2>&1; then
	echo "Cannot find rdiff-backup"
	exit 1
fi


CONF_FILE="$1"; shift
if test -f "$CONF_FILE"; then
	echo "Using configuration file: $CONF_FILE"
else
	echo "Configuration file is not valid"
	exit 1
fi
cd "$(dirname "$CONF_FILE")"

cat $(basename "$CONF_FILE") | grep "^[^#]" | while read SOURCE TARGET_DIR OPTIONS; do 
	if test -z "$SOURCE" -o -z "$TARGET_DIR"; then
		echo "Problem with configuration file"
		continue
	fi
	SOURCE_BASENAME=$(basename "$SOURCE")
	test -n "$SOURCE_BASENAME"
	if ! test -d "$SOURCE"; then
		echo "Cannot find source folder: $SOURCE"
		continue
	fi
	TARGET="$TARGET_DIR/$SOURCE_BASENAME$FOLDER_EXT"
	echo "Backup: $SOURCE --> $TARGET ($OPTIONS)"
	rdiff-backup $OPTIONS "$SOURCE" "$TARGET"
done
