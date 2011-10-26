#!/bin/sh

##
## Binaries
##
GREP_BIN=`which egrep` || exit 1
SED_BIN=`which sed` || exit 1
MV_BIN=`which mv` || exit 1
CP_BIN=`which cp` || exit 1
FIND_BIN=`which find` || exit 1
MKTEMP_BIN=`which mktemp` || exit 1

##
## Constants
##
MODE="REPLACE"
PATTERN_TAG1="{[^}]*}"
PATTERN_TAG2="<[^>]*>"

##
## Remove tags from file
##
__removeTagsFromFile () {
	srtFile="$1"
	tmpFile="`$MKTEMP_BIN`"
	case "$MODE" in 
		"DRYRUN") 
			echo ""
			return 1;;
		"COPY") 
			targetFile="$srtFile.notag";;
		"REPLACE")
			targetFile="$srtFile";;
	esac
	$CP_BIN "$srtFile" "$tmpFile"
	$SED_BIN -e "s/$PATTERN_TAG1//g" -e "s/$PATTERN_TAG2//g" < "$tmpFile" > "$targetFile" 
	echo " -> $targetFile"
}

##
## Test if file contains tags
##
__testFile () {
	srtFile="$1"
	if [ -f "$srtFile" ]; then
		echo "$srtFile" | $GREP_BIN -q "\.srt$"
		if [ $? -eq 0 ]; then
			$GREP_BIN -q -e "$PATTERN_TAG1" -e "$PATTERN_TAG2" <"$srtFile"
			if [ $? -eq 0 ]; then
				echo -n "+++ File contains tag: $srtFile"
				return 0
			else
				echo    "--- File has no tag:   $srtFile"
				return 3
			fi
		else
			echo "    Not a SRT file:    $srtFile"
			return 2
		fi
	else
		echo "    Not a valid file:  $srtFile"
		return 1
	fi
}

##
## Process a folder
##
__processFolder () {
	folder="$1"
	echo "Processing folder: $folder"
	$FIND_BIN "$folder" -type f -name "*.srt" | while read currentFile; do 
		__testFile "$currentFile" && __removeTagsFromFile "$currentFile"
	done
}


##
## Display usage
##
__usage () {
	echo "Usage: "$(basename $0)" [OPTIONS] files dirs ..."
	echo "Options:"
	echo "  -c | --copy: do not overwrite srt files, create new"
	echo "  -d | --dry-run: just checks for tags"
	echo "  -h | --help: display help"
}

##
## Parse args
##
endOfLoop="false"
while [ "$endOfLoop" = "false" ]; do
	case "$1" in
	"-c"|"--copy")
		MODE="COPY"
		 shift ;;
	"-d"|"--dry-run")
		MODE="DRYRUN"
		shift ;;
	"-h"|"--help")
		__usage
		exit 0 ;;
	"-"*)
		__usage
		exit 1 ;;
	*)
		endOfLoop="true" ;;
	esac
done

##
## Main loop
##
for currentFile in "$@"; do 
	if [ -d "$currentFile" ]; then
		__processFolder "$currentFile"
	else
		__testFile "$currentFile" && __removeTagsFromFile "$currentFile"
	fi
done
