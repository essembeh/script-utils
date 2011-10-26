#!/bin/bash

AWK_BIN=`which awk` || exit 1
DIRNAME_BIN=`which dirname` || exit 1
BASENAME_BIN=`which basename` || exit 1
MV_BIN=`which mv` || exit 1
HASH_BIN=`which md5sum` || exit 1
DUPPLICATES="dupplicates"


for currentFile in "$@"; do
	fileHash=`$HASH_BIN "$currentFile" | $AWK_BIN '{ print $1 }'`
	targetFile="`$DIRNAME_BIN "$currentFile"`/$fileHash"
	if [ "`$BASENAME_BIN "$currentFile"`" = "$fileHash" ]; then
		echo "+ Filename is already hash: $targetFile"
	else
		if [ ! -f "$targetFile" ]; then
			echo "  $currentFile renamed as $targetFile"
			$MV_BIN "$currentFile" "$targetFile"
		else
			[ ! -d "$DUPPLICATES" ] && mkdir -p "$DUPPLICATES"
			echo "! File already exist ... $targetFile"
			$MV_BIN "$currentFile" "$DUPPLICATES/$fileHash"
		fi 
	fi
done
