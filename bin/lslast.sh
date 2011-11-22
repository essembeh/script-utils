#!/bin/bash

##
## Common
## 
basename=`which basename` || exit 1
find="`which find` -mindepth 1 -maxdepth 1" || exit 1
grep=`which egrep` || exit 1
cat=`which cat` || exit 1
sort=`which sort` || exit 1

##
## Functions
##
__findFiles () {
	folder="$1"
	pattern="$2"
	find "$folder" -type f 2>> /dev/null | $sort | $grep "$pattern" 
}

##
## Retrieve CONF
##
appConfigurationFile="$HOME/.lslast.conf"
if [ ! -f "$appConfigurationFile" ]; then
	echo "Cannot find configuration file: $appConfigurationFile"
	exit 2
fi

##
## Main
##
commandToApply="$@"
test -z "$commandToApply" && commandToApply="echo"
$grep -v "^#" "$appConfigurationFile" | while read currentPath currentPattern count; do
	test -z "$count" && count=1
	__findFiles "$currentPath" "$currentPattern" | tail -$count | while read line; do 
		$commandToApply "$line"
	done
done

