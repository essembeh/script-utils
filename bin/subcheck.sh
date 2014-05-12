#!/bin/bash

##
## Extensions
##
MOVIE_EXTENSIONS="avi mkv mpg mpeg mp4 mov m4v AVI MKV MPG MPEG MP4 MOV M4V"
SRT_EXTENSIONS="srt SRT"


##
## Colors
##
__customOut() {
    while test $# -gt 0; do
        case $1 in
            black)       tput setaf 0;;
            red)         tput setaf 1;;
            green)       tput setaf 2;;
            yellow)      tput setaf 3;;
            blue)        tput setaf 4;;
            purple)      tput setaf 5;;
            cyan)        tput setaf 6;;
            white)       tput setaf 7;;
            back-black)  tput setab 0;;
            back-red)    tput setab 1;;
            back-green)  tput setab 2;;
            back-yellow) tput setab 3;;
            back-blue)   tput setab 4;;
            back-purple) tput setab 5;;
            back-cyan)   tput setab 6;;
            back-white)  tput setab 7;;
            bold)        tput bold;;
            halfbright)  tput dim;;
            underline)   tput smul;;
            nounderline) tput rmul;;
            reverse)     tput rev;;
            standout)    tput smso;;
            nostandout)  tput rmso;;
            reset)       tput sgr0;;
            *)           tput sgr0;;
        esac
        shift
    done
}


##
## Checks
##

##
## Process file
##
__testFile () {
	local VIDEO_FILE="$1"
	local DIRNAME="`dirname "$VIDEO_FILE"`"
	local BASENAME="`basename "$VIDEO_FILE"`"
	local EXTENSION="${BASENAME##*.}"
	local FILENAME="${BASENAME/%.$EXTENSION/}"

	local IS_VIDEO=false
	for MOVIE_EXTENSION in $MOVIE_EXTENSIONS; do
		if test "$MOVIE_EXTENSION" = "$EXTENSION"; then
			IS_VIDEO=true
			break
		fi
	done
	test $IS_VIDEO = true || return 2
	for SRT_EXTENSION in $SRT_EXTENSIONS; do
		local SRT_FILE="$DIRNAME/$FILENAME.$SRT_EXTENSION"
		test -f "$SRT_FILE" && return 0
	done
	return 1
}

__processFile () {
	local FILE_TO_PROCESS="$1"	
	__testFile "$FILE_TO_PROCESS"
	local RC=$?
	if test $RC -eq 0; then
		__customOut green 
		test $OPTION_VERBOSE -ge 1 && echo "$FILE_TO_PROCESS  ... OK"
	elif test $RC -eq 1; then
		__customOut red
		echo "$FILE_TO_PROCESS  ... No subtitle"
	else
		__customOut cyan
		test $OPTION_VERBOSE -ge 2 && echo "$FILE_TO_PROCESS  --> Not a movie"
	fi
}

##
## Main
##
OPTION_VERBOSE=1
while test -n "$1"; do
	case $1 in
		-q|--quiet) OPTION_VERBOSE=0 ;;
		-v|--verbose) OPTION_VERBOSE=2 ;;
		*) break ;;
	esac
	shift
done

for FILE in "$@"; do
	if test -f "$FILE"; then
		__processFile "$FILE"
	elif test -d "$FILE"; then
		find "$FILE" -type f | sort | while read LINE; do 
			__processFile "$LINE"
		done
	else
		__customOut cyan
		test $OPTION_VERBOSE -ge 1 &&  echo "$FILE  --> Invalid file"
	fi
done

