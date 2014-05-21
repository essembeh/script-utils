#!/bin/bash

set -e

RDIFFBACKUP="rdiff-backup"
if ! "$RDIFFBACKUP" --version > /dev/null 2>&1; then
	echo "Cannot find rdiff-backup"
	exit 1
fi

FOLDER_EXT=".rdiff-backup"

CONF_FILE="$1"; shift
if test -f "$CONF_FILE"; then
	echo "Using configuration file: $CONF_FILE"
else
	echo "Configuration file is not valid"
	exit 1
fi

cat "$CONF_FILE" | grep "^[^#]" | while read SOURCE TARGET_DIR OPTIONS; do 
	if test -z "$SOURCE" -o ! -d "$SOURCE"; then
		echo "Problem with source folder: $SOURCE"
		continue
	fi
	if test -z "$TARGET_DIR"; then
		echo "Problem with destination folder: $TARGET_DIR"
	fi
	SOURCE_BASENAME=$(basename "$SOURCE")
	test -n "$SOURCE_BASENAME"
	TARGET="$TARGET_DIR/$SOURCE_BASENAME$FOLDER_EXT"
	echo "Backup: $SOURCE --> $TARGET ($OPTIONS)"
	rdiff-backup $OPTIONS "$SOURCE" "$TARGET"
done
