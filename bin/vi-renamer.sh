#!/bin/bash

## Common variables
test -x "$EDITOR" || EDITOR=`which vi`
AWK_BIN=`which awk`
MV_BIN=`which mv`
CP_BIN=`which cp`

## Functions
getLine () {
	FILE="$1"
	LINE="$2"
	#head -n ${LINE} $FILE | tail -1
	$AWK_BIN NR==$LINE $FILE
}


## Main
if [ $# -eq 0 ]; then
	echo "Usage: $0 <FILE> <FILE> ..."
	exit 1
fi

## Create tmp directory
TMP=$(mktemp -d)
## Create tmp files
OLDNAMES="$TMP/oldnames"
NEWNAMES="$TMP/newnames"

for FILE in "$@"; do 
	echo "$FILE" >> $OLDNAMES
done

$CP_BIN $OLDNAMES $NEWNAMES

$EDITOR $NEWNAMES 

COUNTA=$(cat $OLDNAMES | wc -l)
COUNTB=$(cat $NEWNAMES | wc -l)

if [ ! $COUNTA = $COUNTB ]; then
	echo "Line count does not match"
	exit 2
fi

for I in $(seq 1 $COUNTA); do 
	OLDNAME="$(getLine $OLDNAMES $I)"
	NEWNAME="$(getLine $NEWNAMES $I)"
	if [ "$OLDNAME" = "$NEWNAME" ]; then
		echo "Do not rename: $OLDNAME"
	else
		$MV_BIN -v "$OLDNAME" "$NEWNAME"
	fi
done	
