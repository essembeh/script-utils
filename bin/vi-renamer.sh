#!/bin/bash

set -e

##
## Binaries
##
AWK_BIN=awk
SED_BIN=sed
MKTEMP_BIN=mktemp
SEQ_BIN=seq

##
## Functions
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
## Main
##
if test $# -eq 0; then
	echo "Usage: $0 <FILE> <FILE> ..."
	exit 0
fi
if test -z "$EDITOR"; then
	export EDITOR=vim
fi
TEMP_FILE_A=`$MKTEMP_BIN` || __error "Error with mktemp"
TEMP_FILE_B=`$MKTEMP_BIN` || __error "Error with mktemp"
for CURRENT_ARG in "$@"; do 
	if test -e "$CURRENT_ARG"; then
		echo "$CURRENT_ARG" >> "$TEMP_FILE_A"
		echo "$CURRENT_ARG" >> "$TEMP_FILE_B"
	fi
done
$EDITOR "$TEMP_FILE_B" 
LINE_COUNT_A=$(wc -l "$TEMP_FILE_A" | $AWK_BIN '{print $1}') 
LINE_COUNT_B=$(wc -l "$TEMP_FILE_B" | $AWK_BIN '{print $1}')
test $LINE_COUNT_A -eq $LINE_COUNT_B
for INDEX in `$SEQ_BIN 1 $LINE_COUNT_A`; do 
	CURRENT_FILE_A="`$SED_BIN -n ${INDEX}p < "$TEMP_FILE_A"`"
	CURRENT_FILE_B="`$SED_BIN -n ${INDEX}p < "$TEMP_FILE_B"`"
	if test "$CURRENT_FILE_A" = "$CURRENT_FILE_B"; then
		continue
	fi
	## Check path
	DIRNAME_A=`dirname "$CURRENT_FILE_A"`
	DIRNAME_B=`dirname "$CURRENT_FILE_B"`
	if test ! "$DIRNAME_A" = "$DIRNAME_B"; then
		__customOut reset red
		echo "Different dirnames, do nothing for file: $CURRENT_FILE_A"
	elif test -e "$CURRENT_FILE_B"; then
		__customOut reset red
		echo "File already exists, do nothing: $CURRENT_FILE_B"
	else
		__customOut reset green
		mv -n -v "$CURRENT_FILE_A" "$CURRENT_FILE_B"
	fi
done

