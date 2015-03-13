#!/bin/bash

AUNPACK="aunpack" 
AUNPACK_ARGS="--quiet"

set -e

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


__testCommand() {
	while test -n "$1"; do
		if ! "$1" --help > /dev/null 2> /dev/null; then
			__customOut bold red
			echo "Missing command: $1"
			exit 1
		fi
		shift
	done
}

__cdCleanFolder() {
	FILE="$1"
	BASENAME=`basename "$FILE"`
	FILENAME="${BASENAME%.*}"
	[[ $FILENAME =~ .tar$ ]] && FILENAME=${FILENAME%.tar}
	test -n "$FILENAME"
	DESTINATION="$FILENAME"
	test ! -e "$DESTINATION" || DESTINATION="${FILENAME}.d"
	test ! -e "$DESTINATION" || DESTINATION="${FILENAME}.$RANDOM"
	test ! -e "$DESTINATION" 
	mkdir -p "$DESTINATION"
	cd "$DESTINATION"
}

__extractHere() {
	FILE="$1"
	__customOut bold back-blue yellow
	case "$FILE" in
		*.zip)
			__testCommand unzip
			echo "Unzip: $FILE  -->  $PWD"
			__customOut reset
			unzip "$FILE"
			;;
		*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tar.xz)
			__testCommand tar
			echo "Untar: $FILE  -->  $PWD"
			__customOut reset
			tar vfax "$FILE"
			;;
		*.rar)
			__testCommand unrar
			echo "Unrar: $FILE  -->  $PWD"
			__customOut reset
			unrar x -kb "$FILE"
			;;
		*.7z)
			__testCommand 7z
			echo "Un7z: $FILE  -->  $PWD"
			__customOut reset
			7z x "$FILE"
			;;
		*)
			__testCommand aunpack
			echo "Aunpack: $FILE  -->  $PWD"
			__customOut reset
			aunpack "$FILE"
			;;
	esac
}

__testCommand realpath 

for FILE in "$@"; do 
	if test -f "$FILE"; then 
		REALPATH=`realpath "$FILE"`
		(__cdCleanFolder "$FILE" && __extractHere "$REALPATH")
	fi
done

