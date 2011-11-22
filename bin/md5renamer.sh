#!/bin/bash
##
## functions
##
__printline () {
	__print "$1" "$2"
	echo 
}
__print () {
	printf "%10s %s" "[$1]" "$2"
}
__error () {
	__printline error "$1"
	exit 1
}
##
## Binaries
##
awk=`which awk` || __error "Error finding command: awk"
dirname=`which dirname` || __error "Error finding command: dirname"
basename=`which basename` || __error "Error finding command: basename"
mv=`which mv` || __error "Error finding command: mv"
md5sum=`which md5sum` || __error "Error finding command: md5sum"
##
## Variables
##
dupplicatesFolder="dupplicates"
##
## Main
##
for currentFile in "$@"; do
	test -e "$currentFile" || continue
	currentBasename=`$basename "$currentFile"`
	currentDirname=`$dirname "$currentFile"`
	fileHash=`$md5sum "$currentFile" | $awk '{ print $1 }'`
	if [ "$currentBasename" = "$fileHash" ]; then
		__printline info "File hashnamed: $currentFile"
	else
		targetFile="$currentDirname/$fileHash"
		if [ -f "$targetFile" ]; then
			test -d "$dupplicatesFolder" || mkdir -p "$dupplicatesFolder"
			__print error "Dupplicate: "
			$mv -v "$currentFile" "$dupplicatesFolder/$fileHash"
		else
			__print info ""
			$mv -v "$currentFile" "$targetFile"
		fi 
	fi
done

