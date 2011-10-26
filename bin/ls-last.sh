#!/bin/bash

## Options
SHOW_FULLPATH="false"

##
## Common
## 
BASENAME_BIN=`which basename` || exit 1
FIND_BIN="`which find` -mindepth 1 -maxdepth 1" || exit 1
GREP_BIN=`which egrep` || exit 1
CAT_BIN=`which cat` || exit 1
SORT_BIN=`which sort` || exit 1

##
## Functions
##
__findFiles () {
	folder="$1"
	pattern="$2"
	find "$folder" -type f 2>> /dev/null | $SORT_BIN | $GREP_BIN "$pattern" 
}

##
## Retrieve CONF
##
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
	exit 2
fi

##
## Main
##
$GREP_BIN -v "^#" "$appConfigurationFile" | while read currentPath currentPattern; do
	lastFile=`__findFiles "$currentPath" "$currentPattern" | tail -1`
	if [ "$SHOW_FULLPATH" = "true" ]; then
		echo "$lastFile"
	else
		$BASENAME_BIN "$lastFile"
	fi
done
