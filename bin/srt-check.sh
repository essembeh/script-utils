#!/bin/sh

##
## Binaries
##
GREP_BIN=`which egrep` || exit 1
SED_BIN=`which sed` || exit 1

##
## Extensions
##
MOVIE_EXTENSIONS="avi mkv mpg mpeg mp4 mov"
SRT_EXTENSIONS="srt"

##
## Process file
##
__processFile () {
	theFile="$1"
	for currentExtension in $MOVIE_EXTENSIONS; do 
		if echo "$theFile" | $GREP_BIN -q "$currentExtension$"; then
			if __findSRT "$theFile"; then
				return 0
			else
				echo "m   Missing subtitle for movie: $theFile"
				return 1
			fi
		fi
	done
	for currentExtension in $SRT_EXTENSIONS; do 
		if echo "$theFile" | $GREP_BIN -q "$currentExtension$"; then
			if __findMovie "$theFile"; then
				return 0
			else
				echo "o   Orphan subtitle: $theFile"
				return 1
			fi
		fi
	done
	echo "e   Unknwon file: $theFile"
	return 2
}

##
## Find SRT for given file
##
__findSRT () {
	movieFile="$1"
	for currentExtension in $SRT_EXTENSIONS; do 
		srtFile=`echo "$movieFile" | $SED_BIN -r "s/[[:alnum:]]+$/$currentExtension/"`
		test -f "$srtFile" && return 0
	done
	return 1
}

##
## Find movie for given srt
##
__findMovie () {
	srtFile="$1"
	for currentExtension in $MOVIE_EXTENSIONS; do 
		movieFile=`echo "$srtFile" | $SED_BIN -r "s/[[:alnum:]]+$/$currentExtension/"`
		test -f "$movieFile" && return 0
	done
	return 1
}

##
## Process folder
##
__processFolder () {
	folder="$1"
	find "$folder" -type f | sort | while read currentFile; do
		__processFile "$currentFile"
	done
}

## 
## Main
##
__main () {
	for currentArg in "$@"; do
		if [ -d "$currentArg" ]; then
			__processFolder "$currentArg"
		else
			__processFile "$currentArg"
		fi
	done
}

__main "$@"
