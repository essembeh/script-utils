#!/bin/bash

## Options
SHOW_FULLPATH="false"

# Common
BASENAME_BIN=`which basename` || exit 1
FIND_BIN="`which find` -mindepth 1 -maxdepth 1" || exit 1
GREP_BIN=`which egrep` || exit 1
CAT_BIN=`which cat` || exit 1


## Functions
__expandPath () {
	pathToExpand=$1
	listOfFiles=`eval echo $pathToExpand`
	for currentFile in $listOfFiles; do 
		test -f "$currentFile" && echo "$currentFile"
	done
}


## Retrieve CONF
appBinary="$0"
while [ -L "$appBinary" ]; do
	appLink="$(readlink "$appBinary")"
	if echo "$appLink" | $GREP_BIN -q "^/"; then
		appBinary="$appLink"
	else
		appBinary="$(dirname "$appBinary")/$appLink"
	fi  
done
appConfigurationFile="${appBinary%.sh}.conf"

if [ ! -f "$appConfigurationFile" ]; then
	echo "Cannot find configuration file: $appConfigurationFile"
	exit 1
fi

## Main
$GREP_BIN -v "^#" "$appConfigurationFile" | while read currentPath; do
	lastFile=`__expandPath "$currentPath" | tail -1`
	if [ "$SHOW_FULLPATH" = "true" ]; then
		echo "$lastFile"
	else
		$BASENAME_BIN "$lastFile"
	fi
done
