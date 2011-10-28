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
## Options
##
SHOW_ERROR="true"
SHOW_MISSING="true"
SHOW_ORPHAN="true"

##
## Process file
##
__processFile () {
	theFile="$1"
	if [ "$SHOW_ORPHAN" = "true" ]; then
		for currentExtension in $MOVIE_EXTENSIONS; do 
			if echo "$theFile" | $GREP_BIN -q "$currentExtension$"; then
				if __findMissing "$theFile"; then
					return 0
				else
					echo "orphan  $theFile"
					return 1
				fi
			fi
		done
	fi
	if [ "$SHOW_MISSING" = "true" ]; then
		for currentExtension in $SRT_EXTENSIONS; do 
			if echo "$theFile" | $GREP_BIN -q "$currentExtension$"; then
				if __findOrphan "$theFile"; then
					return 0
				else
					echo "missing $theFile"
					return 1
				fi
			fi
		done
	fi
	if [ "$SHOW_ERROR" = "true" ]; then
		echo "error   $theFile"
	fi
	return 2
}

##
## Find SRT for given file
##
__findMissing () {
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
__findOrphan () {
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

endOfLoop="false"
while [ "$endOfLoop" = "false" ]; do 
	case "$1" in 
		"--no-orphan")
			SHOW_ORPHAN="false"
			shift;;
		"--no-missing")
			SHOW_MISSING="false"
			shift;;
		"--no-error")
			SHOW_ERROR="false"
			shift;;
		*)
			endOfLoop="true";;
	esac
done

__main "$@"
