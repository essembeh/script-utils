#!/bin/bash

HASH_BIN=/usr/local/bin/gsha1sum
HASH_LEN=7
EXIFTOOL_BIN=/usr/local/bin/exiftool
DATE_FORMAT="%Y%m%d-%H%M%S"

_getHash () {
	HASH=`$HASH_BIN "$1" | awk '{print $1}'`
	if [ $HASH_LEN -eq 0 ]; then
		echo $HASH
	else
		echo $HASH | head -c $HASH_LEN
	fi
}

_getTimeStamp () {
	$EXIFTOOL_BIN -createDate -s3 -d "$DATE_FORMAT" "$1" 2>/dev/null
}

_getExtension () {
	echo "$1" | awk -F . '{print tolower($NF)}'  
}

for FILE in "$@"; do 
	test -f "$FILE" || continue
	HASH=`_getHash "$FILE"` 
	TIMESTAMP=`_getTimeStamp "$FILE"` 
	EXT=`_getExtension "$FILE"` 
	if [ -n "$TIMESTAMP" ]; then
		NEWNAME="${TIMESTAMP}_$HASH.$EXT"
	else 
		NEWNAME="$HASH.$EXT"
	fi
	mv -n -v "$FILE" "`dirname "$FILE"`/$NEWNAME"
done

