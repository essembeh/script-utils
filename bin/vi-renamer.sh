#!/bin/bash

## Common variables
test -n "$EDITOR" || (EDITOR=`which vi` || exit 1)
AWK_BIN=`which awk` || exit 1
SED_BIN=`which sed` || exit 1
MV_BIN=`which mv` || exit 1
CP_BIN=`which cp` || exit 1
MKTEMP_BIN=`which mktemp` || exit 1
SEQ_BIN=`which seq` || exit 1

## Functions
getLine () {
	FILE="$1"
	LINE="$2"
## Head way
	#head -n ${LINE} $FILE | tail -1
## Sed way
	$SED_BIN -n "${LINE}p" < $FILE
# Awk way
	#$AWK_BIN NR==$LINE $FILE
}


## Main
if [ $# -eq 0 ]; then
	echo "Usage: $0 <FILE> <FILE> ..."
	exit 10
fi

## Create tmp directory
TMP=`$MKTEMP_BIN -d` || exit 11
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

for I in `$SEQ_BIN 1 $COUNTA`; do 
	OLDNAME="$(getLine $OLDNAMES $I)"
	NEWNAME="$(getLine $NEWNAMES $I)"
	if [ "$OLDNAME" = "$NEWNAME" ]; then
		echo "Do not rename: $OLDNAME"
	else
		$MV_BIN -v "$OLDNAME" "$NEWNAME"
	fi
done	
