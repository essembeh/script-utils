#!/bin/bash

## Linux
MKTEMP=`which mktemp` || exit 1

## MacOS
#MKTEMP="`which mktemp` -t plop" || exit 1

## Commont
AWK=`which awk` || exit 1
SED=`which sed` || exit 1
GREP=`which egrep` || exit 1
WGET=`which wget` || exit 1
BASENAME=`which basename`|| exit 1
DIRNAME=`which dirname`|| exit 1
UNZIP=`which unzip`
CP="cp -vi"

STEU_URL="http://www.sous-titres.eu/series"
STEU_DISCRIM='class="subList"'

##
## Prints log
##
__log () {
	test -n "$VERBOSE" && echo "$@"
}

##
## Get the serie identifier on soust-titres.eu
##
__getSerieIdentifier () {
	$BASENAME "$1" | $AWK '{print tolower($0)}' | $SED -r -e "s/[\. ]/_/g"
}

##
## Get the serie URL on STEU
##
__getSerieHomepage () {
	SERIE_IDENTIFIER=`__getSerieIdentifier "$1"`
	SERIE_URL="$STEU_URL/$SERIE_IDENTIFIER.html"
	echo "$SERIE_URL"
}

##
## Get the serie from filename
##
__getEpisodeNumber () {
	$BASENAME "$1" | $SED -e "s@^.*[\. ][sS]\([0-9]\+\)[eE]\([0-9]\+\).*@\1x\2@" -e "s/^0\+//"
}
##
## Get the serie from filename
##
__getSerieNameFromFile () {
	$BASENAME "$1" | $SED "s@^\(.*\)[\. ][sS][0-9]\+[eE][0-9]\+.*@\1@"
}

##
## Get Zip URL
##
__getZipUrls () {
	HTML_FILE=`$MKTEMP`
	if $WGET "$1" -qO $HTML_FILE; then
		$GREP $STEU_DISCRIM $HTML_FILE | $SED 's/^.*href="\(.*\.zip\)".*$/\1/' | $GREP "$2"
	else
		return 1
	fi
}

##
## Download SRT and prints paths
##
__getSrtFromUrl () {
	ZIP_FILE=`$MKTEMP`
	if $WGET "$1" -qO "$ZIP_FILE"; then
		TMPDIR=`$MKTEMP -d`
		if $UNZIP -qd $TMPDIR $ZIP_FILE; then
			find $TMPDIR -name "*.srt" | sort
		else
			return 2
		fi
	else
		return 1
	fi
}

##
## File selector
##
__fileSelection () {
	if [ $# -eq 0 ]; then
		return 1
	fi
	if [ $# -eq 1 ]; then
		SELECTED_FILE="$1"
	else
		I=1
		for FILE in $@; do 
			FILE_BASENAME=`$BASENAME "$FILE"`
			echo "[$I] $FILE_BASENAME"
			I=`expr $I + 1`
		done
		ANS=0
		while [ $ANS -lt 1 -o $ANS -ge $I ]; do
			echo "Enter a file ? [1-`expr $I - 1`]"
			read ANS
		done
		SELECTED_FILE=$(eval echo $\{`echo $ANS`\})
	fi
}

##
## Guess the SRT Name
##
__computeSrtFilename () {
	SRT_FILE=`echo "$1" | $SED -e "s/[[:alnum:]]\+$//" -e "s/$/srt/"`
	echo "$SRT_FILE"
	test -f "$SRT_FILE" && return 1
}

__main () {
	for EPISODE in "$@"; do 
		EPISODE_NAME=`$BASENAME "$EPISODE"`
		EPISODE_FOLDER=`$DIRNAME "$EPISODE"`
		echo "Find SRT for File: $EPISODE_NAME"
		SERIE_NAME=`__getSerieNameFromFile "$EPISODE_NAME"`
		__log "Serie name: $SERIE_NAME"
		SERIE_IDENTIFIER=`__getSerieIdentifier "$SERIE_NAME"`
		__log "Serie identifier: $SERIE_IDENTIFIER"
		EPISODE_NUMBER=`__getEpisodeNumber "$EPISODE_NAME"`
		__log "Episode number: $EPISODE_NUMBER"
		TARGET_SRT=`__computeSrtFilename "$EPISODE"`
		__log "SRT target: $TARGET_SRT"
		SERIE_HOMEPAGE=`__getSerieHomepage "$SERIE_IDENTIFIER"` 
		__log "Serie homepage: $SERIE_HOMEPAGE"
		ZIP_FILES=`__getZipUrls "$SERIE_HOMEPAGE" "$EPISODE_NUMBER"`
		if [ ! $? -eq 0 ]; then
			echo "*** Error getting subtitles for episode: $EPISODE_NUMBER, on page: $SERIE_HOMEPAGE"
			break
		fi
		__fileSelection $ZIP_FILES
		if [ ! $? -eq 0 ]; then
			echo "*** Error getting subtitles for episode: $EPISODE_NUMBER, on page: $SERIE_HOMEPAGE"
			break
		fi
		ZIP_FILE="$SELECTED_FILE"
		__log "Selected ZIP file: $ZIP_FILE"
		SRT_FILES=`__getSrtFromUrl "$STEU_URL/$SELECTED_FILE"`
		__fileSelection $SRT_FILES
		if [ ! $? -eq 0 ]; then
			echo "*** Error downloading ZIP: $ZIP_FILE"
			break
		fi
		SRT_FILE="$SELECTED_FILE"
		__log "SRT file: $SRT_FILE"
		$CP "$SRT_FILE" "$TARGET_SRT"
	done
}

__main $@
