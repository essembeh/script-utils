#!/bin/bash

AUNPACK=`which aunpack` || exit 1
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

$AUNPACK --version > /dev/null 2>&1
if test $? -ne 0; then
	echo "Cannot find atools"
	exit 1
fi

for FILE in "$@"; do 
	if test -f "$FILE"; then 
		BASENAME=`basename "$FILE"`
		DESTINATION="${BASENAME%.*}"
		test -e "$DESTINATION" && DESTINATION="$BASENAME"
		test -e "$DESTINATION" && DESTINATION="$BASENAME$$"
		test -e "$DESTINATION" && DESTINATION="$BASENAME$RANDOM"
		test -e "$DESTINATION" && DESTINATION=`mktemp -d`
		if test -d "$DESTINATION"; then
			__customOut reset red	
			echo "Folder already exists: $DESTINATION"
			__customOut reset
		else 
			mkdir "$DESTINATION" 
		fi
		echo -n "Extracting $FILE --> $DESTINATION ... "
		$AUNPACK $AUNPACK_ARGS -X "$DESTINATION" "$FILE"
		echo "done"
	fi
done

