#!/bin/bash

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
CONF_FILES="/etc/ls-last.conf $HOME/.ls-last.conf"
for currentConfFile in $CONF_FILES; do
	test -f "$currentConfFile" && appConfigurationFile="$currentConfFile";
done

if [ ! -f "$appConfigurationFile" ]; then
	echo "Cannot find configuration file, should be one of: $CONF_FILES"
	exit 2
fi

##
## Main
##
commandToApply="$@"
test -z "$commandToApply" && commandToApply="echo"
$GREP_BIN -v "^#" "$appConfigurationFile" | while read currentPath currentPattern count; do
	test -z "$count" && count=1
	__findFiles "$currentPath" "$currentPattern" | tail -$count | while read line; do 
		$commandToApply "$line"
	done
done
