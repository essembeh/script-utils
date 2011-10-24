#!/bin/bash

AWK_BIN=`which awk` || exit 1
DIRNAME_BIN=`which dirname` || exit 1
BASENAME_BIN=`which basename` || exit 1
MV_BIN=`which mv` || exit 1
HASH_BIN=`which md5sum` || exit 1


if [ "$1" = "-h" -o "$1" = "--hash" ]; then
	shift
	HASH_BIN="$1"
	shift
	echo "Using specific hash: $HASH_BIN"
fi


COPY_DIR="COPIES"

for FILE in "$@"; do
	HASH=$($HASH_BIN "$FILE" | $AWK_BIN '{ print $1 }')
	TARGET="`$DIRNAME_BIN "$FILE"`/$HASH"
	if [ "`$BASENAME_BIN "$FILE"`" = "$HASH" ]; then
		echo "+ Filename is already hash: $TARGET"
	else
		if [ ! -f "$TARGET" ]; then
			echo "  $FILE renamed as $TARGET"
			$MV_BIN "$FILE" "$TARGET"
		else
			[ ! -d "$COPY_DIR" ] && mkdir -p "$COPY_DIR"
			echo "! File already exist ... $TARGET"
			$MV_BIN "$FILE" "$COPY_DIR/$HASH"
		fi 
	fi
done
