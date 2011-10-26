#!/bin/bash

##
## Binaries
##
test -n "$EDITOR" || (EDITOR=`which vi` || exit 1)
AWK_BIN=`which awk` || exit 1
SED_BIN=`which sed` || exit 1
MV_BIN=`which mv` || exit 1
CP_BIN=`which cp` || exit 1
MKTEMP_BIN=`which mktemp` || exit 1
SEQ_BIN=`which seq` || exit 1
DIRNAME_BIN=`which dirname` || exit 1
BASENAME_BIN=`which basename` || exit 1

##
## Returns a line of a file 
##
getLine () {
	theFile="$1"
	theLine="$2"
## Head way
	#head -n ${theLine} $"theFile" | tail -1
## Sed way
	$SED_BIN -n "${theLine}p" < "$theFile"
# Awk way
	#$AWK_BIN NR==$theLine "$theFile"
}


##
## Main
##
if [ $# -eq 0 ]; then
	echo "Usage: $0 <FILE> <FILE> ..."
	exit 2
fi

## Create tmp directory
tmpFolder=`$MKTEMP_BIN -d` || exit 3
## Create tmp files
oldNamesFile="$tmpFolder/oldnames"
newNamesFile="$tmpFolder/newnames"

for FILE in "$@"; do 
	echo "$FILE" >> "$oldNamesFile"
done

$CP_BIN "$oldNamesFile" "$newNamesFile"

$EDITOR "$newNamesFile" 

countOld=$(wc -l "$oldNamesFile" | $AWK_BIN '{print $1}')
countNew=$(wc -l "$newNamesFile" | $AWK_BIN '{print $1}')
echo "$countOld $countNew"
if [ ! "$countOld" = "$countNew" ]; then
	echo "Line count does not match"
	exit 4
fi

for currentIndex in `$SEQ_BIN 1 $countOld`; do 
	oldLine="`getLine "$oldNamesFile" $currentIndex`"
	oldDirname=`$DIRNAME_BIN "$oldLine"`
	oldBasename=`$BASENAME_BIN "$oldLine"`
	newLine="`getLine "$newNamesFile" $currentIndex`"
	newDirname=`$DIRNAME_BIN "$newLine"`
	newBasename=`$BASENAME_BIN "$newLine"`
	if [ ! "$oldDirname" = "$newDirname" ]; then
		echo "*** DO NOT MODIFY DIRNAME, ONLY BASENAME FOR FILE: $oldLine"
	else
		if [ "$oldBasename" = "$newBasename" ]; then
			echo "*** Same name for file: $oldLine"
		else
			echo -n "    "
			$MV_BIN -v "$oldLine" "$newLine"
		fi
	fi
done	
